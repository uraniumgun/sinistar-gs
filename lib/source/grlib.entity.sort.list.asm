                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/fixed.buffer.pool.definitions.asm
                                copy lib/source/grlib.definitions.asm
                                copy lib/source/shape.definitions.asm
                                copy lib/source/framelib.definitions.asm
                                copy lib/source/grlib.sprite.definitions.asm
                                copy lib/source/grlib.entity.definitions.asm
                                copy lib/source/grlib.entity.sort.definitions.asm
                                copy lib/source/grlib.update.rects.definitions.asm

                                mcopy generated/grlib.entity.sort.list.macros

                                longa on
                                longi on

; -----------------------------------------------------------------------------
grlib_entity_sort_list_construct start seg_grlib
                                using grlib_global_data
                                using grlib_entity_manager_errors

                                debugtag 'sort_list_construct'
                                debugtag 'grlib_entity'

                                begin_locals
result                          decl word
work_area_size                  end_locals

                                sub (4:pThis,2:wMaxEntities),work_area_size
                                testptr <pThis
                                beq null_pointer

                                pushptr <pThis,#grlib_entity_sort_list~pool
                                pushsword #sizeof~grlib_entity_sort_entry
                                pushsword <wMaxEntities
                                jsl fixed_buffer_pool_construct
                                bcs allocation_error

; We are going to allocate a 'dummy' entry
; This makes it so that we know that we will never give out an address to the
; users of this system, where the lower word (short address), is $0000, allowing
; for a simple null check on those addresses.  This will also get us the bank
; value, for future use.
; We are also going to use this as the location for the list head and tail

                                pushptr <pThis,#grlib_entity_sort_list~pool
                                jsl fixed_buffer_pool_alloc
                                bcs allocation_error

                                setdatabanktoreg x
                                pha
                                putretptr [<pThis],#grlib_entity_sort_list~root_ptr
                                plx

                                putzero {x},#grlib_entity_sort_list_root~head_sptr
                                putzero {x},#grlib_entity_sort_list_root~tail_sptr

                                restoredatabank

exit                            anop
                                sta <result
                                retkc 2:result
null_pointer                    lda #grlib_entity_manager_error_null_pointer
                                sec
                                bra exit
allocation_error                lda #grlib_entity_manager_error_allocation
                                sec
                                bra exit
                                end

; -----------------------------------------------------------------------------
grlib_entity_sort_list_destruct start seg_grlib
                                using grlib_global_data

                                debugtag 'sort_list_destruct'
                                debugtag 'grlib_entity'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size
                                testptr <pThis
                                beq exit
                                pushptr <pThis,#grlib_entity_sort_list~pool
                                jsl fixed_buffer_pool_destruct

exit                            ret

                                end

; -----------------------------------------------------------------------------
; Add an entity to a sort list.
;
; Parameters:
; pThis         - the sort list
; pEntity       - the grlib entity
;
; Returns:
; Carry clear on success, set on error
; The sort list entry in a/x, for reference.  The pointer will not move, and can be stored,
; however, the list will own the pointer.
grlib_entity_sort_list_add      start seg_grlib

                                debugtag 'sort_list_add'
                                debugtag 'grlib_entity'

                                begin_locals
pEntry                          decl ptr
pHead                           decl ptr
spRootNodeHead                  decl word
spRootNodeTail                  decl word
wSortKey                        decl word
work_area_size                  end_locals

                                sub (4:pThis,4:pEntity),work_area_size

                                pushptr <pThis
                                jsl grlib_entity_sort_entry_new
                                jcs allocate_failed
                                putretptr <pEntry

                                stz <wSortKey                                   ; todo: pass this in?

                                setdatabanktoreg x

                                tax

                                lda <pEntity
                                putptrlow {x},#grlib_entity_sort_entry~entity_ptr
                                lda <pEntity+2
                                putptrhigh {x},#grlib_entity_sort_entry~entity_ptr

; Get the pointer to the root node that has the head / tail of the list
                                getword [<pThis],#grlib_entity_sort_list~root_ptr
                                tay
                                getword {y},#grlib_entity_sort_list_root~head_sptr
                                bne not_empty

; Nothing in list
                                putzero {x},#grlib_entity_sort_entry~prev_sptr
                                putzero {x},#grlib_entity_sort_entry~next_sptr
                                txa
                                putword {y},#grlib_entity_sort_list_root~head_sptr
                                putword {y},#grlib_entity_sort_list_root~tail_sptr
                                bra exit

; Search for the insert location
not_empty                       anop
; We need to access the root node, that is in Y, without using registers
                                sty <spRootNodeHead
                                iny
                                iny
                                sty <spRootNodeTail
loop                            tay
                                getword {y},#grlib_entity_sort_entry~sort_value
                                cmp <wSortKey
                                bge insert_before
                                getword {y},#grlib_entity_sort_entry~next_sptr
                                bne loop
; Reached the end, add at the tail
                                txa
                                putword {y},#grlib_entity_sort_entry~next_sptr
                                sta (<spRootNodeTail)                        ; update tail pointer
                                tya
                                putword {x},#grlib_entity_sort_entry~prev_sptr
                                putzero {x},#grlib_entity_sort_entry~next_sptr
                                bra exit

insert_before                   anop
                                getword {y},#grlib_entity_sort_entry~prev_sptr      ; prev from the insert before
                                putword {x},#grlib_entity_sort_entry~prev_sptr      ; into the prev of the insert
                                beq new_head                                        ; are we the new head?
                                txa
                                putword {y},#grlib_entity_sort_entry~prev_sptr      ; insert address, into the prev for the insert before
                                tya                                                 ; insert before address
                                putword {x},#grlib_entity_sort_entry~next_sptr      ; into the next for the insert
                                getword {x},#grlib_entity_sort_entry~prev_sptr      ; get the prev back
                                tay
                                txa
                                putword {y},#grlib_entity_sort_entry~next_sptr      ; hook in the next of that node
                                bra exit
new_head                        anop
                                tya                                                 ; insert before address
                                putword {x},#grlib_entity_sort_entry~next_sptr      ; into the next for the insert
                                putzero {x},#grlib_entity_sort_entry~prev_sptr      ; clear prev
                                txa                                                 ; insert address
                                putword {y},#grlib_entity_sort_entry~prev_sptr      ; set prev of old head to us
                                sta (<spRootNodeHead)                               ; into the head pointer

exit                            clc
                                restoredatabank
exit_failed                     retkc 4:pEntry

allocate_failed                 clearptr <pEntry
                                sec
                                bra exit_failed

                                end

; -----------------------------------------------------------------------------
; Remove an entity from the sort list, by the sort list entry (not the entity)
;
; Parameters:
; pThis         - the sort list
; pEntity       - the sort list entry the entity is using
;
; Returns:
; Carry clear on success, set on error
grlib_entity_sort_list_remove   start seg_grlib

                                debugtag 'sort_list_remove'
                                debugtag 'grlib'

                                begin_locals
pHead                           decl ptr
work_area_size                  end_locals

                                sub (4:pThis,2:spEntry),work_area_size

; Assuming that all the data is in one bank
                                getword [<pThis],#grlib_entity_sort_list~root_ptr+2
                                setdatabanktoreg a
; Get the short pointer to our node
                                ldx <spEntry
                                getword [<pThis],#grlib_entity_sort_list~root_ptr
                                jsr sort_list_disconnect_node

; Free the entry
                                pushsword [<pThis],#grlib_entity_sort_list~root_ptr+2  ; high word of the address
                                pushsword <spEntry
                                pushptr <pThis
                                jsl grlib_entity_sort_entry_delete

                                restoredatabank
                                ret
                                end

; -----------------------------------------------------------------------------
; A helper function, to disconnect a node from the linked list
; This assumes that the data bank is setup, and that the X register
; contains the node to disconnect.
; Assumes that the root node of the list (the one with the head and tail pointers)
; is in the acc.
; The links in the node that is disconnected, are not cleared
; All register are destroyed
sort_list_disconnect_node   private seg_grlib

                            pha
                            getword {x},#grlib_entity_sort_entry~prev_sptr
                            beq was_head
                            tay
                            getword {x},#grlib_entity_sort_entry~next_sptr
                            putword {y},#grlib_entity_sort_entry~next_sptr
                            beq was_tail
                            tax                                             ; x points to the next
                            tya                                             ; get the address of the prev
                            putword {x},#grlib_entity_sort_entry~prev_sptr   ; update the link
                            pla                                             ; discard
                            rts

was_head                    anop
                            getword {x},#grlib_entity_sort_entry~next_sptr
                            beq was_only_one
; new head
                            plx                                             ; get the root node address
                            putword {x},#grlib_entity_sort_list_root~head_sptr
                            tax
                            putzero {x},#grlib_entity_sort_entry~prev_sptr
                            rts

was_only_one                anop
                            plx                                             ; get the root node address
                            putzero {x},#grlib_entity_sort_list_root~head_sptr
                            putzero {x},#grlib_entity_sort_list_root~tail_sptr
                            rts

was_tail                    anop
; was the tail, but not the head, y has the new tail
                            tya
                            plx
                            putword {x},#grlib_entity_sort_list_root~tail_sptr
                            rts

                            end

; -----------------------------------------------------------------------------
; A helper function to adjust the sort location of an entry
; This assumes that the data bank is setup, and that the X register
; contains the node to move.
; This also assumes that A will contain the short pointer to the 'root' node
; where the head and tail are stored.
sort_list_adjust_node_sort  start seg_grlib

                            pha                                         ; store the root node pointer on the stack
                            getword {x},#grlib_entity_sort_entry~prev_sptr
                            beq check_next                              ; if we were the head, then check the other direction
                            tay
                            getword {y},#grlib_entity_sort_entry~sort_value
                            cmpword {x},#grlib_entity_sort_entry~sort_value
                            beq no_move                                 ; if the same as the prev, then we don't have to move
                            blt check_next                              ; if the prev is less, we don't have to move towrd the head, check moving the other way
; We have to move toward the head, find where.  We are at least in front of the entry y is pointing to now
loop_prev                   getword {y},#grlib_entity_sort_entry~prev_sptr
                            beq new_head
                            tay
                            getword {y},#grlib_entity_sort_entry~sort_value
                            cmpword {x},#grlib_entity_sort_entry~sort_value
                            blt insert_after                            ; is the node less than or equal to us?
                            beq insert_after                            ; if so, insert after it
                            bra loop_prev                               ; else we are less, and want to go before it.
new_head                    anop
; Disconnect where we are now.
                            phx
                            lda 3,s                                     ; get the root node address
                            jsr sort_list_disconnect_node
                            plx
                            ldy #grlib_entity_sort_list_root~head_sptr  ; Get the head pointer
                            lda (1,s),y
                            pha                                         ; save the old head pointer
                            txa                                         ; get our node into a
                            sta (3,s),y                                 ; while we are setup to do so, update the new head pointer
                            ply                                         ; old head is now in y

                            putword {y},#grlib_entity_sort_entry~prev_sptr
                            tya
                            putword {x},#grlib_entity_sort_entry~next_sptr
                            putzero {x},#grlib_entity_sort_entry~prev_sptr
no_move                     anop
                            pla                                         ; discard the root node pointer
                            rts

check_next                  anop
                            getword {x},#grlib_entity_sort_entry~next_sptr
                            beq no_move                         ; if we are the tail, then just exit
                            tay
                            getword {y},#grlib_entity_sort_entry~sort_value
                            cmpword {x},#grlib_entity_sort_entry~sort_value
                            bge no_move                         ; already in a good position.
; Must move toward the tail
                            getword {y},#grlib_entity_sort_entry~next_sptr
                            beq new_tail
loop_next                   tay
                            getword {y},#grlib_entity_sort_entry~sort_value
                            cmpword {x},#grlib_entity_sort_entry~sort_value
                            bge insert_before                           ; is the compare node greater than us?  If so, insert before.
                            getword {y},#grlib_entity_sort_entry~next_sptr
                            bne loop_next                               ; else we are greater, and need to go after it
; fall through to add to the tail, if we are at the end

new_tail                    anop
                            phx
                            lda 3,s                                     ; get root node pointer
                            jsr sort_list_disconnect_node
                            plx
                            ldy #grlib_entity_sort_list_root~tail_sptr  ; get the old tail pointer
                            lda (1,s),y
                            pha                                         ; save it
                            txa                                         ; get our node in a
                            sta (3,s),y                                 ; update the tail, while we have the chance
                            ply                                         ; old tail in y
                            putword {y},#grlib_entity_sort_entry~next_sptr
                            tya
                            putword {x},#grlib_entity_sort_entry~prev_sptr
                            putzero {x},#grlib_entity_sort_entry~next_sptr
                            pla                                         ; discard root node pointer
                            rts

; Insert, after y.
insert_after                anop
                            getword {y},#grlib_entity_sort_entry~next_sptr ; could be the new tail
                            beq new_tail
                            pla                                         ; get root node pointer
                            phy
                            phx
                            jsr sort_list_disconnect_node
                            plx
                            ply
; We know we are in the middle somewhere
                            getword {y},#grlib_entity_sort_entry~next_sptr
                            putword {x},#grlib_entity_sort_entry~next_sptr
                            txa
                            putword {y},#grlib_entity_sort_entry~next_sptr
                            tya
                            putword {x},#grlib_entity_sort_entry~prev_sptr
                            getword {x},#grlib_entity_sort_entry~next_sptr
                            tay
                            txa
                            putword {y},#grlib_entity_sort_entry~prev_sptr
                            rts

insert_before               anop
                            getword {y},#grlib_entity_sort_entry~prev_sptr ; could be the new head
                            jeq new_head
                            pla                                         ; get root node pointer
                            phy
                            phx
                            jsr sort_list_disconnect_node
                            plx
                            ply
; We know we are in the middle somewhere
                            getword {y},#grlib_entity_sort_entry~prev_sptr
                            putword {x},#grlib_entity_sort_entry~prev_sptr
                            txa
                            putword {y},#grlib_entity_sort_entry~prev_sptr
                            tya
                            putword {x},#grlib_entity_sort_entry~next_sptr
                            getword {x},#grlib_entity_sort_entry~prev_sptr
                            tay
                            txa
                            putword {y},#grlib_entity_sort_entry~next_sptr
                            rts

                            end

; -----------------------------------------------------------------------------
; Iterate over the update rects, drawing any sprites that overlap a rect.
; This can result in a sprite getting drawn more than once, but it should be clipped
; so that it will never overdraw itself.
;
; This implementation uses a sort list.  A sort list is a sorted, linked list of
; grlib_entity objects.
;
; It is expected that all the enties have been 'invalidated' at their current
; position, so that their bounds_rect, reflects where they are in the playfield.
;
; Parameters:
;  pEntitySortList      - Linked list of sorted grlib_entity objects

grlib_draw_sort_list_into_invalidated_rects start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'draw_sort_list'
                            debugtag 'into_invalidated_rects'

                            begin_locals
wLeft                       decl word
wRight                      decl word
wTop                        decl word
wBottom                     decl word
wClipLeft                   decl word
wClipRight                  decl word
wClipTop                    decl word
wClipBottom                 decl word
wRectCount                  decl word
wRectsOffset                decl word
wSpriteIndex                decl word
spGRValues                  decl word
pShape                      decl ptr
pSortHeadEntry              decl ptr
pSortListRootNode           decl ptr
pSortEntry                  decl ptr
pEntity                     decl ptr
wSpriteLeft                 decl word
wSpriteTop                  decl word
wSpriteRight                decl word
wSpriteBottom               decl word
work_area_size              end_locals

                            sub (4:pEntitySortList),work_area_size

                            getptr [<pEntitySortList],#grlib_entity_sort_list~root_ptr,<pSortListRootNode
                            getword [<pSortListRootNode],#grlib_entity_sort_list_root~head_sptr
                            jeq no_entries

                            sta <pSortHeadEntry
                            lda <pSortListRootNode+2        ; we want a full address, so use the root node's high address
                            sta <pSortHeadEntry+2

; We need to fill in some grlib DP values, but we have our own DP, so do them indirectly.
                            lda >grlib~dp
                            sta <spGRValues
                            tax

; Copy the clip rect, we will need it a lot
                            getword {x},>clipx_left
                            sta <wClipLeft
                            getword {x},>clipx_right
                            sta <wClipRight
                            getword {x},>clipy_top
                            sta <wClipTop
                            getword {x},>clipy_bottom
                            sta <wClipBottom

; Using local bank data
                            setlocaldatabank

                            ldx #urlib_group~update*2
                            lda update_rects_count,x
                            jeq no_rects

                            sta <wRectCount
                            lda update_rects_group_offset,x
                            sta <wRectsOffset
                            tax

loop                        anop
; Horizontal
                            lda update_rects~left,x
                            sta <wLeft
                            cmp <wClipRight
                            bsge clipped                                         ; Our x greater than our right clip, if so, it is entirely clipped
                            lda update_rects~right,x
                            cmp <wClipLeft
                            bslt clipped                                         ; Is the right x of the area, less that the left clip, if so, it is entirely clipped
                            sta <wRight
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the width will not go to 0 or less.
                            cmp <wClipRight
                            bsle ok_right                                        ; Is the right x of the area less than the right clip?
                            lda <wClipRight
                            sta <WRight
ok_right                    anop
                            lda <wLeft
                            cmp <wClipLeft
                            bsge ok_left                                         ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <wClipLeft
                            sta <wLeft
ok_left                     anop
; Vertical
                            lda update_rects~top,x
                            sta <wTop
                            cmp <wClipBottom
                            bsge clipped                                        ; Our y greater than our bottom clip, if so, it is entirely clipped
                            lda update_rects~bottom,x
                            sta <wBottom
                            cmp <wClipTop
                            bslt clipped                                        ; Is the bottom y of the area, less that the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the height will not go to 0 or less.
                            cmp <wClipBottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
                            lda <wClipBottom
                            sta <wBottom

ok_bottom                   anop
                            lda <wTop
                            cmp <wClipTop
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <wClipTop                                      ; Set the y to the top clip
                            sta <wTop

ok_top                      anop
; We now have the clipped rect locally.  See what entries overlap it
                            jsr _draw_sort_list

clipped                     anop
                            ldx <wRectsOffset
                            inx
                            inx
                            stx <wRectsOffset

                            dec <wRectCount
                            bne loop
; Restore the clip rect
                            ldx <spGRValues
                            lda <wClipTop
                            putword {x},>clipy_top
                            lda <wClipBottom
                            putword {x},>clipy_bottom
                            lda <wClipLeft
                            putword {x},>clipx_left
                            lda <wClipRight
                            putword {x},>clipx_right

no_rects                    restoredatabank
no_entries                  ret

; - Local ---------------------------------------------------------------------
; Making this a local function, just so its more readable, and we have less need for long branches
_draw_sort_list             anop
                            lda <pSortHeadEntry
                            sta <pSortEntry
                            lda <pSortHeadEntry+2
                            sta <pSortEntry+2

; Set the grlib clip rect to the local clip rect
                            ldx <spGRValues
                            lda <wTop
                            putword {x},>clipy_top
                            lda <wBottom
                            putword {x},>clipy_bottom
                            lda <wLeft
                            and #$fffe
                            putword {x},>clipx_left
                            lda <wRight
                            bit #1
                            beq not_odd
                            inc a
not_odd                     putword {x},>clipx_right

_draw_sprite_loop           getptr [<pSortEntry],#grlib_entity_sort_entry~entity_ptr,<pEntity
                            beq sprite_next         ; assume null, if high word is 0

                            getword [<pEntity],#grlib_entity~sprite+sprite~primary_shape_ptr+2
                            beq sprite_next         ; no shape?

                            jsr _draw_sprite

sprite_next                 anop
; See if we have any child entities.
                            getword [<pEntity],#grlib_entity~child_entity_ptr+2
                            bne _draw_children

; Advance to the next entry in the linked list, note all the entries are in the same bank
; so we only advance the lower word
next_sort_list_entry        getword [<pSortEntry],#grlib_entity_sort_entry~next_sptr
                            beq at_end
                            sta <pSortEntry
                            brl _draw_sprite_loop

at_end                      rts

; Draw all the children
_draw_children              anop
                            tax
                            getword [<pEntity],#grlib_entity~child_entity_ptr
                            sta <pEntity
                            stx <pEntity+2

sibling_loop                anop
                            getword [<pEntity],#grlib_entity~sprite+sprite~primary_shape_ptr+2
                            beq no_sibling_shape         ; no shape?

                            jsr _draw_sprite

no_sibling_shape            getword [<pEntity],#grlib_entity~sibling_entity_ptr+2
                            beq next_sort_list_entry
                            tax
                            getword [<pEntity],#grlib_entity~sibling_entity_ptr
                            sta <pEntity
                            stx <pEntity+2
                            bra sibling_loop

; Draw a single sprite from <pEntity
_draw_sprite                anop
; The sprite bounds and location are assumed to be in world space coordinates
; Supporting world wrapping as a compile time option
                            aif grlib~support_coordinate_wrapping=0,.skip_wrapping
; This will also compensate for world space wrapping, into the view.
                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~left
; sprite~bounds are now screen space
;                           clc
;                           adc update_rect_to_screen_space_offset_x
                            cmp update_rect_origin_wrap~x
                            bsge no_wrap_left
                            clc
                            adc update_rect_world~width
                            cmp <wRight
                            jsge sprite_clipped
                            sta <wSpriteLeft
                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~right
;                           clc
;                           adc update_rect_to_screen_space_offset_x
                            clc
                            adc update_rect_world~width
                            cmp <wLeft
                            jslt sprite_clipped
                            sta <wSpriteRight
                            bra wrapped_left

no_wrap_left                cmp <wRight
                            jsge sprite_clipped
                            sta <wSpriteLeft

                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~right
; sprite~bounds are now screen space
;                           clc
;                           adc update_rect_to_screen_space_offset_x
                            cmp update_rect_origin_wrap~x
                            bsge no_wrap_right
                            clc
                            adc update_rect_world~width
no_wrap_right               cmp <wLeft
                            jslt sprite_clipped
                            sta <wSpriteRight

wrapped_left                getword [<pEntity],#grlib_entity~sprite+sprite~bounds~top
; sprite~bounds are now screen space
;                           clc
;                           adc update_rect_to_screen_space_offset_y
                            cmp update_rect_origin_wrap~y
                            bsge no_wrap_top
                            clc
                            adc update_rect_world~height
                            cmp <wBottom
                            jsge sprite_clipped
                            sta <wSpriteTop
; We have to wrap the whole rect.
                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~bottom
; sprite~bounds are now screen space
;                           clc
;                           adc update_rect_to_screen_space_offset_y
                            clc
                            adc update_rect_world~height
                            cmp <wTop
                            jslt sprite_clipped
                            sta <wSpriteBottom
                            bra wrapped_top

no_wrap_top                 cmp <wBottom
                            jsge sprite_clipped
                            sta <wSpriteTop

                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~bottom
;                           clc
;                           adc update_rect_to_screen_space_offset_y
                            cmp update_rect_origin_wrap~y
                            bsge no_wrap_bottom
                            clc
                            adc update_rect_world~height
no_wrap_bottom              cmp <wTop
                            jslt sprite_clipped
                            sta <wSpriteBottom

wrapped_top                 anop
.skip_wrapping
                            aif grlib~support_coordinate_wrapping<>0,.skip_no_wrapping
; No coordinate wrapping
                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~left
; sprite~bounds are now screen space
;                           clc
;                           adc update_rect_to_screen_space_offset_x
                            cmp <wRight
                            jsge sprite_clipped
                            sta <wSpriteLeft

                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~right
;                           clc
;                           adc update_rect_to_screen_space_offset_x
                            cmp <wLeft
                            jslt sprite_clipped
                            sta <wSpriteRight

                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~top
; sprite~bounds are now screen space
;                           clc
;                           adc update_rect_to_screen_space_offset_y
                            cmp <wBottom
                            jsge sprite_clipped
                            sta <wSpriteTop

                            getword [<pEntity],#grlib_entity~sprite+sprite~bounds~bottom
;                           clc
;                           adc update_rect_to_screen_space_offset_y
                            cmp <wTop
                            jslt sprite_clipped
                            sta <wSpriteBottom
.skip_no_wrapping

; The sprite falls in the rect, draw it

                            ldx <spGRValues
                            getword [<pEntity],#grlib_entity~sprite+sprite~primary_shape_ptr
                            sta <pShape
                            putword {x},>shape_ptr
                            getword [<pEntity],#grlib_entity~sprite+sprite~primary_shape_ptr+2
                            sta <pShape+2
                            putword {x},>shape_ptr+2

; At this point, we assume that the bounds rect was generated, so that the upper left of the rect,
; is the draw location of the sprite, pre-adjusted for origin drawing.

; As we were doing the clipping, we turned the sprites bounds into a screen space rect.
; Put that into the draw variables.
                            lda <wSpriteLeft
                            putword {x},>draw_x
; Also fill in the screen space, erase rect for later
                            putword [<pEntity],#grlib_entity~sprite+sprite~erase~left

                            lda <wSpriteTop
                            putword {x},>draw_y
                            putword [<pEntity],#grlib_entity~sprite+sprite~erase~top

                            getword [<pShape],#shapedef~width
                            putword {x},>shape_width

                            getword [<pShape],#shapedef~height
                            putword {x},>shape_height

; Finish the sstoring the erase rect
                            lda <wSpriteRight
                            putword [<pEntity],#grlib_entity~sprite+sprite~erase~right
                            lda <wSpriteBottom
                            putword [<pEntity],#grlib_entity~sprite+sprite~erase~bottom

                            getword [<pEntity],#grlib_entity~sprite+sprite~info
                            ora #sprite~info~needs_erase
                            sta [<pEntity],y

                            getword [<pShape],#shapedef~type
                            cmp #shape_data_type~prle
                            bne not_prle
; prle shape
                            jsl _prle_shape_draw
                            bra sprite_done

not_prle                    cmp #shape_data_type~block
                            bne not_block
; block/solid shape
                            jsl _block_shape_draw
not_block                   anop

sprite_clipped              anop
sprite_done                 anop
                            rts

                            end
