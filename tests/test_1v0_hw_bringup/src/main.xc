#include <xs1.h>
#include <platform.h>
#include <limits.h>
#include "debug_print.h"
#include "xassert.h"
#include "otp_board_info.h"
#include "ethernet.h"
#include "icmp.h"
#include "smi.h"
#include "i2c.h"
#include "i2s.h"
#include "sine.h"

// PDM clock and data
out port p_pdm_clk              = on tile[0]: XS1_PORT_1E;
in buffered port:8 p_pdm_mics   = on tile[0]: XS1_PORT_8B;
in port p_mclk_in0              = on tile[0]: XS1_PORT_1F;
// LEDs
out port p_led0to7              = on tile[0]: XS1_PORT_8C;
out port p_led8                 = on tile[0]: XS1_PORT_1K;
out port p_led9                 = on tile[0]: XS1_PORT_1L;
out port p_led10to12            = on tile[0]: XS1_PORT_8D;    
out port p_leds_oen             = on tile[0]: XS1_PORT_1P;
// Buttons
in port p_buttons               = on tile[0]: XS1_PORT_4A;

// Ethernet MII
port p_eth_rxclk  = on tile[1]: XS1_PORT_1A;
port p_eth_rxd    = on tile[1]: XS1_PORT_4A;
port p_eth_txd    = on tile[1]: XS1_PORT_4B;
port p_eth_rxdv   = on tile[1]: XS1_PORT_1C;
port p_eth_txen   = on tile[1]: XS1_PORT_1D;
port p_eth_txclk  = on tile[1]: XS1_PORT_1B;
port p_eth_rxerr  = on tile[1]: XS1_PORT_1K;
port p_eth_dummy  = on tile[1]: XS1_PORT_8C;
clock eth_rxclk   = on tile[1]: XS1_CLKBLK_1;
clock eth_txclk   = on tile[1]: XS1_CLKBLK_2;
// SMI
port p_smi          = on tile[1]: XS1_PORT_4C; // Bit 0: MDC, Bit 1: MDIO
// OTP
otp_ports_t otp_ports = on tile[1]: OTP_PORTS_INITIALIZER;

// I2S
out buffered port:32 p_i2s_dout[1]  = on tile[1]: {XS1_PORT_1P};
in port p_mclk_in1                  = on tile[1]: XS1_PORT_1O;
out buffered port:32 p_bclk         = on tile[1]: XS1_PORT_1M;
out buffered port:32 p_lrclk        = on tile[1]: XS1_PORT_1N;
out port p_pll_sync                 = on tile[1]: XS1_PORT_4D;
port p_i2c                          = on tile[1]: XS1_PORT_4E; // Bit 0: SCLK, Bit 1: SDA
port p_rst_shared                   = on tile[1]: XS1_PORT_4F; // Bit 0: DAC_RST_N, Bit 1: ETH_RST_N
clock mclk                          = on tile[1]: XS1_CLKBLK_3;
clock bclk                          = on tile[1]: XS1_CLKBLK_4;

enum buttons
{
  BUTTON_A=1<<0,
  BUTTON_B=1<<1,
  BUTTON_C=1<<2,
  BUTTON_D=1<<3
};

#define BUTTON_PRESSED(but_mask, old_val, new_val) (((old_val) & (but_mask)) == (but_mask) && ((new_val) & (but_mask)) == 0)
#define BUTTON_DEBOUNCE_DELAY (20000000)
#define LED_ON 0xFFFF
void buttons_and_leds(void)
{
  int button_val;
  int buttons_active = 1;
  unsigned buttons_timeout;
  unsigned time;
  unsigned glow_time;
  timer button_tmr;
  timer leds_tmr;
  timer glow_tmr;
  const int pwm_cycle = 100000; // The period in 100Mhz timer ticks of the pwm
  const int pwm_res = 100; // The resolution of the pwm
  const int pwm_delay = pwm_cycle / pwm_res; // The period between updates to the port output
  int count = 0; // The count that tracks where we are in the pwm cycle

  int period = 1 * 1000 * 1000 * 100 * 15; // period from off to on = 1s;
  unsigned res = 300;                  // increment the brightness in this
                                      // number of steps
  int delay = period / res;           // how long to wait between updates
  // int delay = 1 * 1000 * 1000 * 100;
  int dir = 1;
  int on_led = 0;

  p_leds_oen <: 1;
  p_leds_oen <: 0;
  // This array stores the pwm levels for the leds
  int level[13] = {0, 0,  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

  for (int i=0; i < 13; i++) {
    level[i] = level[i] / (0xFFFF / pwm_res);
  }

  p_buttons :> button_val;
  leds_tmr :> time;
  glow_tmr :> glow_time;

  while (1) {
    select
    {
      case buttons_active => p_buttons when pinsneq(button_val) :> unsigned new_button_val:

        if BUTTON_PRESSED(BUTTON_A, button_val, new_button_val) {
          debug_printf("Button A\n");
          buttons_active = 0;
        }
        if BUTTON_PRESSED(BUTTON_B, button_val, new_button_val) {
          debug_printf("Button B\n");
          buttons_active = 0;
        }
        if BUTTON_PRESSED(BUTTON_C, button_val, new_button_val) {
          debug_printf("Button C\n");
          buttons_active = 0;
        }
        if BUTTON_PRESSED(BUTTON_D, button_val, new_button_val) {
          debug_printf("Button D\n");
          buttons_active = 0;
        }
        if (!buttons_active)
        {
          button_tmr :> buttons_timeout;
          buttons_timeout += BUTTON_DEBOUNCE_DELAY;
        }
        button_val = new_button_val;
        break;
      case !buttons_active => button_tmr when timerafter(buttons_timeout) :> void:
        buttons_active = 1;
        p_buttons :> button_val;
        break;
      case leds_tmr when timerafter(time) :> void: {
        count++;
        if (count == pwm_res) {
          count = 0;
        }
        // Create the output for this phase in the pwm
        unsigned data = 0xFFFFFFFF;
        for (int led = 0; led < 13; led++) {
          // If the led level is higher than the current
          // phase of the pwm then set the bit (i.e. drive the led)
          if (pwm_res - count < level[led]) {
            data &= ~(1 << led);
          }
        }
        // Output the combined led data
        p_led0to7 <: data;
        p_led8 <: (data >> 8) & 1;
        p_led9 <: (data >> 9) & 1;
        p_led10to12 <: (data >> 10) & 0x7;
        // Set up the next event
        leds_tmr :> time;
        time += pwm_delay;
        break;
      }
      case glow_tmr when timerafter(glow_time) :> void:
        for (int i=0; i < 12; i++) {
          unsigned lvl = 0;
          if (on_led == i) {
            lvl = 0xFFFFFFFF;
          }
          if (i == 11 && on_led == 0) {
            lvl = 0x3FFF;
          }
          else if (i == 10 && on_led == 0) {
            lvl = 0x7FF;
          }
          else if (on_led-1 == i) {
            lvl = 0x3FFF;
          }
          else if (on_led-2 == i) {
            lvl = 0x7FF;
          }
          // increase the output level of the led
          level[i] = lvl / (0xFFFF / pwm_res);
        }
        on_led++;
        if (on_led >= 12) {
          on_led = 0;
        }

        // update the timestamp for the next timeout
        glow_time += delay;
        break;
    }
  }
}

#define OUTPUT_SAMPLE_RATE 48000
#define MASTER_CLOCK_FREQUENCY 24576000

[[distributable]]
void i2s_handler(server i2s_callback_if i2s,
                 client i2c_master_if i2c)
{
  int sine_count[2] = {0, 0};
  int sine_inc[2] = {0x080, 0x080};

  p_rst_shared <: 0xF;

  i2c_regop_res_t res;
  int i = 0x4A;
  uint8_t data = i2c.read_reg(i, 1, res);
  debug_printf("I2C ID: %x, res: %d\n", data, res);

  data = i2c.read_reg(i, 0x02, res);
  data |= 1;
  res = i2c.write_reg(i, 0x02, data); // Power down

  // Setting MCLKDIV2 high if using 24.576MHz.
  data = i2c.read_reg(i, 0x03, res);
  data |= 1;
  res = i2c.write_reg(i, 0x03, data);

  data = 0b01110000;
  res = i2c.write_reg(i, 0x10, data);

  data = i2c.read_reg(i, 0x02, res);
  data &= ~1;
  res = i2c.write_reg(i, 0x02, data); // Power up


  while (1) {
    select {
    case i2s.init(i2s_config_t &?i2s_config, tdm_config_t &?tdm_config):
      /* Configure the I2S bus */
      i2s_config.mode = I2S_MODE_I2S;
      i2s_config.mclk_bclk_ratio = (MASTER_CLOCK_FREQUENCY/OUTPUT_SAMPLE_RATE)/64;

      break;

    case i2s.restart_check() -> i2s_restart_t restart:
      // This application never restarts the I2S bus
      restart = I2S_NO_RESTART;
      break;

    case i2s.receive(size_t index, int32_t sample):
      break;

    case i2s.send(size_t index) -> int32_t sample:
      sample = i2s_sine[sine_count[index]>>8];
      sine_count[index] += sine_inc[index];
      if (sine_count[index] >= 100 * 256) {
          sine_count[index] -= 100 * 256;
      }
      break;
    }
  }
};

enum eth_clients {
  ETH_TO_ICMP,
  NUM_ETH_CLIENTS
};

enum cfg_clients {
  CFG_TO_ICMP,
  CFG_TO_PHY_DRIVER,
  NUM_CFG_CLIENTS
};

[[combinable]]
void lan8710a_phy_driver(client interface smi_if smi,
                         client interface ethernet_cfg_if eth) {
  ethernet_link_state_t link_state = ETHERNET_LINK_DOWN;
  ethernet_speed_t link_speed = LINK_100_MBPS_FULL_DUPLEX;
  const int link_poll_period_ms = 1000;
  const int phy_address = 0x0;
  timer tmr;
  int t;
  tmr :> t;

  while (smi_phy_is_powered_down(smi, phy_address));
  smi_configure(smi, phy_address, LINK_100_MBPS_FULL_DUPLEX, SMI_ENABLE_AUTONEG);

  while (1) {
    select {
    case tmr when timerafter(t) :> t:
      ethernet_link_state_t new_state = smi_get_link_state(smi, phy_address);
      // Read LAN8710A status register bit 2 to get the current link speed
      if ((new_state == ETHERNET_LINK_UP) &&
         ((smi.read_reg(phy_address, 0x1F) >> 2) & 1)) {
        link_speed = LINK_10_MBPS_FULL_DUPLEX;
      }
      else {
        link_speed = LINK_100_MBPS_FULL_DUPLEX;
      }
      if (new_state != link_state) {
        link_state = new_state;
        debug_printf("State %d\n", new_state);
        eth.set_link_state(0, new_state, link_speed);
      }
      t += link_poll_period_ms * XS1_TIMER_KHZ;
      break;
    }
  }
}


static unsigned char ip_address[4] = {192, 168, 0, 33};

int main(void)
{
  ethernet_cfg_if i_cfg[NUM_CFG_CLIENTS];
  ethernet_rx_if i_rx[NUM_ETH_CLIENTS];
  ethernet_tx_if i_tx[NUM_ETH_CLIENTS];
  smi_if i_smi;
  i2s_callback_if i_i2s;
  i2c_master_if i_i2c[1];

  par {
    on tile[0]: buttons_and_leds();

    on tile[1]: {
      configure_clock_src(mclk, p_mclk_in1);
      start_clock(mclk);
      i2s_master(i_i2s, p_i2s_dout, 1, null, 0, p_bclk, p_lrclk, bclk, mclk);
    }

    on tile[1]: [[distribute]] i2c_master_single_port(i_i2c, 1, p_i2c, 100, 0, 1, 0);
    on tile[1]: [[distribute]] i2s_handler(i_i2s, i_i2c[0]);

    on tile[1]: mii_ethernet_mac(i_cfg, NUM_CFG_CLIENTS,
                                 i_rx, NUM_ETH_CLIENTS,
                                 i_tx, NUM_ETH_CLIENTS,
                                 p_eth_rxclk, p_eth_rxerr,
                                 p_eth_rxd, p_eth_rxdv,
                                 p_eth_txclk, p_eth_txen, p_eth_txd,
                                 p_eth_dummy,
                                 eth_rxclk, eth_txclk,
                                 1600);

    on tile[1]: lan8710a_phy_driver(i_smi, i_cfg[CFG_TO_PHY_DRIVER]);

    on tile[1]: smi_singleport(i_smi, p_smi, 1, 0);

    on tile[1]: icmp_server(i_cfg[CFG_TO_ICMP],
                            i_rx[ETH_TO_ICMP], i_tx[ETH_TO_ICMP],
                            ip_address, otp_ports);
  }
  return 0;
}