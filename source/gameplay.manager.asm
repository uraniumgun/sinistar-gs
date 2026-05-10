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

                            copy source/app.build.definitions.asm
                            copy source/app.debug.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/app.ui.definitions.asm

                            mcopy generated/gameplay.manager.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; Contains general gameplay related functions for the overall game.

gameplay_manager_data       data seg_gameplay
                            using appdata

gameplay_manager_logic~update_rate equ 2
gameplay_manager_logic~last_tick ds 4
gameplay_manager_logic~tick_delta ds 2              ; The delta from the last update tick.  Logic updates can look at this to see the amount of time from the last update
gameplay_manager_logic~speed_modifier ds 2          ; flag to signal how to adjust 'speed' calculations for the frame.

gameplay_manager~credits        dc i'0'
gameplay_manager~player_count   dc i'1'             ; number of players selected on last start request
gameplay_manager~demo_active    dc i'0'
gameplay_manager~is_in_warp     dc i'0'             ; INWARP, from the original

gameplay_manager~difficulty_count   equ 2           ; number of possible difficulties

gameplay_manager~difficulty     dc i'0'

; Difficulty adjustment.
; This is a multiplier when advancing the 'difficulty timer', at the start of a player's turn.
gameplay_manager~difficulty_adjust~easy equ 3   ; I picked this one.
gameplay_manager~difficulty_adjust~hard equ 5   ; from the CMOS table of the original
gameplay_manager~difficulty_adjust_max equ 9

gameplay_manager~difficulty_adjust dc i'gameplay_manager~difficulty_adjust~easy,gameplay_manager~difficulty_adjust~hard'

; This is the active value, used during a player's turn.  It is not per-player.  Maybe make it so?
gameplay_manager~active_difficulty_adjust dc i'gameplay_manager~difficulty_adjust~easy'

gameplay_manager~starting_ships~easy    equ 5
gameplay_manager~starting_ships~hard    equ 3

gameplay_manager~starting_ship_count    dc i'gameplay_manager~starting_ships~easy,gameplay_manager~starting_ships~hard'

gameplay_manager~starting_bombs~easy    equ 0
gameplay_manager~starting_bombs~hard    equ 0

gameplay_manager~starting_bomb_count   dc i'gameplay_manager~starting_bombs~easy,gameplay_manager~starting_bombs~hard'

gameplay_manager~starting_extra_ship~easy equ $00010000
gameplay_manager~starting_extra_ship~hard equ $00020000
; The starting points to reach for an extra ship, and the amount to add, at each ship
; I think the original didn't have these tied to difficulty, it was just a setting in the CMOS
gameplay_manager~starting_extra_ship    dc i4'gameplay_manager~starting_extra_ship~easy,gameplay_manager~starting_extra_ship~hard'

gameplay_manager~starting_extra_ship_add~easy equ $00010000
gameplay_manager~starting_extra_ship_add~hard equ $00020000
gameplay_manager~starting_extra_ship_add dc i4'gameplay_manager~starting_extra_ship_add~easy,gameplay_manager~starting_extra_ship_add~hard'

; Selection of the starting population/difficulty timer tables

gameplay_manager~starting_pop_table_adjust~easy equ 0
gameplay_manager~starting_pop_table_adjust~hard equ 1
gameplay_manager~starting_pop_table_adjust~max_level equ 2

gameplay_manager~starting_pop_table_adjust dc i'gameplay_manager~starting_pop_table_adjust~easy,gameplay_manager~starting_pop_table_adjust~hard'

; This is the active value, used during a player's turn.  It is not per-player.  It is also x2, to make it easier to use as an index
gameplay_manager~active_starting_pop_table_adjust dc i'gameplay_manager~starting_pop_table_adjust~easy'

; Optional 'attraction', which will deflect the crystal toward the player
crystal_attraction~off      equ 0
crystal_attraction~low      equ 1
crystal_attraction~high     equ 2
crystal_attraction~max_level equ 3

; Crystal Attraction state
gameplay_manager~starting_crystal_attraction~easy equ crystal_attraction~high
gameplay_manager~starting_crystal_attraction~hard equ crystal_attraction~off
gameplay_manager~starting_crystal_attraction dc i'gameplay_manager~starting_crystal_attraction~easy,gameplay_manager~starting_crystal_attraction~hard'

; The axis distance ranges
crystal_attraction~low_distance equ 10
crystal_attraction~high_distance equ 20

; The current state.  This will be applied when
gameplay_crystal_attraction~state dc i'crystal_attraction~off'

; Cheats
gameplay_manager~cheat~unlimited_sinibombs dc i'0'          ; boolean, 0 or $ffff
gameplay_manager~cheat~unlimited_ships  dc i'0'             ; boolean, 0 or $ffff

gameplay_player_defaults~use_keyboard   equ 0
gameplay_player_defaults~use_gamepad    equ gameplay_player_defaults~use_keyboard+2
gameplay_player_defaults~use_analog_joystick equ gameplay_player_defaults~use_gamepad+2
sizeof~gameplay_player_defaults         equ gameplay_player_defaults~use_analog_joystick+2

; This table would need to grow, if gameplay_max_players is more than 2
gameplay_manager~player_defaults_offsets dc i'0'
                                        dc i'sizeof~gameplay_player_defaults'

; The default states for the input preference.  This is copied into the player states.
gameplay_player_defaults                anop
gameplay_manager~player_1_default~use_keyboard dc i'1'
gameplay_manager~player_1_default~use_gamepad dc i'1'           ; this is the controller number
gameplay_manager~player_1_default~use_analog_joystick dc i'0'
gameplay_manager~player_2_default~use_keyboard dc i'1'
gameplay_manager~player_2_default~use_gamepad dc i'1'           ; this is the controller number
gameplay_manager~player_2_default~use_analog_joystick dc i'0'

; Zone Color, used to draw some of the UI in the original.  Since I am able to have different palettes in the UI area
; I am using the UI equates instead.
gameplay_manager~zone_color_table   anop
                            dc i'appdata~ui_color~black~bits'                 ; void zone is black
                            dc i'appdata~ui_color~red~bits'                   ; worker zone is red
                            dc i'appdata~ui_color~purple~bits'                ; warrior zone is dark purple
                            dc i'appdata~ui_color~blue_gray~bits'             ; planetoid zone is blue-gray

; This table would need to grow, if gameplay_max_players is more than 2
gameplay_manager~player_state_offsets   dc i'0'
                                        dc i'sizeof~player_state'

; The active player index
gameplay_manager~active_player  dc i'-1'
gameplay_manager~active_player_x2 dc i'-1'                                  ; active_player x 2, for easier indexing

gameplay_manager~player_1_state_offset equ sizeof~player_state*0
gameplay_manager~player_2_state_offset equ sizeof~player_state*1

gameplay_manager~active_player_state_offset equ sizeof~player_state*gameplay_max_players
; Player states
; Use offsets in the player_state struct definition to access.

; The saved states of the players
gameplay_manager~player_states  ds sizeof~player_state*gameplay_max_players
; Active player state.  This is swapped with the values in the two player state buffer
; Keep this instance after all the persistant player state buffers, so that
; it can be accessed with a sizeof~player_state*gameplay_max_players offset
gameplay_manager~active_state   ds sizeof~player_state

gameplay_manager~show_fps_60_color  equ appdata~ui_color~yellow~bits
gameplay_manager~show_fps_30_color  equ appdata~ui_color~blue~bits
gameplay_manager~show_fps_less_30_color equ appdata~ui_color~red~bits

gameplay_manager~show_fps_pixels    equ $e12000+160+156

; Should we show the FPS pip?
gameplay_manager~fps_pip            ds 2
; Should we limit the FPS to 30?
gameplay_manager~fps_limiter        ds 2

gameplay_manager~below_30fps_count  ds 4
gameplay_manager~30fps_count        ds 4
gameplay_manager~60fps_count        ds 4
gameplay_manager~frame_count        ds 4

; A special flag that will help create a game for static profiling
                                    aif C:debug~use_profile_state=0,.skip
gameplay_manager~static_profile    dc i'0'
.skip

; Debug Handler
gameplay_debug_handler_priority equ $0001
gameplay_difficulty_debug_handler_priority equ $0001

gameplay_debug_handler      dc i'gameplay_debug_handler_id'
                            dc i'gameplay_debug_handler_priority'
                            dc a4'gameplay_debug_handler_show_info'
                            dc a4'gameplay_debug_handler_show_help'
                            dc a4'gameplay_debug_handler_keypress'

gameplay_difficulty_debug_handler dc i'gameplay_difficulty_debug_handler_id'
                            dc i'gameplay_difficulty_debug_handler_priority'
                            dc a4'gameplay_difficulty_debug_handler_show_info'
                            dc a4'gameplay_difficulty_debug_handler_show_help'
                            dc a4'gameplay_difficulty_debug_handler_keypress'

                            end
; ----------------------------------------------------------------------------
gameplay_manager_initialize start seg_gameplay
                            using gameplay_player_logic_data
                            using gameplay_manager_data

                            debugtag 'initialize'
                            debugtag 'gameplay_manager'

                            setlocaldatabank

                            lda #-1
                            sta gameplay_manager~active_player
                            sta gameplay_manager~active_player_x2

; Clear the player states
                            ldx #(sizeof~player_state*gameplay_max_players)-2
loop                        stz gameplay_manager~player_states,x
                            dex
                            dex
                            bpl loop

                            jsl gameplay_manager_state_initialize

; Install the debug handler
                            pushptr #gameplay_debug_handler
                            pushsword #0                                    ; start off disabled
                            jsl appdebug_install_handler

; And the difficulty handler
                            pushptr #gameplay_difficulty_debug_handler
                            pushsword #0                                    ; start off disabled
                            jsl appdebug_install_handler

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_manager_start_game start seg_gameplay
                            using appdata
                            using inputlib_data
                            using player_entity_data
                            using gameplay_player_logic_data
                            using gameplay_level_data
                            using gameplay_manager_data

                            debugtag 'start_game'
                            debugtag 'gameplay_manager'

                            begin_locals
work_area_size              end_locals

                            sub (2:wPlayerCount),work_area_size

                            setlocaldatabank

                            aif C:debug~use_profile_state=0,.skip
                            lda gameplay_manager~static_profile
                            bpl no_profile
; Make sure the random number generator is the same every time
                            lda #$6743
                            jsl math~rnd_initialize
                            jsl math~rnd3_initialize
no_profile                  anop
.skip

; Almost certainly going to just support 2 players, but I will make the code support N players.

                            lda <wPlayerCount
                            sta >gameplay_manager~player_count

; Clear the player states
                            ldx #(sizeof~player_state*gameplay_max_players)-2
clear_loop                  stz gameplay_manager~player_states,x
                            dex
                            dex
                            bpl clear_loop

; Set the values that are non-zero
                            lda gameplay_manager~difficulty
                            asl a
                            tay                             ; Difficulty index in Y

                            ldx #0                          ; Player offset in X
init_player_loop            anop
; Set the starting ships
                            lda gameplay_manager~starting_ship_count,y
                            sta gameplay_manager~player_states+player_state~ship_count,x
                            lda gameplay_manager~starting_bomb_count,y
                            sta gameplay_manager~player_states+player_state~bomb_count,x
; These next values are 32 bit
                            phy
                            tay
                            asl a
                            tay
; Extra ship points
                            lda gameplay_manager~starting_extra_ship,y
                            sta gameplay_manager~player_states+player_state~extra_ship_points,x
                            sta gameplay_manager~player_states+player_state~next_ship_score,x
                            lda gameplay_manager~starting_extra_ship+2,y
                            sta gameplay_manager~player_states+player_state~extra_ship_points+2,x
                            sta gameplay_manager~player_states+player_state~next_ship_score+2,x
; Amount to increment, per ship gained.
                            lda gameplay_manager~starting_extra_ship_add,y
                            sta gameplay_manager~player_states+player_state~extra_ship_add,x
                            lda gameplay_manager~starting_extra_ship_add+2,y
                            sta gameplay_manager~player_states+player_state~extra_ship_add+2,x

                            ply
; Mark that they are starting a new level.
                            lda #1
                            sta gameplay_manager~player_states+player_state~new_level,x
; Set how many pieces Sinitar starts with. Can be upped for testing Sinistar's death or higher difficulty (like this game needs that)
                            lda #0 ; 19
                            sta gameplay_manager~player_states+player_state~sinistar~pieces_built,x

                            txa
                            clc
                            adc #sizeof~player_state
                            tax
                            dec <wPlayerCount
                            bne init_player_loop

; Non-Player centric values
                            lda gameplay_manager~difficulty_adjust,y
                            sta gameplay_manager~active_difficulty_adjust

                            lda gameplay_manager~starting_pop_table_adjust,y
                            asl a               ; most uses, want it x2, so store it that way.
                            sta gameplay_manager~active_starting_pop_table_adjust

; Setup the input preferences
                            lda gameplay_manager~player_1_default~use_keyboard
                            sta gameplay_manager~player_states+player_state~use_keyboard
                            lda gameplay_manager~player_1_default~use_gamepad
                            sta gameplay_manager~player_states+player_state~use_gamepad
;                           lda gameplay_manager~player_1_default~use_analog_joystick
                            lda >input~analog_joystick_enabled
                            sta gameplay_manager~player_states+player_state~use_analog_joystick

                            lda gameplay_manager~player_2_default~use_keyboard
                            sta gameplay_manager~player_states+sizeof~player_state+player_state~use_keyboard
                            lda gameplay_manager~player_2_default~use_gamepad
                            sta gameplay_manager~player_states+sizeof~player_state+player_state~use_gamepad
;                           lda gameplay_manager~player_2_default~use_analog_joystick
                            lda >input~analog_joystick_enabled
                            sta gameplay_manager~player_states+sizeof~player_state+player_state~use_analog_joystick

                            pushsword #$ffff                            ; make no player active, which will signal the turn_start state that the game is starting.
                            jsl gameplay_activate_player

                            lda #app_state~player_turn_start
                            sta >appdata~pending_state

                            lda >appdata~fps_pip
                            sta gameplay_manager~fps_pip
                            lda >appdata~fps_limiter
                            sta gameplay_manager~fps_limiter

                            stz gameplay_manager~below_30fps_count
                            stz gameplay_manager~below_30fps_count+2
                            stz gameplay_manager~30fps_count
                            stz gameplay_manager~30fps_count+2
                            stz gameplay_manager~60fps_count
                            stz gameplay_manager~60fps_count+2
                            stz gameplay_manager~frame_count
                            stz gameplay_manager~frame_count+2

                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; End the game.  This will cleanup a most things, however, it will not
; erase the contents of gameplay_manager~player_states, so it can be used
; from the high_score state.
gameplay_manager_end_game   start seg_gameplay

                            debugtag 'end_game'
                            debugtag 'gameplay_manager'

; Doing this explicitly, though there is a mechanism for adding a state deactivate callback
; I'm not sure why I'm not using that...
                            jsl gameplay_manager_state_deactivate

                            rtl
                            end

; ----------------------------------------------------------------------------
; Make a player the active player
; Currently does NOT deactivate the active player, if different.
; This will not do anything if the player is already active.
gameplay_activate_player    start seg_gameplay
                            using inputlib_data
                            using gameplay_manager_data
                            using task_manager_data

                            debugtag 'activate_player'

                            begin_locals
work_area_size              end_locals

                            sub (2:wPlayerIndex),work_area_size

                            setlocaldatabank

                            lda <wPlayerIndex
                            cmp gameplay_manager~active_player
                            beq already_activated

                            sta gameplay_manager~active_player
                            bit #$8000
                            bne set_no_player                       ; ok to set no-player

                            tay
                            asl a
                            sta gameplay_manager~active_player_x2   ; set the helper value

                            lda #0
loop                        dey
                            bmi have_offset
                            clc
                            adc #sizeof~player_state
                            bra loop

have_offset                 anop
                            tax

; Copy the stored state to the active state
; There isn't much in the player state, at least not right now, so this could just copy the specific entries instead of looping.
                            ldy #0
copy_loop                   lda gameplay_manager~player_states,x
                            sta gameplay_manager~active_state,y
                            inx
                            inx
                            iny
                            iny
                            cpy #sizeof~player_state
                            bne copy_loop

                            lda >input~gamepad_slot
                            bne has_gamepad
; Make sure we don't try to access it.  Might just want to check this in the input loop
                            stz gameplay_manager~active_state+player_state~use_gamepad
has_gamepad                 anop
already_activated           anop
                            restoredatabank
                            ret
set_no_player               sta gameplay_manager~active_player_x2
                            bra already_activated

                            end

; ----------------------------------------------------------------------------
; Copy the active players state, to its storage area.
gameplay_deactivate_player  start seg_gameplay
                            using gameplay_manager_data
                            using task_manager_data

                            debugtag 'deactivate_player'

                            setlocaldatabank

                            lda gameplay_manager~active_player
                            bmi already_deactivated

; Note, for now, I'm not changing the active player to -1, so that activating the deactivated player is simpler.

                            tay
                            lda #0
loop                        dey
                            bmi have_offset
                            clc
                            adc #sizeof~player_state
                            bra loop

have_offset                 anop
                            tax

; Copy the active state to the stored state
; There isn't much in the player state, at least not right now, so this could just copy the specific entries instead of looping.
                            ldy #0
copy_loop                   lda gameplay_manager~active_state,y
                            sta gameplay_manager~player_states,x
                            inx
                            inx
                            iny
                            iny
                            cpy #sizeof~player_state
                            bne copy_loop

                            lda #-1
                            sta gameplay_manager~active_player
                            sta gameplay_manager~active_player_x2

already_deactivated         anop
                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
; From the current active player, what is the next player.
;
; Returns:
; The next player in the acc.  This can return the active player, if it is a single player game.
; Returns -1 in the acc and the carry set, if there are no more players.
gameplay_manager_get_next_player start seg_gameplay
                            using appdata
                            using gameplay_manager_data

                            debugtag 'get_next_player'

                            begin_locals
wPlayer                     decl word
wCount                      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; This loop is overkill, as it will handle N players
                            lda gameplay_manager~player_count
                            sta <wCount

                            lda gameplay_manager~active_player
loop                        inc a
                            cmp gameplay_manager~player_count
                            blt ok_player
                            lda #0                                      ; wrap
ok_player                   anop
                            sta <wPlayer
                            cmp gameplay_manager~active_player
                            bne inactive_player
; If on the active player, we must check that location
                            lda gameplay_manager~active_state+player_state~ship_count
                            bra check
inactive_player             asl a
                            tay
                            ldx gameplay_manager~player_state_offsets,y
                            lda gameplay_manager~player_states+player_state~ship_count,x
check                       bne has_ships
                            lda <wPlayer
                            dec <wCount
                            bne loop

                            sec
                            lda #$ffff
                            sta <wPlayer
                            bra exit

has_ships                   clc
exit                        restoredatabank
                            retkc 2:wPlayer

                            end

; ----------------------------------------------------------------------------
; Handles the turn end for a player
gameplay_turn_end           start seg_gameplay
                            using appdata
                            using gameplay_manager_data

                            debugtag 'turn_end'

; All we do is go to the cut screen, which will handle the transition
                            lda #app_state~player_turn_start
                            sta >appdata~pending_state

                            rtl
                            end

; ----------------------------------------------------------------------------
; The gameplay state is initializing.
; This is called once, at the start of the app, before the first activate of the state.
; This should NOT draw anything.
gameplay_manager_state_initialize start seg_gameplay
                            using appdata
                            using softswitch_definitions

                            debugtag 'state_initialize'
                            debugtag 'gameplay_manager'

                            jsl gameplay_playfield_initialize

; Do one-time initialization of sub-systems. No drawing!  Most of these don't actually do anything.
                            jsl gameplay_player_initialize
                            jsl gameplay_rocks_initialize
                            jsl gameplay_workers_initialize
                            jsl gameplay_warriors_initialize
                            jsl gameplay_sinistar_initialize
                            jsl gameplay_shots_initialize
                            jsl gameplay_crystals_initialize
                            jsl gameplay_bombs_initialize
                            jsl gameplay_explosions_initialize

                            jsl gameplay_level_initialize

                            jsl gameplay_ui_initialize

                            jsl stars_manager_initialize

                            rtl
                            end

; ----------------------------------------------------------------------------
; The gameplay state is uninitializing.
; This is called when the app is shutting down
; This should NOT draw anything.
gameplay_manager_state_uninitialize start seg_gameplay
                            using appdata
                            using softswitch_definitions

                            debugtag 'state_uninitialize'
                            debugtag 'gameplay_manager'

                            jsl gameplay_level_uninitialize

                            jsl gameplay_bombs_uninitialize
                            jsl gameplay_crystals_uninitialize
                            jsl gameplay_shots_uninitialize
                            jsl gameplay_sinistar_uninitialize
                            jsl gameplay_warriors_uninitialize
                            jsl gameplay_workers_uninitialize
                            jsl gameplay_rocks_uninitialize
                            jsl gameplay_player_uninitialize
                            jsl gameplay_explosions_uninitialize

                            jsl gameplay_playfield_uninitialize

                            rtl
                            end
; ----------------------------------------------------------------------------
; The gameplay state is activating
; This can be coming from another state, including the player swap / post-death cut screen
; so this is not necessarily a complete initialization of the state, though this should
; assume that it needs to draw the entire screen, including setting palettes
gameplay_manager_state_activate start seg_gameplay
                            using appdata
                            using gameplay_level_data
                            using gameplay_manager_data
                            using softswitch_definitions

                            debugtag 'state_activate'
                            debugtag 'gameplay_manager'

                            lda #0
                            sta >gameplay_manager_logic~last_tick
                            sta >gameplay_manager_logic~last_tick+2

; Doing explicit pass of deactivate, then activate, so that everything is released, then rebuilt, rather than intermixing.
; This way, I can see if things go to zero, etc.

; Deactivate, maybe do this in in gameplay_turn_end?  gameplay_manager~active_player will have already been switched!
                            jsl gameplay_manager_state_deactivate

; Activate
; Note, not calling all the sub-systems, as most don't need an explicit call.
                            jsl collision_support_turn_activate
                            jsl gameplay_playfield_turn_activate
                            jsl gameplay_player_turn_activate
                            jsl gameplay_sinistar_turn_activate
                            jsl gameplay_crystal_turn_activate

; This calls the populate function, which will rebuild all the other items in the playfield.
                            jsl gameplay_level_turn_activate

                            jsl gameplay_playfield_view_apply_palette

                            jsl stars_manager_turn_activate

; Clear and do one draw pass
                            pushsword #gameplay_ui_playfield_left
                            pushsword #gameplay_ui_playfield_top
                            pushsword #gameplay_ui_playfield_width
                            pushsword #gameplay_ui_playfield_height
                            pushword #0
                            jsl grlib_alt_screen_fill_rect

                            jsl playfield_view_draw
                            jsl stars_manager_update

; We should do this next bit in the vbl
                            jsl grlib_wait_one_frame

                            jsl gameplay_ui_turn_activate
                            jsl gameplay_upper_ui_to_screen
                            jsl gameplay_lower_ui_to_screen

                            pushsword #gameplay_ui_playfield_left
                            pushsword #gameplay_ui_playfield_top
                            pushsword #gameplay_ui_playfield_width
                            pushsword #gameplay_ui_playfield_height
                            jsl grlib_alt_screen_to_screen_rect

                            rtl
                            end

; ----------------------------------------------------------------------------
; The gameplay state is deactivating.
; This will make sure the various sytems have their resources.
gameplay_manager_state_deactivate start seg_gameplay

                            debugtag 'state_deactivate'
                            debugtag 'gameplay_manager'

; I'm expecting that these are all safe to call, even if the system is already deactivated
                            jsl gameplay_level_turn_deactivate
                            jsl gameplay_sinistar_turn_deactivate
                            jsl gameplay_player_turn_deactivate
                            jsl gameplay_shots_state_deactivate
                            jsl gameplay_rocks_turn_deactivate
                            jsl gameplay_bombs_turn_deactivate
                            jsl gameplay_crystals_turn_deactivate
                            jsl gameplay_workers_turn_deactivate
                            jsl gameplay_warriors_turn_deactivate
                            jsl gameplay_explosions_turn_deactivate

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_manager_state_tick start seg_gameplay
                            using appdata
                            using applib_data
                            using gameplay_manager_data
                            using gameplay_level_data
                            using playfield_manager_data

                            debugtag 'state_tick'
                            debugtag 'gameplay_manager'

                            setlocaldatabank

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            lda >applib~current_tick
                            sec
                            sbc gameplay_manager_logic~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc gameplay_manager_logic~last_tick+2
                            bne big_ticks
                            txa
                            bne some_ticks
; No ticks have passed
;                           jsr gameplay_off_tick
                            bra no_ticks

big_ticks                   lda #2
some_ticks                  bit gameplay_manager~fps_limiter                ; Are we trying to limit to 30fps?
                            bpl no_limiter
                            cmp #2
                            blt no_ticks
no_limiter                  jsr gameplay_on_tick

continue                    anop
; Wait for some amount of time.  This can be used to 'slow-down' the game, to see things better.
; Usually this is 0, and we don't wait at all
                            lda >appdata~wait_time
                            beq no_wait
                            jsl applib_wait_ticks
no_wait                     anop
; Update the FPS
                            jsl applib_update_fps

                            lda #0
                            sta playfield_manager~view_changed
                            restoredatabank
                            rtl

no_ticks                    anop
; We don't do any logic, if no ticks have passed, so we are not going to really count this as a 'frame'
; since we can get to the point where we are wasting a lot of time, just waiting for a tick,
; and the FPS calculation would break.

; This busy waiting isn't particularly effective, since we could be right-on-the edge of a tick
; It might be good to maybe do assume that would have a tick click over, and fake that 1 tick passed,
; but then force a VBL wait (essentially a tick)

; Do we have a forced wait?
                            lda >appdata~wait_time
                            beq no_wait2
; Yes
                            jsl applib_wait_ticks
; Then count this as a 'frame'
                            jsl applib_update_fps

no_wait2                    lda #0
                            sta playfield_manager~view_changed
                            restoredatabank
                            rtl

                            end

; -----------------------------------------------------------------------------
; Update the 'on tick' gameplay.
; The acc must contain the delta ticks, which should be at least 1
gameplay_on_tick            private seg_gameplay
                            using appdata
                            using gameplay_manager_data
                            using gameplay_level_data
                            using gameplay_player_logic_data
                            using playfield_manager_data
                            using inputlib_data

; Save the delta
                            sta gameplay_manager_logic~tick_delta

                            jsr game_logic_tick

; If the player is dead or dying, don't update the scanner.  The screen should not be scrolling around
; and it probably doesn't matter if the scanner is frozen, and this will save us some
; CPU cycles that can be put toward the player explosion.
                            lda gameplay_player~is_dead
                            ora gameplay_player~is_dying
                            bne no_scanner

                            jsl playfield_scanner_update
no_scanner                  anop

                            jsl gameplay_upper_ui_tick
; Erase the invalidate rects
;                           jsl grlib_erase_invalidated_rects
; Filling instead of erasing from an alternate buffer

                            aif app~use_merged_update_rects=0,.skip
; If enabled. this path uses merged update rects for the invalidation
                            lda #$0000
                            jsl grlib_fill_invalidated_rects
.skip
                            aif app~use_non_merged_update_rects=0,.skip
; If enabled. this path uses queued (non-merged) update rects for the invalidation
                            jsr _set_view_clip_rect
                            lda #$0000
                            jsl grlib_fill_queued_erase_rects
.skip

                            jsl playfield_view_draw

; Check for collisions
                            jsl collision_test_all
; Debugging
                            lda >appdata~debug_update_rects
                            beq skip_debug_update_rects
                            pha

                            aif app~use_merged_update_rects=0,.skip
                            jsl grlib_update_rects_pre_update
.skip
                            aif app~use_non_merged_update_rects=0,.skip
                            jsl grlib_queued_update_rects_pre_update
.skip
                            bcc skip_debug_update_rects
                            lda #0
                            sta >appdata~debug_update_rects                 ; Pressed ESC while waiting, clear the debug rects.
skip_debug_update_rects     anop

                            lda >appdata~debug_collision_rects
                            beq skip_debug_collision_rects
                            pha
                            jsl collision_rects_debug_draw
                            bcc skip_debug_collision_rects
                            lda #0
                            sta >appdata~debug_collision_rects              ; Pressed ESC while waiting, clear the debug rects.
skip_debug_collision_rects  anop

; Update Sinistar animation
                            lda gameplay_manager_logic~tick_delta
                            jsl gameplay_sinistar_update_speech_anim
; Update colors
                            jsl playfield_view_apply_palette
; Copy the invalidate rects to the screen

; Using merged update rects, do this
                            aif app~use_merged_update_rects=0,.skip
                            jsl grlib_update_invalidated_rects
.skip
; Using queued update rects (not merged), do this
                            aif app~use_non_merged_update_rects=0,.skip
                            jsl grlib_update_queued_rects
.skip
; See if explosion streaks need to be drawn.  I don't like the overhead of having to call this
; all the time. I may make it a bit uglier and pull the check for the streak count to here
; just to save the overlead.
; Could also have do a "bra skip" that is always here, and then nop it out when the explosion is active.
                            jsl explosion_streaks_draw
; Draw the stars last
                            jsl stars_manager_update

                            jsr _set_full_screen_clip_rect

; Input handling
                            jsl snes_max_read_controller                    ; read the button state for the controller, if enabled.

                            jsl get_key_press
                            beq no_keypress
; If this is enabled, the exit game can happen from any screen
;                           cmp #'Q'
;                           beq exit_done
;                           cmp #'q'
;                           beq exit_done
                            pha
                            jsl handle_common_keypresses
; Is this player using the keyboard?
                            lda gameplay_manager~active_state+player_state~use_keyboard
                            beq no_player_keyboard
                            bcc no_keypress                                 ; handled?
                            pushsword >input~last_key_down
                            jsl gameplay_player_handle_key

; Handle 'buttons', these are either 'keyboard' buttons, which are the keys we can tell immediate up/down states
; or the gamepad.  We are not currently going to support both, because the two functions will fight against
; each other.  Might fix this, but really, you are going to be using one or the other.
no_keypress                 anop
; Is this player using the keyboard?
                            lda gameplay_manager~active_state+player_state~use_keyboard
                            beq no_player_keyboard2
                            lda >input~last_key_up
                            beq no_player_keyboard2
                            pha
                            jsl gameplay_player_handle_key_up

no_player_keyboard2         anop
                            lda gameplay_manager~active_state+player_state~use_gamepad         ; if the gamepad is on, use that over the keyboard buttons
                            bne player_use_gamepad
                            lda gameplay_manager~active_state+player_state~use_analog_joystick ; if the joysitck is on, use that over the keyboard buttons
                            bne player_use_analog_joystick

                            pushsword >input~last_key_modifiers
                            jsl gameplay_player_handle_key_buttons

no_player_keyboard          lda gameplay_manager~active_state+player_state~use_gamepad
                            beq no_player_gamead
player_use_gamepad          pha
                            jsl gameplay_player_handle_gamepad
                            bra player_input_done

no_player_gamead            anop
                            lda gameplay_manager~active_state+player_state~use_analog_joystick ; if the joysitck is on, use that over the keyboard buttons
                            beq player_input_done

player_use_analog_joystick  anop
                            pushsword >input~last_key_modifiers
                            jsl gameplay_player_handle_joystick
                            bcc player_input_done
; If the joystick handler return with the carry on, it means it didn't see the joystick.  Fallback to the keyboard buttons
; Should maybe do some kind of count of how many passes we didn't see the joystick and just disable it?
                            pushsword >input~last_key_modifiers
                            jsl gameplay_player_handle_key_buttons

player_input_done           anop
                            jsl grlib_update_rects_frame_end

; Some debugging helpers.
                            jsl appdebug_update_text_screen
                            rts

; Say we want to exit the game
exit_done                   lda #$ffff
                            sta >appdata~exit_requested
                            rts

                            end

; -----------------------------------------------------------------------------
_set_view_clip_rect         private seg_gameplay
                            using grlib_global_equates
                            using grlib_global_data
                            using gameplay_level_data

                            phd
                            lda >grlib~dp
                            tcd

                            lda gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~left
                            sta <clipx_left
                            lda gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~top
                            sta <clipy_top
                            lda gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~right
                            sta <clipx_right
                            lda gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~bottom
                            sta <clipy_bottom

                            pld
                            rts
                            end

; -----------------------------------------------------------------------------
_set_full_screen_clip_rect  private seg_gameplay
                            using grlib_global_equates
                            using grlib_global_data

                            phd
                            lda >grlib~dp
                            tcd

                            stz <clipx_left
                            stz <clipy_top
                            lda #320
                            sta <clipx_right
                            lda #200
                            sta <clipy_bottom

                            pld
                            rts
                            end

; -----------------------------------------------------------------------------
; Do a logic tick pass.
; Assumes that the delta ticks is in A, and must be at least 1
; Can assume the data bank is local
game_logic_tick             private seg_gameplay
                            using grlib_global_data
                            using gameplay_manager_data
                            using playfield_entity_manager_data
                            using applib_data
                            using appdata

                            debugtag 'game_logic_tick'

;                           keyed_break 1,'logic_tick'

; All logic is going to tick at the same rate.
; This currently includes the updating of positions.
; The position updating, might need to be separated out, as that has more of a requirement
; to be in-sync with each other.
; I may rework this so that I call all the functions, as I did before and have each test if it should
; do logic / position updates, or both.

; Assumes that the delta ticks is in A
                            dec a
                            beq set_speed_modifier_single                   ; 60 fps?

                            lda #$8000                                      ; nope, something less.
                            sta gameplay_manager_logic~speed_modifier       ; this is 0, if 60 fps, or $8000 if 30 or less.
                            sta >playfield_entity~speed_modifier            ; same, but in another bank
; Patch playfield_entity_update_position
                            shortm
                            lda #$0a                                        ; ASL A
                            sta >playfield_entity~update_speed_modifier_patch_x
                            sta >playfield_entity~update_speed_modifier_patch_y
                            sta >playfield_entity~update_speed_modifier_patch_os_x
                            sta >playfield_entity~update_speed_modifier_patch_os_y
                            sta gameplay_sinistar_update_speed_modifier_patch_x
                            sta gameplay_sinistar_update_speed_modifier_patch_y
                            longm

                            cpx #3
                            bge less_30
                            inc gameplay_manager~30fps_count
                            lda gameplay_manager~fps_pip                    ; show a fps pip?
                            beq done_speed_modifier
                            lda #gameplay_manager~show_fps_30_color
                            sta >gameplay_manager~show_fps_pixels
                            bra done_speed_modifier

less_30                     anop
                            inc gameplay_manager~below_30fps_count
                            lda gameplay_manager~fps_pip                    ; show a fps pip?
                            beq done_speed_modifier
                            lda #gameplay_manager~show_fps_less_30_color
                            sta >gameplay_manager~show_fps_pixels
                            bra done_speed_modifier

set_speed_modifier_single   sta gameplay_manager_logic~speed_modifier       ; this is 0, if 60 fps, or $8000 if 30 or less.
                            sta >playfield_entity~speed_modifier            ; same, but in another bank
                            inc gameplay_manager~60fps_count
                            shortm
                            lda #$ea                                        ; NOP
                            sta >playfield_entity~update_speed_modifier_patch_x
                            sta >playfield_entity~update_speed_modifier_patch_y
                            sta >playfield_entity~update_speed_modifier_patch_os_x
                            sta >playfield_entity~update_speed_modifier_patch_os_y
                            sta gameplay_sinistar_update_speed_modifier_patch_x
                            sta gameplay_sinistar_update_speed_modifier_patch_y
                            longm
; Show FPS with a color in the upper-right
                            lda gameplay_manager~fps_pip                    ; show a fps pip?
                            beq done_speed_modifier
                            lda #gameplay_manager~show_fps_60_color
                            sta >gameplay_manager~show_fps_pixels
done_speed_modifier         anop

                            inc gameplay_manager~frame_count
; Store the last time we did something
                            lda >applib~current_tick
                            sta gameplay_manager_logic~last_tick
                            lda >applib~current_tick+2
                            sta gameplay_manager_logic~last_tick+2

                            jsl gameplay_player_logic_tick

; Doing this after the player, because the player tick, also moves the screen.  Is this needed?  Maybe just do the tasks first all the time?
                            aif C:debug~use_profile_state=0,.skip
                            lda gameplay_manager~static_profile
                            bmi no_tasks
.skip
                            jsl task_manager_tick
no_tasks                    lda gameplay_manager_logic~speed_modifier
                            bpl no_extra_tick
                            jsl task_manager_tick
no_extra_tick               anop

; Mainly animation updates, and removals.
                            jsl gameplay_all_rocks_update_tick
                            jsl gameplay_all_workers_update_tick
                            jsl gameplay_all_warriors_update_tick
                            jsl gameplay_all_sinistars_update_tick
                            jsl gameplay_all_shots_update_tick
                            jsl gameplay_all_explosions_update_tick
                            jsl gameplay_all_crystals_update_tick
                            jsl gameplay_all_bombs_update_tick

                            clc
                            rts

                            end

; ----------------------------------------------------------------------------
; The game is paused (and possibly not even in-game)
; Parameters:
;  delta ticks in acc
gameplay_do_paused_tick     start seg_gameplay
                            using player_entity_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            cmp #0
                            beq no_ticks

                            lda >gameplay_manager~active_player
                            bmi no_active_player

                            lda >gameplay_manager~active_state+player_state~use_gamepad
                            beq no_player_gamead

                            pha
                            jsl gameplay_player_handle_gamepad_paused

no_player_gamead            anop
no_active_player            anop
no_ticks                    anop
                            rtl

                            end

; ----------------------------------------------------------------------------
; Add what is in the acc, to the score
; Note, to make printing of the value easier, the input and the stored value
; are BCD!
gameplay_add_to_score       start seg_gameplay
                            using player_entity_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            phx
                            ldx #0
                            jsl gameplay_add_to_score_32
                            plx
                            rtl

                            end

; ----------------------------------------------------------------------------
; Add what is in the acc (low) and X (high) to the score
; Note, to make printing of the value easier, the input and the stored value
; are BCD!
gameplay_add_to_score_32    start seg_gameplay
                            using player_entity_data
                            using gameplay_manager_data
                            using gameplay_ui_data
                            using gameplay_sound_data

                            setlocaldatabank

                            inc gameplay_ui~player_score_needs_update           ; flag that it needs an update

                            sed                 ; BCD
                            clc
                            adc gameplay_manager~active_state+player_state~score
                            sta gameplay_manager~active_state+player_state~score

                            txa
                            adc gameplay_manager~active_state+player_state~score+2
                            sta gameplay_manager~active_state+player_state~score+2
                            bcc no_overflow

; Note, the original did not clamp the score, it just wrapped.
; Clear the flag tracking that the next-ship-bonus has wrapped
                            stz gameplay_manager~active_state+player_state~next_ship_score_wrapped
                            bra did_overflow                                        ; force a ship award

no_overflow                 anop

; See if the next ship bonus has wrapped.
; If this is on, then it signals that the next ship bonus is higher than the player's maximum score.
; However, once the player reaches their max score, their score will 'wrap', and this flag will be cleared.
; However, (again), the next ship score isn't clamped either, so it will 'appear' to be less than the maximum score
; though it will still be large, and the player will have a hell of a time reaching it.
; Overall, this is a bit odd, and really, the game is so hard, it is unrealistic that any of this happens without
; cheating.  Maybe revist?  Maybe I got some of this wrong?
                            lda gameplay_manager~active_state+player_state~next_ship_score_wrapped
                            bne no_bonus

; See if we have reached the next bonus.
                            lda gameplay_manager~active_state+player_state~score+2
                            cmp gameplay_manager~active_state+player_state~next_ship_score+2
                            blt no_bonus
                            lda gameplay_manager~active_state+player_state~score
                            cmp gameplay_manager~active_state+player_state~next_ship_score
                            blt no_bonus

did_overflow                anop
; Earned an extra ship!
; Update the extra ship adder.  Note, this makes getting an extra ship, harder and harder.  Setting player_state~extra_ship_add to 0 keeps the next ship points constant.
; Unlike the original, I am not using the extra_ship_add and extra_ship_points values as x100, i.e. shifted up by a byte.  Seems unnecessary, and it is easier to just keep everything in the same domain
                            clc
                            lda gameplay_manager~active_state+player_state~extra_ship_add
                            adc gameplay_manager~active_state+player_state~extra_ship_points
                            sta gameplay_manager~active_state+player_state~extra_ship_points

                            lda gameplay_manager~active_state+player_state~extra_ship_add+2
                            adc gameplay_manager~active_state+player_state~extra_ship_points+2
                            sta gameplay_manager~active_state+player_state~extra_ship_points+2
                            bcc no_extra_add_overflow
; Set to 99,999,900 (decimal)
                            lda #$9999
                            sta gameplay_manager~active_state+player_state~extra_ship_points+2
                            lda #$9900
                            sta gameplay_manager~active_state+player_state~extra_ship_points

no_extra_add_overflow       anop

                            clc
                            lda gameplay_manager~active_state+player_state~extra_ship_points
                            adc gameplay_manager~active_state+player_state~next_ship_score
                            sta gameplay_manager~active_state+player_state~next_ship_score

                            lda gameplay_manager~active_state+player_state~extra_ship_points+2
                            adc gameplay_manager~active_state+player_state~next_ship_score+2
                            sta gameplay_manager~active_state+player_state~next_ship_score+2
                            bcc no_extra_overflow
; Signal that the next-extra-ship score has overflow, and is 'higher' than the player's max score.
; This does assume that the next-extra-ship score will rise faster than the player's score.
; This will be cleared, if the player's total score wraps.  Until then, this will block the player from getting a bonus ship
                            inc gameplay_manager~active_state+player_state~next_ship_score_wrapped

no_extra_overflow           anop
                            cld
; Up the number of ships
                            lda gameplay_manager~active_state+player_state~ship_count
                            cmp #255
                            inc a
                            sta gameplay_manager~active_state+player_state~ship_count

                            pushsword #id_sfx~new_ship
                            jsl sndlib_play_sfx

; flag that some things need an update
                            inc gameplay_ui~ships_remaining_needs_update
                            inc gameplay_ui~player_bonus_at_needs_update

no_bonus                    anop
                            cld

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
; Add a new player ship to the active player.
; Note, this is mainly a debug / cheat function.  The add_score function does
; this internally too.
gameplay_add_player_ship    start seg_gameplay
                            using gameplay_manager_data
                            using gameplay_ui_data
                            using gameplay_sound_data

; Up the number of ships
                            lda >gameplay_manager~active_state+player_state~ship_count
                            cmp #255
                            inc a
                            sta >gameplay_manager~active_state+player_state~ship_count

                            pushsword #id_sfx~new_ship
                            jsl sndlib_play_sfx

; flag that some things need an update
                            lda #1
                            sta >gameplay_ui~ships_remaining_needs_update
                            rtl

                            end
; ----------------------------------------------------------------------------
; Generate a playfield coordinate that is near one of the edges
; Assumes that the data bank is set to local
gameplay_generate_random_edge_location start seg_gameplay
                            using playfield_manager_data

                            begin_locals
wX                          decl word
wY                          decl word
work_area_size              end_locals

                            debugtag 'random_edge_location'

                            sub ,work_area_size

                            static_assert_equal gameplay_playfield_width,1024
                            static_assert_equal gameplay_playfield_height,1024

; Get a random number
                            generate_rnd16
                            tax

; Look at the view speed and favor the edges it is moving toward
                            lda playfield_manager~view_speed_x
                            and #$ff00                              ; discard fraction
                            beq not_left_or_right
                            bpl include_left
; including right
                            lda playfield_manager~view_speed_y
                            and #$ff00                              ; discard fraction
                            beq right
                            bpl inlcude_right_and_top
; including right and bottom
                            txa
                            bpl right
                            brl bottom

inlcude_right_and_top       txa
                            bpl right
                            brl top

include_left                lda playfield_manager~view_speed_y
                            and #$ff00                              ; discard fraction
                            beq left
                            bpl inlcude_left_and_top
; including left and bottom
                            txa
                            bpl left
                            brl bottom

inlcude_left_and_top        txa
                            bpl left
                            brl top

not_left_or_right           lda playfield_manager~view_speed_y
                            and #$ff00                              ; discard fraction
                            beq any_side
                            bpl top
                            txa
                            brl bottom

any_side                    txa
                            bit #$e000              ; 13-15 clear?
                            beq top
                            bit #$6000              ; 13-14 clear?
                            jeq bottom
                            bit #$2000              ; 13 clear?
                            beq right

; Put it on the left
left                        txa
                            and #$0007
                            sec
                            sbc #4                  ; make a number from -4 to +3
                            shiftleft 8             ; make into an FP16 value
                            clc
                            adc playfield_manager~view_speed_x
                            asr 8
                            clc
                            adc #gameplay_playfield_min_x
                            sta <wX

                            get_quick_rnd16
                            and #gameplay_playfield_height_mask
                            clc
                            adc #gameplay_playfield_min_y
                            sta <wY
                            brl exit

right                       txa
                            and #$0007
                            sec
                            sbc #4                  ; make a number from -4 to +3
                            shiftleft 8             ; make into an FP16 value
                            clc
                            adc playfield_manager~view_speed_x
                            asr_nt 8
                            clc
                            adc #gameplay_playfield_max_x
                            sta <wX

                            get_quick_rnd16
                            and #gameplay_playfield_height_mask
                            clc
                            adc #gameplay_playfield_min_y
                            sta <wY
                            bra exit

top                         txa
                            and #$0007
                            sec
                            sbc #4                  ; make a number from -4 to +3
                            shiftleft 8             ; make into an FP16 value
                            clc
                            adc playfield_manager~view_speed_y
                            asr_nt 8
                            clc
                            adc #gameplay_playfield_min_y
                            sta <wY

                            get_quick_rnd16
                            and #gameplay_playfield_width_mask
                            clc
                            adc #gameplay_playfield_min_x
                            sta <wX
                            bra exit

bottom                      txa
                            and #$0007
                            sec
                            sbc #4                  ; make a number from -4 to +3
                            shiftleft 8             ; make into an FP16 value
                            clc
                            adc playfield_manager~view_speed_y
                            asr_nt 8
                            clc
                            adc #gameplay_playfield_max_y
                            sta <wY

                            get_quick_rnd16
                            and #gameplay_playfield_width_mask
                            clc
                            adc #gameplay_playfield_min_x
                            sta <wX

exit                        ret 4:wX

                            end

; ----------------------------------------------------------------------------
; Set the active player to use the input gamepad.
; Parameters:
; wPlayer - 0, 1 or -1.  -1 will set the active player, else it will set player 0
; wGampad - 0 (disable) or 1 or 2
gameplay_manager_set_player_gamepad_state start seg_gameplay
                            using gameplay_manager_data

                            begin_locals
wX                          decl word
wY                          decl word
work_area_size              end_locals

                            debugtag 'set_active_player_gamepad'

                            sub (2:wPlayer,2:wGamepad),work_area_size

                            setlocaldatabank

                            lda <wGamepad
                            cmp #3
                            blt ok
                            lda #0          ; disable

ok                          anop

                            lda <wPlayer
                            bpl want_specific_player
                            lda gameplay_manager~active_player
                            bpl has_activePlayer
                            lda #0          ; just set player 0
has_activePlayer            sta <wPlayer
want_specific_player        cmp gameplay_manager~active_player
                            bne not_active_player
; Set the current state.
                            lda <wGamepad
                            sta gameplay_manager~active_state+player_state~use_gamepad

not_active_player           lda <wPlayer
                            asl a
                            tay

                            lda <wGamepad
; Update the offturn state (do I need this?  It should get updated when the player's turn is over and the active state is copied back to the offturn)
                            ldx gameplay_manager~player_state_offsets,y
                            sta gameplay_manager~player_states+player_state~use_gamepad,x

; Update the default, so it sticks when the start a new game.
                            ldx gameplay_manager~player_defaults_offsets,y
                            sta gameplay_player_defaults+gameplay_player_defaults~use_gamepad,x

                            restoredatabank
                            ret

                            end

; -----------------------------------------------------------------------------
debug_capture_memory        start seg_gameplay
                            using grlib_global_data
                            using gameplay_manager_data

;                            pushptr #grlib~shr_palettes
;                            pushsword #64
;                            jsl debug_copy_memory_to_buffer
                            rtl
                            end

; -----------------------------------------------------------------------------
debug_compare_memory        start seg_gameplay
                            using grlib_global_data
                            using gameplay_manager_data

;                            tay
;                            pushptr #grlib~shr_palettes
;                            pushsword #64
;                            phy
;                            jsl debug_compare_memory_to_buffer
                            rtl
                            end
