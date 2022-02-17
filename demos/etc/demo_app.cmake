
macro( make_demo_app_target 
          TARGET_NAME 
          TARGET_SOURCE_FILES 
          TARGET_INCLUDE_PATHS 
          EXTRA_BUILD_FLAGS )

    add_executable( ${TARGET_NAME} )

    set(BUILD_FLAGS
        "${CMAKE_SOURCE_DIR}/XVF3610_Q60A.xn"
        "-fxscope"
        "-mcmodel=large"
        "-Wno-xcore-fptrgroup"
        "-Wno-unknown-pragmas"
        "-report"
        "-g"
        "-O2"
        "-Wm,--map,memory.map"
        "-DAPP_NAME=\"${TARGET_NAME}\""
    )

    target_link_options( ${TARGET_NAME} PRIVATE 
            ${BUILD_FLAGS} ${EXTRA_BUILD_FLAGS} )

    set_target_properties( ${TARGET_NAME} PROPERTIES 
                            OUTPUT_NAME ${TARGET_NAME}.xe )

    target_compile_options( ${TARGET_NAME} PRIVATE
            ${BUILD_FLAGS} ${EXTRA_BUILD_FLAGS} )

    target_sources( ${TARGET_NAME} PRIVATE ${TARGET_SOURCE_FILES} )

    # set_source_file_properties( ${SOURCES_XC} PROPERTIES LANGUAGE C )

    target_include_directories( ${TARGET_NAME} PRIVATE ${TARGET_INCLUDE_PATHS} )

    target_link_libraries( ${TARGET_NAME} lib_xs3_math lib_i2c lib_i2s)

    install( TARGETS ${TARGET_NAME} )

endmacro()