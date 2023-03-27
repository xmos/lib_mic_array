// Copyright 2022 XMOS LIMITED.
// This Software is subject to the terms of the XMOS Public Licence: Version 1.

#ifndef PCAL6408A_H_
#define PCAL6408A_H_

// PCAL6408A I2C Address
#define PCAL6408A_I2C_DEVICE_ADDR 0x20

#define PCAL6408A_REG_IN_PORT           0x00  // Input Port                 
#define PCAL6408A_REG_OUT_PORT          0x01  // Output Port                
#define PCAL6408A_REG_POLARITY_INV      0x02  // Polarity Inversion         
#define PCAL6408A_REG_CONFIG            0x03  // Configuration              
#define PCAL6408A_REG_OUT_DRIVE_STR0    0x40  // Output Drive Strength 0    
#define PCAL6408A_REG_OUT_DRIVE_STR1    0x41  // Output Drive Strength 1    
#define PCAL6408A_REG_IN_LATCH          0x42  // Input Latch                
#define PCAL6408A_REG_PULL_UP_DOWN_EN   0x43  // Pull-up/pull-down enable   
#define PCAL6408A_REG_PULL_UP_DOWN_SEL  0x44  // Pull-up/pull-down selection
#define PCAL6408A_REG_INT_MASK          0x45  // Interrupt Mask             
#define PCAL6408A_REG_INT_STATUS        0x46  // Interrupt Status           
#define PCAL6408A_REG_OUT_PORT_CONFIG   0x4F  // Output Port Configuration  

#endif // PCAL6408_H_
