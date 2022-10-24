

## Some of the test applications require the Unity test framework
CPMAddPackage(
  NAME unity
  GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
  GIT_TAG        v2.5.2
  GIT_SHALLOW    TRUE
  DOWNLOAD_ONLY  TRUE
)

add_custom_target( tests )


# The CMakeLists that comes with the Unity repo isn't suitable for our needs.
add_subdirectory( ../cmake/unity ${unity_BINARY_DIR} )

add_subdirectory( building )
add_subdirectory( unit )
add_subdirectory( signal )
add_subdirectory( legacy )
add_subdirectory( legacy_vanilla )