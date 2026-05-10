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
;                           copy source/shot.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm

                            mcopy generated/shot.entity.macros

                            longa on
                            longi on
; -----------------------------------------------------------------------------
; Shot entities.
; Right now, they are full playfield_entity objects, but I might change this
; because it is overkill.  However, if there are only a few shots on screen (8-10)
; then really, it is easier to deal with because it is shared code.
; -----------------------------------------------------------------------------
shot_entity_data            data seg_entity
                            using gameplay_caller_logic_data

player_shot_entity_image_collection_id equ '1HSP'       ; In the player ship image
warrior_shot_entity_image_collection_id equ '1RAW'      ; In the warror image

shot_entity_type_id_player  equ 0
shot_entity_type_id_warrior equ 1

; Preloaded shot images
preloaded~player_shot_framelib  ds sizeof~framelib_entity
preloaded~warrior_shot_framelib ds sizeof~framelib_entity

shot_entity_types           dc a4'shot_characteristic_player'
                            dc a4'shot_characteristic_warrior'

shot_characteristic~id      equ 0
shot_characteristic~speed   equ shot_characteristic~id+2
sizeof~shot_characteristic  equ shot_characteristic~speed+2

shot_characteristic_player  dc i'shot_entity_type_id_player'
                            dc i'speed~8_00'
shot_characteristic_warrior dc i'shot_entity_type_id_warrior'
                            dc i'speed~4_00'

                            end

; -----------------------------------------------------------------------------
; Preload any images that shot entities use
; Returns:
; carry clear, if successful
shot_entity_preload_images  start seg_entity
                            using shot_entity_data

                            debugtag 'preload_images'

                            pea $0000           ; our error flag
; Pre-load images
                            pushptr #preloaded~player_shot_framelib
                            pushdword #player_shot_entity_image_collection_id
                            jsl playfield_preload_framelib_collection
                            bcc ok
                            lda #1
                            sta 1,s
ok                          pushptr #preloaded~warrior_shot_framelib
                            pushdword #warrior_shot_entity_image_collection_id
                            jsl playfield_preload_framelib_collection

                            pla
                            lsr a               ; error into the carry

                            rtl

                            end
; -----------------------------------------------------------------------------
; Construct a shot entity
; Parameters:
; spThis    - the short pointer to the shot entity
; wType     - the shot type, player or warrior
shot_entity_construct       start seg_entity
                            using shot_entity_data

                            debugtag 'construct_shot_entity'

                            begin_locals
work_area_size              end_locals

                            sub (2:spThis,2:wType),work_area_size

                            ldy <spThis
                            jsl playfield_entity_construct
                            bcs failed

                            ldx <spThis
                            lda <wType
                            cmp #shot_entity_type_id_player
                            beq is_player_shot

; warrior shot
                            lda #entity_type~warrior_shot
                            putword {x},>entities_root+playfield_entity~type

                            lda #id_characteristic_warrior_shot
                            putword {x},>entities_root+playfield_entity~characteristic_id

; Set the framelib collection / set
                            pushsword <spThis
                            pushptr #preloaded~warrior_shot_framelib                         ; use the preloaded framelib
                            bra next

; player shot
is_player_shot              anop
                            lda #entity_type~player_shot
                            putword {x},>entities_root+playfield_entity~type

                            lda #id_characteristic_player_shot
                            putword {x},>entities_root+playfield_entity~characteristic_id

; Set the framelib collection / set
                            pushsword <spThis
                            pushptr #preloaded~player_shot_framelib                         ; use the preloaded framelib
next                        anop
                            pushsword #framelib_set_id_attack
                            pushsword #0                ; variation
                            jsl playfield_entity_set_collection_from_preload

                            clc
exit                        anop
                            retkc

failed                      lda #system_id_shot_entity_manager+app_error_allocation_failed
                            jsl appdebug_set_last_error
                            bra exit

                            end

; -----------------------------------------------------------------------------
shot_entity_destruct        private seg_entity

                            debugtag 'destruct_shot_entity'

                            begin_locals
work_area_size              end_locals

                            lsub ,work_area_size

                            jsl playfield_entity_destruct

                            lret

                            end

; -----------------------------------------------------------------------------
; Create a new shot entity
; Parameters:
; wType         - shot type, player or warrior
shot_entity_new             start seg_entity
                            using shot_entity_manager_data

                            debugtag 'new_shot_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (2:wType),work_area_size

; Allocate an empty buffer
                            jsl playfield_entity_allocate
                            bcs allocation_error
                            putretptr <pEntity

                            pha                                     ; short pointer to entity
                            pushsword <wType
                            jsl shot_entity_construct
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
; Uninitialize the shot entity.
shot_entity_delete          start seg_entity
                            using shot_entity_data
                            using shot_entity_manager_data

                            debugtag 'delete_shot_entity'

                            txy
                            beq exit

                            phx
; Skipping this, and just calling playfield_entity_destruct directly, since I know that is all it does
;                           jsr shot_entity_destruct
                            jsl playfield_entity_destruct

                            plx
                            jsl playfield_entity_deallocate

exit                        rtl
                            end

                            ago .skip
; -----------------------------------------------------------------------------
; Add the shot entity to the playfield
; Deprecated, use inline_entity_add_to_playfield
shot_entity_add_to_playfield start seg_entity
                            using shot_entity_data

; Set that this is the first update
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_first_update
                            putword {x},>entities_root+playfield_entity~state_flags

                            rtl
                            end
.skip

; -----------------------------------------------------------------------------
; Remove the shot entity from the playfield
; Parameters:
; x-reg                 - short pointer to entity
shot_entity_remove_from_playfield start seg_entity
                            using shot_entity_data

                            debugtag 'remove_from_playfield_shot_entity'


; Make sure this is on, so we get removed from the collision list
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword {x},>entities_root+playfield_entity~state_flags
; Invalidate
                            jsl playfield_entity_invalidate_sprite

                            rtl
                            end

; -----------------------------------------------------------------------------
; Handler for when a shot is 'marked for removal'
; Parameters:
; y-reg         - entity short pointer
shot_entity_remove_handler  start seg_entity
                            using shot_entity_manager_data

                            debugtag 'remove_handler_shot_entity'

                            ldx shot_entity_next_remove_index
                            tya
                            sta shot_entity_remove_array,x
                            inx
                            inx
                            stx shot_entity_next_remove_index
                            inc shot_entity_remove_count

                            rts
                            end
