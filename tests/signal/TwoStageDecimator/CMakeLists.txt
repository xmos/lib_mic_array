
set( APP_NAME tests-signal-decimator )

set( TARGET_XN   XVF3610_Q60A.xn )

add_custom_target( ${APP_NAME} )
add_dependencies( tests-signal  ${APP_NAME} )

get_filename_component(XSCOPE_CONFIG config.xscope ABSOLUTE)

set(APP_COMPILE_FLAGS
  "${CMAKE_CURRENT_SOURCE_DIR}/${TARGET_XN}"
  "${XSCOPE_CONFIG}" 
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


set( APP_INCLUDES  "src" )

file( GLOB_RECURSE APP_SOURCES 
    "src/*.c" 
    "src/*.xc" 
    "src/*.cpp" )



macro( create_target    MICS    S2DEC    S2TAPS )

  set( TARG_NAME  "${APP_NAME}_${MICS}_${S2DEC}_${S2TAPS}" )

  add_executable( ${TARG_NAME} )

  target_compile_options( ${TARG_NAME}
  PRIVATE ${APP_COMPILE_FLAGS} )

  target_link_options( ${TARG_NAME}
  PRIVATE ${APP_LINK_FLAGS} )

  target_sources( ${TARG_NAME} 
  PRIVATE ${APP_SOURCES} )

  target_include_directories( ${TARG_NAME}
  PRIVATE ${APP_INCLUDES} )

  target_link_libraries( ${TARG_NAME}
    lib_xcore_math
    lib_mic_array )

  target_compile_definitions( ${TARG_NAME}
    PRIVATE "CHAN_COUNT=${MICS}"
            "S2_DEC_FACT=${S2DEC}"
            "S2_TAPS=${S2TAPS}"
  )

  add_dependencies( ${APP_NAME}  ${TARG_NAME} )
endmacro()

# NOTE: It doesn't really make senes for the S2TapCount to be smaller
#       than the S2DecFactor -- also that breaks the test.

# Application parameters
#                   Mics    S2DecFactor   S2TapCount
create_target(      1       1             1         )
create_target(      1       1             2         )
create_target(      2       1             1         )
create_target(      2       1             16        )
create_target(      4       6             16        )
create_target(      8       6             48        )
create_target(      1       6             48        )
create_target(      2       6             65        )
create_target(      4       3             65        )
create_target(      8       3             24        )
