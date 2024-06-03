import os
import platform
import subprocess as sbp

import numpy as nm
from Cython.Distutils import build_ext, Extension
from setuptools import setup


# Recover the CLASS version
with open(os.path.join('..', 'include', 'common.h'), 'r') as v_file:
    for line in v_file:
        if line.find("_VERSION_") != -1:
            # get rid of the " and the v
            VERSION = line.split()[-1][2:-1]
            break

compiler = os.environ.get('CC', 'gcc')

includes = [nm.get_include(), "../include",]
if os.environ.get('INCLUDES', None):
    includes += [
        include_path.lstrip('-I')
        for include_path in os.environ['INCLUDES'].split()
    ]

libs = ['class', 'openblas',]

mvec_smoketest = sbp.Popen([compiler, '-lmvec'], stderr=sbp.PIPE)
_, mvec_stderr = mvec_smoketest.communicate()
if b'mvec' not in mvec_stderr:
    libs += ['mvec', 'm',]
else:
    libs += ['m',]

cflags = []
ldflags = []

ompflag = os.environ.get('OMPFLAG', None)
if ompflag:
    cflags += ompflag.split()
    if platform.system().lower() == 'darwin':
        ldflags += ['-Xpreprocessor', '-fopenmp',]
        # libs += ['omp',]
    if platform.system().lower() == 'linux':
        ldflags += ['-fopenmp',]
        # libs += ['gomp',]

classy = Extension(
    'classy',
    ["classy.pyx"],
    include_dirs=includes,
    libraries=libs,
    library_dirs=["../",],
    extra_compile_args=cflags,
    extra_link_args=ldflags,
)

setup(
    name='classy',
    version=VERSION,
    description='Python interface to the Cosmological Boltzmann code CLASS',
    url='http://www.class-code.net',
    cmdclass={'build_ext': build_ext},
    ext_modules=[classy,],
)
