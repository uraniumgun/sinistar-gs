                            copy lib/source/debug.definitions.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm

                            copy lib/source/grlib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            copy source/app.system.ids.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/warrior.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm

                            mcopy generated/warrior.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
warrior_entity_data         data seg_entity
                            using gameplay_caller_logic_data

warrior_entity_image_collection_id equ '1RAW'

; Preloaded images
preloaded~warrior_framelib  ds sizeof~framelib_entity

                            end

; -----------------------------------------------------------------------------
; Preload images the warrior entity uses
; Returns:
; carry clear, if successful
warrior_entity_preload_images start seg_entity
                            using warrior_entity_data

                            debugtag 'preload_images'
; Pre-load images
                            pushptr #preloaded~warrior_framelib
                            pushdword #warrior_entity_image_collection_id
                            jsl playfield_preload_framelib_collection

                            rtl

                            end

; -----------------------------------------------------------------------------
; Parameters:
; x-reg             - the entity short pointer
warrior_entity_construct    start seg_entity
                            using warrior_entity_data

                            debugtag 'construct_warrior_entity'

                            phx
                            txy
                            jsl playfield_entity_construct
                            bcs failed

                            lda 1,s                                                     ; get saved pointer
                            tax
                            lda #entity_type~warrior
                            putword {x},>entities_root+playfield_entity~type

; Set the characteristic id
                            lda #id_characteristic_warrior
                            putword {x},>entities_root+playfield_entity~characteristic_id

; Set the the warrior uses its turret direction as the visual direction.
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_use_turret
                            putword {x},>entities_root+playfield_entity~state_flags

; Set the framelib collection / set
; Note, short pointer to entity is already on the stack
                            pushptr #preloaded~warrior_framelib                      ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            pushsword #0                ; variation
                            jsl playfield_entity_set_collection_from_preload

                            clc
exit                        anop
                            rtl

failed                      plx                                                         ; clear saved pointer
                            lda #system_id_warrior_entity_manager+app_error_allocation_failed
                            jsl appdebug_set_last_error
                            bra exit

                            end

; -----------------------------------------------------------------------------
warrior_entity_destruct     private seg_entity

                            debugtag 'destruct'
                            debugtag 'warrior_entity'

                            begin_locals
work_area_size              end_locals

                            lsub ,work_area_size

                            jsl playfield_entity_destruct

                            lret

                            end

; -----------------------------------------------------------------------------
; Create a new warrior entity
warrior_entity_new          start seg_entity
                            using warrior_entity_manager_data

                            debugtag 'new_warrior_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

; Allocate an empty buffer
                            jsl playfield_entity_allocate
                            bcs allocation_error
                            putretptr <pEntity

                            tax                                     ; short pointer to entity
                            jsl warrior_entity_construct
                            bcs failed

exit                        retkc 4:pEntity
failed                      anop
                            ldx <pEntity
                            jsl playfield_entity_deallocate
allocation_error            anop
                            clearptr <pEntity
                            sec                                     ; error
                            bra exit

                            end

; -----------------------------------------------------------------------------
; Uninitialize the warrior entity.
warrior_entity_delete       start seg_entity

                            txy
                            beq exit

                            phx
;                           jsr warrior_entity_destruct
                            jsl playfield_entity_destruct
                            plx
                            jsl playfield_entity_deallocate

exit                        rtl
                            end

                            ago .skip
; -----------------------------------------------------------------------------
; Add the warrior entity to the playfield
; Deprecated, use inline_entity_add_to_playlist
warrior_entity_add_to_playfield start seg_entity
                            using warrior_entity_data

                            debugtag 'add_to_playfield'
                            debugtag 'warrior_entity'

; Set that this is the first update
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_first_update
                            putword {x},>entities_root+playfield_entity~state_flags

                            rtl
                            end
.skip

; -----------------------------------------------------------------------------
; Remove the warrior entity from the playfield
warrior_entity_remove_from_playfield start seg_entity
                            using warrior_entity_data

                            debugtag 'remove_from_playfield_warrior_entity'

; Make sure this is on, so we get removed from the collision list
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword {x},>entities_root+playfield_entity~state_flags
; Invalidate
                            jsl playfield_entity_invalidate_sprite

                            rtl
                            end

; -----------------------------------------------------------------------------
; Handler for when a warrior is 'marked for removal'
; Parameters:
; y-reg         - entity short pointer
warrior_entity_remove_handler start seg_entity
                            using warrior_entity_manager_data

                            debugtag 'remove_handler_warrior_entity'

                            ldx warrior_entity_next_remove_index
                            tya
                            sta warrior_entity_remove_array,x
                            inx
                            inx
                            stx warrior_entity_next_remove_index
                            inc warrior_entity_remove_count

                            rts
                            end
