#ifndef MIC_ARRAY_BOARD_SUPPORT_H_
#define MIC_ARRAY_BOARD_SUPPORT_H_

#define MAX_LED_BRIGHTNESS 256

#define DEFAULT_INIT {XS1_PORT_8C, XS1_PORT_1K, XS1_PORT_1L, XS1_PORT_8D, XS1_PORT_1P}

typedef enum {
    BUTTON_PRESSED  = 0,
    BUTTON_RELEASED = 1
} e_button_state;

typedef struct {
    out port p_led0to7;
    out port p_led8;
    out port p_led9;
    out port p_led10to12;
    out port p_leds_oen;
} p_leds;

interface led_button_if {
  void set_led_brightness(unsigned led, unsigned brightness);
  [[notification]] slave void button_event(void);
  [[clears_notification]] void get_button_event(unsigned &button, e_button_state &pressed);
};

void button_and_led_server(server interface led_button_if lb, p_leds &leds, in port p_buttons);


#endif /* MIC_ARRAY_BOARD_SUPPORT_H_ */
