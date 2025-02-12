#!/usr/bin/env python3
from dbm.ndbm import library
from logging import root
import os
import subprocess as sbp

import numpy as np
from Cython.Distutils import Extension, build_ext
from setuptools import setup


root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


# -- Package -------------------------------------------------------------

PKGNAME = 'classy'

with open(os.path.join(root_dir, "include", "common.h"), 'r') as info_file:
    for line in info_file:
        if line.find("_VERSION_") != -1:
            # Remove quotation marks and prefixes.
            version = line.split()[-1].strip("\"'").lstrip('v')
            break


# -- Build ---------------------------------------------------------------

compiler = os.getenv('CC', 'gcc')

include_dirs = [np.get_include(), os.path.join(root_dir, "include"),]
if (includes := os.getenv('INCLUDES')) is not None:
    include_dirs += [
        include_path.lstrip('-I')
        for include_path in includes.split()
    ]

library_dirs = [os.path.join(root_dir, "build/lib"),]

libs = ['class', 'openblas',]

_, mvec_stderr = sbp.Popen([compiler, '-lmvec'], stderr=sbp.PIPE).communicate()
if b'mvec' not in mvec_stderr:
    libs += ['mvec', 'm',]
else:
    libs += ['m',]

cflags = []
ldflags = []

if os.getenv('CFLAGS_OMP'):
    cflags += os.getenv('CFLAGS_OMP').split()
if os.getenv('LDFLAGS_OMP'):
    ldflags += os.getenv('LDFLAGS_OMP').split()

classy = Extension(
    PKGNAME,
    sources=[f"{PKGNAME}.pyx",],
    include_dirs=include_dirs,
    libraries=libs,
    library_dirs=library_dirs,
    extra_compile_args=cflags,
    extra_link_args=ldflags,
)

setup(
    name=PKGNAME,
    version=version,
    url='http://www.class-code.net',
    cmdclass={'build_ext': build_ext},
    ext_modules=[classy,],
)
