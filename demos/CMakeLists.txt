
add_custom_target( demos )

include(demo_app.cmake)
include(common/demo_common.cmake)

add_subdirectory( demo )
add_subdirectory( demo_vanilla )
add_subdirectory( measure_mips )