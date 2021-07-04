# simplest way I can think of to segfault Python
import ctypes; ctypes.string_at(0)
