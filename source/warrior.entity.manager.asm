
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
                                copy source/warrior.entity.definitions.asm
                                copy source/gameplay.constants.asm

                                mcopy generated/warrior.entity.manager.macros

                                longa on
                                longi on

; Manager for all the 'warrior' entities

; --------------------------------------------------------------------------------------------
warrior_entity_manager_data     data seg_entity

global_warrior_entity_manager_is_initialized dc i'0'

max_warrior_entity_count        equ 32
warrior_entity_limit            dc i'max_warrior_entity_count'              ; dynamic limit
warrior_entity_count            dc i'0'
warrior_entity_array            ds max_warrior_entity_count*2

warrior_entity_next_remove_index dc i'0'
warrior_entity_remove_count     dc i'0'
warrior_entity_remove_array     ds max_warrior_entity_count*2

                                end

; --------------------------------------------------------------------------------------------
; Initialize the global warrior entity manager.
; This will allocate the global_warrior_entity_manager object and make it ready for use.
; It will allocate a pool for managing entity instances.
;
; Note that this manager provides the fixed buffer object for the entities, however the allocation
; and deallocation is done in the playfield.entity.asm file, using warrior_entity_new and warrior_entity_delete
;
warrior_entity_manager_initialize start seg_entity
                                using warrior_entity_manager_data

                                debugtag 'initialize'
                                debugtag 'warrior_entity_manager'

                                setlocaldatabank
                                lda global_warrior_entity_manager_is_initialized
                                bne is_initialized

                                jsl warrior_entity_preload_images

                                stz warrior_entity_count
                                stz warrior_entity_remove_count
                                stz warrior_entity_next_remove_index

                                lda #1
                                sta >global_warrior_entity_manager_is_initialized

is_initialized                  anop
                                restoredatabank
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
warrior_entity_manager_uninitialize start seg_entity
                                using warrior_entity_manager_data

                                debugtag 'uninitialize'
                                debugtag 'warrior_entity_manager'

                                lda >global_warrior_entity_manager_is_initialized
                                beq exit

                                jsl warrior_entity_manager_remove_all

                                lda #0
                                sta >global_warrior_entity_manager_is_initialized

exit                            anop
                                rtl

                                end

; ----------------------------------------------------------------------------
; Remove all warriors
warrior_entity_manager_remove_all start seg_entity
                                using appdata
                                using warrior_entity_data
                                using warrior_entity_manager_data
                                using task_manager_data
                                using gameplay_level_data

                                debugtag 'remove_all'

                                begin_locals
spEntity                        decl word
work_area_size                  end_locals

                                sub ,work_area_size

                                setlocaldatabank
; Delete all the allocated warriors
                                lda warrior_entity_count
                                beq none
                                dec a
                                asl a
                                tax

loop                            phx

                                lda warrior_entity_array,x
                                sta <spEntity
                                tax
; Remove from playfield
                                jsl warrior_entity_remove_from_playfield
; Delete
                                ldx <spEntity
                                jsl warrior_entity_delete
                                plx
                                dex
                                dex
                                bpl loop

done                            anop
                                stz warrior_entity_count

none                            anop
                                stz warrior_entity_remove_count
                                stz warrior_entity_next_remove_index
                                restoredatabank
                                ret
                                end

; ----------------------------------------------------------------------------
; Add a warrior to the playfield
; Parameters:
; wX        x location
; wY        y location
warrior_entity_manager_add_warrior start seg_entity
                            using appdata
                            using warrior_entity_data
                            using warrior_entity_manager_data
                            using gameplay_level_data
                            using task_manager_data

                            debugtag 'warrior_add'

                            begin_locals
wSlotIndex                  decl word
work_area_size              end_locals

                            sub (2:wX,2:wY),work_area_size

                            setlocaldatabank
;                            brl too_many                        ; Disable

                            lda warrior_entity_count
                            cmp warrior_entity_limit
                            jge too_many
                            asl a
                            sta <wSlotIndex

                            jsl warrior_entity_new
                            bcs error

                            inc warrior_entity_count

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta warrior_entity_array,y

                            lda <wX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

; Set a random direction
                            generate_rnd16
                            and #playfield_entity~direction_range_mask

                            putword {x},>entities_root+playfield_entity~direction
                            putword {x},>entities_root+playfield_entity~desired_direction

                            jsl gameplay_warrior_initialize

; The rest of the warrior setup will be done when its mission code is updated.

too_many                    anop
error                       anop
                            restoredatabank

                            ret
                            end

; ----------------------------------------------------------------------------
; This updates the animation of all, on screen warriors.
gameplay_all_warriors_update_tick start seg_entity
                            using appdata
                            using warrior_entity_data
                            using warrior_entity_manager_data
                            using gameplay_warrior_logic_data
                            using gameplay_level_data
                            using applib_data

                            debugtag 'warriors_update_tick'

                            begin_locals
spEntity                    decl word
wLastEntitySlot             decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Loop over the warriors, backward.
                            lda warrior_entity_count
                            jeq done_update
                            dec a
                            asl a
                            tax

loop                        phx

; Only need the short pointer in this loop
                            lda warrior_entity_array,x
                            sta <spEntity
                            tax

; Is this set to be removed?
                            getword {x},>entities_root+playfield_entity~state_flags
                            jmi on_removal_list

; On screen or off?
                            bit #playfield_entity~state_on_collision_list
                            beq offscreen
; On screen
; Decrement the bounce counter
                            bit #playfield_entity~state_bounce_bits
                            beq no_bounce_bits                          ; already 0?
                            dec a                                       ; we know they are the lower bits, so we can just dec
                            putword {x},>entities_root+playfield_entity~state_flags
no_bounce_bits              anop

; Not checking the first-update flag for this type.

                            jsl playfield_entity_update_direction               ; will not change x
                            jsl playfield_entity_update_position                ; will not change x

                            bra was_onscreen

offscreen                   jsl playfield_entity_update_direction_offscreen     ; will not change x
                            jsl playfield_entity_update_position_offscreen      ; will not change x

was_onscreen                anop
; Update the framelib values
just_draw                   anop
                            getword {x},>entities_root+grlib_entity~changed
                            beq no_framelib_update

                            setdatabanktolabel entities_root
                            jsl grlib_entity_update_framelib
                            restoredatabank
; Invalidate
                            ldx <spEntity
no_framelib_update          anop
; If we need an erase, are to be removed, or is on screen, then do a full invalidate, else
; just do a quick, "are we on screen" check
                            getword {x},>entities_root+sprite~info
                            bmi full_check          ; erase?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list+playfield_entity~state_marked_for_removal ; on-screen or to-be-removed?
                            bne full_check

; Off screen and we don't have anything to add to the update rects, do a quick check
; The coordinates of the object are in world space, compare in view space.
                            getword {x},>entities_root+grlib_entity~x
                            sec
                            sbcword {x},>entities_root+sprite~offset_x
                            cmp #gameplay_ui_playfield_width-gameplay_ui_playfield_center_x
                            bsge clipped

                            clc
                            adcword {x},>entities_root+sprite~width
                            cmp #-gameplay_ui_playfield_center_x
                            bslt clipped

                            getword {x},>entities_root+grlib_entity~y
                            sec
                            sbcword {x},>entities_root+sprite~offset_y
                            cmp #gameplay_ui_playfield_height-gameplay_ui_playfield_center_y
                            bsge clipped

                            clc
                            adcword {x},>entities_root+sprite~height
                            cmp #-gameplay_ui_playfield_center_y
                            bslt clipped

full_check                  anop
; Not clipped, we must be going on-screen
                            jsl playfield_entity_invalidate_sprite

clipped                     anop
on_removal_list             anop
                            plx
                            beq done_update
                            dex
                            dex
                            jmp loop

done_update                 anop

; Do any removals
                            lda warrior_entity_remove_count
                            beq done_remove
                            dec a
                            asl a
                            tax

loop_remove                 phx

; We will need to know the last slot index
                            lda warrior_entity_count
                            dec a
                            asl a
                            sta <wLastEntitySlot

                            lda warrior_entity_remove_array,x
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

                            jsl warrior_entity_remove_from_playfield

                            ldx <spEntity
                            jsl warrior_entity_delete           ; do the delete

                            ply                                 ; get the slot index back
                            cpy <wLastEntitySlot
                            beq is_last_slot                    ; last slot?
; Move the last, into the vacated slot
                            ldx <wLastEntitySlot
                            lda warrior_entity_array,x
                            sta warrior_entity_array,y
                            stz warrior_entity_array,x
; Update the moved entity's slot index
                            tax
                            tya
                            putword {x},>entities_root+playfield_entity~manager_slot_index
is_last_slot                dec warrior_entity_count

                            plx
                            dex
                            dex
                            bpl loop_remove

done_remove                 anop
                            stz warrior_entity_remove_count
                            stz warrior_entity_next_remove_index

                            restoredatabank

                            ret
                            end

; ----------------------------------------------------------------------------
; Toggle the disabled state of the warriors.
; Just enables or disabled the creation of warriors, it will not
; kill any existing ones, if it goes to disabled.  Might change in the future.
warrior_entity_manager_toggle_disabled start seg_entity
                            using warrior_entity_manager_data

                            debugtag 'toggle_disabled'

                            setlocaldatabank

                            lda warrior_entity_limit
                            beq turn_on

                            stz warrior_entity_limit
                            bra exit

turn_on                     lda #max_warrior_entity_count
                            sta warrior_entity_limit

exit                        restoredatabank
                            rtl
                            end
