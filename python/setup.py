# Copyright 2020-2021 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.
import setuptools

# Another repository might depend on python code defined in this one.  The
# procedure to set up a suitable python environment for that repository may
# pip-install this one as editable using this setup.py file.  To minimise the
# chance of version conflicts while ensuring a minimal degree of conformity,
# the 3rd-party modules listed here require the same major version and at
# least the same minor version as specified in the requirements.txt file.
# The same modules should appear in the requirements.txt file as given below.
setuptools.setup(
    name='lib_mic_array',
    packages=setuptools.find_packages(),
    install_requires=[
        "flake8~=3.8",
        "matplotlib~=3.3",
        "numpy~=1.18",
        "pylint~=2.5",
        "pytest~=6.0",
        "pytest-xdist~=1.34",
        "scipy~=1.4",
        "lib_logging",
        "lib_xassert",
    ],

    dependency_links=[
        './../lib_logging#egg=lib_logging',
        './../lib_xassert#egg=lib_xassert',
    ],
)
