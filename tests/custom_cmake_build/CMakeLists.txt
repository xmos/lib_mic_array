
add_custom_target( tests-build )

add_subdirectory( prefab  )
add_subdirectory( vanilla )



add_dependencies( tests tests-build )