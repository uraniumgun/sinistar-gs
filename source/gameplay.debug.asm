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

                            mcopy generated/gameplay.debug.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; A debug handler for general gameplay options.
; Uses the current textbox location.
gameplay_debug_handler_show_info start seg_gameplay
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
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_level_data

                            begin_locals
wStartLine                  decl word
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
                            pushptr #title_string
                            jsl textbox_print_string
                            jsl textbox_newline
                            jsl textbox_set_option_normal

; Ships
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #ships_string
                            jsl textbox_print_string

                            pushsword #state_column_width
                            jsl textbox_next_column
                            pushsword >gameplay_manager~cheat~unlimited_ships
                            jsl textbox_print_hex_word

                            jsl textbox_next_row_end_columns

; Add Ship
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #add_ship_string
                            jsl textbox_print_string

                            jsl textbox_next_row_end_columns

; Simibombs
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #bombs_string
                            jsl textbox_print_string

                            pushsword #state_column_width
                            jsl textbox_next_column
                            pushsword >gameplay_manager~cheat~unlimited_sinibombs
                            jsl textbox_print_hex_word

                            jsl textbox_next_row_end_columns

; Worker
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #workers_string
                            jsl textbox_print_string

                            pushsword #state_column_width
                            jsl textbox_next_column
                            pushsword >worker_entity_limit
                            jsl textbox_print_hex_word

                            jsl textbox_next_row_end_columns

; Warrior
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #warriors_string
                            jsl textbox_print_string

                            pushsword #state_column_width
                            jsl textbox_next_column
                            pushsword >warrior_entity_limit
                            jsl textbox_print_hex_word

                            jsl textbox_next_row_end_columns

; Crystal Attraction
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #crystal_attraction_string
                            jsl textbox_print_string

                            pushsword #state_column_width
                            jsl textbox_next_column
                            pushsword gameplay_crystal_attraction~state
                            jsl textbox_print_hex_word

                            jsl textbox_next_row_end_columns

; Test Code
                            ago .skip
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushptr #test_code_string
                            jsl textbox_print_string

                            jsl textbox_next_row_end_columns

                            jsl textbox_newline
.skip
; Display the gamepad state

; Slot
                            pushdword #snes_max_slot_str
                            jsl textbox_print_string

                            lda >textbox_primary~cursor_x
                            sta snes_slot_print_x
                            lda >textbox_primary~cursor_y
                            sta snes_slot_print_y

                            pushsword >input~gamepad_slot
                            jsl textbox_print_decimal_word

                            jsl textbox_newline

; Controller 1
                            pushdword #controller1_str
                            jsl textbox_print_string

                            lda >input~gamepad1_connected
                            beq not_connected1
                            pushdword #connected_str
                            bra show_connection1
not_connected1              pushdword #not_connected_str
show_connection1            jsl textbox_print_string

                            jsl textbox_newline

                            lda >input~gamepad1_buttons
                            xba
                            and #$ff
                            pha
                            jsl textbox_print_binary_byte
                            lda >input~gamepad1_buttons
                            and #$ff
                            pha
                            jsl textbox_print_binary_byte

                            jsl textbox_newline

; Controller 2
                            pushdword #controller2_str
                            jsl textbox_print_string

                            lda >input~gamepad2_connected
                            beq not_connected2
                            pushdword #connected_str
                            bra show_connection2
not_connected2              pushdword #not_connected_str
show_connection2            jsl textbox_print_string

                            jsl textbox_newline

                            lda >input~gamepad2_buttons
                            xba
                            and #$ff
                            pha
                            jsl textbox_print_binary_byte
                            lda >input~gamepad2_buttons
                            and #$ff
                            pha
                            jsl textbox_print_binary_byte

                            jsl textbox_newline
                            jsl textbox_newline

; Frame Count
                            pushdword #str_frame_count
                            jsl textbox_print_string

                            pushsword gameplay_manager~frame_count
                            jsl textbox_print_decimal_word
                            jsl textbox_newline

; Below 30 fps
                            pushdword #str_below_30
                            jsl textbox_print_string

                            pushsword gameplay_manager~below_30fps_count
                            jsl textbox_print_decimal_word
                            jsl textbox_newline

; 30 fps
                            pushdword #str_30
                            jsl textbox_print_string

                            pushsword gameplay_manager~30fps_count
                            jsl textbox_print_decimal_word
                            jsl textbox_newline

; Debug value
;                           pushdword #str_debug_value1
;                           jsl textbox_print_string

;                           pushsword gameplay_level~swarm_task_call_count
;                           jsl textbox_print_decimal_word
;                           jsl textbox_newline

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

title_string                dc c'Gameplay Options',i1'0'
ships_string                dc c'Unlimited [S]hips',i1'0'
add_ship_string             dc c'Ad[d] ship',i1'0'
bombs_string                dc c'Unlimited Sini[b]ombs',i1'0'
workers_string              dc c'[W]orkers',i1'0'
warriors_string             dc c'W[a]rriors',i1'0'
crystal_attraction_string   dc c'[C]rystal Attraction',i1'0'
test_code_string            dc c'Test Code[7]',i1'0'

snes_max_slot_str           cstring 'SNES MA[X] Slot:'
connected_str               cstring 'Connected'
not_connected_str           cstring 'Not Connected'
controller1_str             cstring 'Controller 1:'
controller2_str             cstring 'Controller 2:'

str_debug_value1            cstring 'Value1:'
str_debug_value2            cstring 'Value2:'
str_frame_count             cstring 'Frames:'
str_below_30                cstring 'Below 30:'
str_30                      cstring 'At 30:'

prev_draw_lines             dc i'0'
snes_slot_print_x           entry
                            dc i'0'
snes_slot_print_y           entry
                            dc i'0'

                            end

; ----------------------------------------------------------------------------
; Draw the help for this handler
gameplay_debug_handler_show_help start seg_gameplay

                            pushptr #basic_help1
                            jsl textbox_print_string
                            jsl textbox_newline

                            rtl

basic_help1                 cstring '[O] - Gameplay Options'

                            end

; -----------------------------------------------------------------------------
gameplay_debug_handler_keypress start seg_gameplay
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
                            cmp #'O'
                            beq disable

; Unlimited Ships toggling
                            lda <wKey
                            cmp #'S'
                            bne not_ships

                            lda >gameplay_manager~cheat~unlimited_ships
                            eor #$ffff
                            sta >gameplay_manager~cheat~unlimited_ships
                            bra handled

not_ships                   anop

; Add a ship
                            lda <wKey
                            cmp #'D'
                            bne not_add_ship

                            jsl gameplay_add_player_ship
                            bra handled

not_add_ship                anop

; Unlimited Sinibombs toggling
                            lda <wKey
                            cmp #'B'
                            bne not_bombs

                            lda >gameplay_manager~cheat~unlimited_sinibombs
                            eor #$ffff
                            sta >gameplay_manager~cheat~unlimited_sinibombs
                            bra handled

not_bombs                   anop

; Worker toggling
                            lda <wKey
                            cmp #'W'
                            bne not_workers

                            jsl worker_entity_manager_toggle_disabled
                            bra handled

not_workers                 anop
; Warrior toggling
                            cmp #'A'
                            bne not_warriors

                            jsl warrior_entity_manager_toggle_disabled
                            bra handled

not_warriors                anop

; Crystal Attraction cycling
                            cmp #'C'
                            bne not_crystal_attraction
                            jsr cycle_crystal_attraction
                            bra handled

not_crystal_attraction      anop

                            ago .skip
; Test Code
                            lda <wKey
                            cmp #'7'
                            bne not_test_code_1

                            jsl run_app_erase_rect_test
                            bra handled

not_test_code_1             anop
.skip

; SNES MAX Slot
                            cmp #'X'
                            bne not_snes_max_slot

                            jsr set_gamepad_slot
                            bra handled

not_snes_max_slot           anop
                            bra not_handled

disable                     anop
                            lda #0
                            putword [<pHandler],#debug_handler~enabled
                            lda #$ffff
                            sta >appdebug~clear_text_screen
                            bra handled

; We are not enabled, the only key we listen for, is the one to enable us
not_enabled                 lda <wKey
                            cmp #'O'
                            beq enable
                            cmp #'o'
                            bne not_handled

enable                      jsl appdebug_disable_all_handlers                           ; Disable everything else

                            lda #$ffff
                            putword [<pHandler],#debug_handler~enabled
                            sta >appdebug~clear_text_screen

handled                     clc
exit                        retkc
not_handled                 sec
                            bra exit

;; Local function
set_gamepad_slot            anop

                            pushsword >snes_slot_print_x
                            pushsword >snes_slot_print_y
                            jsl textbox_set_cursor
                            pushdword #snes_max_slot_press_number
                            jsl textbox_print_string

no_slot_keypress            jsl get_key_press
                            beq no_slot_keypress
                            cmp #key~esc
                            beq skip_gamepad_slot
                            jsl get_hex_digit_from_key
                            bcs skip_gamepad_slot
                            pha
                            jsl snes_max_patch_slot
                            pla
                            beq disable_gamepad
                            lda #1
disable_gamepad             pushsword #$ffff                ; active player, or if no active player, set the defaults for the first player
                            pha
                            jsl gameplay_manager_set_player_gamepad_state
skip_gamepad_slot           rts

snes_max_slot_press_number  cstring 'Press [1-7] or ESC'

;;
cycle_crystal_attraction    anop
                            lda >gameplay_crystal_attraction~state
                            inc a
                            cmp #crystal_attraction~max_level
                            blt ok_ca_value
                            lda #crystal_attraction~off
ok_ca_value                 jsl gameplay_crystals_apply_attraction
                            rts

                            end
