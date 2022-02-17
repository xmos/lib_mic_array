
# This file creates a static library target for lib_xs3_math so that
# it need not be separately compiled for each demo app.

### Library Name
set( LIB_NAME  lib_xs3_math )

### Compile as static lib
add_library( ${LIB_NAME} STATIC  ${LIB_XS3_MATH_SOURCES} )

### Add include paths
target_include_directories( ${LIB_NAME} PUBLIC ${LIB_XS3_MATH_INCLUDES} )

### Make sure the archive has the right name
# @todo: This can hopefully go away when we have CMake toolchain support
set_target_properties( ${LIB_NAME} PROPERTIES
                        PREFIX ""
                        OUTPUT_NAME ${LIB_NAME}
                        SUFFIX ".a" )

### Compile flags

list(APPEND XS3_MATH_COMPILE_FLAGS   
                            -Os -g -MMD 
                            -Wno-format 
                            -march=xs3a
)

target_compile_options( ${LIB_NAME} PRIVATE ${XS3_MATH_COMPILE_FLAGS} )