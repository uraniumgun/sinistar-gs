                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/input.constants.asm

                            copy source/app.debug.definitions.asm

                            mcopy generated/system.debug.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
system_debug_data           data seg_app
                            using appdata

; Debug Handler
system_debug_handler_priority equ $0001

system_debug_handler        dc i'system_debug_handler_id'
                            dc i'system_debug_handler_priority'
                            dc a4'system_debug_handler_show_info'
                            dc a4'system_debug_handler_show_help'
                            dc a4'system_debug_handler_keypress'

                            end

; ----------------------------------------------------------------------------
system_debug_initialize     start seg_app
                            using system_debug_data

                            debugtag 'initialize_system_debug'

                            setlocaldatabank

; Install the debug handler
                            pushptr #system_debug_handler
                            pushsword #0                                    ; start off disabled
                            jsl appdebug_install_handler

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
; A debug handler for some general system related items
; Uses the current textbox location.
system_debug_handler_show_info start seg_app
                            using appdata
                            using appdebug_data
                            using applib_data
                            using textlib_global_data
                            using grlib_global_data
                            using inputlib_data
                            using playfield_manager_data
                            using softswitch_definitions

                            begin_locals
wStartLine                  decl word
wColumn                     decl word
wColor                      decl word
wPalette                    decl word
wOffset                     decl word
dwPositiveCounter           decl long
dwNegativeCounter           decl long
work_area_size              end_locals

type_column_width           equ 22
state_column_width          equ 12

                            sub (2:wStatus),work_area_size
                            setlocaldatabank

                            lda <wStatus
                            bit #debug_handler~status~displayed
                            bne not_first
; First time here
                            stz prev_draw_lines

not_first                   anop

                            lda >textbox_primary~cursor_y
                            sta <wStartLine

                            lda #textbox_option~inverse+textbox_option~line_fill
                            jsl textbox_set_options
                            pushptr #palettes_title_string
                            jsl textbox_print_string
                            jsl textbox_newline
                            jsl textbox_set_option_normal


                            pushptr #playfield_title_string
                            jsl textbox_print_string
                            lda >playfield_view~palette_shr_slot
                            pha
                            jsl textbox_print_hex_byte
                            jsl textbox_newline

                            pushptr #ui_upper_title_string
                            jsl textbox_print_string
                            lda appdata~ui_upper_shr_palette_slot
                            pha
                            jsl textbox_print_hex_byte
                            jsl textbox_newline

                            pushptr #ui_lower_title_string
                            jsl textbox_print_string
                            lda appdata~ui_lower_shr_palette_slot
                            pha
                            jsl textbox_print_hex_byte
                            jsl textbox_newline

                            jsl textbox_newline

; Palettes
                            stz <wPalette
                            stz <wOffset

print_palette_count         equ 4

palette_loop                jsr _print_palette
                            jsl textbox_newline
                            inc <wPalette
                            lda <wPalette
                            cmp #print_palette_count
                            bne palette_loop

;                           jsr _test_vbl

; exit
                            lda >textbox_primary~cursor_y
                            sec
                            sbc <wStartLine
                            sta <wStartLine

                            lda prev_draw_lines
                            sec
                            sbc <wStartLine
                            bcc no_erase
                            beq no_erase
; We have to erase some previous lines
                            pha
                            pushsword #$20
                            jsl textbox_fill_lines

no_erase                    lda <wStartLine
                            sta prev_draw_lines

                            restoredatabank
                            ret

;;; Local functions
;;;
_print_palette              anop
                            lda #0
                            sta >textbox_primary~cursor_x

colors_per_line             equ 8
                            lda #colors_per_line
                            sta <wColumn
                            lda #16
                            sta <wColor

; Print a single hex digit for the palette number
                            lda <wPalette
                            cmp #10
                            bge ge_10
                            adc #'0'
                            bra lt_10
ge_10                       adc #'A'-1
lt_10                       pha
                            jsl textbox_print_char

color_loop                  pushsword #$20
                            jsl textbox_print_char

; print a 24-bit hex value, it will be RRGGBB
                            ldx <wOffset
                            lda >grlib~shr_palettes,x
                            pha
                            jsl textbox_print_hex_word
                            inc <wOffset
                            inc <wOffset

                            dec <wColor
                            beq done_palette

                            dec <wColumn
                            bne color_loop

                            lda #colors_per_line
                            sta <wColumn
                            jsl textbox_newline
                            pushsword #$20
                            jsl textbox_print_char
                            bra color_loop
done_palette                anop
                            jsl textbox_newline

                            rts

; A test to see what state the highbit of ssw~rdvbl ($C019) is, when the screen is 'in' the VBL.
; The hardware docs say one thing, Tech Note #40 says another. (The Tech Note is correct)
; However, up until MAME 281, it was reversed, functioning like the IIe did.
; Why it was reversed on the IIgs?  Probably a HW bug.

                            ago .skip
_test_vbl                   anop
                            clearptr <dwPositiveCounter
                            clearptr <dwNegativeCounter

; Get a good 'sync'
                            shortm
vloop_wait1                 lda >ssw~rdvbl
                            bmi vloop_wait1
vloop_wait2                 lda >ssw~rdvbl
                            bpl vloop_wait2
vloop_wait3                 lda >ssw~rdvbl
                            bmi vloop_wait3
                            longm

; Start counting.  I'm keeping to 16-bit mode and reading off-by-one, which should be fine.
; Future-proofing and counting a 32-bit number, even though we will never get close to that, even at 8Mhz.
; At 8Mhz, that is still only 133,333 cycles and realistically, the inc is 8, because DP will probably have a
; non-page aligned lower byte, the branch is 3 most of the time, and the load of the softswitch is 6.
; and then another 3 for the branch, so 20 cycles, so at most, it might increment to 6,666.
; And, of course, hitting the softswitch is probably making the CPU go to 1Mhz briefly.
; Overall, I'm looking just for a relative value and not a cycle count
vloop_pos                   inc <dwPositiveCounter
                            bne no_rollover1
                            inc <dwPositiveCounter+2
no_rollover1                lda >ssw~rdvbl-1
                            bpl vloop_pos

vloop_neg                   inc <dwNegativeCounter
                            bne no_rollover2
                            inc <dwNegativeCounter+2
no_rollover2                lda >ssw~rdvbl-1
                            bmi vloop_neg

; We should now have a 32-bit counter for how long we were in the positive and negative switch states.
; The 'shorter' one, should be 'in-the-vbl'

                            pushptr #str_vbl_positive
                            jsl textbox_print_string

                            pushsword <dwPositiveCounter+2
                            jsl textbox_print_hex_word
                            pushsword <dwPositiveCounter
                            jsl textbox_print_hex_word

                            pushptr #str_vbl_negative
                            jsl textbox_print_string

                            pushsword <dwNegativeCounter+2
                            jsl textbox_print_hex_word
                            pushsword <dwNegativeCounter
                            jsl textbox_print_hex_word
                            jsl textbox_newline
                            rts
str_vbl_positive            cstring 'VBL: Positive:'
str_vbl_negative            cstring ', Negative:'
.skip

palettes_title_string       cstring 'Palettes'
playfield_title_string      cstring 'Playfield palette: '
ui_upper_title_string       cstring 'UI upper palette:  '
ui_lower_title_string       cstring 'UI lower palette:  '

prev_draw_lines             dc i'0'
                            end

; ----------------------------------------------------------------------------
; Draw the help for this handler
system_debug_handler_show_help start seg_app

                            pushptr #basic_help1
                            jsl textbox_print_string
                            jsl textbox_newline

                            rtl

basic_help1                 cstring '[~] - Show various system level values'

                            end

; -----------------------------------------------------------------------------
system_debug_handler_keypress start seg_app
                            using appdata
                            using appdebug_data
                            using applib_data
                            using grlib_global_data
                            using textlib_global_data

                            begin_locals
work_area_size              end_locals

                            sub (4:pHandler,2:wKey),work_area_size

                            getword [<pHandler],#debug_handler~enabled
                            beq not_enabled

; We are enabled
                            lda >grlib~in_text_mode
                            beq not_handled                                 ; Don't handle any keys if not in text mode

                            lda <wKey
                            cmp #'~'
                            bne not_handled

disable                     anop
                            lda #0
                            putword [<pHandler],#debug_handler~enabled
                            lda #$ffff
                            sta >appdebug~clear_text_screen
                            bra handled

; We are not enabled, the only key we listen for, is the one to enable us
not_enabled                 lda <wKey
                            cmp #'~'
                            bne not_handled

enable                      jsl appdebug_disable_all_handlers                           ; Disable everything else

                            lda #$ffff
                            putword [<pHandler],#debug_handler~enabled
                            sta >appdebug~clear_text_screen

handled                     clc
exit                        retkc
not_handled                 sec
                            bra exit

                            end
