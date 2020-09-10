# Help pyCASS find things.

from os import path
import sys

class NoCourseRoot(Exception):
    def __init__(self, path):
        super().__init__('Couldn’t find course root from {}'.format(path))

def is_course_root(dir):
    return path.exists(path.join(dir, '.root'))

def find_course_root(start_path):
    dir = path.abspath(start_path)
    while dir != '/':
        if is_course_root(dir):
            return dir
        dir = path.dirname(dir)
    raise NoCourseRoot(start_path)

def _setup():
    global _course_root
    global _course_base

    _course_root = find_course_root(__file__)
    sys.path.append(path.join(_course_root, '.CASS', 'lib'))

    _course_base = path.join(_course_root, 'private')
    if not path.exists(_course_base):
        _course_base = _course_root

def _with(*rest):
    return path.join(_course_base, *rest)

def root(*rest):  return path.join(_course_root, *rest)
def bin(*rest):   return _with('bin', *rest)
def etc(*rest):   return _with('etc', *rest)
def lib(*rest):   return _with('lib', *rest)
def var(*rest):   return _with('var', *rest)
def db(*rest):    return _with('var', 'db', *rest)
def cache(*rest): return _with('var', 'cache', *rest)

_setup()
