                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/input.constants.asm
                            mcopy generated/grlib.debug.rect.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------
; Fill the entire alt_screen with a word pattern
; Parameters:
;  ACC contains fill pattern
grlib_draw_debug_rect       start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            begin_locals
wSavedDrawX                 decl word
wSavedDrawY                 decl word
wSavedAreaWidth             decl word
wSavedAreaHeight            decl word
work_area_size              end_locals

                            debugtag 'grlib_draw_debug_rect'
                            ssub (2:wLeft,2:wTop,2:wWidth,2:wHeight,2:wColor,2:wFlags),work_area_size

; Switch to the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

extra_stack                 equ 2

; Save some grlib dp and put in ones from our stack

                            getword <draw_x
                            putword {s},#wSavedDrawX+extra_stack
                            getword {s},#wLeft+extra_stack
                            putword <draw_x

                            getword <draw_y
                            putword {s},#wSavedDrawY+extra_stack
                            getword {s},#wTop+extra_stack
                            putword <draw_y

                            getword <area_width
                            putword {s},#wSavedAreaWidth+extra_stack
                            getword {s},#wWidth+extra_stack
                            putword <area_width

                            getword <area_height
                            putword {s},#wSavedAreaHeight+extra_stack
                            getword {s},#wHeight+extra_stack
                            putword <area_height

                            getword {s},#wColor+extra_stack
                            jsl grlib_screen_draw_rect

; Put the saved values back
                            getword {s},#wSavedDrawX+extra_stack
                            putword <draw_x
                            getword {s},#wSavedDrawY+extra_stack
                            putword <draw_y
                            getword {s},#wSavedAreaWidth+extra_stack
                            putword <area_width
                            getword {s},#wSavedAreaHeight+extra_stack
                            putword <area_height

                            pld

                            lda <wFlags
                            jsl grlib_debug_pause
                            sretkc

                            end

; -----------------------------------------------------------------------------
; Do a 'pause' or 'wait', based on what is in the acc.
; bit 0, off = skip, on = test other bits
; bit 1, off = pause for a few frames, then continue, on = wait for keypress
; Returns:
; Carry set, if the user hit ESC, during a wait.
grlib_debug_pause           start seg_grlib
                            using softswitch_definitions

                            clc                                 ; Assume no ESC
                            bit #1
                            beq no_pause
                            bit #2
                            beq wait
; We will wait for a few frames
                            ldy #4
                            shortm
vbl1                        lda >ssw~rdvbl
                            bpl vbl1       ; If bit 7 is off, we are not in the VBL
                            dey
                            beq done_wait
; wait till we are out
vbl2                        lda >ssw~rdvbl
                            bmi vbl2
                            bra vbl1
done_wait                   anop
                            longm
                            bra no_pause

wait                        jsl get_key_press
                            beq wait
                            cmp #key~esc
                            beq hit_esc
                            jsl handle_common_keypresses
                            bcc wait                        ; If it was handled, loop again.
                            clc
no_pause                    anop
                            rtl
hit_esc                     sec
                            rtl
                            end
