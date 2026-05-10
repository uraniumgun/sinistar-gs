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

                            mcopy generated/copyright.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; The Input Overview screen

copyright_state_data        data seg_gameplay

copyright_state~display_time equ 60*10

copyright_state~last_tick   ds 4
copyright_state~tick_delta  ds 2
copyright_state~countdown   ds 2

copyright_state~update_rate equ 1
                            end
; ----------------------------------------------------------------------------
;copyright_state_initialize  start seg_gameplay
;                            using appdata
;
;                            rtl
;                            end

; ----------------------------------------------------------------------------
copyright_state_activate    start seg_gameplay
                            using appdata
                            using applib_data
                            using copyright_state_data
                            using textlib_global_data
                            using grlib_global_data
                            using sinistar_entity_data
                            using gameplay_ui_data
                            using gameplay_sound_data
                            using turn_start_state_data

                            debugtag 'copyright_state_activate'

                            begin_locals
wX                          decl word
wY                          decl word
wSpaceWidth                 decl word
wSectionOffset              decl word
wSectionYAdvance            decl word
work_area_size              end_locals

                            sub ,work_area_size

line_1_y                    equ 60

line_2_y                    equ 84

                            setlocaldatabank

; Some support for drawing Sinistar using the Turn Start state's code
                            stz turn_start_state~color_cycle_timer
                            lda #sinistar_mouth_closed
                            sta >sinistar_mouth_position
                            lda #sinistar_eyebrow_normal
                            sta >sinistar_eyebrow_position

                            lda #appdata~gameplay_color~black~bits
                            jsl grlib_fill_alt_screen

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

; Line 1
                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_sinistar
                            pushsword #0
                            pushsword #320
                            pushsword #line_1_y
                            jsl grlib_draw_string_centered

                            pushptr #str_tm                         ; will not change A
                            inc a                                   ; x position from the last print
                            pha
                            pushsword #line_1_y+4                   ; adjust downward a bit

; Change the font
                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr
; Draw the TM
                            jsl grlib_draw_string

; Line 2
                            pushptr #str_copyright
                            pushsword #0
                            pushsword #320
                            pushsword #line_2_y
                            jsl grlib_draw_string_centered

; Draw Sinistar
                            pushsword #sinistar_state_alive
                            pushsword #max_sinistar_pieces
                            jsr turn_start_state_draw_sinistar

; Show the screen

                            pushsword #gameplay_ui~palette_id~high_score        ; use the high-score palette
                            jsl gameplay_ui_show_screen

; Play Sinistar speech after we flip the screen

                            jsl gameplay_sinistar_stop_speech

                            lda >appdata~attract_sound_disabled
                            bne no_sound
; Play one of a selected number of taunts
                            jsl math~rnd_generate
                            and #%00000011                          ; There are 4 taunts
                            asl a
                            tax
                            lda taunts,x
                            pha
                            jsl gameplay_sinistar_play_speech

no_sound                    getdword >applib~current_tick,copyright_state~last_tick

                            lda #copyright_state~display_time
                            sta copyright_state~countdown

                            restoredatabank
                            ret

str_sinistar                cstring 'SINISTAR'
str_tm                      cstring 'TM'

str_copyright               cstring 'COPYRIGHT 1982 WILLIAMS ELECTRONICS, INC.'

taunts                      dc i'id_sfx~i_hunger,id_sfx~beware_i_live,id_sfx~beware_coward,id_sfx~i_hunger_coward'
                            end

; ----------------------------------------------------------------------------
copyright_state_tick   start seg_gameplay
                            using appdata
                            using applib_data
                            using copyright_state_data

                            debugtag 'copyright_state_tick'

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            setlocaldatabank

; Get the tick delta
                            lda >applib~current_tick
                            sec
                            sbc copyright_state~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc copyright_state~last_tick+2
                            bne timer_expired                       ; If this happened, we got stuck for quite a while
                            cpx #copyright_state~update_rate
                            blt done

do_update                   getdword >applib~current_tick,copyright_state~last_tick

; X has the tick delta, lower word
                            txa
                            sta copyright_state~tick_delta
                            negate a
                            clc
                            adc copyright_state~countdown
                            sta copyright_state~countdown
                            beq timer_expired
                            bpl continue                           ; still more to go?
;
timer_expired               anop
                            pushsword #app_state~copyright
                            jsl frontend_set_next_state
                            bcc done
; restart
restart                     lda #copyright_state~display_time
                            sta copyright_state~countdown

continue                    anop
; Do other updates, while waiting
                            pushsword copyright_state~tick_delta
                            jsr turn_start_state_update_sinistar
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
