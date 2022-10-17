"""
Модуль содержащий функцию бинарного поиска,
применимую к array из модуля my_array
"""

from __future__ import annotations

from cython_code.my_array import array


def search(sequence: array, item: object) -> object | None:
    """
    Бинарный поиск в массиве
    :param sequence: массив
    :param item: элемент
    :return: индекс элемента или None при его отсутствии
    """
    ind = 0
    length = len(sequence) - 1
    if len(sequence) == 0:
        return None
    while ind < length:
        mid = int((ind + length) / 2)
        if item > sequence[mid]:
            ind = mid + 1
        else:
            length = mid
    if sequence[length] == item:
        return length

    return None
