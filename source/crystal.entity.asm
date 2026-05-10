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
                            copy source/crystal.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm

                            mcopy generated/crystal.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
crystal_entity_data         data seg_entity

crystal_entity_image_collection_id equ '1YRC'

; Preloaded images
preloaded~crystal_framelib  ds sizeof~framelib_entity

                            end

; -----------------------------------------------------------------------------
; Preload images the crystal entity uses
; Returns:
; carry clear, if successful
crystal_entity_preload_images start seg_entity
                            using crystal_entity_data

                            debugtag 'preload_images'
; Pre-load images
                            pushptr #preloaded~crystal_framelib
                            pushdword #crystal_entity_image_collection_id
                            jsl playfield_preload_framelib_collection

                            rtl

                            end

; -----------------------------------------------------------------------------
; Parameters:
; x-reg             - the entity short pointer
crystal_entity_construct    start seg_entity
                            using crystal_entity_data

                            debugtag 'construct_crystal_entity'

                            setlocaldatabank

                            phx
                            txy
                            jsl playfield_entity_construct
                            bcs failed

                            lda 1,s                                                     ; get saved pointer
                            tax
                            lda #entity_type~crystal
                            putword {x},>entities_root+playfield_entity~type

; Set the characteristic id
                            lda #id_characteristic_crystal
                            putword {x},>entities_root+playfield_entity~characteristic_id

; Set the framelib collection / set
; Note, short pointer to entity is already on the stack
                            pushptr #preloaded~crystal_framelib                         ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            pushsword #0                ; variation
                            jsl playfield_entity_set_collection_from_preload

                            clc
exit                        anop
                            restoredatabank
                            rtl

failed                      plx                                                         ; clear saved pointer
                            lda #system_id_crystal_entity_manager+app_error_allocation_failed
                            jsl appdebug_set_last_error
                            bra exit

                            end

                            ago .skip
; -----------------------------------------------------------------------------
; Parameters:
;  short pointer to entity in Y
; Deprecated, just call playfield_entity_destruct
crystal_entity_destruct     private seg_entity

                            debugtag 'destruct_crystal_entity'

                            begin_locals
work_area_size              end_locals

                            lsub ,work_area_size

                            jsl playfield_entity_destruct

                            lret

                            end
.Skip

; -----------------------------------------------------------------------------
; Create a new crystal entity
crystal_entity_new          start seg_entity
                            using crystal_entity_manager_data

                            debugtag 'new'
                            debugtag 'crystal_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

; Allocate an empty buffer
                            jsl playfield_entity_allocate
                            bcs allocation_error
                            putretptr <pEntity

                            tax
                            jsl crystal_entity_construct
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
; Uninitialize the crystal entity.
crystal_entity_delete       start seg_entity
                            using crystal_entity_data
                            using crystal_entity_manager_data

                            debugtag 'delete_crystal_entity'

                            txy
                            beq exit

                            phx
;                           jsr crystal_entity_destruct
                            jsl playfield_entity_destruct

                            plx
                            jsl playfield_entity_deallocate

exit                        rtl
                            end

                            ago .skip
; -----------------------------------------------------------------------------
; Add the crystal entity to the playfield
; Deprecated, use inline_entity_add_to_playfield
crystal_entity_add_to_playfield start seg_entity
                            using crystal_entity_data

; Set that this is the first update
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_first_update
                            putword {x},>entities_root+playfield_entity~state_flags

                            rtl
                            end
.skip

; -----------------------------------------------------------------------------
; Remove the crystal entity from the playfield
crystal_entity_remove_from_playfield start seg_entity
                            using crystal_entity_data

                            debugtag 'remove_from_playfield_crystal_entity'

; Make sure this is on, so we get removed from the collision list
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword {x},>entities_root+playfield_entity~state_flags
; Invalidate
                            jsl playfield_entity_invalidate_sprite

                            rtl
                            end

; -----------------------------------------------------------------------------
; Handler for when a crystal is 'marked for removal'
; Parameters:
; y-reg         - entity short pointer
crystal_entity_remove_handler  start seg_entity
                            using crystal_entity_data
                            using crystal_entity_manager_data

                            debugtag 'remove_handler_crystal_entity'

                            ldx crystal_entity_next_remove_index
                            tya
                            sta crystal_entity_remove_array,x
                            inx
                            inx
                            stx crystal_entity_next_remove_index
                            inc crystal_entity_remove_count

                            rts
                            end
