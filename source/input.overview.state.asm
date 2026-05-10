                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/input.constants.asm

                            copy source/gameplay.constants.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/ui.entity.definitions.asm
                            copy source/app.debug.definitions.asm

                            mcopy generated/input.overview.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; The Input Overview screen

input_overview_state_data   data seg_gameplay

input_overview_state~display_time equ 60*10

input_overview_state~last_tick ds 4
input_overview_state~countdown ds 2

input_overview_state~update_rate equ 1
                            end
; ----------------------------------------------------------------------------
;input_overview_state_initialize start seg_gameplay
;                            using appdata
;
;                            debugtag 'input_overview_state_initialize'
;
;                            rtl
;                            end

; ----------------------------------------------------------------------------
input_overview_state_activate start seg_gameplay
                            using appdata
                            using applib_data
                            using inputlib_data
                            using input_overview_state_data
                            using textlib_global_data
                            using grlib_global_data
                            using gameplay_ui_data

                            debugtag 'input_overview_state_activate'

                            begin_locals
wX                          decl word
wY                          decl word
wSpaceWidth                 decl word
wSectionOffset              decl word
wSectionYAdvance            decl word
work_area_size              end_locals

                            sub ,work_area_size

screen_title_y              equ 14

section_center_x            equ 146
section_center_x_left       equ section_center_x-6
section_center_x_right      equ section_center_x+6

keyboard_section_title_y    equ screen_title_y+14

                            setlocaldatabank

                            lda #appdata~gameplay_color~effect1~bits        ; dark blue
                            jsl grlib_fill_alt_screen

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~secondary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~font_secondary~space_width
                            sta <wSpaceWidth

; Screen title
                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_input
                            pushsword #0
                            pushsword #320
                            pushsword #screen_title_y
                            jsl grlib_draw_string_centered

; Keyboard title
                            lda #appdata~gameplay_color~yellow~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_keyboard
                            pushsword #0
                            pushsword #320
                            pushsword #keyboard_section_title_y
                            jsl grlib_draw_string_centered
                            txa
                            clc
                            adc #keyboard_section_title_y+3
                            sta <wY

; Keyboard section items
                            lda #appdata~gameplay_color~blue_gray~bits
                            jsl grlib_set_font_fore_color

                            lda #keyboard_section
                            jsr _draw_section

                            lda <wY
                            clc
                            adc #6
                            sta <wY

; SNES MAX title
                            lda #appdata~gameplay_color~yellow~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_snes_max
                            pushsword #0
                            pushsword #320
                            pushsword <wY
                            jsl grlib_draw_string_centered
                            txa
                            sec                     ; add an extra
                            adc <wY
                            sta <wY

                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda >input~gamepad_slot
                            beq show_gamepad_disabled

                            lda >input~gamepad1_connected
                            beq show_gamepad_disconnected

; Show that it is enabled and connected
                            pushptr #str_connected
                            lda #appdata~gameplay_color~white~bits
                            jsl grlib_set_font_fore_color
                            bra show_gamepad_state

show_gamepad_disconnected   pushptr #str_disconnected
                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color
                            bra show_gamepad_state

show_gamepad_disabled       pushptr #str_disabled
                            lda #appdata~gameplay_color~light_gray~bits
                            jsl grlib_set_font_fore_color

show_gamepad_state          pushsword #0
                            pushsword #320
                            pushsword <wY
                            jsl grlib_draw_string_centered
                            txa
                            clc
                            adc <wY
                            adc #5
                            sta <wY

                            pushptr >appdata~secondary_font_ptr
                            jsl grlib_set_active_font_ptr

; SNES MAX section items
                            lda #appdata~gameplay_color~blue_gray~bits
                            jsl grlib_set_font_fore_color

                            lda #snes_max_section
                            jsr _draw_section

; Analog Stick
                            lda <wY
                            clc
                            adc #6
                            sta <wY

                            lda #appdata~gameplay_color~yellow~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_analog_joystick
                            pushsword #0
                            pushsword #320
                            pushsword <wY
                            jsl grlib_draw_string_centered
                            txa
                            sec                     ; add an extra
                            adc <wY
                            sta <wY

                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda >input~analog_joystick_enabled
                            beq show_analog_joystick_disabled

                            jsl joy_1_read
                            cmp #$ffff
                            bne show_analog_joystick_detected

                            pushptr #str_analog_joystick_not_detected
                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color
                            bra show_analog_joystick_state

show_analog_joystick_detected pushptr #str_connected
                            lda #appdata~gameplay_color~white~bits
                            jsl grlib_set_font_fore_color
                            bra show_analog_joystick_state

show_analog_joystick_disabled pushptr #str_disabled
                            lda #appdata~gameplay_color~light_gray~bits
                            jsl grlib_set_font_fore_color

show_analog_joystick_state  pushsword #0
                            pushsword #320
                            pushsword <wY
                            jsl grlib_draw_string_centered
                            txa
                            clc
                            adc <wY
                            adc #5
                            sta <wY

                            pushptr >appdata~secondary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~blue_gray~bits
                            jsl grlib_set_font_fore_color

                            lda #analog_joystick_section
                            jsr _draw_section
; Show the screen

                            pushsword #gameplay_ui~palette_id~high_score        ; use the high-score palette
                            jsl gameplay_ui_show_screen

                            lda >applib~current_tick
                            sta input_overview_state~last_tick
                            lda >applib~current_tick+2
                            sta input_overview_state~last_tick+2

                            lda #input_overview_state~display_time
                            sta input_overview_state~countdown

                            restoredatabank
                            ret

                            begin_struct
section_entry~name          decl ptr
section_entry~desc          decl ptr
sizeof~section_entry        end_struct

;; Local Functions
_draw_section               anop
                            sta <wSectionOffset
section_loop                tay
                            getword {y},#section_entry~name+2
                            beq section_done
                            pha
                            getword {y},#section_entry~name
                            pha
                            jsl grlib_get_string_pixel_size                     ; Draw right-justified, so get the width first
                            stx <wSectionYAdvance
                            negate a
                            clc
                            adc #section_center_x_left
                            sta <wX

; Name
                            ldy <wSectionOffset
                            pushptr {y},#section_entry~name
                            pushsword <wX
                            pushsword <wY
                            jsl grlib_draw_string

                            pushsword #ascii~dash
                            pushsword #section_center_x_left+2
                            pushsword <wY
                            jsl grlib_draw_char

; Desc
                            ldy <wSectionOffset
                            pushptr {y},#section_entry~desc
                            pushsword #section_center_x_right
                            pushsword <wY
                            jsl grlib_draw_string

                            lda <wY
                            clc
                            adc <wSectionYAdvance
                            adc #2
                            sta <wY

                            lda <wSectionOffset
                            clc
                            adc #sizeof~section_entry
                            sta <wSectionOffset
                            bra section_loop

section_done                rts

; It would be great if the display of the keys was adjustable to a configuration value for the input.
keyboard_section            dc a4'str_turn'
                            dc a4'str_turn_keys'
                            dc a4'str_thrust'
                            dc a4'str_thrust_keys'
                            dc a4'str_fire'
                            dc a4'str_fire_keys'
                            dc a4'str_sinibomb'
                            dc a4'str_sinibomb_keys'
                            dc a4'str_pause'
                            dc a4'str_pause_keys'
                            dc a4'str_quit'
                            dc a4'str_quit_keys'
                            dc i4'0'                        ; terminator

snes_max_section            dc a4'str_turn_thrust'
                            dc a4'str_turn_controller'
                            dc a4'str_fire'
                            dc a4'str_fire_controller'
                            dc a4'str_sinibomb'
                            dc a4'str_sinibomb_controller'
                            dc a4'str_pause'
                            dc a4'str_pause_controller'
                            dc i4'0'                        ; terminator

analog_joystick_section     dc a4'str_turn_thrust'
                            dc a4'str_turn_joystick'
                            dc a4'str_fire'
                            dc a4'str_fire_joystick'
                            dc a4'str_sinibomb'
                            dc a4'str_sinibomb_joystick'
                            dc i4'0'                        ; terminator

str_input                   cstring 'Input'

str_enabled                 cstring 'ENABLED'
str_disabled                cstring 'DISABLED'
str_connected               cstring 'CONNECTED'
str_disconnected            cstring 'DISCONNECTED'

str_analog_joystick_not_detected cstring 'NOT DETECTED! DISABLE IN CONFIGURATION TO INCREASE PERFORMANCE!'

str_keyboard                cstring 'Keyboard'
str_turn                    cstring 'Turn'
str_turn_keys               cstring 'I,J,K,L or Keypad'
str_thrust                  cstring 'Thrust'
str_thrust_keys             cstring 'Shift or Option'
str_fire                    cstring 'Fire'
str_fire_keys               cstring 'Open-Apple/Command'
str_sinibomb                cstring 'Launch Sinibomb'
str_sinibomb_keys           cstring 'Space'
str_pause                   cstring 'Pause'
str_pause_keys              cstring 'P'
str_quit                    cstring 'Quit'
str_quit_keys               cstring 'Q'

str_snes_max                cstring 'SNES MAX'
str_turn_thrust             cstring 'Turn/Thrust'
str_turn_controller         cstring 'D-Pad'
str_fire_controller         cstring 'Y'
str_sinibomb_controller     cstring 'B'
str_pause_controller        cstring 'Select'

str_analog_joystick         cstring 'Analog Joystick'
str_turn_joystick           cstring 'Joystick'
str_fire_joystick           cstring 'Button 1'
str_sinibomb_joystick       cstring 'Button 2'

                            end

; ----------------------------------------------------------------------------
input_overview_state_tick   start seg_gameplay
                            using appdata
                            using applib_data
                            using input_overview_state_data

                            debugtag 'input_overview_state_tick'

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            setlocaldatabank

; Get the tick delta
                            lda >applib~current_tick
                            sec
                            sbc input_overview_state~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc input_overview_state~last_tick+2
                            bne timer_expired                       ; If this happened, we got stuck for quite a while
                            cpx #input_overview_state~update_rate
                            blt done

do_update                   lda >applib~current_tick
                            sta input_overview_state~last_tick
                            lda >applib~current_tick+2
                            sta input_overview_state~last_tick+2

; X has the tick delta, lower word
                            txa
                            negate a
                            clc
                            adc input_overview_state~countdown
                            sta input_overview_state~countdown
                            beq timer_expired
                            bpl continue                           ; still more to go?
;
timer_expired               anop
                            pushsword #app_state~input_overview
                            jsl frontend_set_next_state
                            bcc done
; restart
restart                     lda #input_overview_state~display_time
                            sta input_overview_state~countdown

continue                    anop
; Do other updates, while waiting
                            jsl snes_max_read_controller                    ; read the button state for the controller, if enabled.
                            jsl get_key_press
                            beq no_keypress
                            cmp #key~space
                            beq timer_expired
; Call the parent state, regardless of a key press or not, it may check the gamepad.
no_keypress                 anop
                            pha
                            jsl frontend_state_handle_input
; Do some housekeeping
                            jsl applib_update_fps
                            jsl appdebug_update_text_screen

done                        anop
                            restoredatabank
                            rtl

                            end
