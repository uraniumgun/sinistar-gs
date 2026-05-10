                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/std.definitions.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            mcopy generated/fixed.buffer.pool.macros

                            longa on
                            longi on

; --------------------------------------------------------------------------------------------
fixed_buffer_data           data seg_memlib

fixed_buffer_object         dc i'sizeof~fixed_buffer_pool'
                            dc a4'0'     ; No vtable, for now

                            end
; --------------------------------------------------------------------------------------------
fixed_buffer_errors        data seg_memlib

; Uncomment, to have validation of the pointer coming into the fixed_buffer_free call.
;debug~validate_fixed_buffer_free    gequ 1

fixed_buffer_error_none            equ 0
fixed_buffer_error_null_pointer    equ system_id_fixed_buffer+1
fixed_buffer_error_allocation      equ system_id_fixed_buffer+2
fixed_buffer_error_free_chain      equ system_id_fixed_buffer+3
fixed_buffer_error_pointer_not_managed equ system_id_fixed_buffer+4
fixed_buffer_error_block_size_too_large equ system_id_fixed_buffer+5

                            end
; --------------------------------------------------------------------------------------------
; Initialize a fixed_buffer_pool
;
; Params:
; pThis                     pointer to the fixed_buffer_pool
; iBufferCapacity           the size of the individual buffers to keep in the pool
; iBuffersPerBlock          number of buffers in a block.  This will currently error out, if the total size of the block will be > 64k
; Returns:
; 0 on success, or an error code.
fixed_buffer_pool_construct     start seg_memlib
                                using std_objects
                                using fixed_buffer_errors

                                debugtag 'pool_construct'
                                debugtag 'fixed_buffer'

                                begin_locals
result                          decl word                                       ; result value inside our local work area
work_area_size                  end_locals

                                sub (4:pThis,2:iBufferCapacity,2:iBuffersPerBlock),work_area_size

                                stz <result

                                testptr <pThis
                                beq null_pointer
; Zero out a few things
                                lda #0
                                putword [<pThis],#fixed_buffer_pool~slots_inuse
                                putptr [<pThis],#fixed_buffer_pool~head_free_slot_ptr
                                putptr [<pThis],#fixed_buffer_pool~tail_free_slot_ptr
; Slot size and number of slots
                                lda <iBufferCapacity
                                cmp #fixed_buffer_pool_min_slot_size
                                bge slot_size_ok
                                lda #fixed_buffer_pool_min_slot_size
slot_size_ok                    putword [<pThis],#fixed_buffer_pool~slot_size
                                tax
                                lda <iBuffersPerBlock
                                putword [<pThis],#fixed_buffer_pool~slots_per_block

; Total block size.
                                jsl math~umul2r2                                       ; Slot size * Slots Per block
                                bvs size_overflow
                                putword [<pThis],#fixed_buffer_pool~block_size

; Allocate the vector of block pointers.
                                pushptr <pThis,#fixed_buffer_pool~blocks_vector
                                pushptr #std_object_system_allocation
                                jsl container_vector_construct

                                clc
exit                            anop
                                retkc 2:result
null_pointer                    lda #fixed_buffer_error_null_pointer
set_error                       sta <result
                                sec
                                bra exit
size_overflow                   lda #fixed_buffer_error_block_size_too_large
                                brk $01
                                bra set_error
                                end

; --------------------------------------------------------------------------------------------
; Initialize a static fixed_buffer_pool
; This is where the fixed buffers is at a pre-allocated location.
; The fixed_buffer_pool will not own the memory pool pointer, nor will it try and grow
; beyond the input size
; Params:
; pThis                     pointer to the fixed_buffer_pool
; pBlock                    pointer to a pre-allocated block.  This must be large enough to hold the requested buffers
; iBufferCapacity           the size of the individual buffers to keep in the pool
; iBuffersPerBlock          number of buffers in a block.  This will currently error out, if the total size of the block will be > 64k
; Returns:
; 0 on success, or an error code.
fixed_buffer_pool_construct_static start seg_memlib
                                using std_objects
                                using fixed_buffer_errors

                                debugtag 'pool_construct'
                                debugtag 'fixed_buffer'

                                begin_locals
result                          decl word                                       ; result value inside our local work area
work_area_size                  end_locals

                                sub (4:pThis,4:pBlock,2:iBufferCapacity,2:iBuffersPerBlock),work_area_size

                                stz <result

                                testptr <pThis
                                beq null_pointer
; Zero out a few things
                                lda #0
                                putword [<pThis],#fixed_buffer_pool~slots_inuse
                                putptr [<pThis],#fixed_buffer_pool~head_free_slot_ptr
                                putptr [<pThis],#fixed_buffer_pool~tail_free_slot_ptr
; Slot size and number of slots
                                lda <iBufferCapacity
                                cmp #fixed_buffer_pool_min_slot_size
                                bge slot_size_ok
                                lda #fixed_buffer_pool_min_slot_size
slot_size_ok                    putword [<pThis],#fixed_buffer_pool~slot_size
                                tax
                                lda <iBuffersPerBlock
                                putword [<pThis],#fixed_buffer_pool~slots_per_block

; Total block size.
                                jsl math~umul2r2                                       ; Slot size * Slots Per block
                                bvs size_overflow
                                putword [<pThis],#fixed_buffer_pool~block_size

; Allocate the vector
                                pushptr <pThis,#fixed_buffer_pool~blocks_vector
                                pushptr #std_object_ptr4
                                jsl container_vector_construct
; Add the pre-defined block
                                pushptr <pThis
                                pushptr <pBlock
                                jsl fixed_buffer_pool_add_static_block

                                clc
exit                            anop
                                retkc 2:result
null_pointer                    lda #fixed_buffer_error_null_pointer
set_error                       sta <result
                                sec
                                bra exit
size_overflow                   lda #fixed_buffer_error_block_size_too_large
                                brk $01
                                bra set_error
                                end

; --------------------------------------------------------------------------------------------
; Destruct the contents of a fixed buffer pool
;
; Params:
; pThis                     pointer to the fixed_buffer_pool
; Returns:
; 0 on success, or an error code.
fixed_buffer_pool_destruct      start seg_memlib
                                using std_objects
                                using container_errors

                                debugtag 'pool_destruct'
                                debugtag 'fixed_buffer'

                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                stz <result

                                testptr <pThis
                                beq null_pointer
; Destruct the vector of pool pointers, they are just std_allocations, and the destruct will deallocate them.
; Do we want to maybe go through and see if there are any allocated buffers and assert on that?
                                pushptr <pThis,#fixed_buffer_pool~blocks_vector
                                jsl container_vector_destruct

exit                            anop
                                ret 2:result
null_pointer                    lda #container_error_null_pointer
                                sta <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Allocate buffer from the pool.  If there is not enough free space, a new block will be
; added to the pool
;
; Params;
;   pThis       - pointer to the buffer pool
;
; Returns:
; if carry clear, pointer to the buffer (will not be null)
; if carry set, null
fixed_buffer_pool_alloc         start seg_memlib

                                debugtag 'pool_alloc'
                                debugtag 'fixed_buffer'

                                begin_locals
result                          decl ptr                                        ; result value inside our local work area
iErrorCode                      decl word
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

try_again                       anop
                                getptr [<pThis],#fixed_buffer_pool~head_free_slot_ptr,<result
                                ora <result
                                bne got_ptr                                 ; Non-zero?
; No more free slots, allocate another block
                                pushptr <pThis
                                jsl fixed_buffer_pool_add_block
                                bne error
                                bra try_again                               ; If no error, we *must* have a new head, so go back and try again

got_ptr                         anop
; The block contains the pointer to the next free slot (or null).  We must put that in the head_ptr
                                getword [<result],#0
                                putword [<pThis],#fixed_buffer_pool~head_free_slot_ptr
                                getword [<result],#2
                                putword [<pThis],#fixed_buffer_pool~head_free_slot_ptr+2
; Keep track of the count.  Don't really need this for anything other than debugging
                                getword [<pThis],#fixed_buffer_pool~slots_inuse
                                inc a
                                putword [<pThis],#same
; Note, at this time, if we wanted to be 'correct', we would see if head is now null, which would mean we used the last slot, and that slot is also the tail, so we should set that to null too.
; Instead, we will just exit and the code must not use tail, unless it is sure that head is not null.
exit                            anop
                                clc                                         ; no error
error_exit                      retkc 4:result
error                           anop
; We are returning a null pointer, but it would be nice to have some error reporting
                                sta <iErrorCode
                                pushptr #str_add_block_failed
                                _DebugStr
                                sec                                         ; error
                                bra error_exit

str_add_block_failed            dw "fixed_buffer_pool_add_block - failed"
                                end

; --------------------------------------------------------------------------------------------
; Free a buffer.
; If a debug build, this will determine if the input buffer is managed by the pool and mark it as free.
; If the input buffer is not managed by the pool, and error will be returned
; If not a debug build, this will not do any validation (it isn't cheap)
fixed_buffer_pool_free          start seg_memlib
                                using fixed_buffer_errors

                                debugtag 'pool_free'
                                debugtag 'fixed_buffer'

                                begin_locals
result                          decl word                                        ; result value inside our local work area
iBlockSize                      decl word
pBlock                          decl ptr
pNext                           decl ptr
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

                                sub (4:pThis,4:pBuffer),work_area_size

                                stz <result
; Check for compile time disable of validation
                                aif C:debug~validate_fixed_buffer_free=0,.skip
; See if the pointer is possibly a pointer we manage.  is this a debug only thing?
                                pushptr <pThis,#fixed_buffer_pool~blocks_vector
                                pushlocalptr #itr
                                jsl container_vector_front
                                jne buffer_error
; Get the block size
                                getword [<pThis],#fixed_buffer_pool~block_size
                                sta <iBlockSize

loop                            anop
; Compare to the front
; We are supporting two types of allocations a 'std_allocation' and a static buffer.
; To tell the difference between the two, we look at the size of the data
; An optimization would be to swap the handle / pointer in the std_allocation, and then we wouldn't have to do anything as the
; block pointer would be in the same position.
                                getword <itr+vector_iterator~delta_size
                                cmp #8                      ; 8 bytes for a std_allocation record
                                beq is_std_allocation
                                getptr [<itr],#0,<pBlock    ; else, it is just a pointer to the block
                                bra do_compare
is_std_allocation               getptr [<itr],#std_system_allocation~ptr,<pBlock

do_compare                      cmpl pBuffer,pBlock
                                blt no_match
                                clc
                                lda <pBlock
                                adc <iBlockSize
                                sta <pBlock
                                lda <pBlock+2
                                adc #0
                                sta <pBlock+2
; Compare to the end
                                cmpl pBuffer,pBlock
                                blt match
; Next
no_match                        anop
                                vector_iterator_next <itr
                                vector_iterator_equals_end <itr
                                bne loop
                                beq buffer_error
.skip

; Put the pointer at the head
match                           getptr [<pThis],#fixed_buffer_pool~head_free_slot_ptr,<pNext
                                lda <pBuffer
                                putptrlow [<pThis],#fixed_buffer_pool~head_free_slot_ptr
                                lda <pBuffer+2
                                putptrhigh [<pThis],#fixed_buffer_pool~head_free_slot_ptr
; Put the old head pointer in the new head's buffer
                                lda <pNext
                                putword [<pBuffer],#0
                                lda <pNext+2
                                putword [<pBuffer],#2

; Keep track of the count.  Don't really need this for anything other than debugging
                                getword [<pThis],#fixed_buffer_pool~slots_inuse
                                dec a
                                putword [<pThis],#same

; Zap the memory.  We can't change the first 4 bytes, since we are using them for the free chain.
                                ago .skip
                                pushptr <pBuffer,#4
                                getword [<pThis],#fixed_buffer_pool~slot_size
                                sec
                                sbc #4
                                pha
                                pushsword #$dddd
                                jsl fill_memory_2
.skip

exit                            anop
                                ret 2:result

                                aif C:debug~validate_fixed_buffer_free=0,.skip
buffer_error                    lda #fixed_buffer_error_pointer_not_managed
                                sta <result
                                brk $89
                                bra exit
.skip
                                end

; TODO:
fixed_buffer_pool_get_index_of start seg_memlib
                                end

fixed_buffer_pool_free_index   start seg_memlib
                                end

fixed_buffer_pool_get_size     start seg_memlib
                                end

fixed_buffer_pool_get_capacity start seg_memlib
                                end

fixed_buffer_pool_free_size    start seg_memlib
                                end

fixed_buffer_pool_reserve      start seg_memlib
                                end

; --------------------------------------------------------------------------------------------
; Get the pointer to an indexed entry in the buffer pool.
; This isn't particularly fast, as it requires a div, a mod and a multiply
; Some options are, to only support power of 2 entries per block and power of 2 slot entry sizes.
; Overall, I implemented this, but realized that it is unlikely to be used, because getting the slot
; index from the allocation is not 'easy' and it would be best if users of the fixed buffer pool
; didn't try to use indices.
fixed_buffer_pool_edit_index    start seg_memlib
                                using fixed_buffer_errors
                                debugtag 'pool_edit_index'
                                debugtag 'fixed_buffer'

                                begin_locals
pBlock                          decl ptr
wBlock                          decl word
work_area_size                  end_locals

                                sub (4:pThis,2:wIndex),work_area_size

; Issues here, other than being slow.  The div is signed and it would also be nice if I could get the remainder from the div
; rather than having to do a a mod2 as well.

                                getword [<pThis],#fixed_buffer_pool~slots_per_block
                                tax
                                lda <wIndex
                                jsl ~div2
                                sta <wBlock

                                getword [<pThis],#fixed_buffer_pool~slots_per_block
                                tax
                                lda <wIndex
                                jsl ~mod2
                                sta <wIndex

                                pushptr <pThis,#fixed_buffer_pool~blocks_vector
                                pushsword <wBlock
                                jsl container_vector_data_at
                                putretptr <pBlock
                                bcs exit

; Gotta do a multiply.
                                getword [<pThis],#fixed_buffer_pool~slot_size
                                ldx <wIndex
                                jsl math~mul2r2
                                clc
                                adc <pBlock
                                sta <pBlock
; Do high byte, however, we really don't support bank crossing, so this is a waste.
                                lda #0
                                adc <pBlock+2
                                sta <pBlock+2

                                clc
exit                            retkc 4:pBlock
                                end

; --------------------------------------------------------------------------------------------
; Add a block to the buffer pool
fixed_buffer_pool_add_block     private seg_memlib
                                using fixed_buffer_errors
                                debugtag 'pool_add_block'
                                debugtag 'fixed_buffer'

                                begin_locals
result                          decl word                                           ; result value inside our local work area
theAllocation                   decl std_system_allocation_object_size
pBlock                          decl ptr
pBlockPlus2                     decl ptr
pNext                           decl ptr
pTail                           decl ptr
iSlotSize                       decl word
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                stz <result
; Allowed to add another block?
                                getword [<pThis],#fixed_buffer_pool~blocks_vector+vector_definition~flags
                                bit #container_allocation_fixed
                                jne allocation_error

                                getword [<pThis],#fixed_buffer_pool~block_size
                                jeq exit

                                jsl allocate_fixed_handle
                                jcs allocation_error
                                sta <theAllocation+std_system_allocation~handle
                                stx <theAllocation+std_system_allocation~handle+2
; Dereference the handle
                                getptr [<theAllocation],#std_system_allocation~handle,<pBlock

; Also put it int the ptr section of the allocation object
                                getptr <pBlock,<theAllocation+std_system_allocation~ptr
; Then add the allocation to the array
                                pushptr <pThis,#fixed_buffer_pool~blocks_vector
                                pushlocalptr #theAllocation
                                jsl container_vector_move_back

; Make the free-chain for the block, by linking all the slots together
                                getword [<pThis],#fixed_buffer_pool~slot_size
                                sta <iSlotSize                  ; Store the slot size, for easy access

                                lda <pBlock
                                clc
                                adc #2
                                sta <pBlockPlus2
                                lda <pBlock+2
                                adc #0
                                sta <pBlockPlus2+2
; Get the first 'next' pointer
                                clc
                                lda <pBlock
                                adc <iSlotSize
                                sta <pNext
                                lda <pBlock+2
                                adc #0
                                sta <pNext+2
                                getword [<pThis],#fixed_buffer_pool~slots_per_block
                                tax
                                ldy #0
                                dex
                                beq one_slot
; Loop through and link
link_loop                       lda <pNext
                                sta [<pBlock],y
                                lda <pNext+2
                                sta [<pBlockPlus2],y
                                tya
                                clc
                                adc <iSlotSize
                                tay
; Advance the next ptr, make macro addtoptr <pNext,<iSlotSize
                                clc
                                lda <pNext
                                adc <iSlotSize
                                sta <pNext
                                lda <pNext+2
                                adc #0
                                sta <pNext+2
                                dex
                                bne link_loop
one_slot                        anop
; Last one gets null
                                lda #0
                                sta [<pBlock],y
                                sta [<pBlockPlus2],y
; Store what will be the new tail
                                tya
                                clc
                                adc <pBlock
                                sta <pTail
                                lda #0
                                adc <pBlock+2
                                sta <pTail+2

; Add the block to the free-chain
                                getptr [<pThis],#fixed_buffer_pool~head_free_slot_ptr,<pNext
                                ora <pNext
                                beq new_head
; Attach to the tail, get the current tail pointer
                                getptr [<pThis],#fixed_buffer_pool~tail_free_slot_ptr,<pNext
                                ora <pNext
                                beq error_tail
; Tell the old tail slot, that there are more (might want to validate that the old tail contain null)
                                lda <pBlock
                                putword [<pNext],#0
                                lda <pBlock+2
                                putword [<pNext],#2
                                bra set_tail

new_head                        anop
                                lda <pBlock
                                putword [<pThis],#fixed_buffer_pool~head_free_slot_ptr
                                lda <pBlock+2
                                putword [<pThis],#fixed_buffer_pool~head_free_slot_ptr+2
; Set the tail
set_tail                        anop
                                lda <pTail
                                putword [<pThis],#fixed_buffer_pool~tail_free_slot_ptr
                                lda <pTail+2
                                putword [<pThis],#fixed_buffer_pool~tail_free_slot_ptr+2

exit                            anop
                                ret 2:result
allocation_error                lda #fixed_buffer_error_allocation
                                sta <result
                                bra exit
error_tail                      lda #fixed_buffer_error_free_chain
                                sta <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Add a block to the buffer pool
fixed_buffer_pool_add_static_block private seg_memlib
                                using fixed_buffer_errors
                                debugtag 'pool_add_static_block'
                                debugtag 'fixed_buffer'

                                begin_locals
result                          decl word                                           ; result value inside our local work area
pBlockPlus2                     decl ptr
pNext                           decl ptr
pTail                           decl ptr
iSlotSize                       decl word
work_area_size                  end_locals

                                sub (4:pThis,4:pBlock),work_area_size

                                stz <result
                                getword [<pThis],#fixed_buffer_pool~block_size
                                jeq exit

; Add the allocation to the array
                                pushptr <pThis,#fixed_buffer_pool~blocks_vector
                                pushlocalptr #pBlock
                                jsl container_vector_move_back

; Set that the vector cannot grow any more
                                getword [<pThis],#fixed_buffer_pool~blocks_vector+vector_definition~flags
                                ora #container_allocation_fixed
                                putword [<pThis],#same

; Make the free-chain for the block, by linking all the slots together
                                getword [<pThis],#fixed_buffer_pool~slot_size
                                sta <iSlotSize                  ; Store the slot size, for easy access

                                lda <pBlock
                                clc
                                adc #2
                                sta <pBlockPlus2
                                lda <pBlock+2
                                adc #0
                                sta <pBlockPlus2+2
; Get the first 'next' pointer
                                clc
                                lda <pBlock
                                adc <iSlotSize
                                sta <pNext
                                lda <pBlock+2
                                adc #0
                                sta <pNext+2
                                getword [<pThis],#fixed_buffer_pool~slots_per_block
                                tax
                                ldy #0
                                dex
                                beq one_slot
; Loop through and link
link_loop                       lda <pNext
                                sta [<pBlock],y
                                lda <pNext+2
                                sta [<pBlockPlus2],y
                                tya
                                clc
                                adc <iSlotSize
                                tay
; Advance the next ptr, make macro addtoptr <pNext,<iSlotSize
                                clc
                                lda <pNext
                                adc <iSlotSize
                                sta <pNext
                                lda <pNext+2
                                adc #0
                                sta <pNext+2
                                dex
                                bne link_loop
one_slot                        anop
; Last one gets null
                                lda #0
                                sta [<pBlock],y
                                sta [<pBlockPlus2],y
; Store what will be the new tail
                                tya
                                clc
                                adc <pBlock
                                sta <pTail
                                lda #0
                                adc <pBlock+2
                                sta <pTail+2

; Add the block to the free-chain
                                getptr [<pThis],#fixed_buffer_pool~head_free_slot_ptr,<pNext
                                ora <pNext
                                beq new_head
; Attach to the tail, get the current tail pointer
                                getptr [<pThis],#fixed_buffer_pool~tail_free_slot_ptr,<pNext
                                ora <pNext
                                beq error_tail
; Tell the old tail slot, that there are more (might want to validate that the old tail contain null)
                                lda <pBlock
                                putword [<pNext],#0
                                lda <pBlock+2
                                putword [<pNext],#2
                                bra set_tail

new_head                        anop
                                lda <pBlock
                                putword [<pThis],#fixed_buffer_pool~head_free_slot_ptr
                                lda <pBlock+2
                                putword [<pThis],#fixed_buffer_pool~head_free_slot_ptr+2
; Set the tail
set_tail                        anop
                                lda <pTail
                                putword [<pThis],#fixed_buffer_pool~tail_free_slot_ptr
                                lda <pTail+2
                                putword [<pThis],#fixed_buffer_pool~tail_free_slot_ptr+2

exit                            anop
                                ret 2:result
allocation_error                lda #fixed_buffer_error_allocation
                                sta <result
                                bra exit
error_tail                      lda #fixed_buffer_error_free_chain
                                sta <result
                                bra exit
                                end
