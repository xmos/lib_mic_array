
set( APP_NAME tests-build-prefab )

set( TARGET_XN   XVF3610_Q60A.xn )


set(APP_COMPILE_FLAGS
  "${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_XN}"
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
  lib_xcore_math
  lib_mic_array )

  
add_dependencies( tests-build tests-build-prefab )