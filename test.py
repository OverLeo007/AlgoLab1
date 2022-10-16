from cython_code import my_array
from array import array as another_array
import time

start = time.time()
for _ in range(100):
    test_array = my_array.array('i', [])
    for i in range(100):
        test_array.append(i)
print(f'\n\033[33mВремя вашего append: {time.time() - start} сек.\033[0m')





