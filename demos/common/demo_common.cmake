
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

set( DEMO_COMMON_INCLUDES  "${CMAKE_CURRENT_LIST_DIR}/src" )

file( GLOB_RECURSE    DEMO_COMMON_SOURCES    
            "${CMAKE_CURRENT_LIST_DIR}/src/*.c"
            "${CMAKE_CURRENT_LIST_DIR}/src/*.xc"
            "${CMAKE_CURRENT_LIST_DIR}/src/*.cpp"
            "${CMAKE_CURRENT_LIST_DIR}/src/*.S"   )