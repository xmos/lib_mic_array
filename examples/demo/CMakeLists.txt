
set( APP_NAME demo )

set( TARGET_XN   XVF3610_Q60A.xn )

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

set( NAME_MAP thread;isr )

foreach( N_MICS  1 2 )
  foreach( USE_ISR   1 0 )

    list( GET NAME_MAP ${USE_ISR} tmp )
    set( TARG_NAME "${APP_NAME}_${N_MICS}mic_${tmp}" )

    unset(TARG_FLAGS)
    list( APPEND TARG_FLAGS 
            "-DN_MICS=${N_MICS}"
            "-DAPP_USE_PDM_RX_ISR=${USE_ISR}" )

    make_demo_app_target( ${TARG_NAME} "${APP_SOURCES}" "${APP_INCLUDES}" "${TARG_FLAGS}" )
    
    add_dependencies( demos  ${TARG_NAME} )

  endforeach()
endforeach()
