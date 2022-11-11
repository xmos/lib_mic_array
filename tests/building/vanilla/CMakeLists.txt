
set( APP_NAME tests-build-vanilla )

set( TARGET_XN   XVF3610_Q60A.xn )

set( MCLK_FREQ            24576000  )


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

set( APP_SOURCES  "src/main.xc" )

#**********************
# create targets
#**********************

# Things to vary:
# MIC_COUNT -> 1, 2
# FRAME_SIZE -> 1, 16, 256
# PDM_FREQ -> 3.072 MHz (16kHz audio), 6.144 MHz (24kHz audio)
# DCOE_ENABLED -> false, true

add_custom_target( ${APP_NAME} )

foreach( MIC_COUNT  1 2 )
  foreach( FRAME_SIZE 1 16 256 )
    foreach( PDM_FREQ   3072000 6144000 )
      foreach( DCOE_ENABLED   0 1 )

        set( TARG_NAME "${APP_NAME}_${MIC_COUNT}mic_${FRAME_SIZE}spf_${PDM_FREQ}hz" )
        if( ${DCOE_ENABLED} )
          set( TARG_NAME "${TARG_NAME}_dcoe" )
        endif()

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
          PRIVATE MIC_ARRAY_CONFIG_USE_DC_ELIMINATION=${DCOE_ENABLED} )

        mic_array_vanilla_add( ${TARG_NAME} 
            ${MCLK_FREQ} ${PDM_FREQ} 
            ${MIC_COUNT} ${FRAME_SIZE} )

        add_dependencies( ${APP_NAME} ${TARG_NAME} )

      endforeach()
    endforeach()
  endforeach()
endforeach()


add_dependencies( tests-build tests-build-vanilla )