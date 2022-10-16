import os


def move():
    path = r".\build\lib.win-amd64-3.9\cython_code\\"
    for file in os.listdir(path):
        os.rename(path + file, path + (new_name := ".".join(file.split(".")[::2])))
        os.replace(path + new_name, new_name)
    print("Билд перемещен")


if __name__ == '__main__':
    move()