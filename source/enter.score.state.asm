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
                            copy lib/source/file.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/ui.entity.definitions.asm
                            copy source/app.debug.definitions.asm

                            mcopy generated/enter.score.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; The Enter Score screen

enter_score_state_data      data seg_gameplay

enter_score_state~display_time equ 60*30    ; user has 30 seconds to get their score in

enter_score_state~last_tick  ds 4
enter_score_state~countdown  ds 2

enter_score_state~update_rate equ 1
enter_score_max_initials_chars equ 3

enter_score_initials_indices ds enter_score_max_initials_chars+1  ; the index of each initial (byte).  Used to look up in the allowed chars table.  Note, using 4 bytes to make it easier to set.
enter_score_active_initial  ds 2            ; which initial is being changed
enter_score_player          ds 2            ; the player index
enter_score_initials_buffer ds 4            ; the built initials 'string'

enter_score~gamepad~prev_buttons    ds 2            ; gamepad button tracking
enter_score~gamepad~buttons         ds 2

enter_score~joystick~prev_buttons   ds 2            ; joystick button tracking
enter_score~joystick~buttons        ds 2

; Allowed characters.  THB, the Run, Coward font, doesn't have as many characters as I would like.
; Not even a ?, I need to fix this.
enter_score_allowed_chars   dc c' ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!-.'
enter_score_allowed_chars_count equ 40

str_player                  cstring 'PLAYER'
str_enter_score_line1       cstring 'CONGRATULATIONS'
str_enter_score_line2       cstring 'YOUR SCORE RANKS'
str_enter_score_line3       cstring 'AMONG THE TOP 30'
str_enter_score_line4       cstring 'GIVE 3 INITIALS'
str_enter_score_line5       cstring 'USE JOYSTICK OR KEYS TO'
str_enter_score_line6       cstring 'MAKE LETTER ENTRY'

                            end
; ----------------------------------------------------------------------------
enter_score_state_initialize start seg_gameplay
                            using appdata
                            using enter_score_state_data

                            debugtag 'enter_score_state_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
enter_score_state_activate  start seg_gameplay
                            using appdata
                            using applib_data
                            using enter_score_state_data
                            using grlib_global_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            debugtag 'enter_score_state_activate'

                            setlocaldatabank

                            stz enter_score_player
                            stz enter_score~gamepad~prev_buttons
                            stz enter_score~joystick~prev_buttons

; Find the first player that has a high score
check_next_player           lda enter_score_player
                            cmp #gameplay_max_players               ; check against gameplay_manager~player_count instead?
                            beq no_more_players

                            ldx #sizeof~player_state
                            jsl math~umul1r2
                            tax
                            pushdword {x},gameplay_manager~player_states+player_state~score
                            jsl high_score_check
                            bcc has_high_score

                            inc enter_score_player
                            stz enter_score~gamepad~prev_buttons
                            stz enter_score~joystick~prev_buttons
                            bra check_next_player

has_high_score              jsr draw_enter_scores_text

exit                        anop
                            restoredatabank

                            rtl

no_more_players             lda #app_state~frontend
                            sta >appdata~pending_state
                            bra exit
                            end

; ----------------------------------------------------------------------------
draw_enter_scores_text      private seg_gameplay
                            using appdata
                            using applib_data
                            using enter_score_state_data
                            using grlib_global_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            debugtag 'draw_enter_scores_text'

                            begin_locals
wX                          decl word
wY                          decl word
work_area_size              end_locals

                            lsub ,work_area_size

title_text_width            equ 64
title_text_x                equ 0+(320-title_text_width)/2
title_text_y                equ 40

title_player_number_x       equ title_text_x+title_text_width+8

line_advance                equ 14

line1_text_width            equ 102
line1_text_x                equ 0+(320-line1_text_width)/2
line1_text_y                equ 66

line2_text_width            equ 108
line2_text_x                equ 0+(320-line2_text_width)/2
line2_text_y                equ line1_text_y+line_advance

line3_text_width            equ 108
line3_text_x                equ 0+(320-line3_text_width)/2
line3_text_y                equ line2_text_y+line_advance

line4_text_width            equ 88
line4_text_x                equ 0+(320-line4_text_width)/2
line4_text_y                equ line3_text_y+line_advance

line5_text_width            equ 136
line5_text_x                equ 0+(320-line5_text_width)/2
line5_text_y                equ line4_text_y+line_advance

line6_text_width            equ 116
line6_text_x                equ 0+(320-line6_text_width)/2
line6_text_y                equ line5_text_y+line_advance

                            lda #appdata~gameplay_color~black~bits
                            jsl grlib_fill_alt_screen

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

; Player
                            pushdword #str_player
                            pushsword #title_text_x
                            pushsword #title_text_y
                            jsl grlib_draw_string

; number
                            clc
                            adc #appdata~font_primary~space_width
                            tax
                            lda enter_score_player
                            clc
                            adc #'1'                                ; fix, if we want more that 9 player ;)
                            pha
                            phx
                            pushsword #title_text_y
                            jsl grlib_draw_char

; The first line gets a drop shadow
                            lda #appdata~gameplay_color~blue~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_enter_score_line1
                            pushsword #line1_text_x+2
                            pushsword #line1_text_y+2
                            jsl grlib_draw_string

                            lda #appdata~gameplay_color~light_yellow~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_enter_score_line1
                            pushsword #line1_text_x
                            pushsword #line1_text_y
                            jsl grlib_draw_string

; Next two lines are in white
                            lda #appdata~gameplay_color~white~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_enter_score_line2
                            pushsword #line2_text_x
                            pushsword #line2_text_y
                            jsl grlib_draw_string

                            pushdword #str_enter_score_line3
                            pushsword #line3_text_x
                            pushsword #line3_text_y
                            jsl grlib_draw_string

; Next three lines are in light yellow
                            lda #appdata~gameplay_color~light_yellow~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_enter_score_line4
                            pushsword #line4_text_x
                            pushsword #line4_text_y
                            jsl grlib_draw_string

                            pushdword #str_enter_score_line5
                            pushsword #line5_text_x
                            pushsword #line5_text_y
                            jsl grlib_draw_string

                            pushdword #str_enter_score_line6
                            pushsword #line6_text_x
                            pushsword #line6_text_y
                            jsl grlib_draw_string

; Setup the initials indices
                            lda #$0001
                            sta enter_score_initials_indices
                            stz enter_score_initials_indices+2

                            stz enter_score_active_initial

                            jsr draw_initials
; Show the screen
                            pushsword #gameplay_ui~palette_id~high_score
                            jsl gameplay_ui_show_screen

                            getdword >applib~current_tick,enter_score_state~last_tick

                            lda #enter_score_state~display_time
                            sta enter_score_state~countdown

                            lret

                            end

; ----------------------------------------------------------------------------
enter_score_state_tick      start seg_gameplay
                            using appdata
                            using applib_data
                            using inputlib_data
                            using enter_score_state_data
                            using gameplay_manager_data
                            using gameplay_player_logic_data

                            debugtag 'enter_score_state_tick'

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            setlocaldatabank

                            lda enter_score_player
                            cmp #gameplay_max_players
                            jge overflow

; Get the tick delta
                            lda >applib~current_tick
                            sec
                            sbc enter_score_state~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc enter_score_state~last_tick+2
                            bne timer_expired                       ; If this happened, we got stuck for quite a while
                            cpx #enter_score_state~update_rate
                            blt done

do_update                   lda >applib~current_tick
                            sta enter_score_state~last_tick
                            lda >applib~current_tick+2
                            sta enter_score_state~last_tick+2

; X has the tick delta, lower word
                            txa
                            negate a
                            clc
                            adc enter_score_state~countdown
                            sta enter_score_state~countdown
                            beq timer_expired
                            bpl continue                           ; still more to go?
;
timer_expired               anop
                            jsr apply_initials
                            bra done

continue                    anop
; Do other updates, while waiting
                            jsr handle_controller
                            bcs done

                            jsl get_key_press
                            beq no_keypress
; Handle the input
                            jsr handle_keypress
                            bcs done
; Call the parent state, regardless of a key press or not, it may check the gamepad.
no_keypress                 anop
                            pha
                            jsl frontend_state_handle_input

                            jsr handle_analog_joystick
; Do some housekeeping
                            jsl applib_update_fps
                            jsl appdebug_update_text_screen

done                        anop
                            restoredatabank
                            rtl

overflow                    anop
                            lda #app_state~frontend
                            sta >appdata~pending_state
                            bra done

;;
; Apply the current player's initials and move on to the next player
apply_initials              anop

                            ldx enter_score_player
                            phx
; Push the initials, leaving spaces, based on where the active initial is
                            lda #$2020
                            sta enter_score_initials_buffer
                            lda #$0020
                            sta enter_score_initials_buffer+2

                            lda #0                                  ; make sure upper bits are clear, for tax in shortm mode, because that will transfer all 16-bits of A!
                            shortm
                            ldy #0
initials_loop               cpy enter_score_active_initial
                            bge skip_initial
                            lda enter_score_initials_indices,y
                            tax
                            lda enter_score_allowed_chars,x
                            sta enter_score_initials_buffer,y
                            iny
                            bra initials_loop
skip_initial                longm

                            pushdword enter_score_initials_buffer
; Get the score
                            lda #sizeof~player_state
                            ldx enter_score_player
                            jsl math~umul1r2
                            tax
                            pushdword {x},gameplay_manager~player_states+player_state~score
                            jsl high_score_add

check_next_player           inc enter_score_player
                            lda enter_score_player
                            cmp #gameplay_max_players               ; check agains gameplay_manager~player_count instead?
                            beq no_more_players

                            ldx #sizeof~player_state
                            jsl math~umul1r2
                            tax
                            pushdword {x},gameplay_manager~player_states+player_state~score
                            jsl high_score_check
                            bcs check_next_player
; Re-draw the screen
                            jsr draw_enter_scores_text
                            rts

no_more_players             anop
                            jsl high_score_write

                            lda #app_state~frontend
                            sta >appdata~pending_state
                            rts

;;
handle_keypress             anop
                            cmp #key~up_arrow
                            beq next_char
                            cmp #key~down_arrow
                            beq prev_char
                            cmp #key~right_arrow
                            beq next_initial
                            cmp #key~left_arrow
                            beq prev_initial

                            clc
                            rts

; increment the index to the next character in the allowed list, or wrap
next_char                   anop
                            ldx enter_score_active_initial
                            shortm
                            lda enter_score_initials_indices,x
                            inc a
                            cmp #enter_score_allowed_chars_count
                            blt ok_char
                            lda #0
ok_char                     sta enter_score_initials_indices,x
                            longm
want_redraw                 jsr redraw_initials
no_change                   sec
                            rts

; decrement the index to the previous character in the allowed list, or wrap
prev_char                   anop
                            ldx enter_score_active_initial
                            shortm
                            lda enter_score_initials_indices,x
                            dec a
                            bpl ok_char
                            lda #enter_score_allowed_chars_count-1
                            bra ok_char
                            longa on

; Move to the next initial.  If > than the max, apply the initials
next_initial                anop
                            lda enter_score_active_initial
                            inc a
                            sta enter_score_active_initial          ; going off the edge will signal we are done.
                            cmp #enter_score_max_initials_chars
                            blt want_redraw
                            jsr apply_initials
                            bra no_change

; Move to the previous initial.  Does not wrap
prev_initial                anop
                            lda enter_score_active_initial
                            beq no_change
                            dec a
                            sta enter_score_active_initial
                            bra want_redraw

;; Local Funtions

;; Handle the SNES MAX controller
handle_controller           anop
                            jsl snes_max_read_controller                    ; read the button state for the controller, if enabled.
                            lda enter_score_player
                            asl a
                            tax
                            lda gameplay_manager~player_state_offsets,x
                            tax
                            getword {x},gameplay_manager~player_states+player_state~use_gamepad
                            beq no_gamepad

                            dec a
                            asl a
                            tax
                            lda >input~gamepad_buttons,x
; We only want 'new' button presses.  If the button is still on from a previous press, turn it off
; Might be nice to have a 'repeat' delay?
                            tax
                            sta enter_score~gamepad~buttons
                            eor enter_score~gamepad~prev_buttons
                            and enter_score~gamepad~buttons
                            sta enter_score~gamepad~buttons
                            stx enter_score~gamepad~prev_buttons

                            bit gameplay_player_up~gamepad_button
                            bne next_char
                            bit gameplay_player_down~gamepad_button
                            bne prev_char
                            bit gameplay_player_right~gamepad_button
                            bne next_initial
                            bit gameplay_player_left~gamepad_button
                            bne prev_initial

no_gamepad                  clc
                            rts

;; Handle the analog joystick
handle_analog_joystick      anop
                            lda enter_score_player
                            asl a
                            tax
                            lda gameplay_manager~player_state_offsets,x
                            tax
                            getword {x},gameplay_manager~player_states+player_state~use_analog_joystick
                            beq no_joystick

                            jsl joy_1_read
                            cmp #$ffff
                            beq no_joystick
; Convert the analog state to buttons
                            jsl convert_joy_state_to_buttons

; We only want 'new' button presses.  If the button is still on from a previous press, turn it off
; Might be nice to have a 'repeat' delay?
                            tax
                            sta enter_score~joystick~buttons
                            eor enter_score~joystick~prev_buttons
                            and enter_score~joystick~buttons
                            sta enter_score~joystick~buttons
                            stx enter_score~joystick~prev_buttons

                            bit #input~joy_up
                            jne next_char
                            bit #input~joy_down
                            jne prev_char
                            bit #input~joy_right
                            jne next_initial
                            bit #input~joy_left
                            jne prev_initial

no_joystick                 clc
                            rts

                            end

initials_x                  gequ 144
initials_y                  gequ 154
initials_x_advance          gequ 10

underscore_width            gequ 8
underscore_height           gequ 1
underscore_y_advance        gequ 4

; ----------------------------------------------------------------------------
; Draw the initials the user is editing
draw_initials               private seg_gameplay
                            using appdata
                            using applib_data
                            using enter_score_state_data
                            using gameplay_manager_data

                            debugtag 'draw_initials'

                            setlocaldatabank

; Set the font and color
                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~yellow~bits
                            jsl grlib_set_font_fore_color

; Must get the character to display, from the index into the allowed characters list.
                            lda enter_score_initials_indices
                            and #$ff
                            tay
                            lda enter_score_allowed_chars,y
                            and #$ff
                            pha
                            pushsword #initials_x
                            pushsword #initials_y
                            jsl grlib_draw_char

                            lda enter_score_initials_indices+1
                            and #$ff
                            tay
                            lda enter_score_allowed_chars,y
                            and #$ff
                            pha
                            pushsword #initials_x+initials_x_advance
                            pushsword #initials_y
                            jsl grlib_draw_char

                            lda enter_score_initials_indices+2
                            and #$ff
                            tay
                            lda enter_score_allowed_chars,y
                            and #$ff
                            pha
                            pushsword #initials_x+(initials_x_advance*2)
                            pushsword #initials_y
                            jsl grlib_draw_char

; Draw the lines under the letters
                            ldx #initials_x
                            lda #0
                            jsr draw_underscore

                            ldx #initials_x+initials_x_advance
                            lda #1
                            jsr draw_underscore

                            ldx #initials_x+(initials_x_advance*2)
                            lda #2
                            jsr draw_underscore

                            restoredatabank

                            rts

;;
draw_underscore             anop
                            phx
                            pushsword #initials_y+underscore_y_advance
                            pushsword #underscore_width
                            pushsword #underscore_height
                            ldy #appdata~gameplay_color~white~bits              ; active one will be white
                            cmp enter_score_active_initial
                            beq is_active
                            ldy #appdata~gameplay_color~blue~bits               ; else it is blue
is_active                   phy
                            jsl grlib_alt_screen_fill_rect
                            rts

                            end

; ----------------------------------------------------------------------------
; This will erase, draw then copy the initials to the screen
redraw_initials             private seg_gameplay
                            using appdata
                            using applib_data
                            using enter_score_state_data
                            using gameplay_manager_data

                            debugtag 'redraw_initials'

                            setlocaldatabank

                            pushsword #initials_x
                            pushsword #initials_y-appdata~font_primary~height
                            pushsword #initials_x_advance*3
                            pushsword #appdata~font_primary~height+underscore_y_advance
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

                            jsr draw_initials

                            pushsword #initials_x
                            pushsword #initials_y-appdata~font_primary~height
                            pushsword #initials_x_advance*3
                            pushsword #appdata~font_primary~height+underscore_y_advance+1
                            jsl grlib_alt_screen_to_screen_rect

                            restoredatabank
                            rts
                            end
