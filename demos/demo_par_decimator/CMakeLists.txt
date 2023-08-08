
set(APP_NAME demo_par_decimator)

set( TARGET_XN   XCORE-AI-EXPLORER.xn )

#**********************
# configuration
#**********************

set( MCLK_FREQ            24576000  )
set( PDM_FREQ             3072000   )
set( SAMPLES_PER_FRAME    16        )

#**********************
# includes
#**********************

set( APP_INCLUDES  "src" )
list( APPEND  APP_INCLUDES ${DEMO_COMMON_INCLUDES} )

#**********************
# sources
#**********************

file( GLOB_RECURSE APP_SOURCES "src/*.c" "src/*.xc" "src/*.cpp" "src/*.S"   )

list( APPEND  APP_SOURCES  ${DEMO_COMMON_SOURCES} )

#**********************
# create targets
#**********************

foreach( N_MICS  8 16 )

  set( TARGET_NAME "${APP_NAME}_${N_MICS}mic" )

  make_demo_app_target( ${TARGET_NAME} "${APP_SOURCES}" "${APP_INCLUDES}" "" )

  target_compile_definitions( ${TARGET_NAME}
    PRIVATE MIC_ARRAY_CONFIG_MCLK_FREQ=${MCLK_FREQ} )
  target_compile_definitions( ${TARGET_NAME}
    PRIVATE MIC_ARRAY_CONFIG_PDM_FREQ=${PDM_FREQ} )
  target_compile_definitions( ${TARGET_NAME}
    PRIVATE MIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS} )
  target_compile_definitions( ${TARGET_NAME}
    PRIVATE MIC_ARRAY_CONFIG_USE_DDR=1 )
  target_compile_definitions( ${TARGET_NAME}
    PRIVATE MIC_ARRAY_CONFIG_PORT_MCLK=PORT_MCLK_IN_OUT )
  target_compile_definitions( ${TARGET_NAME}
    PRIVATE MIC_ARRAY_CONFIG_PORT_PDM_CLK=PORT_PDM_CLK )
  target_compile_definitions( ${TARGET_NAME}
    PRIVATE MIC_ARRAY_CONFIG_PORT_PDM_DATA=PORT_PDM_DATA )
  target_compile_definitions( ${TARGET_NAME}
    PRIVATE MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=${SAMPLES_PER_FRAME} )

  add_dependencies( demos  ${TARGET_NAME} )

endforeach()

