
# Just collects sources and includes for the common stuff


set( DEMO_COMMON_FLAGS
        "${CMAKE_SOURCE_DIR}/XVF3610_Q60A.xn"
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


set( DEMO_COMMON_INCLUDES  "${CMAKE_SOURCE_DIR}/demos/common/src" )

file( GLOB_RECURSE    DEMO_COMMON_SOURCES    
            "${CMAKE_SOURCE_DIR}/demos/common/src/*.c"
            "${CMAKE_SOURCE_DIR}/demos/common/src/*.xc"
            "${CMAKE_SOURCE_DIR}/demos/common/src/*.cpp"
            "${CMAKE_SOURCE_DIR}/demos/common/src/*.S"   )