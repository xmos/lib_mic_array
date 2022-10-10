
set( APP_NAME tests-signal-basicmicarray )

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

macro( create_target    MICS    FRAME_SIZE    USE_ISR )

  set( TARG_NAME  "${APP_NAME}_${MICS}ch_${FRAME_SIZE}smp_${USE_ISR}" )

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
            "SAMPLES_PER_FRAME=${FRAME_SIZE}"
            "USE_ISR=${USE_ISR}"
  )

  add_dependencies( ${APP_NAME}  ${TARG_NAME} )
endmacro()


# Application parameters
#                   Mics    Frame Size    ISR
create_target(      1       1             0         )
create_target(      1       16            0         )
create_target(      2       1             0         )
create_target(      2       16            0         )
create_target(      4       1             0         )
create_target(      4       16            0         )
create_target(      8       1             0         )
create_target(      8       16            0         )
create_target(      8       64            0         )
create_target(      1       1             1         )
create_target(      1       16            1         )
create_target(      2       1             1         )
create_target(      2       16            1         )
create_target(      4       1             1         )
create_target(      4       16            1         )
create_target(      8       1             1         )
create_target(      8       16            1         )
create_target(      8       64            1         )
