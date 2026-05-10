                    copy lib/source/debug.definitions.asm
                    copy lib/source/system.ids.asm
                    copy lib/source/object.definitions.asm
                    copy lib/source/container.definitions.asm
                    copy 13/Ainclude/E16.Memory
                    mcopy generated/container.vector.macros

                    longa on
                    longi on

; --------------------------------------------------------------------------------------------
; An implementation of a std::vector like container
;
; The idea here is to be reasonably faithful to the std::vector interface and functionality
; as well as be as flexible as possible.
; The implementation tries to be clear/concise/re-usable, over speed/cleverness.
; It uses the stack-based parameter passing in most cases, which is clearer and more
; flexible than trying to put values into registers.
; This will also internally call functions with the stack based parameter passing
; so as to centralize and clarify operations, which can be at the expense of speed
; and perceived efficiency.  i.e. most of the values need might already be in registers
; or local variables, but would require duplicate in-lined code to achieve what a common
; function call does, such as get_byte_offset.  Some of these could be turned into
; specialized macros if inlining would make some operations faster.
;
; It is not expected that operations with the container, other than getting element pointers,
; are done frequently, so clarity and robustness is preferred.
;
; Limits that are currently imposed are that the element count and capacity of the vector
; are stored as 16-bits, so neither can be more than 0xFFFF.  Note that this currently does have
; the odd limitation of being -1 from what I really want, as I want the value's range to
; be exclusive and also support being 0.
; Also, we are assuming that the end-user of the vector is probably going to want to access
; the entries with short addressing, so the entire vector can't be more than 0x10000 in size
; and the memory allocation is not allowed to cross a bank boundary.
;
; I'm really expecting this to hold a collection of small'ish struct objects, not a large
; amount of data.
;
; This does support the 'object' definition, to allow for constructors/destructors.

container_errors            data seg_clib

container_error_none            equ 0
container_error_null_pointer    equ system_id_container+1
container_error_resize_overflow equ system_id_container+2
container_error_allocation      equ system_id_container+3
container_error_invalid_handle  equ system_id_container+4
container_error_bad_range       equ system_id_container+5
container_error_bad_iterator    equ system_id_container+6
container_error_size_mismatch   equ system_id_container+7

container_error_msg_bad_iterator anop
                            dw 'container: bad_iterator'
                            end
; --------------------------------------------------------------------------------------------
; Create a new vector
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
;	pObjectDef		- long pointer (4 bytes) to an object definition
; Returns: acc - 0 on success, > 0 is error code.
container_vector_construct    start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                         ; result value inside our local work area
work_area_size          end_locals

                        debugtag 'construct_vector'

                        sub (4:pThis,4:pObjectDef),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result
; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        testptr <pObjectDef
                        beq null_pointer
; Zero out the vector definition
                        pushptr <pThis
                        pushsword #sizeof~vector_definition
                        jsl zero_memory
; Fill in some defaults
                        lda #vector_default_growth_size
                        putword [<pThis],#vector_definition~growth_size

; Copy the object definition into the vector's object definition location
                        pushptr <pObjectDef
; Push the address of the object_definition field in the vector
                        pushptr <pThis,#vector_definition~object_definition
                        pushsword #sizeof~object_definition
                        jsl copy_memory

exit                    anop
                        ret 2:result

null_pointer            anop
                        lda #container_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Destruct the contents of a vector
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
; Returns: acc - 0 on success, > 0 is error code.
container_vector_destruct start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                            ; result value inside our local work area
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'destruct_vector'

                        sub (4:pThis),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        static_assert_equal vector_definition~size,0               ; Dropping the load and index with Y, since it is 0, but do a compile time test to make sure our assumption is true
                        lda [<pThis]
                        beq skip_destruct
; Possible optimization
; If there is no object vtable, this will do a lot of setup work, then do nothing.
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr [<pThis],#vector_definition~data_ptr
                        lda [<pThis]        ; vector_definition~size
                        pha
                        jsl object_destruct_array

skip_destruct           anop
                        pushptr <pThis
                        jsl internal_container_vector_destroy_buffer
                        sta <result
; Clear some values
                        lda #0
                        putword [<pThis],#vector_definition~size
                        putword [<pThis],#vector_definition~capacity

exit                    anop
                        ret 2:result

null_pointer            anop
                        lda #container_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Set the capacity of a vector to a new size.  Can be larger/smaller or even the same size.
; If the vector's capacity is not allowed to change, and error will be returned.
; If the capacity does change, the vectors data pointer will most likely change!
;
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
;	newCapacity	    - new capacity (2 bytes) of the vector
; Returns: acc - 0 on success, > 0 is error code.
container_vector_set_capacity start seg_clib
                        using container_errors
                        using applib_data

; Define our work area data
                        begin_locals
result                  decl word                                           ; result value inside our local work area
wTemp                   decl word
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'set_capacity_vector'

                        sub (4:pThis,2:wNewCapacity),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        ldy #vector_definition~capacity
                        lda <wNewCapacity
                        cmp [<pThis],y
                        jeq exit            ; No change
                        bge inflate
; Making it less
; This will be simiar to inflating, because we will end up with a new block, we just need to test to see if
; the new size will remove any allocated entries
                        static_assert_equal vector_definition~size,0               ; Dropping the load and index with Y, since it is 0, but do a compile time test to make sure our assumption is true
                        cmp [<pThis]        ; Current size
                        bge inflate         ; If bigger than any allocated, then the inflate code will do the work
; The new capacity is smaller than the size of in-use entries, re-size to the capacity, which will delete any that don't fit.
; This will be a touch slower, but cleaner to just call resize here
                        pushptr <pThis
                        pushsword <wNewCapacity
                        jsl container_vector_resize
; Optimize for going to 0
                        lda <wNewCapacity
                        bne inflate
; If the capacity is going to 0, release the buffer and skip to near the end
                        pushptr <pThis
                        jsl internal_container_vector_destroy_buffer
                        brl empty
inflate                 anop
; This assumes the new capacity is NOT 0
;                       assert_zero <wNewCapacity

; Get a new handle.  We *could* do a ReallocHandle, and let the system just do the copy, but I am trying to have copy/move constructors
; Hmm.  I could see if there are any, and if not, then use the Realloc, else use the NewHandle, then the constructors?

; If the source size was 0, then we have nothing to transfer, so releasing the old buffer now would be helpful to allocating the new one.
                        lda [<pThis]
                        bne has_existing_entries
; Toss the existing buffer. Note, that the old capacity value is still there, maybe zap it here, in case an error happens?
                        pushptr <pThis
                        jsl internal_container_vector_destroy_buffer
has_existing_entries    anop
; Get the byte size of the object
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        ldx <wNewCapacity
                        jsl math~umul2r2
                        sta <wTemp
; <wTemp now has the byte size we want
                        pushdword #0         ; result
                        pushsword #0         ; high-word of the size
                        pushsword <wTemp
                        pushsword >applib~MM_ID
                        pushsword #attrLocked+attrNoCross+attrNoSpec       ;locked, no crossing banks, no special
                        pushdword #0         ; no fixed address
                        _NewHandle
                        tay                 ; save toolbox error
                        pulldword <pTemp      ; Put the result in our temp pointer, however we are messing up any return code.
                        jcs allocation_error ; FIX: This can leave us in a bad state, if we pre-deleted the original buffer.  The capacity may not be 0.
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        tax
                        lda <pTemp
                        jsl track_os_allocation
.no_tracking
                        aif C:debug~scramble_allocations=0,.no_scramble
; Debug: Scramble memory
                        pushptr [<pTemp],#0                                 ; <pTemp holds the handle, push the pointer it references
                        pushsword <wTemp
                        jsl scramble_memory
.no_scramble
; Any existing entries to copy?
                        lda [<pThis]
                        beq no_existing_entries
; Copy the old data to the new
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr [<pThis],#vector_definition~data_ptr
                        pushptr [<pTemp],#0                                 ; <pTemp holds the handle, push the pointer it references
                        pushsword [<pThis]
                        jsl object_move_array
; Destroy any handle
                        pushptr <pThis
                        jsl internal_container_vector_destroy_buffer

no_existing_entries     anop
; Put the new handle in
                        ldy #vector_definition~data_handle
                        lda <pTemp
                        sta [<pThis],y
                        ldy #vector_definition~data_handle+2
                        lda <pTemp+2
                        sta [<pThis],y

; And the new pointer
                        lda [<pTemp]
                        ldy #vector_definition~data_ptr
                        sta [<pThis],y
                        ldy #2
                        lda [<pTemp],y
                        ldy #vector_definition~data_ptr+2
                        sta [<pThis],y
; And the new capacity.  This size will remain the same, or will have been already adjusted.
empty                   anop
                        lda <wNewCapacity
                        putword [<pThis],#vector_definition~capacity

exit                    anop
                        ret 2:result

resize_overflow         lda #container_error_resize_overflow
                        bra error_exit
; The error code from the MemoryManager is in A, however, we have to pull the
allocation_error        anop
                        lda #container_error_allocation
                        jsl system_error_handle_toolbox_error
                        bra error_exit
null_pointer            anop
                        lda #container_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Resize a vector to a new size
; If the size is larger that the current size, default constructed items will be added to the end,
; and the size will be increased.  If the capacity is less than the what is needed for the new
; size.  The capacity will be increased to exactly the new size.  i.e. No extra padding.
; If it is intended that more will be added later, think about calling set_capacity first, with
; extra padding, then calling resize.
;
; If the size is smaller that the current size, the destructor will be called on items, larger
; than the new size and the size will be decreased.  This will not adjust the capacity downward.
; If you want to reduce the capacity as well as the existing size, just call set_capacity, it will
; delete items greater than the capacity.
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;   iNewSize        - Index to get the address of
; Returns: acc - 0 on success, > 0 is error code.
container_vector_resize     start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                        ; result value inside our local work area
iObjectSize             decl word
work_area_size          end_locals

                        debugtag 'resize_vector'

                        sub (4:pThis,2:iNewSize),work_area_size          ; Parameters, plus the amount of space for our local work area

                        stz <result
; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        lda <iNewSize
                        cmp [<pThis]                                    ; Compare to the size
                        jeq exit                                        ; Same size
                        blt deflate
; Increasing the size
; Have enough capacity?
                        ldy #vector_definition~capacity
                        cmp [<pThis],y
                        beq inflate_capacity_ok
                        blt inflate_capacity_ok
; Up the capacity.  This will set it to exactly the new size
                        pushptr <pThis
                        pushsword <iNewSize
                        jsl container_vector_set_capacity
                        jne error_exit

inflate_capacity_ok     anop
; Default construct the new entries
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        tax
                        lda [<pThis]
                        jsl math~umul2r2                                    ; Get the offset to the new items
                        sta <iObjectSize

                        pushptr <pThis,#vector_definition~object_definition
                        pushptr [<pThis],#vector_definition~data_ptr,<iObjectSize
                        sec
                        lda <iNewSize
                        sbc [<pThis]
                        pha                                                 ; The number of new entries
                        jsl object_fill_array                               ; Fill the new elements with a default constructed object
                        bra update_size

deflate                 anop
; Get the offset to the items to delete
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        tax
                        lda <iNewSize
                        jsl math~umul2r2                                    ; Get the offset to the removed
                        sta <iObjectSize

; Push the object definition, the address of the first item to delete and the amount to delete
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr [<pThis],#vector_definition~data_ptr,<iObjectSize
                        lda [<pThis]
                        sec
                        sbc <iNewSize
                        pha
                        jsl object_destruct_array

update_size             anop
                        lda <iNewSize
                        sta [<pThis]                                        ; Store the new size

exit                    anop
                        ret 2:result

; Not returning an error code, but might want to add a runtime assert here.
error_capacity          anop
                        lda #container_error_allocation
null_pointer            anop
                        lda #container_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Copy an object to the end of the vector
; The vector's capacity will be increased, if needed and if allowed.
; Note, on resizing, the whole vector can end up moving to a new memory location!
; Note also, this is explicitly a *copy* operation.  It is preferred to use container_vector_move_back
; for complex objects and doesn't hurt to use with POD, as it will not try and erase the POD source data.
;
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
;	pObject 		- long pointer (4 bytes) to an object
; Returns: acc - 0 on success, > 0 is error code.
container_vector_copy_back start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                               ; result value inside our local work area
iDestIndex              decl word
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'copy_back_vector'

                        sub (4:pThis,4:pObject),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result
; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        testptr <pObject
                        jeq null_pointer

                        getword [<pThis],#vector_definition~size          ; Get the size
                        cmpword [<pThis],#vector_definition~capacity
                        blt has_space
; Need to increase the capacity
                        lda [<pThis],y       ; Get the current capacity
                        ldy #vector_definition~growth_size
                        clc
                        adc [<pThis],y
                        bcs resize_overflow     ; Too much!
                        tay
                        pushptr <pThis
                        phy
                        jsl container_vector_set_capacity
                        bne error_exit
                        lda [<pThis]          ; Get the current size back
has_space               anop
                        sta <iDestIndex             ; The destination *index*
; Get the size of the object and multiply it to get the byte offset
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        tax

; Get the destination offset
; Not supporting > 64k
                        lda <iDestIndex
                        jsl math~umul2r2
; Get the destination address
                        clc
                        adcword [<pThis],#vector_definition~data_ptr
                        sta <pTemp
                        lda #0
                        adcword [<pThis],#vector_definition~data_ptr+2
                        sta <pTemp+2
; Copy the object into the destination.
; Possible optimizations.
; * object_copy_array is setup to copy N entries, one that copies a single entry would be a bit quicker.
; * If the object vtable is null, a bitwise will be used, we can pre-check for that to cut the overhead of calling object_copy_array
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr <pObject
                        pushptr <pTemp
                        pushsword #1
                        jsl object_copy_array

                        lda <iDestIndex
                        inc a
                        sta [<pThis]          ; Store the new size (number of elements)

exit                    anop
                        ret 2:result

resize_overflow         lda #container_error_resize_overflow
                        bra error_exit
null_pointer            anop
                        lda #container_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Move an object to the end of the vector
; The vector's capacity will be increased, if needed and if allowed.
; Note, on resizing, the whole vector can end up moving to a new memory location!
; This will use any move constructor the object has.  It is safe to use on POD
; data, as there is no move constructor and a bit-wise one will be used.
;
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
;	pObject 		- long pointer (4 bytes) to an object
; Returns: acc - 0 on success, > 0 is error code.
container_vector_move_back start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                               ; result value inside our local work area
iDestIndex              decl word
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'move_back_vector'

                        sub (4:pThis,4:pObject),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result
; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        testptr <pObject
                        jeq null_pointer

                        getword [<pThis],#vector_definition~size        ; Get the size
                        cmpword [<pThis],#vector_definition~capacity
                        blt has_space
; Need to increase the capacity
                        lda [<pThis],y       ; Get the current capacity
                        clc
                        adcword [<pThis],#vector_definition~growth_size
                        bcs resize_overflow     ; Too much!
                        tay
                        pushptr <pThis
                        phy
                        jsl container_vector_set_capacity
                        bne error_exit
                        lda [<pThis]          ; Get the current size back
has_space               anop
                        sta <iDestIndex             ; The destination *index*
; Get the size of the object and multiply it to get the byte offset
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        tax

; Get the destination offset
; Not supporting > 64k
                        lda <iDestIndex
                        jsl math~umul2r2
; Get the destination address
                        clc
                        adcword [<pThis],#vector_definition~data_ptr
                        sta <pTemp
                        lda #0
                        adcword [<pThis],#vector_definition~data_ptr+2
                        sta <pTemp+2
; Copy the object into the destination.
; Possible optimizations.
; * object_copy_array is setup to copy N entries, one that copies a single entry would be a bit quicker.
; * If the object vtable is null, a bitwise will be used, we can pre-check for that to cut the overhead of calling object_copy_array
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr <pObject
                        pushptr <pTemp
                        pushsword #1
                        jsl object_move_array

                        lda <iDestIndex
                        inc a
                        sta [<pThis]          ; Store the new size (number of elements)

exit                    anop
                        ret 2:result

resize_overflow         lda #container_error_resize_overflow
                        bra error_exit
null_pointer            anop
                        lda #container_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Pop the last element off the end of the vector
; If the container holds objects with vtables, this will destruct the object
;
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
; Returns: acc - 0 on success, > 0 is error code.
container_vector_pop_back start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                       ; result value inside our local work area
work_area_size          end_locals

                        debugtag 'pop_back_vector'

                        sub (4:pThis),work_area_size                    ; Parameters, plus the amount of space for our local work area

                        stz <result
; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        static_assert_equal vector_definition~size,0    ; Dropping the load and index with Y, since it is 0, but do a compile time test to make sure our assumption is true
                        lda [<pThis]                                    ; Get the size
                        beq exit                                        ; Anything in the container? Do we want to maybe assert if there isn't anything in the vector?

; Possible optimizations
; * If there is no vtable or destructor, we can just dec the size and exit
; * internal_container_vector_destruct_range does extra work to be able to do a range, a single delete would be quicker
                        pushptr <pThis
                        lda [<pThis]                                    ; Get the size, again
                        dec a
                        sta [<pThis]                                    ; Update it now, since we have the new size
; Push the size-1, then the size
                        pha
                        inc a
                        pha
                        jsl internal_container_vector_destruct_range

exit                    anop
                        ret 2:result

null_pointer            anop
                        lda #container_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Erase the element at the iterator
; If the container holds objects with vtables, this will destruct the object
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;   pItr            - pointer to an iterator
; Returns: acc - 0 on success, > 0 is error code.
; The iterator will be updated to point to the next item, after the item that
; was erased (often the same location, but don't assume so)
container_vector_erase  start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                       ; result value inside our local work area
pEntry                  decl ptr
pArray                  decl ptr
dwOffset                decl long
wObjectSize             decl word
wVectorSize             decl word
wEraseIndex             decl word
work_area_size          end_locals

                        debugtag 'erase_vector'

                        sub (4:pThis,4:pItr),work_area_size             ; Parameters, plus the amount of space for our local work area

                        stz <result
; Check for null pointers
                        testptr <pThis
                        jeq null_pointer
                        testptr <pItr
                        jeq null_pointer

                        getword [<pThis],#vector_definition~size        ; Get the size
                        jeq exit
                        sta <wVectorSize
; Get the iterator's pointer and the start of the vector
                        getptr [<pItr],#vector_iterator~ptr,<pEntry
                        getptr [<pThis],#vector_definition~data_ptr,<pArray
; Turn the pointer into an index.
                        sub4 pEntry,pArray,dwOffset
                        jcc invalid_pointer                             ; the entry pointer must have been less than the beginning of the data array
; Here is (again) where we are assuming that we won't have a total vector data size >64k.
                        jne invalid_pointer                             ; If the high word has something in it, the pointer is bad, or we need to support >64k
; By supporting less, we can do a 16 bit div.
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        sta <wObjectSize
                        tax
                        lda <dwOffset
                        jsl ~div2
                        cmp <wVectorSize
                        jge invalid_pointer                             ; entry pointer must have been off the end
                        sta <wEraseIndex
; Destruct one item
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr <pEntry
                        pushsword #1
                        jsl object_destruct_array
; How many items were after the one the was erased?
                        sec
                        lda <wVectorSize
                        sbc <wEraseIndex
                        cmp #2
                        blt was_end
; We now need to slide the remaining items down.
                        tax
                        dex
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr <pEntry,<wObjectSize
                        pushptr <pEntry
                        phx
                        jsl object_move_array                           ; We are overlapped, but the destination is lower in memory, so this works.
; Update the size
was_end                 lda <wVectorSize
                        dec a
                        sta [<pThis]
; Update the iterator.  The data pointer will be the same, we just need to update the end_ptr
                        beq empty
; Calculate the end.  Hmm, I'm being 'good', and doing a full recalc, but if we trust the iterator, we can just subtract from its current end.
                        ldx <wObjectSize
                        jsl math~umul2r2
                        clc
                        adc <pArray
                        putptrlow [<pItr],#vector_iterator~end_ptr
                        lda #0
                        adc <pArray+2
                        putptrhigh [<pItr],#vector_iterator~end_ptr
                        lda #0
exit                    anop
                        sta <result
                        ret 2:result

null_pointer            anop
                        lda #container_error_null_pointer
                        bra exit
invalid_pointer         anop
                        pushptr #container_error_msg_bad_iterator
                        _DebugStr
                        lda #container_error_bad_iterator
                        bra exit
empty                   lda #0
                        putptrlow [<pItr],#vector_iterator~ptr
                        putptrhigh [<pItr],#vector_iterator~ptr
                        putptrlow [<pItr],#vector_iterator~end_ptr
                        putptrhigh [<pItr],#vector_iterator~end_ptr
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Fill in an iterator to an a element, by index
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;   pItr            - long pointer to an vector_iterator
;   iIndex          - Index to get the iterator to
; Returns:
; 0 or error code.  If error code is not 0, the returned iterator may not be valid
container_vector_at     start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                       ; result value inside our local work area
iObjectSize             decl word
work_area_size          end_locals

                        debugtag 'at_vector'

                        sub (4:pThis,4:pItr,2:iIndex),work_area_size    ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        testptr <pItr
                        jeq null_pointer

                        lda <iIndex
                        cmpword [<pThis],#vector_definition~size        ; Compare to the size
                        jge range_error                                 ; Out of range

                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        sta <iObjectSize
                        putword [<pItr],#vector_iterator~delta_size

                        ldx <iIndex
                        bne not_zero
; Offset of 0
                        ldy #vector_definition~data_ptr
                        lda [<pThis],y
                        ldy #vector_iterator~ptr
                        sta [<pItr],y
                        ldy #vector_definition~data_ptr+2
                        lda [<pThis],y
                        ldy #vector_iterator~ptr+2
                        sta [<pItr],y
                        bra make_end

; Store the pointer to the element
not_zero                anop
                        jsl math~umul2r2                                ; object size * index
                        clc
                        ldy #vector_definition~data_ptr
                        adc [<pThis],y
                        ldy #vector_iterator~ptr
                        sta [<pItr],y
                        lda #0
                        ldy #vector_definition~data_ptr+2
                        adc [<pThis],y
                        ldy #vector_iterator~ptr+2
                        sta [<pItr],y
; Make an end pointer
make_end                anop
                        lda [<pThis]                                    ; vector size
                        ldx <iObjectSize                                ; * object size
                        jsl math~umul2r2

                        clc
                        ldy #vector_definition~data_ptr
                        adc [<pThis],y
                        ldy #vector_iterator~end_ptr
                        sta [<pItr],y
                        lda #0
                        ldy #vector_definition~data_ptr+2
                        adc [<pThis],y
                        ldy #vector_iterator~end_ptr+2
                        sta [<pItr],y

                        stz <result
exit                    anop
                        ret 2:result

; Not returning an error code, but might want to add a runtime assert here.
range_error             anop
                        lda #container_error_bad_range
                        sta <result
                        bra exit
null_pointer            anop
                        lda #container_error_null_pointer
                        stz <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Get an iterator to the front element.
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;   pItr            - long pointer to an vector_iterator
; Returns: error code or 0
container_vector_front  start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                        ; result value inside our local work area
wTemp                   decl word
work_area_size          end_locals

                        debugtag 'front_vector'

                        sub (4:pThis,4:pItr),work_area_size             ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        getword [<pThis],#vector_definition~size
                        beq range_error                                 ; empty vector?
; Copy the data pointer to the iterator
                        ldy #vector_definition~data_ptr
                        lda [<pThis],y
                        static_assert_equal vector_iterator~ptr,0
                        sta [<pItr]
                        ldy #vector_definition~data_ptr+2
                        lda [<pThis],y
                        ldy #vector_iterator~ptr+2
                        sta [<pItr],y
; Copy the object size
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        putword [<pItr],#vector_iterator~delta_size
; Setup the 'end' pointer. This is expensive, because of the multiply.  Maybe keep track of the end in the vector?
; Multiply the object size, by the length, we are assuming container contents are not > 64k!
                        tax
; Test to see if both values are < $100, if so, we can do a quicker multiply
                        cpx #$100
                        bge need_16bit_mul_1
                        getword [<pThis],#vector_definition~size
                        cmp #$100
                        bge need_16bit_mul_2
; Can do an 8 x 8 multiply
                        stx <wTemp
                        inline~umul1r2 <wTemp,Y
                        bra got_offset
need_16bit_mul_1        getword [<pThis],#vector_definition~size
need_16bit_mul_2        jsl math~umul2r2                              ; Multiplies A * X, result in A
; Add to the start pointer to get the end pointer, which will be one *past* the last element.  This is not a valid pointer, and should only be used for comparison!
got_offset              clc
                        adc [<pItr]
                        ldy #vector_iterator~end_ptr
                        sta [<pItr],y
                        lda #0
                        ldy #vector_iterator~ptr+2
                        adc [<pItr],y
                        ldy #vector_iterator~end_ptr+2
                        sta [<pItr],y

                        stz <result
exit                    anop
                        ret 2:result

; Add asserts?
range_error             anop
                        lda #container_error_bad_range
                        sta <result
                        bra exit
null_pointer            anop
                        lda #container_error_null_pointer
                        stz <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Fill in an iterator to the last (back) element
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;   pItr            - long pointer to an vector_iterator
; Returns: error code or 0
container_vector_back   start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                       ; result value inside our local work area
iObjectSize             decl word
iSize                   decl word
work_area_size          end_locals

                        debugtag 'back_vector'

                        sub (4:pThis,4:pItr),work_area_size             ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        getword [<pThis],#vector_definition~size
                        beq range_error                                 ; Out of range
                        dec a
                        sta <iSize                                      ; Size - 1

                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        putword [<pItr],#vector_iterator~delta_size     ; Store the object size in the iterator
                        sta <iObjectSize                                ; Store for later

                        ldx <iSize
                        jsl math~umul2r2                                ; A * X = offset to last entry

; Copy the data pointer to the iterator
                        clc
                        ldy #vector_definition~data_ptr
                        adc [<pThis],y
                        static_assert_equal vector_iterator~ptr,0
                        sta [<pItr]
                        ldy #vector_definition~data_ptr+2
                        lda #0
                        adc [<pThis],y
                        ldy #vector_iterator~ptr+2
                        sta [<pItr],y
; Since we just calculated the address of the last entry, the end is just one further
                        clc
                        lda [<pItr]
                        adc <iObjectSize
                        ldy #vector_iterator~end_ptr
                        sta [<pItr],y
                        ldy #vector_iterator~ptr+2
                        lda #0
                        adc [<pItr],y
                        ldy #vector_iterator~end_ptr+2
                        sta [<pItr],y

                        stz <result
exit                    anop
                        ret 2:result

; Add asserts?
range_error             anop
                        lda #container_error_bad_range
                        sta <result
                        bra exit
null_pointer            anop
                        lda #container_error_null_pointer
                        stz <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Get a pointer to the front element.  This can return null.
; Unlike container_vector_front, it is not an error to call this
; on an empty vector.
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
; Returns:
; if carry clear, data pointer, will not be null
; if carry set, null
container_vector_data   start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl ptr                                        ; result value inside our local work area
work_area_size          end_locals

                        debugtag 'data_vector'

                        sub (4:pThis),work_area_size                    ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        getword [<pThis],#vector_definition~size
                        beq range_error                                 ; Out of range

                        getptr [<pThis],#vector_definition~data_ptr,<result
                        clc                                             ; no error
exit                    anop
                        retkc 4:result                                    ; address in A/X (low/high)

; Range error is not really an error, however, we probably want to assert if a null pointer to the vector was passed in.
range_error             anop
null_pointer            anop
                        clearptr <result
                        sec                                             ; error
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Get a pointer to a element, by index
; This is intended to be a bit quicker for accessing a specific element, if you don't
; need to iterate from that element afterward.  If you do need an iterator, use
; container_vector_at
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;   iIndex          - Index to get the address of
; Returns:
; if carry clear, the data pointer
; if carry set, null
container_vector_data_at  start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl ptr                                       ; result value inside our local work area
work_area_size          end_locals

                        debugtag 'data_at_vector'
                        sub (4:pThis,2:iIndex),work_area_size          ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        lda <iIndex
                        cmpword [<pThis],#vector_definition~size        ; Compare to the size
                        bge range_error                                 ; Out of range

                        tax                                             ; index to X
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
; Assuming that the vector is < 64k
                        jsl math~umul2r2

                        clc
                        adcword [<pThis],#vector_definition~data_ptr
                        sta <result
                        lda #0
                        adcword [<pThis],#vector_definition~data_ptr+2
                        sta <result+2
                        clc                             ; no errors
exit                    anop
                        retkc 4:result                    ; address in A/X (low/high)

; Not returning an error code, but might want to add a runtime assert here.
range_error             anop
null_pointer            anop
                        clearptr <result
                        sec                             ; error
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Get a pointer to the last element
; This is intended to be a bit quicker for accessing the last element, if you don't
; need to iterate from that element afterward.  If you do need an iterator, use
; container_vector_at
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
; Returns:
; if carry clear, the data pointer
; if carry set, null
container_vector_data_back start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl ptr                                       ; result value inside our local work area
work_area_size          end_locals

                        debugtag 'data_back_vector'
                        sub (4:pThis),work_area_size          ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        getword [<pThis],#vector_definition~size        ; Compare to the size
                        beq range_error                                 ; Out of range

                        dec a
                        tax
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
; Assuming that the vector is < 64k
                        jsl math~umul2r2

                        clc
                        adcword [<pThis],#vector_definition~data_ptr
                        sta <result
                        lda #0
                        adcword [<pThis],#vector_definition~data_ptr+2
                        sta <result+2
                        clc                             ; no errors
exit                    anop
                        retkc 4:result                    ; address in A/X (low/high)

; Not returning an error code, but might want to add a runtime assert here.
range_error             anop
null_pointer            anop
                        clearptr <result
                        sec                             ; error
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Destruct a range of elements in the vector.
; This will just call the object's destructor on the range.  No adjustment to the size/capacity
; or positions of other values will be changed
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;	iStart          - starting element (2 bytes)
;	iEnd            - ending element (2 bytes), the is exclusive.  i.e. to delete just the first element, pass in 0 and 1
; Returns: acc - 0 on success, > 0 is error code.
internal_container_vector_destruct_range start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
iCount                  decl word
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'destruct_range_vector'

                        sub (4:pThis,2:iStart,2:iEnd),work_area_size         ; Parameters, plus the amount of space for our local work area

; We are not checking pointer values, or ranges, as this is an internal function and they should have already been checked.
; We will check the the range is ok
                        sec
                        lda <iEnd
                        sbc <iStart
                        beq exit
                        sta <iCount

                        ldx <iStart
                        beq front                                           ; At the front?  We can skip the adress calculation, if so.

                        getword [<pThis],#vector_definition~object_definition+object_definition~size
; Assuming that the vector is < 64k
                        jsl math~umul2r2

                        clc
                        adcword [<pThis],#vector_definition~data_ptr
                        sta <pTemp
                        lda #0
                        adcword [<pThis],#vector_definition~data_ptr+2
                        sta <pTemp+2

                        pushptr <pThis,#vector_definition~object_definition
                        pushptr <pTemp
                        pushsword <iCount
                        jsl object_destruct_array

exit                    anop
                        ret

front                   anop
; It's from the front, so just push the data pointer
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr [<pThis],#vector_definition~data_ptr
                        pushsword <iCount
                        jsl object_destruct_array

                        ret
                        end

; --------------------------------------------------------------------------------------------
; Destroy the buffer for the container.
; This will also clear the handle and dataptr fields.
; This will *not* change the size/capacity values, it will only clear the handle/ptr values
; It is assumed that the caller is adjusting the other values.
;
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
; Returns: acc - 0 on success, > 0 is error code.
internal_container_vector_destroy_buffer start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                            ; result value inside our local work area
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'destroy_buffer_vector'

                        sub (4:pThis),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

                        getptr [<pThis],#vector_definition~data_handle,<pTemp
                        ora <pTemp
                        beq exit                            ; null already

                        lda <pTemp
                        ldx <pTemp+2
                        jsl deallocate_fixed_handle
                        bcc ok
                        lda #container_error_invalid_handle
                        sta <result

ok                      anop
; Clear the handle
                        lda #0
                        putptr [<pThis],#vector_definition~data_handle
; Clear the pointer
                        putptr [<pThis],#vector_definition~data_ptr

exit                    anop
                        ret 2:result
                        end
