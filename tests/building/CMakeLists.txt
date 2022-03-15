

add_subdirectory( prefab  )
add_subdirectory( vanilla )

add_custom_target( tests-build )

add_dependencies( tests-build
    tests-build-vanilla
    tests-build-prefab
)