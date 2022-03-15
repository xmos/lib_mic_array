
## Some of the test applications require the Unity test framework
include(FetchContent)
FetchContent_Declare(
  unity
  GIT_REPOSITORY https://github.com/ThrowTheSwitch/Unity.git
  GIT_TAG        v2.5.2
  GIT_SHALLOW    TRUE
  SOURCE_DIR     unity
)

# Using FetchContent_MakeAvailable( unity ) will clone the Unity repo and 
# call add_subdirectory() on it, using the CMakeLists.txt in the repo.
# However, that didn't immediately work. Rather than investigate and fix that,
# I've just used a custom CMakeLists.txt
# add_subdirectory( etc/unity )

add_subdirectory( building )


add_custom_target( tests )
add_dependencies( tests
    tests-build
)