                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            mcopy generated/sba.manager.macros

                            longa on
                            longi on

; --------------------------------------------------------------------------------------------
sba_manager_data            data seg_memlib

; SBA Manager object
                            begin_struct
sba_manager~alloc_count     decl word
sba_manager~pools           decl sizeof~vector_definition       ; A vector of fixed_buffer_pool objects
sizeof~sba_manager          end_struct

; The tracking overhead for an allocation
; This first tracking overhead, is the pool ID, it will hold the pool index + 1 that the allocation came from.  If it is 0, then the allocation is from the OS.
sba_manager_tracking_overhead       gequ 2
; If the allocation is from the OS, the the *additional* overhead is in the allocation, which holds the handle allocated from the OS
sba_manager_os_tracking_overhead    gequ 4

global_sba_manager_is_initialized dc i'0'

; Going to cap the max pools for the global manager, so some optimizations can be made
max_global_sba_manager_pools    equ 8
; The global sba manager
global_sba_manager              ds sizeof~sba_manager

; Tables, specific to the global_sba_manager
; A table of pointers to the pools
global_sba_manager~pool_count   ds 2
global_sba_manager~pool_bank    ds 2                                ; only need to store the bank once
global_sba_manager~pool_sptrs   ds max_global_sba_manager_pools*2
global_sba_manager~pool_slot_sizes ds max_global_sba_manager_pools*2

                                end
; --------------------------------------------------------------------------------------------
sba_manager_errors              data seg_memlib

sba_manager_error_none          equ 0
sba_manager_error_null_pointer  equ system_id_sba+1
sba_manager_error_allocation    equ system_id_sba+2
sba_manager_error_not_managed   equ system_id_sba+3
sba_manager_error_handle        equ system_id_sba+4

sba_manager_msg_pool_capacity_error dw 'sba_manager: Pool capacity Error'
sba_manager_msg_pool_index_error dw 'sba_manager: Pool index error'
sba_manager_msg_pool_allocation_error dw 'sba_manager: Allocation error'
sba_manager_msg_pool_no_pool_available dw 'sba_manager: No pool available for requested size'
                            end

; --------------------------------------------------------------------------------------------
; A Small Block Allocator system
; This will manage allocation of arbitrary sized blocks of data, keeping allocations in
; various pools of fixed sizes.
; This allocation scheme is helpful with applications that are creating many small allocations.
; The GS/OS memory allocation is primarily geared toward larger blocks of data and would not
; be efficient with allocating many smaller blocks of data.
;
; This system uses a collection of fixed_buffer_pools of various sizes for the allocation
; system, falling back to GS/OS for requests outside of the set pools.
;
; The pool sizes are up to the application.
;
; Pros of this type of system is that it greatly reduces fragmentation, at the expense of
; having extra slack in the allocations.  i.e. An allocation request for 20 bytes, might end up
; using a 32 byte slot in a pool.  There is overhead in requesting blocks of data from the OS
; so as long as pool definitions are reasonable, the wasted memory is minimal.
;
; To make deallocation quicker, the scheme is currently using 2-bytes of the allocation to
; store a pool index, then giving the caller the buffer pointer + 2.
; This helps cut down on searching for what pool an allocation came from.
; This scheme may end up being deprecated, if memory size ends up being more important that speed.
; An application should strive to minimize allocating/deallocating for maximum speed, regardless
; of allocation strategy.
;

; --------------------------------------------------------------------------------------------
; Initialize the global sba (small block allocator) manager.
; This will allocate the global_sba_manager object and make it ready for use.
; It will allocate some default sized pools for the manager.
;
; TODO: Maybe have a parameter object for defining the pool sizes?
; That might be good for an 'extended' initialization function.
sba_manager_initialize          start seg_memlib
                                using sba_manager_data

                                debugtag 'initialize'
                                debugtag 'sba_manager'

                                lda >global_sba_manager_is_initialized
                                bne is_initialized

                                pushptr #global_sba_manager
                                jsl sba_manager_construct
                                bne error

; Allocate some pools.
; Note that the add_pool does not futz with this sba size to take into account the overhead.
; This means that adding a pool for 16 byte allocations, will really only fit 14 user bytes.
; The reason for not adding the padding when defining the allocations is that we really want to
; have the blocks be page-aligned sizes for the underlying OS allocation.
; This may change.  Maybe I'll just have the blocks pad themselves out
                                pushptr #global_sba_manager
                                pushsword #16                                ; sba size
                                pushsword #64                                ; sbas per block
                                jsl sba_manager_add_pool

                                pushptr #global_sba_manager
                                pushsword #32                                ; sba size
                                pushsword #64                                ; sbas per block
                                jsl sba_manager_add_pool

                                pushptr #global_sba_manager
                                pushsword #64                                ; sba size
                                pushsword #32                                ; sbas per block
                                jsl sba_manager_add_pool

                                pushptr #global_sba_manager
                                pushsword #128                               ; sba size
                                pushsword #32                                ; sbas per block
                                jsl sba_manager_add_pool

                                pushptr #global_sba_manager
                                pushsword #256                               ; sba size
                                pushsword #32                                ; sbas per block
                                jsl sba_manager_add_pool

; Going to make an optimization, and get all the pool pointers into a list, since
; they should not move anymore.  Note, if we are going to let the user of the lib add more pools.
; this would need to get re-built.
                                jsl sba_manager_build_tables

                                lda #1
                                sta >global_sba_manager_is_initialized

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global sba manager.
sba_manager_uninitialize     	start seg_memlib
                                using sba_manager_data

                                debugtag 'uninitialize'
                                debugtag 'sba_manager'

                                lda >global_sba_manager_is_initialized
                                beq exit

                                pushptr #global_sba_manager
                                jsl sba_manager_destruct

                                lda #0
                                sta >global_sba_manager_is_initialized

exit                            anop
                                rtl

                                end

; --------------------------------------------------------------------------------------------
sba_manager_build_tables        start seg_memlib
                                using fixed_buffer_data
                                using sba_manager_data
                                using sba_manager_errors

                                debugtag 'build_tables_sba_manager'

                                begin_locals
pPtr                            decl ptr
wCount                          decl word
work_area_size                  end_locals

                                sub ,work_area_size

                                setlocaldatabank

                                lda global_sba_manager+sba_manager~pools+vector_definition~size
                                cmp #max_global_sba_manager_pools+1
                                bge size_error

                                sta <wCount
                                sta global_sba_manager~pool_count
                                beq none

; Only need to store the bank once
                                lda global_sba_manager+sba_manager~pools+vector_definition~data_ptr+2
                                sta global_sba_manager~pool_bank
                                sta <pPtr+2

                                lda global_sba_manager+sba_manager~pools+vector_definition~data_ptr
                                sta <pPtr
                                ldx #0

loop                            getword [<pPtr],#fixed_buffer_pool~slot_size
                                sta global_sba_manager~pool_slot_sizes,x
                                lda <pPtr
                                sta global_sba_manager~pool_sptrs,x
                                clc
                                adc #sizeof~fixed_buffer_pool               ; the pool vector is a vector of fixed_buffer_pools
                                sta <pPtr
                                inx
                                inx
                                dec <wCount
                                bne loop

none                            restoredatabank
                                ret

size_error                      assert_brk 'too many pools'
                                bra none
                                end
; --------------------------------------------------------------------------------------------
; Make a new sba_manager.
; This does not allocate any internal pools.  Use sba_manager_add_pool to add some before
; using, sba_alloc.
;
; This is not usually called directory, sba_manager_initialize will setup the global
; manager and allocate some default pools
;
; Params:
; pThis                 - the sba manager
; Returns:
; 0 on success or an error result.
sba_manager_construct           start seg_memlib
                                using fixed_buffer_data
                                using sba_manager_data
                                using sba_manager_errors

                                debugtag 'construct'
                                debugtag 'sba_manager'

                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                lda #0
                                putword [<pThis],#sba_manager~alloc_count
; Initialize the vector of pools
                                pushptr <pThis,#sba_manager~pools
                                pushptr #fixed_buffer_object
                                jsl container_vector_construct
                                bne allocation_error

exit                            anop
allocation_error                anop
                                sta <result
                                ret 2:result
null_pointer                    lda #sba_manager_error_null_pointer
                                bra exit
                                end
; --------------------------------------------------------------------------------------------
; Destruct an sba manager.  All managed allocations, other than direct OS ones, will
; become invalid!
;
; Params:
; pThis                 - the sba manager
sba_manager_destruct            start seg_memlib
                                using fixed_buffer_data
                                using sba_manager_data

                                debugtag 'destruct'
                                debugtag 'sba_manager'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq exit

                                pushptr <pThis,#sba_manager~pools
                                jsl container_vector_destruct
exit                            anop
                                ret
                                end
; --------------------------------------------------------------------------------------------
; Add a pool to the manager
;
; Params:
; pThis                 - the sba manager
; iBufferCapacity       - the capacity of the buffers in the pool.  This is inclusive of overhead per-buffer
; iBlockCapacity        - the number of sbas per block
;
; Returns:
; 0 on success or an error result.
;
; Note: I waffling on whether to pass in the number of buffers per block or just the total block size. Each has their pros and cons.
; Passing in the number per block is a helps visualize how many buffers will be available, but having the total size
; gives a good visualization of how much memory is being used.  Each have their advantage, and I didn't want
; the caller to try and do math, making assumptions about things.  I'm trying to hide any overhead a buffer
; might have.
; Also, could have the iBlockCapacity have a dual purpose, i.e. < 1k, its the sbas per block, >= 1k, its the size.
;
; I'm also waffling on whether of not the input iBufferCapacity is inclusive of the overhead, or is what the 'user'
; will see and I add the overhead to the underlying pool slot capacity.  Part of it is to be nice to the underlying
; OS allocator and allocate aligned blocks.  The problem is that we end up with a pool that has slots of 16 bytes,
; but the caller can only use 14 of them.  I feel like the use-case is going to often want buffers to be powers of 2,
; but that might not be true.  Most of the time, 'structs' are getting defined and putting them in these buffers, and
; they are not necessarily 'nice' sizes.  Some debugging should be added that can track the discrepancy between
; what was requested and what was allocated.
;
sba_manager_add_pool            start seg_memlib
                                using sba_manager_data

                                debugtag 'add_pool'
                                debugtag 'sba_manager'

                                begin_locals
result                          decl word                                           ; result value inside our local work area
new_pool                        decl sizeof~fixed_buffer_pool
work_area_size                  end_locals

                                sub (4:pThis,2:iBufferCapacity,2:iBlockCapacity),work_area_size

                                lda <iBufferCapacity
                                beq param_error
                                lda <iBlockCapacity
                                beq param_error
; Todo:
; * See if the capacity being added is already in.
; * If the capacity is not greater than the last, insert.  We want the capacities always going up, (sorted) so its easier to search for one when allocating.
                                pushlocalptr #new_pool
                                pushsword <iBufferCapacity
                                pushsword <iBlockCapacity
                                jsl fixed_buffer_pool_construct
                                bne allocation_error

                                pushptr <pThis,#sba_manager~pools
                                pushlocalptr #new_pool
                                jsl container_vector_move_back
                                bne pool_insert_error

                                stz <result

exit                            anop
                                ret 2:result
param_error                     anop
allocation_error                anop
error_exit                      anop
                                sta <result
                                bra exit
pool_insert_error               anop
                                pha                 ; Save error code
; Must deallocate the temporary pool we created
                                pushlocalptr #new_pool
                                jsl fixed_buffer_pool_destruct
                                pla
                                bra error_exit
                                end

; --------------------------------------------------------------------------------------------
; Test what capacity buffer would be returned for a specified capacity
; This is useful to test to see if the capacity would change if trying to set to a new,
; usually lower capacity.  Usually you can assume that a greater capacity will need a new
; buffer, if the original buffer was allocated through the buffer system.
;
; Params:
; pThis                 - the sba manager
; iCapacity             - desired buffer capacity
; Returns:
; The capacity buffer that would be used for the input capacity.  This is >= the input capacity.
sba_manager_test_capacity       start seg_memlib
                                using sba_manager_errors
                                using sba_manager_data

                                debugtag 'test_capacity'
                                debugtag 'sba_manager'

                                begin_locals                                           ; result value inside our local work area
result                          decl word
itr                             decl sizeof~vector_iterator
iAdjustedCapacity               decl word
work_area_size                  end_locals

                                sub (4:pThis,2:iCapacity),work_area_size

; Add extra for the overhead
                                clc
                                lda <iCapacity
                                adc #sba_manager_tracking_overhead
                                sta <iAdjustedCapacity
; Find the best pool to fit the requested capacity
; We are assuming the pools are in increasing size order
                                pushptr <pThis,#sba_manager~pools
                                pushlocalptr #itr
                                jsl container_vector_front
                                bne index_error
; Get the pointer from the iterator
loop                            anop
                                ldy #fixed_buffer_pool~slot_size
                                lda [<itr+vector_iterator~ptr],y
                                cmp <iAdjustedCapacity
                                bge found
                                vector_iterator_next <itr
                                vector_iterator_equals_end <itr
                                bne loop
                                bra not_found

found                           sec                                               ; Not telling the user about the overhead
                                sbc #sba_manager_tracking_overhead
exit                            anop
                                sta <result
                                ret 2:result
not_found                       anop
; If not found, we return the input capacity, and assume the block will come from the OS
                                lda <iCapacity
                                bra exit
index_error                     anop
                                debugger_msg #sba_manager_msg_pool_index_error
error_exit                      anop
                                lda <iCapacity
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Allocate a buffer.
; This will use the global_sba_manager
;
; Params:
; iCapacity             - desired capacity
; Returns:
; if carry clear, buffer pointer (will not be null)
; if carry set, null
sba_alloc                       start seg_memlib
                                using sba_manager_errors
                                using sba_manager_data

                                begin_locals                                           ; result value inside our local work area
result                          decl ptr
pHandle                         decl ptr
pPtr                            decl ptr
poolId                          decl word
wCapacityWithOverhead           decl word
work_area_size                  end_locals

                                debugtag 'sba_alloc'

                                sub (2:iCapacity),work_area_size
; Add extra for the overhead
                                clc
                                lda <iCapacity
                                adc #sba_manager_tracking_overhead
                                sta <wCapacityWithOverhead
; Find the best pool to fit the requested capacity
; We are assuming the pools are in increasing size order
                                lda >global_sba_manager~pool_count
                                tay
                                ldx #0
; Find a pool slot
loop                            lda >global_sba_manager~pool_slot_sizes,x
                                cmp <wCapacityWithOverhead
                                bge found
                                inx
                                inx
                                dey
                                bne loop
                                bra not_found

found                           anop
                                stx <poolId                                         ; save the index for later
; Get the pool pointer and allocate from it
                                lda >global_sba_manager~pool_bank
                                pha                                                 ; all in the same bank
                                lda >global_sba_manager~pool_sptrs,x
                                pha
                                jsl fixed_buffer_pool_alloc
                                bcs chain_allocation_error
                                putretptr <pPtr
; Advance to what will be given back to the caller.
; This is optimized for the known overhead and that we don't cross bank boundaries.
                                static_assert_equal sba_manager_tracking_overhead,2
                                inc a
                                inc a
                                sta <result
                                stx <result+2

; Put the pool ID in the first word of the allocation
                                lda <poolId
                                lsr a                                               ; it was stored as x 2
                                inc a                                               ; The pool ID will be the pool index + 1
                                sta [<pPtr]
ok_exit                         anop
;                                pushptr <result
;                                pushsword <iCapacity
;                                pushsword #$CCCC
;                                jsl fill_memory_2                                   ; debugging, fill the memory with a pattern
                                clc                                                 ; signal no error
exit                            anop
                                retkc 4:result
; If there is no pool, we will allocate directly from the OS
not_found                       anop
; Add some additional overhead
                                clc
                                lda <wCapacityWithOverhead
                                adc #sba_manager_os_tracking_overhead
                                jsl allocate_fixed_handle
chain_allocation_error          bcs allocation_error
                                sta <pHandle
                                stx <pHandle+2
; Dereference, and also create the pointer that will be given back to the caller
                                lda [<pHandle]
                                sta <pPtr
                                clc
                                adc #sba_manager_tracking_overhead+sba_manager_os_tracking_overhead
                                sta <result
                                ldy #2
                                lda [<pHandle],y
                                sta <pPtr+2
                                adc #0
                                sta <result+2
; Put the handle at the start of the memory
                                lda <pHandle
                                sta [<pPtr]
                                lda <pHandle+2
                                sta [<pPtr],y
; Pool ID of 0, means OS allocated
                                ldy #4
                                lda #0
                                sta [<pPtr],y
                                bra ok_exit
allocation_error                anop
                                debugger_msg #sba_manager_msg_pool_allocation_error
                                bra error_exit
index_error                     anop
                                debugger_msg #sba_manager_msg_pool_index_error
;                               bra error_exit
error_exit                      anop
                                clearptr <result
                                sec                                             ; signal there was an error
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Free a buffer.
; Uses the global_sba_manager
;
; Params:
; pBuffer               - pointer to the buffer.  Can be null.
; Returns:
; none
sba_free      	                start seg_memlib
                                using sba_manager_errors
                                using sba_manager_data

                                begin_locals
work_area_size                  end_locals

                                debugtag 'sba_free'

                                sub (4:pBuffer),work_area_size

                                lda <pBuffer
                                ldx <pBuffer+2
                                bne ok_pointer
                                tay
                                beq null_pointer

ok_pointer                      sec
                                sbc #sba_manager_tracking_overhead
                                sta <pBuffer
; Not supporting cross-bank pointers, so no need to update the high word
;                               txa
;                               sbc #0
;                               sta <pBuffer+2

                                lda [<pBuffer]                              ; Get the pool ID
                                beq no_pool

                                dec a                                       ; The pool ID is the index - 1
                                cmp >global_sba_manager~pool_count          ; check the range
                                bge pool_error

; Get the pointer to the pool, from the lookup table
                                asl a                                       ; need this x2
                                tax
                                lda >global_sba_manager~pool_bank
                                pha
                                lda >global_sba_manager~pool_sptrs,x
                                pha
                                pushptr <pBuffer
                                jsl fixed_buffer_pool_free
                                bne error_exit

; Reference code for what the above is doing.
                                ago .skip
                                tax                                         ; Save pool index
                                pushptr #global_sba_manager+sba_manager~pools
                                phx
                                jsl container_vector_data_at
                                bcs pool_error
                                phx
                                pha
                                pushptr <pBuffer
                                jsl fixed_buffer_pool_free
                                bne error_exit
.skip

exit                            anop
error_exit                      anop
                                ret
null_pointer                    anop
                                lda #sba_manager_error_null_pointer
                                bra error_exit
pool_error                      anop
                                lda #sba_manager_error_not_managed
                                bra error_exit
; If the pool is 0, then further back in the input pointer, is the OS handle we allocated for the block
no_pool                         anop
                                sec
                                lda <pBuffer
                                sbc #sba_manager_os_tracking_overhead
                                sta <pBuffer
                                lda <pBuffer+2
                                sbc #0
                                sta <pBuffer+2
                                getword [<pBuffer],#2
                                tax
                                getword [<pBuffer],#0
                                jsl deallocate_fixed_handle
; Do a clear here, for saftey?
                                bcc exit
                                lda #sba_manager_error_handle
                                bra error_exit

                                end

