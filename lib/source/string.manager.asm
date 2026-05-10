                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/string.manager.definitions.asm
                            mcopy generated/string.manager.macros

                            longa on
                            longi on

; --------------------------------------------------------------------------------------------
string_manager_data             data seg_clib

global_string_manager_is_initialized dc i'0'

; The global string manager
global_string_manager           ds string_manager_object_size

                                end
; --------------------------------------------------------------------------------------------
string_manager_errors           data seg_clib

string_manager_error_none           equ 0
string_manager_error_null_pointer   equ system_id_string_manager+1
string_manager_error_allocation     equ system_id_string_manager+2
string_manager_error_not_managed    equ system_id_string_manager+3

string_manager_msg_pool_capacity_error dw 'string_manager: Pool capacity Error'
string_manager_msg_pool_index_error dw 'string_manager: Pool index error'
string_manager_msg_pool_allocation_error dw 'string_manager: Allocation error'
string_manager_msg_pool_no_pool_available dw 'string_manager: No pool available for requested size'
                            end

; --------------------------------------------------------------------------------------------
; Initialize the global string manager.
; This will allocate the global_string_manager object and make it ready for use.
; It will allocate some default sized pools for the manager.
;
; TODO: Maybe have a parameter object for defining the pool sizes?
; That might be good for an 'extended' initialization function.
string_manager_initialize       start seg_clib
                                using string_manager_data

                                debugtag 'initialize'
                                debugtag 'string_manager'

                                lda >global_string_manager_is_initialized
                                bne is_initialized

                                pushptr #global_string_manager
                                jsl string_manager_construct
                                bne error

; Allocate some pools
; Hmm.  Looking at the values I'm passing, I'm kinda adjusting them based on assumptions.
; One is the 31 characters.  I'm assuming that there is a zero-terminator, when I was explicitly trying not to adjust for 'overhead'
; The other is the strings per block.  Again, I'm looking at the string size and then trying to calculate what I think a total block size might be 'good'
; Should I pass in a desired total block byte-size desired and let string_manager_add_pool figure out how many will fit in that?
; If I'm worried about the underlying allocation size/alignment from the system, I should just pad it in the allocation.
; I'm trying to not worry about making string sizes be easily indexed by bit-shifts.  It would be great, but limits flexibility.
                                pushptr #global_string_manager
                                pushsword #31                            ; string size
                                pushsword #64                            ; strings per block
                                jsl string_manager_add_pool

                                pushptr #global_string_manager
                                pushsword #127                           ; string size
                                pushsword #32                            ; strings per block
                                jsl string_manager_add_pool

                                pushptr #global_string_manager
                                pushsword #255                           ; string size
                                pushsword #32                            ; strings per block
                                jsl string_manager_add_pool

                                lda #1
                                sta >global_string_manager_is_initialized

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global string manager.
string_manager_uninitialize     start seg_clib
                                using string_manager_data

                                debugtag 'uninitialize'
                                debugtag 'string_manager'

                                lda >global_string_manager_is_initialized
                                beq exit

                                pushptr #global_string_manager
                                jsl string_manager_destruct

                                lda #0
                                sta >global_string_manager_is_initialized

exit                            anop
                                rtl

                                end
; --------------------------------------------------------------------------------------------
; Make a new string_manager.
; This does not allocate any internal pools.  Use string_manager_add_pool to add some before using.
;
; Params:
; pThis                 - the string manager
; Returns:
; 0 on success or an error result.
string_manager_construct        start seg_clib
                                using fixed_buffer_data
                                using string_globals

; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'construct'
                                debugtag 'string_manager'

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                lda #0
                                putword [<pThis],#string_manager~alloc_count
; Initialize the vector of pools
                                pushptr <pThis,#string_manager~pools
                                pushptr #fixed_buffer_object
                                jsl container_vector_construct
                                bne allocation_error

exit                            anop
allocation_error                anop
                                sta <result
                                ret 2:result
null_pointer                    lda #string_error_null_pointer
                                bra exit
                                end
; --------------------------------------------------------------------------------------------
; Destruct a string manager.  All allocated strings will become invalid!
;
; Params:
; pThis                 - the string manager
string_manager_destruct         start seg_clib
                                using fixed_buffer_data
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                debugtag 'destruct'
                                debugtag 'string_manager'

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq exit

                                pushptr <pThis,#string_manager~pools
                                jsl container_vector_destruct
exit                            anop
                                ret
                                end
; --------------------------------------------------------------------------------------------
; Add a pool to the manager
;
; Params:
; pThis                 - the string manager
; iStringCapacity       - the capacity of the strings to pool, in characters.
; iBlockCapacity        - the number of strings per block
;
; Returns:
; 0 on success or an error result.
;
; Note: I waffling on whether to pass in the number of strings per block or the block size. Each has their pros and cons.
; Passing in the number per block is a helps visualize how many strings will be available, but having the total size
; gives a good visualization of how much memory is being used.  Each have their advantage, and I didn't want
; the caller to try and do math, making assumptions about things.  I'm trying to hide any overhead a string buffer
; might have, such as the zero-terminator.  I may also sneak in a leading length word on each, to help 'pascal-ize'
; the strings so they can be passed directly to OS calls.
; Also, could have the iBlockCapacity have a dual purpose, i.e. < 1k, its the strings per block, >= 1k, its the size.
;
string_manager_add_pool         start seg_clib
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
new_pool                        decl sizeof~fixed_buffer_pool
work_area_size                  end_locals

                                debugtag 'add_pool'
                                debugtag 'string_manager'

                                sub (4:pThis,2:iStringCapacity,2:iBlockCapacity),work_area_size

                                lda <iStringCapacity
                                beq param_error
                                lda <iBlockCapacity
                                beq param_error
; Todo:
; * See if the capacity being added is already in.
; * If the capacity is not greater than the last, insert.  We want the capacities always going up, (sorted) so its easier to search for one when allocating.
                                pushlocalptr #new_pool
                                lda <iStringCapacity
                                inc a                                               ; +1 for the terminator
                                pha
                                pushsword <iBlockCapacity
                                jsl fixed_buffer_pool_construct
                                bne allocation_error

                                pushptr <pThis,#string_manager~pools
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
; pThis                 - the string manager
; iCapacity             - desired capacity, in usable characters.  Do not include 0 terminator, etc.  The alloc will account for overhead.
; Returns:
; The capacity buffer that would be used for the input capacity.  This is >= the input capacity.
string_manager_test_capacity    start seg_clib
                                using string_globals
                                using string_manager_errors
; Define our work area data
                                begin_locals                                           ; result value inside our local work area
result                          decl word
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

                                debugtag 'test_capacity'
                                debugtag 'string_manager'

                                sub (4:pThis,2:iCapacity),work_area_size

                                inc <iCapacity                                      ; For the zero terminator
; Find the best pool to fit the requested capacity
; We are assuming the pools are in increasing size order
                                pushptr <pThis,#string_manager~pools
                                pushlocalptr #itr
                                jsl container_vector_front
                                bne index_error
; Get the pointer from the iterator
loop                            anop
                                ldy #fixed_buffer_pool~slot_size
                                lda [<itr+vector_iterator~ptr],y
                                cmp <iCapacity
                                bge found
                                vector_iterator_next <itr
                                vector_iterator_equals_end <itr
                                bne loop
                                bra not_found

found                           dec a                                               ; Not telling the user about the overhead
exit                            anop
                                sta <result
                                ret 2:result
not_found                       anop
                                debugger_msg #string_manager_msg_pool_capacity_error
                                bra error_exit
index_error                     anop
                                debugger_msg #string_manager_msg_pool_index_error
error_exit                      anop
                                lda <iCapacity
                                dec a
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Allocate a buffer.
;
; Params:
; pThis                 - the string manager
; iCapacity             - desired capacity, in usable characters.  Do not include 0 terminator, etc.  The alloc will account for overhead.
; pResult               - pointer to an output string_manager_alloc_result object
; Returns:
; 0 on success or an error result.  If the result is non 0, the contents of the pResult object is undefined
string_manager_alloc_buffer     start seg_clib
                                using string_globals
                                using string_manager_errors
; Define our work area data
                                begin_locals                                           ; result value inside our local work area
result                          decl word
itr                             decl sizeof~vector_iterator
pBuffer                         decl ptr
poolId                          decl word
work_area_size                  end_locals

                                debugtag 'alloc_buffer'
                                debugtag 'string_manager'

                                sub (4:pThis,2:iCapacity,4:pResult),work_area_size

                                inc <iCapacity                                      ; For the zero terminator
; Find the best pool to fit the requested capacity
; We are assuming the pools are in increasing size order
                                pushptr <pThis,#string_manager~pools
                                pushlocalptr #itr
                                jsl container_vector_front
                                jne index_error
                                stz <poolId                                         ; Pool ID is just going to be the index in the vector, except for special case pools. Maybe put this in the pool?
; Get the pointer from the iterator
loop                            anop
                                getword [<itr+vector_iterator~ptr],#fixed_buffer_pool~slot_size
                                cmp <iCapacity
                                bge found
                                inc <poolId
                                vector_iterator_next <itr
                                vector_iterator_equals_end <itr
                                bne loop
                                bra not_found

found                           anop
                                pushptr <itr+vector_iterator~ptr
                                jsl fixed_buffer_pool_alloc
                                bcs allocation_error
                                putretptr <pBuffer

; Put the buffer pointer in the result
; TODO: Make getptr support this type of move
                                lda <pBuffer
                                putptrlow [<pResult],#string_manager_alloc_result~ptr
                                lda <pBuffer+2
                                putptrhigh [<pResult],#string_manager_alloc_result~ptr
; And the Pool ID
                                lda <poolId
                                inc a                                               ; The pool ID will be the pool index + 1
                                putword [<pResult],#string_manager_alloc_result~pool
; And the capacity, in usable characters
                                getword [<itr+vector_iterator~ptr],#fixed_buffer_pool~slot_size
                                dec a                                               ; -1, for the zero terminator
                                putword [<pResult],#string_manager_alloc_result~capacity

                                getword [<pThis],#string_manager~alloc_count
                                inc a
                                putword [<pThis],#same

                                lda #0
exit                            anop
                                sta <result
                                ret 2:result
not_found                       anop
                                debugger_msg #string_manager_msg_pool_no_pool_available
                                lda #string_error_allocation
                                bra exit
allocation_error                anop
                                debugger_msg #string_manager_msg_pool_allocation_error
                                lda #string_error_allocation
                                bra exit
index_error                     anop
                                debugger_msg #string_manager_msg_pool_index_error
                                lda #string_error_bad_range
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Free a buffer
;
; Params:
; pThis                 - the string manager
; pBuffer               - pointer to the buffer
; iPool                 - the pool the buffer came from.
; Returns:
; 0 on success or an error result.
string_manager_free_buffer      start seg_clib
                                using string_manager_errors
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
pPool                           decl ptr
work_area_size                  end_locals

                                debugtag 'free_buffer'
                                debugtag 'string_manager'
                                sub (4:pThis,4:pBuffer,2:iPool),work_area_size

                                testptr <pThis
                                beq null_pointer
                                testptr <pBuffer
                                beq null_pointer
                                lda <iPool
                                beq pool_error

                                dec a                                           ; The pool ID is the index - 1
                                cmpword [<pThis],#string_manager~pools+vector_definition~size
                                bge pool_error

                                dec <iPool
                                pushptr <pThis,#string_manager~pools
                                pushsword <iPool
                                jsl container_vector_data_at
                                bcs pool_error
                                putretptr <pPool

                                pushptr <pPool
                                pushptr <pBuffer
                                jsl fixed_buffer_pool_free
                                bne exit

                                getword [<pThis],#string_manager~alloc_count
                                dec a
                                putword [<pThis],#same

                                lda #0
exit                            anop
                                sta <result
                                ret 2:result
null_pointer                    anop
                                lda #string_manager_error_null_pointer
                                bra exit
pool_error                      anop
                                lda #string_manager_error_not_managed
                                bra exit
                                end

; -----------------------------------------------------------------------------
string_parse_buffer_to_strings  start seg_clib
                                using string_globals

                                begin_locals
result                          decl word                                           ; result value inside our local work area
pPool                           decl ptr
dwBufferIndex                   decl long
wAtEOL                          decl word
temp_string_object              decl sizeof~string_object
work_area_size                  end_locals

                                debugtag 'buffer_to_strings'
                                debugtag 'string_parse'
                                sub (4:pVector,4:pBuffer,4:dwBufferLength),work_area_size

                                setlocaldatabank                                    ; so we can use the string~temp_buffer

                                stz <dwBufferIndex
                                stz <dwBufferIndex+2

outer_loop                      stz <wAtEOL
                                ldx #0
                                stz string~temp_buffer
                                ldy <dwBufferIndex
leading_whitespace_skip_loop    lda [<pBuffer],y                                    ; reading a word, even though we only want a byte
                                jsr _is_whitespace
                                bne copy_loop

                                iny_dword <dwBufferIndex,<pBuffer

                                tya
                                eor <dwBufferLength
                                eor <dwBufferIndex+2
                                eor <dwBufferLength+2
                                bne leading_whitespace_skip_loop
                                bra at_eob

copy_loop                       cpx #string~temp_buffer_size-1
                                bge buffer_full
                                sta string~temp_buffer,x                    ; storing a full word, with the high byte == 0, so we are auto-zero terminating.
                                inx

buffer_full                     incdword <dwBufferIndex,<pBuffer

                                ldy <dwBufferIndex
                                tya
                                eor <dwBufferLength
                                eor <dwBufferIndex+2
                                eor <dwBufferLength+2
                                beq at_eob

                                lda [<pBuffer],y
                                jsr _is_whitespace
                                bne copy_loop
; Put the string in the vector
at_eol                          deccs <wAtEOL
                                cpx #0
                                beq no_string

                                pushlocalptr #temp_string_object
                                pushptr #string~temp_buffer
                                jsl string_object_construct_zt

                                pushptr <pVector
                                pushlocalptr #temp_string_object
                                jsl container_vector_move_back

no_string                       anop
                                bit <wAtEOL                                 ; did we stop at an EOL, or was it just plain whitespace?
                                bmi outer_loop
; Didn't hit an EOL, but we are requiring the strings to be one per-line, so skip the rest.
                                jsr _skip_to_eol
                                bcc outer_loop
                                bra no_string_at_eob

at_eob                          anop
                                cpx #0
                                beq no_string_at_eob

                                pushlocalptr #temp_string_object
                                pushptr #string~temp_buffer
                                jsl string_object_construct_zt

                                pushptr <pVector
                                pushlocalptr #temp_string_object
                                jsl container_vector_move_back
no_string_at_eob                anop
                                restoredatabank
                                ret

; This will skip to the eol, and then skip any eol characters, or get to the end
; Returns carry clear, if it is not reached the end, carry on, if it has
_skip_to_eol                    anop
                                ldy <dwBufferIndex
_skip_to_eol_loop               lda [<pBuffer],y
                                jsr _is_whitespace
                                bcs _skip_to_eol_found

                                iny_dword <dwBufferIndex,<pBuffer

                                tya
                                eor <dwBufferLength
                                eor <dwBufferIndex+2
                                eor <dwBufferLength+2
                                bne _skip_to_eol_loop
                                sec
                                rts

_skip_to_eol_found              anop
; Now skip over any remaining eol characters
_skip_to_eol_loop2              lda [<pBuffer],y
                                jsr _is_eol
                                bne _skip_to_eol_done

                                iny_dword <dwBufferIndex,<pBuffer

                                tya
                                eor <dwBufferLength
                                eor <dwBufferIndex+2
                                eor <dwBufferLength+2
                                bne _skip_to_eol_loop2
                                sec
                                rts
_skip_to_eol_done               clc
                                rts

                                end

; -----------------------------------------------------------------------------
; Test to see if the input word is whitespace
; An AND #$00FF is done first
; Returns:
;  z flag on, if it is whitespace, additionally, the carry flag is set if the whitespace is an EOL character
_is_whitespace                  start seg_clib

                                and #$00FF
                                cmp #' '
                                bge is_space_or_not_whitespace
                                cmp #$000D
                                beq is_eol
                                cmp #$000A
                                bne is_not_eol
is_eol                          rts                                 ; z and c will already be set appropriately (both on)

is_not_eol                      bit known_zero                      ; z is 1, we want it to be 0
is_space_or_not_whitespace      clc                                 ; z will already be set appropriately
                                rts

known_zero                      dc i'0'
                                end

; -----------------------------------------------------------------------------
; Test to see if the input word is whitespace
; An AND #$00FF is done first
; Returns:
;  z flag on, if it is whitespace, additionally, the carry flag is set if the whitespace is an EOL character
_is_eol                         start seg_clib
                                and #$00FF
                                cmp #$000D
                                beq is_eol
                                cmp #$000A
is_eol                          rts
                                end
