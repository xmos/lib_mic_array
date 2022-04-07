
set( APP_NAME tests-unit )


set(APP_COMPILE_FLAGS
  "${CMAKE_SOURCE_DIR}/XVF3610_Q60A.xn"
  "-fxscope"
  "-mcmodel=large"
  "-Wno-xcore-fptrgroup"
  "-Wno-unknown-pragmas"
  "-Wno-format"
  "-g"
  "-O2"
)

set(APP_LINK_FLAGS ${APP_COMPILE_FLAGS} ) 
list( APPEND  APP_LINK_FLAGS  "-report"                     )
list( APPEND  APP_LINK_FLAGS  "-fcmdline-buffer-bytes=1024" )


set( APP_INCLUDES  "src" )

file( GLOB_RECURSE APP_SOURCES 
    "src/*.c" 
    "src/*.xc" 
    "src/*.cpp" )

add_executable( ${APP_NAME} )

target_compile_options( ${APP_NAME}
PRIVATE ${APP_COMPILE_FLAGS} )

target_link_options( ${APP_NAME}
PRIVATE ${APP_LINK_FLAGS} )

target_sources( ${APP_NAME} 
PRIVATE ${APP_SOURCES} )

target_include_directories( ${APP_NAME}
PRIVATE ${APP_INCLUDES} )

target_link_libraries( ${APP_NAME}
  xcore_sdk_lib_xs3_math
  xcore_sdk_lib_mic_array
  unity )

add_dependencies( tests  ${APP_NAME} )