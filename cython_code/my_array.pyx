"""
Модуль динамического массива, реализованный для Python
при помощи Cython
Реализованные методы:
append, extend, insert,
remove, pop, __len__,
__eq__, __str__, __repr__, __sizeof__
Принимает значения типа int, float
Способ инициализации:
array("i", [...]) - для int
array("d", [...]) - для float
"""
# cython: language_level=3
# distutils: language = c


from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free

from cpython.float cimport PyFloat_AsDouble
from cpython.int cimport PyInt_AsLong

# Для проверки на тип в __eq__
import array as eq_array

#Структура дескриптора, с поддержкой различных типов данных
cdef struct arraydescr:
    char * typecode
    int itemsize
    object (*getitem)(array, size_t)
    int (*setitem)(array, size_t, object)

cdef object double_getitem(array a, size_t index):
    """
    Функция получения значения типа double из массива по индексу
    :param a: массив из которого получаем
    :param index: индекс искомого элемента
    :return: искомый элемент
    """
    return (<double *> a.data)[index]

cdef int double_setitem(array a, size_t index, object obj):
    """
    Функция записи числа типа double в массив по индексу
    :param a: массив, в который записываем
    :param index: индекс, куда записываем
    :param obj: элемент, который записываем
    :return: код выполнения (0 - успех, -1 - ошибка)
    """
    if not isinstance(obj, int) and not isinstance(obj, float):
        return -1

    cdef double value = PyFloat_AsDouble(obj)

    if index >= 0:
        (<double *> a.data)[index] = value
    return 0

cdef object int_getitem(array a, size_t index):
    """
    Функция получения значения типа long из массива по индексу
    :param a: массив из которого получаем
    :param index: индекс искомого элемента
    :return: искомый элемент
    """
    return (<int *> a.data)[index]

cdef int int_setitem(array a, size_t index, object obj):
    """
    Функция записи числа типа long в массив по индексу
    :param a: массив, в который записываем
    :param index: индекс, куда записываем
    :param obj: элемент, который записываем
    :return: код выполнения (0 - успех, -1 - ошибка)
    """
    if not isinstance(obj, int):
        return -1

    cdef long value = PyInt_AsLong(obj)

    if index >= 0:
        (<long *> a.data)[index] = value
    return 0

# Массив дескрипторов для типов long и double
cdef arraydescr[2] descriptors = [
    arraydescr("d", sizeof(double), double_getitem, double_setitem),
    arraydescr("i", sizeof(long), int_getitem, int_setitem),
]

# Поддержка произвольных типов, значения - индексы дескрипторов в массиве
cdef enum TypeCode:
    DOUBLE = 0
    LONG = 1

#Коды для распознавателя значений
cdef enum TypesCompare:
    INT_TO_INT = 1
    INT_TO_DOUBLE = 2
    DOUBLE_TO_INT = 3
    DOUBLE_TO_DOUBLE = 4
    NOT_IN_TYPES = 0


cdef int char_typecode_to_int(str typecode):
    """
    Преобразование строкового кода в число
    :param typecode: строковое представление
    :return: число, соответствующее строковому представлению
    """
    if typecode == "d":
        return TypeCode.DOUBLE
    if typecode == "i":
        return TypeCode.LONG
    return -1


cdef long index_validate(long index, long length):
    """
    Преобразования индекса (для поддержки обращения с отрицательным индексом)
    :param index: индекс
    :param length: длина массива
    :return: корректный индекс
    """
    if length == 0 and index < 0:
        return 0
    if index < 0:
        return length + index
    return index

cdef class array:
    """
    Класс динамического массива, реализующий основные методы list в python,
    с поддержкой значений типа int и float
    """
    cdef public size_t length, size
    cdef int valtype
    cdef char * data
    cdef arraydescr * descr

    def __init__(self, str typecode, initialise=None):
        """
        Конструктор экземпляра массива
        :param typecode: "i" если массив с значениями типа "int", "d" если float (double)
        :param initialise: Iterable объект для инициализации исходных значений массива
        """
        if initialise is None:
            initialise = []
        self.size = len(initialise)  # Размер массива
        self.length = len(initialise)  # Кол-во элементов массива

        cdef int mtypecode = char_typecode_to_int(typecode)
        self.valtype = mtypecode
        self.descr = &descriptors[mtypecode]

        # Выделяем память для массива
        self.data = <char *> PyMem_Malloc(self.length * self.descr.itemsize)
        if not self.data:
            raise MemoryError()

        for i in range(self.length):
            check_res = self.check_type(initialise[i])
            if check_res == TypesCompare.NOT_IN_TYPES and check_res != TypesCompare.INT_TO_DOUBLE:
                raise TypeError("Incorrect type of value")
            self[i] = self.val_validate(initialise[i])


    def check_type(self, o: object):
        """
        Распознание типа значение в соответствии с типом массива
        :param o входное значение
        :return: результат распознания
        """
        if isinstance(o, int):
            if abs(o) > 2_147_483_647:
                raise ValueError("Слишком большое число")
            if TypeCode.LONG == self.valtype:
                return TypesCompare.INT_TO_INT
            if TypeCode.LONG != self.valtype:
                return TypesCompare.INT_TO_DOUBLE
        if isinstance(o, float):
            if o.is_integer():
                return TypesCompare.DOUBLE_TO_INT
            if TypeCode.DOUBLE == self.valtype:
                return TypesCompare.DOUBLE_TO_DOUBLE
        return TypesCompare.NOT_IN_TYPES

    def val_validate(self, object value):
        """
        Преобразование значения в соответствии с типом массива
        :param value значение для преобразования
        :return: преобразованное значение
        """
        check_res = self.check_type(value)
        if check_res == TypesCompare.INT_TO_INT:
            return int(value)
        if check_res == TypesCompare.INT_TO_DOUBLE:
            return float(value)
        if check_res == TypesCompare.DOUBLE_TO_INT:
            return int(value)
        if check_res == TypesCompare.INT_TO_INT or check_res == TypesCompare.DOUBLE_TO_DOUBLE:
            return value
        raise TypeError("Incorrect type of value")

    def extend_array(self) -> None:
        """
        Увеличение кол-ва выделяемой для массива памяти вдвое
        """
        if self.length == self.size:
            if self.length:
                self.size *= 2
            else:
                self.size = 1
            self.mem_upd()

    def extend_by_array(self, object ext_arr) -> None:
        """
        Изменение количества памяти на размер переданного как аргумент массива
        :param ext_arr: массив, на размер которого увеличиваем текущий массив
        """
        if not isinstance(ext_arr, array):
            raise TypeError
        self.size += ext_arr.size
        self.mem_upd()

    def shorten_array(self) -> None:
        """
        Уменьшение кол-ва выделяемой для массива памяти вдвое
        """
        if self.length <= self.size // 2:
            self.size = self.size // 2
            self.mem_upd()

    def mem_upd(self) -> None:
        """
        Расширение массива, с учетом нового значения size
        """
        self.data = <char *> PyMem_Realloc(self.data, self.size * self.descr.itemsize)

    def append(self, item: object) -> None:
        """
        Добавление нового элемента в конец массива
        :param item: добавляемый элемент
        """
        val_item = self.val_validate(item)

        self.extend_array()
        self.descr.setitem(self, self.length, val_item)
        self.length += 1

    def extend(self, ext_arr: array) -> None:
        """
        Расширение массива другим массивом того же типа
        :param ext_arr: массив, которым расширяем
        """
        if not isinstance(ext_arr, array):
            raise TypeError(f"Incorrect type of argument")
        if self.descr != ext_arr.descr:
            raise TypeError(f"Incorrect type of values")
        self.extend_by_array(ext_arr)
        cdef long i
        for i in range(len(ext_arr)):
            self.descr.setitem(self, self.length, ext_arr[i])
            self.length += 1

    def insert(self, index: int, item: object) -> None:
        """
        Вставка элемента по индексу (с последующим сдвигом вправо элементов идущих после индекса)
        :param index: индекс на который вставляем элемент
        :param item: вставляемый элемент
        """
        val_item = self.val_validate(item)
        if index > self.length and index > 0:
            self.append(val_item)
            return
        if abs(index) > self.length and index < 0:
            index = 0
        self.extend_array()
        index = index_validate(index, self.length)
        self.length += 1
        for i in range(self.length - 1, index, -1):
            self[i] = self[i - 1]
        self[index] = val_item

    def remove(self, object item) -> None:
        """
        Удаление первого вхождения значения в массив
        :param item: значение элемента
        """
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
        """
        Метод удаления элемента по индексу с последующим его возвращением
        array.pop() - удалит последний элемент массива
        :param index: индекс удаляемого элемента
        :return: удаляемый элемент
        """
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
        """
        Очистка памяти, занимаемой массивом
        """
        PyMem_Free(self.data)

    def __getitem__(self, index: int) -> object:
        """
        Получение значения элемента массива по индексу
        :param index: индекс элемента
        :return: значение, находящееся по индексу
        """
        if not isinstance(index, int):
            raise TypeError(f"array indices must be integers, not {type(index).__name__}")
        new_ind = index_validate(index, self.length)
        if 0 <= new_ind < self.length:
            return self.descr.getitem(self, new_ind)
        raise IndexError("list index out of range")

    def __setitem__(self, index: int, value: object) -> None:
        """
        Установка значения элемента массива по индексу
        :param index: индекс элемента
        :param value: новое значение элемента
        """
        if not isinstance(index, int):
            raise TypeError(f"array indices must be integers, not {type(index).__name__}")
        new_ind = index_validate(index, self.length)
        new_val = self.val_validate(value)
        if 0 <= new_ind < self.length:
            self.descr.setitem(self, new_ind, new_val)
        else:
            raise IndexError("list index out of range")

    def __len__(self) -> size_t:
        """
        :return: Кол-во элементов массива
        """
        return self.length

    def __eq__(self, array_to_eq : list | eq_array) -> bool:
        """
        Метод сравнения массива с другим Iterable объектом
        :param array_to_eq: Объект с которым сравниваем
        :return: булевый результат проверки на равенство
        """
        if not isinstance(array_to_eq, (list, eq_array.array)):
            return False
        if len(self) != len(array_to_eq):
            return False
        cdef int el;
        for el in range(self.length):
            if self[el] != array_to_eq[el]:
                return False
        return True

    # def __str__(self) -> str:
    #     """
    #     Возвращает текстовое представление массива
    #     :return: Строка в виде [x1, x2, x3], содержащая все эл-ты массива
    #     """
    #     return f"[{', '.join(str(i) for i in self)}]"

    def __repr__(self) -> str:
        """
        Возвращает текстовое представление массива
        :return: Строка в виде [x1, x2, x3], содержащая все эл-ты массива
        """
        return f"[{', '.join(str(i) for i in self)}]"

    def __sizeof__(self) -> size_t:
        """
        Возвращает занимаемую массивом память
        :return: Количество занимаемой памяти
        """
        return self.size * self.descr.itemsize
