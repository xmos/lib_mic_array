# Makefile to build the Sphinx and Doxygen documentation
#

DOXYGEN_INCLUDE     = Doxyfile.inc
export DOXYGEN_INCLUDE # this is needed for the doxyfile @INCLUDE

BUILDDIR            = _build
DOXYGEN_OUTPUT      =$(BUILDDIR)/_doxygen
DOXYGEN_OUTPUT_DIR  =$(DOXYGEN_OUTPUT)/xml
export DOXYGEN_OUTPUT # this is needed for the doxyfile OUTPUT_DIRECTORY

BREATHE_PROJECT=lib_mic_array

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?= -Dbreathe_projects.$(BREATHE_PROJECT)=$(DOXYGEN_OUTPUT_DIR)
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = .

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: help Makefile Doxyfile doxy

doxy:
	doxygen

$(DOXYGEN_OUTPUT_DIR)/index.xml: Doxyfile
	mkdir -p $(DOXYGEN_OUTPUT)
	doxygen

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile $(DOXYGEN_OUTPUT_DIR)/index.xml
	$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

livehtml:
	sphinx-autobuild --host 0.0.0.0 "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)