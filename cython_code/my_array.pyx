# cython: language_level=3
# distutils: language = c

from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free


from cpython.float cimport PyFloat_AsDouble
from cpython.int cimport PyInt_AsLong

# Для проверки на тип в __eq__
import array as eq_array

# Так как хотим использовать массив для разных типов, указывая только
# код типа без дополнительных замарочек, то используем самописный
# дескриптор. Он будет хранить функции получения и записи значения в
# массив для нужных типов. Упрощенны аналог дескриптора из модуля array:
# https://github.com/python/cpython/blob/243b6c3b8fd3144450c477d99f01e31e7c3ebc0f/Modules/arraymodule.c#L32
cdef struct arraydescr:
    char * typecode
    int itemsize
    object (*getitem)(array, size_t)
    int (*setitem)(array, size_t, object)

cdef object double_getitem(array a, size_t index):
    # Функция получения значения из массива для типа double.
    # Обратите внимание, что Cython сам преобразует Сишное значение типа
    # double в аналогичны объект PyObject
    return (<double *> a.data)[index]

cdef int double_setitem(array a, size_t index, object obj):
    if not isinstance(obj, int) and not isinstance(obj, float):
        return -1

    cdef double value = PyFloat_AsDouble(obj)

    if index >= 0:
        (<double *> a.data)[index] = value
    return 0

cdef object int_getitem(array a, size_t index):
    return (<int *> a.data)[index]

cdef int int_setitem(array a, size_t index, object obj):
    if not isinstance(obj, int):
        return -1

    cdef long value = PyInt_AsLong(obj)

    if index >= 0:
        (<long *> a.data)[index] = value
    return 0

# Если нужно работать с несколькими типами используем массив дескрипторов:
# https://github.com/python/cpython/blob/243b6c3b8fd3144450c477d99f01e31e7c3ebc0f/Modules/arraymodule.c#L556
cdef arraydescr[2] descriptors = [
    arraydescr("d", sizeof(double), double_getitem, double_setitem),
    arraydescr("i", sizeof(long), int_getitem, int_setitem),
]

# Зачатки произвольных типов, значения - индексы дескрипторов в массиве
cdef enum TypeCode:
    DOUBLE = 0
    LONG = 1

# преобразование строкового кода в число
cdef int char_typecode_to_int(str typecode):
    if typecode == "d":
        return TypeCode.DOUBLE
    if typecode == "i":
        return TypeCode.LONG
    return -1


cdef long index_validate(long index, long length):
    if length == 0 and index < 0:
        return 0
    if index < 0:
        return length + index
    return index



cdef class array:
    # Класс статического массива.
    # В поле length сохраняем длину массива, а в поле data будем хранить
    # данне. Обратите внимание, что для data используем тип char,
    # занимающий 1 байт. Далее мы будем выделять сразу несколько ячеек
    # этого типа для одного значения другого типа. Например, для
    # хранения одного double используем 8 ячеек для char.
    cdef public size_t length, size
    cdef char * data
    cdef arraydescr * descr

    def __init__(self, str typecode, initialise=None):
        if initialise is None:
            initialise = []
        self.size = len(initialise) # Размер массива
        self.length = len(initialise) # Кол-во элементов массива

        cdef int mtypecode = char_typecode_to_int(typecode)
        self.descr = &descriptors[mtypecode]

        # Выделяем память для массива
        self.data = <char *> PyMem_Malloc(self.length * self.descr.itemsize)
        if not self.data:
            raise MemoryError()

        for i in range(self.length):
            self[i] = initialise[i]

    def extend_array(self) -> None:
        if self.length == self.size:
            if self.length:
                self.size *= 2
            else:
                self.size = 1
            self.mem_upd()

    def extend_by_array(self, object ext_arr) -> None:
        if not isinstance(ext_arr, array):
            raise TypeError
        self.size += ext_arr.size
        self.mem_upd()


    def shorten_array(self) -> None:
        if self.length <= self.size // 2:
            self.size = self.size // 2
            self.mem_upd()

    def mem_upd(self) -> None:
        self.data = <char *> PyMem_Realloc(self.data, self.size * self.descr.itemsize)

    def append(self, object item) -> None:
        self.extend_array()
        self.descr.setitem(self, self.length, item)
        self.length += 1

    def extend(self, array ext_arr) -> None:
        self.extend_by_array(ext_arr)
        cdef long i
        for i in range(len(ext_arr)):
            self.descr.setitem(self, self.length, ext_arr[i])
            self.length += 1

    def insert(self, index: int, item: object) -> None:
        if index > self.length and index > 0:
            self.append(item)
            return
        if abs(index) > self.length and index < 0:
            index = 0
        self.extend_array()
        index = index_validate(index, self.length)
        self.length += 1
        for i in range(self.length - 1, index, -1):
            self[i] = self[i - 1]
        self[index] = item

    def remove(self, object item) -> None:
        cdef int is_find = False
        cdef long i
        for i in range(self.length):
            if self[i] == item:
                is_find = True
            if is_find and i < self.length - 1:
                self[i] = self[i + 1]
        if not is_find:
            raise ValueError(f"array.remove(item): item not in array")
        self.length -= 1
        self.shorten_array()

    def pop(self, index: int | None = None) -> object:
        if self.length == 0:
            raise IndexError(f"pop from empty list")
        if index is None:
            pop_val = self[self.length - 1]
            self.length -= 1
            return pop_val
        if -index > self.length or index >= self.length:
            raise IndexError(f"pop index out of range")
        index = index_validate(index, self.length)
        pop_val = self[index]
        for i in range(index, self.length - 1):
            self[i] = self[i + 1]
        self.length -= 1
        self.shorten_array()
        return pop_val

    def __dealloc__(self) -> None:
        PyMem_Free(self.data)

    def __getitem__(self, index: int) -> object:
        if 0 <= index < self.length:
            return self.descr.getitem(self, index)
        raise IndexError("list index out of range")

    def __setitem__(self, index: int, value: object) -> None:
        if 0 <= index < self.length:
            self.descr.setitem(self, index, value)
        else:
            raise IndexError("list index out of range")

    def __len__(self) -> size_t:
        return self.length

    def __eq__(self, array_to_eq : list | eq_array) -> bool:
        if not isinstance(array_to_eq, (list, eq_array.array)):
            return False
        if len(self) != len(array_to_eq):
            return False
        cdef int el;
        for el in range(self.length):
            if self[el] != array_to_eq[el]:
                return False
        return True

    def __str__(self) -> str:

        return f"[{', '.join(str(i) for i in self)}]"

    def __repr__(self) -> str:

        return f"[{', '.join(str(i) for i in self)}]"

    def __sizeof__(self) -> size_t:
        return self.size * self.descr.itemsize




