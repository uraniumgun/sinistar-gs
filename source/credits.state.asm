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

                            mcopy generated/credits.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; The Credits / Special Thanks screen

credits_state_data          data seg_gameplay

credits_state~last_tick     ds 4

credits_state~update_rate   equ 1
                            end
; ----------------------------------------------------------------------------
;credits_state_initialize    start seg_gameplay
;                            using appdata
;
;                            debugtag 'credits_state_initialize'
;
;                            rtl
;                            end

; ----------------------------------------------------------------------------
credits_state_activate start seg_gameplay
                            using appdata
                            using applib_data
                            using inputlib_data
                            using credits_state_data
                            using textlib_global_data
                            using grlib_global_data
                            using gameplay_ui_data

                            debugtag 'credits_state_activate'

                            begin_locals
wY                          decl word
work_area_size              end_locals

                            sub ,work_area_size

screen_title_y              equ 14
section_left                equ 4
exit_text_y_offset          equ 200-(appdata~font_teeny~height+4)

                            setlocaldatabank

                            lda #appdata~gameplay_color~effect1~bits        ; dark blue
                            jsl grlib_fill_alt_screen

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

; Screen title
                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_title
                            pushsword #0
                            pushsword #320
                            pushsword #screen_title_y
                            jsl grlib_draw_string_centered
                            txa                                     ; x has line height
                            clc
                            adc #screen_title_y+3
                            sta <wY

; Show section items
                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            pushptr #section_1
                            pushsword #section_left
                            pushsword <wY
                            pushsword #appdata~font_teeny~height+1
                            jsl ui_draw_text_section
                            sta <wY
; End title

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_end_title
                            pushsword #0
                            pushsword #320
                            lda <wY
                            clc
                            adc #8
                            pha
                            jsl grlib_draw_string_centered

; The how to exit

                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~light_gray~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_press_to_exit
                            pushsword #0
                            pushsword #320
                            pushsword #exit_text_y_offset
                            jsl grlib_draw_string_centered

; Show the screen
                            pushsword #gameplay_ui~palette_id~high_score        ; use the high-score palette
                            jsl gameplay_ui_show_screen

                            lda >applib~current_tick
                            sta credits_state~last_tick
                            lda >applib~current_tick+2
                            sta credits_state~last_tick+2

                            restoredatabank
                            ret


sub_section_y_pixels        equ 4

section_1                   anop
                            dc i'0'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_1'

                            dc i'1'
                            dc i'$8000'
                            dc a4'str_section_1_1b'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_1c'

                            dc i'1'
                            dc i'$8000'
                            dc a4'str_section_1_2'

                            dc i'0'
                            dc i'appdata~gameplay_color~red~index'
                            dc a4'str_section_1_2b'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_2c'

; Byte works
                            dc i1'1,sub_section_y_pixels'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_bw'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_bw_b'

; Golden Gate
                            dc i1'1,sub_section_y_pixels'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_gg'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_gg_b'

; BD
                            dc i1'1,sub_section_y_pixels'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_bd'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_bd_b'

                            dc i'1'
                            dc i'$8000'
                            dc a4'str_section_1_bd_c'

; SynaMax
                            dc i1'1,sub_section_y_pixels'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_sm'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_sm_b'

                            dc i'1'
                            dc i'$8000'
                            dc a4'str_section_1_sm_c'

; ZX0
                            dc i1'1,sub_section_y_pixels'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_cmp'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_cmp_b'

                            dc i'1'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_cmp_c'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_cmp_d'

; Fonts
                            dc i1'1,sub_section_y_pixels'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_fnt'

                            dc i'0'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_fnt_a'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_item_separator'

                            dc i'0'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_fnt_b'

                            dc i'0'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_item_separator'

                            dc i'0'
                            dc i'appdata~gameplay_color~light_yellow~index'
                            dc a4'str_section_1_fnt_c'

                            dc i'1'
                            dc i'appdata~gameplay_color~yellow~index'
                            dc a4'str_section_1_fnt_d'

                            dc i'0'
                            dc i'appdata~gameplay_color~red~index'
                            dc a4'str_section_1_fnt_e'

                            dc i4'$ffff'                    ; terminator

str_title                   cstring 'SPECIAL THANKS'
str_end_title               cstring 'APPLE II FOREVER!'

str_section_1_1             dc c'SAM DICKER, NOAH FALSTEIN, R.J. MICAL, RICHARD WITT, JACK HAEGER, MIKE METZ,',i1'0'
str_section_1_1b            dc c'JOHN KOTLARIK',i1'0'
str_section_1_1c            dc c' AND THE REST OF THE WILLIAMS TEAM THAT CREATED SINISTAR.',i1'0'
str_section_1_2             dc c'SEE ',i1'0'
str_section_1_2b            dc c'GITHUB.COM/HISTORICALSOURCE/SINISTAR',i1'0'
str_section_1_2c            dc c' FOR THE SOURCE TO THE ARCADE GAME.',i1'0'

str_section_1_bw             dc c'BYTE WORKS',i1'0'
str_section_1_bw_b          dc c' FOR THE WONDERFUL ORCA/M ENVIRONMENT.',i1'0'

str_section_1_gg            dc c'KELVIN SHERLOCK',i1'0'
str_section_1_gg_b          dc c' FOR THE AMAZING GOLDEN GATE VIRTUAL MACHINE.',i1'0'

str_section_1_bd            dc c'ANTOINE VIGNAI, OLIVIER ZARDINI AND BRUTAL DELUXE SOFTWARE',i1'0'
str_section_1_bd_b          dc c' FOR CYRENE, CADIUS,',i1'0'
str_section_1_bd_c          dc c'AND ALL THE OTHER AWESOME TOOLS AND CODE THEY HAVE CONTRIBUTED OVER THE YEARS.',i1'0'

str_section_1_sm            dc c'SYNAMAX,',i1'0'
str_section_1_sm_b          dc c' FOR THE EXCELLENT INSIGHTS INTO THE ORIGINAL CODE AND',i1'0'
str_section_1_sm_c          dc c'GAMEPLAY MODIFICATION TIPS.',i1'0'

str_section_1_cmp           dc c'EINAR SAUKAS,',i1'0'
str_section_1_cmp_b         dc c' FOR THE FANTASTIC ZX0 COMPRESSION ALGORITHM AND',i1'0'
str_section_1_cmp_c         dc c'EMMANUEL MARTY,',i1'0'
str_section_1_cmp_d         dc c' FOR THE SALVADOR ZX0 DECOMPRESSOR',i1'0'

str_section_1_fnt           dc c'FONTS USED IN THIS GAME, ',i1'0'
str_section_1_fnt_a         dc c'TEENY TINY PIXELS',i1'0'
str_section_1_fnt_b         dc c'RUN, COWARD',i1'0'
str_section_1_fnt_c         dc c'PRESS START',i1'0'
str_section_1_fnt_d         dc c'ARE FROM ',i1'0'
str_section_1_fnt_e         dc c'WWW.FONTSPACE.COM',i1'0'

str_item_separator          dc c', ',i1'0'

str_press_to_exit           cstring 'PRESS SPACE OR ESC TO EXIT'

                            end

; ----------------------------------------------------------------------------
credits_state_tick          start seg_gameplay
                            using appdata
                            using applib_data
                            using credits_state_data

                            debugtag 'credits_state_tick'

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            setlocaldatabank

; Get the tick delta
                            lda >applib~current_tick
                            sec
                            sbc credits_state~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc credits_state~last_tick+2
                            bne do_update                                   ; If this happened, we got stuck for quite a while
                            cpx #credits_state~update_rate
                            blt done

do_update                   lda >applib~current_tick
                            sta credits_state~last_tick
                            lda >applib~current_tick+2
                            sta credits_state~last_tick+2

; Do other updates, while waiting
                            jsl snes_max_read_controller                    ; read the button state for the controller, if enabled.
                            jsl get_key_press
                            beq no_keypress
                            cmp #key~space
                            beq exit_credits
                            cmp #key~esc
                            beq exit_credits
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

exit_credits                anop
                            lda #app_state~frontend
                            sta >appdata~pending_state
                            bra done

                            end
