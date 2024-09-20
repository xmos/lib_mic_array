
set(APP_NAME demo_vanilla)

set( TARGET_XN   XVF3610_Q60A.xn )

#**********************
# Vanilla Configuration
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

foreach( N_MICS  1 2 )

  set( TARG_NAME "${APP_NAME}_${N_MICS}mic" )

  make_demo_app_target( ${TARG_NAME} "${APP_SOURCES}" "${APP_INCLUDES}" "" )

  mic_array_vanilla_add( ${TARG_NAME} ${MCLK_FREQ} ${PDM_FREQ} 
                         ${N_MICS} ${SAMPLES_PER_FRAME} )
    
  add_dependencies( demos  ${TARG_NAME} )

endforeach()

