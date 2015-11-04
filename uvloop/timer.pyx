# cython: language_level=3


cimport cython

from libc.stdint cimport uint64_t

from . cimport uv
from .loop cimport Loop
from .handle cimport Handle

from cpython.mem cimport PyMem_Malloc, PyMem_Free


@cython.freelist(100)
cdef class Timer(Handle):
    def __cinit__(self, Loop loop, object callback, uint64_t timeout,
                  object on_close_callback):
        cdef int err

        self.handle = <uv.uv_handle_t*> \
                            PyMem_Malloc(sizeof(uv.uv_timer_t))
        if self.handle is NULL:
            raise MemoryError()

        self.handle.data = <void*> self

        err = uv.uv_timer_init(loop.loop, <uv.uv_timer_t*>self.handle)
        if err < 0:
            loop._handle_uv_error(err)

        self.callback = callback
        self.on_close_callback = on_close_callback
        self.running = 0
        self.timeout = timeout
        self.loop = loop

    cdef stop(self):
        cdef int err

        if self.running == 1:
            err = uv.uv_timer_stop(<uv.uv_timer_t*>self.handle)
            if err < 0:
                self.loop._handle_uv_error(err)
            self.running = 0

    cdef start(self):
        cdef int err

        if self.running == 0:
            err = uv.uv_timer_start(<uv.uv_timer_t*>self.handle,
                                    cb_timer_callback,
                                    self.timeout, 0)
            if err < 0:
                self.loop._handle_uv_error(err)
            self.running = 1

    cdef void on_close(self):
        Handle.on_close(self)
        try:
            self.on_close_callback()
        except BaseException as ex:
            self.loop._handle_uvcb_exception(ex)


cdef void cb_timer_callback(uv.uv_timer_t* handle):
    cdef Timer timer = <Timer> handle.data
    timer.running = 0
    try:
        timer.callback()
    except BaseException as ex:
        timer.loop._handle_uvcb_exception(ex)