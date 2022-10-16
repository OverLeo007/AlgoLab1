# pylint: disable=C0114

# from setuptools import setup
# from setuptools.command.install import install
import os

from distutils.core import setup
from distutils.command.build_ext import build_ext

from Cython.Build import cythonize

from lib_mover import move


class BuildExtCommand(build_ext):
    def move(self):
        path = r".\build\lib.win-amd64-3.9\cython_code\\"
        for file in os.listdir(path):
            os.rename(path + file, path + (new_name := ".".join(file.split(".")[::2])))
            os.replace(path + new_name, new_name)

    def run(self):
        self.move()
        build_ext.run(self)


cmdclass = {
    "build_ext": BuildExtCommand
}

setup(
    name='my_array',
    ext_modules=cythonize("my_array.pyx"),
    cmdclass=cmdclass,
)
