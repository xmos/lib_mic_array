

FetchContent_GetProperties( unity )
if( NOT unity_POPULATED )
  FetchContent_Populate( unity )
endif()

add_library( unity )

target_sources( unity
  PUBLIC
    ${unity_SOURCE_DIR}/src/unity.c
    ${unity_SOURCE_DIR}/extras/fixture/src/unity_fixture.c
    ${unity_SOURCE_DIR}/extras/memory/src/unity_memory.c
)

target_include_directories( unity 
  PUBLIC 
    ${unity_SOURCE_DIR}/src
    ${unity_SOURCE_DIR}/extras/fixture/src/
    ${unity_SOURCE_DIR}/extras/memory/src/
)

target_compile_definitions( unity
  PRIVATE
    "UNITY_INCLUDE_CONFIG_H"
)

target_compile_options( unity
  PRIVATE
    -Wno-xcore-fptrgroup
)