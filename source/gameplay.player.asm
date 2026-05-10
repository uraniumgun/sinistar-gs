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

                            copy source/task.definitions.asm
                            copy source/gameplay.constants.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/app.debug.definitions.asm

                            mcopy generated/gameplay.player.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the player / player entity.

; ----------------------------------------------------------------------------

gameplay_player_logic_data  data seg_gameplay
                            using softswitch_definitions
                            using appdata
                            using inputlib_data

; Task data for a common, countdown timer
countdown_task_data         gequ sizeof~task_control                            ; we are going to use task_sleep and task_resume, so include the task_control header
countdown_task~counter      gequ countdown_task_data
sizeof~countdown_task_data  gequ countdown_task~counter+2

; Task data for the player death task
gameplay_player_death_task_data  equ sizeof~countdown_task_data
sizeof~gameplay_player_death_task_data equ gameplay_player_death_task_data

; The last time the logic was updated
gameplay_player_logic~last_tick     ds 4
; Rate at which logic is updated
gameplay_player_logic~update_rate   equ 2

; The active player is dead, if non-zero (will be negative for easy testing)
gameplay_player~is_dead     dc i'0'
; The active player is in a death sequence, if non-zero (will be negative for easy testing)
; They are not dead yet, but sinistar has got them on the ropes, and we need to let that play out.
gameplay_player~is_dying   dc i'0'
; A flag to delay the 'regular' player death (getting shot by a warrior)
; This is used in some circumstances to prevent the death task from finishing
gameplay_player~death_delayed  dc i'0'
; Collisions are disabled for the player
gameplay_player~collisions_disabled dc i'0'

gameplay_player~should_warp dc i'0'             ; PLUWPF from the original

gameplay_player_thrust~on   dc i'0'
gameplay_player_thrust~on_start_tick dc i4'0'
gameplay_player_thrust~off_start_tick dc i4'0'

; Max speed on an axis for the player
gameplay_player_speed~max_axis equ 4|8
gameplay_player_speed~limiter dc i'gameplay_player_speed~max_axis'

gameplay_player_logic~auto_fire_rate equ 10
gameplay_player_logic~min_fire_rate equ 8

gameplay_player_fire~on     dc i'0'
gameplay_player_fire~on_start_tick dc i4'0'
gameplay_player_fire~last_tick dc i4'0'
gameplay_player_fire~off_start_tick dc i4'0'
gameplay_player_fire~rate   dc i'0'

; Track if a bomb was launched.  This is primarily for the analog stick buttons, so each launch requires an individual press
gameplay_player_sinibomb~launched dc i'0'

; Hmm, do we want to be nice and make these, per-player?
gameplay_player_thrust~key_button   dc i2'ssw~key_down_shift+ssw~key_down_option'   ; shift or option.  Shift is better in an emulator, as option is usually assigned to 'right-alt', which is awkward to press
gameplay_player_fire~key_button     dc i2'ssw~key_down_apple'       ;

; These are for when using the analog joystick.  We still use the modifier key flags, as we are already
; tracking that state.
gameplay_player_fire~joystick_key_button dc i2'ssw~key_down_apple'
gameplay_player_sinibomb~joystick_key_button dc i2'ssw~key_down_option'

gameplay_player_thrust~gamepad_button dc i'input~gamepad_left_shoulder'
gameplay_player_fire~gamepad_button dc i'input~gamepad_y'
gameplay_player_bomb~gamepad_button dc i'input~gamepad_b'
gameplay_player_up~gamepad_button dc i'input~gamepad_dpad_up'
gameplay_player_down~gamepad_button dc i'input~gamepad_dpad_down'
gameplay_player_left~gamepad_button dc i'input~gamepad_dpad_left'
gameplay_player_right~gamepad_button dc i'input~gamepad_dpad_right'
gameplay_player_pause~gamepad_button dc i'input~gamepad_select'

gameplay_player_controls~disabled   dc i'0'
gameplay_player~last_gamepad_state  dc i'0'
gameplay_player~waiting_for_direction_up_key dc i'0'

; Score values.  Note these are BCD format!
gameplay_score~planetoid            equ $0005
gameplay_score~capture_crystal      equ $0200
gameplay_score~kill_worker          equ $0150
gameplay_score~kill_warrior         equ $0500
gameplay_score~kill_warrior_shot    equ $0100
gameplay_score~kill_sinistar        equ $00015000   ; For when he is complete
gameplay_score~kill_sinistar_part   equ $0500       ; just bombing a part, when he is incomplete

; Where the player is, in view space.  Note, the + in front of the equate, is there, just to prevent a compile error.
player_view_center_x        equ 0 ; +((gameplay_ui_playfield_right-gameplay_ui_playfield_left)/2)
player_view_center_y        equ 0 ; +((gameplay_ui_playfield_bottom-gameplay_ui_playfield_top)/2)

; Center of the view, in screen space
player_screen_center_x      equ +((gameplay_ui_playfield_right-gameplay_ui_playfield_left)/2)+gameplay_ui_playfield_left
player_screen_center_y      equ +((gameplay_ui_playfield_bottom-gameplay_ui_playfield_top)/2)+gameplay_ui_playfield_top

; The area where the player can move around, without scrolling the view.
player_screen_max_top       equ player_screen_center_y-20           ;gameplay_ui_playfield_top+40
player_screen_max_bottom    equ player_screen_center_y+20           ;gameplay_ui_playfield_bottom-40
player_screen_max_left      equ player_screen_center_x-30           ;gameplay_ui_playfield_left+40
player_screen_max_right     equ player_screen_center_x+30           ;gameplay_ui_playfield_right-40

; Debug Handler
player_debug_handler_priority equ $0020                     ; middle area

player_debug_handler        dc i'player_debug_handler_id'
                            dc i'player_debug_handler_priority'
                            dc a4'player_debug_handler_show_info'
                            dc a4'player_debug_handler_show_help'
                            dc a4'player_debug_handler_keypress'

; From stblimpulse in the original (the one in ZSTBLIMP.SRC)
; In the original, this was used as an orbital table, but then the code was patched to be used as an intercept table.
; Orbital tables need their distances to be x 16, which this is not.
gameplay_player~impulse_speed_table anop
                            dc i'$7fff,$1fff,acceleration_function~3'
                            dc i'0250,$0100,acceleration_function~5'
                            dc i'0100,$0080,acceleration_function~2'    ; vel was $0070
                            dc i'0064,$0080,acceleration_function~2'    ; vel was $0070
                            dc i'0048,$0080,acceleration_function~2'    ; vel was $0060
                            dc i'0032,$0040,acceleration_function~2'
                            dc i'0016,$0020,acceleration_function~1'
                            dc i'0000,$0000,acceleration_function~0'

                            end

; ----------------------------------------------------------------------------
gameplay_player_initialize  start seg_gameplay
                            using gameplay_player_logic_data

                            debugtag 'player_initialize'

                            pushptr #player_debug_handler
                            pushsword #1                                    ; start off enabled
                            jsl appdebug_install_handler

; We don't have a mid-level player entity manager, so do its work here
                            jsl player_entity_preload_images

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_player_uninitialize start seg_gameplay
                            using gameplay_level_data

                            debugtag 'player_uninitialize'

                            pushptr #gameplay_level~playfield
                            jsl player_entity_remove_from_playfield

                            jsl player_entity_uninitialize

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_player_turn_deactivate start seg_gameplay

                            debugtag 'player_turn_deactivate'

                            jsl player_entity_uninitialize
                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_player_turn_activate start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using gameplay_level_data

                            debugtag 'player_turn_activate'

                            setlocaldatabank

; Uninitialize any previous player
                            jsl player_entity_uninitialize

; Initialize the player
                            jsl player_entity_initialize

                            stz gameplay_player~is_dead
                            stz gameplay_player~is_dying
                            stz gameplay_player_fire~on
                            stz gameplay_player_thrust~on
                            stz gameplay_player_sinibomb~launched
                            stz gameplay_player_controls~disabled
                            stz gameplay_player~last_gamepad_state
                            stz gameplay_player~collisions_disabled
                            stz gameplay_player~death_delayed
                            stz gameplay_player~waiting_for_direction_up_key

                            lda #gameplay_player_speed~max_axis
                            sta gameplay_player_speed~limiter

                            ldx #player_entity_instance

                            lda #player_view_center_x
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda #player_view_center_y
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            putptrlow >gameplay_player_logic~last_tick
                            putptrhigh >gameplay_player_logic~last_tick

                            inline_entity_add_to_playfield {>x}

; A player type, is a 'caller' of other objects, i.e. Workers and Warriors
; Note, in the original code, if in demo mode, the called the Warrior specific caller initialization
                            jsl gameplay_caller_initialize

                            restoredatabank
                            rtl

                            end

; ----------------------------------------------------------------------------
gameplay_player_logic_tick  start seg_gameplay
                            using appdata
                            using player_entity_data
                            using shot_entity_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_sound_data
                            using applib_data
                            using grlib_update_rects_data2
                            using math_tables
                            using playfield_manager_data

                            debugtag 'player_logic_tick'

                            begin_locals
wEntityScreenX              decl word
wEntityScreenY              decl word
wEntityVectorX              decl word
wEntityVectorY              decl word
wEntitySpeedX               decl word
wEntitySpeedY               decl word
wTemp                       decl word
work_area_size              end_locals

                            sub ,work_area_size

; We can assume the databank is local
                            ldx #player_entity_instance

; Is this set to be removed?
                            getword {x},>entities_root+playfield_entity~state_flags
;                           bmi on_removal_list

; Decrement the bounce counter
                            bit #playfield_entity~state_bounce_bits
                            beq no_bounce_bits                          ; already 0?
                            dec a                                       ; we know they are the lower bits, so we can just dec
                            putword {x},>entities_root+playfield_entity~state_flags
no_bounce_bits              anop

                            lda gameplay_player~is_dead
                            jne is_dead
                            ora gameplay_player~is_dying
                            ora gameplay_player_controls~disabled
                            bne update

                            lda gameplay_player_thrust~on
                            beq thrust_off
; Thrust is on.
; Set the speed value.  Eventually, it would be good to have some acceleration.
                            pushsword #player_entity_instance
                            pushsword {x},>entities_root+playfield_entity~direction
                            pushsword #speed~0_25
                            pushsword gameplay_player_speed~limiter
                            jsl playfield_entity_add_speed
                            bra update

thrust_off                  anop
                            jsl player_entity_decelerate

update                      anop
                            ldx #player_entity_instance
                            jsl playfield_entity_update_direction

                            ldx #player_entity_instance
                            jsl playfield_entity_update_position

                            ldx #player_entity_instance
; Store the current player speed, modified by the speed_modifier.
                            lda gameplay_manager_logic~speed_modifier
                            bpl single_speed
; Doubling the speed, as we are assuming that this frame is 30fps
                            getword {x},>entities_root+playfield_entity~speed_x
                            asl a
                            sta <wEntitySpeedX
                            getword {x},>entities_root+playfield_entity~speed_y
                            asl a
                            sta <wEntitySpeedY

; Copy the unadjusted view speed, into the current view speed
                            lda >playfield_manager~unadjusted_view_speed_x
                            asl a
                            sta >playfield_manager~view_speed_x
; Patch into the update function directly, saves lots of cycles
                            sta >playfield_entity~view_speed_patch_x+1
                            sta >playfield_entity~view_speed_patch_os_x+1

                            lda >playfield_manager~unadjusted_view_speed_y
                            asl a
                            sta >playfield_manager~view_speed_y
; Patch into the update function directly, saves lots of cycles
                            sta >playfield_entity~view_speed_patch_y+1
                            sta >playfield_entity~view_speed_patch_os_y+1

                            bra double_speed
single_speed                anop
; 60fps speed, so copy the values straight in.
                            getword {x},>entities_root+playfield_entity~speed_x,<wEntitySpeedX
                            getword {x},>entities_root+playfield_entity~speed_y,<wEntitySpeedY
; Copy the unadjusted view speed, into the current view speed
                            lda >playfield_manager~unadjusted_view_speed_x
                            sta >playfield_manager~view_speed_x
; Patch into the update function directly, saves lots of cycles
                            sta >playfield_entity~view_speed_patch_x+1
                            sta >playfield_entity~view_speed_patch_os_x+1

                            lda >playfield_manager~unadjusted_view_speed_y
                            sta >playfield_manager~view_speed_y
; Patch into the update function directly, saves lots of cycles
                            sta >playfield_entity~view_speed_patch_y+1
                            sta >playfield_entity~view_speed_patch_os_y+1
double_speed                anop

; Update the screen position
;                           keyed_break 4
; Map the player position to screen space and see how close it is to the edges
; If it is over, make sure that the screen scrolling is matching the player movement.
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            clc
                            adc >update_rect_to_screen_space_offset_x
                            sta <wEntityScreenX                         ; going to need this later
                            cmp #player_screen_max_left
                            bslt off_left
                            cmp #player_screen_max_right
                            bslt test_y
off_left                    getword <wEntitySpeedX
                            beq test_y
                            negate a                                    ; scroll in the opposite direction
                            sta >playfield_manager~view_speed_x

test_y                      anop
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            clc
                            adc >update_rect_to_screen_space_offset_y   ; same as x, this is always 0
                            sta <wEntityScreenY
                            cmp #player_screen_max_top
                            bslt off_top
                            cmp #player_screen_max_bottom
                            bslt test_centering
off_top                     getword <wEntitySpeedY
                            beq test_centering
                            negate a                                    ; scroll in the opposite direction
                            sta >playfield_manager~view_speed_y
; Patch into the update function directly, saves lots of cycles
                            sta >playfield_entity~view_speed_patch_y+1
                            sta >playfield_entity~view_speed_patch_os_y+1

; Now try and move the screen.  This will bias so that the screen will slide forward of where the player is facing.
test_centering              anop
; Get the unit vector for where the player is facing.
                            getword {x},>entities_root+playfield_entity~direction
                            asl a
                            asl a
                            tax
                            lda >math~dir_32_rot_mag_8_step_4_of_32,x           ; direction to 0 - 1.0
                            asr_nt 3                                            ; scale down a bit. Should just read from a table that has the pre-calculated value
                            sta <wEntityVectorX
                            lda >math~dir_32_rot_mag_8_step_4_of_32+2,x
                            asr_nt 3
                            sta <wEntityVectorY

; Get the delta x from the center.  This will be an 'integer' value, which we are going to use
; with FP16 values, so this is just acting as a bit of extra fractional value, based on the delta from where we want to be.
; It will essentially damp the value in the facing direction, and we are somewhat assuming that the value will
; be roughly -0.5 to +0.5, in fp16, of which we will use half
                            lda #player_screen_center_x
                            sec
                            sbc <wEntityScreenX
                            asr_nt 1                                            ; only using half
; subtract the x part of the facing unit vector (this is +/- 0 to $100)
                            sec
                            sbc <wEntityVectorX
; shift the result back up.  We now have a facing unit vector, that is slightly modified by the distance from the center
                            shiftleft 3
; subtract the player's speed, to help slow us down
                            sbc <wEntitySpeedX
; Subtract our last view speed
                            sec
                            sbc >playfield_manager~view_speed_x
; Scale that down
                            asr_nt 5
; save it
                            sta <wTemp
; take half
                            asr_nt 1
; add it back
                            clc
                            adc <wTemp
; what we have now is the three vectors, the facing vector, the player speed and the view speed
; subtracted from one another. add that back to our current speed.
                            clc
                            ldx #0                                      ; clear this, before we set the N flag
                            adc >playfield_manager~view_speed_x
                            sta >playfield_manager~view_speed_x
; Patch into the update function directly, saves lots of cycles
                            sta >playfield_entity~view_speed_patch_x+1
                            sta >playfield_entity~view_speed_patch_os_x+1

; Do the same with the y component

; Get the y delta from the center, using like a fraction value, see the description for the x value above.
                            lda #player_screen_center_y
                            sec
                            sbc <wEntityScreenY
; since this axis' range is less, don't div by 2
;                           asr_nt 1
; subtract the y part of the unit vector (this is +/- 0 to $100)
                            sec
                            sbc <wEntityVectorY
                            shiftleft 3
                            sbc <wEntitySpeedY
                            sec
                            sbc >playfield_manager~view_speed_y
                            asr_nt 5
                            sta <wTemp
                            asr_nt 1
                            clc
                            adc <wTemp
                            clc
                            ldx #0                                      ; clear this, before we set the N flag
                            adc >playfield_manager~view_speed_y
                            sta >playfield_manager~view_speed_y
; Patch into the update function directly, saves lots of cycles
                            sta >playfield_entity~view_speed_patch_y+1
                            sta >playfield_entity~view_speed_patch_os_y+1

; If in static_profile mode, don't move the view
                            aif C:debug~use_profile_state=0,.skip
                            lda gameplay_manager~static_profile
                            bpl no_profile
                            lda #0
                            sta >playfield_manager~view_speed_x
                            sta >playfield_manager~view_speed_y
no_profile                  anop
.skip

; Save the view speed in an unadjusted state, for next pass.
                            lda gameplay_manager_logic~speed_modifier
                            bpl view_single_speed
                            lda >playfield_manager~view_speed_x
                            asr_nt 1
                            sta >playfield_manager~unadjusted_view_speed_x

                            lda >playfield_manager~view_speed_y
                            asr_nt 1
                            sta >playfield_manager~unadjusted_view_speed_y

                            bra view_double_speed
view_single_speed           anop
                            lda >playfield_manager~view_speed_x
                            sta >playfield_manager~unadjusted_view_speed_x

                            lda >playfield_manager~view_speed_y
                            sta >playfield_manager~unadjusted_view_speed_y
view_double_speed           anop

                            lda #$8000
                            sta >playfield_manager~view_changed

; Update the framelib values
                            ldx #player_entity_instance
                            getword {x},>entities_root+grlib_entity~changed
                            beq no_framelib_update

                            setdatabanktolabel entities_root
                            jsl grlib_entity_update_framelib
                            restoredatabank
; Invalidate
                            ldx #player_entity_instance
no_framelib_update          anop
                            jsl playfield_entity_invalidate_sprite

; Check to see if we need to shoot
                            lda gameplay_player~is_dead
                            ora gameplay_player~is_dying
                            ora gameplay_player_controls~disabled
                            bne no_fire

                            lda gameplay_player_fire~on
                            beq no_fire

                            lda >applib~current_tick
                            sec
                            sbc gameplay_player_fire~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc gameplay_player_fire~last_tick+2
                            bne do_fire
                            cpx gameplay_player_fire~rate
                            blt exit

do_fire                     lda >applib~current_tick
                            sta gameplay_player_fire~last_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_fire~last_tick+2

; Once we start firing, the rate is limited by the auto-fire rate.
                            lda #gameplay_player_logic~auto_fire_rate
                            sta gameplay_player_fire~rate

                            pushsword #shot_entity_type_id_player
                            ldx #player_entity_instance
                            pushsword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            pushsword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            pushsword {x},>entities_root+playfield_entity~direction
                            pushsword {x},>entities_root+playfield_entity~speed_x
                            pushsword {x},>entities_root+playfield_entity~speed_y
                            jsl shot_entity_manager_add_shot

                            pushsword #id_sfx~player_shot
                            jsl sndlib_play_sfx

no_fire                     anop
exit                        anop

                            ret

; The player is dead, we want to 'freeze' any view movement, because some parts
; of the player explosion draw directly to the screen
is_dead                     anop
                            ldx #player_entity_instance
                            jsl playfield_entity_update_direction

                            ldx #player_entity_instance
                            jsl playfield_entity_update_position

                            lda #0
                            sta >playfield_manager~unadjusted_view_speed_x
                            sta >playfield_manager~view_speed_x
                            sta >playfield_entity~view_speed_patch_x+1
                            sta >playfield_entity~view_speed_patch_os_x+1
                            sta >playfield_manager~unadjusted_view_speed_y
                            sta >playfield_manager~view_speed_y
                            sta >playfield_entity~view_speed_patch_y+1
                            sta >playfield_entity~view_speed_patch_os_y+1
                            sta >playfield_manager~view_changed

; Update the framelib values
                            ldx #player_entity_instance
                            setdatabanktolabel player_entity_instance
                            jsl grlib_entity_update_framelib
                            restoredatabank
; Invalidate
                            ldx #player_entity_instance
                            jsl playfield_entity_invalidate_sprite

                            bra exit

                            end

; ----------------------------------------------------------------------------
; This handles a keypress for the player.
; Note, modifer-only keys are handled separately
gameplay_player_handle_key  start seg_gameplay
                            using appdata
                            using sinistar_entity_data
                            using player_entity_data
                            using gameplay_manager_data
                            using gameplay_player_logic_data
                            using applib_data
                            using math_tables

                            begin_locals
pTargetEntity               decl ptr
wCurrentDesiredDirection    decl word
work_area_size              end_locals

                            sub (2:wKey),work_area_size

                            setlocaldatabank

                            lda gameplay_player_controls~disabled
                            ora gameplay_player~is_dead
                            beq ok
                            clc
                            bra done

ok                          anop
; Convert any lower case to upper case
                            lda <wKey
                            cmp #'a'
                            blt not_lower
                            cmp #'z'+1
                            bge not_lower
                            sec
                            sbc #'a'-'A'
                            sta <wKey
not_lower                   anop
; would be nice to convert things like control-A to A, in case the user has the control modifier mapped as a button.
; The problem is how would I differential control and the I key being press and TAB, which is control-I.
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
not_found                   sec
done                        anop
                            restoredatabank
                            retkc
found                       inx
                            inx
; Where we want the caller to come back to
                            per done-1
; Use an rts as calculated jump
                            lda key_jmp_table,x
                            dec a
                            pha
                            rts

; Internal functions
move_north                  ldx #direction~north
                            bra set_desired_direction
move_north_east             ldx #direction~north_east
                            bra set_desired_direction
move_east                   ldx #direction~east
                            bra set_desired_direction
move_south_east             ldx #direction~south_east
                            bra set_desired_direction
move_south                  ldx #direction~south
                            bra set_desired_direction
move_south_west             ldx #direction~south_west
                            bra set_desired_direction
move_west                   ldx #direction~west
                            bra set_desired_direction
move_north_west             ldx #direction~north_west

set_desired_direction       anop
                            txa                         ; direction in A
                            ldx #player_entity_instance
                            jsl playfield_entity_set_desired_direction
; Lookng for this up key, to stop turning.
                            lda <wKey
                            sta gameplay_player~waiting_for_direction_up_key
                            clc                         ; signal we handled the key
                            rts

kill_player                 anop
                            pushsword #0                                ; not killed by sinistar
                            jsl gameplay_player_die
                            clc
                            rts

player_quit                 anop
                            pushsword #0                                ; not killed by sinistar
                            jsl gameplay_player_die
; Clear all ships and zero out the score, so the player just goes back to the front-end
                            stz gameplay_manager~active_state+player_state~ship_count
                            stz gameplay_manager~active_state+player_state~score
                            stz gameplay_manager~active_state+player_state~score+2

                            aif C:debug~use_profile_state=0,.skip
; Clear the profile flag.
                            stz gameplay_manager~static_profile
.skip
                            clc
                            rts

key_jmp_table               anop
; Keypad numbers as default
                            dc c'8',i1'0'
                            dc a'move_north'
                            dc c'9',i1'0'
                            dc a'move_north_east'
                            dc c'6',i1'0'
                            dc a'move_east'
                            dc c'3',i1'0'
                            dc a'move_south_east'
                            dc c'2',i1'0'
                            dc a'move_south'
                            dc c'1',i1'0'
                            dc a'move_south_west'
                            dc c'4',i1'0'
                            dc a'move_west'
                            dc c'7',i1'0'
                            dc a'move_north_west'
; Alternate movement
                            dc c'I',i1'0'
                            dc a'move_north'
                            dc c'L',i1'0'
                            dc a'move_east'
                            dc c'K',i1'0'
                            dc a'move_south'
                            dc c'J',i1'0'
                            dc a'move_west'
;
                            dc c' ',i1'0'
                            dc a'gameplay_player_launch_bomb'
;
                            dc c'|',i1'0'
                            dc a'kill_player'
                            dc c'Q',i1'0'
                            dc a'player_quit'

                            dc i'0'                                     ; list terminator

                            end

; ----------------------------------------------------------------------------
; This handles a key up for the player
gameplay_player_handle_key_up start seg_gameplay
                            using appdata
                            using sinistar_entity_data
                            using player_entity_data
                            using gameplay_player_logic_data
                            using applib_data
                            using math_tables

                            begin_locals
work_area_size              end_locals

                            sub (2:wKey),work_area_size

                            setlocaldatabank

                            lda gameplay_player_controls~disabled
                            bne done

                            lda <wKey
                            cmp gameplay_player~waiting_for_direction_up_key
                            bne done

; Stop any rotation
                            lda >player_entity_instance+playfield_entity~direction
                            sta >player_entity_instance+playfield_entity~desired_direction
                            stz gameplay_player~waiting_for_direction_up_key

done                        anop
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Add a bomb to the player's hold.  This will not go over its capacity.
;
gameplay_player_add_bomb    start seg_gameplay
                            using player_entity_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_sound_data
                            using gameplay_ui_data

                            setlocaldatabank

                            lda gameplay_manager~active_state+player_state~bomb_count
                            cmp #gameplay_player~max_bomb_count
                            bge full

                            inc a
                            sta gameplay_manager~active_state+player_state~bomb_count
; Update UI
                            pushsword #id_sfx~player_collect_crystal
                            jsl sndlib_play_sfx

                            bra exit

full                        anop

; Post message
                            lda #gameplay_ui~message_crystal_saved
                            jsl gameplay_ui_set_active_player_message

                            pushsword #id_sfx~max_bomb_pickup
                            jsl sndlib_play_sfx

exit                        anop
                            restoredatabank
                            rtl

                            end

; ----------------------------------------------------------------------------
gameplay_player_launch_bomb private seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using gameplay_sound_data
                            using gameplay_manager_data
                            using gameplay_ui_data
                            using sinistar_entity_data
                            using math_tables
                            using applib_data

                            lda gameplay_manager~cheat~unlimited_sinibombs      ; cheating?
                            bne has_sinibomb

                            lda gameplay_manager~active_state+player_state~bomb_count
                            beq no_sinibomb
                            dec a
                            sta gameplay_manager~active_state+player_state~bomb_count

has_sinibomb                pushsword >player_entity_instance+playfield_entity~grentity+grlib_entity~x
                            pushsword >player_entity_instance+playfield_entity~grentity+grlib_entity~y

; Get the angle to Sinistar.  We should probably pick a piece to target now, no?  It will auto-target something when created.
                            getword >sinistar_entity_root_piece_ptr
                            tax
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            sec
                            sbc >player_entity_instance+playfield_entity~grentity+grlib_entity~x
                            tay
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            sec
                            sbc >player_entity_instance+playfield_entity~grentity+grlib_entity~y
                            tyx
                            jsl math~vec2_angle
                            asl a
                            tax
; Add the sin / cos value, times 4 to the player velocity, as use that as the starting speed
; These values should be capped, so we don't cross our max-velocity.
                            lda >math~sin_256,x
                            shiftleft 2                                 ; x 4
                            clc
                            adc >player_entity_instance+playfield_entity~speed_x
                            sclamp a,#math~max_fps_adjusted_neg_speed,#math~max_fps_adjusted_pos_speed
                            pha

                            lda >math~cos_256,x
                            shiftleft 2                                 ; x 4
                            clc
                            adc >player_entity_instance+playfield_entity~speed_y
                            sclamp a,#math~max_fps_adjusted_neg_speed,#math~max_fps_adjusted_pos_speed
                            pha

                            jsl bomb_entity_manager_add_bomb

; And play a sound
                            pushsword #id_sfx~sinibomb_launch
                            jsl sndlib_play_sfx

                            rts

no_sinibomb                 anop
; Show message.  Would be nice to have a 'bonk' sound of something.
                            lda #gameplay_ui~message_no_bombs
                            jsl gameplay_ui_set_active_player_message
                            rts
                            end

; ----------------------------------------------------------------------------
; This handles key-button presses for the player.
; These are a basically the keys that are treated as modifiers, as they can have
; an instant 'up / down' read state.  We may try to extend this, if reading the ADB
; directly, is feasible and can get up / down states for more keys.
gameplay_player_handle_key_buttons start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using applib_data

                            begin_locals
wCurrentDesiredDirection    decl word
work_area_size              end_locals

                            sub (2:wButtons),work_area_size

                            setlocaldatabank

                            lda gameplay_player_controls~disabled
                            bne exit

                            lda <wButtons
                            bit |gameplay_player_thrust~key_button
                            beq no_thrust
                            lda gameplay_player_thrust~on
                            bne thrust_done
; Turn it on
                            inc gameplay_player_thrust~on
; Track when it started
                            lda >applib~current_tick
                            sta gameplay_player_thrust~on_start_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_thrust~on_start_tick+2
                            bra thrust_done

no_thrust                   lda gameplay_player_thrust~on
                            beq thrust_done
                            dec gameplay_player_thrust~on
; Track when it ended
                            lda >applib~current_tick
                            sta gameplay_player_thrust~off_start_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_thrust~off_start_tick+2

thrust_done                 anop

; Fire
                            lda <wButtons
                            bit |gameplay_player_fire~key_button
                            beq no_fire
                            lda gameplay_player_fire~on
                            bne fire_done
; Turn it on
                            inc gameplay_player_fire~on
; Set the fire rate for the first shot
                            lda #gameplay_player_logic~min_fire_rate
                            sta gameplay_player_fire~rate
; Track when it started
                            lda >applib~current_tick
                            sta gameplay_player_fire~on_start_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_fire~on_start_tick+2
                            bra fire_done

no_fire                     lda gameplay_player_fire~on
                            beq fire_done
                            dec gameplay_player_fire~on
; Track when it ended
                            lda >applib~current_tick
                            sta gameplay_player_fire~off_start_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_fire~off_start_tick+2

fire_done                   anop
exit                        anop

                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; This handles gamepad-button presses for the player.
; This kinda mirrors part of the key-buttons, except this handles more, because
; there are more buttons on a gamepad.
gameplay_player_handle_gamepad start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using applib_data
                            using inputlib_data

                            begin_locals
wButtons                    decl word
wCurrentDesiredDirection    decl word
work_area_size              end_locals

                            sub (2:wControllerIndex),work_area_size

                            setlocaldatabank

                            lda gameplay_player_controls~disabled
                            ora gameplay_player~is_dead
                            jne exit

                            lda <wControllerIndex
                            dec a
                            asl a
                            tax
                            lda >input~gamepad_buttons,x
                            sta <wButtons
; Fire
                            bit gameplay_player_fire~gamepad_button
                            beq no_fire
                            lda gameplay_player_fire~on
                            bne fire_done
; Turn it on
                            inc gameplay_player_fire~on
; Set the fire rate for the first shot
                            lda #gameplay_player_logic~min_fire_rate
                            sta gameplay_player_fire~rate
; Track when it started
                            lda >applib~current_tick
                            sta gameplay_player_fire~on_start_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_fire~on_start_tick+2
                            bra fire_done

no_fire                     lda gameplay_player_fire~on
                            beq fire_done
                            dec gameplay_player_fire~on
; Track when it ended
                            lda >applib~current_tick
                            sta gameplay_player_fire~off_start_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_fire~off_start_tick+2

fire_done                   anop

; Sinibomb
                            lda <wButtons
                            bit gameplay_player_bomb~gamepad_button
                            beq no_sinibomb
; For simibombs, we require an individual press for each launch.  Might also want a time delay too?
                            lda gameplay_player~last_gamepad_state
                            bit gameplay_player_bomb~gamepad_button
                            bne no_sinibomb                                     ; was the button was down last time through?

                            jsr gameplay_player_launch_bomb

no_sinibomb                 anop

; Pause
                            lda <wButtons
                            bit gameplay_player_pause~gamepad_button
                            beq no_pause
; Want only the first press
                            lda gameplay_player~last_gamepad_state
                            bit gameplay_player_pause~gamepad_button
                            bne no_pause                                     ; was the button was down last time through?

                            jsl app_toggle_paused

no_pause                    anop

; Directions
; This uses the fact that the dpad values are all in the lower bits, and we can just use that as an index to jump somewhere
                            lda <wButtons
                            and #$000f
                            asl a
                            tax
                            jsr (direction_table,x)

exit                        anop
; Store the last state of the buttons.  Maybe just have a global for this, as I'm going to need this elsewhere, no?
                            lda <wButtons
                            sta gameplay_player~last_gamepad_state

                            restoredatabank
                            ret

direction_table             anop
                            dc a2'move_none'                ; no movement
                            dc a2'move_east'
                            dc a2'move_west'
                            dc a2'move_invalid'             ; right and left at the same time
                            dc a2'move_south'
                            dc a2'move_south_east'
                            dc a2'move_south_west'
                            dc a2'move_invalid'             ; down, left and right at the same time
                            dc a2'move_north'
                            dc a2'move_north_east'
                            dc a2'move_north_west'
                            dc a2'move_invalid'             ; up, left and right at the same time
                            dc a2'move_invalid'             ; up and down at the same time
                            dc a2'move_invalid'             ; up, down, right at the same time
                            dc a2'move_invalid'             ; up, down, left at the same time
                            dc a2'move_invalid'             ; up, down, left, right at the same time

move_north                  ldx #direction~north
                            bra set_desired_direction
move_north_east             ldx #direction~north_east
                            bra set_desired_direction
move_east                   ldx #direction~east
                            bra set_desired_direction
move_south_east             ldx #direction~south_east
                            bra set_desired_direction
move_south                  ldx #direction~south
                            bra set_desired_direction
move_south_west             ldx #direction~south_west
                            bra set_desired_direction
move_west                   ldx #direction~west
                            bra set_desired_direction
move_north_west             ldx #direction~north_west

set_desired_direction       anop
                            txa                             ; direction in A
                            ldx #player_entity_instance
                            jsl playfield_entity_set_desired_direction

; For the gamepad, we are using the fact that a direction in pressed, to adjust the thrust.
                            lda gameplay_player_thrust~on
                            bne thrust_is_on
; Turn it on
                            inc gameplay_player_thrust~on
; Track when it started
                            getdword >applib~current_tick,gameplay_player_thrust~on_start_tick
thrust_is_on                anop

move_invalid                rts

move_none                   anop
; Turn thrust off
                            lda gameplay_player_thrust~on
                            beq thrust_is_off
                            dec gameplay_player_thrust~on
; Track when it ended
                            getdword >applib~current_tick,gameplay_player_thrust~off_start_tick
; Stop any rotation
                            lda >player_entity_instance+playfield_entity~direction
                            sta >player_entity_instance+playfield_entity~desired_direction
thrust_is_off               rts

                            end

; ----------------------------------------------------------------------------
; This handles gamepad-button presses for the player, when the game is paused
gameplay_player_handle_gamepad_paused start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using applib_data
                            using inputlib_data

                            begin_locals
wButtons                    decl word
work_area_size              end_locals

                            sub (2:wControllerIndex),work_area_size

                            setlocaldatabank

                            lda <wControllerIndex
                            dec a
                            asl a
                            tax
                            lda >input~gamepad_buttons,x
                            sta <wButtons

; Pause
                            bit gameplay_player_pause~gamepad_button
                            beq no_pause
; Want only the first press
                            lda gameplay_player~last_gamepad_state
                            bit gameplay_player_pause~gamepad_button
                            bne no_pause                                     ; was the button was down last time through?

                            jsl app_toggle_paused

no_pause                    anop

exit                        anop
; Store the last state of the buttons.  Maybe just have a global for this, as I'm going to need this elsewhere, no?
                            lda <wButtons
                            sta gameplay_player~last_gamepad_state

                            restoredatabank
                            ret

                            end

; ----------------------------------------------------------------------------
; This handles the analog joystick input for a player.
; This also accepts the current key modifier state, to use to check
; the two joystick buttons (open-apple and option).
; Note, this contains some copy-pasta code from the keyboard button handler.
gameplay_player_handle_joystick start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using applib_data
                            using inputlib_data

                            begin_locals
wXThrust                    decl word
wYThrust                    decl word
wXDirection                 decl word
wYDirection                 decl word
work_area_size              end_locals

                            sub (2:wButtons),work_area_size

                            setlocaldatabank

                            lda gameplay_player_controls~disabled
                            ora gameplay_player~is_dead
                            bne disabled_exit
; Default analog stick ranges, to simulate the 7 ranges from the Sinistar stick.
; There is a 'centered' range, and three positions on either side of centered.
; This is assuming that the raw ranges from the joystick will be in the
; range of 0 - 119.
analog_joystick~range_0     equ 17
analog_joystick~range_1     equ analog_joystick~range_0+17
analog_joystick~range_2     equ analog_joystick~range_1+17
analog_joystick~range_3     equ analog_joystick~range_2+17
analog_joystick~range_4     equ analog_joystick~range_3+17
analog_joystick~range_5     equ analog_joystick~range_4+17
; Anything above range 5, is range 6

; The thrust range
analog_stick~thrust_0       equ 0
analog_stick~thrust_1       equ 1
analog_stick~thrust_2       equ 2
analog_stick~thrust_3       equ 3

; The direction
analog_stick~direction_centered equ 0
analog_stick~direction_low equ 1
analog_stick~direction_high equ 2


; Read the joystick.  This is extremely expensive!
                            jsl joy_1_read
                            cmp #$ffff
                            beq no_joystick             ; joystick is not connected, and we wasted a lot of cyclces, at 1Mhz!
                            pha
                            xba
                            jsr get_range
                            stx <wXThrust
                            sty <wXDirection
                            pla
                            jsr get_range
                            stx <wYThrust
                            sty <wYDirection
                            tya
                            asl a
                            adc <wYDirection
                            adc <wXDirection
                            beq is_centered
                            dec a
                            asl a
                            tax
                            lda analog_to_direction,x
                            ldx #player_entity_instance
                            jsl playfield_entity_set_desired_direction

; For the thrust, I'm just going to pick the largest one
                            lda <wXThrust
                            cmp <wYThrust
                            bge x_thrust_larger
                            lda <wYThrust
x_thrust_larger             cmp #0                  ; do I need to bother with this?  it should have outed early with the centered check, no?
                            beq thrust_off
                            asl a
                            tax
                            lda analog_speed_max,x
                            sta gameplay_player_speed~limiter
                            lda #1
                            sta gameplay_player_thrust~on

do_buttons                  anop
; Do the button handling
                            jsr handle_buttons

disabled_exit               clc
error_exit                  restoredatabank
                            retkc

no_joystick                 sec
                            bra error_exit

is_centered                 anop
thrust_off                  anop
; Turn thrust off
                            lda gameplay_player_thrust~on
                            beq thrust_is_off
                            dec gameplay_player_thrust~on
; Track when it ended
                            getdword >applib~current_tick,gameplay_player_thrust~off_start_tick
; Stop any rotation
                            lda >player_entity_instance+playfield_entity~direction
                            sta >player_entity_instance+playfield_entity~desired_direction
thrust_is_off               bra do_buttons


;;
; This will turn the linear axis range, into 0-2 and a 0-3 range
; The 0-2 range will be if the axis is low, centered, high. (left, center, right or up, center, down)
; and the 0-3 range will be the amount off center, representing the desired thrust level.
; The direction will be returned in Y and the thrust level will be in X
get_range                   anop
                            ldx #analog_stick~thrust_3
                            ldy #analog_stick~direction_low
                            and #$00ff
                            cmp #analog_joystick~range_0
                            blt found_range
                            dex
                            cmp #analog_joystick~range_1
                            blt found_range
                            dex
                            cmp #analog_joystick~range_2
                            blt found_range
                            dex
                            ldy #analog_stick~direction_centered
                            cmp #analog_joystick~range_3
                            blt found_range
                            inx
                            ldy #analog_stick~direction_high
                            cmp #analog_joystick~range_4
                            blt found_range
                            inx
                            cmp #analog_joystick~range_5
                            blt found_range
                            inx

found_range                 rts

;; Local function to handle the buttons
handle_buttons              anop
; Fire
                            lda <wButtons
                            bit |gameplay_player_fire~joystick_key_button
                            beq no_fire
                            lda gameplay_player_fire~on
                            bne fire_done
; Turn it on
                            inc gameplay_player_fire~on
; Set the fire rate for the first shot
                            lda #gameplay_player_logic~min_fire_rate
                            sta gameplay_player_fire~rate
; Track when it started
                            lda >applib~current_tick
                            sta gameplay_player_fire~on_start_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_fire~on_start_tick+2
                            bra fire_done

no_fire                     lda gameplay_player_fire~on
                            beq fire_done
                            dec gameplay_player_fire~on
; Track when it ended
                            lda >applib~current_tick
                            sta gameplay_player_fire~off_start_tick
                            lda >applib~current_tick+2
                            sta gameplay_player_fire~off_start_tick+2

fire_done                   anop
; Sinbombs
                            lda <wButtons
                            bit |gameplay_player_sinibomb~joystick_key_button
                            beq no_sinibomb
; Have we pressed the button already?
                            lda gameplay_player_sinibomb~launched
                            bne sinibomb_done                           ; yes, wait for a release
; Launch a bomb
                            lda #1
                            sta gameplay_player_sinibomb~launched
                            jsr gameplay_player_launch_bomb
sinibomb_done               rts

no_sinibomb                 stz gameplay_player_sinibomb~launched
                            rts

analog_to_direction         dc i'direction~west'        ; left
                            dc i'direction~east'        ; right
                            dc i'direction~north'       ; up
                            dc i'direction~north_west'  ; left + up
                            dc i'direction~north_east'  ; right + up
                            dc i'direction~south'       ; down
                            dc i'direction~south_west'  ; left + down
                            dc i'direction~south_east'  ; right + down

analog_speed_max            dc i'0'
                            dc i'1|8'
                            dc i'2|8'
                            dc i'4|8'
                            end
; ----------------------------------------------------------------------------
; A debug function to 'reset' the player.
gameplay_player_reset       start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using applib_data

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            getptr #player_entity_instance,<pEntity

                            pushsword <pEntity
                            pushsword [<pEntity],#playfield_entity~direction
                            pushsword #speed~0
                            jsl playfield_entity_set_speed

                            lda #player_view_center_x
                            putword [<pEntity],#playfield_entity~grentity+grlib_entity~x
                            lda #player_view_center_y
                            putword [<pEntity],#playfield_entity~grentity+grlib_entity~y

                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Kill the player
; Parameters:
;  wKilledBySinistar    - if true, the player was killed by sinistar
;                         this helps with adjusting the delay before the player's turn is ended.
gameplay_player_die         start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_ui_data
                            using task_manager_data
                            using applib_data

                            begin_locals
pEntity                     decl ptr
pTaskData                   decl ptr
work_area_size              end_locals

                            sub (2:wKilledBySinistar),work_area_size

                            setlocaldatabank

                            lda gameplay_player~is_dead
                            ora gameplay_player~is_dying
                            bne exit                                ; already dead or dying, skip this

; Stop the taunt task
                            jsl gameplay_sinistar_clear_taunt_task

                            getptr #player_entity_instance,<pEntity

                            pushsword <pEntity
                            pushsword [<pEntity],#playfield_entity~direction
                            pushsword #speed~0
                            jsl playfield_entity_set_speed

                            dec gameplay_player~is_dead             ; mark the player is dead

                            pushptr <pEntity
                            jsl explosion_entity_manager_add_explosion

                            ldx <pEntity
                            jsl playfield_entity_mark_for_removal

                            pushsword #task_list_1_offset
                            pushptr #gameplay_player_death_task
                            pushsword #sizeof~gameplay_player_death_task_data
                            jsl task_manager_create_task
                            putretptr <pTaskData
                            lda wKilledBySinistar
                            bne skip
; If not killed by Sinistar, give an extra second up front, so the player explosion plays out a bit more before moving on.
                            lda #60
                            putword [<pTaskData],#countdown_task~counter
skip                        anop
; Decrement the player ship count
                            lda gameplay_manager~cheat~unlimited_ships          ; cheating?
                            bne exit

                            inc gameplay_ui~ships_remaining_needs_update        ; flag that we need an update

                            lda gameplay_manager~active_state+player_state~ship_count
                            dec a
                            bmi exit                ; make sure we don't go negative!  Classic mistake!
                            sta gameplay_manager~active_state+player_state~ship_count

exit                        restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Handles waiting for some things to finish, after the player has been killed
gameplay_player_death_task  start seg_gameplay
                            using gameplay_player_logic_data
                            using gameplay_sinistar_logic_data
                            using gameplay_sound_data
                            using sinistar_entity_data
                            using task_manager_data
                            using appdata

                            debugtag 'death_task'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            getword [<pTaskData],#countdown_task~counter
                            beq no_timer
                            dec a
                            putword [<pTaskData],#same
                            bne exit

no_timer                    task_resume                                     ; this will jump to the wake vector, if set

; First time through, we are waiting for these to clear
                            lda >gameplay_player~death_delayed
                            ora >gameplay_sinistar~speaking
                            bne exit

; Wait 1 second
                            lda #60
                            putword [<pTaskData],#countdown_task~counter
                            task_sleep here,exit

; Sinistar is on screen?
                            lda >sinistar_entity~on_screen
                            beq not_on_screen

                            jsl gameplay_sinistar_stop_speech
; if so, say "I am Sinistar" and then wait one more second.
                            pushsword #id_sfx~i_am_sinistar
                            jsl gameplay_sinistar_play_speech
; Wait 1 second
wait_speech                 lda #60
                            putword [<pTaskData],#countdown_task~counter
                            task_sleep here,exit

                            lda >gameplay_sinistar~speaking
                            bne wait_speech                                        ; still jabbering away?  Wait some more.

; clear the task and exit
not_on_screen               pushptr <pTaskData
                            jsl task_manager_free_task

; Handle this player's turn ending
                            jsl gameplay_turn_end

exit                        ret
                            end

; ----------------------------------------------------------------------------
; A debug function to print some info about the player to the text screen
; Uses the current textbox location.
player_debug_handler_show_info start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using appdebug_data
                            using textlib_global_data
                            using applib_data
                            using grlib_global_data
                            using playfield_manager_data

                            begin_locals
pEntity                     decl ptr
pSprite                     decl ptr
pResponder                  decl ptr
wDrawLines                  decl word
pShape                      decl ptr
work_area_size              end_locals

type_column_width           equ 22
ID_column_width             equ 12
X_column_width              equ 6
Y_column_width              equ 6
Mission_column_width        equ 16

                            sub (2:wStatus),work_area_size
                            setlocaldatabank

                            lda <wStatus
                            bit #debug_handler~status~displayed
                            bne not_first
; First time here
                            stz prev_draw_lines

not_first                   anop

                            lda #textbox_option~inverse+textbox_option~line_fill
                            jsl textbox_set_options
                            pushptr #title_string
                            jsl textbox_print_string
                            jsl textbox_newline
                            jsl textbox_set_option_normal

                            pushptr #ship_string
                            jsl textbox_print_string

                            getptr #player_entity_instance,<pEntity
                            getptr <pEntity,#grlib_entity~sprite,<pSprite

                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~x
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~y
                            jsl textbox_print_hex_word

                            pushsword #$20
                            jsl textbox_print_char
; Bounds
                            pushptr #bounds_string
                            jsl textbox_print_string

                            pushsword [<pSprite],#sprite~bounds~left
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char
                            pushsword [<pSprite],#sprite~bounds~top
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char
                            pushsword [<pSprite],#sprite~bounds~right
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char
                            pushsword [<pSprite],#sprite~bounds~bottom
                            jsl textbox_print_hex_word


                            pushsword #$20
                            jsl textbox_print_char
; Sprite Shape
                            pushptr #sprite_string
                            jsl textbox_print_string

                            getptr [<pSprite],#sprite~primary_shape_ptr,<pShape
                            ora <pShape
                            beq no_shape

                            pushsword [<pShape],#shapedef~width
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char

                            pushsword [<pShape],#shapedef~height
                            jsl textbox_print_hex_word

no_shape                    anop
                            jsl textbox_newline

; Speed
                            pushptr #speed_string
                            jsl textbox_print_string

                            pushsword [<pEntity],#playfield_entity~speed_x
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char

                            pushsword [<pEntity],#playfield_entity~speed_y
                            jsl textbox_print_hex_word

                            pushsword #$20
                            jsl textbox_print_char

; Screen Speed
                            pushptr #screen_speed_string
                            jsl textbox_print_string

                            pushsword >playfield_manager~view_speed_x
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char

                            pushsword >playfield_manager~view_speed_y
                            jsl textbox_print_hex_word

                            jsl textbox_newline

                            pushptr #str_responder_quota
                            jsl textbox_print_string
                            pushsword [pEntity],#playfield_entity~responder_quota+responder_type~worker
                            jsl textbox_print_hex_word
                            pushsword #ascii~comma
                            jsl textbox_print_char
                            pushsword [pEntity],#playfield_entity~responder_quota+responder_type~warrior
                            jsl textbox_print_hex_word

                            jsl textbox_newline

; Responders
                            getword [pEntity],#playfield_entity~responder_root_sptr
                            jeq no_responders
                            sta <pResponder
                            ldy #^entities_root                 ; fix the need for this
                            sty <pResponder+2

                            jsl textbox_set_option_inverse
                            pushptr #responder_list_string
                            jsl textbox_print_string
                            jsl textbox_newline
                            jsl textbox_set_option_normal

                            pushptr #column_header
                            jsl textbox_print_columns

                            pushsword #ascii~mousetext~horizontal_bar
                            jsl textbox_fill_line
                            jsl textbox_newline

                            stz <wDrawLines
; Get the responder (ID is already on the stack)
responder_loop              anop

                            inc <wDrawLines
; Type
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushsword [<pResponder],#playfield_entity~type
                            jsl playfield_entity_get_type_name
                            pushretptr
                            jsl textbox_print_string
; ID
                            pushsword #ID_column_width
                            jsl textbox_next_column
                            pushsword <pResponder
                            jsl textbox_print_hex_word
; X
                            pushsword #X_column_width
                            jsl textbox_next_column
                            pushsword [<pResponder],#playfield_entity~grentity+grlib_entity~x
                            jsl textbox_print_hex_word
; Y
                            pushsword #Y_column_width
                            jsl textbox_next_column
                            pushsword [<pResponder],#playfield_entity~grentity+grlib_entity~y
                            jsl textbox_print_hex_word

; Mission
                            pushsword #Mission_column_width
                            jsl textbox_next_column
                            pushsword [<pResponder],#playfield_entity~mission_id
                            pushsword [<pResponder],#playfield_entity~type
                            jsl gameplay_get_mission_type_name
                            pushretptr
                            jsl textbox_print_string

                            jsl textbox_next_row_end_columns
                            bcs off_end

                            getword [<pResponder],#playfield_entity~next_sibling_sptr
                            beq done_responders
                            sta <pResponder
                            brl responder_loop

off_end                     anop
done_responders             anop
missing                     anop

no_responders               anop
                            jsl textbox_clear_options

                            lda prev_draw_lines
                            sec
                            sbc <wDrawLines
                            bcc no_erase
                            beq no_erase
; We have to erase some previous lines
                            pha
                            pushsword #$20
                            jsl textbox_fill_lines

no_erase                    lda <wDrawLines
                            sta prev_draw_lines

                            restoredatabank
                            ret

column_header               anop
                            dc i'type_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~Type'
                            dc i'ID_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~ID'
                            dc i'X_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~X'
                            dc i'Y_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~Y'
                            dc i'Mission_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~Mission'
                            dc i'0'                             ; terminator

title_string                cstring 'Player'
ship_string                 cstring 'Ship: '
bounds_string               cstring 'Rect: '
sprite_string               cstring 'Sprite: '
speed_string                cstring 'Speed: '
screen_speed_string         cstring 'Screen Speed: '
screen_origin_string        cstring 'Origin: '
str_responder_quota         cstring 'Responder quota: '
responder_list_string       cstring 'Responder List'
prev_draw_lines             dc i'0'
                            end

; ----------------------------------------------------------------------------
; Draw the help for this handler
player_debug_handler_show_help start seg_gameplay

                            pushptr #basic_help1
                            jsl textbox_print_string
                            jsl textbox_newline

                            rtl

basic_help1                 cstring '[P] - Player Ship Info'

                            end

; -----------------------------------------------------------------------------
player_debug_handler_keypress start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using appdebug_data
                            using textlib_global_data
                            using applib_data
                            using grlib_global_data

                            begin_locals
work_area_size              end_locals

                            sub (4:pHandler,2:wKey),work_area_size
                            getword [<pHandler],#debug_handler~enabled
                            beq not_enabled

                            lda <wKey
                            cmp #19                                     ; ctrl-s
                            bne not_add_bomb

                            jsl gameplay_player_add_bomb                ; try to add a bomb
                            bra handled

not_add_bomb                anop
; We are enabled
                            lda >grlib~in_text_mode
                            beq not_handled                                 ; Don't handle any keys if not in text mode

                            lda <wKey
                            cmp #'P'
                            bne not_handled

; Disable
                            lda #0
                            putword [<pHandler],#debug_handler~enabled
                            lda #$ffff
                            sta >appdebug~clear_text_screen
                            bra handled

; We are not enabled, the only key we listen for, is the one to enable us
not_enabled                 lda <wKey
                            cmp #'P'
                            bne not_handled

enable                      lda #$ffff
                            putword [<pHandler],#debug_handler~enabled
                            sta >appdebug~clear_text_screen

handled                     clc
exit                        retkc
not_handled                 sec
                            bra exit

                            end
