
set(APP_NAME demo_vanilla)

#********************************
# Gather lib sources
#********************************
include("${CMAKE_SOURCE_DIR}/lib_mic_array/lib_mic_array.cmake")

#**********************
# Build flags
#**********************

set(EXTRA_BUILD_FLAGS
  "-DMIC_ARRAY_CONFIG_MCLK_FREQ=24576000"
  "-DMIC_ARRAY_CONFIG_PDM_FREQ=3072000"
  "-DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=16"
)


#**********************
# includes
#**********************

set( APP_INCLUDES  "src" )
list( APPEND  APP_INCLUDES ${MIC_ARRAY_INCLUDES} ${DEMO_COMMON_INCLUDES} )
list( APPEND  APP_INCLUDES "${CMAKE_SOURCE_DIR}/etc/vanilla" )

#**********************
# sources
#**********************

file( GLOB_RECURSE APP_SOURCES "src/*.c" "src/*.xc" "src/*.cpp" "src/*.S"   )

list( APPEND  APP_SOURCES  ${MIC_ARRAY_SOURCES} ${DEMO_COMMON_SOURCES} )
list( APPEND  APP_SOURCES  "${CMAKE_SOURCE_DIR}/etc/vanilla/mic_array_vanilla.cpp" )

#**********************
# create targets
#**********************

foreach( N_MICS  1 2 )

  set( TARG_NAME "${APP_NAME}_${N_MICS}mic" )

  set(TARG_FLAGS ${EXTRA_BUILD_FLAGS})
  list( APPEND TARG_FLAGS "-DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}" )

  make_demo_app_target( ${TARG_NAME} "${APP_SOURCES}" "${APP_INCLUDES}" "${TARG_FLAGS}" )

endforeach()

