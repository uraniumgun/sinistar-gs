                            copy lib/source/debug.definitions.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm
                            copy lib/source/grlib.update.rects.definitions.asm

                            copy source/app.build.definitions.asm
                            copy source/app.debug.definitions.asm

                            copy source/playfield.entity.definitions.asm
                            copy source/playfield.definitions.asm
                            copy source/collision.definitions.asm
                            copy source/task.definitions.asm
                            copy source/gameplay.constants.asm
                            copy source/gameplay.entity.characteristic.definitions.asm

                            mcopy generated/playfield.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
playfield_entity_data       data seg_entity

; These next tables need to cover all the entities
                            static_assert_equal entity_type~count,10

; Remove handlers for the entity types
entity_remove_handlers      anop
                            dc a2'rock_entity_remove_handler'       ;planetoid
                            dc a2'player_entity_remove_handler'     ;player
                            dc a2'sinistar_entity_remove_handler'   ;sinistar
                            dc a2'bomb_entity_remove_handler'       ;bomb
                            dc a2'crystal_entity_remove_handler'    ;crystal
                            dc a2'worker_entity_remove_handler'     ;worker
                            dc a2'warrior_entity_remove_handler'    ;warrior
                            dc a2'shot_entity_remove_handler'       ;player_shot
                            dc a2'shot_entity_remove_handler'       ;warrior_shot
                            dc a2'explosion_entity_remove_handler'  ;explosion

entity_responder_types      anop
                            dc i'-1'                        ;planetoid
                            dc i'-1'                        ;player
                            dc i'-1'                        ;sinistar
                            dc i'-1'                        ;bomb
                            dc i'-1'                        ;crystal
                            dc i'responder_type~worker'     ;worker
                            dc i'responder_type~warrior'    ;warrior
                            dc i'-1'                        ;player_shot
                            dc i'-1'                        ;warrior_shot
                            dc i'-1'                        ;explosion

                            end

; -----------------------------------------------------------------------------
; Construct an entity
; Parameters:
;   short pointer to the entity in Y
; Returns:
;  carry clear if no error
playfield_entity_construct  start seg_entity
                            using playfield_entity_manager_errors

                            debugtag 'construct_playfield_entity'

                            begin_locals
spThis                      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            tya
                            jeq null_pointer

                            sty <spThis
; Set the databank to the entities
                            setdatabanktolabel entities_root

; Construct the embedded grlib_entity
                            pushsword #entities_root|-16
                            phy
                            jsl grlib_entity_construct

                            lda #0
                            ldy <spThis
; Hmm, this is getting kinda big, maybe just zero out the sizeof?  That would be slower though
; Might be best to just not zero out some values that the caller *should* be setting to valid values.
; (bad programming practice, but good for speed)
                            putword {y},#playfield_entity~type
                            putword {y},#playfield_entity~direction
                            putword {y},#playfield_entity~desired_direction
                            putword {y},#playfield_entity~turret_direction
                            putword {y},#playfield_entity~target_angle
                            putword {y},#playfield_entity~target_angle_change_avg
                            putword {y},#playfield_entity~frame_animation_timer
                            putword {y},#playfield_entity~frame_animation_rate
                            putword {y},#playfield_entity~rotation_flags
                            putword {y},#playfield_entity~state_flags
;                           putword {y},#playfield_entity~manager_slot_index
                            putword {y},#playfield_entity~custom_draw_sptr
                            putword {y},#playfield_entity~collision_list_entry_sptr
                            putword {y},#playfield_entity~move_accum_x
                            putword {y},#playfield_entity~move_accum_y
                            putword {y},#playfield_entity~speed_x
                            putword {y},#playfield_entity~speed_y
                            putword {y},#playfield_entity~characteristic_id
                            putword {y},#playfield_entity~personality
; Vibration task
                            putptr  {y},#playfield_entity~vibration_task_ptr
; Common tasks
                            putptr  {y},#playfield_entity~task1_ptr
                            putptr  {y},#playfield_entity~task2_ptr

; Caller section
                            putword {y},#playfield_entity~caller_sptr
                            putword {y},#playfield_entity~caller_priority
                            putword {y},#playfield_entity~mission_id
                            putword {y},#playfield_entity~mission_priority
                            static_assert_equal responder_type~count,2
                            putword {y},#playfield_entity~responder_quota+responder_type~worker
                            putword {y},#playfield_entity~responder_quota+responder_type~warrior
                            putword {y},#playfield_entity~responder_root_sptr

                            putword {y},#playfield_entity~next_sibling_sptr

; Set the distance to max
                            lda #$ffff
                            putword {y},#playfield_entity~caller_dist_x
                            putword {y},#playfield_entity~caller_dist_y


; We are using origin relative positioning for everything (a least I think so)
                            lda #sprite~info~origin_relative
                            putword {y},#playfield_entity~grentity+grlib_entity~sprite+sprite~info

; Ask the manager to do any further initialization
; Currently does nothing, so removing, so-as to not waste cycles
;                           jsl playfield_entity_manager_on_entity_construct

                            restoredatabank
exit                        anop
                            retkc
null_pointer                lda #playfield_entity_manager_error_null_pointer
                            jsl appdebug_set_last_error
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Construct a 'lite' entity.  This assumes that the framelib does not need
; to be cleared, and that this is not an entity that needs the caller/responder section.
;
; Parameters:
;   short pointer to the entity in Y
; Returns:
;  carry clear if no error
playfield_entity_construct_lite start seg_entity

                            debugtag 'construct_playfield_entity_lite'

                            begin_locals
work_area_size              end_locals

;                           sub ,work_area_size

                            tyx
; Set the databank to the entities
                            setdatabanktolabel entities_root

; Construct some of the embedded grlib_entity
; We are assuming that the framelib and sprite sections will be filled in with valid data elsewhere.

                            putzeroptr {x},#grlib_entity~parent_entity_ptr
                            putzeroptr {x},#grlib_entity~child_entity_ptr
                            putzeroptr {x},#grlib_entity~sibling_entity_ptr


;                           putzero {x},#playfield_entity~type
                            putzero {x},#playfield_entity~direction
                            putzero {x},#playfield_entity~desired_direction
                            putzero {x},#playfield_entity~frame_animation_timer
                            putzero {x},#playfield_entity~frame_animation_rate
                            putzero {x},#playfield_entity~rotation_flags
                            putzero {x},#playfield_entity~state_flags
                            putzero {x},#playfield_entity~custom_draw_sptr
                            putzero {x},#playfield_entity~collision_list_entry_sptr
                            putzero {x},#playfield_entity~move_accum_x
                            putzero {x},#playfield_entity~move_accum_y
;                           putzero {x},#playfield_entity~speed_x
;                           putzero {x},#playfield_entity~speed_y
;                           putzero {x},#playfield_entity~characteristic_id
                            putzero {x},#playfield_entity~personality
; Vibration task
                            putzeroptr {x},#playfield_entity~vibration_task_ptr
; Common tasks
                            putzeroptr {x},#playfield_entity~task1_ptr
                            putzeroptr {x},#playfield_entity~task2_ptr

; We are using origin relative positioning for everything (a least I think so)
                            lda #sprite~info~origin_relative
                            putword {x},#playfield_entity~grentity+grlib_entity~sprite+sprite~info

                            restoredatabank
                            clc
                            rtl
                            end

; -----------------------------------------------------------------------------
; Destruct an entity
; Parameters:
;  short pointer to entity in Y
playfield_entity_destruct   start seg_entity

                            debugtag 'destruct_playfield_entity'

                            tya
                            beq exit
                            phy
; Call gameplay code first.
                            jsl gameplay_entity_on_destruct

                            plx
                            jsl playfield_entity_delete_tasks

; Ask the manager to do uninitialization
; Currently does nothing, so removing, so-as to not waste cycles
;                           ldy <pThis
;                           jsl playfield_entity_manager_on_entity_destruct

; This also doesn't do anything, except some debug code.
;                           pushptrhigh #entities_root
;                           pushsword <spThis
;                           jsl grlib_entity_destruct

exit                        anop
                            rtl
                            end

; -----------------------------------------------------------------------------
; Destruct a 'lite' entity.  This has no caller / responder section or vibration
; Parameters:
;  short pointer to entity in Y
playfield_entity_destruct_lite start seg_entity

                            debugtag 'destruct_playfield_entity_lite'

                            tyx
                            beq exit

; Not calling any gameplay code, as there is nothing to be done for the lite version

                            jsl playfield_entity_delete_tasks

exit                        anop
                            rtl
                            end

; -----------------------------------------------------------------------------
; Suspend an entity, so it can be re-used.
; Parameters:
;  short pointer to entity in Y
playfield_entity_suspend    start seg_entity

                            debugtag 'suspend_playfield_entity'

; Currently, this does the exact same thing as playfield_entity_destruct
; This will remove responders and tasks, but everything else will stay in place.

                            tya
                            beq exit
                            phy
; Call gameplay code first.
                            jsl gameplay_entity_on_destruct

                            plx
                            jsl playfield_entity_delete_tasks

exit                        anop
                            rtl
                            end

; -----------------------------------------------------------------------------
; Construct an entity
; Parameters:
;   short pointer to the entity in Y
; Returns:
;  carry clear if no error
playfield_entity_reuse      start seg_entity
                            using playfield_entity_manager_errors

                            debugtag 'reuse_playfield_entity'

                            begin_locals
spThis                      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            tya
                            jeq null_pointer

                            sty <spThis
; Set the databank to the entities
                            setdatabanktolabel entities_root

; Construct the embedded grlib_entity
                            pushsword #entities_root|-16
                            phy
                            jsl grlib_entity_reuse

                            lda #0
                            ldy <spThis
; Hmm, this is getting kinda big, maybe just zero out the sizeof?  That would be slower though
; Might tbe best to just not zero out some values that the caller *should* be setting to valid values.
; (bad programming practice, but good for speed)
;                           putword {y},#playfield_entity~type
;                           putword {y},#playfield_entity~direction
;                           putword {y},#playfield_entity~desired_direction
;                           putword {y},#playfield_entity~turret_direction
;                           putword {y},#playfield_entity~target_angle
;                           putword {y},#playfield_entity~target_angle_change_avg
                            putword {y},#playfield_entity~frame_animation_timer
                            putword {y},#playfield_entity~frame_animation_rate
                            putword {y},#playfield_entity~rotation_flags
                            putword {y},#playfield_entity~state_flags
                            putword {y},#playfield_entity~custom_draw_sptr
                            putword {y},#playfield_entity~collision_list_entry_sptr
                            putword {y},#playfield_entity~move_accum_x
                            putword {y},#playfield_entity~move_accum_y
;                           putword {y},#playfield_entity~speed_x
;                           putword {y},#playfield_entity~speed_y
;                           putword {y},#playfield_entity~characteristic_id
;                           putword {y},#playfield_entity~personality
; Vibration
                            putptr  {y},#playfield_entity~vibration_task_ptr

                            putptr  {y},#playfield_entity~task1_ptr
                            putptr  {y},#playfield_entity~task2_ptr

; Caller section
;                           putword {y},#playfield_entity~caller_sptr
;                           putword {y},#playfield_entity~caller_priority
;                           putword {y},#playfield_entity~mission_id
;                           putword {y},#playfield_entity~mission_priority
;                           static_assert_equal responder_type~count,2
;                           putword {y},#playfield_entity~responder_quota+responder_type~worker
;                           putword {y},#playfield_entity~responder_quota+responder_type~warrior
;                           putword {y},#playfield_entity~responder_root_sptr

;                           putword {y},#playfield_entity~next_sibling_sptr

; Set the distance to max
                            lda #$ffff
                            putword {y},#playfield_entity~caller_dist_x
                            putword {y},#playfield_entity~caller_dist_y


; We are using origin relative positioning for everything (a least I think so)
;                           lda #sprite~info~origin_relative
;                           putword {y},#playfield_entity~grentity+grlib_entity~sprite+sprite~info

                            restoredatabank
exit                        anop
                            retkc
null_pointer                lda #playfield_entity_manager_error_null_pointer
                            jsl appdebug_set_last_error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Allocate a new playfield_entity object buffer.
; This allocates from the playfield_entity_manager's fixed pool
; It does NOT do any construction / initialization of the entity
;
; Parameters: none
; Returns:
; if carry clear, the pointer to the object, will not be null
; if carry set, null
playfield_entity_allocate   start seg_entity
                            using playfield_entity_manager_data

                            debugtag 'allocate_playfield_entity'

                            pushptr #global_playfield_entity_manager+playfield_entity_manager~pool
                            jsl fixed_buffer_pool_alloc
                            bcs allocation_error

                            rtl

allocation_error            anop
                            lda #0
                            tax
                            sec                                     ; error
                            rtl
                            end

; --------------------------------------------------------------------------------------------
; Allocate a new playfield_entity object.
; This allocates from the playfield_entity_manager's fixed pool
;
; Parameters: none
; Returns:
; if carry clear, the pointer to the object, will not be null
; if carry set, null
playfield_entity_new        start seg_entity
                            using playfield_entity_manager_data
; Define our work area data
                            begin_locals
result                      decl ptr                                ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'new_playfield_entity'

                            sub ,work_area_size

                            pushptr #global_playfield_entity_manager+playfield_entity_manager~pool
                            jsl fixed_buffer_pool_alloc
                            bcs allocation_error
                            putretptr <result

                            tay
                            jsl playfield_entity_construct
                            clc                                     ; no error
exit                        retkc 4:result
allocation_error            anop
                            clearptr <result
                            sec                                     ; error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Deallocate a playfield_entity object buffer
; This will NOT do any destruction / uninitialization, it will just free the buffer
;
; Parameters:
; x-reg                 - the playfield_entity short pointer.
; Returns:
; nothing
playfield_entity_deallocate start seg_entity
                            using playfield_entity_manager_data

                            debugtag 'deallocate_playfield_entity'

                            txy
                            beq exit

; It is safe to call this with a pointer the buffer does not own
                            pushptr #global_playfield_entity_manager+playfield_entity_manager~pool
                            pushptrhigh #entities_root
                            phx
                            jsl fixed_buffer_pool_free

exit                        rtl
                            end

; --------------------------------------------------------------------------------------------
; Deallocate a playfield_entity object.
; Note that this will destruct a playfield_entity that is not owned by the manager correctly.
;
; Deprecated, specific entity managers handle the delete directly, which is more efficient.
;
; Parameters:
; pThis             - the playfield_entity pointer.
; Returns:
; nothing
                            ago .skip
playfield_entity_delete     start seg_entity
                            using playfield_entity_manager_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'delete_playfield_entity'

                            sub (4:pThis),work_area_size

                            getword <pThis+2
                            beq exit

                            ldy <pThis
                            jsl playfield_entity_destruct

; It is safe to call this with a pointer the buffer does not own
                            pushptr #global_playfield_entity_manager+playfield_entity_manager~pool
                            pushptr <pThis
                            jsl fixed_buffer_pool_free

exit                        ret
                            end
.skip

; --------------------------------------------------------------------------------------------
; Setup the framelib collection for an entity and set its framelib_set
;
; Parameters:
; pThis             - the playfield_entity pointer.
; dwCollectionID    - the collection ID
; wSet              - the set ID
; wVariation        - the variation index
; Returns:
; nothing
playfield_entity_set_collection start seg_entity
                            using playfield_entity_manager_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'set_collection_playfield_entity'

                            sub (4:pThis,4:dwCollectionID,2:wSet,2:wVariation),work_area_size

                            lda <dwCollectionID
                            putlonglow [<pThis],#grlib_entity~frame+framelib_entity~collection_id
                            lda <dwCollectionID+2
                            putlonghigh [<pThis],#grlib_entity~frame+framelib_entity~collection_id

                            pushptr <pThis,#grlib_entity~frame
                            jsl framelib_entity_load_collection
                            bcs failed

; Cache all the pointers.  Note, even though I'm passing in an instance, what is getting 'built'
; is for shared data.  Re-visit adding this directly to framelib_entity_load_collection, so
; that it is only done once.
                            pushptr <pThis,#grlib_entity~frame
                            jsl framelib_entity_cache_collection
                            bcs failed

; Set the flag that some things have changed
                            getword [<pThis],#grlib_entity~changed
                            ora #grlib_entity~changed_frame_collection+grlib_entity~changed_frame_set
                            putword [<pThis],#same

; The set id.  This is 32 bits, the high word is the 'variation'
                            lda <wSet
                            putlonglow [<pThis],#grlib_entity~frame+framelib_entity~set
                            lda <wVariation
                            putlonghigh [<pThis],#grlib_entity~frame+framelib_entity~set

; Call update, to setup the framelib instance
                            ldx <pThis
                            setdatabanktoptr <pThis
                            jsl grlib_entity_update_framelib
                            restoredatabank

failed                      retkc
                            end

; --------------------------------------------------------------------------------------------
; Setup the framelib collection for an entity from a preloading framelib definition
;
; Parameters:
; spThis            - the playfield_entity short pointer.
; pPreload          - the preloaded collection (a framelib_entity)
; wSet              - the set ID
; wVariation        - the variation index
; Returns:
; nothing
playfield_entity_set_collection_from_preload start seg_entity
                            using playfield_entity_manager_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'set_collection_from_preload_playfield_entity'

                            sub (2:spThis,4:pPreload,2:wSet,2:wVariation),work_area_size

; Get the collection ID and the collection pointer, from the preloaded data
; This takes the place of the framelib_entity_load_collection and framelib_entity_cache_collection calls

                            ldx <spThis
                            getword [<pPreload],#framelib_entity~collection_id
                            putlonglow {x},>entities_root+grlib_entity~frame+framelib_entity~collection_id
                            getword [<pPreload],#framelib_entity~collection_id+2
                            putlonghigh {x},>entities_root+grlib_entity~frame+framelib_entity~collection_id

                            getword [<pPreload],#framelib_entity~collection_ptr
                            putlonglow {x},>entities_root+grlib_entity~frame+framelib_entity~collection_ptr
                            getword [<pPreload],#framelib_entity~collection_ptr+2
                            putlonghigh {x},>entities_root+grlib_entity~frame+framelib_entity~collection_ptr

; Make sure the instance level pointers are clear.
                            lda #0
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~set_sptr
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~list_sptr
                            putptr {x},>entities_root+grlib_entity~frame+framelib_entity~primary_frame_data_ptr
                            putptr {x},>entities_root+grlib_entity~frame+framelib_entity~secondary_frame_data_ptr

; Set the flags that some things have changed
                            getword {x},>entities_root+grlib_entity~changed
                            ora #grlib_entity~changed_frame_collection+grlib_entity~changed_frame_set
                            putword {x},>entities_root+grlib_entity~changed

; The set id.  This is 32 bits, the high word is the 'variation'
                            lda <wSet
                            putlonglow {x},>entities_root+grlib_entity~frame+framelib_entity~set
                            lda <wVariation
                            putlonghigh {x},>entities_root+grlib_entity~frame+framelib_entity~set

; Call update, to setup the framelib instance
                            ldx <spThis
                            setdatabanktolabel entities_root
                            jsl grlib_entity_update_framelib
                            restoredatabank

                            retkc
                            end

; --------------------------------------------------------------------------------------------
; Set the absolute direction of a playfield_entity object.
;
; Parameters:
; x-reg             - the playfield_entity short pointer.
; a-reg             - the direction, 0 - 31
; Returns:
; nothing
playfield_entity_set_direction start seg_entity
                            using playfield_entity_manager_data

                            begin_locals
wDirection                  decl word
work_area_size              end_locals

                            debugtag 'set_direction'

                            pha                         ; put into wDirection

;                           assert a,lt,#playfield_entity~direction_range

                            putword {x},>entities_root+playfield_entity~direction

                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_use_turret
                            beq not_turret
                            getword {x},>entities_root+playfield_entity~turret_direction
                            putword {s},#wDirection
not_turret                  anop
; Scale to the number of frame-lists.  This needs to be done more efficiently.
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~list_count
                            tay
                            getword {s},#wDirection
                            cpy #playfield_entity~direction_range
                            bge nodiv
                            cpy #(playfield_entity~direction_range/8)+1
                            blt div8
                            cpy #(playfield_entity~direction_range/4)+1
                            blt div4
                            cpy #(playfield_entity~direction_range/2)+1
                            blt div2
div8                        lsr a
div4                        lsr a
div2                        lsr a
nodiv                       anop
                            cmpword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~list
                            beq same
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~list
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~changed
                            ora #grlib_entity~changed_frame_list
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~changed
same                        anop

exit                        pla                         ; discard temporary
                            rtl
                            end


; --------------------------------------------------------------------------------------------
; Set the desired direction of a playfield_entity object.
; This will update the rotation flags to help keep the object turning in a consistent direction
; if the desired direction keeps changing.
;
; Parameters:
; x-reg             - the playfield_entity short pointer.
; a-reg             - the direction, 0 - 31
; Returns:
; nothing
playfield_entity_set_desired_direction start seg_entity
                            using playfield_entity_manager_data

                            begin_locals
wDirection                  decl word
wCurrentDesiredDirection    decl word
work_area_size              end_locals

                            debugtag 'set_desired_direction'

                            pha                     ; space for wCurrentDesiredDirection
                            pha                     ; wDirection

                            getword {x},>entities_root+playfield_entity~desired_direction
                            cmpword {s},#wDirection
                            beq exit                                        ; no change
                            putword {s},#wCurrentDesiredDirection
                            getword {s},#wDirection                         ; want direction
                            putword {x},>entities_root+playfield_entity~desired_direction
                            sec
                            sbcword {s},#wCurrentDesiredDirection
                            bcs greater
; The want direction is less than the current direction, we will have a negative number in a
                            negate a
                            cmp #16
                            beq exit                    ; exactly opposite, keep whatever rotation direction we were using.
                            bge clockwise               ; better to go clockwise
counter_clockwise           lda #playfield_entity~rotation_counter_clockwise
                            putword {x},>entities_root+playfield_entity~rotation_flags

exit                        tsc                         ; cleanup stack (this is faster the two pla opcodes)
                            clc
                            adc #4
                            tcs

                            rtl

clockwise                   anop
                            lda #playfield_entity~rotation_clockwise
                            putword {x},>entities_root+playfield_entity~rotation_flags
                            bra exit
greater                     anop
; The want direction is greater than the current direction
                            cmp #16
                            beq exit                    ; exactly opposite, keep whatever rotation direction we were using.
                            bge counter_clockwise       ; Better to go counter clock-wise

                            lda #playfield_entity~rotation_clockwise
                            putword {x},>entities_root+playfield_entity~rotation_flags

                            tsc                         ; cleanup stack (this is faster the two pla opcodes)
                            clc
                            adc #4
                            tcs

                            rtl

                            end

; --------------------------------------------------------------------------------------------
; Update the desired direction of a playfield_entity object.
;
; Parameters:
; X register             - the playfield_entity short pointer.
; Returns:
; nothing
; x-register will be preserved
playfield_entity_update_direction start seg_entity
                            using playfield_entity_manager_data

                            debugtag 'update_direction'

                            pha                             ; save some space for a temporary
wCurrentDirection           equ 1                           ; offset to the temporary on the stack

                            getword {x},>entities_root+playfield_entity~direction
                            putword {s},#wCurrentDirection
                            cmpword {x},>entities_root+playfield_entity~desired_direction
                            beq set_framelist               ; Direction not different, but check that the frame list is up-to-date

                            getword {x},>entities_root+playfield_entity~rotation_flags
                            bmi counter_clockwise
; Go clockwise to the desired direction
                            getword {s},#wCurrentDirection
                            inc a
                            and #playfield_entity~direction_range_mask
                            putword {x},>entities_root+playfield_entity~direction
                            putword {s},#wCurrentDirection
                            bra set_framelist

counter_clockwise           anop
                            getword {s},#wCurrentDirection
                            dec a
                            and #playfield_entity~direction_range_mask
                            putword {x},>entities_root+playfield_entity~direction
                            putword {s},#wCurrentDirection

set_framelist               anop
                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_use_turret
                            beq not_turret
                            getword {x},>entities_root+playfield_entity~turret_direction
                            putword {s},#wCurrentDirection
not_turret                  anop
; Scale to the number of frame-lists.  This needs to be done more efficiently.
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~list_count
                            cmp #2
                            blt no_directions                       ; 0 or 1, then just exit
                            tay
                            getword {s},#wCurrentDirection
                            cpy #playfield_entity~direction_range
                            bge nodiv
                            cpy #(playfield_entity~direction_range/16)+1
                            blt div16
                            cpy #(playfield_entity~direction_range/8)+1
                            blt div8
                            cpy #(playfield_entity~direction_range/4)+1
                            blt div4
                            cpy #(playfield_entity~direction_range/2)+1
                            blt div2
div16                       lsr a
div8                        lsr a
div4                        lsr a
div2                        lsr a
nodiv                       anop
                            cmpword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~list
                            beq same
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~list
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~changed
                            ora #grlib_entity~changed_frame_list
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~changed

same                        anop
no_directions               anop
exit                        pla                         ; discard temporary
                            rtl
                            end

; --------------------------------------------------------------------------------------------
; Update the desired direction of a playfield_entity object.
; This is the offscreen version, and it does not invalidate the framelib
; or update the turret direction.
; This is pretty small and could be inlined
;
; Parameters:
; X register             - the playfield_entity short pointer.
; Returns:
; nothing
; x-register will be preserved
playfield_entity_update_direction_offscreen start seg_entity
                            using playfield_entity_manager_data

                            debugtag 'update_direction_offscreen'

                            getword {x},>entities_root+playfield_entity~direction
                            tay
                            cmpword {x},>entities_root+playfield_entity~desired_direction
                            beq exit

                            getword {x},>entities_root+playfield_entity~rotation_flags
                            bmi counter_clockwise
; Go clockwise to the desired direction
                            tya
                            inc a
                            and #playfield_entity~direction_range_mask
                            putword {x},>entities_root+playfield_entity~direction
                            rtl

counter_clockwise           anop
                            tay
                            dec a
                            and #playfield_entity~direction_range_mask
                            putword {x},>entities_root+playfield_entity~direction
exit                        rtl

                            end

; --------------------------------------------------------------------------------------------
; Set the speed vector of a playfield_entity object, based on a direction value and a speed value
; This is essentially turning a polar vector into an x / y vector.
;
; Parameters:
; spThis            - the playfield_entity short pointer.
; wDirection        - the direction of the vector
; wSpeed            - the speed (indexed magnitude) of the vector
; Returns:
; nothing
playfield_entity_set_speed  start seg_entity
                            using playfield_entity_manager_data
                            using math_tables

                            begin_locals
pSpeedTable                 decl ptr
work_area_size              end_locals

                            debugtag 'set_speed'
                            debugtag 'playfield_entity'

                            sub (2:spThis,2:wDirection,2:wSpeed),work_area_size

; The speed, is the magnitude of the movement vector, get the appropriate rotated vector table
                            lda <wSpeed
                            bne has_speed
                            lda #0
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~speed_x
                            putword {x},>entities_root+playfield_entity~speed_y
                            ret

has_speed                   anop
                            dec a
                            asl a
                            asl a
                            tax
                            lda >math~dir_32_rot_to_mag_8_steps_32,x
                            sta <pSpeedTable
                            lda >math~dir_32_rot_to_mag_8_steps_32+2,x
                            sta <pSpeedTable+2
                            ldx <spThis
; Get the vector for the rotation.
                            lda <wDirection
                            asl a                                           ; 2 words per entry, x delta / y delta
                            asl a
                            tay
                            lda [<pSpeedTable],y                            ; x
                            putword {x},>entities_root+playfield_entity~speed_x
                            iny
                            iny
                            lda [<pSpeedTable],y                            ; y
                            putword {x},>entities_root+playfield_entity~speed_y
                            ret
                            end

; --------------------------------------------------------------------------------------------
; Set the speed vector of a playfield_entity object, based on a direction value and a speed value
; This is essentially turning a polar vector into an x / y vector.
;
; Parameters:
; pThis             - the playfield_entity pointer.
; wDirection        - the direction of the vector
; wSpeed            - the speed (indexed magnitude) of the vector
; wXAdjust          - amount to add to the x axis
; wYAdjust          - amount to add to the y axis
; Returns:
; nothing
playfield_entity_set_adjusted_speed start seg_entity
                            using playfield_entity_manager_data
                            using math_tables

                            begin_locals
pSpeedTable                 decl ptr
work_area_size              end_locals

                            debugtag 'set_adjusted_speed'

                            sub (2:spThis,2:wDirection,2:wSpeed,2:wXAdjust,2:wYAdjust),work_area_size

; The speed, is the magnitude of the movement vector, get the appropriate rotated vector table
                            lda <wSpeed
                            bne has_speed
                            lda <wXAdjust
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~speed_x
                            lda <wXAdjust
                            putword {x},>entities_root+playfield_entity~speed_y
                            ret

has_speed                   anop
                            dec a
                            asl a
                            asl a
                            tax
                            lda >math~dir_32_rot_to_mag_8_steps_32,x
                            sta <pSpeedTable
                            lda >math~dir_32_rot_to_mag_8_steps_32+2,x
                            sta <pSpeedTable+2
; Get the vector for the rotation.
                            lda <wDirection
                            asl a                                           ; 2 words per entry, x delta / y delta
                            asl a
                            tay
                            lda [<pSpeedTable],y                            ; x
                            clc
                            adc <wXAdjust                                   ; clamp this to max velocity?
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~speed_x
                            iny
                            iny
                            lda [<pSpeedTable],y                            ; y
                            clc
                            adc <wYAdjust
                            putword {x},>entities_root+playfield_entity~speed_y
                            ret
                            end


; --------------------------------------------------------------------------------------------
; Add to the speed vector of a playfield_entity object, based on a direction value and a speed value
; This is used to deflect the current speed vector.
;
; Parameters:
; pThis             - the playfield_entity pointer.
; wDirection        - the direction of the vector
; wSpeed            - the speed (indexed magnitude) of the vector
; wMaxPosSpeed      - the max positive speed for either axis.
; Returns:
; nothing
playfield_entity_add_speed  start seg_entity
                            using playfield_entity_manager_data
                            using math_tables

                            begin_locals
wMagnitude                  decl word
wTemp                       decl word
wAngleX                     decl word
wAngleY                     decl word
wDeltaAngleX                decl word
wDeltaAngleY                decl word
wMaxNegSpeed                decl word
work_area_size              end_locals

                            debugtag 'add_speed'

                            sub (2:spThis,2:wDirection,2:wSpeed,2:wMaxPosSpeed),work_area_size

; Get the negative speed max.
; Note, I really want the vector of the speed clamped, not each axis.
; This would be a slower calculation, but this function is only used with the player, so maybe not too bad?
                            lda <wMaxPosSpeed
                            negate a
                            sta <wMaxNegSpeed

; The speed, is the magnitude of the movement vector, get the appropriate rotated vector table
                            lda <wSpeed
                            bne has_speed
                            lda #0
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~speed_x
                            putword {x},>entities_root+playfield_entity~speed_y
                            ret

has_speed                   anop

                            asl a
                            tax
                            lda >math~speed_index_to_magnitude,x                ; Convert the speed index to a fp16 magnitude
                            sta <wMagnitude

; Convert the direction to an angle.  Note that we are getting a magnitude 2 angle.
; This is because we will be getting a delta, and we want the result to be non-zero
; if we are adding to the direction we are already going in.
                            lda <wDirection
                            asl a
                            asl a
                            tax
; Use the direction to vector table, that returns a vector of magnitude 2.0 for the direction
                            lda >math~dir_32_rot_mag_8_step_8_of_32,x
                            sta <wAngleX
                            lda >math~dir_32_rot_mag_8_step_8_of_32+2,x
                            sta <wAngleY

; Get the current angle of travel from the speed.  Note, if we are not moving, this will not be a correct value, but it is ok, as we will quickly have a valid value.
                            ldx <spThis
                            getword {x},>entities_root+playfield_entity~speed_x
                            tay
                            getword {x},>entities_root+playfield_entity~speed_y
                            tyx
                            jsl math~vec2_angle
; (A) has the current angle of travel.
                            asl a
                            tax
                            lda <wAngleX                                        ; desired angle, x 2
                            sec
                            sbc >math~sin_256,x
                            sta <wDeltaAngleX                                   ; delta
                            lda <wAngleY
                            sec
                            sbc >math~cos_256,x
                            sta <wDeltaAngleY

; Scale it.  This is expensive, and currently, the input magnitude is always the same.  Assume that, and use lookup table(s)?
                            ldx <wDeltaAngleX
                            lda <wMagnitude         ; scale it (fp16 x fp16)
                            jsl math~mul2r4
; Convert back to fp16, this is doing a >> 8 on the 32 bit result
                            xba
                            and #$00ff
                            sta <wTemp
                            txa
                            xba
                            and #$ff00
                            ora <wTemp
                            asr 1                                               ; compensate for using the magnitude 2 table at the start
                            clc
                            ldx <spThis
                            adcword {x},>entities_root+playfield_entity~speed_x
; clamp
                            bmi neg_x
                            cmp <wMaxPosSpeed
                            blt ok_x
                            lda <wMaxPosSpeed
                            bra ok_x
neg_x                       cmp <wMaxNegSpeed
                            bge ok_x
                            lda <wMaxNegSpeed
ok_x                        putword {x},>entities_root+playfield_entity~speed_x
; Get the Y angle component
                            ldx <wDeltaAngleY
                            lda <wMagnitude
                            jsl math~mul2r4
; Convert back to fp16, this is doing a >> 8 on the 32 bit result
                            xba
                            and #$00ff
                            sta <wTemp
                            txa
                            xba
                            and #$ff00
                            ora <wTemp
                            asr 1                                               ; compensate for using the magnitude 2 table at the start
                            clc
                            ldx <spThis
                            adcword {x},>entities_root+playfield_entity~speed_y
; clamp
                            bmi neg_y
                            cmp <wMaxPosSpeed
                            blt ok_y
                            lda <wMaxPosSpeed
                            bra ok_y
neg_y                       cmp <wMaxNegSpeed
                            bge ok_y
                            lda <wMaxNegSpeed
ok_y                        putword {x},>entities_root+playfield_entity~speed_y
                            ret
                            end

; --------------------------------------------------------------------------------------------
; Update the position of a playfield_entity object, based on the speed values
; If coordinate wrapping is on, then only the speed of the object is added to its position
; and the positon will wrap the postion at the edge of the playfield.
; If coordiate wrapping is off, then both the speed of the object and the speed of the view
; is added and if the object is outside the defined 'sector' extents, the objects
; exit_sector handler is called.
;
; Note that this function is 'patched', based on the FPS.
; If the FPS is 30, the speed is doubled.
;
; Parameters:
; X register             - the playfield_entity short pointer.
; Returns:
; nothing
; x-register will be preserved on exit
playfield_entity_update_position start seg_entity
                            using math_tables
                            using appdata
                            using gameplay_level_data
                            using gameplay_entity_data
                            using playfield_manager_data
                            using playfield_entity_manager_data

                            debugtag 'update_position'

; Don't update the positions of child entities
; Changed to require the caller to do this test, since only Sinistar has child pieces.
;                           getword {x},>entities_root+playfield_entity~grentity+grlib_entity~parent_entity_ptr+2
;                           beq is_parent
;                           brk $01
;                           rtl

is_parent                   anop
; No coordinate wrapping.  This supports applying the current view speed to the entity
; It also supports entities getting removed if they go too far from the origin (0,0)
                            getword {x},>entities_root+playfield_entity~speed_x
playfield_entity~update_speed_modifier_patch_x entry
                            nop
                            clc
playfield_entity~view_speed_patch_x entry
                            adc #$0000                                      ; patched to be >playfield_manager~view_speed_x
                            beq do_y                                        ; how often would this actually be 0, everything is moving all the time.  Would save 2 cycles if removed!
                            clc                                             ; can we get away with not doing this?
                            adcword {x},>entities_root+playfield_entity~move_accum_x      ; add to the accumulator, which contains any left over fractional value from the last move
                            tay
                            bmi neg_x_add
; Adding a positive value to X
                            and #$00ff                                      ; save the fractional part for next time
                            putword {x},>entities_root+playfield_entity~move_accum_x
                            tya
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
; Check to see if it is off the right.
                            cmp #gameplay_playfield_bounds_right            ; gameplay_level~playfield+playfield~bounds+grlib_rect~right
                            bslt do_y
; Do the exit-sector code.
                            bra do_exit_sector

; Adding a negative value to X
neg_x_add                   and #$00ff                                      ; save the fractional part for next time
; Setup rounding correcion. -0.5 is $ff80, and -1 is $ff00, so if there is any factional part
; we want the integer conversion to round toward 0, not away.  Use the carry flag and an add of 0, to adjust the value
                            clc
                            beq neg_x_no_round_correction
                            sec
                            ora #$ff00                                      ; sign extend, though not if 0, there is no -0
neg_x_no_round_correction   anop
                            putword {x},>entities_root+playfield_entity~move_accum_x
                            tya
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            adc #$0000                                      ; rounding correction
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            cmp #gameplay_playfield_bounds_left             ; gameplay_level~playfield+playfield~bounds+grlib_rect~left
                            bslt do_exit_sector                             ; Do the exit-sector code

do_y                        anop
                            getword {x},>entities_root+playfield_entity~speed_y
playfield_entity~update_speed_modifier_patch_y entry
                            nop
                            clc
playfield_entity~view_speed_patch_y entry
                            adc #$0000                                      ; patched to be >playfield_manager~view_speed_y
                            beq next
                            clc
                            adcword {x},>entities_root+playfield_entity~move_accum_y      ; add to the accumulator, which contains any left over fractional value from the last move
                            tay
                            bmi neg_y_add                                   ; have to handle negative numbers differently, because we will need to sign extend
; Adding a positive value to Y
                            and #$00ff                                      ; save the fractional part for next time
                            putword {x},>entities_root+playfield_entity~move_accum_y
                            tya
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            cmp #gameplay_playfield_bounds_bottom           ; gameplay_level~playfield+playfield~bounds+grlib_rect~bottom
                            bsge do_exit_sector
                            rtl

; Adding a negative value to Y
neg_y_add                   and #$00ff                                      ; save the fractional part for next time
; Setup rounding correcion. The factional part is always postive, so -0.5 is $ff80, and -1 is $ff00, so if there is any factional part
; we want the integer conversion to round toward 0, not away.  Use the carry flag and an add of 0, to adjust the value
                            clc
                            beq neg_y_no_round_correction
                            sec
                            ora #$ff00                                      ; sign extend, though not if 0, there is no -0
neg_y_no_round_correction   anop
                            putword {x},>entities_root+playfield_entity~move_accum_y
                            tya
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            adc #$0000                                      ; rounding correction
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            cmp #gameplay_playfield_bounds_top              ; gameplay_level~playfield+playfield~bounds+grlib_rect~top
                            bslt do_exit_sector                             ; Do the exit-sector code

next                        anop
                            rtl

do_exit_sector              anop

                            phx                     ; saving x so caller can assume it is preserved

; Patch the address in.  Note, doing this in an overlapping manner, so I don't have to change the acc size.
                            txy
                            getword {x},>entities_root+playfield_entity~characteristic_id
                            tax

                            lda >characteristics_table+gameplay_entity_characteristic~leave_sector_func_ptr+1,x     ; 6
                            beq no_callback                 ; if this is 0, then its null                           ; 2-3
                            sta >patch_func+2                                                                       ; 6
                            lda >characteristics_table+gameplay_entity_characteristic~leave_sector_func_ptr,x       ; 6
                            sta >patch_func+1                                                                       ; 6
; 8 for the jsl, 34 cycles for non-zero.  Could save 1 cycle using the rtl-style jump table.  One.

; short pointer to the entity is in Y

patch_func                  jsl $ffffff
no_callback                 plx
                            rtl

                            end

; --------------------------------------------------------------------------------------------
; This is the 'off-screen' version of the update position code.
; This is slightly faster, because it does not deal with the move accumulator.
; This does mean that speeds below 1.0 will not move the entity.
;
; Both the speed of the object and the speed of the view is added and
; if the object is outside the defined 'sector' extents, the objects
; exit_sector handler is called.
;
; Note that this function is 'patched', based on the FPS.
; If the FPS is 30, the speed is doubled.
;
; Parameters:
; X register             - the playfield_entity short pointer.
; Returns:
; nothing
; x-register will be preserved on exit
playfield_entity_update_position_offscreen start seg_entity
                            using math_tables
                            using appdata
                            using gameplay_level_data
                            using gameplay_entity_data
                            using playfield_manager_data
                            using playfield_entity_manager_data

                            debugtag 'update_position_offscreen'

; No coordinate wrapping.  This supports applying the current view speed to the entity
; It also supports entities getting removed if they go too far from the origin (0,0)
                            getword {x},>entities_root+playfield_entity~speed_x
playfield_entity~update_speed_modifier_patch_os_x entry
                            nop
                            clc
playfield_entity~view_speed_patch_os_x entry
                            adc #$0000                                      ; patched to be >playfield_manager~view_speed_x
                            beq do_y                                        ; how often would this actually be 0, everything is moving all the time.  Would save 2 cycles if removed!
                            bmi neg_x_add
; Adding a positive value to X
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
; Check to see if it is off the right.
                            cmp #gameplay_playfield_bounds_right            ; gameplay_level~playfield+playfield~bounds+grlib_rect~right
                            bslt do_y
; Do the exit-sector code.
                            bra do_exit_sector

; Adding a negative value to X
neg_x_add                   anop
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            cmp #gameplay_playfield_bounds_left             ; gameplay_level~playfield+playfield~bounds+grlib_rect~left
                            bslt do_exit_sector                             ; Do the exit-sector code

do_y                        anop
                            getword {x},>entities_root+playfield_entity~speed_y
playfield_entity~update_speed_modifier_patch_os_y entry
                            nop
                            clc
playfield_entity~view_speed_patch_os_y entry
                            adc #$0000                                      ; patched to be >playfield_manager~view_speed_y
                            beq next
                            bmi neg_y_add                                   ; have to handle negative numbers differently, because we will need to sign extend
; Adding a positive value to Y
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            cmp #gameplay_playfield_bounds_bottom           ; gameplay_level~playfield+playfield~bounds+grlib_rect~bottom
                            bsge do_exit_sector
                            rtl

; Adding a negative value to Y
neg_y_add                   anop
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            cmp #gameplay_playfield_bounds_top              ; gameplay_level~playfield+playfield~bounds+grlib_rect~top
                            bslt do_exit_sector                             ; Do the exit-sector code

next                        anop
                            rtl

do_exit_sector              anop

                            phx                     ; saving x so caller can assume it is preserved

; Patch the address in.  Note, doing this in an overlapping manner, so I don't have to change the acc size.
                            txy
                            getword {x},>entities_root+playfield_entity~characteristic_id
                            tax

                            lda >characteristics_table+gameplay_entity_characteristic~leave_sector_func_ptr+1,x     ; 6
                            beq no_callback                 ; if this is 0, then its null                           ; 2-3
                            sta >patch_func+2                                                                       ; 6
                            lda >characteristics_table+gameplay_entity_characteristic~leave_sector_func_ptr,x       ; 6
                            sta >patch_func+1                                                                       ; 6
; 8 for the jsl, 34 cycles for non-zero.  Could save 1 cycle using the rtl-style jump table.  One.

; short pointer to the entity is in Y
patch_func                  jsl $ffffff

no_callback                 anop
                            plx
                            rtl

                            end

; --------------------------------------------------------------------------------------------
; Given a distance from a source, to a target, find a table entry, that describes
; what velocity we would like to be going.
; Note, the distance is signed and the table can be setup, so that the returned value is a
; negative velocity, so that the source backs off from the center of the target.
;
; Parameters:
; pTable            - pointer to the velocity table
; wDistanceX        - the X signed distance.
; wDistanceY        - the X signed distance.
; spDPOutput        - an absolute address in bank 0, to put the results
;                     The output struct is:
;                       wVelocityX
;                       wAccelerationX
;                       wVelocityY
;                       wAccelerationY

; Returns:
; Desired velocity in A, Acceleration function in X
playfield_get_to_target_velocity start seg_entity
                            using playfield_entity_manager_data
                            using math_tables
                            using appdata

                            begin_locals
wWasNegative                decl word
work_area_size              end_locals

                            debugtag 'get_to_target_velocity'

                            sub (4:pTable,2:wDistanceX,2:wDistanceY,2:spDPOutput),work_area_size

; The output struct
                            begin_struct
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
                            end_struct

; Setting the bank to the speed table location
                            setdatabanktoptr <pTable            ; 18

                            stz <wWasNegative
                            lda <wDistanceX                     ; is the input a negative distance?
                            bpl pos_x
                            negate a
                            dec <wWasNegative

pos_x                       anop
                            ldy <pTable                         ; y will have the short pointer to the table
; Unrolling the loop.  max 10 entries in a speed table
                            speed_table_find_velocity 10,found_x
                            assert_brk 'spto1'

found_x                     pha                                 ; save the value
                            bit <wWasNegative                   ; was the input a negative distance?
                            bpl was_pos_x
                            negate a                            ; velocity needs to be negative
was_pos_x                   anop
                            ldx <spDPOutput
                            sta >wVelocityX,x                   ; set the output velocity
                            pla
; Loop again, to get the correct acceleration routine.
; I am unsure why the original code did this.  It is essentially seeing if an earlier entry, had a velocity
; that was less, and uses its acceleration.  Why not just set the entry's acceleration function to be the same?
; I do not see any of their tables have that kind of ordering, they all have progressively lower velocity values
; so this search is just going to find the same entry.

                            speed_table_find_acceleration 10,found2_x
                            assert_brk 'spto2'

found2_x                    sta >wAccelerationX,x               ; set the output acceleration

; Do the Y component

                            stz <wWasNegative
                            lda <wDistanceY                     ; is the input a negative distance?
                            bpl pos_y
                            negate a
                            dec <wWasNegative

pos_y                       anop
;
                            speed_table_find_velocity 10,found_y
                            assert_brk 'spto3'

found_y                     pha                                 ; save the value
                            bit <wWasNegative                   ; was the input a negative distance?
                            bpl was_pos_y
                            negate a                            ; velocity needs to be negative
was_pos_y                   anop
                            sta >wVelocityY,x                   ; set the output velocity
                            pla

; Loop again, see above for info
                            speed_table_find_acceleration 10,found2_y
                            assert_brk 'spto4'

found2_y                    sta >wAccelerationY,x               ; set the output acceleration

                            restoredatabank
                            ret
                            end

; --------------------------------------------------------------------------------------------
; Apply the velocity to a target.
; This will adjust the velocity, based on the target's velocity
; Maybe this second part should be broken out into a separate function?
; It would make it so the target and the max velocity didn't have to be passed in.
;
; Once the real desired velocity it calculated, based on the target velocity
; the delta between that and the current velocity is calculated, and then the
; acceleration function is applied.  TBH, it is really a acceleration damping
; function.
;   0 means no damping, the desired velocity will be applied to the entity.
;   1 means half the delta of the velocity will be applied
;   2 means 1/4, and so on, to 7.
;
; Parameters:
; spThis            - the playfield_entity short pointer.
; wTargetVelocityX  - the target's velocity
; wTargetVelocityY  - the target's velocity
; wDesiredVelocityX - desired velocity
; wDesiredVelocityY - desired velocity
; wAccelerationX    - index of the acceleration function to use for X
; wAccelerationY    - index of the acceleration function to use for Y
; wMaxPosVelocity   - max velocity (positive) of the source.
; Returns:
; nothing
playfield_entity_update_to_target_velocity start seg_entity
                            using playfield_entity_manager_data
                            using math_tables
                            using appdata

                            begin_locals
wTargetVelocity             decl word
wMaxNegVelocity             decl word
wVelocityChanged            decl word
work_area_size              end_locals

                            debugtag 'update_to_target_velocity'
                            debugtag 'playfield_entity'

                            sub (2:spThis,2:wTargetVelocityX,2:wTargetVelocityY,2:wDesiredVelocityX,2:wDesiredVelocityY,2:wAccelerationX,2:wAccelerationY,2:wMaxPosVelocity),work_area_size

                            ldx <spThis

                            lda <wMaxPosVelocity
                            negate a
                            sta <wMaxNegVelocity
                            stz <wVelocityChanged

; Do X
; The target velocity sign is compared and if the source is going in the same direction
; the target velocity is added to the desired velocity.  We don't want it to be immediate,
; so the target velocity is shifted down.
; Note, in the original, only a fraction of the target velocity was used, and a majority of the value
; was the screen velocity.  This seemed to tie the chase to the player as a target since the player drives
; the screen velocity.  This works ok, and might be better for chasing the player, but odd if the chased
; object is not the player, and also, was not great if the chaser was the player, because it would feedback.
; I'm probably missing something...
;
                            lda <wTargetVelocityX
                            asr_nt 2
                            sta <wTargetVelocity

                            lda <wDesiredVelocityX
                            jsr chase
                            shiftleft 1                                                 ; velocties from the tables are off by x2 from what I want

; Get the difference.
                            sec
                            sbcword {x},>entities_root+playfield_entity~speed_x
                            beq same_x
; Apply the acceleration routine to the difference

                            asl <wAccelerationX                                          ; Maybe have the indices always be x 2, so I don't have to do this?
                            ldx <wAccelerationX
                            jsr (acceleration_functions,x)
; Add it to the velocity
                            ora #1                                                       ; make sure we have something.

                            ldx <spThis
                            clc
                            adcword {x},>entities_root+playfield_entity~speed_x
; Clamp to max
                            bmi clamp_x_neg
                            cmp <wMaxPosVelocity
                            blt clamp_x_ok
                            lda <wMaxPosVelocity
                            bra clamp_x_ok
clamp_x_neg                 cmp <wMaxNegVelocity
                            bge clamp_x_ok                                              ; unsigned compare, so bigger is ok
                            lda <wMaxNegVelocity
clamp_x_ok                  anop
                            putword {x},>entities_root+playfield_entity~speed_x
                            sta <wDesiredVelocityX
                            inc <wVelocityChanged

same_x                      anop
; Do Y
                            lda <wTargetVelocityY
                            asr_nt 2
                            sta <wTargetVelocity

                            lda <wDesiredVelocityY
                            jsr chase
                            shiftleft 1                                                 ; velocties from the tables are off by x2 from what I want
; Get the difference
                            sec
                            sbcword {x},>entities_root+playfield_entity~speed_y
                            beq same_y

; Apply the acceleration routine to the difference

                            asl <wAccelerationY                                          ; Maybe have the indices always be x 2, so I don't have to do this?
                            ldx <wAccelerationY
                            jsr (acceleration_functions,x)

; Add it to the velocity
                            ora #1                                                       ; make sure we have something.
                            ldx <spThis
                            clc
                            adcword {x},>entities_root+playfield_entity~speed_y
; Clamp to max
                            bmi clamp_y_neg
                            cmp <wMaxPosVelocity
                            blt clamp_y_ok
                            lda <wMaxPosVelocity
                            bra clamp_y_ok
clamp_y_neg                 cmp <wMaxNegVelocity
                            bge clamp_y_ok                                              ; unsigned compare, so bigger is ok
                            lda <wMaxNegVelocity
clamp_y_ok                  anop
                            putword {x},>entities_root+playfield_entity~speed_y
                            sta <wDesiredVelocityY
                            inc <wVelocityChanged

same_y                      anop

                            lda <wVelocityChanged
                            beq both_same
; While we have the values, adjust the heading.  Might just want to return a 'has changed' flag, and let the caller decide
                            ldx <wDesiredVelocityX
                            lda <wDesiredVelocityY
                            jsl math~vec2_angle
                            shiftright 3                                                ; only want 0-31
                            ldx <spThis
                            jsl playfield_entity_set_desired_direction

both_same                   ret

; If the source and the target have the same sign for their velocities, i.e. moving in the
; same direction, then have the source, add the target's velocity, so it can catch up quicker.
; The velocity will be capped to the source's max velocity.
chase                       anop
                            bmi source_negative
                            bit <wTargetVelocity
                            bmi no_change               ; source positive, dest negative, no change.
; both postive
                            clc
                            adc <wTargetVelocity
                            cmp <wMaxPosVelocity
                            blt changed_velocity
                            lda <wMaxPosVelocity
changed_velocity            anop
no_change                   rts
source_negative             anop
                            bit <wTargetVelocity
                            bpl no_change               ; source negative, dest positive, no change
                            clc
                            adc <wTargetVelocity
                            cmp <wMaxNegVelocity
                            bge changed_velocity        ; signed compare of two negative numbers, so bigger is less.
                            lda <wMaxNegVelocity
                            rts

                            end

; --------------------------------------------------------------------------------------------
; Given a source and target entity, get the distance (Manhattan) to the target.
; This will always give the shortest relative distance to the target,
; taking into account the coordinate wrapping, if coordinate wrapping is on.
; Note, if coordinate wrapping is not on, it would probably be better to just
; inline this.
;
; Note, as-is, not using coordinate wrapping, this is depricated in favor of
; just using the inline_entity_push_target_distance macro, as this is just
; a couple of subtracts, and it is not worth having such high overhead
; of the funciton call.
;
; Parameters:
; pThis             - the source playfield_entity pointer.
; pTarget           - the target playfield_entity pointer.
; Returns:
;   X distance in A, Y distance in X.
;   The distance values are relative (signed)
;   Note this is a Manhattan distance to the location.
;
playfield_entity_get_target_distance start seg_entity
                            using playfield_entity_manager_data
                            using playfield_manager_data
                            using math_tables
                            using appdata

                            begin_locals
wDeltaX                     decl word
wDeltaY                     decl word
work_area_size              end_locals

                            debugtag 'get_target_distance'
                            debugtag 'playfield_entity'

                            sub (4:pThis,4:pTarget),work_area_size

                            getword [<pTarget],#playfield_entity~grentity+grlib_entity~x
                            sec
                            sbc [<pThis],y
ok_x                        sta <wDeltaX

; Y
                            getword [<pTarget],#playfield_entity~grentity+grlib_entity~y
                            sec
                            sbc [<pThis],y
ok_y                        sta <wDeltaY

                            ret 4:wDeltaX     ; Return wDeltaX and wDeltaY
                            end

; --------------------------------------------------------------------------------------------
; Given a source location (absolute) and a target location (absolute),
; get the distance (Manhattan) to the target.
; This will always give the shortest relative distance to the target,
; taking into account the coordinate wrapping, if coordinate wrapping is on.
; Note, if coordinate wrapping is off, it is probably best to just inline the math.
;
; Parameters:
; wSourceX
; wSourceY
; wTargetX
; wTargetY
; Returns:
;   X distance in A, Y distance in X.
;   The distance values are relative (signed)
;   Note this is a Manhattan distance to the location.
;
playfield_get_target_distance start seg_entity
                            using playfield_entity_manager_data
                            using playfield_manager_data
                            using math_tables
                            using appdata

                            begin_locals
wDeltaX                     decl word
wDeltaY                     decl word
work_area_size              end_locals

                            debugtag 'get_target_distance'
                            debugtag 'playfield_entity'

                            sub (2:wSourceX,2:wSourceY,2:wTargetX,2:wTargetY),work_area_size

                            lda <wTargetX
                            sec
                            sbc <wSourceX
ok_x                        sta <wDeltaX

; Y
                            lda <wTargetY
                            sec
                            sbc <wSourceY
ok_y                        sta <wDeltaY

                            ret 4:wDeltaX     ; Return wDeltaX and wDeltaY
                            end

; --------------------------------------------------------------------------------------------
; Given a source and target entity, get the distance (Manhattan) to an orbit point on the target.
;
; Important note, regarding this function, vs. what was in the original
; The original did this calculation for each component separately, getlodistance and getsodistance
; Also, the original scales the distance by a factor of 16.  I think this was possibly because it
; wanted to have a speculative value, since the calculation is usually done at a slower tick rate
; usually on tasklist4.  This function does do the speculative distance of the target, it uses the
; target location as-is.  This speeds things up a bit.
; The other thing to note is that the way it calculated the tangent distance
; with the orbital factor, that worked out to be 128 times the input value.
;
; This function simulates that x 16 output of the original, though it just shifts the final result
; rather than shifting all the components as it is doing the calculation.

; Parameters:
; wSourceX          - the source x location
; wSourceY          - the source y location
; wTargetX          - the target x point to orbit
; wTargetY          - the target y point to orbit
; wFactor           - the min distance to orbit from the center of the target.
;                     This is in standard coordinates, i.e. pixels.  Be aware that factor values from
;                     the original source were in scanner coords, i.e. 1:4 ratio.
; wMultiplier       - the multiplier to the distance factor.  Used to pick random orbit distances.
;                     This currently, only checks the sign of the input to determine CW vs. CCW targeting.
; Returns:
;   X distance in A, Y distance in X.
;   Note this is a Manhattan distance to the location.
playfield_get_orbital_distance start seg_entity
                            using playfield_entity_manager_data
                            using math_tables
                            using appdata

                            begin_locals
wDestX                      decl word
wDestY                      decl word
wAnglex2                    decl word
wQuadrant                   decl word
work_area_size              end_locals

                            debugtag 'get_orbital_distance'
                            debugtag 'playfield'

                            sub (2:wSourceX,2:wSourceY,2:wTargetX,2:wTargetY,2:wFactor,2:wMultiplier),work_area_size

; Get the angle, from the source, to the target
; First, turn the coordinates, into a delta
                            lda <wTargetX
                            sec
                            sbc <wSourceX
                            tax
                            lda <wTargetY
                            sec
                            sbc wSourceY
                            jsl math~vec2_angle_quadrant
                            stx <wQuadrant
                            asl a
                            sta <wAnglex2
                            tax
; Find the X component distance
; Multiply the adjustment by the cos.  This pushes the x distance away, tangent to the target
; Note, the original used a signed SIN/COS function, and did a signed multiply
; This is an unsigned SIN/COS table, with a full 0-255 range for the quadrant.  We will do the sign later.
                            lda >math~cos_64,x
                            inline~umul1r2 <wFactor,Y
; The original just used the result, essentially making the result a max of 128 * factor
; However, this was added to an already scaled (* 16) source and target.
; We are not doing the scaling until the end, so we must scale this tangent down.
                            shiftright 1+3
                            ldx <wQuadrant
                            beq cos_neg
                            cpx #math~quadrant_4*2          ; math~vec2_angle_quadrant returns quadrant x 2
                            bne cos_pos
cos_neg                     negate a
cos_pos                     ldx <wMultiplier
                            bpl cos_multi_pos
                            negate a
cos_multi_pos               anop
; Add to X
                            clc
                            adc <wTargetX
; Subtract from the source, to get the (Manhattan) distance.
                            sec
                            sbc <wSourceX
                            shiftleft 4                     ; Match the original codes result range, which is x 16
                            sta <wDestX

; Do the same for the Y component.  Again, tangent to the target, but also flipped.
; The goal is to get a distance so that the source never reaches it, and appears to orbit the 'real' target.
                            ldx <wAnglex2
                            lda >math~sin_64,x
                            inline~umul1r2 <wFactor,Y
                            shiftright 1+3

                            ldx <wQuadrant
                            cpx #math~quadrant_3*2
                            bge sin_neg             ; negative sin quadrant, however, since we wanted to multiple by a negative adjust, the value is positive
                            negate a

sin_neg                     ldx <wMultiplier
                            bpl sin_multi_pos
                            negate a
sin_multi_pos               anop
                            clc
                            adc <wTargetY
                            sec
                            sbc <wSourceY
                            shiftleft 4                     ; Match the original codes result range, which is x 16
                            sta <wDestY

                            ret 4:wDestX     ; Return wDestX and wDestY
                            end

; -----------------------------------------------------------------------------
; Given a source and target entity, get the distance (Manhattan) to an orbit point on the target.
;
; This version perserves the x 16 scaling along with the speculation of where the target will
; be in 8 ticks, based on the input target velocity. i.e. It is more like the original functions
;
; The other thing to note is that the way it calculated the tangent distance
; with the orbital factor, that worked out to be 128 times the input value.
;
; Parameters:
; wSourceX          - the source x location
; wSourceY          - the source y location
; wTargetX          - the target x point to orbit
; wTargetY          - the target y point to orbit
; wTargetVelocityX  - the target x velocity to add to the input target X
; wTargetVelocityY  - the target y velocity to add to the input target Y
; wFactor           - the min distance to orbit from the center of the target.
;                     This is in standard coordinates, i.e. pixels.  Be aware that factor values from
;                     the original source were in scanner coords, i.e. 1:4 ratio.
; wMultiplier       - the multiplier to the distance factor.  Used to pick random orbit distances.
;                     This currently, only checks the sign of the input to determine CW vs. CCW targeting.
; Returns:
;   X distance in A, Y distance in X.
;   Note this is a Manhattan distance to the location.

; A function, more in line with what the original did, in that it uses
; the target velocity to guess where the target will be in about 2 seconds.
playfield_get_orbital_distance_speculative start seg_entity
                            using playfield_entity_manager_data
                            using math_tables
                            using appdata

                            begin_locals
wDestX                      decl word
wDestY                      decl word
wAnglex2                    decl word
wQuadrant                   decl word
wTargetX16                  decl word
wTargetY16                  decl word
work_area_size              end_locals

                            debugtag 'get_orbital_distance2'
                            debugtag 'playfield'

                            sub (2:wSourceX,2:wSourceY,2:wTargetX,2:wTargetY,2:wTargetVelocityX,2:wTargetVelocityY,2:wFactor,2:wMultiplier),work_area_size

                            lda <wTargetX
                            shiftleft 4
                            sta <wTargetX16

                            lda <wTargetY
                            shiftleft 4
                            sta <wTargetY16

; Get the angle, from the source, to the target
; First, turn the coordinates, into a delta
                            lda <wTargetX
                            sec
                            sbc <wSourceX
                            tax
                            lda <wTargetY
                            sec
                            sbc wSourceY
                            jsl math~vec2_angle_quadrant
                            stx <wQuadrant
                            asl a
                            sta <wAnglex2
                            tax
; Find the X component distance
; Multiply the adjustment by the cos.  This pushes the x distance away, tangent to the target
                            lda >math~cos_64,x
                            inline~umul1r2 <wFactor,Y
; Original kept the raw value, though their table is signed, where ours is not, so shift down 1
                            lsr a
                            ldx <wQuadrant
                            beq cos_neg
                            cpx #math~quadrant_4*2          ; math~vec2_angle_quadrant returns quadrant x 2
                            bne cos_pos
cos_neg                     negate a
cos_pos                     ldx <wMultiplier
                            bpl cos_multi_pos
                            negate a
cos_multi_pos               anop
; Add to X
                            clc
                            adc <wTargetX16
                            sta <wTargetX16

; Shift up the source to match the target
                            lda <wSourceX
                            shiftleft 4
                            sta <wDestX

; In original, their velocity of 1/2 pixels per tick was multiplied by 128, to see where the target would be in about 8 ticks,
; along with the needed x 16 to match the multiplier on the source and destination coordinates
; We are already 8.8, so we can just shift down by 1.
                            lda <wTargetVelocityX
                            asr_nt 1
                            clc
                            adc <wTargetX16
                            sec
                            sbc <wDestX
                            sta <wDestX

; Do the same for the Y component.  Again, tangent to the target, but also flipped.
; The goal is to get a distance so that the source never reaches it, and appears to orbit the 'real' target.
                            ldx <wAnglex2
                            lda >math~sin_64,x
                            inline~umul1r2 <wFactor,Y
                            lsr a

                            ldx <wQuadrant
                            cpx #math~quadrant_3*2
                            bge sin_neg             ; negative sin quadrant, however, since we wanted to multiple by a negative adjust, the value is positive
                            negate a

sin_neg                     ldx <wMultiplier
                            bpl sin_multi_pos
                            negate a
sin_multi_pos               anop
                            clc
                            adc <wTargetY16
                            sta <wTargetY16

; Shift up the source to match the target
                            lda <wSourceY
                            shiftleft 4
                            sta <wDestY

; Same adjustment as X velocity
                            lda <wTargetVelocityY
                            asr_nt 1
                            clc
                            adc <wTargetY16
                            sec
                            sbc <wDestY
                            sta <wDestY

                            ret 4:wDestX     ; Return wDestX and wDestY
                            end

; --------------------------------------------------------------------------------------------
; Get an orbital distance from an angle.
;
; Like playfield_get_orbital_distance, the results are x 16.  See playfield_get_orbital_distance
; for more information.
;
; Parameters:
; wAngle            - angle to the target
; wFactor           - the min distance to orbit from the center of the target
; wMultiplier       - the multiplier to the distance factor.  Used to pick random orbit distances.
; Returns:
;   X distance in A, Y distance in X.
;   Note this is a Manhattan distance to the location.
playfield_get_orbital_distance_from_angle start seg_entity
                            using playfield_entity_manager_data
                            using math_tables
                            using appdata

                            begin_locals
wDestX                      decl word
wDestY                      decl word
wAnglex2                    decl word
wQuadrant                   decl word
work_area_size              end_locals

                            debugtag 'get_orbital_distance_from_angle'

                            sub (2:wAngle,2:wFactor,2:wMultiplier),work_area_size

; Covert angle, to quadrant and slope angle
                            lda <wAngle
                            tax
                            shiftright 6
                            sta <wQuadrant
                            cmp #math~quadrant_2
                            beq reverse
                            cmp #math~quadrant_4
                            bne no_reverse

reverse                     txa
                            and #$3f
                            negate a
                            clc
                            adc #math~angle_90
                            bra reversed

no_reverse                  txa
                            and #$3f

reversed                    anop

                            asl a
                            sta <wAnglex2
                            tax
; Find the X component distance
; Multiply the adjustment by the cos.  This pushes the x distance away, tangent to the target
                            lda >math~cos_64,x
                            inline~umul1r2 <wFactor,Y       ; adjust the magnitude, and the sign of the sin
; Keeping the shifted value, like the original
                            ldx <wQuadrant
                            beq cos_neg
                            cpx #math~quadrant_4
                            bne cos_pos
cos_neg                     negate a
cos_pos                     ldx <wMultiplier
                            bpl cos_multi_pos
                            negate a
cos_multi_pos               anop
                            sta <wDestX

; Do the same for the Y component.  Again, tangent to the target, but also flipped.
; The goal is to get a distance so that the source never reaches it, and appears to orbit the 'real' target.
                            ldx <wAnglex2
                            lda >math~sin_64,x
                            inline~umul1r2 <wFactor,Y

                            ldx <wQuadrant
                            cpx #math~quadrant_3
                            bge sin_neg             ; negative sin quadrant, however, since we wanted to multiple by a negative adjust, the value is positive
                            negate a

sin_neg                     ldx <wMultiplier
                            bpl sin_multi_pos
                            negate a
sin_multi_pos               anop
                            sta <wDestY

                            ret 4:wDestX     ; Return wDestX and wDestY
                            end

; --------------------------------------------------------------------------------------------
; Invalidate the entity's sprite.  This sets the entity up to be drawn.
; This function assumes that the static buffer for entities is being used
;
; Note this supports child entities, but entities that have child-entities
; should be calling the playfield_entity_invalidate_hierarchy instead.
; This version will add the child entity's erase and update rects individually,
; which can end up with less efficient erasing / updating, if the rects are not
; merged.
;
; Parameters:
; x-reg - short pointer to the entity
; Returns:
; carry set, if not on screen, clear if on screen
playfield_entity_invalidate_sprite start seg_entity
                            using grlib_global_equates
                            using grlib_update_rects_data
                            using playfield_entity_manager_data
                            using collision_entry_data
                            using gameplay_entity_data
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data

; We are using scratch space on the grlib~dp, however, we have to put it after
; the scratch space usage for the update rects.
                            begin_struct urdp~group+sizeof~urdp~scratch_buffer
; Keep these first, they are used in _invalidate_sprite too.
wX                          decl word
wY                          decl word
spThis                      decl word
;
wNoneOnScreen               decl word
wParentX                    decl word
wParentY                    decl word
sizeof~invalidate_scratch   end_struct

                            static_assert_less_than sizeof~invalidate_scratch,256

                            debugtag 'pe_invalidate_sprite'

                            phd
                            lda >grlib~dp                                   ; Set the grlib~dp
                            tcd

; Setting the databank to the bank where both the update rects and collision entries are stored
; This is so we don't have to swap back and forth
                            setdatabanktolabel collision~shared_data

                            stx <spThis
; Don't invalidate child entities, that is up to the parent
; Not checking for this, though we still don't want this to happen, but constantly
; checking is a waste.  Make this into a debug-only check?
;                           getword {x},>entities_root+grlib_entity~parent_entity_ptr+2
;                           bne is_child
; Invalidate the root
                            getword {x},>entities_root+grlib_entity~x
                            sta <wX
                            getword {x},>entities_root+grlib_entity~y
                            sta <wY
; Do the active invalidate type
                            aif app~use_merged_update_rects=0,.skip
                            jsr _invalidate_sprite_merged
.skip
                            aif app~use_non_merged_update_rects=0,.skip
                            jsr _invalidate_sprite_no_merge
.skip
                            bcs not_on_screen

; If the entity is marked for removal, we are going to remove it from the collision list too.
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi to_be_removed

; Add to the collision list, if not already on
                            bit #playfield_entity~state_on_collision_list
                            beq add_to_list
; It is on its list, however, we need to update the rect and position in the list
                            getword {x},>entities_root+playfield_entity~collision_list_entry_sptr
                            tay
; Bank is already set
;                           setdatabanktolabel collision~entry_pool

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~left
                            putword {y},#collision_entry~rect+grlib_rect~left
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~top
                            putword {y},#collision_entry~rect+grlib_rect~top
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~right
                            putword {y},#collision_entry~rect+grlib_rect~right
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~bottom
                            putword {y},#collision_entry~rect+grlib_rect~bottom

; Adjust the location in the sort list, if needed
                            tyx                             ; node pointer expected in x
                            jsr collision_adjust_node_sort
;                           restoredatabank
                            ldx <spThis
                            clc
                            bra not_on_list

add_to_list                 anop
                            jsr collision_add_to_list
                            ldx <spThis
                            clc
                            bra not_on_list

not_on_screen               anop
                            getword {x},>entities_root+playfield_entity~state_flags
to_be_removed               bit #playfield_entity~state_on_collision_list
                            beq not_on_list_not_on_screen

                            jsr collision_remove_from_list
                            ldx <spThis
not_on_list_not_on_screen   sec
not_on_list                 anop

; Do we have child entities?
                            getword {x},>entities_root+grlib_entity~child_entity_ptr
                            bne _invalidate_children

exit                        restoredatabank
                            pld
                            rtl

;is_child                   sec
;                           restoredatabank
;                           pld
;                           rtl

; sub-function, invalidate the parent and the child entities, and return if any are on screen
_invalidate_children        anop
                            sta <spThis
                            tax

; Carry is still set if the parent was not on screen, put that in a value
                            lda #0
                            rol a
                            sta <wNoneOnScreen      ; 1 = nothing on screen so far

; Need some parent information
                            lda <wX
                            sta <wParentX
                            lda <wY
                            sta <wParentY

child_loop                  anop
; Any shape data?  If not we can go down a different pathway and assume a few things.
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            jeq no_child_shape

                            getword {x},>entities_root+grlib_entity~x
                            clc
                            adc <wParentX
                            sta <wX
                            getword {x},>entities_root+grlib_entity~y
                            clc
                            adc <wParentY
                            sta <wY
; Do the active invalidate type
                            aif app~use_merged_update_rects=0,.skip
                            jsr _invalidate_sprite_merged
.skip
                            aif app~use_non_merged_update_rects=0,.skip
                            jsr _invalidate_sprite_no_merge
.skip
                            bcs child_not_on_screen
                            stz <wNoneOnScreen
; If the entity is marked for removal, we are going to remove it from the collision list too.
; Maybe see if the parent is going to ge removed too?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi child_not_on_screen2
; Add to the collision list, if not already on
                            bit #playfield_entity~state_on_collision_list
                            beq child_add_to_list
; It is on its list, however, we need to update the rect and position in the list
                            getword {x},>entities_root+playfield_entity~collision_list_entry_sptr
                            tay
; Bank is already set
;                           setdatabanktolabel collision~entry_pool

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~left
                            putword {y},#collision_entry~rect+grlib_rect~left
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~top
                            putword {y},#collision_entry~rect+grlib_rect~top
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~right
                            putword {y},#collision_entry~rect+grlib_rect~right
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~bottom
                            putword {y},#collision_entry~rect+grlib_rect~bottom

; Adjust the location in the sort list, if needed
                            tyx
                            jsr collision_adjust_node_sort
;                           restoredatabank
                            bra next_child

child_add_to_list           anop
                            jsr collision_add_to_list
                            bra next_child

child_not_on_screen         anop
                            getword {x},>entities_root+playfield_entity~state_flags
child_not_on_screen2        bit #playfield_entity~state_on_collision_list
                            beq next_child2
; Remove from collision list
                            jsr collision_remove_from_list

next_child                  anop
                            ldx <spThis
next_child2                 anop
                            getword {x},>entities_root+grlib_entity~sibling_entity_ptr+2
                            beq done_with_children
                            getword {x},>entities_root+grlib_entity~sibling_entity_ptr
                            sta <spThis
                            tax
                            brl child_loop

done_with_children          lda <wNoneOnScreen              ; will be 1 or 0
                            lsr a                           ; put that in the carry
                            restoredatabank
                            pld
                            rtl
;;;
; The child has no shape data.  Check to see if it needs erasing
no_child_shape              anop
                            getword {x},>entities_root+sprite~info
                            static_assert_equal sprite~info~needs_erase,$8000
                            bpl child_not_on_screen
; Clear the flag
                            eor #sprite~info~needs_erase
                            putword {x},>entities_root+sprite~info

; Add the erase rect
                            aif app~use_merged_update_rects=0,.skip
                            jsr _invalidate_sprite_erase_merged
.skip
                            aif app~use_non_merged_update_rects=0,.skip
                            jsr _invalidate_sprite_erase_no_merge
.skip
                            bra child_not_on_screen

                            end

; --------------------------------------------------------------------------------------------
; A specialized version of the invalidate sprite, that assumes that
; the entity is made up of multiple child entities.
; This will collect the erase and update rects from the parts, and make a
; unified erase and unified update rect.
; This will still update each child's collision rect separately.
;
; This function assumes that the static buffer for entities is being used
;
; Parameters:
; x-reg - short pointer to the entity
; Returns:
; carry set, if not on screen, clear if on screen
playfield_entity_invalidate_hierarchy start seg_entity
                            using grlib_global_equates
                            using grlib_update_rects_data
                            using playfield_entity_manager_data
                            using collision_entry_data
                            using gameplay_entity_data
                            using grlib_global_data

; We are using scratch space on the grlib~dp, however, we have to put it after
; the scratch space usage for the update rects.
                            begin_struct urdp~group+sizeof~urdp~scratch_buffer
; Keep these first, they are used in _invalidate_sprite too.
wX                          decl word
wY                          decl word
spThis                      decl word
;
wEraseLeft                  decl word
wEraseTop                   decl word
wEraseRight                 decl word
wEraseBottom                decl word
wUpdateLeft                 decl word
wUpdateTop                  decl word
wUpdateRight                decl word
wUpdateBottom               decl word
;
wNoneOnScreen               decl word
wParentX                    decl word
wParentY                    decl word
sizeof~invalidate_scratch   end_struct

                            static_assert_less_than sizeof~invalidate_scratch,256

                            debugtag 'pe_invalidate_hierarchy'

                            phd
                            lda >grlib~dp                                   ; Set the grlib~dp
                            tcd

; Setting the databank to the bank where both the update rects and collision entries are stored
; This is so we don't have to swap back and forth
                            setdatabanktolabel collision~shared_data

; Initialize the erase and update rect to a invalid (inverted extremes)
; This way, any rect added, will cause all members to update.
; Could have a flag for the 'first' added, but that requires extra code and flow changes
; which would negate any savings.
extreme_high_value          equ 2048
extreme_low_value           equ -2048

                            lda #extreme_high_value
                            sta <wEraseLeft
                            sta <wEraseTop
                            sta <wUpdateLeft
                            sta <wUpdateTop

                            lda #extreme_low_value
                            sta <wEraseRight
                            sta <wEraseBottom
                            sta <wUpdateRight
                            sta <wUpdateBottom

                            stx <spThis
; Don't invalidate child entities, that is up to the parent
; Not checking for this, though we still don't want this to happen, but constantly
; checking is a waste.  Make this into a debug-only check?
;                           getword {x},>entities_root+grlib_entity~parent_entity_ptr+2
;                           bne is_child
; Invalidate the root
                            getword {x},>entities_root+grlib_entity~x
                            sta <wX
                            getword {x},>entities_root+grlib_entity~y
                            sta <wY
; Invalidate into a single merged erase and update rect
                            jsr _invalidate_sprite_single_merge
                            bcs not_on_screen

; If the entity is marked for removal, we are going to remove it from the collision list too.
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi to_be_removed

; Add to the collision list, if not already on
                            bit #playfield_entity~state_on_collision_list
                            beq add_to_list
; It is on its list, however, we need to update the rect and position in the list
                            getword {x},>entities_root+playfield_entity~collision_list_entry_sptr
                            tay
; Bank is already set
;                           setdatabanktolabel collision~entry_pool

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~left
                            putword {y},#collision_entry~rect+grlib_rect~left
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~top
                            putword {y},#collision_entry~rect+grlib_rect~top
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~right
                            putword {y},#collision_entry~rect+grlib_rect~right
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~bottom
                            putword {y},#collision_entry~rect+grlib_rect~bottom

; Adjust the location in the sort list, if needed
                            tyx                             ; node pointer expected in x
                            jsr collision_adjust_node_sort
;                           restoredatabank
                            ldx <spThis
                            clc
                            bra not_on_list

add_to_list                 anop
                            jsr collision_add_to_list
                            ldx <spThis
                            clc
                            bra not_on_list

not_on_screen               anop
                            getword {x},>entities_root+playfield_entity~state_flags
to_be_removed               bit #playfield_entity~state_on_collision_list
                            beq not_on_list_not_on_screen

                            jsr collision_remove_from_list
                            ldx <spThis
not_on_list_not_on_screen   sec
not_on_list                 anop

; Do we have child entities?
                            getword {x},>entities_root+grlib_entity~child_entity_ptr
                            bne _invalidate_children

exit                        jmp add_merged_rects

;is_child                   sec
;                           restoredatabank
;                           pld
;                           rtl

; sub-function, invalidate the parent and the child entities, and return if any are on screen
_invalidate_children        anop
                            sta <spThis
                            tax

; Carry is still set if the parent was not on screen, put that in a value
                            lda #0                  ; Could probably skip this, as we only test the lower bit later on.
                            rol a
                            sta <wNoneOnScreen      ; 1 = nothing on screen so far

; Need some parent information
                            lda <wX
                            sta <wParentX
                            lda <wY
                            sta <wParentY

child_loop                  anop
; Any shape data?  If not we can go down a different pathway and assume a few things.
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            jeq no_child_shape

                            getword {x},>entities_root+grlib_entity~x
                            clc
                            adc <wParentX
                            sta <wX
                            getword {x},>entities_root+grlib_entity~y
                            clc
                            adc <wParentY
                            sta <wY
; Invalidate into a single merged erase and update rect
                            jsr _invalidate_sprite_single_merge
                            bcs child_not_on_screen
                            stz <wNoneOnScreen
; If the entity is marked for removal, we are going to remove it from the collision list too.
; Maybe see if the parent is going to ge removed too?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi child_not_on_screen2
; Add to the collision list, if not already on
                            bit #playfield_entity~state_on_collision_list
                            beq child_add_to_list
; It is on its list, however, we need to update the rect and position in the list
                            getword {x},>entities_root+playfield_entity~collision_list_entry_sptr
                            tay
; Bank is already set
;                           setdatabanktolabel collision~entry_pool

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~left
                            putword {y},#collision_entry~rect+grlib_rect~left
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~top
                            putword {y},#collision_entry~rect+grlib_rect~top
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~right
                            putword {y},#collision_entry~rect+grlib_rect~right
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~bottom
                            putword {y},#collision_entry~rect+grlib_rect~bottom

; Adjust the location in the sort list, if needed
                            tyx
                            jsr collision_adjust_node_sort
;                           restoredatabank
                            bra next_child

child_add_to_list           anop
                            jsr collision_add_to_list
                            bra next_child

child_not_on_screen         anop
                            getword {x},>entities_root+playfield_entity~state_flags
child_not_on_screen2        bit #playfield_entity~state_on_collision_list
                            beq next_child2
; Remove from collision list
                            jsr collision_remove_from_list

next_child                  anop
                            ldx <spThis
next_child2                 anop
                            getword {x},>entities_root+grlib_entity~sibling_entity_ptr+2
                            beq done_with_children
                            getword {x},>entities_root+grlib_entity~sibling_entity_ptr
                            sta <spThis
                            tax
                            brl child_loop

done_with_children          lda <wNoneOnScreen              ; will be 1 or 0
                            lsr a                           ; put that in the carry
                            jmp add_merged_rects
;;;
; The child has no shape data.  Check to see if it needs erasing
no_child_shape              anop
                            getword {x},>entities_root+sprite~info
                            static_assert_equal sprite~info~needs_erase,$8000
                            bpl child_not_on_screen
; Clear the flag
                            eor #sprite~info~needs_erase
                            putword {x},>entities_root+sprite~info

; Add the erase rect
                            jsr _invalidate_sprite_erase_single_merge
                            bra child_not_on_screen

;;;
add_merged_rects            anop
; This only supports the queued rects.  Might want to support a path of adding
; to the global merged update rects, for completness, even though I'm not using
; that for pathway for this game.
                            php                                             ; must preserve the carry flag

                            lda <wEraseLeft
                            cmp #extreme_high_value
                            bsge no_merged_erase
; Put the erase values into the erase rects queue
                            ldy |update_rects_queued~erase_insert_offset
                            cpy #max_queued_update_rect_count*2             ; make sure we don't go over our cap.
                            bge no_merged_erase

                            lda <wEraseLeft
                            sta |update_rects_queued~erase_rects~left,y
                            lda <wEraseTop
                            sta |update_rects_queued~erase_rects~top,y
                            lda <wEraseRight
                            sta |update_rects_queued~erase_rects~right,y
                            lda <wEraseBottom
                            sta |update_rects_queued~erase_rects~bottom,y

                            iny
                            iny
                            sty |update_rects_queued~erase_insert_offset

no_merged_erase             anop
                            lda <wUpdateLeft
                            cmp #extreme_high_value
                            bsge no_merged_update

                            ldy |update_rects_queued~update_insert_offset
                            cpy #max_queued_update_rect_count*2
                            bge no_merged_update

                            lda <wUpdateLeft
                            sta |update_rects_queued~update_rects~left,y
                            lda <wUpdateTop
                            sta |update_rects_queued~update_rects~top,y
                            lda <wUpdateRight
                            sta |update_rects_queued~update_rects~right,y
                            lda <wUpdateBottom
                            sta |update_rects_queued~update_rects~bottom,y

                            iny
                            iny
                            sty |update_rects_queued~update_insert_offset

no_merged_update            plp
                            restoredatabank
                            pld
                            rtl

                            end

; --------------------------------------------------------------------------------------------
; A custom version of playfield_entity_invalidate_sprite that:
;  * Does not add / remove the entity from the collision list
;  * Does not support child-entities.
;
; This function is use for explosion images, that do not collide.
; Since they are not on the collision-list, a custom draw loop
; will have to be used.
;
; This function assumes that the static buffer for entities is being used
;
; Parameters:
; x-reg - short pointer to the entity
; Returns:
; carry set, if not on screen, clear if on screen
playfield_entity_invalidate_sprite_no_collision start seg_entity
                            using grlib_global_equates
                            using grlib_update_rects_data
                            using playfield_entity_manager_data
                            using collision_entry_data
                            using gameplay_entity_data
                            using grlib_global_equates
                            using grlib_global_data

; We are using scratch space on the grlib~dp, however, we have to put it after
; the scratch space usage for the update rects.
                            begin_struct urdp~group+sizeof~urdp~scratch_buffer
; Keep these first, they are used in _invalidate_sprite too.
wX                          decl word
wY                          decl word
spThis                      decl word
;
wNoneOnScreen               decl word
wParentX                    decl word
wParentY                    decl word
sizeof~invalidate_scratch   end_struct

                            static_assert_less_than sizeof~invalidate_scratch,256

                            debugtag 'pe_invsp_no_collision'

                            phd
                            lda >grlib~dp                                   ; Set the grlib~dp
                            tcd

; Setting the databank to the bank where both the update rects are stored
                            setdatabanktolabel collision~shared_data
; Invalidate the root
                            getword {x},>entities_root+grlib_entity~x
                            sta <wX
                            getword {x},>entities_root+grlib_entity~y
                            sta <wY
; Do the active invalidate type
                            aif app~use_merged_update_rects=0,.skip
                            jsr _invalidate_sprite_merged
.skip
                            aif app~use_non_merged_update_rects=0,.skip
                            jsr _invalidate_sprite_no_merge
.skip

                            restoredatabank
                            pld
                            rtl

                            end

; --------------------------------------------------------------------------------------------
; Copied and modified version of grlib_invalidate_sprite
; This is optmized for the playfield entity, and is meant to be called from playfield_entity_invalidate_sprite
; I would have made it simply a function inside that parent function, but I needed to get
; a global label that would appear in the linker map for the profiler.
; Parameters:
; x-register: short pointer to the sprite
; wX and wY are on DP scratch space
; Returns:
; Carry clear, if the sprite was added to the update rects, set if not.
; the x-register will be preserved
_invalidate_sprite_merged   private seg_entity
                            using grlib_global_data
                            using grlib_global_equates
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

; We are using scratch space on the grlib~dp, however, we have to put it after
; the scratch space usage for the update rects.
; This is expected to be filled in by the caller.
                            begin_struct urdp~group+sizeof~urdp~scratch_buffer
wX                          decl word
wY                          decl word
spThis                      decl word
                            end_struct

                            getword {x},>entities_root+sprite~info
                            static_assert_equal sprite~info~needs_erase,$8000
;                           bit #sprite~info~needs_erase
                            bpl no_erase                                    ; we can just go on the negative flag
; Clear flag
                            eor #sprite~info~needs_erase
                            putword {x},>entities_root+sprite~info

;; NOTE!! I'm now skipping adding to the separate erase-rects tracking and just adding
; to the update-rects.  Erasing will be done to the update-rects, which means erasing more
; than is needed, but saves on the tracking of the erase-rects.

                            ago .skip
; Put the erase values into the erase rects
                            static_assert_equal urlib_group~erase,0
;                           lda #urlib_group~erase*2
;                           sta <urdp~group
                            stz <urdp~group
                            getword {x},>entities_root+sprite~erase~left
                            sta <urdp~left
                            getword {x},>entities_root+sprite~erase~top
                            sta <urdp~top
                            getword {x},>entities_root+sprite~erase~right
                            sta <urdp~right
                            getword {x},>entities_root+sprite~erase~bottom
                            sta <urdp~bottom
                            jsl grlib_add_screen_space_rect_to_update_always_merge
                            ldx <spThis
; We will need to put the erase rect in the update rects, however, if we are going to draw something
; it would be best to just add a merged rect of the draw and erase rect.
.skip
                            bra has_erase                                   ; go to the draw rect pathway that knows there is an erase rect

no_erase                    anop
; We may need a flag here, signifying that the sprite is to be drawn or not, i.e. it has been removed.

; Get the pointer to the shape table. We are going to be as quick as possible with testing
; and just assume if the high word is 0, then the whole pointer is null.  i.e. No shape data in bank 0.
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            beq no_shape

; Add the draw rect to the update
; This doesn't do any drawing, it is just signifying that we will eventually draw to that area.
; This will also update the bounds rect.  I'm not currently transferring the rect to the erase rect.
; That will be done when the sprite is actually drawn.

; This converts the world space coordinates into screen space.
                            getword <wX
                            sec
                            sbcword {x},>entities_root+sprite~offset_x
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4  could be replaced with fixed value of gameplay_ui_playfield_center_x
                            cmp <urdp~max~right                             ; 4  could also be replaced with a fixed value of gameplay_ui_playfield_right
                            bsge clipped
                            putword {x},>entities_root+sprite~bounds~left
                            sta <urdp~left

                            clc
                            adcword {x},>entities_root+sprite~width
                            cmp <urdp~max~left                              ; 4
                            bslt clipped
                            putword {x},>entities_root+sprite~bounds~right
                            sta <urdp~right

                            getword <wY
                            sec
                            sbcword {x},>entities_root+sprite~offset_y
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge clipped
                            putword {x},>entities_root+sprite~bounds~top
                            sta <urdp~top

                            clc
                            adcword {x},>entities_root+sprite~height
                            cmp <urdp~max~top                               ; 4
                            bslt clipped
                            putword {x},>entities_root+sprite~bounds~bottom
                            sta <urdp~bottom

                            lda #urlib_group~update*2
                            sta <urdp~group

                            jsl grlib_add_screen_space_rect_to_update_always_merge
                            ldx <spThis

                            rts

; Clipped.  Do stack cleanup and exit
clipped                     anop
no_shape                    anop
                            sec
                            rts

;;;;
; Pathway, if there there was an erase

has_erase                    anop
; Get the pointer to the shape table. We are going to be as quick as possible with testing
; and just assume if the high word is 0, then the whole pointer is null.  i.e. No shape data in bank 0.
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            jeq just_erase

; Add the draw rect to the update
; This pathway assumes that the sprite~erase rect also needs to be added to the update rects, and will merge the draw and erase rect
; Note, this doesn't test for overlap, and if there isn't any, this can end up adding a rect, larger than what is desired.

                            getword <wX
                            sec
                            sbcword {x},>entities_root+sprite~offset_x
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4
                            cmp <urdp~max~right                             ; 4
                            bsge just_erase
                            putword {x},>entities_root+sprite~bounds~left
                            cmpword {x},>entities_root+sprite~erase~left
                            bslt draw_left_ok
                            getword {x},>entities_root+sprite~erase~left
draw_left_ok                sta <urdp~left

                            getword <wY
                            sec
                            sbcword {x},>entities_root+sprite~offset_y
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge just_erase
                            putword {x},>entities_root+sprite~bounds~top
                            cmpword {x},>entities_root+sprite~erase~top
                            bslt draw_top_ok
                            getword {x},>entities_root+sprite~erase~top
draw_top_ok                 sta <urdp~top

                            getword {x},>entities_root+sprite~width
                            clc
                            adcword {x},>entities_root+sprite~bounds~left
                            cmp <urdp~max~left                              ; 4
                            bslt just_erase
                            putword {x},>entities_root+sprite~bounds~right
                            cmpword {x},>entities_root+sprite~erase~right
                            bsge draw_right_ok
                            getword {x},>entities_root+sprite~erase~right
draw_right_ok               sta <urdp~right

                            getword {x},>entities_root+sprite~height
                            clc
                            adcword {x},>entities_root+sprite~bounds~top
                            cmp <urdp~max~top                               ; 4
                            bslt just_erase
                            putword {x},>entities_root+sprite~bounds~bottom
                            cmpword {x},>entities_root+sprite~erase~bottom
                            bsge draw_bottom_ok
                            getword {x},>entities_root+sprite~erase~bottom
draw_bottom_ok              sta <urdp~bottom

                            lda #urlib_group~update*2
                            sta <urdp~group

                            jsl grlib_add_screen_space_rect_to_update_always_merge
                            ldx <spThis

                            clc
                            rts

; The draw rect was clipped, but we had an erase rect.  Just add the erase rect to the update rects
just_erase                  anop
                            getword {x},>entities_root+sprite~erase~left
                            sta <urdp~left
                            getword {x},>entities_root+sprite~erase~top
                            sta <urdp~top
                            getword {x},>entities_root+sprite~erase~right
                            sta <urdp~right
                            getword {x},>entities_root+sprite~erase~bottom
                            sta <urdp~bottom

                            lda #urlib_group~update*2
                            sta <urdp~group

                            jsl grlib_add_screen_space_rect_to_update_always_merge
                            ldx <spThis

                            sec
                            rts

                            end

; --------------------------------------------------------------------------------------------
; Copied and modified version of grlib_invalidate_sprite
; This is optmized for the playfield entity, and is meant to be called from playfield_entity_invalidate_sprite
; This version is used for collecting non-merged rects.
; The rects are just put into a queue, as-is.
;
; Assumes:
; Databank is set to the update rects bank.
;
; Parameters:
; x-register: short pointer to the sprite
; wX and wY are on DP scratch space
;
; Returns:
; Carry clear, if the sprite was added to the update rects, set if not.
; the x-register will be preserved
_invalidate_sprite_no_merge private seg_entity
                            using grlib_global_data
                            using grlib_global_equates
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

; We are using scratch space on the grlib~dp, however, we have to put it after
; the scratch space usage for the update rects.
; This is expected to be filled in by the caller.
                            begin_struct urdp~group+sizeof~urdp~scratch_buffer
wX                          decl word
wY                          decl word
spThis                      decl word
                            end_struct

; Assuming databank is already set update_rects
;                           setdatabanktolabel update_rects_queued~erase_insert_offset

                            getword {x},>entities_root+sprite~info
                            static_assert_equal sprite~info~needs_erase,$8000
;                           bit #sprite~info~needs_erase
                            bpl no_erase                                    ; we can just go on the negative flag
; Clear flag
                            eor #sprite~info~needs_erase
                            putword {x},>entities_root+sprite~info

; Put the erase values into the erase rects queue
                            ldy |update_rects_queued~erase_insert_offset
                            cpy #max_queued_update_rect_count*2             ; make sure we don't go over our cap.
                            jge has_erase

ok_erase_count              getword {x},>entities_root+sprite~erase~left
                            sta |update_rects_queued~erase_rects~left,y
                            getword {x},>entities_root+sprite~erase~top
                            sta |update_rects_queued~erase_rects~top,y
                            getword {x},>entities_root+sprite~erase~right
                            sta |update_rects_queued~erase_rects~right,y
                            getword {x},>entities_root+sprite~erase~bottom
                            sta |update_rects_queued~erase_rects~bottom,y

                            iny
                            iny
                            sty |update_rects_queued~erase_insert_offset

                            bra has_erase                                   ; go to the draw rect pathway that knows there is an erase rect

no_erase                    anop
; We may need a flag here, signifying that the sprite is to be drawn or not, i.e. it has been removed.

; Get the pointer to the shape table. We are going to be as quick as possible with testing
; and just assume if the high word is 0, then the whole pointer is null.  i.e. No shape data in bank 0.
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            beq no_shape

                            ldy |update_rects_queued~update_insert_offset
                            cpy #max_queued_update_rect_count*2
                            bge too_many_updates

; Add the draw rect to the update
; This doesn't do any drawing, it is just signifying that we will eventually draw to that area.
; This will also update the bounds rect.  I'm not currently transferring the rect to the erase rect.
; That will be done when the sprite is actually drawn.

; This converts the world space coordinates into screen space.
                            getword <wX
                            sec
                            sbcword {x},>entities_root+sprite~offset_x
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4  could be replaced with fixed value of gameplay_ui_playfield_center_x
                            cmp <urdp~max~right                             ; 4  could also be replaced with a fixed value of gameplay_ui_playfield_right
                            bsge clipped
                            putword {x},>entities_root+sprite~bounds~left
                            sta |update_rects_queued~update_rects~left,y

                            clc
                            adcword {x},>entities_root+sprite~width
                            cmp <urdp~max~left                              ; 4
                            bslt clipped
                            putword {x},>entities_root+sprite~bounds~right
                            sta |update_rects_queued~update_rects~right,y

                            getword <wY
                            sec
                            sbcword {x},>entities_root+sprite~offset_y
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge clipped
                            putword {x},>entities_root+sprite~bounds~top
                            sta |update_rects_queued~update_rects~top,y

                            clc
                            adcword {x},>entities_root+sprite~height
                            cmp <urdp~max~top                               ; 4
                            bslt clipped
                            putword {x},>entities_root+sprite~bounds~bottom
                            sta |update_rects_queued~update_rects~bottom,y

                            iny
                            iny
                            sty |update_rects_queued~update_insert_offset

;                           restoredatabank
                            clc
                            rts

; Clipped.  Do stack cleanup and exit
clipped                     anop
no_shape                    anop
too_many_updates            anop
;                           restoredatabank
                            sec
                            rts

;;;;
; Pathway, if there there was an erase

has_erase                    anop
; Get the pointer to the shape table. We are going to be as quick as possible with testing
; and just assume if the high word is 0, then the whole pointer is null.  i.e. No shape data in bank 0.
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            jeq just_erase

                            ldy |update_rects_queued~update_insert_offset
                            cpy #max_queued_update_rect_count*2
                            bge too_many_updates

; Add the draw rect to the update
; This pathway assumes that the sprite~erase rect also needs to be added to the update rects, and will merge the draw and erase rect
; Note, this doesn't test for overlap, and if there isn't any, this can end up adding a rect, larger than what is desired.

                            getword <wX
                            sec
                            sbcword {x},>entities_root+sprite~offset_x
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4
                            cmp <urdp~max~right                             ; 4
                            bsge just_erase
                            putword {x},>entities_root+sprite~bounds~left
                            cmpword {x},>entities_root+sprite~erase~left
                            bslt draw_left_ok
                            getword {x},>entities_root+sprite~erase~left
draw_left_ok                sta |update_rects_queued~update_rects~left,y

                            getword <wY
                            sec
                            sbcword {x},>entities_root+sprite~offset_y
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge just_erase
                            putword {x},>entities_root+sprite~bounds~top
                            cmpword {x},>entities_root+sprite~erase~top
                            bslt draw_top_ok
                            getword {x},>entities_root+sprite~erase~top
draw_top_ok                 sta |update_rects_queued~update_rects~top,y

                            getword {x},>entities_root+sprite~width
                            clc
                            adcword {x},>entities_root+sprite~bounds~left
                            cmp <urdp~max~left                              ; 4
                            bslt just_erase
                            putword {x},>entities_root+sprite~bounds~right
                            cmpword {x},>entities_root+sprite~erase~right
                            bsge draw_right_ok
                            getword {x},>entities_root+sprite~erase~right
draw_right_ok               sta |update_rects_queued~update_rects~right,y

                            getword {x},>entities_root+sprite~height
                            clc
                            adcword {x},>entities_root+sprite~bounds~top
                            cmp <urdp~max~top                               ; 4
                            bslt just_erase
                            putword {x},>entities_root+sprite~bounds~bottom
                            cmpword {x},>entities_root+sprite~erase~bottom
                            bsge draw_bottom_ok
                            getword {x},>entities_root+sprite~erase~bottom
draw_bottom_ok              sta |update_rects_queued~update_rects~bottom,y

                            iny
                            iny
                            sty |update_rects_queued~update_insert_offset

;                           restoredatabank

                            clc
                            rts

; The draw rect was clipped, but we had an erase rect.  Just add the erase rect to the update rects
just_erase                  anop
                            ldy |update_rects_queued~update_insert_offset
                            cpy #max_queued_update_rect_count*2
                            bge too_many_updates2

                            getword {x},>entities_root+sprite~erase~left
                            sta |update_rects_queued~update_rects~left,y
                            getword {x},>entities_root+sprite~erase~top
                            sta |update_rects_queued~update_rects~top,y
                            getword {x},>entities_root+sprite~erase~right
                            sta |update_rects_queued~update_rects~right,y
                            getword {x},>entities_root+sprite~erase~bottom
                            sta |update_rects_queued~update_rects~bottom,y

                            iny
                            iny
                            sty |update_rects_queued~update_insert_offset

too_many_updates2           anop
;                           restoredatabank

                            sec
                            rts

                            end

; --------------------------------------------------------------------------------------------
; Adds just the erase rect to the queued update rects
;
; Parameters:
; x-register: short pointer to the sprite
; Returns:
; Carry set
; the x-register will be preserved
_invalidate_sprite_erase_no_merge private seg_entity
                            using grlib_global_data
                            using grlib_global_equates
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

; Setting the databank to the update_rects
                            setdatabanktolabel update_rects_queued~erase_insert_offset

; Put the erase values into the erase rects queue
                            ldy |update_rects_queued~erase_insert_offset
                            cpy #max_queued_update_rect_count*2             ; make sure we don't go over our cap.
                            bge too_many_updates

                            getword {x},>entities_root+sprite~erase~left
                            sta |update_rects_queued~erase_rects~left,y
                            getword {x},>entities_root+sprite~erase~top
                            sta |update_rects_queued~erase_rects~top,y
                            getword {x},>entities_root+sprite~erase~right
                            sta |update_rects_queued~erase_rects~right,y
                            getword {x},>entities_root+sprite~erase~bottom
                            sta |update_rects_queued~erase_rects~bottom,y

                            iny
                            iny
                            sty |update_rects_queued~erase_insert_offset

too_many_updates            anop
                            restoredatabank
                            sec
                            rts

                            end


; --------------------------------------------------------------------------------------------
; Copied and modified version of grlib_invalidate_sprite
; This is optmized for the playfield entity, and is meant to be called from playfield_entity_invalidate_sprite
; This version is used for collecting a single merged erase and update rect, for later adding to the
; find erase and update rects.
;
; Assumes:
; Databank is set to the update rects bank.
;
; Parameters:
; x-register: short pointer to the sprite
; wX and wY are on DP scratch space
; The rects to 'expand' are in.
; <wEraseLeft, <wEraseTop, <wEraseRight, <wEraseBottom
; <wUpdateLeft, <wUpdateTop, <wUpdateRight, <wUpdateBottom
; These are initialize to an inverted rect value, so the first one
; added, will always set the values.
;
; Returns:
; Carry clear, if the sprite was added to the update rects, set if not.
; the x-register will be preserved
_invalidate_sprite_single_merge private seg_entity
                            using grlib_global_data
                            using grlib_global_equates
                            using grlib_update_rects_data

; We are using scratch space on the grlib~dp, however, we have to put it after
; the scratch space usage for the update rects.
; This is expected to be filled in by the caller.
                            begin_struct urdp~group+sizeof~urdp~scratch_buffer
wX                          decl word
wY                          decl word
spThis                      decl word
;
wEraseLeft                  decl word
wEraseTop                   decl word
wEraseRight                 decl word
wEraseBottom                decl word
wUpdateLeft                 decl word
wUpdateTop                  decl word
wUpdateRight                decl word
wUpdateBottom               decl word
                            end_struct

; Assuming databank is already set update_rects
;                           setdatabanktolabel update_rects_queued~erase_insert_offset

                            getword {x},>entities_root+sprite~info
                            static_assert_equal sprite~info~needs_erase,$8000
;                           bit #sprite~info~needs_erase
                            bpl no_erase                                    ; we can just go on the negative flag
; Clear flag
                            eor #sprite~info~needs_erase
                            putword {x},>entities_root+sprite~info

; Make the existing erase rect bigger, based on this erase rect
                            getword {x},>entities_root+sprite~erase~left
                            cmp <wEraseLeft
                            bsge erase_left_skip
                            sta <wEraseLeft
erase_left_skip             getword {x},>entities_root+sprite~erase~top
                            cmp <wEraseTop
                            bsge erase_top_skip
                            sta <wEraseTop
erase_top_skip              getword {x},>entities_root+sprite~erase~right
                            cmp <wEraseRight
                            bslt erase_right_skip
                            sta <wEraseRight
erase_right_skip            getword {x},>entities_root+sprite~erase~bottom
                            cmp <wEraseBottom
                            bslt erase_bottom_skip
                            sta <wEraseBottom

erase_bottom_skip           anop
                            bra has_erase                                   ; go to the draw rect pathway that knows there is an erase rect

no_erase                    anop
; We may need a flag here, signifying that the sprite is to be drawn or not, i.e. it has been removed.

; Get the pointer to the shape table. We are going to be as quick as possible with testing
; and just assume if the high word is 0, then the whole pointer is null.  i.e. No shape data in bank 0.
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            beq no_shape

; Add the draw rect to the update
; This doesn't do any drawing, it is just signifying that we will eventually draw to that area.
; This will also update the bounds rect.  I'm not currently transferring the rect to the erase rect.
; That will be done when the sprite is actually drawn.

; This converts the world space coordinates into screen space.
                            getword <wX
                            sec
                            sbcword {x},>entities_root+sprite~offset_x
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4  could be replaced with fixed value of gameplay_ui_playfield_center_x
                            cmp <urdp~max~right                             ; 4  could also be replaced with a fixed value of gameplay_ui_playfield_right
                            bsge clipped
                            putword {x},>entities_root+sprite~bounds~left
                            cmp <wUpdateLeft
                            bsge update_left_skip
                            sta <wUpdateLeft

update_left_skip            clc
                            adcword {x},>entities_root+sprite~width
                            cmp <urdp~max~left                              ; 4
                            bslt clipped
                            putword {x},>entities_root+sprite~bounds~right
                            cmp <wUpdateRight
                            bslt update_right_skip
                            sta <wUpdateRight

update_right_skip           getword <wY
                            sec
                            sbcword {x},>entities_root+sprite~offset_y
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge clipped
                            putword {x},>entities_root+sprite~bounds~top
                            cmp <wUpdateTop
                            bsge update_top_skip
                            sta <wUpdateTop

update_top_skip             clc
                            adcword {x},>entities_root+sprite~height
                            cmp <urdp~max~top                               ; 4
                            bslt clipped
                            putword {x},>entities_root+sprite~bounds~bottom
                            cmp <wUpdateBottom
                            bslt update_bottom_skip
                            sta <wUpdateBottom

update_bottom_skip          anop

;                           restoredatabank
                            clc
                            rts

; Clipped.  Do stack cleanup and exit
clipped                     anop
no_shape                    anop
too_many_updates            anop
;                           restoredatabank
                            sec
                            rts

;;;;
; Pathway, if there there was an erase

has_erase                    anop
; Get the pointer to the shape table. We are going to be as quick as possible with testing
; and just assume if the high word is 0, then the whole pointer is null.  i.e. No shape data in bank 0.
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            jeq just_erase

; Add the draw rect to the update
; This pathway assumes that the sprite~erase rect also needs to be added to the update rects, and will merge the draw and erase rect
; Note, this doesn't test for overlap, and if there isn't any, this can end up adding a rect, larger than what is desired.

                            getword <wX
                            sec
                            sbcword {x},>entities_root+sprite~offset_x
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4
                            cmp <urdp~max~right                             ; 4
                            bsge just_erase
                            putword {x},>entities_root+sprite~bounds~left
                            cmpword {x},>entities_root+sprite~erase~left
                            bslt draw_left_ok
                            getword {x},>entities_root+sprite~erase~left
draw_left_ok                cmp <wUpdateLeft
                            bsge update_erase_left_skip
                            sta <wUpdateLeft

update_erase_left_skip      getword <wY
                            sec
                            sbcword {x},>entities_root+sprite~offset_y
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge just_erase
                            putword {x},>entities_root+sprite~bounds~top
                            cmpword {x},>entities_root+sprite~erase~top
                            bslt draw_top_ok
                            getword {x},>entities_root+sprite~erase~top
draw_top_ok                 cmp <wUpdateTop
                            bsge update_erase_top_skip
                            sta <wUpdateTop

update_erase_top_skip       getword {x},>entities_root+sprite~width
                            clc
                            adcword {x},>entities_root+sprite~bounds~left
                            cmp <urdp~max~left                              ; 4
                            bslt just_erase
                            putword {x},>entities_root+sprite~bounds~right
                            cmpword {x},>entities_root+sprite~erase~right
                            bsge draw_right_ok
                            getword {x},>entities_root+sprite~erase~right
draw_right_ok               cmp <wUpdateRight
                            bslt update_erase_right_skip
                            sta <wUpdateRight

update_erase_right_skip     getword {x},>entities_root+sprite~height
                            clc
                            adcword {x},>entities_root+sprite~bounds~top
                            cmp <urdp~max~top                               ; 4
                            bslt just_erase
                            putword {x},>entities_root+sprite~bounds~bottom
                            cmpword {x},>entities_root+sprite~erase~bottom
                            bsge draw_bottom_ok
                            getword {x},>entities_root+sprite~erase~bottom
draw_bottom_ok              cmp <wUpdateBottom
                            bslt update_erase_bottom_skip
                            sta <wUpdateBottom

update_erase_bottom_skip    anop

;                           restoredatabank

                            clc
                            rts

; The draw rect was clipped, but we had an erase rect.  Just add the erase rect to the update rects
just_erase                  anop

                            getword {x},>entities_root+sprite~erase~left
                            cmp <wUpdateLeft
                            bsge just_erase_left_skip
                            sta <wUpdateLeft
just_erase_left_skip        getword {x},>entities_root+sprite~erase~top
                            cmp <wUpdateTop
                            bsge jsut_erase_top_skip
                            sta <wUpdateTop
jsut_erase_top_skip         getword {x},>entities_root+sprite~erase~right
                            cmp <wUpdateRight
                            bslt just_erase_right_skip
                            sta <wUpdateRight
just_erase_right_skip       getword {x},>entities_root+sprite~erase~bottom
                            cmp <wUpdateBottom
                            bslt just_erase_bottom_skip
                            sta <wUpdateBottom

just_erase_bottom_skip      anop
;                           restoredatabank

                            sec
                            rts

                            end

; --------------------------------------------------------------------------------------------
; Adds just the erase rect to the single merge rect that is defined by
; the DP values:
; wEraseLeft, wEraseTop, wEraseRight, wEraseBottom
;
; Parameters:
; x-register: short pointer to the sprite
; Returns:
; Carry set
; the x-register will be preserved
_invalidate_sprite_erase_single_merge private seg_entity
                            using grlib_global_data
                            using grlib_global_equates
                            using grlib_update_rects_data

; We are using scratch space on the grlib~dp, however, we have to put it after
; the scratch space usage for the update rects.
; This is expected to be filled in by the caller.
                            begin_struct urdp~group+sizeof~urdp~scratch_buffer
wX                          decl word
wY                          decl word
spThis                      decl word
;
wEraseLeft                  decl word
wEraseTop                   decl word
wEraseRight                 decl word
wEraseBottom                decl word
wUpdateLeft                 decl word
wUpdateTop                  decl word
wUpdateRight                decl word
wUpdateBottom               decl word
                            end_struct

; Add erase values to the single merged erase rect
                            getword {x},>entities_root+sprite~erase~left
                            cmp <wEraseLeft
                            bsge erase_left_skip
                            sta <wEraseLeft
erase_left_skip             getword {x},>entities_root+sprite~erase~top
                            cmp <wEraseTop
                            bsge erase_top_skip
                            sta <wEraseTop
erase_top_skip              getword {x},>entities_root+sprite~erase~right
                            cmp <wEraseRight
                            bslt erase_right_skip
                            sta <wEraseRight
erase_right_skip            getword {x},>entities_root+sprite~erase~bottom
                            cmp <wEraseBottom
                            bslt erase_bottom_skip
                            sta <wEraseBottom
erase_bottom_skip           sec
                            rts

                            end

; ----------------------------------------------------------------------------
; Mark an entity for removal, also invalidate its rect.
; Parameters:
; x-reg         - short pointer to the entity
playfield_entity_mark_for_removal start seg_entity
                            using playfield_entity_data

                            debugtag 'mark_for_removal'

                            begin_locals
work_area_size              end_locals

                            sub ,work_area_size

; Is it a child?  If so, the parent will remove the child.  We don't want children on the removal list
; in case the child get added, after the parent, in which case, the parent will be deleted, and the child pointer
; will be stale.
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~parent_entity_ptr+2
                            bne is_child

                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi already_on_removal_list

; Setting the databank local.  The handlers are currently relying on this, but shouldn't they just set it themselves?
; They *could* be in other banks, though I know they are not.
                            setlocaldatabank

                            ora #playfield_entity~state_marked_for_removal
                            putword {x},>entities_root+playfield_entity~state_flags

add_to_list                 txy                     ; entity short pointer in Y
                            getword {x},>entities_root+playfield_entity~type
                            asl a
                            tax
                            jsr (entity_remove_handlers,x)

                            restoredatabank

is_child                    anop
already_on_removal_list     anop
                            ret
                            end

; -----------------------------------------------------------------------------
; Default handler for when an entity is 'marked for removal'
; This is usually overridden, by the entity type definition, so it gets
; added to its manager's removal list.
; Parameters:
; y-reg         - short pointer to entity
default_entity_remove_handler start seg_entity

                            debugtag 'remove_handler_default_entity'

                            rts                                 ; called by a jsr
                            end

; -----------------------------------------------------------------------------
; Remove an entity from the playfield
; Note, unless the entity has children, it is best to just inline marking the
; entity for removal and invalidate it
; Parameters:
; x-reg             - short pointer to entity
playfield_entity_remove_from_playfield start seg_entity
                            using sinistar_entity_data

                            debugtag 'remove_from_playfield'

                            begin_locals
pChildEntity                decl ptr
work_area_size              end_locals

                            sub ,work_area_size

; Make sure this is on, so we get removed from the collision list
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword {x},>entities_root+playfield_entity~state_flags

; Do we have child entities?
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~child_entity_ptr+2
                            beq no_children
                            phx
                            jsr mark_children
; Invalidate.  This will do the children, as well as the parent.
                            plx
no_children                 anop
                            jsl playfield_entity_invalidate_sprite

                            ret

; sub-function to mark the children for removal.  However, they will not be put on the entity remove list
; Only the parent should be on there, so we don't have any deletion order issues.
mark_children               anop
                            sta <pChildEntity+2
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~child_entity_ptr
                            sta <pChildEntity

child_loop                  getword [<pChildEntity],#playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword [<pChildEntity],#same

                            getword [<pChildEntity],#playfield_entity~grentity+grlib_entity~sibling_entity_ptr+2
                            beq done_with_children
                            tax
                            getword [<pChildEntity],#playfield_entity~grentity+grlib_entity~sibling_entity_ptr
                            sta <pChildEntity
                            stx <pChildEntity+2
                            bra child_loop

done_with_children          rts

                            end

; -----------------------------------------------------------------------------
; Delete any task associated with the entity
playfield_entity_delete_tasks private seg_entity

                            debugtag 'delete_tasks_playfield_entity'

                            phx

                            getword {x},>entities_root+playfield_entity~task1_ptr+2
                            beq no_task1
                            pha
                            getword {x},>entities_root+playfield_entity~task1_ptr
                            pha
                            jsl task_manager_free_task

no_task1                    plx

                            getword {x},>entities_root+playfield_entity~task2_ptr+2
                            beq no_task2
                            pha
                            getword {x},>entities_root+playfield_entity~task2_ptr
                            pha
                            jsl task_manager_free_task
no_task2                    rtl

                            end

; -----------------------------------------------------------------------------
; Check to see if an animated entity needs its frame changed.
; Parameters:
;  x-reg            - short pointer to the entity
; Returns:
;  In ACC
;   0 if frame did not cross a loop boundry
;   1 if crossed forward
;   2 if crossed backward
;  In X
;   0 not looped
;   1 looped
;
; Note, if the animation is not set to loop, this will still return 1 or 2, but
; the frame will not actually cross the boundry.  This helps detect when an animation
; is completed.
playfield_entity_frame_change start seg_entity
                            using gameplay_manager_data

                            debugtag 'frame_change'
                            debugtag 'entity'

                            begin_locals
result                      decl dword
pList                       decl ptr
wTimer                      decl word
work_area_size              end_locals
                            sub ,work_area_size

                            stz <result
                            stz <result+2

; Do we have a timer?
                            getword {x},>entities_root+playfield_entity~frame_animation_timer
                            jeq none
; Check the update rate
                            sec
; It would be great to pass this in, but every place this function is called, uses this fixed value,
; so it is best to just use this directly.
                            sbc >gameplay_manager_logic~tick_delta
                            beq next
                            bcc next
                            putword {x},>entities_root+playfield_entity~frame_animation_timer
                            brl none
; We are changing the frame
next                        anop
;                           sta <wTimer

; Reset the timer.  Should probably add in the underflow.
                            getword {x},>entities_root+playfield_entity~frame_animation_rate
                            putword {x},>entities_root+playfield_entity~frame_animation_timer

; Get how the animation runs.
; This is being 'generic' and looking at the framelib list for the animation type.  Should I even bother?
; I've already ditched using the framelib_animation~base_rate, and I'm using a rate in the entity itself, mostly
; so I can randomize it.  Nothing else in the game is going to do anything other than 'frame advance'
; so I could save some cycles by just having that code pathway here, or add the animation_type to the entity as well.
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~collection_bank,<pList+2
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~list_sptr,<pList
                            getword [<pList],#framelib_list~animation+framelib_animation~type
                            beq forward
                            cmp #framelib_animation_type~frame_advance
                            beq forward
                            cmp #framelib_animation_type~frame_reverse
                            jne none
; going backward
                            getword [<pList],#framelib_list~animation+framelib_animation~options
;                           bit #framelib_animation_options~looped
                            lsr a                           ; doing this is faster to test bit 0
                            bcs backward_looped

                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame
                            beq would_backward_cross
                            ldy #frame_change~no_crossing
                            dec a
                            bra ok
would_backward_cross        ldy #frame_change~crossed_backward          ; no frame change, but we want to return our result
                            sty <result
                            bra none

; backward, and looping
backward_looped             inc <result+2                           ; signal that this ws looped
                            ldy #frame_change~no_crossing
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame
                            dec a
                            bpl ok
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame_count
                            dec a
                            ldy #frame_change~crossed_backward
                            bra exit

forward                     anop
                            getword [<pList],#framelib_list~animation+framelib_animation~options
;                           bit #framelib_animation_options~looped
                            lsr a                           ; doing this is faster to test bit 0
                            bcs forward_looped
; forward, no looping
                            ldy #frame_change~no_crossing
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame
                            inc a
                            cmpword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame_count
                            blt ok
                            ldy #frame_change~crossed_forward        ; no change, but we want to return our result
                            sty <result
                            bra none

; forward, with looping
forward_looped              inc <result+2                           ; signal that this ws looped
                            ldy #frame_change~no_crossing
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame
                            inc a
                            cmpword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame_count
                            blt ok
                            lda #0
                            ldy #frame_change~crossed_forward

exit                        cmpword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame      ; changed?
                            beq none
; Yes
ok                          putword {x},>entities_root+playfield_entity~grentity+grlib_entity~frame+framelib_entity~frame
                            sty <result
; Signal that it changed
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~changed
                            ora #grlib_entity~changed_frame_index
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~changed

none                        ret 4:result
                            end

; -----------------------------------------------------------------------------
; Get the view space x/y from an entity.
; This will take into account if the entity is a child
; Not exactly fast...
; Parameters:
; x-reg         - short pointer to entity
playfield_entity_get_xy     start seg_entity

                            debugtag 'get_xy_playfield_entity'

                            begin_locals
pParent                     decl ptr
wTargetX                    decl word
wTargetY                    decl word
work_area_size              end_locals

                            sub ,work_area_size

                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~parent_entity_ptr+2
                            beq no_parent
                            sta <pParent+2
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~parent_entity_ptr
                            sta <pParent

; We have to get the child absolute position
is_child                    getword [<pParent],#playfield_entity~grentity+grlib_entity~x
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            sta <wTargetX

                            getword [<pParent],#playfield_entity~grentity+grlib_entity~y
                            clc
                            adcword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            sta <wTargetY

                            bra exit

; Input is the parent
no_parent                   anop
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            sta <wTargetX
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                            sta <wTargetY

exit                        ret 4:wTargetX
                            end

;
; Support functions
;

; --------------------------------------------------------------------------------------------
; Get the speed vector based on a direction value and a speed value
; This is essentially turning a polar vector into an x / y vector.
;
; Parameters:
; wDirection        - the direction of the vector
; wSpeed            - the speed (indexed magnitude) of the vector
; Returns:
; speed x in A, speed y in x
playfield_get_speed         start seg_entity
                            using playfield_entity_manager_data
                            using math_tables

                            begin_locals
pSpeedTable                 decl ptr
wSpeedX                     decl word
wSpeedY                     decl word
work_area_size              end_locals

                            debugtag 'get_speed'

                            sub (2:wDirection,2:wSpeed),work_area_size

; The speed, is the magnitude of the movement vector, get the appropriate rotated vector table
                            lda <wSpeed
                            bne has_speed
                            stz <wSpeedX
                            stz <wSpeedY
                            bra exit

has_speed                   anop
                            dec a
                            asl a
                            asl a
                            tax
                            lda >math~dir_32_rot_to_mag_8_steps_32,x
                            sta <pSpeedTable
                            lda >math~dir_32_rot_to_mag_8_steps_32+2,x
                            sta <pSpeedTable+2
; Get the vector for the rotation.
                            lda <wDirection
                            asl a                                           ; 2 words per entry, x delta / y delta
                            asl a
                            tay
                            phy
                            lda [<pSpeedTable],y                            ; x
                            sta <wSpeedX
                            ply
                            iny
                            iny
                            lda [<pSpeedTable],y                            ; y
                            sta <wSpeedY

exit                        ret 4:wSpeedX
                            end

; -----------------------------------------------------------------------------
; Do a fairly quick but smooth decelerate
; Parameters:
; x-reg  - entity short pointer
playfield_entity_decelerate start seg_entity
                            using player_entity_data

                            debugtag 'decelerate'
                            debugtag 'playfield_entity'

                            pha                                 ; create a temporary on the stack

                            getword {x},>entities_root+playfield_entity~speed_x
                            beq no_x

                            ldx #231             ; about .902, in fp16
                            jsl math~mul2r4
; Convert back to fp16, this is doing a >> 8 on the 32 bit result
                            xba
                            and #$00ff
                            sta 1,s
                            txa
                            xba
                            and #$ff00
                            ora 1,s
                            ldx #player_entity_instance
                            putword {x},>entities_root+playfield_entity~speed_x

no_x                        anop
                            getword {x},>entities_root+playfield_entity~speed_y
                            beq no_y

                            ldx #231             ; about .902, in fp16
                            jsl math~mul2r4
; Convert back to fp16, this is doing a >> 8 on the 32 bit result
                            xba
                            and #$00ff
                            sta 1,s
                            txa
                            xba
                            and #$ff00
                            ora 1,s
                            ldx #player_entity_instance
                            putword {x},>entities_root+playfield_entity~speed_y

no_y                        anop
                            pla                                     ; remove the temporary
                            rtl

                            end
