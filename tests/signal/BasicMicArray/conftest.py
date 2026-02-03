# Copyright 2022-2026 XMOS LIMITED.
# This Software is subject to the terms of the XMOS Public Licence: Version 1.

import enum
import random
import numpy as np
import sys
import pytest

FLAGS = [
  "print-output",
  "print-xgdb",
  "debug-print-filters"
]

def pytest_addoption(parser):
    parser.addoption("--build-dir", action="store", default='.')
    parser.addoption("--frames", type=int, default=40)
    parser.addoption(
                      "--level",
                      action="store",
                      default="smoke",
                      choices=["smoke", "nightly"],
                      help="Test coverage level",
                  )
    parser.addoption("--seed", type=int, default=None)

    addflag = lambda x: parser.addoption(f"--{x}", action="store_true")

    [addflag(x) for x in FLAGS]


class DevCommand(enum.Enum):
  RESUME = 0
  TERMINATE = 1
  PRINT_FILTERS = 2

def pytest_configure(config):
    if config.pluginmanager.hasplugin("xdist"):
        if hasattr(config, 'workerinput'): # skip if worker node
            return

    # We're here if either master node in xdist or running without xdist
    # Perform setup that should happen only once here
    seed_value = config.getoption("--seed")
    if seed_value is None:
        seed_value = random.randint(0, sys.maxsize) # Set a random seed
    config.seed = seed_value
    print(f"Set seed to {config.seed}")

def pytest_configure_node(node):
    # Propagate the value to each worker. This is called only for worker nodes
    node.workerinput['seed'] = node.config.seed


@pytest.fixture(scope="session", autouse=True)
def set_random_seed(request):
    """Automatically seed Python and NumPy for all tests."""
    if hasattr(request.config, 'workerinput'):
        # Worker node
        seed = request.config.workerinput['seed']
    else:
        # Master node
        seed = request.config.seed

    # Seed Python and NumPy
    random.seed(seed)
    np.random.seed(seed % 2**32)

def pytest_collection_modifyitems(config, items):
    selected = []
    deselected = []

    for item in items:
        m = item.get_closest_marker("uncollect_if")
        if m:
            func = m.kwargs["func"]
            if func(config, **item.callspec.params):
                deselected.append(item)
            else:
                selected.append(item)
        else: # If test doesn't define an uncollect function, default behaviour is to collect it
            selected.append(item)

    config.hook.pytest_deselected(items=deselected)
    items[:] = selected
