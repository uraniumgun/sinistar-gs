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
                            copy lib/source/tokenizer.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/ui.entity.definitions.asm
                            copy source/app.debug.definitions.asm

                            mcopy generated/config.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; The Configuration Screen

config_state_data           data seg_gameplay

config_state~last_tick      ds 4

config_state~update_rate    equ 1

config_state~top_entry_y    equ 30
config_state~entry_text_x   equ 10
config_state~entry_value_x  equ 320-40

config_state~current_index  ds 2
config_state~current_offset  ds 2
config_state~current_draw_y ds 2

config_state~selected_index  ds 2
config_state~selected_offset ds 2

config_state~waiting_for_write_confirm ds 2
difficulty_child_indent     equ 8

; A definition for a configuration item
                                begin_struct
config_def~state                decl word               ; some state, see config_item~state
config_def~draw_text            decl word               ; function to draw the text
config_def~draw_value           decl word               ; function to draw the value
config_def~change_value_up      decl word               ; function to change the value 'upward'
config_def~change_value_down    decl word               ; function to change the value 'downward'
config_def~reset_value          decl word               ; function to reset the value to its default
config_def~key_handler          decl word               ; general key handler (optional)
sizeof~config_entry             end_struct

; Number of config items in the config_items table.  Maybe just have a terminator for the list?
config_item~count           equ 21

config_item~state_text_needs_draw equ $0001
config_item~state_value_needs_draw equ $0002

config_items                anop
; Unlimited Ships
                            dc i'0'
                            dc a'unlimited_ships_draw_text'
                            dc a'unlimited_ships_draw_value'
                            dc a'unlimited_ships_value_up'
                            dc a'unlimited_ships_value_down'
                            dc a'unlimited_ships_value_reset'
                            dc a'0'

; Unlimited Sinibombs
                            dc i'0'
                            dc a'unlimited_sinibombs_draw_text'
                            dc a'unlimited_sinibombs_draw_value'
                            dc a'unlimited_sinibombs_value_up'
                            dc a'unlimited_sinibombs_value_down'
                            dc a'unlimited_sinibombs_value_reset'
                            dc a'0'

; Difficulty Level
                            dc i'0'
                            dc a'difficulty_level_draw_text'
                            dc a'difficulty_level_draw_value'
                            dc a'difficulty_level_value_up'
                            dc a'difficulty_level_value_down'
                            dc a'difficulty_level_value_reset'
                            dc a'0'

; Difficulty Adjustment
config_item~difficulty_adjustment dc i'0'
                            dc a'difficulty_adjustment_draw_text'
                            dc a'difficulty_adjustment_draw_value'
                            dc a'difficulty_adjustment_value_up'
                            dc a'difficulty_adjustment_value_down'
                            dc a'difficulty_adjustment_value_reset'
                            dc a'0'

; Starting Ships
config_item~difficulty_starting_ships dc i'0'
                            dc a'starting_ships_draw_text'
                            dc a'starting_ships_draw_value'
                            dc a'starting_ships_value_up'
                            dc a'starting_ships_value_down'
                            dc a'starting_ships_value_reset'
                            dc a'0'

; Starting Sinibombs
config_item~difficulty_starting_sinibombs dc i'0'
                            dc a'starting_sinibombs_draw_text'
                            dc a'starting_sinibombs_draw_value'
                            dc a'starting_sinibombs_value_up'
                            dc a'starting_sinibombs_value_down'
                            dc a'starting_sinibombs_value_reset'
                            dc a'0'

; First Extra Ship
config_item~difficulty_first_extra_ship dc i'0'
                            dc a'first_extra_ship_draw_text'
                            dc a'first_extra_ship_draw_value'
                            dc a'first_extra_ship_value_up'
                            dc a'first_extra_ship_value_down'
                            dc a'first_extra_ship_value_reset'
                            dc a'0'

; Next Extra Ship
config_item~difficulty_next_extra_ship dc i'0'
                            dc a'next_extra_ship_draw_text'
                            dc a'next_extra_ship_draw_value'
                            dc a'next_extra_ship_value_up'
                            dc a'next_extra_ship_value_down'
                            dc a'next_extra_ship_value_reset'
                            dc a'0'

; Crystal Attraction
config_item~difficulty_crystal_attraction dc i'0'
                            dc a'crystal_attraction_draw_text'
                            dc a'crystal_attraction_draw_value'
                            dc a'crystal_attraction_value_up'
                            dc a'crystal_attraction_value_down'
                            dc a'crystal_attraction_value_reset'
                            dc a'0'

; Starting Population Table Adjust
config_item~difficulty_starting_pop_table_adjust dc i'0'
                            dc a'starting_pop_table_adjust_draw_text'
                            dc a'starting_pop_table_adjust_draw_value'
                            dc a'starting_pop_table_adjust_value_up'
                            dc a'starting_pop_table_adjust_value_down'
                            dc a'starting_pop_table_adjust_value_reset'
                            dc a'0'


; Sound Disabled (global)
config_item~sound_disabled  dc i'0'
                            dc a'sound_disabled_draw_text'
                            dc a'sound_disabled_draw_value'
                            dc a'sound_disabled_value_up'
                            dc a'sound_disabled_value_down'
                            dc a'sound_disabled_value_reset'
                            dc a'0'

; Attract Sound Disabled
config_item~attract_sound_disabled dc i'0'
                            dc a'attract_sound_disabled_draw_text'
                            dc a'attract_sound_disabled_draw_value'
                            dc a'attract_sound_disabled_value_up'
                            dc a'attract_sound_disabled_value_down'
                            dc a'attract_sound_disabled_value_reset'
                            dc a'0'

; FPS PIP
config_item~fps_pip         dc i'0'
                            dc a'fps_pip_draw_text'
                            dc a'fps_pip_draw_value'
                            dc a'fps_pip_value_up'
                            dc a'fps_pip_value_down'
                            dc a'fps_pip_value_reset'
                            dc a'0'

; FPS Limiter
config_item~fps_limiter     dc i'0'
                            dc a'fps_limiter_draw_text'
                            dc a'fps_limiter_draw_value'
                            dc a'fps_limiter_value_up'
                            dc a'fps_limiter_value_down'
                            dc a'fps_limiter_value_reset'
                            dc a'0'

; SNES Max Slot
config_item~snes_max_slot   dc i'0'
                            dc a'snes_max_slot_draw_text'
                            dc a'snes_max_slot_draw_value'
                            dc a'0'
                            dc a'0'
                            dc a'snes_max_slot_value_reset'
                            dc a'snes_max_slot_key_handler'

; Analog Joystick Enabled
config_item~analog_joystick dc i'0'
                            dc a'analog_joystick_draw_text'
                            dc a'analog_joystick_draw_value'
                            dc a'analog_joystick_value_up'
                            dc a'analog_joystick_value_down'
                            dc a'analog_joystick_value_reset'
                            dc a'0'

; Workers Disabled
config_item~workers_disabled dc i'0'
                            dc a'workers_disabled_draw_text'
                            dc a'workers_disabled_draw_value'
                            dc a'workers_disabled_value_up'
                            dc a'workers_disabled_value_down'
                            dc a'workers_disabled_value_reset'
                            dc a'0'

; Warriors Disabled
config_item~warriors_disabled dc i'0'
                            dc a'warriors_disabled_draw_text'
                            dc a'warriors_disabled_draw_value'
                            dc a'warriors_disabled_value_up'
                            dc a'warriors_disabled_value_down'
                            dc a'warriors_disabled_value_reset'
                            dc a'0'

; Reset High-Scores
config_item~reset_high_scores dc i'0'
                            dc a'reset_high_scores_draw_text'
                            dc a'reset_high_scores_draw_value'
                            dc a'0'
                            dc a'0'
                            dc a'0'
                            dc a'0'

; Debug Mode Enable
config_item~debug_enabled   dc i'0'
                            dc a'debug_enabled_draw_text'
                            dc a'debug_enabled_draw_value'
                            dc a'debug_enabled_value_up'
                            dc a'debug_enabled_value_down'
                            dc a'debug_enabled_value_reset'
                            dc a'0'

; Restore Defaults
config_item~restore_defaults dc i'0'
                            dc a'restore_defaults_draw_text'
                            dc a'restore_defaults_draw_value'
                            dc a'0'
                            dc a'0'
                            dc a'0'
                            dc a'restore_defaults_key_handler'

; Binary image of the individual configuration data.
; The storage on disk will be text, just for the heck of it,
; so the user can edit the values externally.
; This will be used with a buffer to apply / restore values.
; I'm going to use a full word, even if it is a boolean, it's easier.
                                    begin_struct
config_data~unlimited_ships         decl word
config_data~unlimited_sinibombs     decl word
config_data~difficulty_level        decl word
; These are pairs, because we have two levels of difficulty.
config_data~difficulty_adjustment   decl 2*2
config_data~starting_ships          decl 2*2
config_data~starting_bombs          decl 2*2
config_data~crystal_attraction      decl 2*2
config_data~starting_pop_table_adjust decl 2*2
config_data~first_extra_ship        decl 4*2
config_data~next_extra_ship         decl 4*2
config_data~sound_disabled          decl word
config_data~attract_sound_disabled  decl word
config_data~fps_pip                 decl word
config_data~fps_limiter             decl word
config_data~snes_max_slot           decl word
config_data~analog_joystick         decl word
config_data~debug_mode              decl word
sizeof~config_data                  end_struct

; Display strings
str_unlimited_ships         cstring 'UNLIMITED SHIPS'
str_unlimited_sinibombs     cstring 'UNLIMITED SINIBOMBS'
str_difficulty_level        cstring 'DIFFICULTY LEVEL'
str_difficulty_adjustment   cstring 'DIFFICULTY ADJUSTMENT'
str_starting_ships          cstring 'STARTING SHIPS'
str_starting_sinibombs      cstring 'STARTING SINIBOMBS'
str_first_extra_ship        cstring 'FIRST EXTRA SHIP AT SCORE'
str_next_extra_ship         cstring 'EXTRA SHIP EVERY ADDITIONAL'
str_crystal_attraction      cstring 'CRYSTAL ATTRACTION'
str_starting_pop_table_adjust cstring 'POPULATION DIFFICULTY'
str_sound_disabled          cstring 'SOUND DISABLED'
str_attract_sound_disabled  cstring 'ATTRACT SOUND DISABLED'
str_fps_pip                 cstring 'FPS PIP'
str_fps_limiter             cstring 'FPS LIMITER'
str_snes_max_slot           cstring 'SNES MAX SLOT'
str_snes_max_slot_selected  cstring 'PRESS 1 TO 7 FOR SLOT / 0 OR D TO DISABLE'
str_analog_joystick         cstring 'ANALOG JOYSTICK'
str_workers_disabled        cstring 'WORKERS DISABLED'
str_warriors_disabled       cstring 'WARRIORS DISABLED'
str_reset_high_scores       cstring 'RESET HIGH SCORES'
str_debug_disabled          cstring 'DEBUG MODE'
str_debug_enabled           cstring 'DEBUG MODE, PRESS T ANY TIME TO TOGGLE SCREEN'
str_restore_defaults        cstring 'RESTORE DEFAULTS'

str_press_y_to_confirm      cstring 'PRESS Y TO CONFIRM'

str_disabled                cstring 'DISABLED'
str_detected                cstring 'DETECTED'
str_not_detected            cstring 'NOT DETECTED'

str_config_help             cstring 'USE UP/DOWN TO SELECT ITEM, LEFT/RIGHT TO CHANGE VALUE'
str_confirm_write_text      cstring 'SAVE CHANGES? Y/N OR ESC TO CANCEL'

str_joystick_state          anop
                            dc c'X:'
str_joystick_state_x        dc c'00'
                            dc c', Y:'
str_joystick_state_y        dc c'00'
                            dc c', B0:'
str_joystick_state_button_0 dc c'00'
                            dc c', B1:'
str_joystick_state_button_1 dc c'00'
                            dc i1'0'

; Display and config strings for a few things.
str_config_suffix_easy      anop
                            dc c'.'
str_easy                    anop
str_config_easy             anop
                            cstring 'EASY'

str_config_suffix_hard      anop
                            dc c'.'
str_hard                    anop
str_config_hard             anop
                            cstring 'HARD'

str_yes                     anop
str_config_yes              anop                            ; this gets written to the config
                            cstring 'YES'
str_no                      anop
str_config_no               anop                            ; this gets written to the config
                            cstring 'NO'

str_off                     anop
str_config_off              anop
                            cstring 'OFF'

str_low                     anop
str_config_low              anop
                            cstring 'LOW'

str_high                    anop
str_config_high             anop
                            cstring 'HIGH'

; Strings written to the config file
str_config_unlimited_ships  cstring 'UNLIMITED_SHIPS'
str_config_unlimited_bombs  cstring 'UNLIMITED_SINIBOMBS'
str_config_difficulty_level cstring 'DIFFICULTY_LEVEL'
str_config_difficulty_adjustment cstring 'DIFFICULTY_ADJUSTMENT'
str_config_starting_ships   cstring 'STARTING_SHIPS'
str_config_starting_bombs   cstring 'STARTING_BOMBS'
str_config_first_extra_ship cstring 'FIRST_EXTRA_SHIP'
str_config_next_extra_ship  cstring 'NEXT_EXTRA_SHIP'
str_config_crystal_attraction cstring 'CRYSTAL_ATTRACTION'
str_config_starting_pop_table_adjust cstring 'POPULATION_DIFFICULTY'
str_config_sound_disabled   cstring 'SOUND_DISABLED'
str_config_attract_sound_disabled cstring 'ATTRACT_SOUND_DISABLED'
str_config_fps_pip          cstring 'FPS_PIP'
str_config_fps_limiter      cstring 'FPS_LIMITER'
str_config_snes_max_slot    cstring 'SNES_MAX_SLOT'
str_config_analog_joystick  cstring 'ANALOG_JOYSTICK'
str_config_debug_enabled    cstring 'DEBUG_MODE'

; Lookup tables for strings
yes_no_value_strings            dc a'str_config_no'
                                dc a'str_config_yes'

difficulty_level_value_strings  dc a'str_config_easy'
                                dc a'str_config_hard'

difficulty_level_suffix_strings dc a'str_config_suffix_easy'
                                dc a'str_config_suffix_hard'

crystal_attraction_level_value_strings dc a'str_config_off'
                                dc a'str_config_low'
                                dc a'str_config_high'

starting_pop_table_adjust_level_value_strings anop
                                dc a'str_config_easy'
                                dc a'str_config_hard'

; Number of tags in the list.  Maybe use a terminator instead?
config_tag_count            equ 17

config_tags                 anop
                            dc a'str_config_unlimited_ships'
                            dc a'str_config_unlimited_bombs'
                            dc a'str_config_difficulty_level'
                            dc a'str_config_difficulty_adjustment'
                            dc a'str_config_starting_ships'
                            dc a'str_config_starting_bombs'
                            dc a'str_config_crystal_attraction'
                            dc a'str_config_starting_pop_table_adjust'
                            dc a'str_config_first_extra_ship'
                            dc a'str_config_next_extra_ship'
                            dc a'str_config_sound_disabled'
                            dc a'str_config_attract_sound_disabled'
                            dc a'str_config_fps_pip'
                            dc a'str_config_fps_limiter'
                            dc a'str_config_snes_max_slot'
                            dc a'str_config_analog_joystick'
                            dc a'str_config_debug_enabled'

config_desc                 ds sizeof~file_descriptor
config_name_object          ds sizeof~string_object

config_name                 cstring '9:config'

str_config_separator        dc i1'$09,$00'                  ; single tab
str_config_line_terminator  dc i1'$0d,$00'                  ; IIgs style, i.e. just a CR, the reader will allow Window / Linux style.

; A buffer large enough to store a bcd32 (8 digits) + 2 for a terminating word
config_bcd_str_buffer       ds 10

config_parse_tokenizer      ds sizeof~tokenizer

; The cached config state
config_state~cached         ds sizeof~config_data
; A backup state for comparing
config_state~backup         ds sizeof~config_data

                            end
; ----------------------------------------------------------------------------
config_state_initialize     start seg_gameplay
                            using appdata

                            debugtag 'config_state_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
config_state_activate       start seg_gameplay
                            using appdata
                            using applib_data
                            using config_state_data
                            using grlib_global_data
                            using gameplay_level_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            debugtag 'config_state_activate'

                            begin_locals
wEntryIndex                 decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Copy the current state to the cache
                            jsl config_cache_current_state
; Copy that to the backup
                            jsr config_cached_state_to_backup

                            lda #appdata~gameplay_color~effect1~bits
                            jsl grlib_fill_alt_screen

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

; Title
title_text_width            equ 84
title_text_x_offset         equ 0+(320-title_text_width)/2
title_text_y_offset         equ 4+appdata~font_primary~height

                            pushdword #str_title
                            pushsword #title_text_x_offset
                            pushsword #title_text_y_offset
                            jsl grlib_draw_string

; Help
                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            jsr draw_help_text
; Draw the entries
                            stz <wEntryIndex
                            stz config_state~selected_index
                            stz config_state~selected_offset
                            stz config_state~waiting_for_write_confirm

loop                        lda <wEntryIndex
                            jsr set_current_config_entry
                            jsr draw_config_entry
                            inc <wEntryIndex
                            lda <wEntryIndex
                            cmp #config_item~count
                            blt loop

                            pushsword #gameplay_ui~palette_id~config
                            jsl gameplay_ui_show_screen

                            getdword >applib~current_tick,config_state~last_tick

                            restoredatabank

                            ret

str_title                   cstring 'CONFIGURATION'
                            end

; ----------------------------------------------------------------------------
config_state_tick           start seg_gameplay
                            using appdata
                            using applib_data
                            using config_state_data

                            debugtag 'config_state_tick'

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            setlocaldatabank

; Get the tick delta
                            lda >applib~current_tick
                            sec
                            sbc config_state~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc config_state~last_tick+2
                            bne do_update                                   ; If this happened, we got stuck for quite a while
                            cpx #config_state~update_rate
                            blt done

do_update                   getdword >applib~current_tick,config_state~last_tick

                            jsl snes_max_read_controller                    ; read the button state for the controller, if enabled.
                            jsr get_analog_joystick_state                   ; read the analog joystick state, if enabled.

                            lda config_state~waiting_for_write_confirm
                            beq adjusting_values
; Are we waiting for a confirm press?
                            jsr waiting_for_write_confirm
                            bcs handled
                            bra no_keypress

adjusting_values            jsl get_key_press
                            beq no_keypress
                            cmp #key~esc
                            beq exit_config
                            jsr config_selection_value_key_handler          ; see if the config value wants to deal with the key directly
                            bcs handled
                            cmp #key~up_arrow
                            beq selection_up
                            cmp #key~down_arrow
                            beq selection_down
                            cmp #key~left_arrow
                            beq selection_value_down
                            cmp #key~right_arrow
                            beq selection_value_up
; Call the common key handler
no_keypress                 anop
                            pha
                            jsl handle_common_keypresses

handled                     jsr update_config_screen
; Do some housekeeping
                            jsl applib_update_fps
                            jsl appdebug_update_text_screen

done                        anop
                            restoredatabank

                            rtl

exit_config                 anop
                            jsl config_cache_current_state          ; copy the current state to the cache
                            jsr config_cached_state_compare_to_backup ; compare to what we started with
                            bcs not_same
                            lda #app_state~frontend                   ; I'd like to support coming into the config screen, from anywhere, so this would need to change
                            sta >appdata~pending_state
                            bra done

selection_up                jsr config_selection_up
                            bra handled
selection_down              jsr config_selection_down
                            bra handled
selection_value_down        jsr config_selection_value_down
                            bra handled
selection_value_up          jsr config_selection_value_up
                            bra handled

; Go into, waiting to confirm mode
not_same                    lda #$ffff
                            sta config_state~waiting_for_write_confirm
                            jsr erase_help_text
                            jsr draw_confirm_write_text
                            jsr copy_help_text_to_screen
                            bra handled

;;
waiting_for_write_confirm   anop
                            jsl get_key_press
                            beq no_confirm
                            cmp #key~esc
                            beq cancel_exit
                            tax
                            jsl key_to_upper
                            cmp #'Y'
                            beq do_write
                            cmp #'N'
                            beq do_revert
                            txa                                 ; get the unmodified key back
no_confirm                  clc
                            rts

cancel_exit                 stz config_state~waiting_for_write_confirm  ; cancel the wait and just go back to editing
; Put the help text back
                            jsr erase_help_text
                            jsr draw_help_text
                            jsr copy_help_text_to_screen
                            sec
                            rts

do_write                    jsl config_write
                            jsr config_apply_active_state

; Would be nice to handle any error with the writing...
can_exit                    lda #app_state~frontend
                            sta >appdata~pending_state
                            sec
                            rts

do_revert                   jsr config_backup_to_cached_state       ; get the backup into the cached state
                            jsl config_apply_cached_state           ; then apply that to the active state
                            bra can_exit

                            end

; -----------------------------------------------------------------------------
draw_help_text              private seg_gameplay
                            using appdata
                            using config_state_data

                            lda #appdata~gameplay_color~light_yellow~bits
                            jsl grlib_set_font_fore_color

help_text_width             equ 212
help_text_x_offset          equ 0+(320-help_text_width)/2
help_text_y_offset          equ 200-4

; Assuming the teeny font is active
                            pushdword #str_config_help
                            pushsword #help_text_x_offset
                            pushsword #help_text_y_offset
                            jsl grlib_draw_string
                            rts

                            end

; -----------------------------------------------------------------------------
draw_confirm_write_text     private seg_gameplay
                            using appdata
                            using config_state_data

                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

help_text_width             equ 136
help_text_x_offset          equ 0+(320-help_text_width)/2
help_text_y_offset          equ 200-4

; Assuming the teeny font is active
                            pushdword #str_confirm_write_text
                            pushsword #help_text_x_offset
                            pushsword #help_text_y_offset
                            jsl grlib_draw_string
                            rts

                            end

; -----------------------------------------------------------------------------
erase_help_text             private seg_gameplay
                            using appdata
                            using config_state_data

help_text_y_offset          equ 200-4

                            pushsword #0
                            pushsword #help_text_y_offset-appdata~font_teeny~height
                            pushsword #320
                            pushsword #appdata~font_teeny~height+2
                            pushsword #appdata~gameplay_color~effect1~bits
                            jsl grlib_alt_screen_fill_rect

                            rts
                            end

; -----------------------------------------------------------------------------
copy_help_text_to_screen    private seg_gameplay
                            using appdata
                            using config_state_data

help_text_y_offset          equ 200-4

                            pushsword #0
                            pushsword #help_text_y_offset-appdata~font_teeny~height
                            pushsword #320
                            pushsword #appdata~font_teeny~height+2
                            jsl grlib_alt_screen_to_screen_rect

                            rts
                            end

; -----------------------------------------------------------------------------
; Draw any config text/values that need updating
update_config_screen        private seg_gameplay
                            using appdata
                            using config_state_data

                            begin_locals
wEntryIndex                 decl word
work_area_size              end_locals

                            lsub ,work_area_size

; Draw the entries
                            stz <wEntryIndex

loop                        lda <wEntryIndex
                            jsr set_current_config_entry

                            ldx config_state~current_offset
                            getword {x},config_items+config_def~state
                            bit #config_item~state_text_needs_draw
                            bne draw_text
                            bit #config_item~state_value_needs_draw
                            beq no_update

                            jsr draw_config_entry_value
                            jsr copy_config_value_to_screen
                            bra just_value

draw_text                   jsr draw_config_entry
                            jsr copy_config_text_to_screen

just_value                  anop
no_update                   anop
                            inc <wEntryIndex
                            lda <wEntryIndex
                            cmp #config_item~count
                            blt loop

                            lret
                            end

; -----------------------------------------------------------------------------
config_selection_up         private seg_gameplay
                            using appdata
                            using config_state_data

                            lda config_state~selected_index
                            beq done

                            dec a
                            sta config_state~selected_index

                            ldx config_state~selected_offset
                            lda #config_item~state_text_needs_draw+config_item~state_value_needs_draw
                            putword {x},config_items+config_def~state
                            txa
                            sec
                            sbc #sizeof~config_entry
                            sta config_state~selected_offset
                            tax
                            lda #config_item~state_text_needs_draw+config_item~state_value_needs_draw
                            putword {x},config_items+config_def~state

done                        rts

                            end

; -----------------------------------------------------------------------------
config_selection_down       private seg_gameplay
                            using appdata
                            using config_state_data

                            lda config_state~selected_index
                            inc a
                            cmp #config_item~count
                            bge done

                            sta config_state~selected_index

                            ldx config_state~selected_offset
                            lda #config_item~state_text_needs_draw+config_item~state_value_needs_draw
                            putword {x},config_items+config_def~state
                            txa
                            clc
                            adc #sizeof~config_entry
                            sta config_state~selected_offset
                            tax
                            lda #config_item~state_text_needs_draw+config_item~state_value_needs_draw
                            putword {x},config_items+config_def~state

done                        rts

                            end

; -----------------------------------------------------------------------------
set_current_selected_config_entry private seg_gameplay
                            using appdata
                            using config_state_data

                            cmp #config_item~count
                            bge done
                            cmp config_state~selected_index
                            beq done

                            sta config_state~selected_index

                            ldx config_state~selected_offset
                            lda #config_item~state_text_needs_draw+config_item~state_value_needs_draw
                            putword {x},config_items+config_def~state

                            lda config_state~selected_index
                            ldx #sizeof~config_entry
                            jsl math~umul1r2
                            sta config_state~selected_offset
                            tax
                            lda #config_item~state_text_needs_draw+config_item~state_value_needs_draw
                            putword {x},config_items+config_def~state

done                        rts

                            end

; -----------------------------------------------------------------------------
config_selection_value_up   private seg_gameplay
                            using appdata
                            using config_state_data

                            ldx config_state~selected_offset
                            getword {x},config_items+config_def~change_value_up
                            beq none
                            per return-1
                            dec a
                            pha
                            rts
return                      anop
                            bcs none            ; carry means no change

                            ldx config_state~selected_offset
                            getword {x},config_items+config_def~state
                            ora #config_item~state_value_needs_draw
                            putword {x},config_items+config_def~state

none                        rts
                            end

; -----------------------------------------------------------------------------
config_selection_value_down private seg_gameplay
                            using appdata
                            using config_state_data

                            ldx config_state~selected_offset
                            getword {x},config_items+config_def~change_value_down
                            beq none
                            per return-1
                            dec a
                            pha
                            rts
return                      anop
                            bcs none            ; carry means no change

                            ldx config_state~selected_offset
                            getword {x},config_items+config_def~state
                            ora #config_item~state_value_needs_draw
                            putword {x},config_items+config_def~state

none                        rts
                            end

; -----------------------------------------------------------------------------
config_selection_value_key_handler private seg_gameplay
                            using appdata
                            using config_state_data

                            pha                                 ; save the key
; Make it easier for compare, and convert to upper case
                            jsl key_to_upper
                            tay
                            ldx config_state~selected_offset
                            getword {x},config_items+config_def~key_handler
                            beq none
                            per return-1
                            dec a
                            pha
                            tya                                 ; get the key back in a
                            rts
return                      anop
                            pla                                 ; get the key back
                            rts

none                        pla                                 ; get the key back
                            clc
                            rts
                            end
; -----------------------------------------------------------------------------
set_current_config_entry    private seg_gameplay
                            using appdata
                            using config_state_data

                            sta config_state~current_index
                            ldx #sizeof~config_entry
                            jsl math~umul1r2
                            sta config_state~current_offset

                            lda config_state~current_index
                            ldx #appdata~font_teeny~height+2
                            jsl math~umul1r2
                            clc
                            adc #config_state~top_entry_y
                            sta config_state~current_draw_y

                            lda config_state~current_index
                            cmp config_state~selected_index
                            beq is_selected

                            lda #appdata~gameplay_color~yellow~bits
                            jsl grlib_set_font_fore_color
                            bra not_selected

is_selected                 lda #appdata~gameplay_color~light_yellow~bits
                            jsl grlib_set_font_fore_color

not_selected                rts
                            end

; -----------------------------------------------------------------------------
draw_config_entry           private seg_gameplay
                            using appdata
                            using config_state_data

                            jsr draw_config_entry_text
                            jsr draw_config_entry_value

                            rts
                            end

; -----------------------------------------------------------------------------
; Helper function to draw the text, pointed to in A, with an extra indent
; if what is in X, at the current_draw_y
; Returns:
; Last x draw position in a-reg
draw_config_entry_text_ptr  private seg_gameplay
                            using config_state_data

                            pea config_items|-16
                            pha
                            txa
                            clc
                            adc #config_state~entry_text_x
                            pha
                            pushsword config_state~current_draw_y

                            jsl grlib_draw_string
                            rts
                            end

; -----------------------------------------------------------------------------
; Draw the current entry's (config_state~current_offset) value part
; at the current_draw_y
draw_config_entry_text      private seg_gameplay
                            using config_state_data

                            jsr erase_config_text

                            ldx config_state~current_offset
                            getword {x},config_items+config_def~state
                            and #((config_item~state_text_needs_draw)*-1)-1
                            putword {x},config_items+config_def~state

                            getword {x},config_items+config_def~draw_text
                            beq none
                            dec a
                            pha
none                        rts
                            end

; -----------------------------------------------------------------------------
; Draw the current entry's (config_state~current_offset) value part
; at the current_draw_y
draw_config_entry_value     private seg_gameplay
                            using config_state_data

                            jsr erase_config_value

                            ldx config_state~current_offset
                            getword {x},config_items+config_def~state
                            and #((config_item~state_value_needs_draw)*-1)-1
                            putword {x},config_items+config_def~state

                            getword {x},config_items+config_def~draw_value
                            beq none
                            dec a
                            pha
none                        rts
                            end

;;
; -----------------------------------------------------------------------------
; Draw a yes or no at the current value location
; Parameters:
; ACC 0 = no, anything else = yes
draw_config_value_yes_no    private seg_gameplay
                            using config_state_data

                            cmp #0
                            beq no
                            pushptr #str_yes
                            bra next
no                          pushptr #str_no
next                        pushsword #config_state~entry_value_x
                            pushsword config_state~current_draw_y

                            jsl grlib_draw_string

                            rts
                            end

; -----------------------------------------------------------------------------
; Draw a decimal number at the current value location
; This assumes the input is in BCD format
; Parameters:
; ACC = low, X = high
draw_config_value_number    private seg_gameplay
                            using config_state_data

                            phx
                            pha
                            pushsword #config_state~entry_value_x
                            pushsword config_state~current_draw_y

                            jsl grlib_draw_bcd32

                            rts
                            end

; -----------------------------------------------------------------------------
; Erase the value column of the current config item
erase_config_value          private seg_gameplay
                            using appdata
                            using config_state_data

                            pushsword #config_state~entry_value_x
                            lda config_state~current_draw_y
                            sec
                            sbc #appdata~font_teeny~height
                            pha
                            pushsword #320-config_state~entry_value_x
                            pushsword #appdata~font_teeny~height+2
                            pushword #appdata~gameplay_color~effect1~bits
                            jsl grlib_alt_screen_fill_rect

                            rts
                            end

; -----------------------------------------------------------------------------
; Copy the value column of the current config item to the screen
copy_config_value_to_screen private seg_gameplay
                            using appdata
                            using config_state_data

                            pushsword #config_state~entry_value_x
                            lda config_state~current_draw_y
                            sec
                            sbc #appdata~font_teeny~height
                            pha
                            pushsword #320-config_state~entry_value_x
                            pushsword #appdata~font_teeny~height+2
                            jsl grlib_alt_screen_to_screen_rect

                            rts
                            end

; -----------------------------------------------------------------------------
; Erase the text column of the current config item
erase_config_text           private seg_gameplay
                            using appdata
                            using config_state_data

                            pushsword #config_state~entry_text_x
                            lda config_state~current_draw_y
                            sec
                            sbc #appdata~font_teeny~height
                            pha
                            pushsword #config_state~entry_value_x
                            pushsword #appdata~font_teeny~height+2
                            pushword #appdata~gameplay_color~effect1~bits
                            jsl grlib_alt_screen_fill_rect

                            rts
                            end

; -----------------------------------------------------------------------------
; This will copy the text and the value of the current item to the screen
copy_config_text_to_screen  private seg_gameplay
                            using appdata
                            using config_state_data

                            pushsword #0
                            lda config_state~current_draw_y
                            sec
                            sbc #appdata~font_teeny~height
                            pha
                            pushsword #320
                            pushsword #appdata~font_teeny~height+2
                            jsl grlib_alt_screen_to_screen_rect

                            rts
                            end

; -----------------------------------------------------------------------------
; Invalidate all the config items that are tied to the difficulty_level
config_invalidate_difficulty_items private seg_gameplay
                            using config_state_data
                            using gameplay_manager_data

                            lda #config_item~state_text_needs_draw+config_item~state_value_needs_draw
                            sta config_item~difficulty_adjustment
                            sta config_item~difficulty_starting_ships
                            sta config_item~difficulty_starting_sinibombs
                            sta config_item~difficulty_first_extra_ship
                            sta config_item~difficulty_next_extra_ship
                            sta config_item~difficulty_crystal_attraction
                            sta config_item~difficulty_starting_pop_table_adjust
                            rts
                            end

; -----------------------------------------------------------------------------
; Get the current state values, and put them in the cache.
config_cache_current_state  start seg_gameplay
                            using inputlib_data
                            using appdata
                            using appdebug_data
                            using gameplay_manager_data
                            using config_state_data

                            setlocaldatabank
; Well, I could make function pointers in the config entry, and just make this a generic loop
; but that seems like more overhead that I need.  Just doing them all right here

                            lda gameplay_manager~cheat~unlimited_ships
                            sta config_state~cached+config_data~unlimited_ships
                            lda gameplay_manager~cheat~unlimited_sinibombs
                            sta config_state~cached+config_data~unlimited_sinibombs
                            lda gameplay_manager~difficulty
                            sta config_state~cached+config_data~difficulty_level
; These read the two different levels of difficulty
                            ldy #2
loop1                       lda gameplay_manager~difficulty_adjust,y
                            sta config_state~cached+config_data~difficulty_adjustment,y
                            lda gameplay_manager~starting_ship_count,y
                            sta config_state~cached+config_data~starting_ships,y
                            lda gameplay_manager~starting_bomb_count,y
                            sta config_state~cached+config_data~starting_bombs,y
                            lda gameplay_manager~starting_crystal_attraction,y
                            sta config_state~cached+config_data~crystal_attraction,y
                            lda gameplay_manager~starting_pop_table_adjust,y
                            sta config_state~cached+config_data~starting_pop_table_adjust,y
                            dey
                            dey
                            bpl loop1

                            ldy #6
loop2                       lda gameplay_manager~starting_extra_ship,y
                            sta config_state~cached+config_data~first_extra_ship,y
                            lda gameplay_manager~starting_extra_ship_add,y
                            sta config_state~cached+config_data~next_extra_ship,y
                            dey
                            dey
                            bpl loop2

                            lda >appdata~sound_disabled
                            sta config_state~cached+config_data~sound_disabled
                            lda >appdata~attract_sound_disabled
                            sta config_state~cached+config_data~attract_sound_disabled
                            lda >appdata~fps_pip
                            sta config_state~cached+config_data~fps_pip
                            lda >appdata~fps_limiter
                            sta config_state~cached+config_data~fps_limiter

                            lda >input~gamepad_slot
                            sta config_state~cached+config_data~snes_max_slot
                            lda >input~analog_joystick_enabled
                            sta config_state~cached+config_data~analog_joystick
                            lda >appdebug~debug_mode
                            sta config_state~cached+config_data~debug_mode

                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Apply the current cached state to the config values
config_apply_cached_state   start seg_gameplay
                            using inputlib_data
                            using appdata
                            using gameplay_manager_data
                            using config_state_data

                            setlocaldatabank

                            lda config_state~cached+config_data~unlimited_ships
                            sta gameplay_manager~cheat~unlimited_ships
                            lda config_state~cached+config_data~unlimited_sinibombs
                            sta gameplay_manager~cheat~unlimited_sinibombs
                            lda config_state~cached+config_data~difficulty_level
                            sta gameplay_manager~difficulty
; These read the two different levels of difficulty
                            ldy #2
loop1                       lda config_state~cached+config_data~difficulty_adjustment,y
                            sta gameplay_manager~difficulty_adjust,y
                            lda config_state~cached+config_data~starting_ships,y
                            sta gameplay_manager~starting_ship_count,y
                            lda config_state~cached+config_data~starting_bombs,y
                            sta gameplay_manager~starting_bomb_count,y
                            lda config_state~cached+config_data~crystal_attraction,y
                            sta gameplay_manager~starting_crystal_attraction,y
                            lda config_state~cached+config_data~starting_pop_table_adjust,y
                            sta gameplay_manager~starting_pop_table_adjust,y
                            dey
                            dey
                            bpl loop1

                            ldy #6
loop2                       lda config_state~cached+config_data~first_extra_ship,y
                            sta gameplay_manager~starting_extra_ship,y
                            lda config_state~cached+config_data~next_extra_ship,y
                            sta gameplay_manager~starting_extra_ship_add,y
                            dey
                            dey
                            bpl loop2

                            lda config_state~cached+config_data~sound_disabled
                            sta >appdata~sound_disabled
; The actual switch to prevent audio is in the sound lib
                            eor #$ffff
                            jsl sndlib_set_enabled

                            lda config_state~cached+config_data~attract_sound_disabled
                            sta >appdata~attract_sound_disabled
                            lda config_state~cached+config_data~fps_pip
                            sta >appdata~fps_pip
                            lda config_state~cached+config_data~fps_limiter
                            sta >appdata~fps_limiter

                            lda config_state~cached+config_data~snes_max_slot
                            jsl snes_max_patch_slot                 ; this does range validation

                            lda config_state~cached+config_data~analog_joystick
                            sta >input~analog_joystick_enabled

                            lda config_state~cached+config_data~debug_mode
                            jsl appdebug_set_debug_mode

; Apply any active state globals, that are not explicitly set by the above
                            jsr config_apply_active_state

                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Copy the cached state to a backup.
; This is done before editing the configuration.
config_cached_state_to_backup private seg_gameplay
                            using config_state_data

                            ldy #sizeof~config_data-2
loop                        lda config_state~cached,y
                            sta config_state~backup,y
                            dey
                            dey
                            bpl loop

                            rts
                            end

; -----------------------------------------------------------------------------
; Restore the cached state from the backup.
; This does not apply the cached state
config_backup_to_cached_state private seg_gameplay
                            using config_state_data

                            ldy #sizeof~config_data-2
loop                        lda config_state~backup,y
                            sta config_state~cached,y
                            dey
                            dey
                            bpl loop

                            rts
                            end

; -----------------------------------------------------------------------------
; Compare the cached state to the backup and return carry clear if it is the
; same and set if different
config_cached_state_compare_to_backup private seg_gameplay
                            using config_state_data

                            ldy #sizeof~config_data-2
loop                        lda config_state~backup,y
                            cmp config_state~cached,y
                            bne different
                            dey
                            dey
                            bpl loop

                            clc
                            rts

different                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
; Apply any active state globals that were not explicitly set.
; Most configuration change operations (up/down value) change their global state
; However, some need to be 'applied' at the end.
;
config_apply_active_state   private seg_gameplay

                            setlocaldatabank

                            jsr config_apply_crystal_attraction

                            restoredatabank
                            rts
                            end

; -----------------------------------------------------------------------------
; Crystal attaction is a bit different, in that it is under the difficulty
; but it is a global value once set, and I'd also like to have it so
; that it can be overridden by the debug panel.
;
config_apply_crystal_attraction private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_crystal_attraction,y
                            jsl gameplay_crystals_apply_attraction

                            rts
                            end
; -----------------------------------------------------------------------------
; Write the config to a file (CONFIG) at the application directory location.
; The config values written, come from the cached state buffer
config_write                start seg_gameplay
                            using file_manager_data
                            using config_state_data

                            begin_locals
pFileWriter                 decl ptr
spStrTable                  decl word
wIndex                      decl word
work_area_size              end_locals

                            debugtag 'config_write'
                            sub ,work_area_size

                            setlocaldatabank

                            pushptr #config_name_object
                            pushptr #config_name
                            jsl string_object_construct_zt

                            pushptr #config_desc
                            jsl file_descriptor_construct

                            pushptr #config_desc
                            pushptr #config_name_object
                            pushsword #file_option~write
                            pushsword #file_type~txt
                            pushsword #0
                            jsl file_descriptor_create
                            bne failed_to_create

                            pushptr #config_desc
                            jsl file_writer_new_with_desc
                            bcs failed_new_file_writer
                            putretptr <pFileWriter

                            jsr write_config_to_buffer

                            pushptr <pFileWriter
                            jsl file_writer_delete                      ; this will flush the buffer

                            pushptr #config_desc
                            jsl file_descriptor_destruct                ; close the file

                            pushptr #config_name_object
                            jsl string_object_destruct

                            clc
exit                        anop
                            restoredatabank
                            retkc

failed_to_create            sec
                            pushptr #config_name_object
                            jsl string_object_destruct
                            bra exit

failed_new_file_writer      anop
                            pushptr #config_desc
                            jsl file_descriptor_destruct
                            sec
                            bra exit

;;
write_config_to_buffer      anop

; Unlimited Ships
                            lda #str_config_unlimited_ships
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~unlimited_ships
                            jsr write_yes_no

; Unlimited Sinibombs
                            lda #str_config_unlimited_bombs
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~unlimited_sinibombs
                            jsr write_yes_no

; Difficulty Level
                            lda #str_config_difficulty_level
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~difficulty_level
                            ldx #difficulty_level_value_strings
                            jsr write_indexed_string
                            jsr write_line_terminator

                            stz <wIndex
difficulty_loop             anop
; Difficulty Adjustment
                            lda #str_config_difficulty_adjustment
                            jsr write_string_and_suffix
                            lda <wIndex
                            asl a
                            tax
                            lda config_state~cached+config_data~difficulty_adjustment,x
                            jsr write_word_as_decimal
                            jsr write_line_terminator
; Starting ships
                            lda #str_config_starting_ships
                            jsr write_string_and_suffix
                            lda <wIndex
                            asl a
                            tax
                            lda config_state~cached+config_data~starting_ships,x
                            jsr write_word_as_decimal
                            jsr write_line_terminator

; Starting bombs
                            lda #str_config_starting_bombs
                            jsr write_string_and_suffix
                            lda <wIndex
                            asl a
                            tax
                            lda config_state~cached+config_data~starting_bombs,x
                            jsr write_word_as_decimal
                            jsr write_line_terminator

; First Extra Ship
                            lda #str_config_first_extra_ship
                            jsr write_string_and_suffix
                            lda <wIndex
                            asl a
                            asl a
                            tay
                            lda config_state~cached+config_data~first_extra_ship+2,y
                            tax
                            lda config_state~cached+config_data~first_extra_ship,y
                            jsr write_bcd_32
                            jsr write_line_terminator

; Next Extra Ship
                            lda #str_config_next_extra_ship
                            jsr write_string_and_suffix
                            lda <wIndex
                            asl a
                            asl a
                            tay
                            lda config_state~cached+config_data~next_extra_ship+2,y
                            tax
                            lda config_state~cached+config_data~next_extra_ship,y
                            jsr write_bcd_32
                            jsr write_line_terminator

; Crystal Attraction
                            lda #str_config_crystal_attraction
                            jsr write_string_and_suffix
                            lda <wIndex
                            asl a
                            tax
                            lda config_state~cached+config_data~crystal_attraction,x
                            ldx #crystal_attraction_level_value_strings
                            jsr write_indexed_string
                            jsr write_line_terminator

; Starting Pop Table
                            lda #str_config_starting_pop_table_adjust
                            jsr write_string_and_suffix
                            lda <wIndex
                            asl a
                            tax
                            lda config_state~cached+config_data~starting_pop_table_adjust,x
                            ldx #starting_pop_table_adjust_level_value_strings
                            jsr write_indexed_string
                            jsr write_line_terminator

; Next inner difficulty pass
                            inc <wIndex
                            lda <wIndex
                            cmp #2
                            jlt difficulty_loop

; Sound Disabled
                            lda #str_config_sound_disabled
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~sound_disabled
                            jsr write_yes_no            ; writes line terminator too.

; Attract Sound Disabled
                            lda #str_config_attract_sound_disabled
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~attract_sound_disabled
                            jsr write_yes_no            ; writes line terminator too.

; FPS PIP
                            lda #str_config_fps_pip
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~fps_pip
                            jsr write_yes_no            ; writes line terminator too.

; FPS Limiter
                            lda #str_config_fps_limiter
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~fps_limiter
                            jsr write_yes_no            ; writes line terminator too.

; SNES MAX Slot
                            lda #str_config_snes_max_slot
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~snes_max_slot
                            jsr write_word_as_decimal
                            jsr write_line_terminator

; Analog Joystick
                            lda #str_config_analog_joystick
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~analog_joystick
                            jsr write_yes_no            ; writes line terminator too.

; Debug Mode
                            lda #str_config_debug_enabled
                            jsr write_string
                            jsr write_separator
                            lda config_state~cached+config_data~debug_mode
                            jsr write_yes_no            ; writes line terminator too.

                            rts

;; helpers
write_string                anop
                            pushptr <pFileWriter                        ; assumes that ACC will not change
                            ldx #^str_config_unlimited_ships            ; all the strings are in the same bank
                            phx
                            pha
                            jsl file_writer_append_zt
                            rts

write_indexed_string        anop
                            pushptr <pFileWriter                        ; assumes that ACC will not change
                            asl a
                            tay
                            stx <spStrTable
                            ldx #^str_config_unlimited_ships
                            phx
                            lda (<spStrTable),y
                            pha
                            jsl file_writer_append_zt
                            rts

write_string_and_suffix     anop
                            jsr write_string
                            lda <wIndex
                            ldx #difficulty_level_suffix_strings
                            jsr write_indexed_string
                            jsr write_separator
                            rts

write_word_as_decimal       anop
                            pha
                            pushptr #config_bcd_str_buffer
                            pushsword #1
                            jsl word_to_str
                            tax
                            stz config_bcd_str_buffer,x
                            lda #config_bcd_str_buffer
                            jsr write_string
                            rts

write_bcd_32                anop
                            phx
                            pha
                            pushptr #config_bcd_str_buffer
                            pushsword #1
                            jsl bcd32_to_str
                            tax
                            stz config_bcd_str_buffer,x
                            lda #config_bcd_str_buffer
                            jsr write_string
                            rts

write_separator             anop
                            pushptr <pFileWriter
                            pushptr #str_config_separator
                            jsl file_writer_append_zt
                            rts

write_line_terminator       anop
                            pushptr <pFileWriter
                            pushptr #str_config_line_terminator
                            jsl file_writer_append_zt
                            rts

write_yes_no                anop
                            cmp #0
                            beq write_no

                            pushptr <pFileWriter
                            pushptr #str_config_yes
                            jsl file_writer_append_zt
                            jsr write_line_terminator
                            rts

write_no                    pushptr <pFileWriter
                            pushptr #str_config_no
                            jsl file_writer_append_zt
                            jsr write_line_terminator
                            rts

                            end

; -----------------------------------------------------------------------------
config_read                 start seg_gameplay
                            using textlib_global_data
                            using config_state_data

                            begin_locals
failed                      decl word
pReader                     decl ptr
pBuffer                     decl ptr
wBufferSize                 decl word
wTokenOffset                decl word
wTokenLength                decl word
wTokenBaseLength            decl word
wTagIndex                   decl word
wDifficultyOffset           decl word
work_area_size              end_locals

                            debugtag 'config_read'
                            sub ,work_area_size

                            setlocaldatabank

; Fill the cache with the current state, we are allowing the save config to be incomplete.
                            jsl config_cache_current_state

                            lda #1
                            sta <failed                                     ; assume we failed

                            pushptr #config_name_object
                            pushptr #config_name
                            jsl string_object_construct_zt

                            pushptr #config_desc
                            jsl file_descriptor_construct

                            pushptr #config_desc
                            pushptr #config_name_object
                            jsl file_descriptor_open
                            bne failed_to_open

                            pushptr #config_desc
                            jsl file_reader_new_with_desc
                            bcs reader_failed
                            putretptr <pReader
; Get a buffer
                            lda config_desc+file_descriptor~length
                            sta <wBufferSize
                            pha
                            jsl sba_alloc
                            bcs allocation_error
                            putretptr <pBuffer
; Read into the buffer
                            pushptr <pReader
                            pushptr <pBuffer
                            pushsword #0
                            pushword <wBufferSize
                            jsl file_reader_put_in_buffer
                            bcs read_error
; Parse
                            jsr parse_config
                            bcs read_error

                            stz <failed
                            jsl config_apply_cached_state

read_error                  anop
                            pushptr <pBuffer
                            jsl sba_free

allocation_error            anop
                            pushptr <pReader
                            jsl file_reader_delete

reader_failed               anop
                            pushptr #config_desc
                            jsl file_descriptor_close

failed_to_open              anop
                            pushptr #config_name_object
                            jsl string_object_destruct

                            restoredatabank
                            lsr <failed                         ; Move the failed flag into the carry
                            retkc

;;
parse_config                anop

; Construct a tokenizer
                            pushptr #config_parse_tokenizer
                            pushptr <pBuffer
                            pushsword <wBufferSize
                            jsl tokenizer_construct

line_loop                   stz <wTagIndex

                            pushptr #config_parse_tokenizer
                            jsl tokenizer_get_next
                            bcs next_line

                            sta <wTokenOffset
                            stx <wTokenLength
                            stx <wTokenBaseLength

; The difficulty tags have a base and suffix, compare to the base
                            pushsword <wTokenOffset
                            pushsword <wTokenLength
                            pushptr <pBuffer
                            pushsword #ascii~period
                            jsl str_view_find_char
                            bcs tag_loop
                            sta <wTokenBaseLength

tag_loop                    anop
                            pushsword <wTokenOffset
                            pushsword <wTokenBaseLength
                            pushptr <pBuffer
                            pea config_tags|-16
                            ldx <wTagIndex
                            lda config_tags,x
                            pha
                            jsl str_view_compare_to_zt
                            bcc matched_tag
                            lda <wTagIndex
                            inc a
                            inc a
                            sta <wTagIndex
                            cmp #config_tag_count*2
                            blt tag_loop
; Didn't match anything, go to the next line

next_line                   pushptr #config_parse_tokenizer
                            jsl tokenizer_next_line
                            bcc line_loop
                            clc
                            bra done

matched_tag                 anop
                            ldx <wTagIndex
                            jsr (tag_handlers,x)
                            bra next_line

done                        rts

; Must be in same order as config_tags
tag_handlers                dc a'parse_unlimited_ships'
                            dc a'parse_unlimited_bombs'
                            dc a'parse_difficulty_level'
                            dc a'parse_difficulty_adjustment'
                            dc a'parse_starting_ships'
                            dc a'parse_starting_bombs'
                            dc a'parse_crystal_attraction'
                            dc a'parse_starting_pop_table_adjust'
                            dc a'parse_first_extra_ship'
                            dc a'parse_next_extra_ship'
                            dc a'parse_sound_disabled'
                            dc a'parse_attract_sound_disabled'
                            dc a'parse_fps_pip'
                            dc a'parse_fps_limiter'
                            dc a'parse_snes_max_slot'
                            dc a'parse_analog_joystick'
                            dc a'parse_debug_mode'

;;
parse_unlimited_ships       anop
                            jsr parse_yes_no
                            bcs line_error

                            sta config_state~cached+config_data~unlimited_ships
                            clc
line_error                  rts

;;
parse_unlimited_bombs       anop
                            jsr parse_yes_no
                            bcs line_error

                            sta config_state~cached+config_data~unlimited_sinibombs
                            clc
                            rts

;;
parse_difficulty_level      anop
                            pushptr #config_parse_tokenizer
                            jsl tokenizer_get_next
                            bcs line_error

                            pha
                            phx
                            pushptr <pBuffer
                            pushsword #2
                            pushptr #difficulty_level_value_strings
                            jsl str_view_compare_to_short_table_zt
                            bcs line_error

                            sta config_state~cached+config_data~difficulty_level
                            clc
                            rts

;;
parse_difficulty_adjustment anop
                            jsr parse_difficulty_word_value
                            bcs line_error

                            sta config_state~cached+config_data~difficulty_adjustment,x
                            clc
                            rts

parse_starting_ships        anop
                            jsr parse_difficulty_word_value
                            bcs line_error

                            sta config_state~cached+config_data~starting_ships,x
                            clc
                            rts

parse_starting_bombs        anop
                            jsr parse_difficulty_word_value
                            bcs line_error

                            sta config_state~cached+config_data~starting_bombs,x
                            clc
                            rts

parse_first_extra_ship      anop
                            jsr parse_difficulty_bcd32_value
                            bcs line_error

                            sta config_state~cached+config_data~first_extra_ship,y
                            txa
                            sta config_state~cached+config_data~first_extra_ship+2,y
                            clc
                            rts

parse_next_extra_ship       anop
                            jsr parse_difficulty_bcd32_value
                            bcs line_error

                            sta config_state~cached+config_data~next_extra_ship,Y
                            txa
                            sta config_state~cached+config_data~next_extra_ship+2,y
                            clc
                            rts

;;
parse_crystal_attraction    anop
; Get the difficulty suffix
                            jsr get_difficulty_suffix_offset_x2
                            bcs line_error2

                            pushptr #config_parse_tokenizer
                            jsl tokenizer_get_next
                            bcs line_error2

                            pha
                            phx
                            pushptr <pBuffer
                            pushsword #3
                            pushptr #crystal_attraction_level_value_strings
                            jsl str_view_compare_to_short_table_zt
                            bcs line_error2

                            ldx <wDifficultyOffset
                            sta config_state~cached+config_data~crystal_attraction,x
                            clc
line_error2                 rts

;;
parse_starting_pop_table_adjust anop
; Get the difficulty suffix
                            jsr get_difficulty_suffix_offset_x2
                            bcs line_error2

                            pushptr #config_parse_tokenizer
                            jsl tokenizer_get_next
                            bcs line_error2

                            pha
                            phx
                            pushptr <pBuffer
                            pushsword #3
                            pushptr #starting_pop_table_adjust_level_value_strings
                            jsl str_view_compare_to_short_table_zt
                            bcs line_error2

                            ldx <wDifficultyOffset
                            sta config_state~cached+config_data~starting_pop_table_adjust,x
                            clc
                            rts

parse_sound_disabled        anop
                            jsr parse_yes_no
                            bcs analog_error

                            sta config_state~cached+config_data~sound_disabled
                            clc
                            rts

parse_attract_sound_disabled anop
                            jsr parse_yes_no
                            bcs analog_error

                            sta config_state~cached+config_data~attract_sound_disabled
                            clc
                            rts

parse_fps_pip               anop
                            jsr parse_yes_no
                            bcs analog_error

                            sta config_state~cached+config_data~fps_pip
                            clc
                            rts

parse_fps_limiter           anop
                            jsr parse_yes_no
                            bcs analog_error

                            sta config_state~cached+config_data~fps_limiter
                            clc
                            rts

parse_snes_max_slot         anop
                            jsr parse_decimal_value
                            bcs analog_error

                            sta config_state~cached+config_data~snes_max_slot
                            clc
                            rts

parse_analog_joystick       anop
                            jsr parse_yes_no
                            bcs analog_error

                            sta config_state~cached+config_data~analog_joystick
                            clc
analog_error                rts

parse_debug_mode            anop
                            jsr parse_yes_no
                            bcs debug_mode_error

                            sta config_state~cached+config_data~debug_mode
                            clc
debug_mode_error            rts

;;
parse_yes_no                anop
                            pushptr #config_parse_tokenizer
                            jsl tokenizer_get_next
                            bcs yn_error

                            sta <wTokenOffset
                            stx <wTokenLength
                            pha
                            phx
                            pushptr <pBuffer
                            pushptr #str_config_yes
                            jsl str_view_compare_to_zt
                            bcc is_yes

                            pushsword <wTokenOffset
                            pushsword <wTokenLength
                            pushptr <pBuffer
                            pushptr #str_config_no
                            jsl str_view_compare_to_zt
                            bcs yn_error

                            lda #0
                            clc
yn_error                    rts

is_yes                      lda #$ffff                          ; using $ffff for yes, because it it can be helpful to have flag values with the high bit on as well, i.e. 'bit my_value' can set the N flag without disturbing A
                            clc
                            rts

;;
parse_difficulty_suffix     anop
; Point the view to the suffix
                            lda <wTokenOffset
                            sec                     ; want + 1
                            adc <wTokenBaseLength
                            pha
                            lda <wTokenLength
                            clc                     ; want + 1
                            sbc <wTokenBaseLength
                            pha
                            pushptr <pBuffer
                            pushsword #2
                            pushptr #difficulty_level_value_strings
                            jsl str_view_compare_to_short_table_zt
                            rts

;;
get_difficulty_suffix_offset_x2 anop
                            jsr parse_difficulty_suffix
                            bcs x2_suffix_error
                            asl a
                            sta <wDifficultyOffset
                            clc
x2_suffix_error             rts

;;
get_difficulty_suffix_offset_x4 anop
                            jsr parse_difficulty_suffix
                            bcs x4_suffix_error
                            asl a
                            asl a
                            sta <wDifficultyOffset
                            clc
x4_suffix_error             rts

;;
; Read the suffix on the current token, and set wDifficultyOffset, then get the word value
parse_decimal_value         anop
                            pushptr #config_parse_tokenizer
                            jsl tokenizer_get_next
                            bcs value_error

                            pha
                            phx
                            pushptr <pBuffer
                            jsl str_view_decimal_to_word
value_error                 rts

;;
; Read the suffix on the current token, and set wDifficultyOffset, then get the word value
; Value will be in A, difficulty offset in X, carry set if error
parse_difficulty_word_value anop
                            jsr get_difficulty_suffix_offset_x2
                            bcs suffix_error

                            pushptr #config_parse_tokenizer
                            jsl tokenizer_get_next
                            bcs suffix_error

                            pha
                            phx
                            pushptr <pBuffer
                            jsl str_view_decimal_to_word
                            ldx <wDifficultyOffset              ; return the offset in x

suffix_error                rts

;;
; Read the suffix on the current token, and set wDifficultyOffset, then get the bcd32 value (A/X)
; Y will have the difficulty offset, carry will be set if there was an error parsing
parse_difficulty_bcd32_value anop
                            jsr get_difficulty_suffix_offset_x4
                            bcs suffix_error

                            pushptr #config_parse_tokenizer
                            jsl tokenizer_get_next
                            bcs suffix_error

                            pha
                            phx
                            pushptr <pBuffer
                            jsl str_view_decimal_to_bcd32
                            ldy <wDifficultyOffset
                            rts

                            end

; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------
; The handlers for the individual entries

;;

; -----------------------------------------------------------------------------
unlimited_ships_draw_text   private seg_gameplay
                            using config_state_data

                            lda #str_unlimited_ships
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
unlimited_ships_draw_value  private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~cheat~unlimited_ships
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
unlimited_ships_value_up    private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~cheat~unlimited_ships
                            bne already_on
                            lda #$ffff
                            sta gameplay_manager~cheat~unlimited_ships
                            clc
                            rts

already_on                  sec
                            rts

                            end

; -----------------------------------------------------------------------------
unlimited_ships_value_down  private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~cheat~unlimited_ships
                            beq already_off
                            stz gameplay_manager~cheat~unlimited_ships
                            clc
                            rts

already_off                 sec
                            rts
                            end

; -----------------------------------------------------------------------------
unlimited_ships_value_reset private seg_gameplay

                            jmp unlimited_ships_value_down

                            end

;;
; -----------------------------------------------------------------------------
unlimited_sinibombs_draw_text private seg_gameplay
                            using config_state_data

                            lda #str_unlimited_sinibombs
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end

; -----------------------------------------------------------------------------
unlimited_sinibombs_draw_value private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~cheat~unlimited_sinibombs
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
unlimited_sinibombs_value_up private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~cheat~unlimited_sinibombs
                            bne already_on
                            lda #$ffff
                            sta gameplay_manager~cheat~unlimited_sinibombs
                            clc
                            rts

already_on                  sec
                            rts
                            end

; -----------------------------------------------------------------------------
unlimited_sinibombs_value_down private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~cheat~unlimited_sinibombs
                            beq already_off
                            stz gameplay_manager~cheat~unlimited_sinibombs
                            clc
                            rts

already_off                 sec
                            rts
                            end

; -----------------------------------------------------------------------------
unlimited_sinibombs_value_reset private seg_gameplay

                            jmp unlimited_sinibombs_value_down

                            end

;;
; -----------------------------------------------------------------------------
difficulty_level_draw_text  private seg_gameplay
                            using config_state_data

                            lda #str_difficulty_level
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end

; -----------------------------------------------------------------------------
difficulty_level_draw_value private seg_gameplay
                            using gameplay_manager_data
                            using config_state_data

                            lda gameplay_manager~difficulty
                            cmp #0
                            beq easy
                            pushptr #str_hard
                            bra next
easy                        pushptr #str_easy
next                        pushsword #config_state~entry_value_x
                            pushsword config_state~current_draw_y

                            jsl grlib_draw_string
                            rts

                            end

; -----------------------------------------------------------------------------
difficulty_level_value_up   private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            inc a
                            cmp #gameplay_manager~difficulty_count
                            bge exit
                            sta gameplay_manager~difficulty
                            jsr config_invalidate_difficulty_items
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
difficulty_level_value_down private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            beq exit
                            dec a
                            sta gameplay_manager~difficulty
                            jsr config_invalidate_difficulty_items
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
difficulty_level_value_reset private seg_gameplay
                            using gameplay_manager_data

                            stz gameplay_manager~difficulty
                            end

;;
; -----------------------------------------------------------------------------
difficulty_adjustment_draw_text private seg_gameplay
                            using config_state_data

                            lda #str_difficulty_adjustment
                            ldx #difficulty_child_indent
                            jmp draw_config_entry_text_ptr

                            end

; -----------------------------------------------------------------------------
difficulty_adjustment_draw_value private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~difficulty_adjust,y
                            pha
                            jsl word_to_decimal
                            jmp draw_config_value_number

                            end

; -----------------------------------------------------------------------------
difficulty_adjustment_value_up private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~difficulty_adjust,y
                            cmp #gameplay_manager~difficulty_adjust_max
                            bge exit
                            inc a
                            sta gameplay_manager~difficulty_adjust,y
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
difficulty_adjustment_value_down private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~difficulty_adjust,y
                            beq exit
                            dec a
                            sta gameplay_manager~difficulty_adjust,y
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
difficulty_adjustment_value_reset private seg_gameplay
                            using gameplay_manager_data

                            lda #gameplay_manager~difficulty_adjust~easy
                            lda gameplay_manager~difficulty_adjust
                            lda #gameplay_manager~difficulty_adjust~hard
                            sta gameplay_manager~difficulty_adjust+2

                            rts
                            end


;;
; -----------------------------------------------------------------------------
starting_ships_draw_text    private seg_gameplay
                            using config_state_data

                            lda #str_starting_ships
                            ldx #difficulty_child_indent
                            jmp draw_config_entry_text_ptr

                            end

; -----------------------------------------------------------------------------
starting_ships_draw_value   private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_ship_count,y
                            pha
                            jsl word_to_decimal
                            jmp draw_config_value_number

                            end

; -----------------------------------------------------------------------------
starting_ships_value_up     private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_ship_count,y
                            inc a
                            cmp #256                            ; I'm gonna cap it for no good reason
                            bge exit
                            sta gameplay_manager~starting_ship_count,y
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
starting_ships_value_down   private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_ship_count,y
                            cmp #2                              ; at least 1 ship
                            blt exit
                            dec a
                            sta gameplay_manager~starting_ship_count,y
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
starting_ships_value_reset  private seg_gameplay
                            using gameplay_manager_data

                            lda #gameplay_manager~starting_ships~easy
                            lda gameplay_manager~starting_ship_count
                            lda #gameplay_manager~starting_ships~hard
                            lda gameplay_manager~starting_ship_count+2
                            rts
                            end

;;

; -----------------------------------------------------------------------------
starting_sinibombs_draw_text private seg_gameplay
                            using config_state_data

                            lda #str_starting_sinibombs
                            ldx #difficulty_child_indent
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
starting_sinibombs_draw_value private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_bomb_count,y
                            pha
                            jsl word_to_decimal
                            jmp draw_config_value_number

                            end

; -----------------------------------------------------------------------------
starting_sinibombs_value_up private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_bomb_count,y
                            inc a
                            cmp #gameplay_player~max_bomb_count+1           ; can't do anything with more that this
                            bge exit
                            sta gameplay_manager~starting_bomb_count,y
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
starting_sinibombs_value_down private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_bomb_count,y
                            beq exit
                            dec a
                            sta gameplay_manager~starting_bomb_count,y
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
starting_sinibombs_value_reset private seg_gameplay
                            using gameplay_manager_data

                            lda #gameplay_manager~starting_bombs~easy
                            lda gameplay_manager~starting_bomb_count
                            lda #gameplay_manager~starting_bombs~hard
                            lda gameplay_manager~starting_bomb_count+2
                            rts
                            end

;;
; -----------------------------------------------------------------------------
first_extra_ship_draw_text  private seg_gameplay
                            using config_state_data

                            lda #str_first_extra_ship
                            ldx #difficulty_child_indent
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
first_extra_ship_draw_value private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            asl a
                            tay
                            lda gameplay_manager~starting_extra_ship+2,y
                            tax
                            lda gameplay_manager~starting_extra_ship,y
                            jmp draw_config_value_number

                            end

; -----------------------------------------------------------------------------
first_extra_ship_value_up   private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            asl a
                            tay

                            sed                                             ; decimal value
                            lda gameplay_manager~starting_extra_ship,y
                            clc
                            adc #$1000
                            tax
                            lda gameplay_manager~starting_extra_ship+2,y
                            adc #0
                            bmi exit
                            sta gameplay_manager~starting_extra_ship+2,y
                            txa
                            sta gameplay_manager~starting_extra_ship,y
                            cld
                            clc
                            rts

exit                        cld
                            sec
                            rts
                            end

; -----------------------------------------------------------------------------
first_extra_ship_value_down private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            asl a
                            tay

                            sed                                             ; decimal value
                            lda gameplay_manager~starting_extra_ship,y
                            sec
                            sbc #$1000
                            tax
                            lda gameplay_manager~starting_extra_ship+2,y
                            sbc #0
                            bmi exit
                            bne ok
                            cpx #$1000                                      ; don't let this go to 0
                            blt exit
ok                          sta gameplay_manager~starting_extra_ship+2,y
                            txa
                            sta gameplay_manager~starting_extra_ship,y
                            cld
                            clc
                            rts

exit                        cld
                            sec
                            rts
                            end

; -----------------------------------------------------------------------------
first_extra_ship_value_reset private seg_gameplay
                            using gameplay_manager_data

                            lda #gameplay_manager~starting_extra_ship~easy
                            sta gameplay_manager~starting_extra_ship
                            lda #^gameplay_manager~starting_extra_ship~easy
                            sta gameplay_manager~starting_extra_ship+2

                            lda #gameplay_manager~starting_extra_ship~hard
                            sta gameplay_manager~starting_extra_ship+4
                            lda #^gameplay_manager~starting_extra_ship~hard
                            sta gameplay_manager~starting_extra_ship+6
                            rts
                            end

;;
; -----------------------------------------------------------------------------
next_extra_ship_draw_text   private seg_gameplay
                            using config_state_data

                            lda #str_next_extra_ship
                            ldx #difficulty_child_indent
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
next_extra_ship_draw_value  private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            asl a
                            tay
                            lda gameplay_manager~starting_extra_ship_add+2,y
                            tax
                            lda gameplay_manager~starting_extra_ship_add,y
                            jmp draw_config_value_number

                            end

; -----------------------------------------------------------------------------
next_extra_ship_value_up    private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            asl a
                            tay

                            sed                                             ; decimal value
                            lda gameplay_manager~starting_extra_ship_add,y
                            clc
                            adc #$1000
                            tax
                            lda gameplay_manager~starting_extra_ship_add+2,y
                            adc #0
                            bmi exit
                            sta gameplay_manager~starting_extra_ship_add+2,y
                            txa
                            sta gameplay_manager~starting_extra_ship_add,y
                            cld
                            clc
                            rts

exit                        cld
                            sec
                            rts
                            end

; -----------------------------------------------------------------------------
next_extra_ship_value_down  private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            asl a
                            tay

                            sed                                             ; decimal value
                            lda gameplay_manager~starting_extra_ship_add,y
                            sec
                            sbc #$1000
                            tax
                            lda gameplay_manager~starting_extra_ship_add+2,y
                            sbc #0
                            bmi exit
                            bne ok
                            cpx #$1000                                      ; don't let this go to 0
                            blt exit
ok                          sta gameplay_manager~starting_extra_ship_add+2,y
                            txa
                            sta gameplay_manager~starting_extra_ship_add,y
                            cld
                            clc
                            rts

exit                        cld
                            sec
                            rts
                            end

; -----------------------------------------------------------------------------
next_extra_ship_value_reset private seg_gameplay
                            using gameplay_manager_data

                            lda #gameplay_manager~starting_extra_ship_add~easy
                            sta gameplay_manager~starting_extra_ship_add
                            lda #^gameplay_manager~starting_extra_ship_add~easy
                            sta gameplay_manager~starting_extra_ship_add+2

                            lda #gameplay_manager~starting_extra_ship_add~hard
                            sta gameplay_manager~starting_extra_ship_add+4
                            lda #^gameplay_manager~starting_extra_ship_add~hard
                            sta gameplay_manager~starting_extra_ship_add+6
                            rts

                            end

;;
; -----------------------------------------------------------------------------
crystal_attraction_draw_text private seg_gameplay
                            using config_state_data

                            lda #str_crystal_attraction
                            ldx #difficulty_child_indent
                            jmp draw_config_entry_text_ptr

                            end

; -----------------------------------------------------------------------------
crystal_attraction_draw_value private seg_gameplay
                            using gameplay_manager_data
                            using config_state_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_crystal_attraction,y
                            asl a
                            tax
                            pushptrhigh #str_config_off                     ; all the strings are in the same bank
                            lda crystal_attraction_level_value_strings,x
                            pha
                            pushsword #config_state~entry_value_x
                            pushsword config_state~current_draw_y

                            jsl grlib_draw_string
                            rts
                            end

; -----------------------------------------------------------------------------
crystal_attraction_value_up private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_crystal_attraction,y
                            inc a
                            cmp #crystal_attraction~max_level
                            bge exit
                            sta gameplay_manager~starting_crystal_attraction,y
                            jsr config_invalidate_difficulty_items
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
crystal_attraction_value_down private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_crystal_attraction,y
                            dec a
                            bmi exit
                            sta gameplay_manager~starting_crystal_attraction,y
                            jsr config_invalidate_difficulty_items
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
crystal_attraction_value_reset  private seg_gameplay
                            using gameplay_manager_data

                            lda #gameplay_manager~starting_crystal_attraction~easy
                            lda gameplay_manager~starting_crystal_attraction
                            lda #gameplay_manager~starting_crystal_attraction~hard
                            lda gameplay_manager~starting_crystal_attraction+2
                            rts
                            end

;;
; -----------------------------------------------------------------------------
starting_pop_table_adjust_draw_text private seg_gameplay
                            using config_state_data

                            lda #str_starting_pop_table_adjust
                            ldx #difficulty_child_indent
                            jmp draw_config_entry_text_ptr

                            end

; -----------------------------------------------------------------------------
starting_pop_table_adjust_draw_value private seg_gameplay
                            using gameplay_manager_data
                            using config_state_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_pop_table_adjust,y
                            asl a
                            tax
                            pushptrhigh #str_config_off                     ; all the strings are in the same bank
                            lda starting_pop_table_adjust_level_value_strings,x
                            pha
                            pushsword #config_state~entry_value_x
                            pushsword config_state~current_draw_y

                            jsl grlib_draw_string
                            rts
                            end

; -----------------------------------------------------------------------------
starting_pop_table_adjust_value_up private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_pop_table_adjust,y
                            inc a
                            cmp #gameplay_manager~starting_pop_table_adjust~max_level
                            bge exit
                            sta gameplay_manager~starting_pop_table_adjust,y
                            jsr config_invalidate_difficulty_items
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
starting_pop_table_adjust_value_down private seg_gameplay
                            using gameplay_manager_data

                            lda gameplay_manager~difficulty
                            asl a
                            tay
                            lda gameplay_manager~starting_pop_table_adjust,y
                            dec a
                            bmi exit
                            sta gameplay_manager~starting_pop_table_adjust,y
                            jsr config_invalidate_difficulty_items
                            clc
                            rts

exit                        sec
                            rts
                            end

; -----------------------------------------------------------------------------
starting_pop_table_adjust_value_reset  private seg_gameplay
                            using gameplay_manager_data

                            lda #gameplay_manager~starting_pop_table_adjust~easy
                            lda gameplay_manager~starting_pop_table_adjust
                            lda #gameplay_manager~starting_pop_table_adjust~hard
                            lda gameplay_manager~starting_pop_table_adjust+2
                            rts
                            end

;;
; -----------------------------------------------------------------------------
sound_disabled_draw_text    private seg_gameplay
                            using config_state_data

                            lda #str_sound_disabled
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
sound_disabled_draw_value   private seg_gameplay
                            using appdata

                            lda >appdata~sound_disabled
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
sound_disabled_value_up     private seg_gameplay
                            using appdata

                            lda >appdata~sound_disabled
                            bne no_change
                            lda #$ffff
                            sta >appdata~sound_disabled
; The actual switch to prevent audio is in the sound lib
                            eor #$ffff
                            jsl sndlib_set_enabled
                            clc
                            rts

no_change                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
sound_disabled_value_down   private seg_gameplay
                            using appdata

                            lda >appdata~sound_disabled
                            beq no_change
                            lda #0
                            sta >appdata~sound_disabled
; The actual switch to prevent audio is in the sound lib
                            eor #$ffff
                            jsl sndlib_set_enabled
                            clc
                            rts

no_change                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
sound_disabled_value_reset  private seg_gameplay

                            jmp sound_disabled_value_down

                            end

;;
; -----------------------------------------------------------------------------
attract_sound_disabled_draw_text private seg_gameplay
                            using config_state_data

                            lda #str_attract_sound_disabled
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
attract_sound_disabled_draw_value private seg_gameplay
                            using appdata

                            lda >appdata~attract_sound_disabled
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
attract_sound_disabled_value_up private seg_gameplay
                            using appdata

                            lda >appdata~attract_sound_disabled
                            bne no_change
                            lda #$ffff
                            sta >appdata~attract_sound_disabled
                            clc
                            rts

no_change                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
attract_sound_disabled_value_down private seg_gameplay
                            using appdata

                            lda >appdata~attract_sound_disabled
                            beq no_change
                            lda #0
                            sta >appdata~attract_sound_disabled
                            clc
                            rts

no_change                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
attract_sound_disabled_value_reset private seg_gameplay

                            jmp attract_sound_disabled_value_down

                            end

;;
; -----------------------------------------------------------------------------
fps_pip_draw_text           private seg_gameplay
                            using config_state_data

                            lda #str_fps_pip
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
fps_pip_draw_value          private  seg_gameplay
                            using appdata

                            lda >appdata~fps_pip
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
fps_pip_value_up            private seg_gameplay
                            using appdata

                            lda >appdata~fps_pip
                            bne no_change
                            dec a
                            sta >appdata~fps_pip
                            clc
                            rts

no_change                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
fps_pip_value_down          private seg_gameplay
                            using appdata

                            lda >appdata~fps_pip
                            beq no_change
                            lda #0
                            sta >appdata~fps_pip
                            clc
                            rts

no_change                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
fps_pip_value_reset         private seg_gameplay

                            jmp fps_pip_value_down

                            end

;;
; -----------------------------------------------------------------------------
fps_limiter_draw_text       private seg_gameplay
                            using config_state_data

                            lda #str_fps_limiter
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
fps_limiter_draw_value      private  seg_gameplay
                            using appdata

                            lda >appdata~fps_limiter
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
fps_limiter_value_up        private seg_gameplay
                            using appdata

                            lda >appdata~fps_limiter
                            bne no_change
                            dec a
                            sta >appdata~fps_limiter
                            clc
                            rts

no_change                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
fps_limiter_value_down      private seg_gameplay
                            using appdata

                            lda >appdata~fps_limiter
                            beq no_change
                            lda #0
                            sta >appdata~fps_limiter
                            clc
                            rts

no_change                   sec
                            rts
                            end

; -----------------------------------------------------------------------------
fps_limiter_value_reset     private seg_gameplay

                            jmp fps_limiter_value_down

                            end

;;
; -----------------------------------------------------------------------------
snes_max_slot_draw_text     private seg_gameplay
                            using appdata
                            using config_state_data

                            lda #str_snes_max_slot
                            ldx #0
                            jsr draw_config_entry_text_ptr

                            tax                             ; last X draw position
; Line selected?  If so, show some additional text.
                            lda config_state~current_index
                            cmp config_state~selected_index
                            bne not_selected

                            phx
                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color
                            plx

                            pea config_items|-16
                            lda #str_snes_max_slot_selected
                            pha
                            txa
                            clc
                            adc #10
                            pha
                            pushsword config_state~current_draw_y
                            jsl grlib_draw_string

                            lda #appdata~gameplay_color~light_yellow~bits
                            jsl grlib_set_font_fore_color

not_selected                rts

                            end
; -----------------------------------------------------------------------------
snes_max_slot_draw_value    private seg_gameplay
                            using inputlib_data
                            using config_state_data

                            lda >input~gamepad_slot
                            bne has_slot
                            pushptr #str_disabled
                            pushsword #config_state~entry_value_x
                            pushsword config_state~current_draw_y
                            jsl grlib_draw_string
                            rts

has_slot                    pha
                            jsl word_to_decimal
                            jmp draw_config_value_number

                            end

; -----------------------------------------------------------------------------
snes_max_slot_key_handler   private seg_gameplay
                            using inputlib_data
                            using config_state_data

                            cmp #'0'
                            beq disable
                            cmp #'D'
                            beq disable
                            cmp #'1'
                            blt not_slot
                            cmp #'9'+1
                            bge not_slot
; Slot number
                            sec
                            sbc #'0'
                            cmp >input~gamepad_slot
                            beq same_slot
                            jsl snes_max_patch_slot
                            lda #config_item~state_value_needs_draw
                            sta config_item~snes_max_slot

same_slot                   sec                                             ; used the key
                            rts

not_slot                    clc
                            rts

disable                     lda #0
                            jsl snes_max_patch_slot
                            lda #config_item~state_value_needs_draw
                            sta config_item~snes_max_slot
                            sec
                            rts

                            end

; -----------------------------------------------------------------------------
snes_max_slot_value_reset   private seg_gameplay

                            lda #0
                            jsl snes_max_patch_slot
                            rts
                            end

;;
; -----------------------------------------------------------------------------
analog_joystick_draw_text   private seg_gameplay
                            using config_state_data
                            using inputlib_data

                            lda #str_analog_joystick
                            ldx #0
                            jsr draw_config_entry_text_ptr

                            tax             ; save the x postion

                            lda >input~analog_joystick_enabled
                            beq not_enabled

                            pushdword #str_joystick_state
                            txa
                            clc
                            adc #10
                            pha
                            pushsword config_state~current_draw_y
                            jsl grlib_draw_string

not_enabled                 rts

                            end
; -----------------------------------------------------------------------------
analog_joystick_draw_value  private seg_gameplay
                            using inputlib_data

                            lda >input~analog_joystick_enabled
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
analog_joystick_value_up    private seg_gameplay
                            using inputlib_data

                            lda >input~analog_joystick_enabled
                            bne already_enabled
                            inc a
                            sta >input~analog_joystick_enabled
                            clc
                            rts

already_enabled             sec
                            rts
                            end

; -----------------------------------------------------------------------------
analog_joystick_value_down  private seg_gameplay
                            using inputlib_data

                            lda >input~analog_joystick_enabled
                            beq already_disabled
                            lda #0
                            sta >input~analog_joystick_enabled
                            clc
                            rts

already_disabled            sec
                            rts
                            end

; -----------------------------------------------------------------------------
analog_joystick_value_reset private seg_gameplay

                            jmp analog_joystick_value_down

                            end

;;
; -----------------------------------------------------------------------------
workers_disabled_draw_text  private seg_gameplay
                            using config_state_data

                            lda #str_workers_disabled
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
workers_disabled_draw_value private seg_gameplay
                            using worker_entity_manager_data

                            lda >worker_entity_limit
                            beq is_disabled
                            lda #0
                            jmp draw_config_value_yes_no
is_disabled                 lda #1
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
workers_disabled_value_up   private seg_gameplay
                            using worker_entity_manager_data

                            lda >worker_entity_limit
                            beq already_disabled
                            jsl worker_entity_manager_toggle_disabled
                            clc
                            rts

already_disabled            sec
                            rts
                            end

; -----------------------------------------------------------------------------
workers_disabled_value_down private seg_gameplay
                            using worker_entity_manager_data

                            lda >worker_entity_limit
                            bne already_enabled
                            jsl worker_entity_manager_toggle_disabled
                            clc
                            rts

already_enabled             sec
                            rts
                            end

; -----------------------------------------------------------------------------
workers_disabled_value_reset private seg_gameplay

                            jmp workers_disabled_value_down

                            end

;;
; -----------------------------------------------------------------------------
warriors_disabled_draw_text private seg_gameplay
                            using config_state_data

                            lda #str_warriors_disabled
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
warriors_disabled_draw_value private seg_gameplay
                            using warrior_entity_manager_data

                            lda >warrior_entity_limit
                            beq is_disabled
                            lda #0
                            jmp draw_config_value_yes_no
is_disabled                 lda #1
                            jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
warriors_disabled_value_up   private seg_gameplay
                            using warrior_entity_manager_data

                            lda >warrior_entity_limit
                            beq already_disabled
                            jsl warrior_entity_manager_toggle_disabled
                            clc
                            rts

already_disabled            sec
                            rts
                            end

; -----------------------------------------------------------------------------
warriors_disabled_value_down private seg_gameplay
                            using warrior_entity_manager_data

                            lda >warrior_entity_limit
                            bne already_enabled
                            jsl warrior_entity_manager_toggle_disabled
                            clc
                            rts

already_enabled             sec
                            rts
                            end

; -----------------------------------------------------------------------------
warriors_disabled_value_reset private seg_gameplay

                            jmp warriors_disabled_value_down

                            end

;;
; -----------------------------------------------------------------------------
debug_enabled_draw_text     private seg_gameplay
                            using config_state_data
                            using appdebug_data

                            lda >appdebug~debug_mode
                            beq is_disabled

                            lda #str_debug_enabled
                            ldx #0
                            jmp draw_config_entry_text_ptr

is_disabled                 lda #str_debug_disabled
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
debug_enabled_draw_value    private seg_gameplay
                            using appdebug_data

                            lda >appdebug~debug_mode
                            beq is_disabled
                            lda #1
                            jmp draw_config_value_yes_no
is_disabled                 jmp draw_config_value_yes_no

                            end

; -----------------------------------------------------------------------------
debug_enabled_value_up      private seg_gameplay
                            using appdebug_data
                            using config_state_data

                            lda >appdebug~debug_mode
                            bne already_enabled
                            lda #1
                            jsl appdebug_set_debug_mode
                            lda #config_item~state_text_needs_draw
                            sta config_item~debug_enabled
                            clc
                            rts

already_enabled             sec
                            rts
                            end

; -----------------------------------------------------------------------------
debug_enabled_value_down    private seg_gameplay
                            using appdebug_data
                            using config_state_data

                            lda >appdebug~debug_mode
                            beq already_disabled
                            lda #0
                            jsl appdebug_set_debug_mode
                            lda #config_item~state_text_needs_draw
                            sta config_item~debug_enabled
                            clc
                            rts

already_disabled            sec
                            rts
                            end

; -----------------------------------------------------------------------------
debug_enabled_value_reset   private seg_gameplay

                            jmp debug_enabled_value_down

                            end

;;
; -----------------------------------------------------------------------------
reset_high_scores_draw_text private seg_gameplay
                            using config_state_data

                            lda #str_reset_high_scores
                            ldx #0
                            jmp draw_config_entry_text_ptr

                            end
; -----------------------------------------------------------------------------
reset_high_scores_draw_value private seg_gameplay

                            rts

                            end

;;
; -----------------------------------------------------------------------------
restore_defaults_draw_text  private seg_gameplay
                            using appdata
                            using config_state_data

                            lda #str_restore_defaults
                            ldx #0
                            jsr draw_config_entry_text_ptr

                            tax                             ; last X draw position
; Line selected?  If so, show some additional text.
                            lda config_state~current_index
                            cmp config_state~selected_index
                            bne not_selected

                            phx
                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color
                            plx

                            pea config_items|-16
                            lda #str_press_y_to_confirm
                            pha
                            txa
                            clc
                            adc #10
                            pha
                            pushsword config_state~current_draw_y
                            jsl grlib_draw_string

                            lda #appdata~gameplay_color~light_yellow~bits
                            jsl grlib_set_font_fore_color

not_selected                rts

                            end
; -----------------------------------------------------------------------------
restore_defaults_draw_value private seg_gameplay

                            rts

                            end

; -----------------------------------------------------------------------------
restore_defaults_key_handler private seg_gameplay
                            using inputlib_data
                            using config_state_data

                            cmp #'Y'
                            beq reset
                            clc
                            rts

reset                       jsr restore_defaults

; Set the selection back to the first one
                            lda #0
                            jsr set_current_selected_config_entry

                            sec
                            rts

                            end

; -----------------------------------------------------------------------------
restore_defaults            private seg_gameplay
                            using config_state_data

                            lda #0
                            pha

loop                        ldx #sizeof~config_entry
                            jsl math~umul1r2
                            tax
; Say that the item will need a re-draw
                            lda #config_item~state_text_needs_draw+config_item~state_value_needs_draw
                            sta config_items+config_def~state,x
; Setup return value, then jump to the reset function
                            lda config_items+config_def~reset_value,x
                            beq next                            ; do we have a reset function?
                            per next-1
                            dec a
                            pha
                            rts
next                        anop
                            lda 1,s
                            inc a
                            sta 1,s
                            cmp #config_item~count
                            blt loop
                            pla
                            rts

                            end

; -----------------------------------------------------------------------------
get_analog_joystick_state   private seg_gameplay
                            using inputlib_data
                            using config_state_data
                            using softswitch_definitions

                            lda >input~analog_joystick_enabled
                            beq not_enabled

                            jsl joy_1_read
                            pha                         ; save

                            xba
                            and #$00ff
                            pha

                            pushdword #str_joystick_state_x
                            pushsword #2
                            jsl word_to_hex_str

                            pla
                            and #$00ff
                            pha
                            pushdword #str_joystick_state_y
                            pushsword #2
                            jsl word_to_hex_str

                            lda >ssw~button_0
                            pha
                            asl a
                            xba
                            and #$0001
                            pha
                            pushdword #str_joystick_state_button_0
                            pushsword #2
                            jsl word_to_hex_str

                            pla
                            and #$8000
                            rol a
                            rol a
                            pha
                            pushdword #str_joystick_state_button_1
                            pushsword #2
                            jsl word_to_hex_str

                            lda #config_item~state_text_needs_draw
                            sta config_item~analog_joystick

not_enabled                 rts
                            end
