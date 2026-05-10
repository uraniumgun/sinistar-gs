                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/fixed.buffer.pool.definitions.asm
                                copy lib/source/grlib.definitions.asm
                                copy lib/source/grlib.sprite.definitions.asm
                                copy lib/source/framelib.definitions.asm
                                copy lib/source/grlib.entity.definitions.asm
                                copy lib/source/grlib.entity.sort.definitions.asm

                                copy source/app.system.ids.asm
                                copy source/gameplay.constants.asm
                                copy source/playfield.definitions.asm
                                copy source/playfield.entity.definitions.asm

                                mcopy generated/shot.entity.manager.macros

                                longa on
                                longi on

; Manager for all the 'shot' entities

; --------------------------------------------------------------------------------------------
shot_entity_manager_data        data seg_entity

; Entity Manager object
shot_entity_manager~pool        gequ 0
sizeof~shot_entity_manager      gequ shot_entity_manager~pool+sizeof~fixed_buffer_pool

global_shot_entity_manager_is_initialized dc i'0'

; The global entity manager
global_shot_entity_manager      ds sizeof~shot_entity_manager

shot_update~update_rate         equ 1                                   ; Update every frame

max_shot_entity_count           equ 64
shot_entity_count               dc i'0'
shot_entity_array               ds max_shot_entity_count*2

shot_entity_next_remove_index   dc i'0'
shot_entity_remove_count        dc i'0'
shot_entity_remove_array        ds max_shot_entity_count*2

                                end

; --------------------------------------------------------------------------------------------
; Initialize the global shot entity manager.
; This manages 'shots' for all sources, which are the player and the warrior.
;
shot_entity_manager_initialize  start seg_entity
                                using shot_entity_manager_data

                                debugtag 'initialize'
                                debugtag 'shot_entity_manager'

                                lda >global_shot_entity_manager_is_initialized
                                bne is_initialized

                                jsl shot_entity_preload_images

                                lda #1
                                sta >global_shot_entity_manager_is_initialized

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
shot_entity_manager_uninitialize start seg_entity
                                using shot_entity_manager_data

                                debugtag 'uninitialize'
                                debugtag 'shot_entity_manager'

                                lda >global_shot_entity_manager_is_initialized
                                beq exit


                                lda #0
                                sta >global_shot_entity_manager_is_initialized

exit                            anop
                                rtl

                                end

; ----------------------------------------------------------------------------
; Remove all shots
shot_entity_manager_remove_all  start seg_entity
                                using appdata
                                using shot_entity_data
                                using shot_entity_manager_data
                                using task_manager_data
                                using gameplay_level_data

                                debugtag 'remove_all'

                                begin_locals
spEntity                        decl word
work_area_size                  end_locals

                                sub ,work_area_size

                                setlocaldatabank
; Delete all the allocated warriors
                                lda shot_entity_count
                                beq none
                                dec a
                                asl a
                                tax

loop                            phx

                                lda shot_entity_array,x
                                sta <spEntity
; Remove from playfield
                                tax
                                jsl shot_entity_remove_from_playfield
; Delete
                                ldx <spEntity
                                jsl shot_entity_delete
                                plx
                                dex
                                dex
                                bpl loop

done                            anop
                                stz shot_entity_count

none                            anop
                                restoredatabank
                                ret
                                end

; ----------------------------------------------------------------------------
; Add a shot to the playfield
; Parameters:
; wType         type.  Some defaults will be set from this, such as velocity
; wX            x location
; wY            y location
; wDirection    direction of travel
; wXAdjust      amount to add to the x axis
; wYAdjust      amount to add to the y axis
shot_entity_manager_add_shot start seg_entity
                            using appdata
                            using shot_entity_data
                            using shot_entity_manager_data
                            using task_manager_data
                            using gameplay_level_data

                            debugtag 'add_shot'

                            begin_locals
spEntity                    decl word
wSlotIndex                  decl word
pType                       decl ptr
work_area_size              end_locals

                            sub (2:wType,2:wX,2:wY,2:wDirection,2:wXAdjust,2:wYAdjust),work_area_size

                            setlocaldatabank

                            lda shot_entity_count
                            cmp #max_shot_entity_count
                            jge too_many
                            asl a
                            sta <wSlotIndex

                            pushsword <wType
                            jsl shot_entity_new
                            bcs error

                            inc shot_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta shot_entity_array,y

                            lda <wX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

                            ldx <spEntity
                            lda <wDirection
                            putword {x},>entities_root+playfield_entity~desired_direction
                            jsl playfield_entity_set_direction

; Get the speed from the type.  Overkill?  Maybe just pass the speed in too?
                            lda <wType
                            asl a
                            asl a
                            tax
                            lda shot_entity_types,x
                            sta <pType
                            lda shot_entity_types+2,x
                            sta <pType+2
                            getword [<pType],#shot_characteristic~speed

                            pushsword <spEntity                                ; assuming this will not update A
                            pushsword <wDirection
                            pha
                            pushsword <wXAdjust
                            pushsword <wYAdjust
                            jsl playfield_entity_set_adjusted_speed

; Make sure the framelib is correct for the direction, after that, we don't have to update it again.
                            ldx <spEntity
                            setdatabanktolabel entities_root
                            jsl grlib_entity_update_framelib
                            restoredatabank

too_many                    anop
error                       anop
                            restoredatabank

                            ret
                            end

; --------------------------------------------------------------------------------------------
gameplay_shots_initialize   start seg_entity
                            using shot_entity_manager_data

                            rtl
                            end

; --------------------------------------------------------------------------------------------
gameplay_shots_uninitialize start seg_entity
                            using shot_entity_manager_data

                            jsl shot_entity_manager_remove_all

                            rtl
                            end

; --------------------------------------------------------------------------------------------
gameplay_shots_state_deactivate start seg_entity
                            using shot_entity_manager_data

                            debugtag 'shots_state_deactivate'

                            jsl shot_entity_manager_remove_all

                            rtl
                            end

; ----------------------------------------------------------------------------
; This updates the animation of all, on screen shots.
gameplay_all_shots_update_tick start seg_entity
                            using appdata
                            using shot_entity_data
                            using shot_entity_manager_data
                            using applib_data
                            using gameplay_level_data

                            debugtag 'shots_update_tick'

                            begin_locals
spEntity                    decl word
wLastEntitySlot             decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Loop over the workers, backward.
                            lda shot_entity_count
                            beq done_update
                            dec a
                            asl a
                            tax

loop_update                 phx

; Only need short pointer in this loop
                            lda shot_entity_array,x
                            sta <spEntity
                            tax

; Is this set to be removed?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi already_on_removal_list

                            bit #playfield_entity~state_first_update
                            beq update_state
; First update, we don't want to adjust any position or frame, just draw it
                            and #((playfield_entity~state_first_update*-1)-1)
                            putword {x},>entities_root+playfield_entity~state_flags
                            bra just_draw

update_state                anop
; Note, not bothering to update direction, it should not change.
                            jsl playfield_entity_update_position

just_draw                   anop
; Update the framelib values
; Are we going to allow for animated shots?  If not, this is not needed
;                           ldx <spEntity
;                           setdatabanktolabel entities_root
;                           jsl grlib_entity_update_framelib
;                           restoredatabank

; Invalidate
                            ldx <spEntity
                            jsl playfield_entity_invalidate_sprite
                            bcc still_on_screen
; Not on screen anymore, mark it for removal
                            ldx <spEntity
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal+playfield_entity~state_removed_from_screen
                            putword {x},>entities_root+playfield_entity~state_flags

                            ldx shot_entity_next_remove_index
                            lda <spEntity
                            sta shot_entity_remove_array,x
                            inx
                            inx
                            stx shot_entity_next_remove_index
                            inc shot_entity_remove_count

already_on_removal_list     anop
still_on_screen             anop
                            plx
                            dex
                            dex
                            bpl loop_update

done_update                 anop

; Do any removals
                            lda shot_entity_remove_count
                            beq done_remove
                            dec a
                            asl a
                            tax

loop_remove                 phx

; We will need to know the last slot index
                            lda shot_entity_count
                            dec a
                            asl a
                            sta <wLastEntitySlot

                            lda shot_entity_remove_array,x
                            sta <spEntity
                            tax

                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_removed_from_screen
                            bne already_removed_from_screen

                            jsl playfield_entity_invalidate_sprite
                            ldx <spEntity

already_removed_from_screen anop
; Get the slot we are in
                            getword {x},>entities_root+playfield_entity~manager_slot_index
                            pha                                 ; save it

                            jsl shot_entity_remove_from_playfield

                            ldx <spEntity
                            jsl shot_entity_delete
                            ply                                 ; get the slot index back
                            cpy <wLastEntitySlot
                            beq is_last_slot                    ; last slot?
; Move the last, into the vacated slot
                            ldx <wLastEntitySlot
                            lda shot_entity_array,x
                            sta shot_entity_array,y
                            stz shot_entity_array,x
; Update the moved entity's slot index
                            tax
                            tya
                            putword {x},>entities_root+playfield_entity~manager_slot_index
is_last_slot                dec shot_entity_count

                            plx
                            dex
                            dex
                            bpl loop_remove

done_remove                 anop
                            stz shot_entity_remove_count
                            stz shot_entity_next_remove_index

exit                        anop
                            restoredatabank

                            ret
                            end
