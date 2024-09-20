// Copyright 2023 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#pragma once

#define AUDIO_BUFFER_SAMPLES  ((unsigned)(MIC_ARRAY_CONFIG_SAMPLES_PER_FRAME * 1.2))
#define APP_I2S_AUDIO_SAMPLE_RATE       16000
#define MIC_ARRAY_CLK1                  XS1_CLKBLK_1
#define MIC_ARRAY_CLK2                  XS1_CLKBLK_2

// NOTE: Tile 1 might still have issues with channels other than the first.
#define MIC_ARRAY_TILE                  0

// When using MIC_ARRAY_TILE == 0, A single button on X0D12, J12 - Pin2 is used (pullup enabled)
#define USE_BUTTONS                     1

// Indicates the number of subtasks to perform the decimation process on.
#define NUM_DECIMATOR_SUBTASKS          2

// Specifies whether to include burn() tasks on remaining cores for testing purposes.
#define ENABLE_BURN_MIPS                0

#if MIC_ARRAY_TILE == 0

// NOTE: When using Tile 0, the VocalSorcery adapter card should be fitted
// __with__ the jumper applied. The screw terminal connection does not
// need to be connected to anything.
// ALSO NOTE: Depending on configuration, one or more of the following
// board interfaces will be unavailable for application use: push buttons,
// LEDs, and USB.

// X0D00, J14 - Pin 2
#define PORT_PDM_CLK                    XS1_PORT_1A

#if MIC_ARRAY_CONFIG_MIC_COUNT == 8
// Either of the following ports may be used with VocalSorcery adapter card.

// X0D14,X0D15,X0D20,X0D21, J14 - Pin 3,5,12,14
//#define PORT_PDM_DATA                 XS1_PORT_4C

// X0D16..X0D19, J14 - Pin 6,7,10,11
#define PORT_PDM_DATA                   XS1_PORT_4D

#elif MIC_ARRAY_CONFIG_MIC_COUNT == 16
// X0D14..X0D21 | J14 - Pin 3,5,12,14 and Pin 6,7,10,11
#define PORT_PDM_DATA                   XS1_PORT_8B

#endif // MIC_ARRAY_CONFIG_MIC_COUNT

#if PORT_PDM_DATA == XS1_PORT_4C
// X1D09
#define PORT_CODEC_RST_N                XS1_PORT_4A
#endif

// NOTE: This conditional only works if the other 4 data lines are not connected.
//#if USE_BUTTONS && (PORT_PDM_DATA == XS1_PORT_4D || PORT_PDM_DATA == XS1_PORT_8B)
// X0D12, J12 - Pin2
#define ALTERNATE_BUTTON                XS1_PORT_1E
//#endif

#else // MIC_ARRAY_TILE == 0

// NOTE: When using Tile 1, the VocalSorcery adapter card should be fitted
// __without__ the jumper applied and the screw terminal connection to be directly
// connected to the CODEC_RST_N test point.
// ALSO NOTE: X1D09 (last mic input) CANNOT BE USED! Signal is electrically
// connected to CODEC_RST_N (and associated pin on J10 is 3v3). This means
// there are only 14 usable MICs of the 16 for this configuration.

// X1D36, J10 - Pin 2
#define PORT_PDM_CLK                    XS1_PORT_1M

#if MIC_ARRAY_CONFIG_MIC_COUNT == 8
// Either of the following ports may be used with VocalSorcery adapter card.

// X1D02,X1D03,X1D08,X1D09 | J10 - Pin 3,5,12
//#define PORT_PDM_DATA                 XS1_PORT_4A

// X1D04..X1D07 | J10 - Pin 6,7,10,11
#define PORT_PDM_DATA                   XS1_PORT_4B

#if PORT_PDM_DATA == XS1_PORT_4B
#define PORT_CODEC_RST_N                XS1_PORT_4A
#else
// X1D38 | J10 - Pin 15
// Used with 3k3 resistor to drive CODEC_RST_N high
#define PORT_CODEC_RST_N                XS1_PORT_1O
#endif

#elif MIC_ARRAY_CONFIG_MIC_COUNT == 16
// X1D02..X1D09 | J10 - Pin 3,5,12 and Pin 6,7,10,11
#define PORT_PDM_DATA                   XS1_PORT_8B

// X1D38 | J10 - Pin 15
// Used with 3k3 resistor to drive CODEC_RST_N high
#define PORT_CODEC_RST_N                XS1_PORT_1O

#endif // MIC_ARRAY_CONFIG_MIC_COUNT


// Configuration checks
#if MIC_ARRAY_CONFIG_MIC_COUNT > 8 && NUM_DECIMATOR_SUBTASKS < 2
#error "NUM_DECIMATOR_SUBTASKS: Unsupported value"
#endif

#if !(MIC_ARRAY_CONFIG_MIC_COUNT == 8 || MIC_ARRAY_CONFIG_MIC_COUNT == 16)
#error "MIC_ARRAY_CONFIG_MIC_COUNT: Unsupported value"
#endif

#if NUM_DECIMATOR_SUBTASKS > MIC_ARRAY_CONFIG_MIC_COUNT
#error "NUM_DECIMATOR_SUBTASKS must be less than or equal to MIC_ARRAY_CONFIG_MIC_COUNT"
#endif

#endif

#if MIC_ARRAY_CONFIG_USE_DDR != 1
#error "MIC_ARRAY_CONFIG_USE_DDR: This application only supports DDR"
#endif
