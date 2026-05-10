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

                            copy source/gameplay.constants.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/worker.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm

                            mcopy generated/gameplay.worker.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the workers.

; ----------------------------------------------------------------------------

gameplay_worker_logic_data  data seg_gameplay
; Rate at which animation is updated
gameplay_worker_update~update_rate equ 2

; Orbit factor (mininum orbit distance)
gameplay_worker_orbit_factor    equ 8                       ; OORBIT in original, which was 8
gameplay_worker_drift_orbit_factor equ 2                    ; DORBIT in original, which was 2

gameplay_worker_task            equ 0
gameplay_worker_task~entity_ptr equ gameplay_worker_task
sizeof~gameplay_worker_task     equ gameplay_worker_task~entity_ptr+4

; framelib variations
gameplay_worker_normal_variation_id equ 0
gameplay_worker_with_crystal_variation_id equ 1

; A common multiplier for the worker orbits. (WorkOrbit)
; This is periodically randomised, and is either 1 or -1, to change the direction of the orbit.
gameplay_worker_orbit_multiplier    dc i'1'

id_worker_mission_drift         equ 0               ; note, we are currently requiring the first mission of any responder to not require a caller
id_worker_mission_tail          equ 1
id_worker_mission_intercept     equ 2
id_worker_mission_bring_crystal equ 3
id_worker_mission_evade         equ 4
id_worker_mission_count         equ 5               ; keep last

; The jump table to the worker's missions.
gameplay_worker_logic~mission_table dc a'gameplay_worker_mission_drift'
                            dc a'gameplay_worker_mission_tail'
                            dc a'gameplay_worker_mission_intercept'
                            dc a'gameplay_worker_mission_bring_crystal'
                            dc a'gameplay_worker_mission_evade'

; Orbital table for the workers (stblworker)
; Note, these distance values are skewed higher, because the orbital distance calculation returns
; distance x 16
gameplay_worker_logic~orbit_speed_table anop
                            dc i'1536|2,(65|4),acceleration_function~3'
                            dc i'0800|2,(42|4),acceleration_function~2'
                            dc i'0384|2,(25|4),acceleration_function~1'
                            dc i'0320|2,(24|4),acceleration_function~1'
                            dc i'0256|2,(22|4),acceleration_function~1'
                            dc i'0192|2,(18|4),acceleration_function~1'
                            dc i'0128|2,(12|4),acceleration_function~1'
                            dc i'0064|2,(07|4),acceleration_function~3'
                            dc i'0000|2,(03|4),acceleration_function~4'

; Workers without crystals, intercepting a crystal or sinibomb.  (stblintercept)
gameplay_worker_logic~intercept_speed_table anop
                            dc i'1536,(65|4),acceleration_function~3'
                            dc i'0080,(48|4),acceleration_function~4'
                            dc i'0064,(44|4),acceleration_function~4'
                            dc i'0048,(36|4),acceleration_function~3'
                            dc i'0032,(32|4),acceleration_function~3'
                            dc i'0008,(16|4),acceleration_function~2'
                            dc i'0000,(12|4),acceleration_function~1'

; Bring crystal intercept speed table.  (stblheavy)
gameplay_worker_logic~bring_crystal_intercept_speed_table anop
                            dc i'1536,(65|4),acceleration_function~3'
                            dc i'0048,(36|4),acceleration_function~4'
                            dc i'0032,(32|4),acceleration_function~3'
                            dc i'0008,(16|4),acceleration_function~2'
                            dc i'0000,(12|4),acceleration_function~1'

                            end

; ----------------------------------------------------------------------------
; Gameplay Logic initialization for a new worker
; Parameters:
; x-reg         - short pointer to the entity
gameplay_worker_initialize  start seg_gameplay
                            using appdata
                            using worker_entity_data
                            using gameplay_worker_logic_data
                            using applib_data
                            using task_manager_data

                            debugtag 'worker_initialize'

                            begin_locals
pTaskData                   decl ptr
spThis                      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            stx <spThis

                            pushsword #task_list_8_offset
                            pushptr #gameplay_task_worker_logic_tick
                            pushsword #sizeof~gameplay_worker_task
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

; Add the entity to the task data
                            lda <spThis
                            putptrlow [<pTaskData],#gameplay_worker_task~entity_ptr
                            lda #^entities_root
                            putptrhigh [<pTaskData],#gameplay_worker_task~entity_ptr

; Add the task, to the entity, in the task1 slot
                            ldx <spThis
                            lda <pTaskData
                            putptrlow {x},>entities_root+playfield_entity~task1_ptr
                            lda <pTaskData+2
                            putptrhigh {x},>entities_root+playfield_entity~task1_ptr

error                       anop
                            ret
                            end

; ----------------------------------------------------------------------------
; Task callback for worker logic
gameplay_task_worker_logic_tick start seg_gameplay
                            using appdata
                            using worker_entity_data
                            using gameplay_worker_logic_data
                            using applib_data

                            debugtag 'task_worker_logic_tick'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

; Set the databank to the entities pool
                            setdatabanktolabel entities_root

;                           assert_brk 'task_worker_logic_tick'

                            getword [<pTaskData],#gameplay_worker_task~entity_ptr
                            tay

; Call the mission code.
                            getword {y},#playfield_entity~mission_id
                            asl a
                            tax
                            jsr (gameplay_worker_logic~mission_table,x)

                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Give the worker a crystal.
; Parameters:
; spThis        - short pointer to the worker entity
gameplay_worker_give_crystal start seg_gameplay
                            using worker_entity_data
                            using gameplay_worker_logic_data
                            using gameplay_caller_logic_data
                            using sinistar_entity_data

                            debugtag 'give_crystal'
                            debugtag 'gameplay_worker'

                            begin_locals
pTaskData                   decl ptr
work_area_size              end_locals

                            sub (2:spThis),work_area_size

; Make sure it is not responding to anyone
                            ldy <spThis
                            jsl gameplay_responder_remove_from_caller

; Change characteristic id
                            lda #id_characteristic_worker_with_crystal
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~characteristic_id

; Set the framelib variation.
                            lda #gameplay_worker_with_crystal_variation_id
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~variation
                            getword {x},>entities_root+grlib_entity~changed
                            ora #grlib_entity~changed_frame_set
                            putword {x},>entities_root+grlib_entity~changed

; Patch in the mission.  This mission doesn't get 'assigned' like the others and
; we don't have the caller (sinistar), know about this 'responder'.
; This is the last thing the worker will do, and if sinistar happens to
; die or get completed, the worker will just hang around him.
                            lda #id_worker_mission_bring_crystal
                            putword {x},>entities_root+playfield_entity~mission_id
; Special priority, so it doesn't get distracted.
                            lda #mission_special_priority
                            putword {x},>entities_root+playfield_entity~mission_priority
                            putword {x},>entities_root+playfield_entity~caller_priority
                            lda >sinistar_entity_pieces_ptrs
                            putword {x},>entities_root+playfield_entity~caller_sptr

                            ret
                            end

; ----------------------------------------------------------------------------
; The mission to just float around
; Parameters:
;  entity short pointer in y
;
; The function can assume that the databank is set to the entities_root
gameplay_worker_mission_drift private seg_gameplay
                            using gameplay_worker_logic_data
                            using grlib_global_data

                            debugtag 'mission_drift'

                            begin_locals
spEntity                    decl word
wDistanceX                  decl word
wDistanceY                  decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
; In the original game, the worker drift, just made them turn in a circle
                            getword {y},#playfield_entity~desired_direction
                            inc a
                            cmp #playfield_entity~direction_range
                            blt ok_direction
                            lda #0
ok_direction                anop
                            pha                     ; save for later
; Push the full entity pointer
                            tyx                     ; entity short pointer into x
; direction is in A
                            jsl playfield_entity_set_desired_direction

; Orbiting ourselves.  We can't get an angle from points, since they are the same, so just use the facing direction
                            pla                     ; get the direction back
                            shiftleft 3             ; direction x 8
                            pha                     ; = angle
                            pushsword #gameplay_worker_drift_orbit_factor
                            pushsword >gameplay_worker_orbit_multiplier
                            jsl playfield_get_orbital_distance_from_angle
                            sta <wDistanceX
                            stx <wDistanceY

                            pushptr #gameplay_worker_logic~orbit_speed_table
                            pushsword <wDistanceX
                            pushsword <wDistanceY
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <spEntity
                            pushsword #0                        ; imagining that the target (us), is stationary
                            pushsword #0
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda >gameplay_worker_logic~orbit_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

                            lret

                            end

; ----------------------------------------------------------------------------
; Worker Tail/Orbit Mission Logic
; Parameters:
;  entity short pointer in y
;
; The function can assume that the databank is set to the entities_root
gameplay_worker_mission_tail private seg_gameplay
                            using appdata
                            using worker_entity_data
                            using gameplay_worker_logic_data
                            using gameplay_level_data
                            using grlib_global_data

                            debugtag 'mission_tail'

                            begin_locals
spEntity                    decl word
spTargetEntity              decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
                            getword {y},#playfield_entity~caller_sptr
                            beq invalid_caller

                            sta <spTargetEntity
                            tax

; Take this opportunity to update the caller distance, used by the caller assignment code.
                            inline_responder_update_distance {y},{x}

; Push the table parameter for playfield_get_to_target_velocity now
                            pushptr #gameplay_worker_logic~orbit_speed_table

; Get the orbital distance
                            pushsword {y},#playfield_entity~grentity+grlib_entity~x
                            pushsword {y},#playfield_entity~grentity+grlib_entity~y
                            pushsword {x},#playfield_entity~grentity+grlib_entity~x
                            pushsword {x},#playfield_entity~grentity+grlib_entity~y
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            pushsword #gameplay_worker_orbit_factor
                            pushsword >gameplay_worker_orbit_multiplier
                            jsl playfield_get_orbital_distance_speculative
                            pha                                                         ; distance X
                            phx                                                         ; distance Y
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <spEntity
                            ldx <spTargetEntity
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda >gameplay_worker_logic~orbit_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

invalid_caller              anop
                            lret
                            end

; ----------------------------------------------------------------------------
; Intercept logic.  This is for intercepting a crystal.
; Parameters:
;  entity short pointer in y
;
; The function can assume that the databank is set to the entities_root
gameplay_worker_mission_intercept private seg_gameplay
                            using appdata
                            using worker_entity_data
                            using gameplay_worker_logic_data
                            using gameplay_level_data

                            debugtag 'mission_intercept'

                            begin_locals
spEntity                    decl word
spTargetEntity              decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
                            getword {y},#playfield_entity~caller_sptr
                            beq invalid_caller

                            sta <spTargetEntity
                            tax

; Take this opportunity to update the caller distance.
                            inline_responder_update_distance {y},{x}

                            pushptr #gameplay_worker_logic~intercept_speed_table
; Why not use the caller distance, I just calculated?
; Well, that is currently the absolute distance, and is used by the gameplay_caller_logic_tick for
; assignment.  Use that for the target distance too?
                            inline_entity_push_target_distance {y},{x}
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <spEntity
                            ldx <spTargetEntity
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda >gameplay_worker_logic~intercept_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

invalid_caller              anop
                            lret
                            end

; ----------------------------------------------------------------------------
; Bring a crystal to Sinistar
; This mission has a priority where it doesn't get interrupted
; Parameters:
;  entity short pointer in y
;
; The function can assume that the databank is set to the entities_root
gameplay_worker_mission_bring_crystal private seg_gameplay
                            using appdata
                            using worker_entity_data
                            using gameplay_worker_logic_data
                            using gameplay_level_data
                            using gameplay_entity_data
                            using sinistar_entity_data
                            using grlib_global_data
                            using gameplay_manager_data

                            debugtag 'mission_bring_crystal'

                            begin_locals
spEntity                    decl word
spParentEntity              decl word
spTargetEntity              decl word
wTargetX                    decl word
wTargetY                    decl word
wDistanceX                  decl word
wDistanceY                  decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
                            inline_entity_test_should_think {y}         ; like the original, we will see if we should 'think' or not
                            jcs exit

                            getword {y},#playfield_entity~caller_sptr
                            jeq invalid_caller

                            cmp >sinistar_entity_pieces_ptrs            ; For this mission, this should always be the root sinistar piece
                            jne invalid_caller

                            lda >gameplay_manager~active_state+player_state~sinistar~state   ; Is sinistar dead?
                            cmp #sinistar_state_dead
                            jeq do_tail

                            cmp #sinistar_state_alive
                            bne not_alive

; If Sinistar is alive, and it is the first one the player is facing, we go easy on the player
; and don't repair Sinistar
                            lda >gameplay_manager~active_state+player_state~sinistars_killed
                            jeq do_tail

not_alive                   jsl sinistar_entity_get_next_piece_to_build
                            jcs do_tail                                 ; fully built?

                            sta <spTargetEntity
                            tax                                         ; x will have the target

                            lda >sinistar_entity_root_piece_ptr
                            sta <spParentEntity
                            tay                                         ; y will have the parent

; Targeting the parent?
                            cmp <spTargetEntity
                            bne is_child

; Yes, get just get the target's position.
                            getword {x},#playfield_entity~grentity+grlib_entity~x
                            sta <wTargetX
                            getword {x},#playfield_entity~grentity+grlib_entity~y
                            sta <wTargetY
                            bra update_target_distance

; We have to get the child absolute position
is_child                    getword {y},#playfield_entity~grentity+grlib_entity~x
                            clc
                            adcword {x},#playfield_entity~grentity+grlib_entity~x
                            sta <wTargetX

                            getword {y},#playfield_entity~grentity+grlib_entity~y
                            clc
                            adcword {x},#playfield_entity~grentity+grlib_entity~y
                            sta <wTargetY

; Take this opportunity to update the distance to the caller
update_target_distance      ldy <spEntity
                            inline_responder_update_distance_xy {y},<wTargetX,<wTargetY

; Getting the distance.  Why not use the caller distance, I just calculated?
; Well, that is currently the absolute distance, and is used by the gameplay_caller_logic_tick for
; assignment.  Might be more efficient to just get this distance, then make it into and absolute distance
; and put it into the responder fields
                            pushptr #gameplay_worker_logic~bring_crystal_intercept_speed_table
; Distance x
                            getword <wTargetX
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~x
                            sta <wDistanceX                                             ; save for later
                            pha
; Distance y
                            getword <wTargetY
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~y
                            sta <wDistanceY                                             ; save for later
                            pha

                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <spEntity
                            ldx <spParentEntity
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda >gameplay_worker_logic~bring_crystal_intercept_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

close_to_sinistar_piece     equ 4

                            lda <wDistanceX
                            cmp #close_to_sinistar_piece
                            bsge too_far
                            cmp #-close_to_sinistar_piece
                            bslt too_far
                            lda <wDistanceY
                            cmp #close_to_sinistar_piece
                            bsge too_far
                            cmp #-close_to_sinistar_piece
                            bslt too_far
; Close enough, add the piece

                            ldx <spEntity
                            jsl playfield_entity_mark_for_removal

                            ldx <spTargetEntity
                            jsl sinistar_entity_build_piece
                            bcc ok_build
; Didn't build that specific piece, someone else probably got there first.
; Pick another
                            jsl sinistar_entity_get_next_piece_to_build
                            bcs not_building                                    ; fully built?
                            tax                                                 ; short pointer to x
                            jsl sinistar_entity_build_piece

not_building                anop
ok_build                    anop
invalid_caller              anop
too_far                     anop
exit                        lret

; Run the tail mission
do_tail                     ldy <spEntity
; Note, orginal code passed through a different orbit factor (SORBIT)
                            jsr gameplay_worker_mission_tail
                            bra exit
                            end

; ----------------------------------------------------------------------------
gameplay_worker_mission_evade private seg_gameplay
                            using appdata
                            using worker_entity_data
                            using gameplay_worker_logic_data
                            using gameplay_level_data

                            debugtag 'mission_evade'

                            begin_locals
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.
                            lret
                            end

; -----------------------------------------------------------------------------
; Worker with crystal is leaving the sector.
; Parameters:
; y-reg     - short pointer to the entity
gameplay_worker_with_crystal_leave_sector start seg_gameplay
                            using gameplay_manager_data
                            using gameplay_player_logic_data
                            using sinistar_entity_data

                            phy                                             ; save entity for later
; Sinistar 'building'?
                            lda >gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_building
                            bne not_building

; Player alive?
                            lda >gameplay_player~is_dead
                            bne not_building

                            jsl sinistar_entity_get_next_piece_to_build
                            bcs not_building                                ; fully built?
                            tax                                             ; short pointer to x
                            jsl sinistar_entity_build_piece

not_building                anop
                            plx
                            jsl playfield_entity_mark_for_removal

                            rtl

                            end


; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------
; Initialize the workers for gameplay, this is pre-state activation
gameplay_workers_initialize start seg_gameplay
                            using worker_entity_manager_data

                            debugtag 'workers_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_workers_uninitialize start seg_gameplay
                            using gameplay_worker_logic_data
                            using gameplay_level_data

                            debugtag 'workers_uninitialize'

                            jsl worker_entity_manager_remove_all

                            rtl
                            end

; ----------------------------------------------------------------------------
; Turn deactivations
gameplay_workers_turn_deactivate start seg_gameplay
                            using worker_entity_manager_data

                            debugtag 'workers_turn_deactivate'

                            jsl worker_entity_manager_remove_all
; The population function will add the workers later in the state activation

                            rtl
                            end

; ----------------------------------------------------------------------------
; Check the population of workers and add more if needed
; Parameters:
; wMax      - max number to add
; wEdge     - add at the edges of the sector
; Returns:
; number added
gameplay_workers_check_population start seg_gameplay
                            using appdata
                            using worker_entity_data
                            using worker_entity_manager_data
                            using gameplay_worker_logic_data
                            using gameplay_level_data
                            using gameplay_manager_data
                            using playfield_manager_data

                            debugtag 'workers_check_population'

                            begin_locals
wCount                      decl word
result                      decl word
work_area_size              end_locals

                            sub (2:wMax,2:wEdge),work_area_size

                            setlocaldatabank

                            stz <result
; Get the desired amount.  Pass this in too?
                            lda gameplay_manager~active_state+player_state~desired_pop~workers      ; fp16 value
                            bmi no_extra                                ; test for negative
                            xba
                            and #$00ff                                  ; integer portion
                            sec
                            sbc >worker_entity_count
                            bcc no_extra
                            beq no_extra
; A, has ours deficit
                            cmp <wMax                   ; clamp to max limit
                            blt ok
                            lda <wMax
                            beq no_extra
ok                          sta <wCount
                            sta <result

                            lda <wEdge
                            bne loop_edge

loop                        anop
; Make sure we can do the range optimizations
                            static_assert_not_equal gameplay_playfield_width_mask,0
                            static_assert_not_equal gameplay_playfield_height_mask,0

                            generate_rnd16
                            and #gameplay_playfield_width_mask
                            clc
                            adc #gameplay_playfield_min_x
                            pha                         ; x coord
                            generate_rnd16
                            and #gameplay_playfield_height_mask
                            clc
                            adc #gameplay_playfield_min_y
                            pha                         ; y coord
                            jsl worker_entity_manager_add_worker

                            dec <wCount
                            bne loop
                            bra no_extra

; Add to the edges
loop_edge                   anop
                            jsl gameplay_generate_random_edge_location
                            pha         ; x coordinate
                            phx         ; y coordinate
                            jsl worker_entity_manager_add_worker

                            dec <wCount
                            bne loop_edge

no_extra                    anop
                            restoredatabank

                            ret 2:result
                            end
