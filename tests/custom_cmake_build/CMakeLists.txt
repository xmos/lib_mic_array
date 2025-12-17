
add_custom_target( tests-build )

add_subdirectory( default )



add_dependencies( tests tests-build )
