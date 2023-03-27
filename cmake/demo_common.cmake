
# Just collects sources and includes for the common stuff

set( DEMO_COMMON_FLAGS
        "${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_XN}"
        "-fxscope"
        "-mcmodel=large"
        "-Wno-xcore-fptrgroup"
        "-Wno-unknown-pragmas"
        "-report"
        "-g"
        "-O2"
        "-Wm,--map,memory.map"
        "-DAPP_NAME=\"${APP_NAME}\""
)

set( DEMO_COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/common" )

set( DEMO_COMMON_INCLUDES  "${DEMO_COMMON_DIR}/src" )

file( GLOB_RECURSE    DEMO_COMMON_SOURCES    
            "${DEMO_COMMON_DIR}/src/*.c"
            "${DEMO_COMMON_DIR}/src/*.xc"
            "${DEMO_COMMON_DIR}/src/*.cpp"
            "${DEMO_COMMON_DIR}/src/*.S"   )