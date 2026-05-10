                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/fixed.buffer.pool.definitions.asm
                                copy lib/source/grlib.definitions.asm
                                copy lib/source/grlib.sprite.definitions.asm
                                copy lib/source/framelib.definitions.asm
                                copy lib/source/grlib.entity.definitions.asm

                                copy source/app.system.ids.asm
                                copy source/playfield.entity.definitions.asm
                                copy source/crystal.entity.definitions.asm
                                mcopy generated/crystal.entity.manager.macros

                                longa on
                                longi on

; Manager for all the 'crystal' entities

; --------------------------------------------------------------------------------------------
crystal_entity_manager_data     data seg_entity

crystal_logic~update_rate       equ 2

global_crystal_entity_manager_is_initialized dc i'0'

max_crystal_entity_count            equ 32
crystal_entity_count                dc i'0'
crystal_entity_array                ds max_crystal_entity_count*2

crystal_entity_next_remove_index    dc i'0'
crystal_entity_remove_count         dc i'0'
crystal_entity_remove_array         ds max_crystal_entity_count*2

                                end

; --------------------------------------------------------------------------------------------
; Initialize the global crystal entity manager.
; This will allocate the global_crystal_entity_manager object and make it ready for use.
; It will allocate a pool for managing entity instances.
;
; Note that this manager provides the fixed buffer object for the entities, however the allocation
; and deallocation is done in the playfield.entity.asm file, using crystal_entity_new and crystal_entity_delete
;
crystal_entity_manager_initialize  start seg_entity
                                using crystal_entity_manager_data

                                debugtag 'initialize'
                                debugtag 'crystal_entity_manager'

                                lda >global_crystal_entity_manager_is_initialized
                                bne is_initialized

                                jsl crystal_entity_preload_images

                                lda #1
                                sta >global_crystal_entity_manager_is_initialized

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
crystal_entity_manager_uninitialize start seg_entity
                                using crystal_entity_manager_data

                                debugtag 'uninitialize'
                                debugtag 'crystal_entity_manager'

                                lda >global_crystal_entity_manager_is_initialized
                                beq exit

                                lda #0
                                sta >global_crystal_entity_manager_is_initialized

exit                            anop
                                rtl

                                end

; ----------------------------------------------------------------------------
; Add a crystal to the playfield
; Parameters:
; wX        x location
; wY        y location
; wSpeedX   starting speed x
; wSpeedY   starting speed y
crystal_entity_manager_add_crystal start seg_entity
                            using appdata
                            using crystal_entity_data
                            using crystal_entity_manager_data
                            using gameplay_level_data

                            debugtag 'crystal_add'

                            begin_locals
spEntity                    decl word
wSlotIndex                  decl word
work_area_size              end_locals

                            sub (2:wX,2:wY,2:wSpeedX,2:wSpeedY),work_area_size

                            setlocaldatabank
;                            brl too_many                        ; Disable

                            lda crystal_entity_count
                            cmp #max_crystal_entity_count
                            jge too_many
                            asl a
                            sta <wSlotIndex
; Just doing one for now
                            jsl crystal_entity_new
                            bcs error

                            inc crystal_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta crystal_entity_array,y

; Do this in the constructor?
                            jsl gameplay_crystal_initialize

                            ldx <spEntity
                            lda <wX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

; Set the speed
                            lda <wSpeedX
                            putword {x},>entities_root+playfield_entity~speed_x
                            lda <wSpeedY
                            putword {x},>entities_root+playfield_entity~speed_y

; Set the direction to 0.  This is not correct, in that it is not going in the direction we just set the speed to.
; but it won't change anything either.
                            lda #0
                            putword {x},>entities_root+playfield_entity~direction
                            putword {x},>entities_root+playfield_entity~desired_direction

; This is more correct, but slower
;                           ldx <wSpeedX
;                           lda <wSpeedY
;                           jsl math~vec2_angle
;                           shiftright 3                                                ; only want 0-31
;                           ldx <spEntity
;                           putword {x},>entities_root+playfield_entity~direction
;                           putword {x},>entities_root+playfield_entity~desired_direction

too_many                    anop
error                       anop
                            restoredatabank

                            ret
                            end

; ----------------------------------------------------------------------------
crystal_entity_manager_remove_all start seg_entity
                            using crystal_entity_data
                            using crystal_entity_manager_data
                            using gameplay_level_data

                            debugtag 'remove_all'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Delete all the allocated crystals
                            lda crystal_entity_count
                            beq none
                            dec a
                            asl a
                            tax

loop                        phx

                            lda crystal_entity_array,x
                            sta <spEntity
                            tax
; Remove from playfield
                            jsl crystal_entity_remove_from_playfield
; Delete
                            ldx <spEntity
                            jsl crystal_entity_delete

                            plx
                            dex
                            dex
                            bpl loop

done                        anop
                            stz crystal_entity_count

none                        anop
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
gameplay_all_crystals_update_tick start seg_entity
                            using appdata
                            using crystal_entity_data
                            using crystal_entity_manager_data
                            using gameplay_level_data
                            using gameplay_manager_data
                            using applib_data

                            debugtag 'crystal_logic_tick'

                            begin_locals
spEntity                    decl word
wLastEntitySlot             decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Loop over the crystals, backward.
                            lda crystal_entity_count
                            beq done_update
                            dec a
                            asl a
                            tax

loop                        phx

; Only need the short pointer in this loop
                            lda crystal_entity_array,x
                            sta <spEntity
                            tax

; Is this set to be removed?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi on_removal_list

; On screen or off?
                            bit #playfield_entity~state_on_collision_list
                            beq offscreen
; On screen
; Not checking the first-update flag for this type.
                            jsl playfield_entity_update_position                ; will not change x
                            jsl playfield_entity_frame_change
                            ldx <spEntity
                            bra was_onscreen

offscreen                   jsl playfield_entity_update_position_offscreen      ; will not change x

was_onscreen                anop
; Update the framelib values
                            getword {x},>entities_root+grlib_entity~changed
                            beq no_framelib_update

                            setdatabanktolabel entities_root
                            jsl grlib_entity_update_framelib
                            restoredatabank
; Invalidate
                            ldx <spEntity
no_framelib_update          jsl playfield_entity_invalidate_sprite

on_removal_list             anop

                            plx
                            dex
                            dex
                            bpl loop

done_update                 anop

; Do any removals
                            lda crystal_entity_remove_count
                            beq done_remove
                            dec a
                            asl a
                            tax

loop_remove                 phx

; We will need to know the last slot index
                            lda crystal_entity_count
                            dec a
                            asl a
                            sta <wLastEntitySlot

                            lda crystal_entity_remove_array,x
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

                            jsl crystal_entity_remove_from_playfield

                            ldx <spEntity
                            jsl crystal_entity_delete

                            ply                                 ; get the slot index back
                            cpy <wLastEntitySlot
                            beq is_last_slot                    ; last slot?
; Move the last, into the vacated slot
                            ldx <wLastEntitySlot
                            lda crystal_entity_array,x
                            sta crystal_entity_array,y
                            stz crystal_entity_array,x
; Update the moved entity's slot index
                            tax
                            tya
                            putword {x},>entities_root+playfield_entity~manager_slot_index
is_last_slot                dec crystal_entity_count

                            plx
                            dex
                            dex
                            bpl loop_remove

done_remove                 anop
                            stz crystal_entity_remove_count
                            stz crystal_entity_next_remove_index

exit                        anop
                            restoredatabank

                            ret
                            end
