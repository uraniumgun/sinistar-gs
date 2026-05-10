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

                            copy source/gameplay.constants.asm
                            copy source/task.definitions.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/app.debug.definitions.asm
                            copy source/app.ui.definitions.asm

                            mcopy generated/gameplay.difficulty.debug.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; A debug handler for the difficulty system
gameplay_difficulty_debug_handler_show_info start seg_gameplay
                            using appdata
                            using appdebug_data
                            using textlib_global_data
                            using applib_data
                            using grlib_global_data
                            using inputlib_data
                            using task_manager_data
                            using playfield_manager_data
                            using worker_entity_manager_data
                            using warrior_entity_manager_data
                            using rock_entity_manager_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_level_data

                            begin_locals
wStartLine                  decl word
work_area_size              end_locals

type_column_width           equ 22
target_column_width         equ 12
value_column_width          equ 12

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

                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #str_title
                            jsl textbox_print_string

                            pushsword #target_column_width
                            jsl textbox_next_column
                            pushptr #str_target
                            jsl textbox_print_string

                            pushsword #value_column_width
                            jsl textbox_next_column
                            pushptr #str_value
                            jsl textbox_print_string

                            jsl textbox_next_row_end_columns
                            jsl textbox_set_option_normal

; Timer
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #str_timer
                            jsl textbox_print_string

                            pushsword #target_column_width
                            jsl textbox_next_column
                            getword gameplay_manager~active_state+player_state~difficulty_timer
                            jsr _print_fp16

                            jsl textbox_next_row_end_columns

; Workers
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #str_workers
                            jsl textbox_print_string

                            pushsword #target_column_width
                            jsl textbox_next_column
                            getword gameplay_manager~active_state+player_state~desired_pop~workers
                            jsr _print_fp16

                            pushsword #value_column_width
                            jsl textbox_next_column
                            pushsword >worker_entity_count
                            jsl textbox_print_hex_word
                            jsl textbox_next_row_end_columns

; Warriors
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #str_warriors
                            jsl textbox_print_string

                            pushsword #target_column_width
                            jsl textbox_next_column
                            getword gameplay_manager~active_state+player_state~desired_pop~warriors
                            jsr _print_fp16

                            pushsword #value_column_width
                            jsl textbox_next_column
                            pushsword >warrior_entity_count
                            jsl textbox_print_hex_word
                            jsl textbox_next_row_end_columns

; Planetoids 1
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #str_planetoids1
                            jsl textbox_print_string

                            pushsword #target_column_width
                            jsl textbox_next_column
                            getword gameplay_manager~active_state+player_state~desired_pop~planetoids1
                            jsr _print_fp16

                            pushsword #value_column_width
                            jsl textbox_next_column
                            pushsword >rock_entity_variation_count+(0*2)
                            jsl textbox_print_hex_word
                            jsl textbox_next_row_end_columns

; Planetoids 3
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #str_planetoids3
                            jsl textbox_print_string

                            pushsword #target_column_width
                            jsl textbox_next_column
                            getword gameplay_manager~active_state+player_state~desired_pop~planetoids3
                            jsr _print_fp16

                            pushsword #value_column_width
                            jsl textbox_next_column
                            pushsword >rock_entity_variation_count+(2*2)
                            jsl textbox_print_hex_word
                            jsl textbox_next_row_end_columns

; Planetoids 5
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #str_planetoids5
                            jsl textbox_print_string

                            pushsword #target_column_width
                            jsl textbox_next_column
                            getword gameplay_manager~active_state+player_state~desired_pop~planetoids5
                            jsr _print_fp16

                            pushsword #value_column_width
                            jsl textbox_next_column
                            pushsword >rock_entity_variation_count+(4*2)
                            jsl textbox_print_hex_word
                            jsl textbox_next_row_end_columns

; Warrior Aggression
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #str_warrior_aggression
                            jsl textbox_print_string

                            pushsword #target_column_width
                            jsl textbox_next_column
                            getword gameplay_manager~active_state+player_state~warrior_aggression
                            jsr _print_fp16

                            jsl textbox_next_row_end_columns

;
                            jsl textbox_clear_options

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

_print_fp16                 anop
                            pha
                            xba
                            and #$ff
                            pha
                            jsl textbox_print_hex_byte

                            lda #'.'
                            pha
                            jsl textbox_print_char
                            pla
                            and #$ff
                            pha
                            jsl textbox_print_hex_byte
                            rts

str_title                   cstring 'Difficulty'
str_target                  cstring 'Target'
str_value                   cstring 'Current'

str_timer                   cstring 'Timer'
str_workers                 cstring 'Workers'
str_warriors                cstring 'Warriors'
str_planetoids1             cstring 'Planetoids 1'
str_planetoids3             cstring 'Planetoids 3'
str_planetoids5             cstring 'Planetoids 5'
str_warrior_aggression      cstring 'Aggression'

prev_draw_lines             dc i'0'

                            end

; ----------------------------------------------------------------------------
; Draw the help for this handler
gameplay_difficulty_debug_handler_show_help start seg_gameplay

                            pushptr #basic_help1
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help2
                            jsl textbox_print_string
                            jsl textbox_newline

                            rtl

basic_help1                 cstring '[D] - Gameplay Difficulty Internal State'
basic_help2                 cstring '      This shows the current population adjustments and warrior aggression'

                            end

; -----------------------------------------------------------------------------
gameplay_difficulty_debug_handler_keypress start seg_gameplay
                            using appdata
                            using worker_entity_manager_data
                            using warrior_entity_manager_data
                            using gameplay_manager_data
                            using appdebug_data
                            using textlib_global_data
                            using applib_data
                            using grlib_global_data

                            begin_locals
work_area_size              end_locals

                            sub (4:pHandler,2:wKey),work_area_size

                            lda >grlib~in_text_mode
                            jeq not_handled                                 ; Don't handle any keys if not in text mode

                            getword [<pHandler],#debug_handler~enabled
                            beq not_enabled

; We are enabled
                            lda <wKey
                            cmp #'D'
                            beq disable

                            bra not_handled

disable                     anop
                            lda #0
                            putword [<pHandler],#debug_handler~enabled
                            lda #$ffff
                            sta >appdebug~clear_text_screen
                            bra handled

; We are not enabled, the only key we listen for, is the one to enable us
not_enabled                 lda <wKey
                            cmp #'D'
                            beq enable
                            cmp #'d'
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
