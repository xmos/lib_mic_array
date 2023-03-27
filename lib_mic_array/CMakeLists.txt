set(MIC_ARRAY_PATH ${CMAKE_CURRENT_LIST_DIR})

## Source files
file( GLOB_RECURSE    MIC_ARRAY_C_SOURCES       ${MIC_ARRAY_PATH}/src/*.c   )
file( GLOB_RECURSE    MIC_ARRAY_XC_SOURCES      ${MIC_ARRAY_PATH}/src/*.xc  )
file( GLOB_RECURSE    MIC_ARRAY_CPP_SOURCES     ${MIC_ARRAY_PATH}/src/*.cpp )
file( GLOB_RECURSE    MIC_ARRAY_ASM_SOURCES     ${MIC_ARRAY_PATH}/src/*.S   )

## Compile flags
unset(MIC_ARRAY_COMPILE_FLAGS)
list( APPEND  MIC_ARRAY_COMPILE_FLAGS     
              -Wno-unused-variable 
              -Wno-missing-braces
              -Wno-xcore-fptrgroup
              -O2
)

# Includes
set( MIC_ARRAY_INCLUDES     ${MIC_ARRAY_PATH}/api           )

unset(MIC_ARRAY_SOURCES)
list( APPEND  MIC_ARRAY_SOURCES   ${MIC_ARRAY_C_SOURCES} 
                                  ${MIC_ARRAY_XC_SOURCES}  
                                  ${MIC_ARRAY_CPP_SOURCES} 
                                  ${MIC_ARRAY_ASM_SOURCES} )

set_source_files_properties( ${MIC_ARRAY_XC_SOURCES}  PROPERTIES LANGUAGE C   ) 

## Apply compile flags
foreach(COMPILE_FLAG ${MIC_ARRAY_COMPILE_FLAGS})
  set_source_files_properties( ${MIC_ARRAY_SOURCES} 
        PROPERTIES COMPILE_FLAGS ${COMPILE_FLAG}) 
endforeach()


add_library(lib_mic_array STATIC)

target_sources(lib_mic_array
    PRIVATE ${MIC_ARRAY_SOURCES}
)

target_include_directories(lib_mic_array
    PUBLIC ${MIC_ARRAY_INCLUDES}
)

target_compile_options(lib_mic_array
    PRIVATE ${MIC_ARRAY_COMPILE_FLAGS}
)

target_link_libraries(lib_mic_array
    PUBLIC
        lib_xcore_math
)
