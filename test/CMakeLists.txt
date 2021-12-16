
set(APP_NAME test)

set(HIL_DIR "${XCORE_SDK_PATH}/modules/hil")


#********************************
# Gather test sources
#********************************
include("${CMAKE_SOURCE_DIR}/lib_mic_array/lib_mic_array.cmake")

#**********************
# Build flags
#**********************

add_executable( ${APP_NAME} )


set(BUILD_FLAGS
  "${CMAKE_SOURCE_DIR}/XVF3610_Q60A.xn"
  "-fxscope"
  "-mcmodel=large"
  "-Wno-xcore-fptrgroup"
  "-Wno-unknown-pragmas"
  "-report"
  "-g"
  "-O2"
  "-Wm,--map,memory.map"
)

target_link_options(${APP_NAME} PRIVATE ${BUILD_FLAGS} -w)
set_target_properties(${APP_NAME} PROPERTIES OUTPUT_NAME ${APP_NAME}.xe)

target_compile_options(${APP_NAME} PRIVATE ${BUILD_FLAGS})

#**********************
# includes
#**********************

set( APP_INCLUDES  "src" )

#**********************
# sources
#**********************

file( GLOB_RECURSE    SOURCES_C    "src/*.c"    )
file( GLOB_RECURSE    SOURCES_XC   "src/*.xc"   )
file( GLOB_RECURSE    SOURCES_CPP  "src/*.cpp"  )
file( GLOB_RECURSE    SOURCES_ASM  "src/*.S"    )

unset(APP_SOURCES)
list( APPEND  APP_SOURCES  ${SOURCES_C}
                           ${SOURCES_XC}
                           ${SOURCES_CPP}
                           ${SOURCES_ASM}       )

target_sources(${APP_NAME} 
  PRIVATE ${MIC_ARRAY_SOURCES}
  PRIVATE ${APP_SOURCES}
  PRIVATE ${LIB_XS3_MATH_SOURCES}
)

set_source_files_properties( ${SOURCES_XC}  PROPERTIES LANGUAGE C ) 

target_include_directories(${APP_NAME}
  PRIVATE ${MIC_ARRAY_INCLUDES}
  PRIVATE ${APP_INCLUDES}
  PRIVATE ${LIB_XS3_MATH_INCLUDES}
)


#**********************
# run
#**********************

add_custom_target( run
  COMMAND xrun --xscope ${APP_NAME}.xe
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} )

add_dependencies( run ${APP_NAME} test )


#**********************
# debug
#**********************

add_custom_target( debug
  COMMAND xgdb --ex=\"connect --xscope\" --ex=run ${APP_NAME}.xe
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} )

add_dependencies( debug ${APP_NAME} test )