
# This file creates a static library target for lib_i2c so that
# it need not be separately compiled for each demo app.

### Library Name
set( LIB_NAME  lib_i2s )

### Compile as static lib
add_library( ${LIB_NAME} STATIC  ${I2S_HIL_SOURCES} )

### Add include paths
target_include_directories( ${LIB_NAME} PUBLIC ${I2S_HIL_INCLUDES} )

### Make sure the archive has the right name
# @todo: This can hopefully go away when we have CMake toolchain support
set_target_properties( ${LIB_NAME} PROPERTIES
                        PREFIX ""
                        OUTPUT_NAME ${LIB_NAME}
                        SUFFIX ".a" )

### Compile flags

set(LIB_COMPILE_FLAGS   
        "-Os" "-g" "-MMD" 
        "-Wno-format" 
        "-march=xs3a"
        "-fxscope"
        "-mcmodel=large"
        "-Wno-xcore-fptrgroup"
        "-Wno-unknown-pragmas"
)

target_compile_options( ${LIB_NAME} PRIVATE ${LIB_COMPILE_FLAGS} )