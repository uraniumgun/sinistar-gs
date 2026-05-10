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

                            copy source/task.definitions.asm
                            copy source/gameplay.constants.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/crystal.entity.definitions.asm

                            mcopy generated/gameplay.crystal.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the crystals.

; ----------------------------------------------------------------------------
gameplay_crystal_logic_data data seg_gameplay

gameplay_crystal_task_data  equ sizeof~task_control                         ; Starting with support for sleep commands
gameplay_crystal_task_data~entity_ptr equ gameplay_crystal_task_data        ; Pointer to the entity
gameplay_crystal_task_data~age equ gameplay_crystal_task_data~entity_ptr+4  ; age of the crystal
sizeof~gameplay_crystal_task_data equ gameplay_crystal_task_data~age+2

; Number of passes through the logic, with the crystal off screen. (64 * 16) / 60 = 17 seconds.
max_crystal_age             equ 16

; Chance that a worker, who is close enough, will get the offscreen crystal they are chasing.
crystal_catch_chance        equ 1*(60*256)/100
; The pixel distance, a worker has to be within, to catch an offscreen crystal
; This is an axis of a manhatten distance, and we don't add the axis together either, so if both are less that this, they win
; This is all off screen, and just a way to have the workers capture what they are chasing.
; Original code, used 12
crystal_catch_distance      equ 12

; Rate at which the crystal runs through its animation.
crystal_animation~rate      equ 4
; To keep the crystals from flashing at the same'ish time, track
; the last time a flash happened and don't do another until some
; amount of time has expired
crystal_ticks_between_flashes equ 60
; The last time a crystal flashed.  Just the lower part of the tick
crystal_last_flash_tick     ds 2
                            end

; ----------------------------------------------------------------------------
; Parameters:
; x-reg         - short pointer to entity
gameplay_crystal_initialize start seg_gameplay
                            using crystal_entity_data
                            using gameplay_crystal_logic_data
                            using task_manager_data

                            debugtag 'crystal_initialize'

                            begin_locals
spThis                      decl word
pTaskData                   decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            stx <spThis
                            jsl gameplay_caller_initialize

                            pushsword #task_list_64_offset
                            pushptr #gameplay_task_crystal_logic_tick
                            pushsword #sizeof~gameplay_crystal_task_data
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

; Put the caller pointer into the task data
                            lda <spThis
                            tax
                            putptrlow [<pTaskData],#gameplay_crystal_task_data~entity_ptr
                            lda #^entities_root
                            putptrhigh [<pTaskData],#gameplay_crystal_task_data~entity_ptr

; And the task pointer, into the caller.  Using the task2 slot

                            lda <pTaskData
                            putptrlow {x},>entities_root+playfield_entity~task2_ptr
                            lda <pTaskData+2
                            putptrhigh {x},>entities_root+playfield_entity~task2_ptr

error                       anop
                            ret
                            end

; -----------------------------------------------------------------------------
gameplay_crystal_turn_activate  start seg_gameplay
                            using applib_data
                            using gameplay_crystal_logic_data

                            lda >applib~current_tick
                            sta >crystal_last_flash_tick

                            rtl
                            end

; -----------------------------------------------------------------------------
gameplay_task_crystal_logic_tick start seg_gameplay
                            using applib_data
                            using math_tables
                            using task_manager_data
                            using crystal_entity_data
                            using crystal_entity_manager_data
                            using gameplay_sound_data
                            using gameplay_crystal_logic_data

                            debugtag 'crystal_logic_tick'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

; Set the databank to the entities pool
                            setdatabanktolabel entities_root

                            getword [<pTaskData],#gameplay_crystal_task_data~entity_ptr
                            sta <spEntity
                            tay

; Resume task.  Note, we are doing this after we have setup the spEntity
                            task_resume
; Is the crystal on screen?
                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq not_on_screen
; Yes, clear the age
                            lda #0
                            putword [<pTaskData],#gameplay_crystal_task_data~age

; Setup to occasionally flash.
                            pushptr <pTaskData
                            pushsword #task_list_8_offset
                            jsl task_manager_change_list

skip_flash                  anop
exit_flash                  anop
                            task_sleep here,exit
;;;
; Resume point for on-screen
; Is the crystal still on screen?
                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            bne still_on_screen

; Nope, switch to offscreen thinking
                            pushptr <pTaskData
                            pushsword #task_list_64_offset
                            jsl task_manager_change_list

                            task_sleep reset,exit                       ; resets entry point to the top of the task

still_on_screen             anop

                            jsr _attract

; Can we flash?
                            lda >applib~current_tick
                            sec
                            sbc >crystal_last_flash_tick
                            cmp #crystal_ticks_between_flashes
                            blt skip_flash

; Do a 'fast' random, by just peeking into the seed array
                            generate_rnd16
                            bmi skip_flash                              ; use bit 15 as a quick 50/50

; Set the animation speed.  Could maybe vary this a bit.
                            lda #crystal_animation~rate
                            putword {y},#playfield_entity~frame_animation_timer
                            putword {y},#playfield_entity~frame_animation_rate

; Set the framelib collection / set
                            pushsword <spEntity
                            pushptr #preloaded~crystal_framelib         ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            pushsword #1                                ; the flash variation
                            jsl playfield_entity_set_collection_from_preload

; Set the time of the flash
                            lda >applib~current_tick
                            sta >crystal_last_flash_tick
; And play a sound
                            pushsword #id_sfx~crystal_flash
                            jsl sndlib_play_sfx

                            bra exit_flash

;;;
; Offscreen thinking
not_on_screen               anop
                            getword [<pTaskData],#gameplay_crystal_task_data~age
                            inc a
                            beq was_max
                            putword [<pTaskData],#same
was_max                     anop
                            cmp #max_crystal_age
                            blt ok_age
; It is dead
                            ldx <spEntity
                            jsl playfield_entity_mark_for_removal
                            bra exit

ok_age                      anop
                            ldy <spEntity
; See if one of the workers, who are responding, will capture the crystal
                            getword {y},#playfield_entity~responder_quota+responder_type~worker
                            beq no_responders               ; any workers at all?
; Roll to see if there is a chance to catch the crystal
                            generate_rnd16
                            and #$00ff
                            cmp #crystal_catch_chance
                            bge no_responders

; Loop through the responders.  Note, there can be warriors in the list
                            getword {y},#playfield_entity~responder_root_sptr
                            beq no_responders

responder_loop              tax
; Make sure it is a worker
                            getword {x},#playfield_entity~type
                            cmp #entity_type~worker
                            bne next_responder

                            getword {x},#playfield_entity~caller_dist_x
                            cmp #crystal_catch_distance
                            bge next_responder
                            getword {x},#playfield_entity~caller_dist_y
                            cmp #crystal_catch_distance
                            bge next_responder
; This responder is close enough
                            getword {x},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq responder_wins                          ; Is it on screen?  If not, he wins

next_responder              anop
                            getword {x},#playfield_entity~next_sibling_sptr
                            bne responder_loop
; fall though if at the end of the responders

no_responders               anop
; Make sure we are on the correct, offscreen, task list
                            pushptr <pTaskData
                            pushsword #task_list_64_offset
                            jsl task_manager_change_list

exit                        restoredatabank
                            ret

responder_wins              anop
                            phx                                     ; push the responder sptr while we have it
; Remove the crystal
                            ldx <spEntity
                            jsl playfield_entity_mark_for_removal
; Give the worker the crystal
                            jsl gameplay_worker_give_crystal
                            bra exit

_attract                    anop
patch_disable_attraction    entry
                            nop                                     ; will be set to rts if attraction is off
                            getword >player_entity_instance+playfield_entity~grentity+grlib_entity~x
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~x
                            bpl pos_x
patch_crystal_attraction_x_neg entry
                            cmp #-20
                            bge close_x
                            rts
patch_crystal_attraction_x_pos entry
pos_x                       cmp #20
                            bge not_close
close_x                     tax

                            getword >player_entity_instance+playfield_entity~grentity+grlib_entity~y
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~y
                            bpl pos_y
patch_crystal_attraction_y_neg entry
                            cmp #-20
                            bge close_y
                            rts
patch_crystal_attraction_y_pos entry
pos_y                       cmp #20
                            bge not_close
close_y                     anop
; In range!
                            phy
                            jsl math~vec2_angle
                            ply
                            asl a
                            tax
; Add the sin / cos value to the crystal speed
; These values should be capped, so we don't cross our max-velocity.
                            lda >math~sin_256,x
                            clc
                            adcword {y},#playfield_entity~speed_x
                            sclamp a,#math~max_fps_adjusted_neg_speed,#math~max_fps_adjusted_pos_speed
                            putword {y},#playfield_entity~speed_x

                            lda >math~cos_256,x
                            clc
                            adcword {y},#playfield_entity~speed_y
                            sclamp a,#math~max_fps_adjusted_neg_speed,#math~max_fps_adjusted_pos_speed
                            putword {y},#playfield_entity~speed_y
not_close                   rts

                            end

; ----------------------------------------------------------------------------
; Initialize the crystals for gameplay, this is pre-state activation
gameplay_crystals_initialize start seg_gameplay
                            using crystal_entity_manager_data

                            debugtag 'crystals_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_crystals_uninitialize start seg_gameplay
                            using gameplay_crystal_logic_data
                            using gameplay_level_data

                            debugtag 'crystals_uninitialize'

                            jsl crystal_entity_manager_remove_all

                            rtl
                            end

; ----------------------------------------------------------------------------
; Turn deactivation
gameplay_crystals_turn_deactivate start seg_gameplay
                            using crystal_entity_manager_data

                            debugtag 'crystals_turn_deactivate'

                            jsl crystal_entity_manager_remove_all

                            rtl
                            end

; ----------------------------------------------------------------------------
; Apply the crystal attraction state
; Parameters:
; a-reg     - desired state
gameplay_crystals_apply_attraction start seg_gameplay
                            using gameplay_manager_data
                            using gameplay_crystal_logic_data

                            debugtag 'crystals_set_attraction'

                            setlocaldatabank

                            sta gameplay_crystal_attraction~state
                            cmp #crystal_attraction~off
                            bne not_off
; off, just disable the attaction function
                            shortm
                            lda #$60            ; rts
                            sta patch_disable_attraction
                            longm
                            restoredatabank
                            rtl
not_off                     cmp #crystal_attraction~low
                            bne is_high
; low
                            shortm
                            lda #$ea            ; nop
                            sta patch_disable_attraction
                            longm
                            lda #crystal_attraction~low_distance
                            sta patch_crystal_attraction_x_pos+1
                            sta patch_crystal_attraction_y_pos+1
                            lda #-crystal_attraction~low_distance
                            sta patch_crystal_attraction_x_neg+1
                            sta patch_crystal_attraction_y_neg+1
                            restoredatabank
                            rtl

; high
is_high                     shortm
                            lda #$ea            ; nop
                            sta patch_disable_attraction
                            longm
                            lda #crystal_attraction~high_distance
                            sta patch_crystal_attraction_x_pos+1
                            sta patch_crystal_attraction_y_pos+1
                            lda #-crystal_attraction~high_distance
                            sta patch_crystal_attraction_x_neg+1
                            sta patch_crystal_attraction_y_neg+1
                            restoredatabank
                            rtl
                            end
