#include <xs1.h>
#include "mic_array_board_support.h"
#include <stdio.h>

#define LED_COUNT 13
#define LED_MAX_COUNT (0xfffff)

void button_and_led_server(server interface led_button_if lb, p_leds &leds, in port p_buttons){

    e_button_state latest_button_pressed;
    unsigned latest_button_id;

    leds.p_leds_oen <: 1;
    leds.p_leds_oen <: 0;

    unsigned led_brightness[LED_COUNT] = {0};
    timer t;
    unsigned time;
    unsigned start_of_time;
    t :> start_of_time;
    t :> time;

    unsigned button_val;
    p_buttons :> button_val;
    while(1){
#pragma ordered
        select {
        case lb.set_led_brightness(unsigned led, unsigned brightness):{
            led_brightness[led] = brightness;
            break;
        }
        case lb.get_button_event(unsigned &button, e_button_state &pressed):{
            button = latest_button_id;
            pressed = latest_button_pressed;
            break;
        }
        case p_buttons when pinsneq(button_val):> unsigned new_button_val:{
#define REPS 512
            unsigned button_count[4] = {0};
            unsigned diff = button_val^new_button_val;
            for(unsigned i=0;i<4;i++)
                button_count[i] += ((diff>>i)&1);
            for(unsigned i=0;i<REPS;i++){
                p_buttons :> new_button_val;
                diff = button_val^new_button_val;
                for(unsigned i=0;i<4;i++)
                    button_count[i] += ((diff>>i)&1);
            }
            for(unsigned i=0;i<4;i++){
                button_val ^= ((1<<i)*(button_count[i]>(REPS/2)));
                if( button_count[i]>(REPS/2)){
                    latest_button_id = i;
                    latest_button_pressed = (button_val>>i)&1;
                    lb.button_event();
                }
            }
            break;
        }

        case t:> unsigned now :{
            unsigned elapsed = (now-start_of_time)&LED_MAX_COUNT;
            elapsed>>=(20-8);
            unsigned d=0;
            for(unsigned i=0;i<8;i++)
                d=(d>>1)+(0x80*(led_brightness[i]<=elapsed));
            leds.p_led0to7 <: d;
            leds.p_led8 <: (led_brightness[8]<=elapsed);
            leds.p_led9 <: (led_brightness[9]<=elapsed);
            d=0;
            for(unsigned i=10;i<13;i++)
                d=(d>>1)+(0x4*(led_brightness[i]<=elapsed));
            leds.p_led10to12 <: d;
            break;
        }
        /*
        default:{
            unsigned now;
            t:> now;
            unsigned elapsed = (now-start_of_time)&LED_MAX_COUNT;
            elapsed>>=(20-8);
            unsigned d=0;
            for(unsigned i=0;i<8;i++)
                d=(d>>1)+(0x80*(led_brightness[i]<=elapsed));
            leds.p_led0to7 <: d;
            leds.p_led8 <: (led_brightness[8]<=elapsed);
            leds.p_led9 <: (led_brightness[9]<=elapsed);
            d=0;
            for(unsigned i=10;i<13;i++)
                d=(d>>1)+(0x4*(led_brightness[i]<=elapsed));
            leds.p_led10to12 <: d;
            break;
        }
        */
        }
    }
}
