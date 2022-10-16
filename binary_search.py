"""Шаблон бинарного поиска"""


def search(sequence, item):
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
