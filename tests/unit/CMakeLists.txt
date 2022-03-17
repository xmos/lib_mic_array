

add_subdirectory( dcoe  )
add_subdirectory( frame_transfer )

add_custom_target( tests-unit )

# add_dependencies( tests-build
#     tests-unit-dcoe
#     tests-unit-frame_transfer
# )