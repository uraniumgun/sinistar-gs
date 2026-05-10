                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/input.constants.asm

                            copy source/app.debug.definitions.asm

                            mcopy generated/app.debug.support.macros

; -----------------------------------------------------------------------------
appdebug_data                   data seg_app

; Tracking for the text mode state, for the debug system, so that it can signal
; handlers and such, that the state has changed.
appdebug~in_text_mode           dc i'0'
appdebug~clear_text_screen      dc i'0'

; The last error code
appdebug~last_error_code        dc i'0'

; If true, debug mode/keys are enabled.  Note, expecting true to have the high-bit on
appdebug~debug_mode             dc i'0'

; The modes the handler update is in
appdebug~handler_display~info   equ 0       ; display the handler info
appdebug~handler_display~help   equ 2       ; display the handler text

appdebug~handler_display_mode   dc i'appdebug~handler_display~help'     ; starting in help-mode

; The text_display member points to the function that will get called,
; when the text display is active, and only when it is active.
; Handlers should check where the cursor is, in the textbox, if they
; co-exist with other handlers.  If the cursor is off the bottom,
; then some other handler has used up all the space.

; The function is passed:
; wStatus       - a status on the function call, this is used to see if
;                 this is the first time the function was called

; If true, this handler has been updated at least once since the text display was
; enabled.  This will get cleared

debug_handlers~count            dc i'0'
debug_handlers~array            ds debug_handlers~max_count*sizeof~debug_handler


; Some common strings
debug_str~Type                  cstring 'Type'
debug_str~ID                    cstring 'ID'
debug_str~X                     cstring 'X'
debug_str~Y                     cstring 'Y'
debug_str~Sort                  cstring 'Sort'
debug_str~Mission               cstring 'Mission'
debug_str~Responder             cstring 'Responder'
debug_str~none                  cstring 'none'

; A debug buffer to help find overwrites
debug~max_compare_buffer        equ 256
debug_compare_buffer            ds debug~max_compare_buffer

                                end

; -----------------------------------------------------------------------------
; Set the 'last error' code
; Parameters:
; Error code in A
; Returns:
; carry set
appdebug_set_last_error     start seg_app
                            using appdebug_data

; Can we print the code too?
                            assert_brk 'error_hit'

                            sta >appdebug~last_error_code
                            sec
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the debug mode
; Parameters:
; Mode in A
appdebug_set_debug_mode     start seg_app
                            using appdebug_data

                            cmp #0
                            beq off
                            ora #$8000                              ; high-bit on, for easy testing of the N bit
off                         sta >appdebug~debug_mode
                            rtl
                            end

; -----------------------------------------------------------------------------
; Handle some common (mostly debug) keypresses.
; Returns:
; carry clear if the keypress was handled.
handle_common_keypresses    start seg_app
                            using grlib_global_data
                            using inputlib_data
                            using appdebug_data
                            using appdata
                            using softswitch_definitions
                            using gameplay_sinistar_logic_data
                            using gameplay_sound_data

                            debugtag 'handle_common_keypresses'
                            begin_locals
wCount                      decl word
wLocalBank                  decl word
work_area_size              end_locals

                            sub (2:wKey),work_area_size
                            setlocaldatabank

; Make the key upper case.
; I was allowing for key handlers to support upper and lower case, but in practice, this usually just meant that handlers
; were just doubling up checking upper and lower case. i.e. There isn't any case where it is advantageous to have them separate
; and it is just wasting time to check for both.  A handler could peek at the input~last_key_down_modifiers if it needs to know more information.
                            lda <wKey
                            cmp #'a'
                            blt not_lower
                            cmp #'z'+1
                            bge not_lower
                            sec
                            sbc #'a'-'A'
                            sta <wKey
not_lower                   anop

                            ldx #0
loop                        lda key_jmp_table,x
                            beq not_found
                            cmp <wKey
                            beq found
                            inx
                            inx
                            inx
                            inx
                            bra loop

; didn't handle the key press, try the debug keys
not_found                   anop
                            sec                     ; assume not handled
                            bit appdebug~debug_mode
                            bpl done
; Check the top-level debug keys
                            ldx #0
loop2                       lda debug_key_jmp_table,x
                            beq not_used2
                            cmp <wKey
                            beq found2
                            inx
                            inx
                            inx
                            inx
                            bra loop2

; didn't handle the key press, try the debug panel handlers
not_used2                   jsr check_debug_handlers

done                        anop
                            restoredatabank
                            retkc

found                       inx
                            inx
                            jsr (key_jmp_table,x)
                            bcc done                                            ; was the key actually used?
                            bra not_found                                       ; no, check the debug keys

found2                      inx
                            inx
                            jsr (debug_key_jmp_table,x)
                            bcc done                                            ; was the key actually used?
                            bra not_used2                                       ; no, check the debug handlers.

; Internal functions

check_debug_handlers        anop

                            lda appdebug~handler_display_mode
                            bne no_handlers
; Do all the installed debug handlers
; Note, we pass keys to all handlers, even if they are disabled.
; If a handler is disabled, it should only be listening for its key that turns it on.
; We are, however, passing the key to the enabled ones first, then the disabled ones, in case a handler
; that is enabled, uses the 'enable' key that another uses, while it is enabled.
; Overall, they key usage can become a bit of a PITA, and maybe having multiple debug panels
; at once isn't great, though it can be useful.

                            lda debug_handlers~count
                            beq no_handlers
                            sta <wCount
; I need the data bank, as a word
                            phb
                            phb
                            pla
                            and #$00ff
                            sta <wLocalBank

                            ldx #debug_handlers~array

handler_loop_enabled        anop
                            getword {x},#debug_handler~enabled
                            beq next_handler1

                            getword {x},#debug_handler~key_pressed+1
                            beq next_handler1                       ; if 0, then no handler
                            sta patch1+2
                            getword {x},#debug_handler~key_pressed
                            sta patch1+1

                            phx                                     ; save the index
; Push the address of the handler
                            pushsword <wLocalBank
                            phx
; Push the key
                            pushsword <wKey

patch1                      jsl $ffffff

                            plx                                     ; Get our index back
                            bcc handled

next_handler1               txa                                     ; advance to the next one
                            clc
                            adc #sizeof~debug_handler
                            tax
                            dec <wCount
                            bne handler_loop_enabled

                            lda debug_handlers~count
                            sta <wCount
                            ldx #debug_handlers~array

; Then do the disabled ones, to allow them to turn themselves on
handler_loop_disabled       anop
                            getword {x},#debug_handler~enabled
                            bne next_handler2

                            getword {x},#debug_handler~key_pressed+1
                            beq next_handler2                       ; if 0, then no handler
                            sta patch2+2
                            getword {x},#debug_handler~key_pressed
                            sta patch2+1

                            phx                                     ; save the index
; Push the address of the handler
                            pushsword <wLocalBank
                            phx
; Push the key
                            pushsword <wKey

patch2                      jsl $ffffff

                            plx                                     ; Get our index back
                            bcc handled

next_handler2               txa                                     ; advance to the next one
                            clc
                            adc #sizeof~debug_handler
                            tax
                            dec <wCount
                            bne handler_loop_disabled

no_handlers                 sec

handled                     rts

;;
increase_delay              anop
                            inc appdata~wait_time
                            clc
                            rts

reduce_delay                lda appdata~wait_time
                            beq key_used                        ; can't go lower
                            dec a
                            sta appdata~wait_time
key_used                    clc
                            rts
;;
reset_player                jsl gameplay_player_reset
                            clc
                            rts
;;
toggle_vbl                  lda >grlib~wait_for_vbl
                            eor #$8000
                            sta >grlib~wait_for_vbl
                            clc                                                 ; signal we handled the keypress
                            rts
;;
toggle_text_mode            anop
                            lda >grlib~in_text_mode
                            eor #grlib~switch_on
                            jsl grlib_set_text_mode
                            clc                                                 ; signal we handled the keypress
                            rts
;;
toggle_debug_help           anop
                            lda >grlib~in_text_mode
                            beq not_in_text_mode
; Swap the mode and force the screen to clear
                            lda appdebug~handler_display_mode
                            eor #appdebug~handler_display~help
                            sta appdebug~handler_display_mode
;                           jsl appdebug_disable_all_handlers
                            lda #$ffff
                            sta appdebug~clear_text_screen
                            clc                                                 ; signal we handled the keypress
                            rts
not_in_text_mode            sec
                            rts
;;
want_break                  anop
no_break_keypress           jsl get_key_press
                            beq no_break_keypress
                            jsl get_hex_digit_from_key
                            bcs skip_break
                            ora #$8000
                            sta >grlib~do_break
skip_break                  clc                                                 ; signal we handled the keypress
                            rts

toggle_pause                lda >grlib~in_text_mode                             ; don't do this if in text mode
                            beq toggle_pause2
                            sec
                            rts
toggle_pause2               jsl app_toggle_paused
                            clc                                                 ; signal we handled the keypress
                            rts

toggle_update_rects         lda appdata~debug_update_rects
                            beq turn_on_update_rects
                            lda #0
                            sta appdata~debug_update_rects
                            clc
                            rts
turn_on_update_rects        lda >input~last_key_down_modifiers
                            bit #ssw~key_down_shift
                            beq turn_on_update_rects_wait
                            lda #%00000001                                      ; pause
                            sta appdata~debug_update_rects
                            clc
                            rts
turn_on_update_rects_wait   lda #%00000011                                      ; wait
                            sta appdata~debug_update_rects
                            clc
                            rts
;
toggle_collision_rects      lda appdata~debug_collision_rects
                            beq turn_on_collision_rects
                            lda #0
                            sta appdata~debug_collision_rects
                            clc
                            rts
turn_on_collision_rects     lda >input~last_key_down_modifiers
                            bit #ssw~key_down_shift
                            beq turn_on_collision_rects_wait
                            lda #%00000001                                      ; pause
                            sta appdata~debug_collision_rects
                            clc
                            rts
turn_on_collision_rects_wait lda #%00000011                                     ; wait
                            sta appdata~debug_collision_rects
                            clc
                            rts

stun_sinistar               anop
                            lda >grlib~in_text_mode
                            bne ignore_in_text_mode
                            lda >gameplay_sinistar_logic~in_stun
                            bne unstun
                            lda #60*60                                          ; will be counted down in his logic tick
                            sta >gameplay_sinistar_logic~in_stun
                            clc
                            rts
unstun                      lda #0
                            sta >gameplay_sinistar_logic~in_stun
                            clc
                            rts
ignore_in_text_mode         sec
                            rts
;;
test_speech                 anop
                            lda >grlib~in_text_mode
                            bne ignore_in_text_mode
                            pushsword #id_sfx~beware_i_live
                            jsl gameplay_sinistar_play_speech
                            clc
                            rts

;force_keyed_break           lda #$8007
;                            sta >grlib~do_break
;                            clc
;                            rts

get_hex_digit_from_key      entry
                            cmp #'0'
                            blt not_digit
                            cmp #'9'+1
                            bge next_range
                            sec
                            sbc #'0'
                            bra got_digit
next_range                  cmp #'A'
                            blt next_range2
                            cmp #'F'+1
                            bge next_range2
                            sec
                            sbc #'A'-10
                            bra got_digit
next_range2                 cmp #'a'
                            blt not_digit
                            cmp #'f'+1
                            bge not_digit
                            sec
                            sbc #'a'-10

got_digit                   clc
                            rtl
not_digit                   sec
                            rtl

; These keys are always checked in all modes
key_jmp_table               anop
; Pause, non-control key only works when showing the game, so it doesn't conflict with debug keys
                            dc c'P',i1'0'
                            dc a'toggle_pause'
                            dc i'$0010'                                 ; ctrl-p
                            dc a'toggle_pause2'

                            dc i'0'

; These keys are only checked, if appdebug~debug_mode is true
debug_key_jmp_table         anop
                            dc c'{',i1'0'
                            dc a'reduce_delay'
                            dc c'}',i1'0'
                            dc a'increase_delay'
;                            dc c'7',i1'0'
;                            dc a'force_keyed_break'
; Reset Player Location.  Maybe remove, now that the game is mostly working
;                           dc c'R',i1'0'
;                           dc a'reset_player'
; Toggle VBL wait
                            dc c'V',i1'0'
                            dc a'toggle_vbl'
; Toggle Text / Debug mode
                            dc c'T',i1'0'
                            dc a'toggle_text_mode'
; Toggle Debug Help
                            dc c'/',i1'0'
                            dc a'toggle_debug_help'
                            dc c'?',i1'0'
                            dc a'toggle_debug_help'

; Want a keyed-break
; Keyed breaks can be disabled
                            aif C:debug~use_keyed_breaks=0,.skip
                            dc i'$0002'                                 ; ctrl-b
                            dc a'want_break'
.skip

; Toggle Update Rect drawing
                            dc i'$0016'                                 ; ctrl-v
                            dc a'toggle_update_rects'
; Toggle Collision Rect drawing
                            dc i'$0004'                                 ; ctrl-d    (wanted control-c, but that exits mame)
                            dc a'toggle_collision_rects'

; Stun/un-stun sinistar
;                           dc c'S',i1'0'
;                           dc a'stun_sinistar'

;                           dc c'I',i1'0'
;                           dc a'test_speech'

                            dc i'0'                                     ; list terminator

                            end

; -----------------------------------------------------------------------------
; Install a debug handler
; Parameters:
; pHandler      - the handler to install
; wEnabled      - true, to enable after installing
appdebug_install_handler    start seg_app
                            using appdebug_data

                            begin_locals
wPriority                   decl word
work_area_size              end_locals

                            sub (4:pHandler,2:wEnabled),work_area_size

                            setlocaldatabank
                            lda debug_handlers~count
                            cmp #debug_handlers~max_count
                            jge no_install

                            ldx #debug_handlers~array
                            cmp #0
                            beq add_at                             ; nothing in there, just add it at 0
; See where that fits in the list

; Get the priority
                            getword [<pHandler],#debug_handler~priority
                            sta <wPriority

                            ldy #0
check_loop                  getword {x},#debug_handler~priority
                            cmp <wPriority
                            bge insert_here
                            txa
                            clc
                            adc #sizeof~debug_handler
                            tax
                            iny
                            cpy #debug_handlers~max_count
                            bne check_loop
                            bra add_at                              ; if we reach here, we are adding at the end
; Insert where X is pointing, and Y has the index of that location in the array
insert_here                 anop
                            phx                                     ; save the location
                            tya
                            negate a                                ; negate the index
                            clc
                            adc debug_handlers~count                ; add to the count, to get the remaining
                            phx
                            ldx #sizeof~debug_handler
                            jsl math~umul1r2
                            plx
; A has the amount to move
                            dec a                                   ; mvp needs - 1
                            pha                                     ; gotta save it though.

                            txa                                     ; X has top of the buffer to move
                            clc
                            adc 1,s
                            tax                                     ; x now has the bottom - 1
                            adc #sizeof~debug_handler
                            tay                                     ; Y has destination
; Set the banks.  Conveniently, they are both the same
                            phb
                            phb
                            pla                                     ; have the same bank in high and low
                            sta patch_move+1                        ; patch it!
                            pla                                     ; get the length - 1 back
patch_move                  mvp $000000,$000000                     ; X and Y will go backward.  How this opcode is used, without self-modifiying code, I don't know.
                            plx                                     ; get the desintation back

add_at                      getword [<pHandler],#debug_handler~id
                            putword {x},#debug_handler~id
                            getword [<pHandler],#debug_handler~priority
                            putword {x},#debug_handler~priority
                            getword [<pHandler],#debug_handler~text_display
                            putword {x},#debug_handler~text_display
                            getword [<pHandler],#debug_handler~text_display+2
                            putword {x},#debug_handler~text_display+2
                            getword [<pHandler],#debug_handler~help_display
                            putword {x},#debug_handler~help_display
                            getword [<pHandler],#debug_handler~help_display+2
                            putword {x},#debug_handler~help_display+2
                            getword [<pHandler],#debug_handler~key_pressed
                            putword {x},#debug_handler~key_pressed
                            getword [<pHandler],#debug_handler~key_pressed+2
                            putword {x},#debug_handler~key_pressed+2

; Set to disabled
                            putzero {x},#debug_handler~enabled
                            putzero {x},#debug_handler~status

                            inc debug_handlers~count

                            lda <wEnabled
                            beq keep_disabled
; Turn off all others, at the same priority, then enable us
; This will make it so that only one of each priority is on, as the handlers are registered.
; Might want to just leave them all off, and have the app startup decided if any are on.
                            phx
                            pushsword <wPriority
                            jsl appdebug_disable_handlers_of_priority
                            plx
                            lda #$ffff
                            putword {x},#debug_handler~enabled

keep_disabled               clc
exit                        restoredatabank
                            retkc
no_install                  anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Disable all handlers
appdebug_disable_all_handlers start seg_app
                            using appdebug_data

                            setlocaldatabank
                            ldy debug_handlers~count
                            beq exit

                            ldx #debug_handlers~array
check_loop                  getword {x},#debug_handler~enabled
                            beq next
                            putzero {x},#debug_handler~enabled
; Assume that changing the enabled state, is going to require everything to update
                            lda #1
                            sta appdebug~clear_text_screen
next                        txa
                            clc
                            adc #sizeof~debug_handler
                            tax
                            dey
                            bne check_loop
exit                        restoredatabank
                            rtl

                            end

; -----------------------------------------------------------------------------
; Disable all handlers that have the specified priority
appdebug_disable_handlers_of_priority start seg_app
                            using appdebug_data

                            begin_locals
work_area_size              end_locals

                            sub (2:wPriority),work_area_size

                            setlocaldatabank
                            ldy debug_handlers~count
                            beq exit

                            ldx #debug_handlers~array
check_loop                  getword {x},#debug_handler~priority
                            cmp <wPriority
                            bne next
                            getword {x},#debug_handler~enabled
                            beq next
                            putzero {x},#debug_handler~enabled
; Assume that changing the enabled state, is going to require everything to update
                            lda #1
                            sta appdebug~clear_text_screen
next                        txa
                            clc
                            adc #sizeof~debug_handler
                            tax
                            dey
                            bne check_loop
exit                        restoredatabank
                            ret

                            end
; -----------------------------------------------------------------------------
; Update the text screen, drawing any active panels
appdebug_update_text_screen start seg_app
                            using appdata
                            using grlib_global_data
                            using applib_data
                            using appdebug_data
                            using inputlib_data

                            debugtag 'update_text_screen'

                            setlocaldatabank

; Print it, if we are in text mode
                            lda >grlib~in_text_mode
                            bmi mode_on
; Off.  Clear our own flag and exit.  Maybe support informing the handlers that the text mode is off?
                            stz appdebug~in_text_mode
                            restoredatabank
                            rtl

; The text mode is on
mode_on                     anop
; Get our switch to see if this is the first time
                            bit appdebug~in_text_mode
                            bmi was_on
; First time the mode has been turned on, since we last saw it.
                            dec appdebug~in_text_mode           ; make non-zero
; clear the status of the handlers, so they get notified that this is the first-display
                            jsr reset_handler_display_status

was_on                      anop

; Do we need a full 'clear'?
                            lda appdebug~clear_text_screen
                            beq no_clear
                            stz appdebug~clear_text_screen
                            pushsword #$20
                            jsl textbox_clear

no_clear                    anop
                            pushsword #0
                            pushsword #0
                            jsl textbox_set_cursor
                            jsl textbox_clear_options

                            ldx appdebug~handler_display_mode
                            jsr (handler_display_mode_table,x)

exit                        anop
                            restoredatabank
                            rtl

;;;
handler_display_mode_table  anop
                            dc a'draw_handler_info'
                            dc a'draw_handler_help'
;;
draw_handler_info           anop
                            jsr display_basic_debug_info                        ; Maybe make this into its own handler?

; Do all the installed debug handlers
                            lda debug_handlers~count
                            beq no_handlers
                            sta count
                            lda #debug_handlers~array
                            tax

handler_loop                getword {x},#debug_handler~enabled
                            bpl skip_handler

                            getword {x},#debug_handler~text_display+1
                            sta patch+2
                            getword {x},#debug_handler~text_display
                            sta patch+1

                            phx
; Get the handler status to pass in.  We are storing each, individually, so that we can
; enable / disable handlers, while the text display is up, and they will get properly notified that
; this is their first time to display
                            pushsword {x},#debug_handler~status
; Store that we displayed it.
                            ora #debug_handler~status~displayed
                            putword {x},#debug_handler~status

patch                       jsl $ffffff

                            plx                                     ; Get our index back

skip_handler                txa                                     ; advance to the next one
                            clc
                            adc #sizeof~debug_handler
                            tax
                            dec count
                            bne handler_loop

no_handlers                 anop
                            rts

;;
draw_handler_help           anop
                            jsr display_basic_debug_help

; Do all the installed debug handlers
                            lda debug_handlers~count
                            beq no_handlers
                            sta count
                            lda #debug_handlers~array
                            tax

handler_help_loop           getword {x},#debug_handler~help_display+1
                            beq no_help_func
                            sta patch_help+2
                            getword {x},#debug_handler~help_display
                            sta patch_help+1

                            phx

patch_help                  jsl $ffffff

                            plx                                     ; Get our index back

no_help_func                txa                                     ; advance to the next one
                            clc
                            adc #sizeof~debug_handler
                            tax
                            dec count
                            bne handler_help_loop
                            rts

; Local function to reset the status on all the handlers
reset_handler_display_status anop
                            ldy debug_handlers~count
                            beq reset_no_handlers
                            lda #debug_handlers~array
                            tax

reset_handler_loop          putzero {x},#debug_handler~status           ; won't change A
                            clc
                            adc #sizeof~debug_handler
                            tax
                            dey
                            bne reset_handler_loop
reset_no_handlers           rts

; Local function for displaying some basic debug info, such as the FPS, and the last key pressed
display_basic_debug_info    anop
; Display the FPS
                            pushptr #fps_string
                            jsl textbox_print_string

                            pushsword >applib~fps_current
                            jsl textbox_print_decimal_word
                            pushsword #$20
                            jsl textbox_print_char

                            pushptr #lastkey_string
                            jsl textbox_print_string
; Show the last key down
                            pushsword >input~last_key_down
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char
; Show last key up
                            pushsword >input~last_key_up
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char
; Show modifiers
                            pushsword >input~last_key_modifiers
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char

; Show if VBL is on or off
                            ldx #'V'
                            lda >grlib~wait_for_vbl
                            bmi vbl_on
                            ldx #' '
vbl_on                      anop
                            phx
                            jsl textbox_print_char
; Show if the alt-screen is in shadowed memory or not
                            ldx #'S'
                            lda >grlib~altscr_is_shadowed
                            bmi shadowed
                            ldx #' '
shadowed                    anop
                            phx
                            jsl textbox_print_char

                            jsl textbox_newline
                            rts

;;
; Draw some basic help
display_basic_debug_help    anop
                            pushptr #basic_help1
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help2
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help3
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help4
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help5
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help6
                            jsl textbox_print_string
                            jsl textbox_newline
                            jsl textbox_newline
                            pushptr #basic_help7
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help8
                            jsl textbox_print_string
                            jsl textbox_newline
                            rts

count                       ds 2

fps_string                  cstring 'FPS:'
lastkey_string              cstring 'Key:'

basic_help1                 cstring 'Keys active while the game is running:'
basic_help2                 cstring '[T] Toggles Text Display'
basic_help3                 cstring '[{ and }] Lowers or adds a tick delay between frames'
basic_help4                 cstring '[ctrl-V] Toggle Update rectangle drawing'
basic_help5                 cstring '[ctrl-D] Toggle Collsion rectangle drawing'
basic_help6                 cstring 'Top line shows FPS, last key down/up, key-modifiers [V]BL & Shadow Memory usage'
basic_help7                 cstring 'Panel activation keys to show/hide a panel:'
basic_help8                 cstring '[/ or ?] - Toggles help panel (this panel)'
                            end

; -----------------------------------------------------------------------------
; Get the palette from a shape.  Note this assumes that there is a
; datalib_shapedef header *before* where the input pointer is pointing to.
set_palette_from_shape      start seg_app

                            debugtag 'set_palette_from_shape'

                            begin_locals
pPalette                    decl ptr
pDatalibHeader              decl ptr
pDataEntry                  decl ptr
pTypeEntry                  decl ptr
pLibrary                    decl ptr
work_area_size              end_locals

                            sub (4:pShape),work_area_size          ; Parameters, plus the amount of space for our local work area

; Must get a pointer backward, since we can't index backward
                            lda <pShape
                            sec
                            sbc #sizeof~datalib_shapedef
                            sta <pDatalibHeader
                            lda <pShape+2
                            sbc #0
                            sta <pDatalibHeader+2

; Lots of dereferencing.  Not done often, but maybe the datalib_shapedef keeps the library pointer cached too?
                            getptr [<pDatalibHeader],#datalib_shapedef~data_entry_ptr,<pDataEntry
                            getptr [<pDataEntry],#datalib_data_entry~type_ptr,<pTypeEntry
                            getptr [<pTypeEntry],#datalib_type_entry~library_ptr,<pLibrary
; Get the palette
                            pushptr <pLibrary
                            pushdword #datalib_type_PALT
                            pushptr [<pShape],#shapedef~metadata_id
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            bcs exit
                            putretptr <pPalette

                            pushptr <pPalette
                            pushsword #0
                            jsl grlib_set_shr_palette

exit                        ret

                            end

; -----------------------------------------------------------------------------
; Debug function to copy some memory to a buffer, that we can then compare against later
debug_copy_memory_to_buffer start seg_app
                            using appdebug_data

                            begin_locals
work_area_size              end_locals

                            sub (4:pSrc,2:wSize),work_area_size

                            lda <wSize
                            and #$fffe              ; only going to support a multiple of 2
                            beq exit
                            setlocaldatabank
                            cmp #debug~max_compare_buffer
                            tay
                            dey
                            dey
loop                        anop
                            lda [<pSrc],y
                            sta debug_compare_buffer,y
                            dey
                            dey
                            bpl loop
                            restoredatabank

exit                        ret

                            end

; -----------------------------------------------------------------------------
; Debug function to copy some memory to a buffer, that we can then compare against later
debug_compare_memory_to_buffer start seg_app
                            using appdebug_data

                            begin_locals
work_area_size              end_locals

                            sub (4:pSrc,2:wSize,2:wBreak),work_area_size

                            lda <wSize
                            and #$fffe              ; only going to support a multiple of 2
                            beq exit
                            setlocaldatabank
                            cmp #debug~max_compare_buffer
                            tay
                            dey
                            dey
loop                        anop
                            lda [<pSrc],y
                            cmp debug_compare_buffer,y
                            bne different
                            dey
                            dey
                            bpl loop
done                        restoredatabank

exit                        ret

different                   lda <wBreak
                            and #$00ff                      ; put the code in the upper byte, and with the lower byte == 0, we have a full brk instruction
                            xba
                            sta break_code
break_code                  brk $01
                            bra done

                            end
