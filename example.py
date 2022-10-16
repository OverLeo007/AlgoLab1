"""Пример использования модуля my_array"""

import sys

from cython_code import my_array

x = my_array.array('d', [123, 0, 0, 1, 2])

print(f'{x = }')
print(f'{x.length = }')


print(f'{x[0] = }')
print(f'{x[1] = }')
print(f'{x[2] = }')
print(f'{x[3] = }')
print(f'{x[4] = }')
print('-' * 50)

x.append(123)

y = [0.0, 1.0, 2.0, 3.0, 4.0]
print(f'{sys.getsizeof(x) = }')
print(f'{sys.getsizeof(y) = }')
