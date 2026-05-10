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
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm
                            copy lib/source/sndlib.definitions.asm

                            copy source/task.definitions.asm
                            copy source/gameplay.constants.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/collision.definitions.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/sinistar.entity.definitions.asm
                            copy source/explosion.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm

                            mcopy generated/gameplay.sinistar.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the Sinistar.

; ----------------------------------------------------------------------------

gameplay_sinistar_logic_data    data seg_gameplay
                                using sinistar_entity_data

; Note some of these equates are global, so that they resolve at compile time, rather than link time. This helps with some macro expansion, like getword

; Main logic tick task data
gameplay_sinistar_task            gequ 0
gameplay_sinistar_task~entity_ptr gequ gameplay_sinistar_task
sizeof~gameplay_sinistar_task     gequ gameplay_sinistar_task~entity_ptr+4

; task data that is shared amongst several sinistar tasks.  They just have one extra word of storage
gameplay_sinistar_shared_task_data gequ sizeof~task_timer_header
; union {
gameplay_sinistar_shared_task_data~increment gequ gameplay_sinistar_shared_task_data
gameplay_sinistar_shared_task_data~count gequ gameplay_sinistar_shared_task_data
; };
sizeof~gameplay_sinistar_shared_task_data gequ gameplay_sinistar_shared_task_data+2

; The range that Sinistar is allow to be in, when outside the main sector (which is +/- 512 from the center of the screen)
gameplay_sinistar_super_sector_max_x equ 1024
gameplay_sinistar_super_sector_min_x equ -1024
gameplay_sinistar_super_sector_max_y equ 1024
gameplay_sinistar_super_sector_min_y equ -1024

; non-zero, if Sinistar is 'in-sector', else he is out of the main sector.
gameplay_sinistar_logic~in_sector   ds 2

; non-zero, if Sinistar is 'stunned'
gameplay_sinistar_logic~in_stun     ds 2

; 1 or -1 for the orbit direction
gameplay_sinistar_logic~orbit_multiplier ds 2

; The task pointer for handling Sinistar's random taunts
gameplay_sinistar~taunt_task_ptr        dc a4'0'
; If non-zero, sinistar is speaking
gameplay_sinistar~speaking              dc i'0'
; If speaking, this is the oscillator instance
gameplay_sinistar~speaking_on_oscillator dc i'0'

gameplay_sinistar~last_taunt_seed       dc i'0'

; The tick timer for the current speech animation segment
gameplay_sinistar~speech_timer          dc i'0'
; The current speech animation segment short pointer
gameplay_sinistar~speech_segment_sptr   dc i'0'

; The jump table to the sinistar's missions.
gameplay_sinistar_logic~mission_table   dc a'0'

; Bits in the personality member, to use for the orbit countdown.
; Might want to just put in a separate member, since we are not as memory constrained as the original
gameplay_sinistar_logic~orbit_countdown equ %00001111

; Note, this uses a number similar to the original, since it needs to fit in 4 bits.  The real value is scaled before use.
gameplay_sinistar_logic~max_orbit_factor equ 12
gameplay_sinistar_logic~on_screen_orbit_factor equ 1+((gameplay_sinistar_logic~max_orbit_factor*3)/4)       ; The point at which Sinistar must be on screen, before it moves closer in orbit

gameplay_sinistar~death_sequence_state dc i'0'      ; INIMPULSE from the original
gameplay_sinistar~blown_up             dc i'0'      ; an extra flag for the sequence, to signal that Sinistar is blown up, though the entity will still be on screen.

; Explosion screen flash time, in ticks
gameplay_sinistar_explosion_flash_time  equ 60*3
; Number of 'booms' during a Sinistar death sequence
gameplay_sinistar_explosion_booms_count equ 6                       ; Original had this at 14
; The is the timer for the explosion sounds as Sinistar is doing his breakup death sequence
gameplay_sinistar_death_task_time   equ 60*1

; The orbit factor when the player is orbiting Sinistar while he explodes.  XORBIT in the original, which was 1
gameplay_sinistar~player_orbit_factor equ 1

; Values are from the original (STBLSinistar)
gameplay_sinistar_logic~intercept_speed_table anop
                            dc i'$7fff,($07ff),acceleration_function~5'
                            dc i'4000,($2000|-1),acceleration_function~4'
                            dc i'1024,($0100|-1),acceleration_function~1'
                            dc i'0600,($0280|-1),acceleration_function~5'
                            dc i'0080,($0200|-1),acceleration_function~3'
                            dc i'0064,($0180|-1),acceleration_function~4'
                            dc i'0032,($0100|-1),acceleration_function~4'
                            dc i'0016,($00c0|-1),acceleration_function~3'
                            dc i'0000,($0080|-1),acceleration_function~2'

; Values are from the original (STblOSini)
; Note that this oddly does not take into account that the orbital distance
; calculations are always x 16 the real distance.
; It seems like the '100' distance line is the only one that will ever be used.
gameplay_sinistar_logic~orbit_speed_table anop
                            dc i'$7fff,($1fff),acceleration_function~3'
                            dc i'0100,($0200),acceleration_function~4'
                            dc i'0048,($01c0),acceleration_function~3'
                            dc i'0040,($0170),acceleration_function~3'
                            dc i'0032,($0148),acceleration_function~3'
                            dc i'0024,($00f8),acceleration_function~2'
                            dc i'0016,($0080),acceleration_function~2'
                            dc i'0008,($0030),acceleration_function~1'
                            dc i'0004,($0000),acceleration_function~1'
                            dc i'0000,($0000),acceleration_function~0'

; An extra 'kill' table, so Sinistar lines up his mouth on the player quicker
gameplay_sinistar_logic~kill_speed_table anop
                            dc i'$7fff,($07ff),acceleration_function~5'
                            dc i'0600,($0280|-1),acceleration_function~5'
                            dc i'0064,($0180|-1),acceleration_function~1'
                            dc i'0032,($0100|-1),acceleration_function~1'
                            dc i'0016,($00c0|-1),acceleration_function~1'
                            dc i'0004,($0080|-1),acceleration_function~0'
                            dc i'0000,($0000),acceleration_function~0'

gameplay_sinistar~stun_flash_color dc i'$0E00,$0C00,$0A00,$0800,$0600,$0500,$0400,$0300'
gameplay_sinistar~death_flash_color dc i'$0E00,$03F0'

; The effect3 color that is cycled.  This makes his eyes and mouth glow.
gameplay_sinistar~effect_cycle_color    dc i'$0000,$0800,$0F00,$0000'

; This was used as part of the 'mutating' of the Sinistar image, as it is exploding.
; gameplay_sinistar_explosion_increments	dc i'$0000,$FFFF,$DEDE,$EFEF,$2222,$1111,$CECD,$BCBC'

; The sequence to which the Sinistar center pieces breakup
; Overall, I'm not quite using this as the original did.  I do need to keep the center piece as the first one
; in the list.
gameplay_sinistar~center_breakup_sequence dc i'19,13,14,15,16,17,18,12'

; The struct definition for the entries in the speech tables
                            begin_struct
speech_segment~position     decl word
speech_segment~timer        decl word
sizeof~speech_segment       end_struct

speech_segment~end_of_animation equ $8000

; The mouth postion / timing tables for each speech.
; These are from the original in the ANISINI.ASM file.  Times are in frames at 60 fps.
; Each line is the position for a word in the speech.
; I am Sinistar.
speech_anim~i_am_sinistar   anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_wide_open,14,sinistar_mouth_open,8'
        dc i'sinistar_mouth_wide_open,6,sinistar_mouth_closed,20'
        dc i'sinistar_mouth_open,12,sinistar_mouth_closed,1,sinistar_mouth_open,10,sinistar_mouth_closed,3,sinistar_mouth_wide_open,25,sinistar_mouth_open,3,sinistar_mouth_closed,1'
        dc i'speech_segment~end_of_animation,0'

; Beware!  I Live!
speech_anim~beware_i_live   anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_wide_open,2,sinistar_mouth_open,16,sinistar_mouth_closed,5,sinistar_mouth_open,3,sinistar_mouth_wide_open,7,sinistar_mouth_open,14,sinistar_mouth_closed,13'
        dc i'sinistar_mouth_wide_open,12,sinistar_mouth_open,8'
        dc i'sinistar_mouth_wide_open,7,sinistar_mouth_closed,3,sinistar_mouth_open,15,sinistar_mouth_closed,1'
        dc i'speech_segment~end_of_animation,0'

; I hunger!
speech_anim~i_hunger        anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_wide_open,5,sinistar_mouth_open,11'
        dc i'sinistar_mouth_wide_open,12,sinistar_mouth_open,24,sinistar_mouth_closed,1'
        dc i'speech_segment~end_of_animation,0'

; Beware, Coward!
speech_anim~beware_coward   anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_wide_open,2,sinistar_mouth_open,16,sinistar_mouth_closed,7,sinistar_mouth_open,3,sinistar_mouth_wide_open,5,sinistar_mouth_open,14,sinistar_mouth_closed,13'
        dc i'sinistar_mouth_open,8,sinistar_mouth_closed,6,sinistar_mouth_open,3,sinistar_mouth_wide_open,5,sinistar_mouth_open,13,sinistar_mouth_closed,13'
        dc i'speech_segment~end_of_animation,0'

; Run, Coward!
speech_anim~run_coward      anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_open,4,sinistar_mouth_wide_open,14,sinistar_mouth_open,6,sinistar_mouth_closed,13'
        dc i'sinistar_mouth_open,8,sinistar_mouth_closed,6,sinistar_mouth_open,3,sinistar_mouth_wide_open,5,sinistar_mouth_open,13,sinistar_mouth_closed,13'
        dc i'speech_segment~end_of_animation,0'

; Run!  Run!  Run!
speech_anim~run_run_run     anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_open,4,sinistar_mouth_wide_open,14,sinistar_mouth_open,6,sinistar_mouth_closed,13'
        dc i'sinistar_mouth_open,4,sinistar_mouth_wide_open,14,sinistar_mouth_open,6,sinistar_mouth_closed,13'
        dc i'sinistar_mouth_open,4,sinistar_mouth_wide_open,14,sinistar_mouth_open,6,sinistar_mouth_closed,13'
        dc i'speech_segment~end_of_animation,0'

; I Hunger, Coward!
speech_anim~i_hunger_coward  anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_wide_open,5,sinistar_mouth_open,11'
        dc i'sinistar_mouth_wide_open,12,sinistar_mouth_open,24,sinistar_mouth_closed,13'
        dc i'sinistar_mouth_open,8,sinistar_mouth_closed,6,sinistar_mouth_open,3,sinistar_mouth_wide_open,5,sinistar_mouth_open,13,sinistar_mouth_closed,13'
        dc i'speech_segment~end_of_animation,0'

; EEERRAAURGH!
speech_anim~EEERRAAURGH     anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_open,20,sinistar_mouth_wide_open,126,sinistar_mouth_open,2,sinistar_mouth_closed,1'
        dc i'speech_segment~end_of_animation,0'

; EEERRAAURGH, but end with the mouth open
speech_anim~EEERRAAURGH_death anop
        dc i'sinistar_mouth_closed,1'
        dc i'sinistar_mouth_open,20,sinistar_mouth_wide_open,126,sinistar_mouth_open,2'
        dc i'speech_segment~end_of_animation,0'

; Close Mouth
speech_anim~close_mouth     anop
        dc i'sinistar_mouth_closed,1'
        dc i'speech_segment~end_of_animation,0'


; A lookup table for the speech animations.
; This must be in the id_sfx order.  See gameplay.sound.asm
gameplay_sinistar~speech_table anop
        dc a'speech_anim~i_hunger'
        dc a'speech_anim~beware_i_live'
        dc a'speech_anim~beware_coward'
        dc a'speech_anim~EEERRAAURGH'
        dc a'speech_anim~i_am_sinistar'
        dc a'speech_anim~i_hunger_coward'
        dc a'speech_anim~run_coward'
        dc a'speech_anim~run_run_run'
        dc a'speech_anim~EEERRAAURGH_death'
                            end

; ----------------------------------------------------------------------------
; Gameplay logic initialization for Sinistar
gameplay_sinistar_initialize_logic start seg_gameplay
                            using appdata
                            using sinistar_entity_data
                            using gameplay_sinistar_logic_data
                            using applib_data
                            using task_manager_data

                            debugtag 'sinistar_initialize'

                            begin_locals
pTaskData                   decl ptr
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            setlocaldatabank

                            lda #1
                            sta gameplay_sinistar_logic~in_sector
                            sta gameplay_sinistar_logic~orbit_multiplier
                            stz gameplay_sinistar_logic~in_stun
                            stz gameplay_sinistar~last_taunt_seed
                            stz gameplay_sinistar~speech_segment_sptr
                            stz gameplay_sinistar~speech_timer
; May want to do these earlier, since we have him speak on the turn start screen.
                            stz gameplay_sinistar~speaking
                            stz gameplay_sinistar~speaking_on_oscillator

; Sinistar is a caller type
                            ldx <pThis
                            jsl gameplay_caller_initialize

                            pushsword #task_list_8_offset
                            pushptr #_task_sinistar_logic_tick
                            pushsword #sizeof~gameplay_sinistar_task
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

; Add the entity to the task data
                            lda <pThis
                            putptrlow [<pTaskData],#gameplay_sinistar_task~entity_ptr
                            lda <pThis+2
                            putptrhigh [<pTaskData],#gameplay_sinistar_task~entity_ptr

; Add the task, to the entity, in the task2 slot
                            lda <pTaskData
                            putptrlow [<pThis],#playfield_entity~task2_ptr
                            lda <pTaskData+2
                            putptrhigh [<pThis],#playfield_entity~task2_ptr

                            getword [<pThis],#playfield_entity~personality
                            ora #gameplay_sinistar_logic~max_orbit_factor
                            putword [<pThis],#same

error                       anop
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Task callback for sinistar logic
_task_sinistar_logic_tick   private seg_gameplay
                            using appdata
                            using grlib_global_data
                            using sinistar_entity_data
                            using gameplay_sinistar_logic_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using playfield_manager_data
                            using player_entity_data
                            using applib_data

                            debugtag 'task_sinistar_logic_tick'

                            begin_locals
pEntity                     decl ptr
wDistanceX                  decl word
wDistanceY                  decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

                            getptr [<pTaskData],#gameplay_sinistar_task~entity_ptr,<pEntity

                            ldx <pEntity
                            jsl gameplay_entity_test_should_think       ; like the original, we will see if we should 'think' or not
                            bcs exit

; Is Sinistar alive?
                            lda gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_alive
                            bne not_alive

                            jsr _rotate_anim                            ; update eyebrows and effect colors
;                           bra not_alive                               ; uncomment to make Sinistar stay put

                            getword [<pEntity],#playfield_entity~personality
                            tax                                                 ; save for later
                            and #gameplay_sinistar_logic~orbit_countdown
                            beq is_zero

                            cmp #gameplay_sinistar_logic~on_screen_orbit_factor
                            bge large_orbit
; Getting closer, must be on screen, to reduce orbit
                            lda >sinistar_entity~on_screen                      ; use global, that will be true if any part is on screen
                            beq off_screen
large_orbit                 anop
                            dex                                                 ; one less.  We know that this was at least 1, so this will not affect the upper bits
                            txa
                            putword [<pEntity],#playfield_entity~personality

is_zero                     anop
off_screen                  anop

                            lda gameplay_sinistar_logic~in_stun
                            beq stunned_is_zero
                            dec a
                            sta gameplay_sinistar_logic~in_stun

stunned_is_zero             anop
                            jsr stop_check
                            bcs exit
                            jsr orbit_or_chase_player

exit                        anop
                            restoredatabank
                            ret

not_alive                   anop
; Update the velocity to 0
                            ldx <pEntity
                            jsl playfield_entity_decelerate
                            bra exit

;;; Local function
_rotate_anim                anop
; Rotate all the animated bits so I can position them

                            lda >sinistar_eyebrow_position
                            cmp #sinistar_eyebrow_up
                            bne next_eyebrow
                            lda #0
                            bra set_eyebrow
next_eyebrow                clc
                            adc #4
set_eyebrow                 sta >sinistar_eyebrow_position

; Use the eyebrow index to also control what the effect3 color is set to
                            lsr a
                            tay
                            lda >playfield_view~palette_shr_slot_offset
                            clc
                            adc #appdata~gameplay_color~effect3~index*2
                            tax
                            lda >grlib~shr_palettes,x
                            and #grlb~shr_palette_reserved_mask             ; Apple says the upper bits are reserved and they shouldn't be modified.  Is this really needed?
                            ora gameplay_sinistar~effect_cycle_color,y
                            sta >grlib~shr_palettes,x
                            rts

;;; Local function

; See if Sinistar should stop.
; Note, this follows the 'patched' code from the original.  See FIXSINI.SRC
stop_check                  anop

                            lda gameplay_sinistar_logic~in_stun
                            bne clear_velocity

                            lda gameplay_manager~demo_active
                            beq not_demo

; In demo mode, is it on screen?
                            lda >sinistar_entity~on_screen
                            bne clear_velocity

not_demo                    clc
                            rts

clear_velocity              anop
                            lda #0
                            putword [<pEntity],#playfield_entity~speed_x
                            putword [<pEntity],#playfield_entity~speed_y
                            sec
                            rts

;;; Local function

orbit_or_chase_player       anop

; Get the orbit factor from the personality member
                            getword [<pEntity],#playfield_entity~personality
                            and #gameplay_sinistar_logic~orbit_countdown
                            beq do_intercept
; Clamp the factor
                            cmp #gameplay_sinistar_logic~max_orbit_factor
                            blt ok_factor
                            lda #gameplay_sinistar_logic~max_orbit_factor

ok_factor                   anop
                            tax

; Sinistar is orbiting the player
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~x
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~y
                            pushsword >player_entity_instance+playfield_entity~grentity+grlib_entity~x
                            pushsword >player_entity_instance+playfield_entity~grentity+grlib_entity~y
                            pushsword >player_entity_instance+playfield_entity~speed_x
                            pushsword >player_entity_instance+playfield_entity~speed_y
                            phx
                            pushsword gameplay_sinistar_logic~orbit_multiplier
                            jsl playfield_get_orbital_distance_speculative
                            sta <wDistanceX
                            stx <wDistanceY

                            pushptr #gameplay_sinistar_logic~orbit_speed_table
                            pushsword <wDistanceX
                            pushsword <wDistanceY
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <pEntity
                            pushsword >player_entity_instance+playfield_entity~speed_x
                            pushsword >player_entity_instance+playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda gameplay_sinistar_logic~orbit_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity
                            rts

do_intercept                anop
                            pushptr <pEntity
                            pushptr #player_entity_instance
                            jsl playfield_entity_get_target_distance
                            sta <wDistanceX
                            stx <wDistanceY

                            lda gameplay_player~is_dying
                            beq player_not_dying

; Player dying, use a different speed table to help get sinistar lined up for the chomp
                            pushptr #gameplay_sinistar_logic~kill_speed_table
                            pushsword <wDistanceX
                            pushsword <wDistanceY
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity
                            bra apply

; Player Alive
player_not_dying            pushptr #gameplay_sinistar_logic~intercept_speed_table
                            pushsword <wDistanceX
                            pushsword <wDistanceY
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

apply                       pushsword <pEntity
                            pushsword >player_entity_instance+playfield_entity~speed_x
                            pushsword >player_entity_instance+playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda gameplay_sinistar_logic~intercept_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

                            rts

                            end

; ----------------------------------------------------------------------------
; Task callback for sinistar killing the player.  Note the regular sinistar
; logic tick is still running.
gameplay_task_sinistar_player_kill start seg_gameplay
                            using appdata
                            using task_manager_data
                            using sinistar_entity_data
                            using gameplay_sinistar_logic_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using player_entity_data
                            using applib_data

                            debugtag 'task_sinistar_player_kill'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

; It is possible that sinistar can die before it kills the player
                            lda >gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_alive
                            bne is_dead

                            getptr >sinistar_entity_root_piece_ptr,<pEntity

; Make the player spin (original scrambled the direction)
                            lda >player_entity_instance+playfield_entity~direction
                            inc a
                            cmp #playfield_entity~direction_range
                            blt ok_direction
                            lda #0
ok_direction                anop
; Make the desire direction match, so direction adjustment code doesn't try to change the value.
                            sta >player_entity_instance+playfield_entity~desired_direction
                            ldx #player_entity_instance
                            jsl playfield_entity_set_direction

; Make sure a few things are clear for the logic tick
                            stz gameplay_sinistar_logic~in_stun

                            getword [<pEntity],#playfield_entity~personality
                            and #(gameplay_sinistar_logic~orbit_countdown*-1)-1
                            putword [<pEntity],#same

                            getword [<pTaskData],#task_timer_header~timer
                            dec a
                            putword [<pTaskData],#same
                            bne exit
; Crunch the player
                            stz gameplay_sinistar~speech_segment_sptr           ; make sure this is cleared
                            lda #sinistar_mouth_closed
                            sta >sinistar_mouth_position

; Set the player collision type back to normal
                            stz gameplay_player~collisions_disabled

; Clear that the player is dying
                            stz gameplay_player~is_dying
; Then kill them
                            pushsword #1                                ; killed by sinistar
                            jsl gameplay_player_die

                            pushptr <pTaskData
                            jsl task_manager_free_task

exit                        restoredatabank
                            ret

is_dead                     anop
; Player got lucky and sinistar died before he crunched!
; Re-enable player controls
                            stz gameplay_player_controls~disabled
; Set the player collision type back to normal
                            stz gameplay_player~collisions_disabled
; Clear that the player is dying
                            stz gameplay_player~is_dying
stop_task                   anop
                            pushptr <pTaskData
                            jsl task_manager_free_task
                            bra exit

                            end
; ----------------------------------------------------------------------------
; Initialize sinistar.
gameplay_sinistar_initialize start seg_gameplay
                            using sinistar_entity_manager_data

                            debugtag 'sinistar_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_sinistar_uninitialize start seg_gameplay
                            using gameplay_sinistar_logic_data

                            debugtag 'sinistar_uninitialize'

; We can just call the turn_deactivate, to make sure everything is cleaned up
                            jsl gameplay_sinistar_turn_deactivate

                            rtl
                            end

; ----------------------------------------------------------------------------
; Deactivate the turn
gameplay_sinistar_turn_deactivate start seg_gameplay
                            using gameplay_sinistar_logic_data

                            debugtag 'sinistar_turn_deactivate'

                            jsl sinistar_entity_manager_remove_all
                            jsl gameplay_sinistar_clear_taunt_task

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_sinistar_clear_taunt_task start seg_gameplay
                            using gameplay_sinistar_logic_data

                            lda >gameplay_sinistar~taunt_task_ptr+2
                            beq skip
                            pha
                            lda >gameplay_sinistar~taunt_task_ptr
                            pha
                            jsl task_manager_free_task
                            lda #0
                            sta >gameplay_sinistar~taunt_task_ptr
                            sta >gameplay_sinistar~taunt_task_ptr+2

skip                        rtl
                            end


; ----------------------------------------------------------------------------
; Setup sinistar for the gameplay turn activation
gameplay_sinistar_turn_activate start seg_gameplay
                            using sinistar_entity_manager_data
                            using gameplay_sinistar_logic_data
                            using gameplay_level_data
                            using playfield_manager_data
                            using task_manager_data

                            debugtag 'sinistar_turn_activate'

                            setlocaldatabank

; Remove any existing, and remove any tasks
                            jsl gameplay_sinistar_turn_deactivate

; An extra task to handle auto-building and 'taunting'.  In the original, this was initialized
; what I call gameplay_level_turn_activate.  Feels more appropriate to do it here.

                            pushsword #task_list_64_offset
                            pushptr #_task_sinistar_taunt
                            pushsword #0
                            jsl task_manager_create_task
                            putretptr >gameplay_sinistar~taunt_task_ptr

; Add Sinistar
                            lda #1                      ; he is going to be in-sector
                            sta gameplay_sinistar_logic~in_sector

; Put him at an edge.
                            jsl gameplay_generate_random_edge_location
                            pha         ; x coordinate
                            phx         ; y coordinate
                            jsl sinistar_entity_manager_add_sinistar

; Note, this needs to read the current build progress of sinistar from the current player's state

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
; Handle Sinistar leaving the main sector
; This can end up just forcing him to stay in the main sector
; Unlike the original, we're using 16-bit coords all the time, so
; when leaving the sector, not much is being done, other than setting a flag.
; Parameters:
; y-reg     - short pointer to the entity
gameplay_sinistar_leave_sector start seg_gameplay
                            using sinistar_entity_manager_data
                            using sinistar_entity_data
                            using gameplay_manager_data
                            using gameplay_sinistar_logic_data
                            using gameplay_level_data
                            using playfield_manager_data

                            debugtag 'sinistar_leave_sector'

                            tyx                                             ; short pointer to x
; Is Sinistar 'alive'
                            lda >gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_alive
                            bne not_alive

; Yes, then he is not allowed to leave the sector.  Force his location to the nearest edge.

; Check horizontal
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            cmp #gameplay_playfield_bounds_right            ; >gameplay_level~playfield+playfield~bounds+grlib_rect~right
                            bslt ok_right
                            lda #gameplay_playfield_bounds_right            ; >gameplay_level~playfield+playfield~bounds+grlib_rect~right
                            dec a
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            bra check_y
ok_right                    cmp #gameplay_playfield_bounds_left             ; >gameplay_level~playfield+playfield~bounds+grlib_rect~left
                            bsge check_y
                            inc a
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
; Check vertical
check_y                     getword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            cmp #gameplay_playfield_bounds_bottom           ; >gameplay_level~playfield+playfield~bounds+grlib_rect~bottom
                            bslt ok_bottom
                            lda #gameplay_playfield_bounds_bottom           ; >gameplay_level~playfield+playfield~bounds+grlib_rect~bottom
                            dec a
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            bra check_y
ok_bottom                   cmp #gameplay_playfield_bounds_top              ; >gameplay_level~playfield+playfield~bounds+grlib_rect~top
                            bsge ok_top
                            inc a
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

ok_top                      anop
exit                        rtl

; Sinistar is still being built
not_alive                   anop
                            lda >gameplay_sinistar_logic~in_sector
                            beq exit                        ; This shouldn't happen, once Sinistar is out of sector, his position updating happens with a custom function
; Not in the sector anymore
                            lda #0
                            sta >gameplay_sinistar_logic~in_sector
; That's it really.  He will still be alive, but the update code will use the flag above to do a special positioning update that will
; pretty much do the normal movement, but allow for an expanded range.
                            bra exit

                            end

; --------------------------------------------------------------------------------------------
; A custom version of update_position function for Sinistar, when he is out of the main sector.
; This is (sadly)  cut and paste of the playfield_entity_update_position, with the sector range
; expanded out and no 'leave sector' callback.  The entity will be clamped to the edge.
;
; I'm using a custom copy of the function, rather than parameterizing playfield_entity_update_position
; simply because I don't want to incur the overhead of setting everything up, for a special case.
;
; I removed any references to the 'wrapping' verison, for clarity.
;
; Note that this function is 'patched', based on the FPS.
; If the FPS is 30, the speed is doubled.
;
; Parameters:
; x-reg                 - the entity short pointer.
; Returns:
; nothing
; Will preserve x
gameplay_sinistar_update_position_oos start seg_gameplay
                            using math_tables
                            using appdata
                            using gameplay_level_data
                            using playfield_manager_data
                            using playfield_entity_manager_data
                            using gameplay_sinistar_logic_data
                            using gameplay_sound_data
                            using gameplay_ui_data

                            debugtag 'update_position_oos'

; Set the databank to pThis, so we can use register addressing, we are doing enough to overcome the overhead.
                            setdatabanktolabel entities_root

; Don't update the positions of child entities
                            getword {x},#playfield_entity~grentity+grlib_entity~parent_entity_ptr+2
                            jne is_child

                            getword {x},#playfield_entity~speed_x
gameplay_sinistar_update_speed_modifier_patch_x entry
                            nop
                            clc
                            adc >playfield_manager~view_speed_x
                            beq do_y
                            clc
                            adcword {x},#playfield_entity~move_accum_x      ; add to the accumulator, which contains any left over fractional value from the last move
                            tay
                            bmi neg_x_add
; Adding a positive value to X
                            and #$00ff                                      ; save the fractional part for next time
                            putword {x},#playfield_entity~move_accum_x
                            tya
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            clc
                            adcword {x},#playfield_entity~grentity+grlib_entity~x
                            putword {x},#playfield_entity~grentity+grlib_entity~x
; Check to see if it is off the right.
                            cmp #gameplay_sinistar_super_sector_max_x
                            bslt do_y
                            lda #gameplay_sinistar_super_sector_max_x-1
                            putword {x},#playfield_entity~grentity+grlib_entity~x
                            bra do_y

; Adding a negative value to X
neg_x_add                   and #$00ff                                      ; save the fractional part for next time
; Setup rounding correcion. -0.5 is $ff80, and -1 is $ff00, so if there is any factional part
; we want the integer conversion to round toward 0, not away.  Use the carry flag and an add of 0, to adjust the value
                            clc
                            beq neg_x_no_round_correction
                            sec
                            ora #$ff00                                      ; sign extend, though not if 0, there is no -0
neg_x_no_round_correction   anop
                            putword {x},#playfield_entity~move_accum_x
                            tya
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            adc #$0000                                      ; rounding correction
                            clc
                            adcword {x},#playfield_entity~grentity+grlib_entity~x
                            putword {x},#playfield_entity~grentity+grlib_entity~x
                            cmp #gameplay_sinistar_super_sector_min_x
                            bsge do_y
                            lda #gameplay_sinistar_super_sector_min_x+1
                            putword {x},#playfield_entity~grentity+grlib_entity~x

do_y                        anop
                            getword {x},#playfield_entity~speed_y
gameplay_sinistar_update_speed_modifier_patch_y entry
                            nop
                            clc
                            adc >playfield_manager~view_speed_y
                            beq next
                            clc
                            adcword {x},#playfield_entity~move_accum_y      ; add to the accumulator, which contains any left over fractional value from the last move
                            bmi neg_y_add                                   ; have to handle negative numbers differently, because we will need to sign extend
; Adding a positive value to Y
                            tay
                            and #$00ff                                      ; save the fractional part for next time
                            putword {x},#playfield_entity~move_accum_y
                            tya
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            clc
                            adcword {x},#playfield_entity~grentity+grlib_entity~y
                            putword {x},#playfield_entity~grentity+grlib_entity~y
                            cmp #gameplay_sinistar_super_sector_max_y
                            bslt next
                            lda #gameplay_sinistar_super_sector_max_y-1
                            putword {x},#playfield_entity~grentity+grlib_entity~y
                            bra next

; Adding a negative value to Y
neg_y_add                   tay
                            and #$00ff                                      ; save the fractional part for next time
; Setup rounding correcion. The factional part is always postive, so -0.5 is $ff80, and -1 is $ff00, so if there is any factional part
; we want the integer conversion to round toward 0, not away.  Use the carry flag and an add of 0, to adjust the value
                            clc
                            beq neg_y_no_round_correction
                            sec
                            ora #$ff00                                      ; sign extend, though not if 0, there is no -0
neg_y_no_round_correction   anop
                            putword {x},#playfield_entity~move_accum_y
                            tya
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            adc #$0000                                      ; rounding correction
                            clc
                            adcword {x},#playfield_entity~grentity+grlib_entity~y
                            putword {x},#playfield_entity~grentity+grlib_entity~y
                            cmp #gameplay_sinistar_super_sector_min_y
                            bsge next
                            lda #gameplay_sinistar_super_sector_min_y+1
                            putword {x},#playfield_entity~grentity+grlib_entity~y

next                        anop
; Test to see if he is back in_sector
                            getword {x},#playfield_entity~grentity+grlib_entity~x
                            cmp #gameplay_playfield_bounds_left             ; >gameplay_level~playfield+playfield~bounds+grlib_rect~left
                            bslt not_in_sector
                            cmp #gameplay_playfield_bounds_right            ; >gameplay_level~playfield+playfield~bounds+grlib_rect~right
                            bsge not_in_sector

                            getword {x},#playfield_entity~grentity+grlib_entity~y
                            cmp #gameplay_playfield_bounds_top              ; >gameplay_level~playfield+playfield~bounds+grlib_rect~top
                            bslt not_in_sector
                            cmp #gameplay_playfield_bounds_bottom           ; >gameplay_level~playfield+playfield~bounds+grlib_rect~bottom
                            bsge not_in_sector

                            phx
; He is back in sector.  Set the flag, and the regular position updating will take over
                            lda #1
                            sta >gameplay_sinistar_logic~in_sector
; Play the message tune
                            pushsword #id_sfx~message
                            jsl sndlib_play_sfx
; Should show a message too in the status display
                            lda #gameplay_ui~message_sinistar_in_scanner
                            jsl gameplay_ui_set_active_player_message
                            plx
not_in_sector               anop
is_child                    restoredatabank
                            rtl

                            end


; --------------------------------------------------------------------------------------------
; Stun sinistar.
; This also adds to the player's score and prints a message
gameplay_stun_sinistar      start seg_gameplay
                            using math_tables
                            using sinistar_entity_data
                            using player_entity_data
                            using playfield_manager_data
                            using gameplay_player_logic_data
                            using gameplay_sinistar_logic_data
                            using gameplay_manager_data

                            begin_locals
pSinistar                   decl ptr
wTemp                       decl word
work_area_size              end_locals

                            debugtag 'stun_sinistar'

                            sub ,work_area_size

                            getptr >sinistar_entity_root_piece_ptr,<pSinistar
; Cut his velocity in half
                            getword [<pSinistar],#playfield_entity~speed_x
                            asr_nt 1
                            putword [<pSinistar],#same
                            getword [<pSinistar],#playfield_entity~speed_y
                            asr_nt 1
                            putword [<pSinistar],#same

                            ldx #$0e            ; assume minimal color flash
                            lda >gameplay_sinistar_logic~in_sector
                            beq not_in_sector

; Get the absolute distance to the player (note the original had sinistar holding the distance to the player in the caller distance.  Where was that updated? The player is not calling sinistar)
; This is then scaled down, so each component is a max of $ff, then that is multipled together to get a pseudo-linear distance, that can be used to
; pick a flash intensity.

 ago .skip  ;; SKIPPING!

; This is an approximation of how the original did it, where it scaled down both axes, then multiplied them together, then took the upper bits
; This doesn't do a good job, if one axis has a small delta, and the other has a large one.

; Max abs distance between sinistar and the player is 1024 for each axis, though this should be more like 512, since the player
; is always on screen, however, the player isn't alwasy at the center.  It is a bit easier and we get more recision, if we just get
; Sinistar's postiion and use that as the distance, because that is from the center of the screen.
                            getword [<pSinistar],#playfield_entity~grentity+grlib_entity~x
                            bpl ok_x
                            negate a
ok_x                        shiftright 1
                            and #$00ff
                            bne x_not_0
                            inc a              ; can't be 0
x_not_0                     tax

                            getword [<pSinistar],#playfield_entity~grentity+grlib_entity~y
                            bpl ok_y
                            negate a
ok_y                        shiftright 1
                            and #$00ff
                            bne y_not_0
                            inc a              ; can't be 0
y_not_0                     jsl math~umul1r2

; Maximum value here should be $FE01 ($FF * $FF)

; Take the high byte, shift down, and make sure it is even
                            xba
                            shiftright 3
                            and #$000e
.skip

; Get the square of each axis, then add those together, and take the upper bits of that.
; Still just using Sinistar's position, which is the signed distance from the center of the screen
                            getword [<pSinistar],#playfield_entity~grentity+grlib_entity~x
                            bpl ok_x
                            negate a
ok_x                        shiftright 2        ; we want a max of $7f
                            and #$007f
                            bne x_not_0
                            inc a              ; can't be 0
x_not_0                     asl a
                            tax
                            lda >math~squared,x
                            sta <wTemp

                            getword [<pSinistar],#playfield_entity~grentity+grlib_entity~y
                            bpl ok_y
                            negate a
ok_y                        shiftright 2
                            and #$007f
                            bne y_not_0
                            inc a              ; can't be 0
y_not_0                     asl a
                            tax
                            lda >math~squared,x
                            clc
                            adc <wTemp

; Maximum value here should be $7E02 (($7F * $7F) * 2)

; Take the high byte, shift down, and make sure it is even
                            xba
                            shiftright 3
                            and #$000e

; Should have a number, (0-7)*2, that is a rough distance that sinistar is from the player.
; Use that to get a color to 'flash' the screen with.
                            tax
not_in_sector               lda >gameplay_sinistar~stun_flash_color,x
                            sta >playfield_view~palette+palette_modifier~alt_color          ; color slot 0
                            lda #palette_modifier~new_count_down+4                          ; high-bit set to apply on the next frame, and the lower bits are the frame countdown
                            sta >playfield_view~palette+palette_modifier~count_down

; Message display is done elsewhere

; Add to the score
                            lda #gameplay_score~kill_sinistar_part
                            jsl gameplay_add_to_score

                            ret
                            end

; --------------------------------------------------------------------------------------------
; Kill Sinistar!
; This also adds to the player's score
gameplay_kill_sinistar      start seg_gameplay
                            using sinistar_entity_data
                            using player_entity_data
                            using playfield_manager_data
                            using gameplay_player_logic_data
                            using gameplay_sinistar_logic_data
                            using gameplay_manager_data
                            using task_manager_data

                            begin_locals
pTaskData                   decl ptr
work_area_size              end_locals

                            debugtag 'kill_sinistar'

                            sub ,work_area_size
                            setlocaldatabank
; Don't accidentally call twice
                            lda gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_alive
                            jne exit

                            lda #sinistar_state_dead
                            sta gameplay_manager~active_state+player_state~sinistar~state

; Just in case the player is also dying, or gets killed, prevent its callback from ending the game
                            inc gameplay_player~death_delayed
; Stop speaking
                            jsl gameplay_sinistar_stop_speech
                            jsl gameplay_sinistar_clear_taunt_task

; Setup the sequence flag (Inimpulse in the original)
                            lda #$ffff
                            sta gameplay_sinistar~death_sequence_state
                            stz gameplay_sinistar~blown_up      ; extra sequencing flag

; Make sure he is not moving
                            lda >sinistar_entity_root_piece_ptr
                            tax
                            lda #0
                            putword {x},>entities_root+playfield_entity~speed_x
                            putword {x},>entities_root+playfield_entity~speed_y

; Explosion Task
                            pushsword #task_list_4_offset
                            pushptr #_sinistar_explosion_task
                            pushsword #sizeof~gameplay_sinistar_shared_task_data
                            jsl task_manager_create_task
                            jcs error
                            putretptr <pTaskData

; Pick a random explosion increment
; KWG: Not using this
;                            generate_rnd16
;                            and #$0003
;                            asl a
;                            tax
;                            lda gameplay_sinistar_explosion_increments,x
;                            putword [<pTaskData],#gameplay_sinistar_shared_task_data~increment

; Flash Task
                            pushsword #task_list_4_offset
                            pushptr #_sinistar_explosion_flash_task
                            pushsword #sizeof~gameplay_sinistar_shared_task_data
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

                            lda #gameplay_sinistar_explosion_flash_time/4                       ; Div by 4, because it is on the task 4 list
                            putword [<pTaskData],#task_timer_header~timer

; Booms task.
                            pushsword #task_list_4_offset                                       ; the original had this on task_list_2, but it seems too fast.
                            pushptr #_sinistar_explosion_booms_task
                            pushsword #sizeof~gameplay_sinistar_shared_task_data
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

                            lda #gameplay_sinistar_explosion_booms_count
                            putword [<pTaskData],#gameplay_sinistar_shared_task_data~count

; Increment Sinistar kills, though cap at 32768
                            lda gameplay_manager~active_state+player_state~sinistars_killed
                            inc a
                            bmi bad_kills
                            sta gameplay_manager~active_state+player_state~sinistars_killed
bad_kills                   anop

; You get so many points, we have to add it with 32-bits!
                            lda #gameplay_score~kill_sinistar
                            ldx #^gameplay_score~kill_sinistar
                            jsl gameplay_add_to_score_32

                            stz gameplay_player~death_delayed

                            lda gameplay_player~is_dead
                            bne player_is_dead

                            inc gameplay_player~should_warp
                            inc gameplay_manager~is_in_warp                     ; may not need this flag, I'm using gameplay_player~collisions_disabled, for what this was mostly used for.
                            lda #$8000
                            sta gameplay_player_controls~disabled
                            sta gameplay_player~collisions_disabled

player_is_dead              anop

; Yet another task, that will go on while Sinistar is dying.
; This handle the rest of the death sequence, such as moving the player near sinistar, in case he was offscreen, and displaying some messages
; and then doing the warp to the next level
                            pushsword #task_list_1_offset
                            pushptr #_sinistar_death_task
                            pushsword #sizeof~gameplay_sinistar_shared_task_data
                            jsl task_manager_create_task
                            bcs error                                       ; Hmm, if this has an error, we are going to have a real problem continuing.

exit                        restoredatabank
                            ret

error                       anop
                            bra exit
                            end

; ----------------------------------------------------------------------------
; Task callback for the explosion part of the sinistar death sequence
_sinistar_explosion_task    private seg_gameplay
                            using sinistar_entity_data
                            using gameplay_sound_data
                            using gameplay_sinistar_logic_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data

                            debugtag 'task_sinistar_explosion'

                            begin_locals
pEntity                     decl ptr
wX                          decl word
wY                          decl word
wIndex                      decl word
wPieceIndex                 decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank
                            task_resume

; Note, in the original, while the gameplay_sinistar~death_sequence_state is -1, this task would 'mutate' the Sinistar piece images, by
; doing an EOR #$FFFF of the pixel bits, then adding an 'increment' value.  This made the Sinistar image look inverted'ish.
; Well, I'm not going to try and do that, it would be a bit slow and the pixel values are not nicely in a bit buffer like
; the original has and their fancy-pants DMA transfer to the screen magic.  I can maybe add a custom draw function that does something similar on the fly.
                            lda gameplay_sinistar~death_sequence_state
                            bne exit
; Blow up the pieces

; The original code would startup another task, on task_list1, to do the 'breakup' of Sinistar
; I'm just going to do that in this this task.  Also, since I have the center piece as 'solid', rather than keeping
; the individual pieces, I'm just going to blow them all up, using special explosion type, that uses the pieces, then
; the mangled image.

                            jsr _blowup_pieces

                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

; Set a timer
                            lda #gameplay_sinistar_death_task_time/4
                            putword [<pTaskData],#task_timer_header~timer

                            task_sleep here,exit

; Check the timer
                            getword [<pTaskData],#task_timer_header~timer
                            dec a
                            putword [<pTaskData],#same
                            bne exit

; Play another explosion sound
                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

; Maybe do one more?

task_done                   anop
                            pushptr <pTaskData
                            jsl task_manager_free_task

exit                        anop
                            restoredatabank
                            ret
;;;
; Local Subroutine to do the piece blowup
_blowup_pieces              anop
                            lda #sinistar_center_pieces
                            sta <wIndex

breakup_loop                lda <wIndex
                            asl a
                            tax
                            lda gameplay_sinistar~center_breakup_sequence,x         ; index into a breakup sequence table.  They are in order, but just in case I want to change it.
                            sta <wPieceIndex
                            shiftleft 2                                             ; this should just be in the table
                            tax
                            lda >sinistar_entity_pieces_ptrs+2,x
                            sta <pEntity+2
                            pha
                            lda >sinistar_entity_pieces_ptrs,x
                            sta <pEntity
                            pha
; Save the location
                            getword [<pEntity],#playfield_entity~grentity+grlib_entity~x,<wX
                            getword [<pEntity],#playfield_entity~grentity+grlib_entity~y,<wY
; Destroy the piece.  Should only have to destroy the solid center one.
                            pushsword #0
                            jsl sinistar_entity_destroy_piece
; Put in a 'mangled' piece that floats away

                            getword [<pEntity],#playfield_entity~grentity+grlib_entity~parent_entity_ptr+2
                            beq not_child

                            lda >sinistar_entity_root_piece_ptr
                            tax
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            clc
                            adc <wX
                            sta <wX

                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            clc
                            adc <wY
                            sta <wY

not_child                   pushsword <wX
                            pushsword <wY
                            pushsword #explosion_type~sinistar_fragment
                            lda <wPieceIndex
                            sec
                            sbc #12
                            pha
                            jsl explosion_entity_manager_add_explosion_at
                            dec <wIndex
                            bpl breakup_loop

; Put a basic explosion at the last location, which I know is the center
                            pushsword <wX
                            pushsword <wY
                            pushsword #explosion_type~basic
                            pushsword #explosion_variation~default
                            jsl explosion_entity_manager_add_explosion_at

; Make sure he is not moving anymore
                            lda >sinistar_entity_root_piece_ptr
                            tax
                            lda #0
                            putword {x},>entities_root+playfield_entity~speed_x
                            putword {x},>entities_root+playfield_entity~speed_y

                            inc gameplay_sinistar~blown_up              ; signal he is blown up
                            rts

                            end

; ----------------------------------------------------------------------------
; Task callback for the flash-the-screen part of the sinistar death sequence
_sinistar_explosion_flash_task private seg_gameplay
                            using gameplay_sinistar_logic_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using playfield_manager_data

                            debugtag 'task_sinistar_flash'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

; As long as the player is being controlled by other tasks (the screen is moving to Sinistar), flash the screen.
                            lda gameplay_sinistar~death_sequence_state
                            bne do_flash
                            getword [<pTaskData],#task_timer_header~timer
                            dec a
                            putword [<pTaskData],#same
                            bne do_flash
; We are done, free the task
                            pushptr <pTaskData
                            jsl task_manager_free_task
                            bra exit

do_flash                    anop
; Using the 'count' to simply determine which color to flash
                            getword [<pTaskData],#gameplay_sinistar_shared_task_data~count
                            eor #2
                            putword [<pTaskData],#same
                            tax
                            lda gameplay_sinistar~death_flash_color,x
                            sta >playfield_view~palette+palette_modifier~alt_color          ; color slot 0
                            lda #palette_modifier~new_count_down+4                          ; high-bit set to apply on the next frame, and the lower bits are the frame countdown
                            sta >playfield_view~palette+palette_modifier~count_down

exit                        restoredatabank
                            ret

                            end

; ----------------------------------------------------------------------------
; Task callback for the explosion 'booms' part of the sinistar death sequence
_sinistar_explosion_booms_task private seg_gameplay
                            using sinistar_entity_data
                            using gameplay_sinistar_logic_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_sound_data

                            debugtag 'task_sinistar_booms'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank
                            task_resume

; Wait for Sinistar to come on screen
                            getptr >sinistar_entity_pieces_ptrs+(sinistar_piece_nose*4),<pEntity        ; Check his center piece
                            getword [<pEntity],#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq exit

                            task_sleep here                                                             ; just sets the new entry point, after sinistar is on the screen
; Add a warrior-style explosion on the screen, near Sinistar
                            getptr >sinistar_entity_root_piece_ptr,<pEntity
; Put it somewhere near
                            generate_rnd16
                            and #64-1
                            sec
                            sbc #32
                            clc
                            adcword [<pEntity],#playfield_entity~grentity+grlib_entity~x
                            pha
                            get_quick_rnd16
                            and #64-1
                            sec
                            sbc #32
                            clc
                            adcword [<pEntity],#playfield_entity~grentity+grlib_entity~y
                            pha
                            pushsword #explosion_type~warrior
                            pushsword #explosion_variation~default
                            jsl explosion_entity_manager_add_explosion_at

                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

; Count down the number of explosions
                            getword [<pTaskData],#gameplay_sinistar_shared_task_data~count
                            dec a
                            putword [<pTaskData],#same
                            bne exit                            ; exit if we still have more to do.  Note, the resume point will remain the same.

                            pushptr <pTaskData
                            jsl task_manager_free_task

exit                        anop
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Task callback for the master controller of the sinistar death task.
; This manages the text overlay tasks, moves the view to where sinistar is,
; in case he is not on screen, and waits for the other support tasks to complete.
; This will then 'warp' the player to the next sector, if the player is not dead.
_sinistar_death_task        private seg_gameplay
                            using math_tables
                            using task_manager_data
                            using sinistar_entity_data
                            using gameplay_sinistar_logic_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using player_entity_data

                            debugtag 'task_sinistar_death'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank
                            task_resume_timer exit

; The first thing the original did, was to setup additional tasks for displaying overlaid text
; "CONGRATULATIONS"
; "YOU DEFEATED THE SINISTAR"
; Well, for now, I'm skipping that.  It will be expensive to draw with the text drawing functions.
; Maybe just have an image that has the message(s) in-situ

; Turn on the 'impluse' engines.  This just means that the game will be moving the player around
                            lda #$ffff
                            sta gameplay_sinistar~death_sequence_state
                            stz gameplay_sinistar~blown_up

; Get the angle to Sinistar, and save it for later for our warp angle.
; Note, the original seemed to want to set this in the move-to-sinistar task.
; However, looking at the code, where it is set, is if-def'ed out.  A bug I guess?
                            getptr >sinistar_entity_root_piece_ptr,<pEntity
                            getword [<pEntity],#playfield_entity~grentity+grlib_entity~x
                            sec
                            sbc >player_entity_instance+playfield_entity~grentity+grlib_entity~x
                            tax
                            getword [<pEntity],#playfield_entity~grentity+grlib_entity~y
                            sec
                            sbc >player_entity_instance+playfield_entity~grentity+grlib_entity~y
                            jsl math~vec2_angle
                            asl a                       ; we will want it x2
                            sta _warp_angle

; Start another task to do the actual movement of the ship toward Sinistar
                            pushsword #task_list_1_offset
                            pushptr #_move_player_to_sinistar_task
                            pushsword #0
                            jsl task_manager_create_task
;                           bcs error

; Now just wait here, until Sinistar comes on screen

                            task_sleep here,exit
; Wait until his center is on screen
                            getptr >sinistar_entity_pieces_ptrs+(sinistar_piece_nose*4),<pEntity
                            getword [<pEntity],#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            jeq exit                                            ; nope, just exit, and we will resume at the last sleep location
; He is on screen

; Wait a little longer, by putting some time in the timer of the task and then exit
                            lda #(60*3/2)
                            putword [<pTaskData],#task_timer_header~timer
                            task_sleep here,exit

; Player is no longer being moved by the game.  This also signals the Sinistar explosion task that it can start (Why didn't it just add it here?)
                            stz gameplay_sinistar~death_sequence_state
; Original cleared the messages here

; Wait a little longer, by putting some time in the timer of the task and then exit
                            lda #(60*3)
                            putword [<pTaskData],#task_timer_header~timer
                            task_sleep here,exit

; Set to 1, this will stop the move_to task
                            inc gameplay_sinistar~death_sequence_state              ; make this 1

; The original changed the text overlay tasks to display
; "THE BATTLE COMPUTER IS"
; "ENGAGING WARP ENGINES"

; Get the current facing direction of the ship and use that as the direction to 'warp'
; The original set the speed by multiplying 8 in the 'short' direction and 16 in the 'long'.

                            ldx _warp_angle
                            lda >math~sin_256,x
                            shiftleft 4
                            sta _warp_speed_x
                            lda >math~cos_256,x
                            shiftleft 4
                            sta _warp_speed_y

; Start a task to do the warp movement
; Start another task to do the actual movement of the ship toward Sinistar
                            pushsword #task_list_1_offset
                            pushptr #_warp_player_task
                            pushsword #0
                            jsl task_manager_create_task

; Wait a little bit
                            lda #(60*2)
                            putword [<pTaskData],#task_timer_header~timer
                            task_sleep here,exit
; The original removed the displayed text here

; Wait a bit more
                            lda #(60*3)
                            putword [<pTaskData],#task_timer_header~timer
                            task_sleep here,exit

; Start another task to slow the player down
                            pushsword #task_list_4_offset
                            pushptr #_slow_player_warp_speed_task
                            pushsword #0
                            jsl task_manager_create_task

; Update the sector population
                            jsl gameplay_level_apply_difficulty                 ; Apply the difficulty for the current player, which includes setting up desired populations
                            pushdword #0                                        ; fake task data pointer, I know the function doesn't use it.
                            jsl gameplay_task_update_population                 ; force a population rebuild
; Original change the overlay message to
; "ENTERING xxx ZONE"
; "PREPARE FOR BATTLE"

; Re-fresh the border to the new zone's color
                            jsl gameplay_ui_refresh_frame

; Wait a bit more
                            lda #(60*2)
                            putword [<pTaskData],#task_timer_header~timer
                            task_sleep here,exit

; Original cleared the text and also set the overlay tasks to remove themselves on their next cycle

; Reset the flag.
                            lda #$ffff
                            sta gameplay_sinistar~death_sequence_state

; Reposition Sinistar ahead of where the player is facing.
; It is assumed that during the 'warp', the remains of the last Sinistar, will already
; be set to be 'out of sector', so we will just move his out-of-sector position.
                            getptr >sinistar_entity_root_piece_ptr,<pEntity

                            ldx _warp_angle
                            lda >math~sin_256,x
                            asl a
                            putword [<pEntity],#playfield_entity~grentity+grlib_entity~x

                            lda >math~cos_256,x
                            asl a
                            putword [<pEntity],#playfield_entity~grentity+grlib_entity~Y

; Make sure he is not moving
                            lda #0
                            putword [<pEntity],#playfield_entity~speed_x
                            putword [<pEntity],#playfield_entity~speed_y

; Say we are out of warp, and set sinistar to building (should be already, no?)
                            stz gameplay_manager~is_in_warp
; It is also assumed that we desotryed all the pieces, and Sinistar is ready to be re-built.
;                           static_assert_equal sinistar_state_building,0
                            stz gameplay_manager~active_state+player_state~sinistar~state

; Set the player collision type back to normal and give control to the player
                            stz gameplay_player_controls~disabled
                            stz gameplay_player~collisions_disabled

; Done!
                            pushptr <pTaskData
                            jsl task_manager_free_task

exit                        restoredatabank
                            ret

; Shared data for the warp
_warp_angle                 entry
                            ds 2
_warp_speed_x               entry
                            ds 2
_warp_speed_y               entry
                            ds 2
                            end

; ----------------------------------------------------------------------------
; Task callback to move the player toward Sinistar
_move_player_to_sinistar_task private seg_gameplay
                            using task_manager_data
                            using sinistar_entity_data
                            using gameplay_sinistar_logic_data
                            using gameplay_player_logic_data
                            using gameplay_warrior_logic_data
                            using gameplay_manager_data
                            using player_entity_data

                            debugtag 'task_move_player_to_sinistar'

                            begin_locals
pEntity                     decl ptr
wDistanceX                  decl word
wDistanceY                  decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

                            lda gameplay_sinistar~death_sequence_state
                            cmp #1
                            bne task_not_done
; We are done
                            pushptr <pTaskData
                            jsl task_manager_free_task
                            brl exit

task_not_done               anop
                            cmp #0                                  ; is he about to be?
                            bne not_blown_up
; Yes, stop moving him or the player.  Really, I should end the task, no?
                            jsl player_entity_decelerate
                            brl exit

not_blown_up                lda >sinistar_entity_root_piece_ptr
                            tax

; The original turned the 'demo' flag on/off while it did this.  Something related to making this use the same 'demo' attack?

; Note, this is getting the regular target distance, rather than an 'orbital' distance.
; This original code *looks* like it is trying to get an orbital distance, but that was 'patched over'
; to just get the regular distance.  This is because it was trying to use stblimpulse for an orbital table
; however, the distances were not x 16, so it didn't actually work, and they patched it over.
; This means the player just goes to Sinistar and doesn't try to orbit him.
; I could maybe just 'fix' the table.  I'm not sure why they didn't patch that in, rather than nerfing this.
                            pushsword >player_entity_instance+playfield_entity~grentity+grlib_entity~x
                            pushsword >player_entity_instance+playfield_entity~grentity+grlib_entity~y
                            pushsword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            pushsword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            jsl playfield_get_target_distance
                            sta <wDistanceX
                            stx <wDistanceY

                            pushptr #gameplay_player~impulse_speed_table
                            pushsword <wDistanceX
                            pushsword <wDistanceY
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword #player_entity_instance
                            lda >sinistar_entity_root_piece_ptr
                            tax
                            pushsword {x},>entities_root+playfield_entity~speed_x
                            pushsword {x},>entities_root+playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            pushsword gameplay_player~impulse_speed_table+target_velocity_entry~velocity
                            jsl playfield_entity_update_to_target_velocity

; The original also updated the screen velocity, so that the screen moved in-step with the player.  I don't think I need to do that

; I am going to do something different with Sinistar, once he comes on screen.
                            lda >sinistar_entity~on_screen                      ; use global, that will be true if any part is on screen
                            beq exit

; Yes, move him toward the player.  This will get him closer to the center of the screen, when the other task will blow him up.
                            pushptr #gameplay_player~impulse_speed_table        ; using the player impulse table
                            lda >sinistar_entity_root_piece_ptr
                            tax
; Distance from the Sinistar to the player
                            getword >player_entity_instance+playfield_entity~grentity+grlib_entity~x
                            sec
                            sbcword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            pha
                            getword >player_entity_instance+playfield_entity~grentity+grlib_entity~y
                            sec
                            sbcword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            pha
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword >sinistar_entity_root_piece_ptr
                            pushsword #0                                    ; assume no velocity for the player, else we can get a feedback loop,
                            pushsword #0                                    ; because the player is also trying to move toward
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
                            lda gameplay_player~impulse_speed_table+target_velocity_entry~velocity    ; vmax
                            pha
                            jsl playfield_entity_update_to_target_velocity

exit                        restoredatabank
                            ret

                            end

warp_out_speed_x            gequ $0100
warp_out_speed_y            gequ $0200             ; fewer pixels in the Y direction

; ----------------------------------------------------------------------------
; Task callback to warp the player to the next sector
_warp_player_task           private seg_gameplay
                            using task_manager_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using player_entity_data
                            using playfield_manager_data

                            debugtag 'task_warp_player'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

; Test to see if the external speed value we are applying is below a threshold
                            lda _warp_speed_y
                            bpl ok_y
                            negate a
ok_y                        cmp #warp_out_speed_y
                            bge apply
                            lda _warp_speed_x
                            bpl ok_x
                            negate a
ok_x                        cmp #warp_out_speed_x
                            bge apply

; We have slowed down.  Exit the task
                            pushptr <pTaskData
                            jsl task_manager_free_task
                            bra exit

; Apply the speed to the player, and the opposite speed to the view.
apply                       anop

                            lda _warp_speed_x
                            sta >player_entity_instance+playfield_entity~speed_x
;                           negate a
;                           sta playfield_manager~view_speed_x

                            lda _warp_speed_y
                            sta >player_entity_instance+playfield_entity~speed_y
;                           negate a
;                           sta playfield_manager~view_speed_y

exit                        restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Task callback to slow the warp speed down gradually.
_slow_player_warp_speed_task private seg_gameplay
                            using task_manager_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using player_entity_data

                            debugtag 'task_slow_player_warp'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

; Test to see if the external speed value we are applying is below a threshold
                            lda _warp_speed_y
                            bpl ok_y
                            negate a
ok_y                        cmp #warp_out_speed_y
                            bge apply
                            lda _warp_speed_x
                            bpl ok_x
                            negate a
ok_x                        cmp #warp_out_speed_x
                            bge apply

; We have slowed down, enough.  Exit the task
                            stz _warp_speed_x
                            stz _warp_speed_y
                            pushptr <pTaskData
                            jsl task_manager_free_task
                            bra exit

; Slow the warp speed down, by subtracting the current speed / 8
apply                       anop

                            lda _warp_speed_x
                            asr 4
                            negate a
                            clc
                            adc _warp_speed_x
                            sta _warp_speed_x

                            lda _warp_speed_y
                            asr 4
                            negate a
                            clc
                            adc _warp_speed_y
                            sta _warp_speed_y

exit                        restoredatabank
                            ret
                            end

; --------------------------------------------------------------------------------------------
; Stop any speech that might be playing.
gameplay_sinistar_stop_speech start seg_gameplay
                            using gameplay_sinistar_logic_data

                            debugtag 'stop_speech'

                            lda >gameplay_sinistar~speaking
                            beq not_speaking

                            pushsword >gameplay_sinistar~speaking_on_oscillator
                            pushsword #sfx_stop_option~cancel_callback
                            jsl sndlib_stop_sfx_instance

                            lda #0
                            sta >gameplay_sinistar~speaking
                            sta >gameplay_sinistar~speaking_on_oscillator

not_speaking                anop
                            rtl
                            end

; --------------------------------------------------------------------------------------------
; Play a sinistar speach SFX.
; This will setup a callback, so we can interrupt or stop the speech.
; If there is already speech playing, this will not interrupt it. Call gameplay_sinistar_stop_speech
; if you want to be sure the speech plays
gameplay_sinistar_play_speech start seg_gameplay
                            using gameplay_sinistar_logic_data
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'play_speech'

                            sub (2:wSfxXID),work_area_size

                            setlocaldatabank

; We don't want him to speak over the top of himself
                            lda gameplay_sinistar~speaking
                            bne exit                                        ; he is saying something already, just exit
; Play the speech
                            pushsword <wSfxXID
                            pushsword #0                                    ; no frequency adjustment
                            pushdword #_speech_callback
                            jsl sndlib_play_sfx_with_callback
                            bcs exit
; Save where it is playing
                            sta gameplay_sinistar~speaking_on_oscillator
                            inc gameplay_sinistar~speaking                  ; make non-zero to flag he is speaking.

                            lda <wSfxXID
                            sec
                            sbc #id_sfx~i_hunger
                            bcc exit
                            asl a
                            tax
                            lda gameplay_sinistar~speech_table,x
                            sta gameplay_sinistar~speech_segment_sptr
                            stz gameplay_sinistar~speech_timer              ; clear this to signal that we want to start the segment

exit                        anop
                            restoredatabank
                            ret
                            end

; --------------------------------------------------------------------------------------------
; Callback when sinistar speech is complete.
_speech_callback            private seg_gameplay
                            using gameplay_sinistar_logic_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'speech_callback'

                            sub (2:wOscillatorInstance,2:wSfxXID),work_area_size

; We just want to clear the speaking flag
                            lda #0
                            sta >gameplay_sinistar~speaking
                            sta >gameplay_sinistar~speaking_on_oscillator

                            ret
                            end

; --------------------------------------------------------------------------------------------
; Update the speech animation for Sinistar
; This changes the mouth position, based on timing the speech that is playing.
;
; This is expected to be called once a frame, but we know that isn't always possible.
; Parameters:
;   acc - tick delta
gameplay_sinistar_update_speech_anim start seg_gameplay
                            using gameplay_sinistar_logic_data
                            using gameplay_manager_data
                            using sinistar_entity_data

                            setlocaldatabank

                            sta tick_delta

; This is the timer for the animation segment
; Unlike the original, we have to be tolerant of not running at 60 fps.
                            ldx gameplay_sinistar~speech_segment_sptr
                            beq exit                                        ; no animation
                            lda gameplay_sinistar~speech_timer
                            beq start_segment                               ; if 0, we want to start the segment
                            sec
                            sbc tick_delta
                            sta gameplay_sinistar~speech_timer
                            beq segment_advance
                            bcs exit                                        ; still more to go
; Advance to the next segment
segment_advance             txa
                            clc
                            adc #sizeof~speech_segment
                            sta gameplay_sinistar~speech_segment_sptr
                            tax
start_segment               getword {x},#speech_segment~position
                            bmi done                                        ; at the end?

                            sta >sinistar_mouth_position
                            getword {x},#speech_segment~timer
                            clc
                            adc gameplay_sinistar~speech_timer              ; add any underflow from the previous (it will be negative)
                            beq overflow                                    ; 0 or negative, we overflowed the whole next sequence.
                            bpl ok_timer
; 0 or overflowed the whole segement.  It would be nice to skip until we have a 'positive' segment.  Maybe later...
overflow                    lda #1                                          ; minimum of 1
ok_timer                    sta gameplay_sinistar~speech_timer

exit                        restoredatabank
                            rtl

; Done with the animation.  Note that we don't force the mouth to any position
; so that the Death Roar will end with the mouth open, then he can chomp the player.
done                        anop
                            stz gameplay_sinistar~speech_segment_sptr
                            restoredatabank
                            rtl

tick_delta                  ds 2
                            end

; ----------------------------------------------------------------------------
; If Sinistar is alive, this will randomly play a taunt.
; If Sinistar is not built, this will see if the he is out-of-sector
; and if so, he will have a random chance of getting a piece built.
_task_sinistar_taunt        private seg_gameplay
                            using task_manager_data
                            using gameplay_sinistar_logic_data
                            using sinistar_entity_data
                            using gameplay_manager_data

                            debugtag '_task_sinistar_taunt'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

                            lda gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_alive
                            beq is_alive
                            cmp #sinistar_state_dead
                            beq exit
; The original had this bit of sneaky difficulty, that I think I may turn off if in 'easy' mode
; or at least adjust the chance downward.
; If Sinistar is not alive yet, and out-of-sector, he can randomly get a piece!  That's cheating!
; The workers already deliver crystals to him by just reaching the sector edge.

chance_for_add_part         equ $40+1

                            lda gameplay_sinistar_logic~in_sector
                            bne exit

; Out-of-sector, chance for auto-build
                            generate_rnd16
                            and #$ff
                            cmp #chance_for_add_part
                            bge exit

                            jsl sinistar_entity_get_next_piece_to_build
                            bcs exit
                            tax                                                 ; short pointer to x
                            jsl sinistar_entity_build_piece
                            bra exit

is_alive                    anop

chance_for_taunt            equ $38+1

                            generate_rnd16
                            and #$ff
                            cmp #chance_for_add_part
                            bge exit

                            jsl gameplay_sinistar_play_taunt

exit                        restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
gameplay_sinistar_play_taunt start seg_gameplay
                            using gameplay_sinistar_logic_data
                            using gameplay_sound_data

                            debugtag 'play_taunt'

                            begin_locals
work_area_size              end_locals

                            sub ,work_area_size

                            generate_rnd16
                            and #$7f
                            clc
                            adc >gameplay_sinistar~last_taunt_seed
                            and #$ff
                            sta >gameplay_sinistar~last_taunt_seed

; Ranges from the original, though I add +1, because I only have bge, rather than bhi
taunt1_range                equ $28+1
taunt2_range                equ $50+1
taunt3_range                equ $78+1
taunt4_range                equ $a0+1
taunt5_range                equ $c8+1

                            cmp #taunt1_range
                            bge next1

                            pushsword #id_sfx~i_hunger
                            bra speak

next1                       cmp #taunt2_range
                            bge next2

                            pushsword #id_sfx~beware_coward
                            bra speak

next2                       cmp #taunt3_range
                            bge next3

                            pushsword #id_sfx~run_coward
                            bra speak

next3                       cmp #taunt4_range
                            bge next4

                            pushsword #id_sfx~run_run_run
                            bra speak

next4                       cmp #taunt5_range
                            bge next5

                            pushsword #id_sfx~i_hunger_coward
                            bra speak

next5                       pushsword #id_sfx~EEERRAAURGH
speak                       jsl gameplay_sinistar_play_speech

exit                        ret
                            end
