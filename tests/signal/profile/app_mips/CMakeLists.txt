cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(test_mips)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../../..)

include(${CMAKE_CURRENT_LIST_DIR}/../../../../examples/deps.cmake)

set(APP_HW_TARGET XK-VOICE-L71.xn)

set(AUTOGEN_OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/autogen")

set(NAME_MAP thread;isr)
# Exactly one custom filter (.pkl) may be listed alongside numeric sample rates.
# The .pkl file is expected to be in the ${CMAKE_CURRENT_LIST_DIR}/../../BasicMicArray/ directory
# Configs ending with _customfs correspond to the .pkl file based build.
#
# Note that the automated test (test_measure_mips.py) only profiles the default configs
# (the ones specified with samp_freq 16000/32000/48000)
# Support to specify a custom pkl file is added here and the expectation is
# for the user to run the <>_customfs.xe executable manually and check MIPS and
# memory impact.

# Replace good_3_stage_filter_int.pkl below with some other custom filter file. Compile and run manually to check MIPS impact
foreach(SAMP_FREQ   16000 32000 48000 "good_3_stage_filter_int.pkl")
    if (SAMP_FREQ MATCHES "\\.pkl$")
        # SAMP_FREQ specifying custom filter as .pkl value
        set(PKL_FILE "${CMAKE_CURRENT_LIST_DIR}/../../BasicMicArray/${SAMP_FREQ}")
        set(GEN_HDR  "${AUTOGEN_OUT_DIR}/custom_filter.h")

        add_custom_command(
            OUTPUT "${GEN_HDR}"
            COMMAND ${CMAKE_COMMAND} -E echo "Generating ${GEN_HDR} from ${PKL_FILE}"
            COMMAND python3 "${XMOS_SANDBOX_DIR}/lib_mic_array/python/combined.py"
                    "${PKL_FILE}" -fp "custom_filter" -fd "${AUTOGEN_OUT_DIR}"
            DEPENDS "${PKL_FILE}" "${XMOS_SANDBOX_DIR}/lib_mic_array/python/combined.py"
            WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
            COMMENT "Auto-generating custom_filter.h for ${PKL_FILE}"
            VERBATIM)

        # Tie the generation to a per-config target so it runs before build
        add_custom_target(gen_custom_filter_mips_test DEPENDS "${GEN_HDR}")
        set(USE_CUSTOM_FILT 1)
        set(APP_SAMP_FREQ 0)
        set(samp_freq_str "customfs")
    else()
        set(USE_CUSTOM_FILT 0)
        set(APP_SAMP_FREQ ${SAMP_FREQ})
        set(samp_freq_str "${SAMP_FREQ}fs")
    endif()
    foreach(N_MICS  1 2)
        foreach(USE_ISR   1 0)
            list(GET NAME_MAP ${USE_ISR} tmp)
            set(CONFIG "${N_MICS}mic_${tmp}_${samp_freq_str}")

            set(APP_COMPILER_FLAGS_${CONFIG}    -Os
                                                -g
                                                -report
                                                -mcmodel=large
                                                -DAPP_NAME="MIC_ARRAY_MEASURE_MIPS_${CONFIG}"
                                                -DMIC_ARRAY_CONFIG_USE_PDM_ISR=${USE_ISR}
                                                -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                                -DAPP_SAMP_FREQ=${APP_SAMP_FREQ}
                                                -DUSE_CUSTOM_FILTER=${USE_CUSTOM_FILT})
        endforeach()
    endforeach()
endforeach()

set(APP_INCLUDES    src src/mips/ ${AUTOGEN_OUT_DIR})

XMOS_REGISTER_APP()

foreach(target ${APP_BUILD_TARGETS})
    if (target MATCHES "customfs$")
        add_dependencies(${target} gen_custom_filter_mips_test)
    endif()
endforeach()
