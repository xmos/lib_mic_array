
set( APP_NAME tests-build-prefab )


set(APP_COMPILE_FLAGS
  "${CMAKE_SOURCE_DIR}/XVF3610_Q60A.xn"
  "-fxscope"
  "-mcmodel=large"
  "-Wno-xcore-fptrgroup"
  "-Wno-unknown-pragmas"
  "-report"
  "-g"
  "-O2"
)

set(APP_LINK_FLAGS ${APP_COMPILE_FLAGS} ) 

set( APP_INCLUDES  "src" )

set( APP_SOURCES
    "src/app.cpp"
    "src/main.xc" )

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
  xcore_sdk_lib_mic_array )

  
add_dependencies( tests-build tests-build-prefab )