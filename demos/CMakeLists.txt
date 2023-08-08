

CPMAddPackage(
  NAME fwk_io
  GIT_REPOSITORY https://github.com/xmos/fwk_io
  GIT_TAG        290c3ec127af4a4cdfdea482d168c16a5b6f4bc7
  GIT_SUBMODULES ""
  DOWNLOAD_ONLY  TRUE
)


add_subdirectory( ${fwk_io_SOURCE_DIR}/modules/i2c ${fwk_io_BINARY_DIR}/modules/i2c EXCLUDE_FROM_ALL)
add_subdirectory( ${fwk_io_SOURCE_DIR}/modules/i2s ${fwk_io_BINARY_DIR}/modules/i2s EXCLUDE_FROM_ALL)


add_custom_target( demos )

include(../cmake/demo_app.cmake)
include(../cmake/demo_common.cmake)

add_subdirectory( demo )
add_subdirectory( demo_vanilla )
add_subdirectory( demo_par_decimator )
add_subdirectory( measure_mips )