
add_custom_target( tests-signal )


add_subdirectory( TwoStageDecimator )
add_subdirectory( BasicMicArray )

add_dependencies(tests tests-signal)

