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
                            copy source/bomb.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm

                            mcopy generated/bomb.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
bomb_entity_data            data seg_entity

bomb_entity_image_collection_id equ_id 'BOMB'

; Preloaded images
preloaded~bomb_framelib     ds sizeof~framelib_entity

                            end

; -----------------------------------------------------------------------------
; Preload images the bomb entity uses
; Returns:
; carry clear, if successful
bomb_entity_preload_images  start seg_entity
                            using bomb_entity_data

                            debugtag 'preload_images'
; Pre-load images
                            pushptr #preloaded~bomb_framelib
                            pushdword #bomb_entity_image_collection_id
                            jsl playfield_preload_framelib_collection

                            rtl

                            end

; -----------------------------------------------------------------------------
; Parameters:
; x-reg             - the entity short pointer
bomb_entity_construct       start seg_entity
                            using bomb_entity_data

                            debugtag 'construct_bomb_entity'

                            setlocaldatabank

                            phx
                            txy
                            jsl playfield_entity_construct
                            bcs failed

                            lda 1,s                                                     ; get saved pointer
                            tax
                            lda #entity_type~bomb
                            putword {x},>entities_root+playfield_entity~type

; Set the characteristic id
                            lda #id_characteristic_bomb
                            putword {x},>entities_root+playfield_entity~characteristic_id

; Set the framelib collection / set
; Note, short pointer to entity is already on the stack
                            pushptr #preloaded~bomb_framelib                            ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            pushsword #0                ; variation
                            jsl playfield_entity_set_collection_from_preload

                            clc
exit                        restoredatabank
                            rtl

failed                      plx                                                         ; clear saved pointer
                            lda #system_id_bomb_entity_manager+app_error_allocation_failed
                            jsl appdebug_set_last_error
                            bra exit

                            end

; -----------------------------------------------------------------------------
bomb_entity_destruct        private seg_entity

                            debugtag 'destruct'
                            debugtag 'bomb_entity'

                            begin_locals
work_area_size              end_locals

                            lsub ,work_area_size

                            jsl playfield_entity_destruct

                            lret

                            end

; -----------------------------------------------------------------------------
; Create a new bomb entity
bomb_entity_new             start seg_entity
                            using bomb_entity_manager_data

                            debugtag 'new'
                            debugtag 'bomb_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

; Allocate an empty buffer
                            jsl playfield_entity_allocate
                            bcs allocation_error
                            putretptr <pEntity
                            tax
                            jsl bomb_entity_construct
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
; Uninitialize the bomb entity.
bomb_entity_delete          start seg_entity
                            using bomb_entity_data
                            using bomb_entity_manager_data

                            debugtag 'delete_bomb_entity'

                            txy
                            beq exit

                            phx
;                           jsr bomb_entity_destruct
                            jsl playfield_entity_destruct

                            plx
                            jsl playfield_entity_deallocate

exit                        rtl
                            end

; -----------------------------------------------------------------------------
; Add the bomb entity to the playfield
; Deprecated, use inline_entity_add_to_playfield
bomb_entity_add_to_playfield start seg_entity
                            using bomb_entity_data

                            debugtag 'add_to_playfield_bomb_entity'

; Set that this is the first update
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_first_update
                            putword {x},>entities_root+playfield_entity~state_flags

                            rtl
                            end

; -----------------------------------------------------------------------------
; Remove the bomb entity from the playfield
bomb_entity_remove_from_playfield start seg_entity
                            using bomb_entity_data

                            debugtag 'remove_from_playfield_bomb_entity'


; Make sure this is on, so we get removed from the collision list
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword {x},>entities_root+playfield_entity~state_flags
; Invalidate
                            jsl playfield_entity_invalidate_sprite

                            rtl
                            end

; -----------------------------------------------------------------------------
; Handler for when a bomb is 'marked for removal'
; Parameters:
; y-reg         - entity short pointer
bomb_entity_remove_handler  start seg_entity
                            using bomb_entity_data
                            using bomb_entity_manager_data

                            debugtag 'remove_handler_bomb_entity'

                            ldx bomb_entity_next_remove_index
                            tya
                            sta bomb_entity_remove_array,x
                            inx
                            inx
                            stx bomb_entity_next_remove_index
                            inc bomb_entity_remove_count

                            rts
                            end
