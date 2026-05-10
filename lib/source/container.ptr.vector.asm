                    copy lib/source/debug.definitions.asm
                    copy lib/source/system.ids.asm
                    copy lib/source/object.definitions.asm
                    copy lib/source/container.definitions.asm
                    copy 13/Ainclude/E16.Memory
                    mcopy generated/container.ptr.vector.macros

                    longa on
                    longi on

; --------------------------------------------------------------------------------------------
; A derivation on the container.vector, where the contents are *pointers* to objects
; and the vector owns the pointers and will delete them, using the object vtable.
; This is essentially a std::vector<std::unique_ptr<T>>
;
; This could have probably been done though objects definitions of pointers to object
; or even a bit flag in the container.vector code, however, I felt like the efficiency
; would be a lot lower.
;
; The downside of doing it separately, is that the user has to know to call the
; different interfaces and, the worst..., duplicate code that is *slightly* modified.
; Oh well, no templates, so we gotta deal.
;
; The upside is that some of the functions are simpler internally, since we know
; the size of what we are holding at compile time, i.e. pointers and arrays of pointers,
; which will eliminate some 'mul' calls, since they can just be a pair of asl ops.
; Moving/resizing is also simpler because we don't have to worry about calling copy/move
; constructors if the objects have them, because we are moving just the pointers to the objects.
;
; Some interfaces have been removed, mainly the 'copy' interfaces, because it is assumed
; that the container *owns* the pointers, so no copy should be made.
; A vector of unowned pointers can be done through the plain container.vector
;
; This does attempt to share most of the object definitions,
; i.e. the vector_definition is the same.
;
; For general container.vector information.  See that file.
;

; --------------------------------------------------------------------------------------------
; Create a new vector
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
;	pObjectDef		- long pointer (4 bytes) to an object definition
; Returns: acc - 0 on success, > 0 is error code.
container_ptr_vector_construct start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                         ; result value inside our local work area
work_area_size          end_locals

                        debugtag 'construct'
                        debugtag 'ptr_vector'
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

                        clc
exit                    anop
                        retkc 2:result

null_pointer            anop
                        lda #container_error_null_pointer
error_exit              anop
                        sta <result
                        sec
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Destruct the contents of a vector
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
; Returns: acc - 0 on success, > 0 is error code.
container_ptr_vector_destruct start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                             ; result value inside our local work area
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'destruct'
                        debugtag 'ptr_vector'
                        sub (4:pThis),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        getword [<pThis],#vector_definition~size
                        beq skip_destruct
; Possible optimization
; If there is no object vtable, this will do a lot of setup work, then do nothing.
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr [<pThis],#vector_definition~data_ptr
                        getword [<pThis],#vector_definition~size
                        pha
                        jsl object_destruct_ptr_array

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
container_ptr_vector_set_capacity start seg_clib
                        using container_errors
                        using applib_data

; Define our work area data
                        begin_locals
result                  decl word                                               ; result value inside our local work area
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'set_capacity'
                        debugtag 'ptr_vector'
                        sub (4:pThis,2:wNewCapacity),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        lda <wNewCapacity
                        cmpword [<pThis],#vector_definition~capacity
                        jeq exit            ; No change
                        bge inflate
; Making it less
; This will be simiar to inflating, because we will end up with a new block, we just need to test to see if
; the new size will remove any allocated entries
                        cmpword [<pThis],#vector_definition~size            ; Current size
                        bge inflate         ; If bigger than any allocated, then the inflate code will do the work
; The new capacity is smaller than the size of in-use entries, re-size to the capacity, which will delete any that don't fit.
; This will be a touch slower, but cleaner to just call resize here
                        pushptr <pThis
                        pushsword <wNewCapacity
                        jsl container_ptr_vector_resize
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
; We are holding pointers, so the math is simple
                        lda <wNewCapacity
                        asl a
                        asl a
                        tax                 ; x now has the byte size we want
                        pushdword #0         ; result
                        pushsword #0         ; high-word of the size
                        phx                 ; low-byte
                        pushsword >applib~MM_ID
                        pushsword #attrLocked+attrNoCross+attrNoSpec       ;locked, no crossing banks, no special
                        pushdword #0          ; no fixed address
                        _NewHandle
                        tay                 ; save toolbox error
                        pulllong <pTemp      ; Put the result in our temp pointer, however we are messing up any return code.
                        bcs allocation_error ; FIX: This can leave us in a bad state, if we pre-deleted the original buffer.  The capacity may not be 0.
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        tax
                        lda <pTemp
                        jsl track_os_allocation
.no_tracking
; Any existing entries to copy?
                        lda [<pThis]
                        beq no_existing_entries
; Copy the old data to the new.  Since they are just pointers, we can just do a memory copy
                        pushptr [<pThis],#vector_definition~data_ptr
                        pushptr [<pTemp],#0    ; <pTemp holds the handle, push the pointer it references
                        lda [<pThis]        ; previous count
                        asl a               ; * sizeof(ptr)
                        asl a
                        pha
                        jsl copy_memory
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
container_ptr_vector_resize start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                        ; result value inside our local work area
wOffset                 decl word
work_area_size          end_locals

                        debugtag 'resize'
                        debugtag 'ptr_vector'
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
                        cmpword [<pThis],#vector_definition~capacity
                        beq inflate_capacity_ok
                        blt inflate_capacity_ok
; Up the capacity.  This will set it to exactly the new size
                        pushptr <pThis
                        pushsword <iNewSize
                        jsl container_ptr_vector_set_capacity
                        jne error_exit

inflate_capacity_ok     anop
; Default construct the new entries.  Since they are just pointers, just set them to 0
                        lda [<pThis]
                        asl a
                        asl a
                        sta <wOffset
                        pushptr [<pThis],#vector_definition~data_ptr,<wOffset
                        sec
                        lda <iNewSize
                        sbc [<pThis]
                        asl a
                        asl a
                        jsl zero_memory
                        bra update_size

deflate                 anop
; Get the offset to the items to delete
                        lda <iNewSize
                        asl a
                        asl a
                        sta <wOffset
; Push the object definition, the address of the first item to delete and the amount to delete
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr [<pThis],#vector_definition~data_ptr,<wOffset
                        sec
                        lda [<pThis]
                        sbc <iNewSize
                        pha
                        jsl object_destruct_ptr_array

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
; Move a pointer to an object to the end of the vector.  The vector will *own* the pointer.
; The vector's capacity will be increased, if needed and if allowed.
; Note, on resizing, the whole vector can end up moving to a new memory location!
;
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
;	pObject 		- long pointer (4 bytes) to an object.  This *must* have been allocated by sba_alloc.
; Returns: acc - 0 on success, > 0 is error code.
container_ptr_vector_move_back start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                               ; result value inside our local work area
iDestIndex              decl word
iDestOffset             decl word
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'move_back'
                        debugtag 'ptr_vector'
                        sub (4:pThis,4:pObject),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result
; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        testptr <pObject
                        jeq null_pointer

                        getword [<pThis],#vector_definition~size
                        cmpword [<pThis],#vector_definition~capacity
                        blt has_space
; Need to increase the capacity
                        static_assert_not_equal vector_definition~capacity,0
                        lda [<pThis],y       ; Get the current capacity
                        ldy #vector_definition~growth_size
                        clc
                        adc [<pThis],y
                        bcs resize_overflow     ; Too much!
                        tay
                        pushptr <pThis
                        phy
                        jsl container_ptr_vector_set_capacity
                        bne error_exit
                        lda [<pThis]          ; Get the current size back
has_space               anop
                        sta <iDestIndex       ; The destination *index*
                        asl a
                        asl a
                        sta <iDestOffset
; Get the destination address
                        getptr [<pThis],#vector_definition~data_ptr,<pTemp,<iDestOffset
; We know that this is just a single pointer, so a simple copy
                        lda <pObject
                        sta [<pTemp]
                        ldy #2
                        lda <pObject+2
                        sta [<pTemp],y
; Update the size
                        lda <iDestIndex
                        inc a
                        sta [<pThis]

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
; The pointer will be deleted.
;
; Params:
;	pThis			- long pointer (4 bytes) to a vector_definition
; Returns: acc - 0 on success, > 0 is error code.
container_ptr_vector_pop_back start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                       ; result value inside our local work area
work_area_size          end_locals

                        debugtag 'pop_back'
                        debugtag 'ptr_vector'
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
                        jsl internal_container_ptr_vector_destruct_range

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
container_ptr_vector_erase start seg_clib
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

                        debugtag 'erase'
                        debugtag 'ptr_vector'
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
; We can also quickly test that the offset is a valid one, it should be divisible by 4
                        bit #3
                        jne invalid_pointer
; Array is just pointers, so div by 4 by sliding down
                        lsr a
                        lsr a
                        cmp <wVectorSize
                        jge invalid_pointer                             ; entry pointer must have been off the end
                        sta <wEraseIndex
; Destruct one item
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr <pEntry
                        pushsword #1
                        jsl object_destruct_ptr_array
; How many items were after the one the was erased?
                        sec
                        lda <wVectorSize
                        sbc <wEraseIndex
                        cmp #2
                        blt was_end
; We now need to slide the remaining items down.  This is a simple copy, as we are just moving pointers
                        dec a
; Times 4
                        asl a
                        asl a
                        tay
; We have a lot of known starting parameters, so just do it here, rather than calling copy_memory
                        clc
                        lda <pEntry
                        adc #4
                        sta <dwOffset                                   ; reusing this ZP location
                        lda <pEntry+2
                        adc #0
                        sta <dwOffset+2
dword_loop              anop
                        dey
                        dey
                        lda [<dwOffset],y
                        sta [<pEntry],y
                        dey
                        dey
                        lda [<dwOffset],y
                        sta [<pEntry],y
                        cpy #0
                        bne dword_loop
; Update the size
was_end                 lda <wVectorSize
                        dec a
                        sta [<pThis]
; Update the iterator.  The data pointer will be the same, we just need to update the end_ptr
                        beq empty
                        asl a
                        asl a
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
                        putptr [<pItr],#vector_iterator~ptr
                        putptr [<pItr],#vector_iterator~end_ptr
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Fill in an iterator to an a element, by index
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;   pItr            - long pointer to an vector_iterator
;   iIndex          - Index to get the address of
; Returns: the address or null
container_ptr_vector_at start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                       ; result value inside our local work area
iObjectSize             decl word
work_area_size          end_locals

                         debugtag 'at'
                         debugtag 'ptr_vector'
                        sub (4:pThis,4:pItr,2:iIndex),work_area_size    ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        jeq null_pointer

                        testptr <pItr
                        jeq null_pointer

                        lda <iIndex
                        cmpword [<pThis],#vector_definition~size        ; Compare to the size
                        jge range_error                                 ; Out of range

                        lda #4                                          ; pointer is 4 bytes
                        putword [<pItr],#vector_iterator~delta_size     ; Store the delta for the iterator

                        lda <iIndex
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
                        asl a
                        asl a
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
                        asl a
                        asl a
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
container_ptr_vector_front start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                           ; result value inside our local work area
iObjectSize             decl word
work_area_size          end_locals

                         debugtag 'front'
                         debugtag 'ptr_vector'
                        sub (4:pThis,4:pItr),work_area_size             ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

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
                        lda #4
                        putword [<pItr],#vector_iterator~delta_size
; Multiply the object size, by the length, we are assuming container contents are not > 64k!
                        getword [<pThis],#vector_definition~size
                        asl a
                        asl a
; Add to the start pointer to get the end pointer, which will be one *past* the last element.  This is not a valid pointer, and should only be used for comparison!
                        clc
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
container_ptr_vector_back start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                           ; result value inside our local work area
work_area_size          end_locals

                         debugtag 'back'
                         debugtag 'ptr_vector'
                        sub (4:pThis,4:pItr),work_area_size                    ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        lda #4
                        ldy #vector_iterator~delta_size
                        sta [<pItr],y                                   ; Store the object size in the iterator

                        static_assert_equal vector_definition~size,0    ; Dropping the load and index with Y, since it is 0, but do a compile time test to make sure our assumption is true
                        lda [<pThis]
                        beq range_error                                 ; Out of range
                        dec a

                        asl a
                        asl a

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
                        adc #4
                        ldy #vector_iterator~end_ptr
                        sta [<pItr],y
                        ldy #vector_iterator~ptr+2
                        lda #0
                        adc [<pItr],y
                        ldy #vector_iterator~end_ptr+2
                        sta [<pItr],y

                        stz <result
exit                    anop
                        ret 2:result                    ; address in A/X (low/high)

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
; if carry clear, the pointer
; if carry set, null
container_ptr_vector_data start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl ptr                                        ; result value inside our local work area
work_area_size          end_locals

                        debugtag 'data'
                        debugtag 'ptr_vector'
                        sub (4:pThis),work_area_size                    ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        getword [<pThis],#vector_definition~size
                        beq range_error                                 ; Out of range

                        getptr [<pThis],#vector_definition~data_ptr,<result
                        clc                                             ; no error
exit                    anop
                        retkc 4:result                    ; address in A/X (low/high)

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
; container_vector_data_at
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;   iIndex          - Index to get the address of
; Returns:
; if carry clear, the pointer
; if carry set, null
container_ptr_vector_data_at start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl ptr                                       ; result value inside our local work area
work_area_size          end_locals

                         debugtag 'data_at'
                         debugtag 'ptr_vector'
                        sub (4:pThis,2:iIndex),work_area_size          ; Parameters, plus the amount of space for our local work area

; Check for null pointers
                        testptr <pThis
                        beq null_pointer

                        lda <iIndex
                        static_assert_equal vector_definition~size,0    ; Dropping the load and index with Y, since it is 0, but do a compile time test to make sure our assumption is true
                        cmp [<pThis]                                    ; Compare to the size
                        bge range_error                                 ; Out of range

                        asl a
                        asl a

                        clc
                        ldy #vector_definition~data_ptr
                        adc [<pThis],y
                        sta <result
                        lda #0
                        ldy #vector_definition~data_ptr+2
                        adc [<pThis],y
                        sta <result+2
                        clc                                             ; no error

exit                    anop
                        retkc 4:result                    ; address in A/X (low/high)

; Not returning an error code, but might want to add a runtime assert here.
range_error             anop
null_pointer            anop
                        clearptr <result
                        sec                                             ; error
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
internal_container_ptr_vector_destruct_range start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
iCount                  decl word
pTemp                   decl ptr
work_area_size          end_locals

                         debugtag 'destruct_range'
                         debugtag 'ptr_vector'
                        sub (4:pThis,2:iStart,2:iEnd),work_area_size         ; Parameters, plus the amount of space for our local work area

; We are not checking pointer values, or ranges, as this is an internal function and they should have already been checked.
; We will check the the range is ok
                        sec
                        lda <iEnd
                        sbc <iStart
                        beq exit
                        sta <iCount

                        lda <iStart
                        beq front                                           ; At the front?  We can skip the adress calculation, if so.
                        asl a
                        asl a
                        clc
                        ldy #vector_definition~data_ptr
                        adc [<pThis],y
                        sta <pTemp
                        ldy #vector_definition~data_ptr+2
                        lda #0
                        adc [<pThis],y
                        sta <pTemp+2

                        pushptr <pThis,#vector_definition~object_definition
                        pushptr <pTemp
                        pushsword <iCount
                        jsl object_destruct_ptr_array

exit                    anop
                        ret

front                   anop
; It's from the front, so just push the data pointer
                        pushptr <pThis,#vector_definition~object_definition
                        pushptr [<pThis],#vector_definition~data_ptr
                        pushsword <iCount
                        jsl object_destruct_ptr_array

                        ret
                        end
