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
                            copy source/rock.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm

                            mcopy generated/rock.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
rock_entity_data            data seg_entity

rock_entity_image_collection_id equ '1COR'

; Preloaded images
preloaded~rock_framelib     ds sizeof~framelib_entity
preloaded~rock_visual_variation_count ds 2

rock_variation_to_characteristics anop
                            dc i'id_characteristic_planetoid_1'
                            dc i'id_characteristic_planetoid_2'
                            dc i'id_characteristic_planetoid_3'
                            dc i'id_characteristic_planetoid_4'
                            dc i'id_characteristic_planetoid_5'
                            end

; -----------------------------------------------------------------------------
; Preload images the rock entity uses
; Returns:
; carry clear, if successful
rock_entity_preload_images  start seg_entity
                            using rock_entity_data

                            debugtag 'preload_images'
                            lda #0
                            sta >preloaded~rock_visual_variation_count

; Pre-load images
                            pushptr #preloaded~rock_framelib
                            pushdword #rock_entity_image_collection_id
                            jsl playfield_preload_framelib_collection
                            bcs failed

; See how many variations for the walk set.
                            pushptr #preloaded~rock_framelib
                            pushword #framelib_set_id_walk
                            jsl framelib_entity_get_set_id_variation_count
                            bcs failed
                            sta >preloaded~rock_visual_variation_count

failed                      anop
                            rtl

                            end

; -----------------------------------------------------------------------------
; Construct a rock entity
; Parameters:
; pThis         - the entity storage
; wVariation    - the variation to use.  0 to rock_entity~variation_max-1
rock_entity_construct       start seg_entity
                            using rock_entity_data
                            using gameplay_entity_data

                            debugtag 'construct_rock_entity'

                            begin_locals
wVisualVariation            decl word
work_area_size              end_locals

                            sub (2:spThis,2:wVariation),work_area_size

                            setlocaldatabank

                            ldy <spThis
                            jsl playfield_entity_construct
                            bcs failed

                            lda <wVariation
                            cmp #rock_entity~variation_max
                            blt ok_variation
                            lda #0
                            sta <wVariation
ok_variation                anop
                            cmp >preloaded~rock_visual_variation_count
                            blt ok_visual_variation
                            lda #0
ok_visual_variation         sta <wVisualVariation

                            lda #entity_type~planetoid
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~type

; Set the characteristic id
                            lda <wVariation
                            asl a
                            tay
                            lda rock_variation_to_characteristics,y
                            putword {x},>entities_root+playfield_entity~characteristic_id

; For rocks, we store off the mass in the personality member, as we will decrease it as crystals are mined.
                            tax
                            lda >characteristics_table+gameplay_entity_characteristic~mass,x
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~personality

; Set the framelib collection / set
                            pushsword <spThis
                            pushptr #preloaded~rock_framelib                            ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            pushsword <wVisualVariation                                 ; variation
                            jsl playfield_entity_set_collection_from_preload

                            clc
exit                        anop
                            restoredatabank
                            retkc

failed                      lda #system_id_rock_entity_manager+app_error_allocation_failed
                            jsl appdebug_set_last_error
                            bra exit

                            end

; -----------------------------------------------------------------------------
rock_entity_destruct        private seg_entity

                            debugtag 'destruct'
                            debugtag 'rock_entity'

                            begin_locals
work_area_size              end_locals

                            lsub ,work_area_size

                            jsl playfield_entity_destruct

                            lret

                            end

; -----------------------------------------------------------------------------
; Create a new rock entity
; Parameters:
; wVariation    - the variation to use.  0 to rock_entity~variation_max-1
rock_entity_new             start seg_entity
                            using rock_entity_manager_data

                            debugtag 'new_rock_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (2:wVariation),work_area_size

; Allocate an empty buffer
                            jsl playfield_entity_allocate
                            bcs allocation_error
                            putretptr <pEntity

                            pha                                     ; short pointer to entity
                            pushsword <wVariation
                            jsl rock_entity_construct
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
; Uninitialize the rock entity and deallocate it.
; Parameters:
; x-reg     - short pointer to entity
rock_entity_delete          start seg_entity
                            using rock_entity_data
                            using rock_entity_manager_data

                            debugtag 'delete_rock_entity'

                            begin_locals
spThis                      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            cpx #0                              ; allow for null
                            beq exit

                            stx <spThis
                            txy
;                           jsr rock_entity_destruct
                            jsl playfield_entity_destruct

                            ldx <spThis
                            jsl playfield_entity_deallocate

exit                        ret
                            end

; -----------------------------------------------------------------------------
; Uninitialize and deallocate a rock entity that has already had a 'suspend' call on it.
; Parameters:
; x-reg     - short pointer to entity
rock_entity_delete_suspended start seg_entity
                            using rock_entity_data
                            using rock_entity_manager_data

                            debugtag 'delete_rock_entity'

                            cpx #0                              ; allow for null
                            beq exit

; The destruct has already been called by the suspend, and we currently don't want to try calling
; that again, because some of the values may still have 'valid' values in them, such as the tasks.
; We are trying not to clear values multiple times, though it might be best to prevent bugs.

; Deallocate the entity
                            jsl playfield_entity_deallocate

exit                        rtl
                            end

; -----------------------------------------------------------------------------
; Put the entity into a suspended state, where it can be re-used.
; Parameters:
; x-reg     - short pointer to entity
rock_entity_suspend         start seg_entity

                            debugtag 'suspend_rock_entity'

                            cpx #0                              ; allow for null
                            beq exit

                            txy
                            jsl playfield_entity_suspend

exit                        rtl
                            end

; -----------------------------------------------------------------------------
; Reuse a previously used entity.
; This assumes that most of the entity is already initialized, primarily
; the image set.  This can handle the variation changing.
; Parameters:
; spThis        - the entity to reuse
; wVariation    - the variation to use.  0 to rock_entity~variation_max-1
rock_entity_reuse           start seg_entity
                            using rock_entity_manager_data
                            using rock_entity_data
                            using gameplay_entity_data

                            debugtag 'reuse_rock_entity'

                            begin_locals
wVisualVariation            decl word
work_area_size              end_locals

                            sub (2:spThis,2:wVariation),work_area_size

                            ldy <spThis
                            jsl playfield_entity_reuse

                            lda <wVariation
                            cmp #rock_entity~variation_max
                            blt ok_variation
                            lda #0
                            sta <wVariation
ok_variation                anop
                            cmp >preloaded~rock_visual_variation_count
                            blt ok_visual_variation
                            lda #0
ok_visual_variation         sta <wVisualVariation

                            lda #entity_type~planetoid
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~type

; Set the characteristic id
                            lda <wVariation
                            asl a
                            tay
                            lda rock_variation_to_characteristics,y
                            putword {x},>entities_root+playfield_entity~characteristic_id

; For rocks, we store off the mass in the personality member, as we will decrease it as crystals are mined.
                            tax
                            lda >characteristics_table+gameplay_entity_characteristic~mass,x
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~personality

; Set the framelib collection / set
                            pushsword <spThis
                            pushptr #preloaded~rock_framelib                            ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            pushsword <wVisualVariation                                 ; variation
                            jsl playfield_entity_set_collection_from_preload

                            clc
                            retkc 2:spThis

                            end

                            ago .skip
; -----------------------------------------------------------------------------
; Add the rock entity to the playfield
; Deprecated, use inline_entity_add_to_playfield
rock_entity_add_to_playfield start seg_entity
                            using rock_entity_data

; Set that this is the first update
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_first_update
                            putword {x},>entities_root+playfield_entity~state_flags

                            rtl
                            end
.skip

; -----------------------------------------------------------------------------
; Remove the rock entity from the playfield
; Parameters:
; x-reg     - short pointer to entity
rock_entity_remove_from_playfield start seg_entity
                            using rock_entity_data
                            using rock_entity_manager_data

                            debugtag 'remove_from_playfield'
                            debugtag 'rock_entity'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            stx <spEntity
; Get the variation from the characteristic.  Could get it from the visual state, but I'm allowing that to 'possibly' be different.
; Should this go in the 'delete'?
                            getword {x},>entities_root+playfield_entity~characteristic_id

                            ldx #0
find_variation_loop         cmp rock_variation_to_characteristics,x
                            beq found_variation
                            inx
                            inx
                            cpx #rock_entity~variation_max*2
                            bne find_variation_loop
                            bra variation_error         ; uh oh, not found!

; Remove from the variation count list
found_variation             lda rock_entity_variation_count,x
                            beq variation_error
                            dec a
                            sta rock_entity_variation_count,x

variation_error             anop

; Make sure this is on, so we get removed from the collision list
                            ldx <spEntity
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword {x},>entities_root+playfield_entity~state_flags
; Invalidate
                            jsl playfield_entity_invalidate_sprite

                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Handler for when a rock is 'marked for removal'
; Parameters:
; y-reg         - entity short pointer
rock_entity_remove_handler  start seg_entity
                            using rock_entity_data
                            using rock_entity_manager_data

                            debugtag 'remove_handler_rock_entity'

                            ldx rock_entity_next_remove_index
                            tya
                            sta rock_entity_remove_array,x
                            inx
                            inx
                            stx rock_entity_next_remove_index
                            inc rock_entity_remove_count

                            rts
                            end
