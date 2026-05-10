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

                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/explosion.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm

                            mcopy generated/explosion.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
explosion_entity_data       data seg_entity

explosion_image_basic_collection_id     equ '1TSM'          ; In the Workers image file
explosion_image_rock_collection_id      equ '1COR'          ; in the Rocks image file
explosion_image_warrior_collection_id   equ '1RAW'          ; In the Warrior image file
explosion_image_player_fragment_collection_id equ '1HSP'    ; In Player Ship image file
explosion_image_player_fragment2_collection_id equ '1HSP'   ; In Player Ship image file
explosion_image_sinistar_fragment_collection_id equ '1NIS'  ; In Sinistar image file

explosion_image_type_count              equ 6

; Here is where I am a bit sad, in that I'm going to hard-code the variation counts
; in the set for the associated collections.
; I could probably do 'max' or something, which would allow this to be more data driven
; or even do the storage as an allocation, but I want this fast and tight.
explosion_image_basic_variation_count   equ 1
explosion_image_rock_variation_count    equ 8
explosion_image_warrior_variation_count equ 1
explosion_image_player_fragment_variation_count equ 4
explosion_image_player_fragment2_variation_count equ 1
explosion_image_sinistar_variation_count equ 8

preloaded~explosion_framelibs           anop
preloaded~explosion_basic_framelibs     ds explosion_image_basic_variation_count*sizeof~framelib_entity
preloaded~explosion_rock_framelibs      ds explosion_image_rock_variation_count*sizeof~framelib_entity
preloaded~explosion_warrior_framelibs   ds explosion_image_warrior_variation_count*sizeof~framelib_entity
preloaded~explosion_player_fragment_framelibs ds explosion_image_player_fragment_variation_count*sizeof~framelib_entity
preloaded~explosion_player_fragment2_framelibs ds explosion_image_player_fragment2_variation_count*sizeof~framelib_entity
preloaded~explosion_sinistar_framelibs  ds explosion_image_sinistar_variation_count*sizeof~framelib_entity

preloaded~explosion_framelib_sptr       dc a2'preloaded~explosion_basic_framelibs'
                                        dc a2'preloaded~explosion_rock_framelibs'
                                        dc a2'preloaded~explosion_warrior_framelibs'
                                        dc a2'preloaded~explosion_player_fragment_framelibs'
                                        dc a2'preloaded~explosion_player_fragment2_framelibs'
                                        dc a2'preloaded~explosion_sinistar_framelibs'

preloaded~explosion_variation_counts    anop
                                        dc i'explosion_image_basic_variation_count'
                                        dc i'explosion_image_rock_variation_count'
                                        dc i'explosion_image_warrior_variation_count'
                                        dc i'explosion_image_player_fragment_variation_count'
                                        dc i'explosion_image_player_fragment2_variation_count'
                                        dc i'explosion_image_sinistar_variation_count'

; Offsets to up to 8 variations.  Essentially a table for n * sizeof~framelib_entity
preloaded~explosion_variation_offsets   dc i'0'
                                        dc i'sizeof~framelib_entity'
                                        dc i'sizeof~framelib_entity*2'
                                        dc i'sizeof~framelib_entity*3'
                                        dc i'sizeof~framelib_entity*4'
                                        dc i'sizeof~framelib_entity*5'
                                        dc i'sizeof~framelib_entity*6'
                                        dc i'sizeof~framelib_entity*7'

explosion_image_type_to_set_id          dc i2'framelib_set_id_die'          ; explosion_image~basic
                                        dc i2'framelib_set_id_die'          ; explosion_image~rock
                                        dc i2'framelib_set_id_die'          ; explosion_image~warrior
                                        dc i2'framelib_set_id_die'          ; explosion_image~player_fragment
                                        dc i2'framelib_set_id_die+1'        ; explosion_image~player_fragment2
                                        dc i2'framelib_set_id_die'          ; explosion_image~sinistar_fragment

explosion_image_type_to_collection_id anop
                            dc i4'explosion_image_basic_collection_id'      ; explosion_image~basic
                            dc i4'explosion_image_rock_collection_id'       ; explosion_image~rock
                            dc i4'explosion_image_warrior_collection_id'    ; explosion_image~warrior
                            dc i4'explosion_image_player_fragment_collection_id' ; explosion_image~player_fragment
                            dc i4'explosion_image_player_fragment2_collection_id' ; explosion_image~player_fragment2
                            dc i4'explosion_image_sinistar_fragment_collection_id' ; explosion_image~sinistar_fragment
                            end

; -----------------------------------------------------------------------------
; Preload any images the explosion entities use
; Returns:
; carry clear, if successful
explosion_entity_preload_images start seg_entity
                            using explosion_entity_data

                            debugtag 'preload_images'
                            debugtag 'explosion_entity'

                            begin_locals
wIndex                      decl word
wIndexX2                    decl word
wIndexX4                    decl word
spBuffer                    decl word
wVariationCount             decl word
wVariationIndex             decl word
wFailed                     decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            stz <wIndex
                            stz <wFailed

                            lda #0

; Pre-load images
outer_loop                  asl a
                            sta <wIndexX2
                            tax
                            asl a
                            sta <wIndexX4

; Preload the collection into the first entry
                            pushptrhigh #preloaded~explosion_framelibs
                            getword {x},preloaded~explosion_framelib_sptr
                            sta <spBuffer
                            pha

                            ldx <wIndexX4
                            pushdword {x},explosion_image_type_to_collection_id
; Make sure this is clear.
                            ldx <spBuffer
                            jsl framelib_entity_construct_implicit

                            jsl playfield_preload_framelib_collection
                            bcs failed_preload
; See how many variations for the set ID.
;                           pushptr <pBuffer
;                           ldx <wIndexX2
;                           pushsword {x},explosion_image_type_to_set_id
;                           jsl framelib_entity_get_set_id_variation_count
;                           bcs failed_set_count
;                           ldx <wIndexX2
;                           sta preloaded~explosion_variation_counts,x
; Do complete loads of the set/variation/list/frame
                            ldx <wIndexX2
                            getword {x},preloaded~explosion_variation_counts
                            sta <wVariationCount
                            stz <wVariationIndex

variation_loop              jsr set_buffer_variation                ; fill in the set/variation

                            dec <wVariationCount
                            beq next
                            inc <wVariationIndex
                            jsr copy_collection_to_next             ; advance the buffer
                            ldx <wIndexX2                           ; get the type index back
                            bra variation_loop

failed_set_count            anop
failed_preload              anop
                            inc <wFailed

; Next type
next                        inc <wIndex
                            lda <wIndex
                            cmp #explosion_image_type_count
                            bne outer_loop

                            clc
                            lda <wFailed
                            beq exit
                            sec
exit                        restoredatabank
                            ret

; Set the current buffer's set/variation, and update it
set_buffer_variation        anop
                            lda #0
                            ldy <spBuffer                               ; y will have the short pointer to the buffer
                            putword {y},#framelib_entity~frame
                            putword {y},#framelib_entity~list
                            getword {x},explosion_image_type_to_set_id
                            putword {y},#framelib_entity~set
                            lda <wVariationIndex
                            putword {y},#framelib_entity~variation

                            tyx                                         ; just need the short pointer
; This will build the pointers in the framelib
                            jsl framelib_entity_update_set
                            jsl framelib_entity_update_list
                            jsl framelib_entity_update_frame
                            rts

; Copy the current buffer's collection information to the next one
; and advance the buffer pointer
copy_collection_to_next     anop
                            lda <spBuffer
                            tay
                            clc
                            adc #sizeof~framelib_entity
                            tax
; y-reg as the source pointer, x-reg as the destination
                            getword {y},#framelib_entity~collection_id
                            putword {x},#framelib_entity~collection_id
                            getword {y},#framelib_entity~collection_id+2
                            putword {x},#framelib_entity~collection_id+2
                            getword {y},#framelib_entity~collection_ptr
                            putword {x},#framelib_entity~collection_ptr
                            getword {y},#framelib_entity~collection_ptr+2
                            putword {x},#framelib_entity~collection_ptr+2

                            stx <spBuffer
                            rts

                            end

; -----------------------------------------------------------------------------
; Construct an explosion entity
; Parameters:
; spThis            - the short pointer to the entity to construct
; wImageType        - the image type to assign
; wVariationOverride - if not $ffff, this is the variation that will be used, else
;                      a random variation will be used.
explosion_entity_construct  start seg_entity
                            using explosion_entity_data

                            debugtag 'construct_explosion_entity'

                            begin_locals
wVariation                  decl word
spFramelibCache             decl word
pShape                      decl ptr
work_area_size              end_locals

                            sub (2:spThis,2:wImageType,2:wVariationOverride),work_area_size

                            setlocaldatabank

                            ldy <spThis
                            jsl playfield_entity_construct_lite             ; using the 'lite' version that does less clearing / setup
                            bcs failed

                            lda #entity_type~explosion
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~type

; Set the characteristic id
                            lda #id_characteristic_explosion
                            putword {x},>entities_root+playfield_entity~characteristic_id

; Set the framelib collection / set
                            lda <wImageType
                            asl a
                            tax
                            getword {x},preloaded~explosion_framelib_sptr
                            sta <spFramelibCache
; Did the caller ask for a specific variation.  Note, we don't check the range!  Can't waste the cycles!
                            lda <wVariationOverride
                            bpl specific_variation

                            getword {x},preloaded~explosion_variation_counts
                            cmp #2
                            blt one_variation
; Get a random variation
                            sta <wVariation
                            generate_rnd16                              ; get a random number
                            and #$00ff                                  ; treat as a fractional value
                            inline~umul1r2 <wVariation,Y                ; and multiply by the variation count
                            xba                                         ; upper byte is the contains a mod of the variation count
                            and #$00ff

; Add in the offset
; I could multiply, but a lookup table is faster
specific_variation          asl a
                            tax
                            getword {x},preloaded~explosion_variation_offsets
                            clc
                            adc <spFramelibCache
                            sta <spFramelibCache

one_variation               ldy <spFramelibCache                        ; y-reg will have the short pointer to the cache
                            ldx <spThis
                            jsr copy_preload

                            clc
failed                      anop
exit                        anop
                            restoredatabank
                            retkc

null_pointer                sec
                            bra exit

; Copy the preload to the entity
copy_preload                anop
                            getword {y},#framelib_entity~collection_id
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~collection_id
                            getword {y},#framelib_entity~collection_id+2
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~collection_id+2

                            getword {y},#framelib_entity~collection_ptr
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~collection_ptr
                            getword {y},#framelib_entity~collection_ptr+2
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~collection_ptr+2
; Copy the state values
                            getword {y},#framelib_entity~set
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~set
                            getword {y},#framelib_entity~variation
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~variation
                            getword {y},#framelib_entity~list
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~list
                            getword {y},#framelib_entity~frame
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~frame
; The counts
                            getword {y},#framelib_entity~list_count
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~list_count
                            getword {y},#framelib_entity~frame_count
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~frame_count

; Copy the set/list pointers
                            getword {y},#framelib_entity~set_sptr
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~set_sptr
                            getword {y},#framelib_entity~list_sptr
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~list_sptr

; Copy the frame pointers.  Note, we are copying to the sprite too
                            getword {y},#framelib_entity~primary_frame_data_ptr
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~primary_frame_data_ptr
                            putword {x},>entities_root+grlib_entity~sprite+sprite~primary_shape_ptr
                            sta <pShape
                            getword {y},#framelib_entity~primary_frame_data_ptr+2
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~primary_frame_data_ptr+2
                            putword {x},>entities_root+grlib_entity~sprite+sprite~primary_shape_ptr+2
                            sta <pShape+2

                            getword {y},#framelib_entity~secondary_frame_data_ptr
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~secondary_frame_data_ptr
                            putword {x},>entities_root+grlib_entity~sprite+sprite~secondary_shape_ptr
                            getword {y},#framelib_entity~secondary_frame_data_ptr+2
                            putword {x},>entities_root+grlib_entity~frame+framelib_entity~secondary_frame_data_ptr+2
                            putword {x},>entities_root+grlib_entity~sprite+sprite~secondary_shape_ptr+2

; Clear the changed flags
                            lda #0
                            putword {x},>entities_root+grlib_entity~changed
                            putword {x},>entities_root+grlib_entity~sprite+sprite~info

; Cache some information in the sprite.  This should be cached in the main caching process, so it doesn't have to be read from the sprite each time.
                            getword [<pShape],#shapedef~origin_x
                            putword {x},>entities_root+grlib_entity~sprite+sprite~offset_x
                            getword [<pShape],#shapedef~origin_y
                            putword {x},>entities_root+grlib_entity~sprite+sprite~offset_y
                            getword [<pShape],#shapedef~width
                            putword {x},>entities_root+grlib_entity~sprite+sprite~width
                            getword [<pShape],#shapedef~height
                            putword {x},>entities_root+grlib_entity~sprite+sprite~height
                            rts

                            end


; -----------------------------------------------------------------------------
; The contents of this are just called directly
                            ago .skip
explosion_entity_destruct   private seg_entity

                            debugtag 'destruct'
                            debugtag 'explosion_entity'

                            jsl playfield_entity_destruct_lite

                            rts

                            end
.skip
; -----------------------------------------------------------------------------
; Create a new explosion entity
; Parameters:
; wImageType         - explosion_image type
; wVariationOverride - if not $ffff, this is the variation that will be used, else
;                      a random variation will be used.
explosion_entity_new        start seg_entity
                            using explosion_entity_manager_data

                            debugtag 'new'
                            debugtag 'explosion_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (2:wImageType,2:wVariationOverride),work_area_size

; Allocate an empty buffer
                            jsl playfield_entity_allocate
                            bcs allocation_error
                            putretptr <pEntity

                            pha                                     ; short pointer for the construct
                            pushsword <wImageType
                            pushsword <wVariationOverride
                            jsl explosion_entity_construct
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
; Uninitialize the explosion entity.
explosion_entity_delete     start seg_entity
                            using explosion_entity_data
                            using explosion_entity_manager_data

                            debugtag 'delete_explosion_entity'

                            txy
                            beq exit

                            phx
;                           jsl explosion_entity_destruct
                            jsl playfield_entity_destruct_lite

                            plx
                            jsl playfield_entity_deallocate

exit                        rtl
                            end

; -----------------------------------------------------------------------------
; Add the explosion entity to the playfield
; Deprecated, since this doesn't do anything special.  Use inline_entity_add_to_playfield
explosion_entity_add_to_playfield start seg_entity
                            using explosion_entity_data

                            debugtag 'add_to_playfield_explosion_entity'


; Set that this is the first update
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_first_update
                            putword {x},>entities_root+playfield_entity~state_flags

                            rtl
                            end

; -----------------------------------------------------------------------------
; Remove the explosion entity from the playfield
explosion_entity_remove_from_playfield start seg_entity
                            using explosion_entity_data

                            debugtag 'remove_from_playfield_explosion_entity'

; Make sure this is on, so we get removed from the collision list
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword {x},>entities_root+playfield_entity~state_flags
; Invalidate
                            jsl playfield_entity_invalidate_sprite

                            rtl
                            end

; -----------------------------------------------------------------------------
; Handler for when a explosion is 'marked for removal'
; Parameters:
; y-reg         - entity short pointer
explosion_entity_remove_handler start seg_entity
                            using explosion_entity_data
                            using explosion_entity_manager_data

                            debugtag 'remove_handler_explosion_entity'

                            ldx explosion_entity_next_remove_index
                            tya
                            sta explosion_entity_remove_array,x
                            inx
                            inx
                            stx explosion_entity_next_remove_index
                            inc explosion_entity_remove_count

                            rts
                            end
