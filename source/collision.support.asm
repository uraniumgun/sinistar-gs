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

                            copy source/task.definitions.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/collision.definitions.asm
                            copy source/app.debug.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/gameplay.player.definitions.asm

                            mcopy generated/collision.support.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Collision support uses a sorted, linked-list of the objects that are in the
; collision field, which we are assuming, is just the on-screen entities
; The sort currently uses just one dimension, vertical.  This means
; that we can still end up comparing to a few things that are far way, but
; it shouldn't be too bad, because we are only checking screen-space.

; -----------------------------------------------------------------------------
; Note that the collision data is separated into two sections
; the 'entry' data and the matrix and other misc data.
; This is because I want the entry data to be in the same data bank
; as the update rects, so that functions can set the data bank and use short addressing
; for both sets of data.

collision_entry_data        data seg_grlib          ; this is the same segment as the update rects

sizeof~collision_hits_entry gequ 2*2                ; two short-pointers
collision_hits_max          gequ 32                 ; max of 32 collisions in a pass
collision_hits_max_offset   gequ sizeof~collision_hits_entry*collision_hits_max

; A label for setting the databank to when the collision entries and update rects are in the same bank
collision~shared_data       anop

collision_hits_buffer       ds collision_hits_max_offset ; A buffer of pointer pairs for collisions in a pass.

; The collision entries
; Note that where this appears in this data segment is somewhat on purpose
; I don't want this pool to be mapped to $0000 in the segment, so that $0000 is
; reserved as a null short-pointer
collision~entry_pool        ds sizeof~collision_entry*collision_max_entries

; Stack of short pointers to all the free entries.
; Allocations are taken from the bottom
; Could save memory and use the unallocated entries to store a linked-list
; of the free entries, but that is slower than just having a stack of entry short-pointers
collision~free_entry_stack  ds 2*collision_max_entries
; The index one past the next free entry
collision~free_entry_stack_end ds 2

; Linked list of the allocated entries
collision_entries~head_sptr ds 2
collision_entries~tail_sptr ds 2

; Sorting on this member
collision_entity_sort_member equ playfield_entity~grentity+grlib_entity~sprite+sprite~bounds~top

                            end

; -----------------------------------------------------------------------------
collision_matrix_data       data seg_entity

; Debug Handler
collision_debug_handler_priority equ $0080          ; later in the display order

collision_debug_handler     dc i'collision_debug_handler_id'
                            dc i'collision_debug_handler_priority'
                            dc a4'collision_debug_display'
                            dc a4'collision_debug_show_help'
                            dc a4'collision_debug_keypress'

; The type v. type collision matrix.
; This is setup so that all the functions that are called are not redundant
; The first entity, has a equal or lower type number to the second entity
collision_matrix            anop
; Planetoid
                            dc a'collision_planetoid_planetoid'
                            dc a'collision_planetoid_player'
                            dc a'collision_planetoid_sinistar'
                            dc a'collision_planetoid_bomb'
                            dc a'collision_planetoid_crystal'
                            dc a'collision_planetoid_worker'
                            dc a'collision_planetoid_warrior'
                            dc a'collision_planetoid_player_shot'
                            dc a'collision_planetoid_warrior_shot'
                            dc a'collision_planetoid_explosion'

; Player
                            dc a'collision_planetoid_player'
                            dc a'collision_player_player'
                            dc a'collision_player_sinistar'
                            dc a'collision_player_bomb'
                            dc a'collision_player_crystal'
                            dc a'collision_player_worker'
                            dc a'collision_player_warrior'
                            dc a'collision_player_player_shot'
                            dc a'collision_player_warrior_shot'
                            dc a'collision_player_explosion'

; Sinistar
                            dc a'collision_planetoid_sinistar'
                            dc a'collision_player_sinistar'
                            dc a'collision_sinistar_sinistar'
                            dc a'collision_sinistar_bomb'
                            dc a'collision_sinistar_crystal'
                            dc a'collision_sinistar_worker'
                            dc a'collision_sinistar_warrior'
                            dc a'collision_sinistar_player_shot'
                            dc a'collision_sinistar_warrior_shot'
                            dc a'collision_sinistar_explosion'

; Bomb
                            dc a'collision_planetoid_bomb'
                            dc a'collision_player_bomb'
                            dc a'collision_sinistar_bomb'
                            dc a'collision_bomb_bomb'
                            dc a'collision_bomb_crystal'
                            dc a'collision_bomb_worker'
                            dc a'collision_bomb_warrior'
                            dc a'collision_bomb_player_shot'
                            dc a'collision_bomb_warrior_shot'
                            dc a'collision_bomb_explosion'

; Crystal
                            dc a'collision_planetoid_crystal'
                            dc a'collision_player_crystal'
                            dc a'collision_sinistar_crystal'
                            dc a'collision_bomb_crystal'
                            dc a'collision_crystal_crystal'
                            dc a'collision_crystal_worker'
                            dc a'collision_crystal_warrior'
                            dc a'collision_crystal_player_shot'
                            dc a'collision_crystal_warrior_shot'
                            dc a'collision_crystal_explosion'

; Worker
                            dc a'collision_planetoid_worker'
                            dc a'collision_player_worker'
                            dc a'collision_sinistar_worker'
                            dc a'collision_bomb_worker'
                            dc a'collision_crystal_worker'
                            dc a'collision_worker_worker'
                            dc a'collision_worker_warrior'
                            dc a'collision_worker_player_shot'
                            dc a'collision_worker_warrior_shot'
                            dc a'collision_worker_explosion'

; Warrior
                            dc a'collision_planetoid_warrior'
                            dc a'collision_player_warrior'
                            dc a'collision_sinistar_warrior'
                            dc a'collision_bomb_warrior'
                            dc a'collision_crystal_warrior'
                            dc a'collision_worker_warrior'
                            dc a'collision_warrior_warrior'
                            dc a'collision_warrior_player_shot'
                            dc a'collision_warrior_warrior_shot'
                            dc a'collision_warrior_explosion'

; Player shot
                            dc a'collision_planetoid_player_shot'
                            dc a'collision_player_player_shot'
                            dc a'collision_sinistar_player_shot'
                            dc a'collision_bomb_player_shot'
                            dc a'collision_crystal_player_shot'
                            dc a'collision_worker_player_shot'
                            dc a'collision_warrior_player_shot'
                            dc a'collision_player_shot_player_shot'
                            dc a'collision_player_shot_warrior_shot'
                            dc a'collision_player_shot_explosion'

; Warrior shot
                            dc a'collision_planetoid_warrior_shot'
                            dc a'collision_player_warrior_shot'
                            dc a'collision_sinistar_warrior_shot'
                            dc a'collision_bomb_warrior_shot'
                            dc a'collision_crystal_warrior_shot'
                            dc a'collision_worker_warrior_shot'
                            dc a'collision_warrior_warrior_shot'
                            dc a'collision_player_shot_warrior_shot'
                            dc a'collision_warrior_shot_warrior_shot'
                            dc a'collision_warrior_shot_explosion'

; Explosion
                            dc a'collision_planetoid_explosion'
                            dc a'collision_player_explosion'
                            dc a'collision_sinistar_explosion'
                            dc a'collision_bomb_explosion'
                            dc a'collision_crystal_explosion'
                            dc a'collision_worker_explosion'
                            dc a'collision_warrior_explosion'
                            dc a'collision_player_shot_explosion'
                            dc a'collision_warrior_shot_explosion'
                            dc a'collision_explosion_explosion'


; To keep the 'bounce' sfx from playing too much, limit the time between sfx requests
sfx_bounce_ticks_between_plays equ 4
; The last time a bounce sfx played.  Just the lower part of the tick
sfx_bounce_last_play_tick   ds 2

                            end

; -----------------------------------------------------------------------------
collision_support_initialize start seg_entity
                            using collision_entry_data
                            using collision_matrix_data

                            setdatabanktolabel collision~entry_pool

                            stz |collision_entries~head_sptr
                            stz |collision_entries~tail_sptr

                            pushptr #collision_debug_handler
                            pushsword #0                                    ; start off disabled
                            jsl appdebug_install_handler

; Make a stack of short-pointers, for allocation
                            ldx #0
                            lda #collision~entry_pool
loop                        putword {x},#collision~free_entry_stack
                            clc
                            adc #sizeof~collision_entry
                            inx
                            inx
                            cpx #collision_max_entries*2
                            bne loop

                            stx |collision~free_entry_stack_end

                            clc
                            restoredatabank
                            rtl

                            end

; -----------------------------------------------------------------------------
collision_support_uninitialize start seg_entity

                            rtl
                            end

; -----------------------------------------------------------------------------
collision_support_turn_activate start seg_entity
                            using collision_entry_data

                            lda >collision~free_entry_stack_end
                            cmp #collision_max_entries*2
                            beq ok
                            assert_brk 'collision not clear'
ok                          rtl
                            end

; -----------------------------------------------------------------------------
; Add an entity to its assigned collision list
; This assumes that the data bank is set to the collision entry data bank
;
; Parameters:
;  x-reg      - the entity to add
;
collision_add_to_list       start seg_entity
                            using collision_entry_data
                            using gameplay_entity_data

                            debugtag 'add_to_list_collision'

;                           setdatabanktolabel collision~entry_pool

                            txy                                     ; save the entity
; Get the collision type
                            getword {x},>entities_root+playfield_entity~characteristic_id
                            tax
                            lda >characteristics_table+gameplay_entity_characteristic~collision_type,x
                            pha                                     ; save for later
                            tyx                                     ; get the entity back in x

; Get a free collision entry
                            ldy |collision~free_entry_stack_end
                            jeq allocation_error
                            dey
                            dey
                            sty |collision~free_entry_stack_end
                            getword {y},#collision~free_entry_stack
                            tay                                     ; Y can hold the short address to the sort entry
; Store the pointer
                            txa                                     ; entity short pointer -> a
                            putword {y},#collision_entry~entity_sptr
                            pla                                     ; get collision type
                            putword {y},#collision_entry~collision_type

; Store the rect.  Note, using the bounds rect, as that is the last draw location.
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~sprite+sprite~bounds~left
                            putword {y},#collision_entry~rect+grlib_rect~left
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~sprite+sprite~bounds~top
                            sta >patch_sort_key+1
                            putword {y},#collision_entry~rect+grlib_rect~top
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~sprite+sprite~bounds~right
                            putword {y},#collision_entry~rect+grlib_rect~right
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~sprite+sprite~bounds~bottom
                            putword {y},#collision_entry~rect+grlib_rect~bottom
; Flag that it is on the list
                            getword {x},>entities_root+playfield_entity~state_flags
                            ora #playfield_entity~state_on_collision_list
                            putword {x},>entities_root+playfield_entity~state_flags
; Store the short pointer to the entry.  Could put the full pointer, if it is more convenient in the long run.
                            tya
                            putword {x},>entities_root+playfield_entity~collision_list_entry_sptr

; We now need to figure out where it goes in the list.
; Sorting by the top line of the image
                            lda |collision_entries~head_sptr
                            bne not_empty
; Nothing in list
                            lda #0
                            putword {y},#collision_entry~prev_sptr
                            putword {y},#collision_entry~next_sptr
                            tya
                            sta |collision_entries~head_sptr
                            sta |collision_entries~tail_sptr
                            bra exit
; Search for the insert location
not_empty                   anop
                            tyx                                         ; y had the short-pointer to the new entry, but now we want it in x
loop                        tay
                            getword {y},#collision_entry~rect+grlib_rect~top
patch_sort_key              cmp #$0000                                  ; will be patched with the sort key
                            bsge insert_before
                            getword {y},#collision_entry~next_sptr
                            bne loop
; Reached the end, add at the tail
                            txa
                            putword {y},#collision_entry~next_sptr
                            sta |collision_entries~tail_sptr            ; update tail pointer
                            tya
                            putword {x},#collision_entry~prev_sptr
                            putzero {x},#collision_entry~next_sptr
                            bra exit

insert_before               anop
                            getword {y},#collision_entry~prev_sptr      ; prev from the insert before
                            putword {x},#collision_entry~prev_sptr      ; into the prev of the insert
                            beq new_head                                ; are we the new head?
                            txa
                            putword {y},#collision_entry~prev_sptr      ; insert address, into the prev for the insert before
                            tya                                         ; insert before address
                            putword {x},#collision_entry~next_sptr      ; into the next for the insert
                            getword {x},#collision_entry~prev_sptr      ; get the prev back
                            tay
                            txa
                            putword {y},#collision_entry~next_sptr      ; hook in the next of that node
                            bra exit
new_head                    anop
                            tya                                         ; insert before address
                            putword {x},#collision_entry~next_sptr      ; into the next for the insert
                            putzero {x},#collision_entry~prev_sptr      ; clear prev
                            txa                                         ; insert address
                            putword {y},#collision_entry~prev_sptr      ; set prev of old head to us
                            sta |collision_entries~head_sptr            ; into the head pointer

exit                        anop
error_exit                  anop
;                           restoredatabank
                            rts
allocation_error            anop
                            pla                                         ; remove the saved collision type
                            assert_brk 'collision_add_to_list'
                            bra error_exit

                            end

; -----------------------------------------------------------------------------
; Add an entity to a collision array
; This assumes that the data bank is set to the collision entry data bank
;
; Parameters:
;  x-reg      - the entity to add
collision_remove_from_list  start seg_entity
                            using collision_entry_data

                            debugtag 'remove_from_list_collision'

                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list                   ; redundant check?  Caller should have most likely checked already.
                            beq not_on_list
; Clear the collision list flag.  Also clear a few other things that are 'on screen' only flags
                            and #((playfield_entity~state_on_collision_list+playfield_entity~state_first_update+playfield_entity~state_bounce_bits)*-1)-1
                            putword {x},>entities_root+playfield_entity~state_flags         ; clear it.

;                           setdatabanktolabel collision~entry_pool

; Get the short pointer to our node
                            getword {x},>entities_root+playfield_entity~collision_list_entry_sptr
; Put the entry back on the free stack
                            ldy |collision~free_entry_stack_end
                            putword {y},#collision~free_entry_stack
                            iny
                            iny
                            sty |collision~free_entry_stack_end
                            tax

; Disconnect, this just uses what is in the x register (the entry)
                            jsr collision_disconnect_node

;                           restoredatabank
not_on_list                 anop
                            rts
                            end


; -----------------------------------------------------------------------------
; A helper function, to disconnect a node from the collision linked list
; This assumes that the data bank is setup, and that the X register
; contains the node to disconnect.
; The links in the node that is disconnected, are not cleared
; All register are destroyed
collision_disconnect_node   private seg_entity
                            using collision_entry_data

                            getword {x},#collision_entry~prev_sptr
                            beq was_head
                            tay
                            getword {x},#collision_entry~next_sptr
                            putword {y},#collision_entry~next_sptr
                            beq was_tail
                            tax                                     ; x points to the next
                            tya                                     ; get the address of the prev
                            putword {x},#collision_entry~prev_sptr  ; update the link
                            rts

was_head                    anop
                            getword {x},#collision_entry~next_sptr
                            beq was_only_one
; new head
                            sta |collision_entries~head_sptr
                            tay
                            lda #0
                            putword {y},#collision_entry~prev_sptr
                            rts

was_only_one                anop
                            stz |collision_entries~head_sptr
                            stz |collision_entries~tail_sptr
                            rts

was_tail                    anop
; was the tail, but not the head, y has the new tail
                            tya
                            sta |collision_entries~tail_sptr
                            rts

                            end

; -----------------------------------------------------------------------------
; A helper function to adjust the sort location of an entry
; This assumes that the data bank is setup, and that the X register
; contains the node to move.
collision_adjust_node_sort  start seg_entity
                            using collision_entry_data

; So, I can try and buffer the 'sort key' at this point, using the stack, and then doing a cmp 1,S, but
; it will take 15 cycles to do so. The get, push, and a pop later to clear it.
; I will only save 1 cycle on the compare.  Is it worth it?  This function is called as the object is moving
; or changing size, and shouldn't cause much change, if at all.  Also, this is screen only, so I don't think it is worth it.

                            getword {x},#collision_entry~prev_sptr
                            beq check_next                              ; if we were the head, then check the other direction
                            tay
                            getword {y},#collision_entry~rect+grlib_rect~top
                            cmpword {x},#collision_entry~rect+grlib_rect~top
                            beq no_move                                 ; if the same as the prev, then we don't have to move
                            bslt check_next                              ; if the prev is less, we don't have to move towrd the head, check moving the other way
; We have to move toward the head, find where.  We are at least in front of the entry y is pointing to now
loop_prev                   getword {y},#collision_entry~prev_sptr
                            beq new_head
                            tay
                            getword {y},#collision_entry~rect+grlib_rect~top
                            cmpword {x},#collision_entry~rect+grlib_rect~top
                            bslt insert_after                            ; is the node less than or equal to us?
                            beq insert_after                            ; if so, insert after it
                            bra loop_prev                               ; else we are less, and want to go before it.
new_head                    anop
; Disconnect where we are now.  Could just inline that and save a few cycles.
                            phx
                            jsr collision_disconnect_node
                            plx
                            lda |collision_entries~head_sptr
                            tay

                            txa
                            putword {y},#collision_entry~prev_sptr
                            sta |collision_entries~head_sptr
                            tya
                            putword {x},#collision_entry~next_sptr
                            putzero {x},#collision_entry~prev_sptr
no_move                     anop
                            rts

check_next                  anop
                            getword {x},#collision_entry~next_sptr
                            beq no_move                         ; if we are the tail, then just exit
                            tay
                            getword {y},#collision_entry~rect+grlib_rect~top
                            cmpword {x},#collision_entry~rect+grlib_rect~top
                            bsge no_move                         ; already in a good position.
; Must move toward the tail
                            getword {y},#collision_entry~next_sptr
                            beq new_tail
loop_next                   tay
                            getword {y},#collision_entry~rect+grlib_rect~top
                            cmpword {x},#collision_entry~rect+grlib_rect~top
                            bsge insert_before                           ; is the compare node greater than us?  If so, insert before.
                            getword {y},#collision_entry~next_sptr
                            bne loop_next                               ; else we are greater, and need to go after it
; fall through to add to the tail, if we are at the end

new_tail                    anop
                            phx
                            jsr collision_disconnect_node
                            plx
                            lda |collision_entries~tail_sptr
                            tay
                            txa
                            putword {y},#collision_entry~next_sptr
                            sta |collision_entries~tail_sptr
                            tya
                            putword {x},#collision_entry~prev_sptr
                            putzero {x},#collision_entry~next_sptr
                            rts

insert_before               anop
                            getword {y},#collision_entry~prev_sptr          ; could be the new head
                            beq new_head
                            phy
                            phx
                            jsr collision_disconnect_node
                            plx
                            ply
; We know we are in the middle somewhere
                            getword {y},#collision_entry~prev_sptr
                            putword {x},#collision_entry~prev_sptr
                            txa
                            putword {y},#collision_entry~prev_sptr
                            tya
                            putword {x},#collision_entry~next_sptr
                            getword {x},#collision_entry~prev_sptr
                            tay
                            txa
                            putword {y},#collision_entry~next_sptr
                            rts

; Insert, after y.
insert_after                anop
                            getword {y},#collision_entry~next_sptr          ; could be the new tail
                            beq new_tail
                            phy
                            phx
                            jsr collision_disconnect_node
                            plx
                            ply
; We know we are in the middle somewhere
                            getword {y},#collision_entry~next_sptr
                            putword {x},#collision_entry~next_sptr
                            txa
                            putword {y},#collision_entry~next_sptr
                            tya
                            putword {x},#collision_entry~prev_sptr
                            getword {x},#collision_entry~next_sptr
                            tay
                            txa
                            putword {y},#collision_entry~prev_sptr
                            rts

                            end

; -----------------------------------------------------------------------------
; Test for collisions
; The collision list is sorted by the top of the rect, so we iterate
; from the head.  If the compare's top, is less than the source's bottom, we have
; an overlap in the vertical direction.  If not, then we can be assured that
; no further compares would match, because all further ones, have a top that is
; greater than or equal to the one we checked against.
;
collision_test_all          start seg_entity
                            using collision_entry_data
                            using collision_matrix_data

                            debugtag 'test_all'
                            debugtag 'collision'

                            begin_locals
wCollisionHitsOffset        decl word
wOuterCollisionType         decl word
wOverlapHeight              decl word
wOutlineAdjust              decl word
spOuterCollision            decl word
spInnerCollision            decl word
pOuterShape                 decl ptr
pInnerShape                 decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            lda >collision_entries~head_sptr
                            jeq none
                            tax

                            setdatabanktolabel collision~entry_pool

                            stz <wCollisionHitsOffset

loop                        getword {x},#collision_entry~next_sptr
                            beq done                                            ; any more to test?
                            tay
                            getword {x},#collision_entry~collision_type
                            beq next_outer                                      ; no collisions?
                            sta <wOuterCollisionType
next_inner                  getword {y},#collision_entry~collision_type         ; get the compare's collision type
                            beq no_overlap                                      ; no collisions?
; because the list is sorted by the top value, we only have to check if the top of the inner compare entity,
; is less than the outer compare entity, to know if it overlaps vertically.
                            getword {y},#collision_entry~rect+grlib_rect~top    ; get the compare's top, and check against the source bottom
                            cmpword {x},#collision_entry~rect+grlib_rect~bottom
                            bslt compare_rect
; not overlapping, and there can be no more, we are done with this one.
next_outer                  getword {x},#collision_entry~next_sptr
                            tax
                            bra loop
; we know that the source is overlapping vertically
compare_rect                anop
                            getword {y},#collision_entry~rect+grlib_rect~right
                            cmpword {x},#collision_entry~rect+grlib_rect~left
                            bslt no_overlap
                            getword {x},#collision_entry~rect+grlib_rect~right
                            cmpword {y},#collision_entry~rect+grlib_rect~left
                            bslt no_overlap
; Test if the outer is a 'no collide with same type'
                            lda <wOuterCollisionType
                            bpl no_ignore
                            cmpword {y},#collision_entry~collision_type
                            beq no_overlap                                  ; same type, we don't collide

no_ignore                   anop
; We overlap.  Add to a temporary list, so we can call the handler, outside of iterating over the list
; This will allow the handlers a bit more freedom to add / remove things, which might upset the list.
; This isn't particularly fast...

                            jsr outline_check
                            bcs no_overlap

                            phx
                            getword {x},#collision_entry~entity_sptr
                            ldx <wCollisionHitsOffset
                            putword {x},#collision_hits_buffer
                            getword {y},#collision_entry~entity_sptr
                            putword {x},#collision_hits_buffer+2
                            txa
                            clc
                            adc #sizeof~collision_hits_entry
                            sta <wCollisionHitsOffset
                            plx
                            cmp #collision_hits_max_offset                  ; have we hit our max?
                            beq done

no_overlap                  anop
                            getword {y},#collision_entry~next_sptr
                            beq next_outer
                            tay
                            bra next_inner

done                        anop

; Did we have any hits we saved?
                            ldx #0
                            cpx <wCollisionHitsOffset
                            beq no_hits

; Yes call them
; All the collision handlers can assume the databank is pointing to the entities bank
; Doing this without saving the bank, as we will be restoring it as we exit.
                            shortm
                            lda #^entities_root
                            pha
                            longm
                            plb

call_loop                   phx

                            lda >collision_hits_buffer+2,x                  ; second entity into y
                            tay
                            lda >collision_hits_buffer,x
                            tax                                             ; first in x

                            jsl collision_handler

                            pla
                            clc
                            adc #sizeof~collision_hits_entry
                            tax
                            cpx <wCollisionHitsOffset
                            bne call_loop

no_hits                     anop
                            restoredatabank
none                        anop
                            ret

;;;
; local function to do an outline check

no_outline                  anop
                            ldx <spOuterCollision
                            ldy <spInnerCollision
                            clc
                            rts

outline_check               anop
; we are going to need x and y, so save them
                            stx <spOuterCollision
                            sty <spInnerCollision
; get the outline tables
                            getword {x},#collision_entry~entity_sptr
                            pha
; get the inner shape pointer
                            getword {y},#collision_entry~entity_sptr
                            tax
                            getword {x},>entities_root+sprite~primary_shape_ptr
                            putword <pInnerShape
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            putword <pInnerShape+2
; get the outer shape pointer
                            plx
                            getword {x},>entities_root+sprite~primary_shape_ptr
                            putword <pOuterShape
                            getword {x},>entities_root+sprite~primary_shape_ptr+2
                            putword <pOuterShape+2

                            getword [<pOuterShape],#shapedef~outline_data_offset
                            beq no_outline
                            clc
                            adc <pOuterShape
                            sta <pOuterShape                                ; now points to the outline data
                            getword [<pInnerShape],#same
                            beq no_outline
                            clc
                            adc <pInnerShape
                            sta <pInnerShape                                ; now points to the outline data

; get our collision entry short-pointers back
                            ldx <spOuterCollision
                            ldy <spInnerCollision
; We know from the sort, that the outer compare's {x} top is less than or equal to the inner compare's {y} top
; Get Y offset of the outer compare's rect we will start to test from.
                            getword {y},#collision_entry~rect+grlib_rect~top
                            sec
                            sbcword {x},#collision_entry~rect+grlib_rect~top
;                           sta <wOuterYOffset
                            shiftleft 2                                     ; each outline entry is 4 bytes
                            clc
                            adc <pOuterShape
                            sta <pOuterShape
; Now we have to find the overlap height
                            getword {y},#collision_entry~rect+grlib_rect~bottom
                            cmpword {x},#collision_entry~rect+grlib_rect~bottom
                            bslt inner_bottom_less
; the outer bottom is less, so subtract that from the inner top
                            getword {x},#collision_entry~rect+grlib_rect~bottom
                            sec
                            sbcword {y},#collision_entry~rect+grlib_rect~top
                            bra got_overlap_height
; the inner bottom is less, so the entire height of the inner is inside the outer
inner_bottom_less           getword {y},#collision_entry~rect+grlib_rect~bottom
                            sec
                            sbcword {y},#collision_entry~rect+grlib_rect~top
got_overlap_height          sta <wOverlapHeight

; Now see the outer compare's left edge is greater than or equal to the inner's
                            getword {x},#collision_entry~rect+grlib_rect~left
                            cmpword {y},#collision_entry~rect+grlib_rect~left
                            bsge outer_left_to_inner_right
; The inner is greater, so we will compare the inner's left to the outer's right
                            getword {y},#collision_entry~rect+grlib_rect~left
                            sec
                            sbcword {x},#collision_entry~rect+grlib_rect~left
                            sta <wOutlineAdjust
; advance the outer shape's outline pointer so it starts at the right edge
                            inc <pOuterShape
                            inc <pOuterShape
                            ldy #0
outer_is_right_loop         lda [<pOuterShape],y
                            sec
                            sbc <wOutlineAdjust
                            cmp [<pInnerShape],y
                            bsge has_collision
                            iny
                            iny
                            iny
                            iny
                            dec <wOverlapHeight
                            bne outer_is_right_loop
                            bra no_outline_collision

; The outer is greater, so we will compare the outer's left to the inners's right
outer_left_to_inner_right   anop
                            getword {x},#collision_entry~rect+grlib_rect~left
                            sec
                            sbcword {y},#collision_entry~rect+grlib_rect~left
                            sta <wOutlineAdjust
; advance the inner shape's outline pointer so it starts at the right edge
                            inc <pInnerShape
                            inc <pInnerShape
                            ldy #0
inner_is_right_loop         lda [<pInnerShape],y
                            sec
                            sbc <wOutlineAdjust
                            cmp [<pOuterShape],y
                            bsge has_collision
                            iny
                            iny
                            iny
                            iny
                            dec <wOverlapHeight
                            bne inner_is_right_loop

no_outline_collision        anop
                            ldx <spOuterCollision
                            ldy <spInnerCollision
                            sec
                            rts

has_collision               anop
                            ldx <spOuterCollision
                            ldy <spInnerCollision
                            clc
                            rts

                            end

; ----------------------------------------------------------------------------
; Handle a collision between two entities
; Parameters:
; x-reg  - short pointer to entity1
; y-reg  - short pointer to entity2
;
; Assumes the databank is set to the entities bank
collision_handler           private seg_entity
                            using collision_matrix_data

                            begin_locals
spEntity1                   decl word
spEntity2                   decl word
wRowIndex                   decl word
wTemp                       decl word
work_area_size              end_locals

                            sub ,work_area_size

                            stx <spEntity1
                            sty <spEntity2

; Compare the types, to see which is lower
                            getword {x},#playfield_entity~type
                            cmpword {y},#playfield_entity~type
                            blt first_is_le
                            beq first_is_le
; Second entry is lower
                            getword {y},#playfield_entity~type
                            static_assert_equal entity_type~count,10
                            asl a                           ; x 2
                            sta <wTemp
                            asl a                           ; x 2
                            asl a                           ; x 2 == x 8
                            adc <wTemp                      ; + (x 2) == x 10
                            asl a                           ; * 2, for the short address width
                            sta <wRowIndex
                            getword {x},#playfield_entity~type
                            shiftleft 1                     ; * 2, for the short address width
                            adc <wRowIndex
                            tax

                            pushsword <spEntity2
                            pushsword <spEntity1
                            jsr (collision_matrix,x)
null_pointer                ret

; First entry has a lower type, we don't have to swap
first_is_le                 anop
                            static_assert_equal entity_type~count,10
                            asl a                           ; x 2
                            sta <wTemp
                            asl a                           ; x 2
                            asl a                           ; x 2 == x 8
                            adc <wTemp                      ; + (x 2) == x 10
                            asl a                           ; * 2, for the short address width
                            sta <wRowIndex
                            getword {y},#playfield_entity~type
                            shiftleft 1                     ; * 2, for the short address width
                            adc <wRowIndex
                            tax

                            pushsword <spEntity1
                            pushsword <spEntity2
                            jsr (collision_matrix,x)
                            ret

                            end

; -----------------------------------------------------------------------------
; Debug Draw all the collision rects
; Parameters:
; wOptions - bit 0, off = skip, on = test other bits
;            bit 1, off = pause for a few frames, then continue, on = wait for keypress
; Returns:
; carry set, if the user pressed ESC during a wait.
collision_rects_debug_draw  start seg_entity
                            using collision_entry_data
                            using gameplay_level_data

                            debugtag 'debug_draw'
                            debugtag 'collision'

                            begin_locals
wX                          decl word
wY                          decl word
wWidth                      decl word
wHeight                     decl word
wViewTop                    decl word
wViewBottom                 decl word
wViewBottomPlus1            decl word
work_area_size              end_locals

                            sub (2:wOptions),work_area_size

                            lda >collision_entries~head_sptr
                            jeq none
                            tax

                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~top
                            sta <wViewTop
                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~bottom
                            sta <wViewBottom
                            inc a
                            sta <wViewBottomPlus1
                            setdatabanktolabel collision~entry_pool

loop                        getword {x},#collision_entry~next_sptr
                            beq done                                            ; any more to test?
                            getword {x},#collision_entry~collision_type
                            bne draw_rect                                       ; no collisions? Skip rect
;
next_rect                   anop
                            getword {x},#collision_entry~next_sptr
                            tax
                            bra loop

done                        anop
                            lda <wOptions
                            jsl grlib_debug_pause

                            restoredatabank
none                        anop
                            retkc

;
draw_rect                   anop
                            phx
; The rect is in screen space, but clip to the view.  We are going to assume the left/right are 0, 320
; The vertical will clip to the view area top / bottom.
                            getword {x},#collision_entry~rect+grlib_rect~left
                            bpl ok_x
                            lda #0
ok_x                        cmp #320
                            bge off_edge
                            sta <wX
                            getword {x},#collision_entry~rect+grlib_rect~top
                            cmp <wViewTop
                            bge ok_y
                            lda <wViewTop
ok_y                        cmp <wViewBottom
                            bge off_edge
                            sta <wY
                            getword {x},#collision_entry~rect+grlib_rect~right
                            sec
                            sbcword {x},#collision_entry~rect+grlib_rect~left
                            beq off_edge
                            bcc off_edge
                            sta <wWidth
                            clc
                            adc <wX
                            cmp #321
                            blt ok_width
                            lda #320
                            sec
                            sbc <wX
                            beq off_edge
                            bcc off_edge
                            sta <wWidth
ok_width                    anop

                            getword {x},#collision_entry~rect+grlib_rect~bottom
                            sec
                            sbcword {x},#collision_entry~rect+grlib_rect~top
                            beq off_edge
                            bcc off_edge
                            sta <wHeight
                            clc
                            adc <wY
                            cmp <wViewBottomPlus1
                            blt ok_height
                            lda <wViewBottom
                            sec
                            sbc <wY
                            beq off_edge
                            bcc off_edge
                            sta <wHeight

ok_height                   anop
                            pushsword <wX
                            pushsword <wY
                            pushsword <wWidth
                            pushsword <wHeight
                            pushsword #$ffff
                            pushsword #0
                            jsl grlib_draw_debug_rect
off_edge                    anop
                            plx
                            brl next_rect

                            end

;;; The entity v. entity collision handlers

;;;; Planetoid v.

; ----------------------------------------------------------------------------
collision_planetoid_planetoid private seg_entity

                            begin_locals
pTaskData                   decl ptr                        ; the task data for any vibration.  Keep this first!
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Remove the vibration deltas
                            ldx <spEntity1
                            jsr entity_remove_vibration_delta
                            ldx <spEntity2
                            jsr entity_remove_vibration_delta

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

; Restore the vibration delta
                            ldx <spEntity1
                            jsr entity_restore_vibration_delta
                            ldx <spEntity2
                            jsr entity_restore_vibration_delta

                            lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_player  private seg_entity
                            using gameplay_sound_data
                            using gameplay_player_logic_data

                            begin_locals
pTaskData                   decl ptr                        ; the task data for any vibration.  Keep this first!
wDeltaX                     decl word
wDeltaY                     decl word
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lda >gameplay_player~collisions_disabled
                            bne exit

; Remove the vibration delta on the planetoid.  Does not remove the vibration task.
; If there is none, we are doing a lot of work for nothing here and restoring.  Maybe test here first?  Maybe use macros?
                            ldx <spEntity1
                            jsr entity_remove_vibration_delta

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

; Restore the vibration delta on the planetoid
                            ldx <spEntity1
                            jsr entity_restore_vibration_delta

exit                        lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_sinistar private seg_entity

                            begin_locals
pTaskData                   decl ptr                        ; the task data for any vibration.  Keep this first!
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Remove the vibration delta on the planetoid and Sinistar
                            ldx <spEntity1
                            jsr entity_remove_vibration_delta
                            ldx <spEntity2
                            jsr entity_remove_vibration_delta

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

; Restore the vibration delta
                            ldx <spEntity1
                            jsr entity_restore_vibration_delta
                            ldx <spEntity2
                            jsr entity_restore_vibration_delta

                            lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_bomb    private seg_entity
                            using gameplay_sound_data
                            using gameplay_ui_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            jsl explosion_entity_manager_add_explosion

                            ldx <spEntity1
                            jsl playfield_entity_mark_for_removal
                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

; Do we get a score for this?

                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

; Post message
                            lda #gameplay_ui~message_sinibomb_intercepted
                            jsl gameplay_ui_set_active_player_message

                            lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_crystal private seg_entity

                            begin_locals
pTaskData                   decl ptr                        ; the task data for any vibration.  Keep this first!
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Remove the vibration delta on the planetoid.  Does not remove the vibration task.
; If there is none, we are doing a lot of work for nothing here and restoring.  Maybe test here first?  Maybe use macros?
                            ldx <spEntity1
                            jsr entity_remove_vibration_delta

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

; Restore the vibration delta on the planetoid
                            ldx <spEntity1
                            jsr entity_restore_vibration_delta

                            lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_worker  private seg_entity
                            using gameplay_sound_data

                            begin_locals
pTaskData                   decl ptr                        ; the task data for any vibration.  Keep this first!
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Remove the vibration delta on the planetoid.  Does not remove the vibration task.
; If there is none, we are doing a lot of work for nothing here and restoring.  Maybe test here first?  Maybe use macros?
                            ldx <spEntity1
                            jsr entity_remove_vibration_delta

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

; Restore the vibration delta on the planetoid
                            ldx <spEntity1
                            jsr entity_restore_vibration_delta

                            lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_warrior private seg_entity
                            using gameplay_sound_data

                            begin_locals
pTaskData                   decl ptr                        ; the task data for any vibration.  Keep this first!
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Remove the vibration delta on the planetoid.  Does not remove the vibration task.
; If there is none, we are doing a lot of work for nothing here and restoring.  Maybe test here first?  Maybe use macros?
                            ldx <spEntity1
                            jsr entity_remove_vibration_delta

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

; Restore the vibration delta on the planetoid
                            ldx <spEntity1
                            jsr entity_restore_vibration_delta

                            lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_player_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            ldx <spEntity1
                            jsl gameplay_entity_add_vibration
                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_warrior_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            ldx <spEntity1
                            jsl gameplay_entity_add_vibration
                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            lret
                            end

; ----------------------------------------------------------------------------
collision_planetoid_explosion private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;; Player v.

; ----------------------------------------------------------------------------
collision_player_player     private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_player_sinistar   private seg_entity
                            using gameplay_manager_data
                            using gameplay_player_logic_data
                            using gameplay_sinistar_logic_data
                            using sinistar_entity_data
                            using player_entity_data
                            using gameplay_sound_data
                            using task_manager_data

                            begin_locals
pTaskData                   decl ptr
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Sinistar alive?
                            lda >gameplay_manager~active_state+player_state~sinistar~state
;                           static_assert_equal sinistar_state_building,0
                            beq is_building
                            cmp #sinistar_state_alive
                            bne exit

; Check to see if we have already started this process
                            lda >gameplay_player~is_dead
                            ora >gameplay_player~is_dying
                            bne exit

; Start the "bite the player" sequence

; Stop Sinistar
                            ldx <spEntity2
                            putzero {x},#playfield_entity~speed_x
                            putzero {x},#playfield_entity~speed_y
; Stop the player
                            ldx <spEntity1
                            putzero {x},#playfield_entity~speed_x
                            putzero {x},#playfield_entity~speed_y

; Stop the taunt task
                            jsl gameplay_sinistar_clear_taunt_task
; Do a roar.
                            jsl gameplay_sinistar_stop_speech               ; cancel anything he might be saying now
                            pushsword #id_sfx~EEERRAAURGH_death             ; we play the special 'death' roar, that is the same sound, but the animation with it, keep his mouth open
                            jsl gameplay_sinistar_play_speech

; Create a task to do the first part of the player kill sequence
                            pushsword #task_list_1_offset
                            pushptr #gameplay_task_sinistar_player_kill
                            pushsword #sizeof~gameplay_sinistar_shared_task_data
                            jsl task_manager_create_task
                            bcs exit
                            putretptr <pTaskData
; Add a timer for how long the roar is for
                            lda #id_sfx~EEERRAAURGH~tick_length
                            putword [<pTaskData],#task_timer_header~timer
; Not storing entity, we have globals sinistar and the player

; Turn off collisions for the player
; Disable player controls, and mark that the player is in sinistar's death grips.  They can escape this with luck!
                            lda #$8000
                            sta >gameplay_player_controls~disabled
                            sta >gameplay_player~is_dying
                            sta >gameplay_player~collisions_disabled

                            bra exit

is_building                 anop
; Act like a bonce off a planetoid
                            pushsword <spEntity2
                            pushsword <spEntity1
                            jsr collision_planetoid_player

exit                        lret
                            end

; ----------------------------------------------------------------------------
collision_player_bomb       private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_player_crystal    private seg_entity
                            using gameplay_player_logic_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lda >gameplay_player~collisions_disabled
                            bne exit

                            jsl gameplay_player_add_bomb                ; try to add a bomb

                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            lda #gameplay_score~capture_crystal
                            jsl gameplay_add_to_score

; note, sfx played in the add_bomb code

exit                        lret
                            end

; ----------------------------------------------------------------------------
collision_player_worker     private seg_entity
                            using gameplay_sound_data
                            using gameplay_player_logic_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lda >gameplay_player~collisions_disabled
                            bne exit

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

exit                        lret
                            end

; ----------------------------------------------------------------------------
collision_player_warrior    private seg_entity
                            using gameplay_sound_data
                            using gameplay_player_logic_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lda >gameplay_player~collisions_disabled
                            bne exit

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

exit                        lret
                            end

; ----------------------------------------------------------------------------
collision_player_player_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_player_warrior_shot private seg_entity
                            using gameplay_player_logic_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            lda >gameplay_player~collisions_disabled
                            bne exit

                            pushsword #0                                ; not killed by sinistar
                            jsl gameplay_player_die

exit                        lret
                            end

; ----------------------------------------------------------------------------
collision_player_explosion private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;; Sinistar v.

; ----------------------------------------------------------------------------
collision_sinistar_sinistar private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_sinistar_bomb     private seg_entity
                            using sinistar_entity_data
                            using gameplay_player_logic_data
                            using gameplay_sinistar_logic_data
                            using gameplay_manager_data
                            using gameplay_sound_data
                            using gameplay_ui_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Test for multiple collisions
                            ldx <spEntity2
                            getword {x},#playfield_entity~state_flags
                            bit #playfield_entity~state_marked_for_removal
                            bne already_collided

; We hit! Destroy a piece!
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl explosion_entity_manager_add_explosion

                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

                            lda >gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_dead
                            beq already_collided                    ; already dead?

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushsword #1                            ; ok, with killing another piece, if this is already dead
                            jsl sinistar_entity_destroy_piece

; Add vibration to the root piece
                            lda >sinistar_entity_root_piece_ptr
                            tax
                            jsl gameplay_entity_add_vibration

; On screen collision, stuns sinistar for 2 frames
                            lda >gameplay_sinistar_logic~in_stun
                            inc a
                            inc a
                            sta >gameplay_sinistar_logic~in_stun
; Post message
                            lda #gameplay_ui~message_sinibomb_attack
                            jsl gameplay_ui_set_active_player_message

already_collided            lret
                            end

; ----------------------------------------------------------------------------
collision_sinistar_crystal  private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_sinistar_worker   private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_sinistar_warrior  private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_sinistar_player_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Just remove the shot
                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            lret
                            end

; ----------------------------------------------------------------------------
collision_sinistar_warrior_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_sinistar_explosion private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;; Bomb v.

; ----------------------------------------------------------------------------
collision_bomb_bomb         private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_bomb_crystal      private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_bomb_worker       private seg_entity
                            using gameplay_ui_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Same as the worker hitting a player shot
                            pushsword <spEntity2
                            pushsword <spEntity1
                            jsr collision_worker_player_shot

; Post message
                            lda #gameplay_ui~message_sinibomb_intercepted
                            jsl gameplay_ui_set_active_player_message

                            lret
                            end

; ----------------------------------------------------------------------------
collision_bomb_warrior      private seg_entity
                            using gameplay_ui_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

; Same as the warrior hitting a player shot
                            pushsword <spEntity2
                            pushsword <spEntity1
                            jsr collision_warrior_player_shot

; Post message
                            lda #gameplay_ui~message_sinibomb_intercepted
                            jsl gameplay_ui_set_active_player_message

                            lret
                            end

; ----------------------------------------------------------------------------
collision_bomb_player_shot  private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end


; ----------------------------------------------------------------------------
collision_bomb_warrior_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_bomb_explosion    private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;; Crystal v.

; ----------------------------------------------------------------------------
collision_crystal_crystal   private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_crystal_worker    private seg_entity
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            ldx <spEntity2
                            getword {x},#playfield_entity~characteristic_id
                            cmp #id_characteristic_worker_with_crystal
                            beq has_crystal

; Remove the crystal and give it to the worker
                            ldx <spEntity1
                            jsl playfield_entity_mark_for_removal
                            pushsword <spEntity2
                            jsl gameplay_worker_give_crystal

                            pushsword #id_sfx~worker_collect_crystal
                            jsl sndlib_play_sfx

; No bounce, like the original code, it prevents workers from kicking crystals away from other persuers.
has_crystal                 anop
                            lret
                            end

; ----------------------------------------------------------------------------
collision_crystal_warrior   private seg_entity
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

                            lret
                            end

; ----------------------------------------------------------------------------
collision_crystal_player_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_crystal_warrior_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_crystal_explosion private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;; Worker v.

; ----------------------------------------------------------------------------
collision_worker_worker     private seg_entity
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

                            lret
                            end

; ----------------------------------------------------------------------------
collision_worker_warrior    private seg_entity
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

                            lret
                            end

; ----------------------------------------------------------------------------
collision_worker_player_shot private seg_entity
                            using gameplay_player_logic_data
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            jsl explosion_entity_manager_add_explosion
; See if the worker had a crystal
                            ldx <spEntity1
                            getword {x},#playfield_entity~characteristic_id
                            cmp #id_characteristic_worker_with_crystal
                            bne no_crystal
; Yes, make a new crystal, at the same position, going in the same direction
                            pushsword {x},#playfield_entity~grentity+grlib_entity~x
                            pushsword {x},#playfield_entity~grentity+grlib_entity~y
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            jsl crystal_entity_manager_add_crystal

no_crystal                  ldx <spEntity1
                            jsl playfield_entity_mark_for_removal
                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            lda #gameplay_score~kill_worker
                            jsl gameplay_add_to_score

                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

                            lret
                            end

; ----------------------------------------------------------------------------
collision_worker_warrior_shot private seg_entity
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size
; Warrior shots kill workers.  This is the same code as the player shot hitting a worker, except for
; for the score for the player.  Maybe make a shared function with the common bits?

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            jsl explosion_entity_manager_add_explosion
; See if the worker had a crystal
                            ldx <spEntity1
                            getword {x},#playfield_entity~characteristic_id
                            cmp #id_characteristic_worker_with_crystal
                            bne no_crystal
; Yes, make a new crystal, at the same position, going in the same direction
                            pushsword {x},#playfield_entity~grentity+grlib_entity~x
                            pushsword {x},#playfield_entity~grentity+grlib_entity~y
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            jsl crystal_entity_manager_add_crystal

no_crystal                  ldx <spEntity1
                            jsl playfield_entity_mark_for_removal
                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

                            lret
                            end

; ----------------------------------------------------------------------------
collision_worker_explosion  private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;; Warrior

; ----------------------------------------------------------------------------
collision_warrior_warrior   private seg_entity
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            pushptrhigh #entities_root
                            pushsword <spEntity2
                            jsl collision_bounce

                            jsr _play_bounce_sfx

                            lret
                            end

; ----------------------------------------------------------------------------
collision_warrior_player_shot private seg_entity
                            using gameplay_player_logic_data
                            using gameplay_sound_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            pushptrhigh #entities_root
                            pushsword <spEntity1
                            jsl explosion_entity_manager_add_explosion

                            ldx <spEntity1
                            jsl playfield_entity_mark_for_removal
                            ldx <spEntity2
                            jsl playfield_entity_mark_for_removal

                            lda #gameplay_score~kill_warrior
                            jsl gameplay_add_to_score

                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

                            lret
                            end

; ----------------------------------------------------------------------------
collision_warrior_warrior_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_warrior_explosion private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;; Player Shot

; ----------------------------------------------------------------------------
collision_player_shot_player_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end


; ----------------------------------------------------------------------------
collision_player_shot_warrior_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_player_shot_explosion private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;; Warrior Shot

; ----------------------------------------------------------------------------
collision_warrior_shot_warrior_shot private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; ----------------------------------------------------------------------------
collision_warrior_shot_explosion private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

;;;;; Explosion

; ----------------------------------------------------------------------------
collision_explosion_explosion private seg_entity

                            begin_locals
work_area_size              end_locals

                            lsub (2:spEntity1,2:spEntity2),work_area_size

                            lret
                            end

; -----------------------------------------------------------------------------
; Play the bounce sfx.  Use this function, as it will limit the number of them
; playing, since we can get large number of collisions, very quickly.
_play_bounce_sfx            private seg_entity
                            using applib_data
                            using collision_matrix_data
                            using gameplay_sound_data

                            lda >applib~current_tick
                            sec
                            sbc >sfx_bounce_last_play_tick
                            cmp #sfx_bounce_ticks_between_plays
                            blt skip

                            lda >applib~current_tick
                            sta >sfx_bounce_last_play_tick

                            pushsword #id_sfx~bounce
                            jsl sndlib_play_sfx

skip                        rts
                            end

; ----------------------------------------------------------------------------
; Two entities have collided, bounce them off each other.
collision_bounce            private seg_entity
                            using appdata
                            using applib_data
                            using appdebug_data
                            using collision_matrix_data
                            using gameplay_entity_data
                            using math_tables

                            begin_locals
wMass1                      decl word
wMass2                      decl word
wMass1Ratio                 decl word
wMass2Ratio                 decl word
wRatioMuliplier             decl word
wSpeedX                     decl word
wSpeedY                     decl word
wTemp                       decl word
work_area_size              end_locals

                            sub (4:pEntity1,4:pEntity2),work_area_size

; If both have bounced, exit
                            getword [<pEntity1],#playfield_entity~state_flags
                            bit #playfield_entity~state_bounce_bits
                            beq not_bounced
                            getword [<pEntity2],#playfield_entity~state_flags
                            bit #playfield_entity~state_bounce_bits
                            beq not_bounced
neither_has_mass            brl already_bounced
not_bounced                 anop
                            getword [<pEntity1],#playfield_entity~characteristic_id
                            tax
                            lda >characteristics_table+gameplay_entity_characteristic~mass,x
                            sta <wMass1
                            lda [<pEntity2],y
                            tax
                            lda >characteristics_table+gameplay_entity_characteristic~mass,x
                            sta <wMass2
                            clc
                            adc <wMass1
                            beq neither_has_mass
                            dec a                           ; minus 1, our lookup table starts at 1 over 1
; we are assuming we will not overflow a 16 bit value, when adding the two together
; Scale A + B, to fit within our inverse lookup table range
scale_loop                  cmp #256
                            blt ok_range
                            lsr a                           ; scale A+B
                            lsr <wMass1                     ; scale A and B as well
                            lsr <wMass2
                            bra scale_loop

ok_range                    asl a
                            tax
                            lda >math~inverse_256,x         ; look up 1 / (a+b)
                            sta <wRatioMuliplier
                            ldx <wMass1
                            bne entity_1_has_mass
; entity 1 has no mass, use entity 2 as the center of momentum
                            getword [<pEntity2],#playfield_entity~speed_x
                            sta <wSpeedX
                            getword [<pEntity2],#playfield_entity~speed_y
                            brl skip
entity_1_has_mass           anop
                            jsl math~mul2r2                                 ; multiply the ratio multipler, by the mass of entity 1.  This will give us its ratio of the whole
                            sta <wMass1Ratio
                            ldx <wMass2
                            bne entity_2_has_mass
; entity 2 has no mass, use entity 1 as the center of momentum
                            getword [<pEntity1],#playfield_entity~speed_x
                            sta <wSpeedX
                            getword [<pEntity1],#playfield_entity~speed_y
                            bra skip
entity_2_has_mass           anop
                            lda <wRatioMuliplier
                            jsl math~mul2r2
                            sta <wMass2Ratio

; Now calculate the what each entity contributes to the overall direction of the bounce
                            ldx <wMass1Ratio
                            getword [<pEntity1],#playfield_entity~speed_x
                            math~mulfp16 <wTemp                                     ; providing temp memory, so this doesn't use the stack
                            sta <wSpeedX
                            ldx <wMass1Ratio
                            getword [<pEntity1],#playfield_entity~speed_y
                            math~mulfp16 <wTemp
                            sta <wSpeedY

                            ldx <wMass2Ratio
                            getword [<pEntity2],#playfield_entity~speed_x
                            math~mulfp16 <wTemp
                            clc
                            adc <wSpeedX
                            sta <wSpeedX
                            ldx <wMass2Ratio
                            getword [<pEntity2],#playfield_entity~speed_y
                            math~mulfp16 <wTemp
                            clc
                            adc <wSpeedY
;                           sta <wSpeedY

skip                        asl a
                            sta <wSpeedY
                            ldy #playfield_entity~speed_y
                            sec
                            sbc [<pEntity1],y
                            sta [<pEntity1],y

                            lda <wSpeedY
                            sec
                            sbc [<pEntity2],y
                            sta [<pEntity2],y

                            lda <wSpeedX
                            asl a
                            sta <wSpeedX

                            ldy #playfield_entity~speed_x
                            sec
                            sbc [<pEntity1],y
                            sta [<pEntity1],y

                            lda <wSpeedX
                            sec
                            sbc [<pEntity2],y
                            sta [<pEntity2],y

already_bounced             anop
                            getword [<pEntity1],#playfield_entity~state_flags
                            ora #playfield_entity~state_bounce_set_value
                            sta [<pEntity1],y

                            lda [<pEntity2],y
                            ora #playfield_entity~state_bounce_set_value
                            sta [<pEntity2],y
                            ret

                            end
; ----------------------------------------------------------------------------
; A debug function to print some info about the collision data to the text screen
collision_debug_display     start seg_entity
                            using appdata
                            using player_entity_data
                            using applib_data
                            using appdebug_data
                            using textlib_global_data
                            using collision_entry_data

                            begin_locals
pEntity                     decl ptr
pCharacteristic             decl ptr
spCollisionEntry            decl word
wDrawLines                  decl word
work_area_size              end_locals

                            sub (2:wStatus),work_area_size

type_column_width           equ 22
ID_column_width             equ 12
X_column_width              equ 6
Y_column_width              equ 6
Sort_column_width           equ 6

                            setlocaldatabank

                            lda <wStatus
                            bit #debug_handler~status~displayed
                            bne not_first
; First time here
                            stz prev_draw_lines

not_first                   anop
                            lda #textbox_option~inverse+textbox_option~line_fill
                            jsl textbox_set_options
                            pushptr #title_string
                            jsl textbox_print_string
                            jsl textbox_newline
                            jsl textbox_set_option_normal

                            pushptr #column_header
                            jsl textbox_print_columns

                            pushsword #ascii~mousetext~horizontal_bar
                            jsl textbox_fill_line
                            jsl textbox_newline

                            stz <wDrawLines
                            setdatabanktolabel collision~entry_pool
                            lda >collision_entries~head_sptr
                            beq none
                            tax
loop                        stx <spCollisionEntry

                            getword {x},#collision_entry~entity_sptr,<pEntity
                            lda #^entities_root
                            sta <pEntity+2
                            inc <wDrawLines
; Type
                            pushsword #type_column_width
                            jsl textbox_set_column
                            pushsword [<pEntity],#playfield_entity~type
                            jsl playfield_entity_get_type_name
                            pushretptr
                            jsl textbox_print_string

; ID
                            pushsword #ID_column_width
                            jsl textbox_next_column
                            pushsword <pEntity
                            jsl textbox_print_hex_word

; X
                            pushsword #X_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~x
                            jsl textbox_print_hex_word

; Y
                            pushsword #Y_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~y
                            jsl textbox_print_hex_word

; Sort
                            pushsword #Sort_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#collision_entity_sort_member
                            jsl textbox_print_hex_word

                            jsl textbox_next_row_end_columns
                            bcs off_end
                            ldx <spCollisionEntry
                            getword {x},#collision_entry~next_sptr
                            tax
                            bne loop

off_end                     anop
none                        anop
                            restoredatabank

                            jsl textbox_clear_options

                            lda prev_draw_lines
                            sec
                            sbc <wDrawLines
                            bcc no_erase
                            beq no_erase
; We have to erase some previous lines
                            pha
                            pushsword #$20
                            jsl textbox_fill_lines

no_erase                    lda <wDrawLines
                            sta prev_draw_lines

exit                        anop
                            restoredatabank
                            ret

column_header               anop
                            dc i'type_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~Type'
                            dc i'ID_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~ID'
                            dc i'X_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~X'
                            dc i'Y_column_width'
                            dc i'textbox_data~string'
                            dc a4'debug_str~Y'
                            dc i'Sort_column_width'
                            dc i'textbox_data~string'
                            dc a4'Sort_title_string'
                            dc i'0'                             ; terminator

title_string                cstring 'Collision List'
Sort_title_string           cstring 'Sort'

prev_draw_lines             dc i'0'
                            end

; ----------------------------------------------------------------------------
; Draw the help for this handler
collision_debug_show_help   start seg_gameplay

                            pushptr #basic_help1
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help2
                            jsl textbox_print_string
                            jsl textbox_newline

                            rtl

basic_help1                 cstring '[C] - Show the entities that are on the collision list'
basic_help2                 cstring '      These are the on-screen entities'

                            end

; -----------------------------------------------------------------------------
collision_debug_keypress    start seg_gameplay
                            using appdata
                            using player_entity_data
                            using gameplay_player_logic_data
                            using appdebug_data
                            using textlib_global_data
                            using applib_data
                            using grlib_global_data

                            begin_locals
work_area_size              end_locals

                            sub (4:pHandler,2:wKey),work_area_size
                            getword [<pHandler],#debug_handler~enabled
                            beq not_enabled

; We are enabled
                            lda >grlib~in_text_mode
                            beq not_handled                                 ; Don't handle any keys if not in text mode

                            lda <wKey
                            cmp #'C'
                            bne not_handled

; Disable
                            lda #0
                            putword [<pHandler],#debug_handler~enabled
                            lda #$ffff
                            sta >appdebug~clear_text_screen
                            bra handled

; We are not enabled, the only key we listen for, is the one to enable us
not_enabled                 lda <wKey
                            cmp #'C'
                            bne not_handled

; Enable
; We are assuming that at our priority, other handlers have to be shut-off
                            pushsword [<pHandler],#debug_handler~priority
                            jsl appdebug_disable_handlers_of_priority

                            lda #$ffff
                            putword [<pHandler],#debug_handler~enabled
                            sta >appdebug~clear_text_screen

handled                     clc
exit                        retkc
not_handled                 sec
                            bra exit

                            end

; -----------------------------------------------------------------------------
; Remove the vibration delta.
; This is a helper function to temporarily remove the random direction
; the object is vibrating in, so the true movement velocity is restored.
; This is needed if the object is going to be involved in a 'bounce'
; Parameters:
; x-reg     - short pointer to the entity
entity_remove_vibration_delta private seg_entity
                            using gameplay_entity_data

; Assuming the caller has this defined
                            begin_locals
pTaskData                   decl ptr                        ; the task data for any vibration.  Keep this first!
work_area_size              end_locals

; Remove the vibration
                            getword {x},>entities_root+playfield_entity~vibration_task_ptr+2    ; 6
                            beq no_vibraton                                                     ; 2-3
                            sta <pTaskData+2                                                    ; 5
                            getword {x},>entities_root+playfield_entity~vibration_task_ptr      ; 6
                            sta <pTaskData                                                      ; 5

                            getword [<pTaskData],#vibrate_task~delta_x                  ; 11
                            negate a                                                    ; 5
                            clc                                                         ; 2
                            adcword {x},>entities_root+playfield_entity~speed_x         ; 6
                            putword {x},>entities_root+playfield_entity~speed_x         ; 6

                            getword [<pTaskData],#vibrate_task~delta_y                  ; 11
                            negate a                                                    ; 5
                            clc                                                         ; 2
                            adcword {x},>entities_root+playfield_entity~speed_y         ; 6
                            putword {x},>entities_root+playfield_entity~speed_y         ; 6 = 84

no_vibraton                 rts
                            end

; -----------------------------------------------------------------------------
; Set the vibration delta to a specific value
; Parameters:
; x-reg     - short pointer to the entity
entity_restore_vibration_delta private seg_entity
                            using gameplay_entity_data

; Assuming the caller has this defined
                            begin_locals
pTaskData                   decl ptr                        ; the task data for any vibration.  Keep this first!
work_area_size              end_locals

                            getword {x},>entities_root+playfield_entity~vibration_task_ptr+2
                            beq no_vibraton
; Apply the vibration
                            getword [<pTaskData],#vibrate_task~delta_x
                            clc
                            adcword {x},>entities_root+playfield_entity~speed_x
                            putword {x},>entities_root+playfield_entity~speed_x  ; does this need a cap?

                            getword [<pTaskData],#vibrate_task~delta_y
                            clc
                            adcword {x},>entities_root+playfield_entity~speed_y
                            putword {x},>entities_root+playfield_entity~speed_y  ; does this need a cap?

no_vibraton                 rts
                            end

