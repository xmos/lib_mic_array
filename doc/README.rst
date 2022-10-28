######################
Building Documentation
######################

Instructions are given below to build the documentation.  The recommended method is using Docker, 
however, alternative instructions are provided in case using Docker in not an option.

To develop the content of this repository, it is recommended to launch a `sphinx-autobuild`
server as per the instructions below. Once started, point a web-browser at
http://127.0.0.1:8000. If running the server within a VM, remember to configure
port forwarding.

You can now edit the .rst documentation, and your web-browser content will automatically
update.

************
Using Docker
************

=============
Prerequisites
=============

Install `Docker <https://www.docker.com/>`_.

Pull the docker container:

.. code-block:: console

    $ docker pull ghcr.io/xmos/doc_builder:main

========
Building
========

To build the documentation, run the following command in the root of the repository:

.. code-block:: console

    $ docker run --rm -t -u "$(id -u):$(id -g)" -v $(pwd):/build -e REPO:/build -e DOXYGEN_INCLUDE=/build/doc/Doxyfile.inc ghcr.io/xmos/doc_builder:main

********************
Without Using Docker
********************

=============
Prerequisites
=============

Install `Doxygen <https://www.doxygen.nl/index.html>`_.

Install the required Python packages:

.. code-block:: console

    $ pip install -r requirements.txt

========
Building
========

Build documentation:

.. code-block:: console

    $ make html

Launch sphinx-autobuild server:

.. code-block:: console

    $ make livehtml

Clean documentation:

.. code-block:: console

    $ make clean

Clean and build documentation with link check:

.. code-block:: console
    
    $ make clean html linkcheck SPHINXOPTS="-W --keep-going"
