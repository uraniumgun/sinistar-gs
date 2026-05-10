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
                            copy source/sinistar.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/gameplay.player.definitions.asm

                            mcopy generated/sinistar.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
sinistar_entity_data        data seg_entity
                            using gameplay_caller_logic_data

sinistar_entity_image_collection_id equ '1NIS'

max_sinistar_pieces         equ 20                      ; max visible pieces.  There is an invisible root piece.
sinistar_center_pieces      equ 8                       ; once Sinistar is alive, these pieces don't need to be destroyed to kill him
sinistar_outer_pieces       equ max_sinistar_pieces-sinistar_center_pieces

sinistar_piece_head_ul      equ 12
sinistar_piece_head_ur      equ 13
sinistar_piece_brow_l       equ 14
sinistar_piece_brow_r       equ 15
sinistar_piece_chin         equ 16
sinistar_piece_jaw_l        equ 17
sinistar_piece_jaw_r        equ 18
sinistar_piece_nose         equ 19                      ; or nez, as the original source like to call it.
sinistar_piece_center       equ 20                      ; the special 'full center' piece, for quicker drawing

piece_offsets               dc i'-06,00,06,00'
                            dc i'-12,04,14,04'
                            dc i'-15,16,19,16'
                            dc i'-16,26,18,26'
                            dc i'-12,38,14,38'
                            dc i'-01,40,05,40'

                            dc i'-05,12,09,12'
                            dc i'-09,24,09,24'
                            dc i'00,33,-03,32'
                            dc i'03,32,01,24'

; Roll this into the piece_offsets.  Please.
sinistar_piece_y_offset_from_root equ -29

sinistar_total_x_offset     equ 23
sinistar_total_y_offset     equ 33

sinistar_total_width        equ 49
sinistar_total_height       equ 52

; The state the Sinistar can be in
sinistar_state_building     equ 0
sinistar_state_alive        equ 1
sinistar_state_dead         equ 2

sinistar_piece_state_not_built  equ 0
sinistar_piece_state_built      equ 1

; Static asserts here, for some places lower down that require these to be true.  The test values have to be gequ to work, maybe just change them?
                            static_assert_equal sinistar_state_building,0
                            static_assert_equal sinistar_piece_state_not_built,0

; non-zero, if any part of Sinistar is on-screen.  Use this, rather than looking at the sinistar entity itself,
; as that is just the root piece, and may not be on screen, but other pieces might be.
sinistar_entity~on_screen   ds 2

; Preloaded images
preloaded~sinistar_framelib ds sizeof~framelib_entity

; Note that the state of sinistar is kept in the active player state, so it is preserved between players.

; All the pieces will be put in this array, for easy access.  The array will not own the pointers.
sinistar_entity_pieces_ptrs ds max_sinistar_pieces*4            ; get rid of this
sinistar_entity_pieces_sptrs ds max_sinistar_pieces*2
; The state of all the pieces.  0 = not built
sinistar_entity_pieces_state ds max_sinistar_pieces*2

; The invisible root piece.  This will serve as the nominal position of sinistar, and
; will be used for general targeting, but will not be part of targeting for building or destroying.
sinistar_entity_root_piece_ptr ds 4

; The animated overlay parts
sinistar_mouth_offset_x     equ 3
sinistar_mouth_offset_y     equ 24

sinistar_mouth_closed       equ 0
sinistar_mouth_open         equ 4
sinistar_mouth_wide_open    equ 8
sinistar_mouth_shape_count  equ 3

sinistar_mouth_primary_shape_ptrs       ds 4*sinistar_mouth_shape_count
sinistar_mouth_secondary_shape_ptrs     ds 4*sinistar_mouth_shape_count
sinistar_mouth_position     ds 2                        ; what position the mouth is currently in.  Must be closed, open, wide_open

sinistar_eyebrow_offset_x    equ 3
sinistar_eyebrow_offset_y    equ 0

sinistar_eyebrow_down       equ 0
sinistar_eyebrow_normal     equ 4
sinistar_eyebrow_up         equ 8
sinistar_eyebrow_shape_count equ 3

sinistar_eyebrow_primary_shape_ptrs     ds 4*sinistar_mouth_shape_count
sinistar_eyebrow_secondary_shape_ptrs   ds 4*sinistar_mouth_shape_count
sinistar_eyebrow_position    ds 2

                            end

; -----------------------------------------------------------------------------
; Preload images the sinistar entity uses
; Returns:
; carry clear, if successful
sinistar_entity_preload_images start seg_entity
                            using sinistar_entity_data

                            debugtag 'preload_images'

; Pre-load images
                            pushptr #preloaded~sinistar_framelib
                            pushdword #sinistar_entity_image_collection_id
                            jsl playfield_preload_framelib_collection

                            pushptr >preloaded~sinistar_framelib+framelib_entity~collection_ptr
                            jsr _preload_animated_parts

                            rtl

                            end

; -----------------------------------------------------------------------------
sinistar_entity_construct   start seg_entity
                            using sinistar_entity_data
                            using gameplay_manager_data

                            debugtag 'construct'
                            debugtag 'sinistar_entity'

                            begin_locals
pChild                      decl ptr
wPieceIndex                 decl word
wPiecesBuilt                decl word
wSinistarState              decl word
wOffset                     decl word
wFrame                      decl word
wFrameID                    decl word
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            setlocaldatabank

                            assert_ptr <pThis,'null_pointer'

                            lda #sinistar_mouth_closed
                            sta sinistar_mouth_position

                            lda #sinistar_eyebrow_normal
                            sta sinistar_eyebrow_position

; Create the root piece.  This will be invisible, and will not be part of the targeting pieces.
                            ldy <pThis
                            jsl playfield_entity_construct
                            jcs failed

                            lda #entity_type~sinistar
                            putword [<pThis],#playfield_entity~type

; Set the characteristic id
                            lda #id_characteristic_sinistar
                            putword [<pThis],#playfield_entity~characteristic_id

                            pushsword <pThis
                            pushptr #preloaded~sinistar_framelib                      ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            pushsword #0
                            jsl playfield_entity_set_collection_from_preload

; Put the root piece in a global
                            lda <pThis
                            sta sinistar_entity_root_piece_ptr
                            lda <pThis+2
                            sta sinistar_entity_root_piece_ptr+2

; Clear the sprite shape, we don't want to see this one.
                            lda #0
                            putptrlow [<pThis],#playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr
                            putptrhigh [<pThis],#playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr

; Add the sub-pieces
                            stz <wPieceIndex

                            lda >gameplay_manager~active_state+player_state~sinistar~state
;                           static_assert_equal sinistar_state_building,0
                            dec a
                            sta <wSinistarState                                 ; make the high bit on, if sinistar is building
                            bmi is_building
; Don't count the center pieces
                            lda >gameplay_manager~active_state+player_state~sinistar~pieces_built
                            sec
                            sbc #sinistar_center_pieces
                            sta <wPiecesBuilt
                            bra piece_loop

is_building                 anop
                            lda >gameplay_manager~active_state+player_state~sinistar~pieces_built
                            sta <wPiecesBuilt

piece_loop                  pushsword <wPieceIndex
                            jsl sinistar_piece_entity_new
                            putretptr <pChild

                            pushptr <pThis
                            pushptr <pChild
                            jsl grlib_entity_add_child

                            pushsword <pChild
                            pushptr #preloaded~sinistar_framelib                      ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            lda <wPieceIndex
                            cmp #sinistar_piece_nose
                            bne not_nose
; Set the custom draw function
                            lda #sinistar_entity_custom_draw-1
                            putword [<pChild],#playfield_entity~custom_draw_sptr
                            lda <wPieceIndex
                            inc a                                   ; also use the 'full' image variation.  I may change this so there isn't a nose-only variation, but might need it during the death sequence.
not_nose                    pha
                            jsl playfield_entity_set_collection_from_preload

                            lda <wPieceIndex
                            asl a
                            tax
; Built?
                            lda #sinistar_piece_state_built
                            dec <wPiecesBuilt
                            bpl is_built2

                            lda #sinistar_piece_state_not_built
                            ldy <wPieceIndex                        ; The first piece?  If so, don't clear it, we always see that one, even if it is not built.
                            beq is_center

                            bit <wSinistarState
                            bmi is_building2

; Not building (alive / dead), turn on the unified center piece (the last one) others are off
; This check is kinda ugly
                            cpy #sinistar_outer_pieces
                            blt is_building2
                            lda #sinistar_piece_state_built
                            cpy #sinistar_piece_nose
                            beq is_center
; Clear the 'building' center piece
                            lda #0
                            putptrlow [<pChild],#playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr
                            putptrhigh [<pChild],#playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr
                            lda #sinistar_piece_state_built
                            bra is_center

is_building2                anop
; Clear the sprite shape for the children.  This will prevent the piece from drawing, since it is not 'active', but everything else will be in place
                            lda #0
                            putptrlow [<pChild],#playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr
                            putptrhigh [<pChild],#playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr
; Note, assuming sinistar_piece_state_not_built is 0, so no need to load it

is_center                   anop
is_built2                   sta sinistar_entity_pieces_state,x
; Put the child piece in the global sptr list
                            lda <pChild
                            sta sinistar_entity_pieces_sptrs,x
; Next bit of code needs the piece index x 4
                            txa
                            asl a
                            tax
                            lda piece_offsets,x
                            putword [<pChild],#playfield_entity~grentity+grlib_entity~x
                            lda piece_offsets+2,x
                            clc
                            adc #sinistar_piece_y_offset_from_root                          ; roll this into the offset table
                            putword [<pChild],#playfield_entity~grentity+grlib_entity~y

; Put the child piece in the global list
                            lda <pChild
                            sta sinistar_entity_pieces_ptrs,x
                            lda <pChild+2
                            sta sinistar_entity_pieces_ptrs+2,x

                            inc <wPieceIndex
                            lda <wPieceIndex
                            cmp #max_sinistar_pieces
                            jlt piece_loop

                            clc
exit                        anop
                            restoredatabank
                            retkc

failed                      assert_brk 'alloc_failed'
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Load the images for the animated parts and put the pointers into so global
; pointers for quick access.
_preload_animated_parts     private seg_entity
                            using sinistar_entity_data
                            using gameplay_manager_data

                            debugtag 'preload_animated_parts'
                            debugtag 'sinistar_entity'

                            begin_locals
wOffset                     decl word
wFrame                      decl word
wFrameID                    decl word
work_area_size              end_locals

                            lsub (4:pFrameEntityCollection),work_area_size

                            setlocaldatabank

; Get the shape pointers for the eyebrows from Idle, subset 1
                            jsr _load_eyebrows
; And the pointers for the mouth from Idle, subset 2
                            jsr _load_mouth

                            restoredatabank
                            lret

;; Local Functions
_load_eyebrows              anop
                            stz <wOffset
                            stz <wFrame
                            ldy #0

eyebrow_load_loop           anop
; Clear the entry
                            lda #0
                            sta sinistar_eyebrow_primary_shape_ptrs,y
                            sta sinistar_eyebrow_primary_shape_ptrs+2,y
                            sta sinistar_eyebrow_secondary_shape_ptrs,y
                            sta sinistar_eyebrow_secondary_shape_ptrs+2,y

                            pushptr <pFrameEntityCollection
;                            pushsword #$0100                                ; subset is the high byte, variation is the low byte
                            pushsword #$0001                                ; sub-sets are collapsed into the variations now
                            pushsword #framelib_set_id_idle
                            pushsword #0                                    ; direction
                            pushsword <wFrame
                            jsl framelib_collection_get_frame_id
                            bcs eyebrow_load_next
; Get the primary (pixel) shape pointer
                            sta <wFrameID
                            pushptr <pFrameEntityCollection
                            pushsword <wFrameID
                            jsl framelib_collection_get_frame_primary_shape_ptr
                            bcs eyebrow_load_primary_error
                            clc
                            adc #sizeof~datalib_shapedef                    ; skip the header
                            ldy <wOffset
                            sta sinistar_eyebrow_primary_shape_ptrs,y
                            txa
                            sta sinistar_eyebrow_primary_shape_ptrs+2,y
eyebrow_load_primary_error  anop
; Get the secondary (compiled) shape pointer
                            pushptr <pFrameEntityCollection
                            pushsword <wFrameID
                            jsl framelib_collection_get_frame_secondary_shape_ptr
                            bcs eyebrow_load_next
                            clc
                            adc #sizeof~datalib_shapedef                    ; skip the header
                            ldy <wOffset
                            sta sinistar_eyebrow_secondary_shape_ptrs,y
                            txa
                            sta sinistar_eyebrow_secondary_shape_ptrs+2,y

eyebrow_load_next           inc <wFrame
                            ldy <wOffset
                            iny
                            iny
                            iny
                            iny
                            sty <wOffset
                            cpy #sinistar_eyebrow_shape_count*4
                            blt eyebrow_load_loop
                            rts

;;
_load_mouth                 anop
                            stz <wOffset
                            stz <wFrame
                            ldy #0

mouth_load_loop             anop
; Clear the entry
                            lda #0
                            sta sinistar_mouth_primary_shape_ptrs,y
                            sta sinistar_mouth_primary_shape_ptrs+2,y
                            sta sinistar_mouth_secondary_shape_ptrs,y
                            sta sinistar_mouth_secondary_shape_ptrs+2,y

                            pushptr <pFrameEntityCollection
;                            pushsword #$0200                                ; subset is the high byte, variation is the low byte
                            pushsword #$0002                                ; sub-sets are collapsed into the variations now
                            pushsword #framelib_set_id_idle
                            pushsword #0                                    ; direction
                            pushsword <wFrame
                            jsl framelib_collection_get_frame_id
                            bcs mouth_load_next
; Get the primary (pixel) shape pointer
                            sta <wFrameID
                            pushptr <pFrameEntityCollection
                            pushsword <wFrameID
                            jsl framelib_collection_get_frame_primary_shape_ptr
                            bcs mouth_primary_load_error
                            clc
                            adc #sizeof~datalib_shapedef                    ; skip the header
                            ldy <wOffset
                            sta sinistar_mouth_primary_shape_ptrs,y
                            txa
                            sta sinistar_mouth_primary_shape_ptrs+2,y

mouth_primary_load_error    anop
; Get the secondary (compiled) shape pointer
                            pushptr <pFrameEntityCollection
                            pushsword <wFrameID
                            jsl framelib_collection_get_frame_secondary_shape_ptr
                            bcs mouth_load_next
                            clc
                            adc #sizeof~datalib_shapedef                    ; skip the header
                            ldy <wOffset
                            sta sinistar_mouth_secondary_shape_ptrs,y
                            txa
                            sta sinistar_mouth_secondary_shape_ptrs+2,y

mouth_load_next             inc <wFrame
                            ldy <wOffset
                            iny
                            iny
                            iny
                            iny
                            sty <wOffset
                            cpy #sinistar_mouth_shape_count*4
                            blt mouth_load_loop
                            rts

                            end

; -----------------------------------------------------------------------------
sinistar_entity_destruct    private seg_entity

                            debugtag 'destruct'
                            debugtag 'sinistar_entity'

                            begin_locals
pChild                      decl ptr
work_area_size              end_locals

                            lsub (4:pThis),work_area_size

child_loop                  pushptr <pThis,#playfield_entity~grentity
                            jsl grlib_entity_remove_first_child
                            bcs no_children

                            putretptr <pChild
                            tay
                            jsl playfield_entity_destruct           ; Note, simplifying, since this is all sinistar_piece_entity_destruct would do.

; Note, we are assuming children were allocated in this way.
                            ldx <pChild
                            jsl playfield_entity_deallocate
                            bra child_loop

no_children                 anop
                            ldy <pThis
                            jsl playfield_entity_destruct

                            lret

                            end

; -----------------------------------------------------------------------------
; Create a new sinistar entity
sinistar_entity_new         start seg_entity
                            using sinistar_entity_manager_data

                            debugtag 'new'
                            debugtag 'sinistar_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

; Allocate an empty buffer
                            jsl playfield_entity_allocate
                            bcs allocation_error
                            putretptr <pEntity
                            pushretptr

                            jsl sinistar_entity_construct
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
; Uninitialize the sinistar entity.
sinistar_entity_delete      start seg_entity
                            using sinistar_entity_data
                            using sinistar_entity_manager_data

                            debugtag 'delete_sinistar_entity'

                            txy
                            beq exit

                            phx
                            pushptrhigh #entities_root
                            phx
                            jsr sinistar_entity_destruct

                            plx
                            jsl playfield_entity_deallocate

exit                        rtl
                            end

; -----------------------------------------------------------------------------
; Construct a sinistar piece
; Parameters:
; pThis         - the piece entity
; wPiece        - the piece index
sinistar_piece_entity_construct start seg_entity
                            using sinistar_entity_data

                            debugtag 'construct'
                            debugtag 'sinistar_piece_entity'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis,2:wPiece),work_area_size

                            getword <pThis+2
                            beq null_pointer

                            ldy <pThis
                            jsl playfield_entity_construct
                            bcs failed

                            lda #entity_type~sinistar
                            putword [<pThis],#playfield_entity~type

; Set the characteristic id
                            lda #id_characteristic_sinistar
                            putword [<pThis],#playfield_entity~characteristic_id

; Note, not setting the image in the function, as we are assuming that parent is going to do it.

                            clc
exit                        anop
                            retkc

null_pointer                lda #system_id_sinistar_entity_manager+app_error_null_pointer
                            jsl appdebug_set_last_error
                            bra exit
failed                      lda #system_id_sinistar_entity_manager+app_error_allocation_failed
                            jsl appdebug_set_last_error
                            bra exit

                            end

; -----------------------------------------------------------------------------
; Create a new sinistar piece entity
; Similar to the main entity, except the construction is a bit different
; and it requires parameters.
; Note that the child piece is not added to the manager's entity list.
; The parent will manage the lifetime of the child.
; Parameters:
; wPiece        - the piece index
sinistar_piece_entity_new   start seg_entity
                            using sinistar_entity_manager_data

                            debugtag 'new'
                            debugtag 'sinistar_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (2:wPiece),work_area_size

; Allocate an empty buffer
                            jsl playfield_entity_allocate
                            bcs allocation_error
                            putretptr <pEntity
                            pushretptr

                            pushsword <wPiece
                            jsl sinistar_piece_entity_construct
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
; Uninitialize the sinistar piece entity.
sinistar_piece_entity_delete start seg_entity
                            using sinistar_entity_data
                            using sinistar_entity_manager_data

                            debugtag 'delete'
                            debugtag 'sinistar_entity'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            getword <pThis+2
                            beq exit
                            pha
                            pushsword <pThis

                            jsr sinistar_entity_destruct

                            ldx <pThis
                            jsl playfield_entity_deallocate

exit                        ret
                            end

; -----------------------------------------------------------------------------
; Add the sinistar entity to the playfield
; Deprecated, use inline_entity_add_to_playfield
sinistar_entity_add_to_playfield start seg_entity
                            using sinistar_entity_data

                            debugtag 'add_to_playfield_sinistar_entity'

                            lda #0
                            sta >sinistar_entity~on_screen
; Set that this is the first update
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_first_update
                            putword {x},>entities_root+playfield_entity~state_flags

                            rtl
                            end

; -----------------------------------------------------------------------------
; Remove the sinistar entity from the playfield
sinistar_entity_remove_from_playfield start seg_entity
                            using sinistar_entity_data

                            debugtag 'remove_from_playfield_sinistar_entity'

                            jsl playfield_entity_remove_from_playfield

                            lda #0
                            sta >sinistar_entity~on_screen

                            rtl
                            end

; -----------------------------------------------------------------------------
; Handler for when a sinistar is 'marked for removal'
; Parameters:
; y-reg         - entity short pointer
sinistar_entity_remove_handler start seg_entity
                            using sinistar_entity_manager_data

                            debugtag 'remove_handler_sinistar_entity'

                            ldx sinistar_entity_next_remove_index
                            tya
                            sta sinistar_entity_remove_array,x
                            inx
                            inx
                            stx sinistar_entity_next_remove_index
                            inc sinistar_entity_remove_count

                            rts
                            end

; -----------------------------------------------------------------------------
; Get the piece index from the ID
; Carry will be clear and the piece index * 2, in X
sinistar_entity_get_piece_index start seg_entity
                            using sinistar_entity_data

                            debugtag 'get_piece_index'
                            debugtag 'sinistar_entity'

                            begin_locals
work_area_size              end_locals

                            sub (4:pPiece),work_area_size

                            lda <pPiece
                            ldx #0
loop                        cmp >sinistar_entity_pieces_sptrs,x
                            beq found
next                        inx
                            inx
                            cpx #max_sinistar_pieces*2
                            blt loop
; blt is carry clear, so the carry must be set already
; x will be preserved on return
                            retkc
found                       clc
; x will be preserved on return
                            retkc
                            end

; -----------------------------------------------------------------------------
; Get the next piece that needs to be built
; Returns:
; short pointer to entity in A or null
sinistar_entity_get_next_piece_to_build start seg_entity
                            using sinistar_entity_data

                            debugtag 'get_next_piece'

                            setlocaldatabank

                            ldx #0
loop                        lda sinistar_entity_pieces_state,x
                            beq found           ; sinistar_piece_state_not_built == 0
                            inx
                            inx
                            cpx #max_sinistar_pieces*2
                            blt loop

                            restoredatabank
                            lda #0
                            sec
                            rtl

found                       txa
                            asl a
                            tax
                            lda sinistar_entity_pieces_ptrs,x
; Carry should already be clear
                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Builds the piece passed in.
; Parameters:
; x-reg:        - short pointer to the piece to build
; Returns:
; carry set, if the piece is already built
sinistar_entity_build_piece start seg_entity
                            using sinistar_entity_data
                            using gameplay_manager_data
                            using gameplay_sound_data
                            using gameplay_sinistar_logic_data

                            debugtag 'build_piece'

                            begin_locals
spPieceToBuild              decl word
wTemp                       decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            stx <spPieceToBuild
; Well, we don't have the index, find it
                            txa

                            ldx #0
loop                        cmp sinistar_entity_pieces_sptrs,x
                            beq found
                            inx
                            inx
                            cpx #max_sinistar_pieces*2
                            blt loop
                            brl error            ; Not in the list?
found                       anop
; Make sure it is not_built
                            lda sinistar_entity_pieces_state,x
                            bne error            ; already built!, cmp #sinistar_piece_state_not_built
                            lda #sinistar_piece_state_built
                            sta sinistar_entity_pieces_state,x
; Update the count in the persistant state
                            lda >gameplay_manager~active_state+player_state~sinistar~pieces_built
                            inc a
                            sta >gameplay_manager~active_state+player_state~sinistar~pieces_built
                            cmp #max_sinistar_pieces
                            blt not_alive_yet

                            jsr _make_alive

not_alive_yet               anop
; Set the flag that the frame change, and update.  This will cause the frame to put the shape pointer back in
                            ldx <spPieceToBuild
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~changed
                            ora #grlib_entity~changed_frame_index
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~changed

                            setdatabanktolabel entities_root
                            jsl grlib_entity_update_framelib
                            restoredatabank

                            pushsword #id_sfx~deliver_crystal
                            jsl sndlib_play_sfx

                            clc
exit                        restoredatabank
                            retkc
error                       sec
                            bra exit

_make_alive                 anop
; Hmm, this code is kinda 'gameplay' code.  Should this whole function be gameplay side?

; Sinistar is alive!
                            lda #sinistar_state_alive
                            sta >gameplay_manager~active_state+player_state~sinistar~state

                            generate_rnd16
                            sta >gameplay_sinistar_logic~orbit_multiplier       ; direction or orbit. Just tests the high-bit, so no need to compare.
                            and #gameplay_sinistar_logic~orbit_countdown
                            ora #gameplay_sinistar_logic~max_orbit_factor       ; Note, we can end up with a value, greater than the max orbit factor.  This is as it was in the original.  The value will be clamped later.
                            sta <wTemp

                            ldx sinistar_entity_root_piece_ptr
                            getword {x},>entities_root+playfield_entity~personality
                            and #((gameplay_sinistar_logic~orbit_countdown)*-1)-1
                            ora <wTemp
                            putword {x},>entities_root+playfield_entity~personality

                            pushsword #id_sfx~beware_i_live
                            jsl gameplay_sinistar_play_speech

; Clear all the center piece images, except for the 'nose', which is actually the full center image, so it will draw faster.
                            ldy #sinistar_outer_pieces*4
clear_loop                  lda sinistar_entity_pieces_ptrs,y
                            tax
                            lda #0
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr+2
                            iny
                            iny
                            iny
                            iny
                            cpy #sinistar_piece_nose*4
                            blt clear_loop
                            rts

                            end

; -----------------------------------------------------------------------------
; Get a piece of sinistar to target
; If Sinistar is in the 'building' phase, any built piece is picked.
; If there is nothing build, the first piece is picked.
; If Sinistar is alive, then only the outer crown pieces will be picked,
; except if they are all dead, then a center piece will be picked.

sinistar_entity_get_piece_to_target start seg_entity
                            using sinistar_entity_data
                            using gameplay_manager_data

                            debugtag 'get_piece_to_target'
                            debugtag 'sinistar_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            ldx #(max_sinistar_pieces*2)-2
                            lda >gameplay_manager~active_state+player_state~sinistar~state
;                           static_assert_equal sinistar_state_building,0
                            beq loop
; Just pick from the outer pieces
                            ldx #(sinistar_outer_pieces*2)-2

loop                        lda sinistar_entity_pieces_state,x
                            cmp #sinistar_piece_state_built
                            beq found
                            dex
                            dex
                            bpl loop
; If building, just retarget the first piece
                            lda >gameplay_manager~active_state+player_state~sinistar~state
;                           static_assert_equal sinistar_state_building,0
                            beq target_first
; target a center piece
                            ldx #sinistar_piece_nose*2
                            bra found

target_first                lda sinistar_entity_pieces_ptrs
                            sta <pEntity
                            lda sinistar_entity_pieces_ptrs+2
                            sta <pEntity+2
                            clc
                            bra exit

found                       txa
                            asl a
                            tax
                            lda sinistar_entity_pieces_ptrs,x
                            sta <pEntity
                            lda sinistar_entity_pieces_ptrs+2,x
                            sta <pEntity+2
; Carry should already be clear
exit                        restoredatabank
                            retkc 4:pEntity
                            end

; -----------------------------------------------------------------------------
; Get a piece of sinistar to destroy.  This is similar to
; get_piece_to_target, except when sinistar is not building (alive or dead)
; if will not return a valid piece, if there is nothing to destroy.
sinistar_entity_get_piece_to_destroy start seg_entity
                            using sinistar_entity_data
                            using gameplay_manager_data

                            debugtag 'get_piece_to_destroy'
                            debugtag 'sinistar_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            ldx #(max_sinistar_pieces*2)-2
                            lda >gameplay_manager~active_state+player_state~sinistar~state
;                           static_assert_equal sinistar_state_building,0
                            beq loop
; Just pick from the outer pieces
                            ldx #(sinistar_outer_pieces*2)-2

loop                        lda sinistar_entity_pieces_state,x
                            cmp #sinistar_piece_state_built
                            beq found
                            dex
                            dex
                            bpl loop
; If building, just retarget the first piece
                            lda >gameplay_manager~active_state+player_state~sinistar~state
;                           static_assert_equal sinistar_state_building,0
                            beq target_first
; If alive / dead, then no piece
                            sec
                            bra exit

target_first                lda sinistar_entity_pieces_ptrs
                            sta <pEntity
                            lda sinistar_entity_pieces_ptrs+2
                            sta <pEntity+2
                            clc
                            bra exit

found                       txa
                            asl a
                            tax
                            lda sinistar_entity_pieces_ptrs,x
                            sta <pEntity
                            lda sinistar_entity_pieces_ptrs+2,x
                            sta <pEntity+2
; Carry should already be clear
exit                        restoredatabank
                            retkc 4:pEntity
                            end

; -----------------------------------------------------------------------------
; Destroy a piece of sinistar
; Parameters:
; pPiece        - the piece to destroy, if null, a built piece will be picked
; wPickAnother  - if true, and the input piece is already dead, pick another.
sinistar_entity_destroy_piece start seg_entity
                            using sinistar_entity_data
                            using player_entity_data
                            using playfield_manager_data
                            using gameplay_player_logic_data
                            using gameplay_sinistar_logic_data
                            using gameplay_manager_data

                            debugtag 'destroy_piece'
                            debugtag 'sinistar_entity'

                            begin_locals
work_area_size              end_locals

                            sub (4:pPiece,2:wPickAnother),work_area_size

                            setlocaldatabank

                            lda <pPiece+2
                            bne has_piece
; Allowing for calling with null.  Get a piece
pick_another                jsl sinistar_entity_get_piece_to_destroy
                            bcs exit                                    ; Might not be anything.
                            putretptr <pPiece
; Note, not efficient, since we are getting the index and checking the state of a piece we just lookup up and already did most of this.

has_piece                   pushptr <pPiece
                            jsl sinistar_entity_get_piece_index
                            bcs exit

                            lda >gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_alive                   ; building, or dead, we can destroy any piece.
                            bne not_alive
; If he is alive, don't try and destroy a center pieces, pick another one
                            cpx #(sinistar_outer_pieces*2)
                            bge pick_another

not_alive                   lda sinistar_entity_pieces_state,x
                            cmp #sinistar_piece_state_built
                            beq is_built

                            lda <wPickAnother
                            beq is_building
                            stz <wPickAnother                           ; clear this, sinistar_entity_get_piece_to_destroy can still return something that is not built, if that is all that is left.
                            bra pick_another

is_built                    anop
                            stz sinistar_entity_pieces_state,x          ; sinistar_piece_state_not_built is == 0

; clear the sprite
; however, if sinistar is building, don't clear the first piece
                            lda >gameplay_manager~active_state+player_state~sinistar~state
;                           static_assert_equal sinistar_state_building,0
                            bne not_building
                            cpx #0                                      ; first piece?
                            beq keep_visual                             ; if so, keep the visual, even though the piece is marked as dead, as the original did.  Without this, you wouldn't know where he was, except for the scanner dot

not_building                lda #0
                            putptrlow [<pPiece],#playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr
                            putptrhigh [<pPiece],#playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr

keep_visual                 anop
; Decrement the global count
                            lda >gameplay_manager~active_state+player_state~sinistar~pieces_built
                            dec a
                            bpl ok_count                            ; test for negative, just in case.
                            lda #0
ok_count                    sta >gameplay_manager~active_state+player_state~sinistar~pieces_built
                            tax
; Need to check his state
                            lda >gameplay_manager~active_state+player_state~sinistar~state
;                           static_assert_brk sinistar_state_building,0
                            beq is_building                         ; in the building state, just exit
                            cmp #sinistar_state_dead
                            beq exit                                ; already dead, just exit
                            cpx #sinistar_center_pieces+1           ; Hmm, do we just have to kill the 'crown', or the 'crown' and the center piece?
                            blt kill_sinistar

is_building                 anop
                            jsl gameplay_stun_sinistar

exit                        restoredatabank
                            ret

; Killed Sinistar!
kill_sinistar               jsl gameplay_kill_sinistar
                            bra exit

                            end

; -----------------------------------------------------------------------------
; The is the custom draw function for the center piece, when sinistar is 'built'
; When built, the center is a single entity, rather than multiple,
; and this will also draw the animated overlay sprites.
; Note this function must be in seg_entity, as it is accessed through a short-pointer
; from that segment.
;
; This will draw the center piece as normal, but then overlay the animated mouth and eyebrows.
;
; Parameters:
; x - a short pointer to the pEntity.  The databank should be assumed to be undefined and needs to be preserved.
; dp - will be set to the grlib~dp.
; The grlib clip rect, the draw position and shape_ptr will all be setup to draw the
; primary sprite.  Note, these values do not need to be preserved.
sinistar_entity_custom_draw start seg_entity
                            using sinistar_entity_data
                            using sinistar_entity_manager_data
                            using grlib_global_equates

; Some DP values this function will use, in the grdp space
; Note, normally I'd use grdp~caller_scratch_buffer, but the caller of this function
; playfield_draw_collision_list_into_invalidated_rects, is already using scratch space.
; I'd have to get the end of that usage, into here.  I could probably do that
; by putting the struct that function is using into a data segment, but I hate how
; those equates will then become 'global'.  i.e. I don't want to add wLeft, to a data segment.
; Where I have added struct definitions to data segments, I have prefixed all the members.
; Hmm.  For now, just reverse the logic and use some space from the end of the DP.
                            begin_struct 256-6
wX                          decl word
wY                          decl word
wUseSecondary               decl word
sizeof~locals               end_struct

; Well I don't have to preserve values, but I'm going to need some of them across draw calls, so save them
                            lda <draw_x
                            sta <wX
                            lda <draw_y
                            sta <wY

; By the time we get here, the caller has determined if the shape is clipped or not and
; has picked the shape type.  We can use that to assume the clipping state of the overlay items too.
                            stz <wUseSecondary
                            getword [<shape_ptr],#shapedef~type
                            cmp #shape_data_type~compiled_basic
                            bne center_is_block

                            dec <wUseSecondary                          ; make negative
                            jsl _compiled_basic_shape_draw
                            bra draw_overlays

center_is_block             anop
                            jsl _block_shape_draw

draw_overlays               anop

; Draw animated parts, the mouth and the eyebrows.
; This does not update any animation, it just draws the current state

                            lda <wX
                            clc
                            adc #sinistar_mouth_offset_x
                            sta <draw_x

                            lda <wY
                            clc
                            adc #sinistar_mouth_offset_y
                            sta <draw_y

                            lda >sinistar_mouth_position
                            tax
                            bit <wUseSecondary
                            bpl mouth_use_primary

; Check for secondary (compiled) shape
                            getword {x},>sinistar_mouth_secondary_shape_ptrs+2
                            beq mouth_use_primary
                            sta <shape_ptr+2
                            getword {x},>sinistar_mouth_secondary_shape_ptrs
                            sta <shape_ptr

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            jsl _compiled_basic_shape_draw
                            bra draw_eyebrow

mouth_use_primary           getword {x},>sinistar_mouth_primary_shape_ptrs+2
                            sta <shape_ptr+2
                            getword {x},>sinistar_mouth_primary_shape_ptrs
                            sta <shape_ptr

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            jsl _block_shape_draw

draw_eyebrow                anop

; Eyebrow
                            lda <wX
                            clc
                            adc #sinistar_eyebrow_offset_x
                            sta <draw_x

                            lda <wY
                            clc
                            adc #sinistar_eyebrow_offset_y
                            sta <draw_y

                            lda >sinistar_eyebrow_position
                            tax
                            bit <wUseSecondary
                            bpl eyebrow_use_primary

; Check for secondary (compiled) shape
                            getword {x},>sinistar_eyebrow_secondary_shape_ptrs+2
                            beq eyebrow_use_primary
                            sta <shape_ptr+2
                            getword {x},>sinistar_eyebrow_secondary_shape_ptrs
                            sta <shape_ptr

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            jsl _compiled_basic_shape_draw
                            rts

eyebrow_use_primary         getword {x},>sinistar_eyebrow_primary_shape_ptrs+2
                            sta <shape_ptr+2
                            getword {x},>sinistar_eyebrow_primary_shape_ptrs
                            sta <shape_ptr

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            jsl _block_shape_draw
                            rts

                            end
