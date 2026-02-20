cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(test_ma)

set(XMOS_SANDBOX_DIR    ${CMAKE_CURRENT_LIST_DIR}/../../../..)

set(APP_DEPENDENT_MODULES   "lib_mic_array")

set(APP_HW_TARGET       XK-EVK-XU316)

set_property(DIRECTORY "${CMAKE_CURRENT_LIST_DIR}" PROPERTY CMAKE_CONFIGURE_DEPENDS
             "${CMAKE_CURRENT_LIST_DIR}/test_params.json")

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON N_MICS_LIST GET ${JSON_CONTENT} N_MICS)
string(JSON FRAME_SIZE_LIST GET ${JSON_CONTENT} FRAME_SIZE)
string(JSON USE_ISR_LIST GET ${JSON_CONTENT} USE_ISR)
string(JSON SAMP_FREQ_LIST GET ${JSON_CONTENT} SAMP_FREQ)

# Convert JSON lists to CMake lists
string(JSON NUM_N_MICS LENGTH ${N_MICS_LIST})
string(JSON NUM_FRAME_SIZE LENGTH ${FRAME_SIZE_LIST})
string(JSON NUM_USE_ISR LENGTH ${USE_ISR_LIST})
string(JSON NUM_SAMP_FREQ LENGTH ${SAMP_FREQ_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_N_MICS "${NUM_N_MICS} - 1")
math(EXPR NUM_FRAME_SIZE "${NUM_FRAME_SIZE} - 1")
math(EXPR NUM_USE_ISR "${NUM_USE_ISR} - 1")
math(EXPR NUM_SAMP_FREQ "${NUM_SAMP_FREQ} - 1")

# Count how many SAMP_FREQ entries are custom (.pkl)
set(CUSTOM_PKL_COUNT 0)
foreach(idx RANGE 0 ${NUM_SAMP_FREQ})
    string(JSON SF GET ${SAMP_FREQ_LIST} ${idx})
    if (SF MATCHES "\\.pkl$")
        math(EXPR CUSTOM_PKL_COUNT "${CUSTOM_PKL_COUNT} + 1")
    endif()
endforeach()

if (CUSTOM_PKL_COUNT GREATER 1)
    message(FATAL_ERROR "Only one custom filter (.pkl) in test_params.json is supported at a time. Found ${CUSTOM_PKL_COUNT}.")
endif()

set(AUTOGEN_OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/autogen")

foreach(l RANGE 0 ${NUM_SAMP_FREQ})
    string(JSON SAMP_FREQ GET ${SAMP_FREQ_LIST} ${l})
    if (SAMP_FREQ MATCHES "\\.pkl$")
        # SAMP_FREQ specifying custom filter as .pkl value
        set(PKL_FILE "${SAMP_FREQ}")
        set(GEN_HDR  "${AUTOGEN_OUT_DIR}/custom_filter.h")

        add_custom_command(
            OUTPUT "${GEN_HDR}"
            COMMAND ${CMAKE_COMMAND} -E echo "Generating ${GEN_HDR} from ${PKL_FILE}"
            COMMAND python3 "${XMOS_SANDBOX_DIR}/lib_mic_array/python/combined.py"
                    "${PKL_FILE}" -fp "custom_filter" -fd "${AUTOGEN_OUT_DIR}"
            DEPENDS "${PKL_FILE}" "${XMOS_SANDBOX_DIR}/lib_mic_array/python/combined.py" "${CMAKE_CURRENT_LIST_DIR}/test_params.json"
            WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
            COMMENT "Auto-generating custom_filter.h for ${PKL_FILE}"
            VERBATIM)

        # Tie the generation to a per-config target so it runs before build
        add_custom_target(gen_custom_filter DEPENDS "${GEN_HDR}")
        set(USE_CUSTOM_FILT 1)
        set(APP_SAMP_FREQ 0)
        set(samp_freq_str "customfs") # configs ending with _customfs correspond to the pkl file
    else()
        set(USE_CUSTOM_FILT 0)
        set(APP_SAMP_FREQ ${SAMP_FREQ})
        set(samp_freq_str "${SAMP_FREQ}fs")
    endif()

    foreach(i RANGE 0 ${NUM_N_MICS})
        string(JSON N_MICS GET ${N_MICS_LIST} ${i})
        foreach(j RANGE 0 ${NUM_FRAME_SIZE})
            string(JSON FRAME_SIZE GET ${FRAME_SIZE_LIST} ${j})
            foreach(k RANGE 0 ${NUM_USE_ISR})
                string(JSON USE_ISR GET ${USE_ISR_LIST} ${k})
                set(CONFIG "${N_MICS}ch_${FRAME_SIZE}smp_${USE_ISR}isr_${samp_freq_str}")

                message(${CONFIG})
                set(APP_COMPILER_FLAGS_${CONFIG}    -O2
                                                    -g
                                                    -report
                                                    -mcmodel=large
                                                    -Wno-xcore-fptrgroup
                                                    -Wno-unknown-pragmas
                                                    -Wno-format
                                                    -DMIC_ARRAY_CONFIG_USE_PDM_ISR=${USE_ISR}
                                                    -DMIC_ARRAY_CONFIG_SAMPLES_PER_FRAME=${FRAME_SIZE}
                                                    -DMIC_ARRAY_CONFIG_MIC_COUNT=${N_MICS}
                                                    -DMIC_ARRAY_CONFIG_MIC_IN_COUNT=${N_MICS}
                                                    -DMIC_ARRAY_CONFIG_USE_DC_ELIMINATION=0
                                                    -DAPP_SAMP_FREQ=${APP_SAMP_FREQ}
                                                    -DUSE_CUSTOM_FILTER=${USE_CUSTOM_FILT}
                                                    )
            endforeach()
        endforeach()
    endforeach()
endforeach()

set(APP_INCLUDES src ${AUTOGEN_OUT_DIR})

XMOS_REGISTER_APP()

foreach(target ${APP_BUILD_TARGETS})
    if (target MATCHES "customfs$")
        add_dependencies(${target} gen_custom_filter)
    endif()
endforeach()
