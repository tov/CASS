# Loads settings and secrets from COURSE_ROOT/etc.

import cass
import re

comment_line  = re.compile('^\s*(#|$)')
variable_line = re.compile('^\s*([_a-zA-Z][_a-zA-Z0-9]*)=(.*)$')

class EnvSyntaxError(Exception):
    def __init__(self, filename, lineno):
        message = 'Syntax error at {} line {}'.format(filename, lineno)
        super().__init__(message)

def load(name):
    filename = cass.etc('{}.env'.format(name))
    with open(filename) as f:
        return load_from_file(f, filename)

def load_from_file(f, name='<unknown>'):
    lineno = 0
    result = {}
    for line in f.readlines():
        lineno += 1
        if comment_line.match(line): continue
        m = variable_line.match(line)
        if not m: raise EnvSyntaxError(name, lineno)
        result[m[1]] = m[2].strip('\n')
    return result

def load_secret(name):
    filename = cass.etc('{}.secret'.format(name))
    with open(filename) as f:
        return load_secret_from_file(f)

def load_secret_from_file(f):
    return f.read().rstrip('\n')

