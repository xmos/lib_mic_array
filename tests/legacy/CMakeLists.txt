
set(BINARY_PATH   bin)
set(BINARY_NAME   legacy_build.xe)

set(LEGACY_BUILD_TOOL   xmake)

# This folder is for making sure that the module_build_info in the
# library is correct. Not an app that needs to be run, just built.
# Here it's added as a custom target so that it can be tested just 
# via CMake
add_custom_target( tests-legacy_build
  BYPRODUCTS ${BINARY_PATH}/${BINARY_NAME}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
  COMMAND ${LEGACY_BUILD_TOOL}
  COMMENT "Building legacy_build.xe..." )

  
add_dependencies( tests tests-legacy_build )