                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/string.definitions.asm
                            mcopy generated/string.support.macros

                            longa on
                            longi on

; --------------------------------------------------------------------------------------------
string_globals              data seg_clib
; String return codes.  Some functions can also return error codes from underlying systems
string_error_none           equ 0
string_error_null_pointer   equ system_id_string+1
string_error_allocation     equ system_id_string+2
string_error_bad_range      equ system_id_string+3
string_error_unmanaged      equ system_id_string+4
string_error_buffer_too_small equ system_id_string+5

string_object               dc i'sizeof~string_object'
                            dc a4'string_object~vtable'

; vtable for the string object
string_object~vtable        anop
                            dc a4'string_object_construct'
                            dc a4'string_object_copy_construct'
                            dc a4'string_object_move_construct'
                            dc a4'string_object_destruct'

string~temp_buffer_size     equ 256
string~temp_buffer          ds string~temp_buffer_size
                            end

; --------------------------------------------------------------------------------------------
; Get a zero terminated string length.
; This will check for null on the pointer, use the string_length macro for inlining, if
; you know the pointer is valid.
;
; Params:
; pStr      - the zero terminated string.  Can be null, which will just return a 0 length.
;
; Returns:
; The string length
string_zt_length                start seg_clib
; Define our work area data
                                begin_locals
result                          decl word                                         ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'zt_length'
                                debugtag 'string'
                                sub (4:pStr),work_area_size

                                testptr <pStr
                                beq null_pointer

                                ldy #0
                                shortm
loop                            lda [<pStr],y
                                beq str_end
                                iny
                                bne loop                        ; Saftey, so we don't get into an infinite loop
str_end                         anop
                                longm
                                sty <result
exit                            ret 2:result
null_pointer                    stz <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Compare a string_zt_object to another string_zt_object.
; This is faster than comparing for < = >, as it will stop as soon as it hits a non-equal character.
; This assumes the strings are null terminated.
; This also assumes the strings are 8 bit characters
; The code is not particularly big.  Maybe make this a macro?  It would cut down on some overhead
;
; Params:
; pStr1     - string 1
; pStr2     - string 2
; Returns:
; 0 if equal, non-zero if not equal.  Somewhat reversed, but it allows for using beq if equal.
string_zt_is_equal              start seg_clib
; Define our work area data
                                begin_locals
result                          decl word                                         ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'zt_is_equal'
                                debugtag 'string'
                                sub (4:pStr1,4:pStr2),work_area_size

                                stz <result
; Well, not super efficient, but we don't have the length of either string.  Might want to calculate the break-even point for this code
; vs. code that gets the lengths of each, then does a more efficient comparison.
; Another hidden slowdown is that because I'm using the 'sub' macro, the DP register almost certainly has a non-zero value in its lower byte, which
; adds a cycle penalty for anything related to DP values.
; Options are:
; * Patch the code addresses (many patches, so not great)
; * Copy the contents of <pStr1 and <pStr2 to a known DP that is aligned, switch to that DP, then switch back.
; * Make this code a macro, so it is inlined, and assume the user's DP is aligned.
                                ldy #0
                                shortm
loop                            lda [<pStr1],y
                                beq str1_end
                                cmp [<pStr2],y
                                bne not_equal
                                lda [<pStr2],y                  ; end of the second string?
                                beq not_equal
                                iny
                                bne loop                        ; Safety, so we don't get into an infinite loop
                                beq not_equal

str1_end                        lda [<pStr2],y                  ; does the second string end too?
                                beq is_equal
not_equal                       inc <result                     ; Still in shortm mode, but we have already cleared the full result, so it's ok
is_equal                        anop
                                longm
                                ret 2:result

                                end

; --------------------------------------------------------------------------------------------
; Compare  string_object to another string_object together.
; This is faster than comparing for < = >, as it will stop as soon as it hits a non-equal character.
; This assumes the string are full string_objects, and will compare the length first, and exit if
; they don't match.
;
; Params:
; pStr1     - string 1
; pStr2     - string 2
; Returns:
; 0 if equal, non-zero if not equal.  Somewhat reversed, but it allows for using beq if equal.
string_object_is_equal          start seg_clib
; Define our work area data
                                begin_locals
result                          decl word                                       ; result value inside our local work area
pStr1Buffer                     decl ptr
pStr2Buffer                     decl ptr
work_area_size                  end_locals

                                debugtag 'object_is_equal'
                                debugtag 'string'
                                sub (4:pStr1,4:pStr2),work_area_size

                                stz <result
                                testptr <pStr1
                                beq not_equal
                                testptr <pStr2
                                beq not_equal

                                static_assert_equal string_object~length,0
                                lda [<pStr1]                                    ; Get the length
                                cmp [<pStr2]
                                bne not_equal
; We know at this point the length is equal, and it can't be 0.
                                pha
; Need to now get the string buffer pointers.  Most likey blowing all the savings we will get with the compare.
                                ldy #string_object~str
                                lda [<pStr1],y
                                sta <pStr1Buffer
                                lda [<pStr2],y
                                sta <pStr2Buffer
                                ldy #string_object~str+2
                                lda [<pStr1],y
                                sta <pStr1Buffer+2
                                lda [<pStr2],y
                                sta <pStr2Buffer+2
; At this point, we should probably validate the buffer pointers, but we've already wasted enough cycles.
; Test the length
                                pla
                                bit #1
                                bne odd
; We know the length is even and at least 2, we can do words
                                tay
word_loop                       anop
                                dey
                                dey
                                lda [<pStr1Buffer],y
                                cmp [<pStr2Buffer],y
                                bne not_equal
                                tya                                      ; Hate that we have to do this, but we are going backward, so y is inclusive.  Note, we are doing a tya, just to test y for 0, which is quicker than, cpy #0
                                bne word_loop
                                bra is_equal
odd                             anop
; Length is odd, and at least one
; Note that we could take advantage of the zero-terminator and just 'mix that in' to the compare, i.e. making it even in this case.  Hmm.
                                tay
                                dey
                                shortm
                                lda [<pStr1Buffer],y
                                cmp [<pStr2Buffer],y
                                longm
                                bne not_equal
                                tya                                     ; Was the length 1? Note, we are doing a tya, just to test y for 0, which is quicker than, cpy #0
                                beq is_equal
; Length is odd, and at least 3
word_loop2                      anop
                                dey
                                dey
                                lda [<pStr1Buffer],y
                                cmp [<pStr2Buffer],y
                                bne not_equal
                                tya
                                bne word_loop2
is_equal                        anop
                                ret 2:result
not_equal                       inc <result
                                ret 2:result

                                end

; --------------------------------------------------------------------------------------------
; Create a new string object, and assign a zt string to it
;
; Params:
; pThis                 - the string object
; pSrc                  - the zero terminated string
;
string_object_construct_zt      start seg_clib
                                using string_globals

                                begin_locals
result                          decl word
work_area_size                  end_locals

                                debugtag 'construct_zt'
                                debugtag 'string_object'
                                sub (4:pThis,4:pSrc),work_area_size

                                testptr <pThis
                                beq null_pointer
; Could make this more efficient, since we already tested the null pointer, and the other calls will do the same.
                                pushptr <pThis
                                jsl string_object_construct
                                bne exit
                                pushptr <pThis
                                pushptr <pSrc
                                jsl string_object_copy_zt
exit                            anop
                                sta <result
                                ret 2:result
null_pointer                    lda #string_error_null_pointer
                                bra exit
                                end
; --------------------------------------------------------------------------------------------
; Create a new string object
;
; Params:
; pThis                 - the string object
;
string_object_construct         start seg_clib
                                using string_globals

                                begin_locals
result                          decl word
work_area_size                  end_locals

                                debugtag 'construct'
                                debugtag 'string_object'
                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                lda #0
                                putword [<pThis],#string_object~length
                                putword [<pThis],#string_object~capacity
                                putword [<pThis],#string_object~info
                                putptr [<pThis],#string_object~str
                                stz <result
exit                            anop
                                ret 2:result
null_pointer                    lda #string_error_null_pointer
                                sta <result
                                bra exit
                                end
; --------------------------------------------------------------------------------------------
; Create a new string object from a copy of another string object
;
; Params:
; pThis                 - the string object
;
string_object_copy_construct    start seg_clib
                                using string_globals

                                begin_locals
pStr                            decl ptr
work_area_size                  end_locals

                                debugtag 'copy_construct'
                                debugtag 'string_object'
                                sub (4:pThis,4:pSrc),work_area_size
; Intialize
                                pushptr <pThis
                                jsl string_object_construct

                                testptr <pSrc
                                beq exit

                                getptr [<pSrc],#string_object~str,<pStr
                                beq exit

                                pushptr <pThis
                                pushptr <pStr
                                jsl string_object_copy_zt

exit                            ret
                                end
; --------------------------------------------------------------------------------------------
; Create a new string object from a copy of another string object
;
; Params:
; pThis                 - the string object
;
string_object_move_construct    start seg_clib
                                using string_globals

                                begin_locals
work_area_size                  end_locals

                                debugtag 'move_construct'
                                debugtag 'string_object'
                                sub (4:pThis,4:pSrc),work_area_size
; Intialize
                                pushptr <pThis
                                jsl string_object_construct

                                testptr <pSrc
                                beq exit

                                testptr [<pSrc],#string_object~str
                                beq exit

; Copy the bits, and clear the source as we go
                                ldy #0
loop                            lda [<pSrc],y
                                sta [<pThis],y
                                lda #0
                                sta [<pSrc],y
                                iny
                                iny
                                cpy #sizeof~string_object
                                bne loop

exit                            ret
                                end
; --------------------------------------------------------------------------------------------
; Destruct the contents of a string object
;
; Params:
; pThis                 - the string object
;
string_object_destruct          start seg_clib

                                begin_locals
result                          decl word
work_area_size                  end_locals

                                debugtag 'destruct'
                                debugtag 'string_object'
                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer                    ; null pointer is ok

                                pushptr <pThis
                                jsl internal_string_object_free_buffer
null_pointer                    anop
                                sta <result
                                ret 2:result

                                end
; --------------------------------------------------------------------------------------------
; Set the capacity of a string object.
; Any existing data will be preserved.
;
; Params:
; pStr                  - the string object
; iCapacity             - the desired capacity.  This can be higher or lower than the existing
;                         capacity.  It can also be 0.
;
string_object_set_capacity      start seg_clib
                                using string_globals
                                using string_manager_data
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
iCurrentCapacity                decl word
iCurrentSize                    decl word
kAllocResult                    decl string_manager_alloc_result_object_size
work_area_size                  end_locals

                                debugtag 'set_capacity'
                                debugtag 'string_object'
                                sub (4:pThis,2:iNewCapacity),work_area_size

                                stz <result
                                testptr <pThis
                                jeq null_pointer

                                getword [<pThis],#string_object~capacity
                                sta <iCurrentCapacity
                                cmp <iNewCapacity
                                jeq exit                                        ; Same?

                                lda <iNewCapacity
                                jeq dealloc_string

                                lda [<pThis]
                                beq is_empty                                    ; Empty string now?  Makes things easier, since we don't have to copy anything
; We know the new capacity is not 0, is different from what we and we have an existing string to copy to the new destination
                                lda <iNewCapacity
                                cmp <iCurrentCapacity
                                bge change_capcity                              ; We will assume that anything bigger will require a buffer change.  May want to do the capacity test anyhow?
; See if the capacity will actually change to a lower value.  Because we have fixed sized buffers, it might not.  i.e. resizing a 15 byte capacity string to a 14 byte string, will not change, because the next lowest down is smaller than 14
                                pushptr #global_string_manager
                                pushsword <iNewCapacity
                                jsl string_manager_test_capacity
                                cmp <iCurrentCapacity
                                beq exit                                        ; It's not going to change, just leave
change_capcity                  anop
                                pushptr #global_string_manager
                                pushsword <iNewCapacity
                                pushlocalptr #kAllocResult
                                jsl string_manager_alloc_buffer
                                bne allocation_error
; Copy the string from the current buffer, into the new buffer
                                pushptr [<pThis],#string_object~str
                                pushptr <kAllocResult+string_manager_alloc_result~ptr
                                lda [<pThis]
                                sta <iCurrentSize                               ; Save this, it will get overwritten
                                inc a                                           ; We want to copy the terminator too.
                                pha
                                jsl copy_memory
; We can now free the old buffer
                                pushptr <pThis
                                jsl internal_string_object_free_buffer
; And attach the new one
                                pushptr <pThis
                                pushlocalptr #kAllocResult
                                jsl internal_string_object_attach_buffer
; Put the size back
                                lda <iCurrentSize
                                sta [<pThis]
                                stz <result
                                bra exit
is_empty                        anop
; Since we know we are empty, just release, then set to whatever the new capacity is.
; If going smaller, this can end up just getting back the same buffer, because we have fixed capacity sizes.  Could optimize for that, by having
; a test for the current capacity, against the new capacity and see if the pool would actually change.  Overall, it is rare to set the capacity lower for a string
; other than setting it to 0, which is handled already.
                                pushptr <pThis
                                jsl internal_string_object_free_buffer
                                bne error
; Allocate a new buffer
                                pushptr <pThis
                                lda <iNewCapacity
                                pha
                                jsl internal_string_object_alloc_buffer
error                           sta <result                                 ; Use the allocation result
exit                            ret 2:result
null_pointer                    anop
                                lda #string_error_null_pointer
                                bra error
allocation_error                lda #string_error_allocation
                                bra error
dealloc_string                  anop
                                pushptr <pThis
                                jsl internal_string_object_free_buffer
                                sta <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Copy the contents of a string object to another string object
;
; Parameters:
; pThis             The destination object
; pSrc              The source object. Can be null, the destination is *not* changed/cleared.
; Returns 0 or an error code.
string_object_copy              start seg_clib
                                using string_globals
; Define our work area data
                                begin_locals
result                          decl word                                   ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'copy'
                                debugtag 'string_object'
                                sub (4:pThis,4:pSrc),work_area_size

                                testptr <pThis
                                beq null_pointer
                                testptr <pSrc
                                beq null_pointer
; Compare the destination capacity to the length
                                getword [<pThis],#string_object~capacity
                                static_assert_equal string_object~length,0
                                cmp [<pSrc]
                                bge copy_characters
; Need to increase the capacity
                                pushptr <pThis
                                lda [<pSrc]
                                pha
                                jsl string_object_set_capacity
                                bne allocation_error
; We know at this point, the destination capacity is enough to hold the source string.
copy_characters                 anop
                                lda [<pSrc]
                                sta [<pThis]                            ; While we have the length, update the destination
; Note, the length could be 0, but even still, we need to put the null terminator in the correct location.  Could make some special case code, but it is cleaner to just let copy memory copy the one byte
                                tax
                                pushptr [<pSrc],#string_object~str
                                pushptr [<pThis],#string_object~str
                                inx                                     ; Plus 1, to copy the zero-terminator
                                phx
                                jsl copy_memory
                                lda #0
error                           sta <result
exit                            ret 2:result
null_pointer                    lda #string_error_null_pointer
                                bra error
allocation_error                lda #string_error_allocation
                                bra error
                                end

; --------------------------------------------------------------------------------------------
; Copy a zero terminated string to a string object
;
; Parameters:
; pThis             - destination string object
; pSrc              - pointer to a zero terminated string.  Can be null, the destination is *not* changed/cleared.
; Returns 0 or error code
string_object_copy_zt           start seg_clib
                                using string_globals
; Define our work area data
                                begin_locals
result                          decl word                                   ; result value inside our local work area
iSrcStringLength                decl word
work_area_size                  end_locals

                                debugtag 'copy_zt'
                                debugtag 'string_object'
                                sub (4:pThis,4:pSrc),work_area_size

                                testptr <pThis
                                beq null_pointer
                                testptr <pSrc
                                beq null_pointer
; First, get the length of the source string
                                string_length [<pSrc]
                                sty <iSrcStringLength
; Compare the destination capacity to the length
                                getword [<pThis],#string_object~capacity
                                cmp <iSrcStringLength
                                bge copy_characters
; Need to increase the capacity
                                pushptr <pThis
                                pushsword <iSrcStringLength
                                jsl string_object_set_capacity
                                bne allocation_error
; We know at this point, the destination capacity is enough to hold the source string.
copy_characters                 anop
                                lda <iSrcStringLength
                                static_assert_equal string_object~length,0
                                sta [<pThis]                            ; While we have the length, update the destination
; Note, the length could be 0, but even still, we need to put the null terminator in the correct location.  Could make some special case code, but it is cleaner to just let copy memory copy the one byte
                                tax
                                pushptr <pSrc
                                pushptr [<pThis],#string_object~str
                                inx                                     ; Plus 1, to copy the zero-terminator
                                phx
                                jsl copy_memory
                                lda #0
error                           sta <result
exit                            ret 2:result
null_pointer                    lda #string_error_null_pointer
                                bra error
allocation_error                lda #string_error_allocation
                                bra error
                                end

; --------------------------------------------------------------------------------------------
; Move the buffer from one string objec to another
;
; Parameters:
;  pThis        - the destination object.  If the object has any current buffer, it will be lost.
;  pSrc         - the source object.  It's buffer will be moved to the destination.  Note, the source can have no buffer (length of 0)
;                 If the source is null, the destination will be unchanged.
; Returns:
; 0 or error code.
string_object_move              start seg_clib
; Define our work area data
                                begin_locals
                                using string_globals
; Define our work area data
                                begin_locals
result                          decl word                                   ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'move'
                                debugtag 'string_object'
                                sub (4:pThis,4:pSrc),work_area_size

                                testptr <pThis
                                beq null_pointer
                                testptr <pSrc
                                beq null_pointer
; Also make sure the two pointers are not the same
                                cmpl pThis,pSrc
                                beq same
; Release the exisiting buffer
                                pushptr <pThis
                                jsl internal_string_object_free_buffer
; Copy the contents of the source to the destination, and clear the source.  This assumes all the bits transfer, so we will loop over everything, though it is only 5 words
                                ldx #0
                                ldy #sizeof~string_object-2
loop                            lda [<pSrc],y
                                sta [<pThis],y
                                txa
                                sta [<pSrc],y
                                dey
                                dey
                                bpl loop

same                            anop
                                lda #0
error                           sta <result
exit                            ret 2:result
null_pointer                    lda #string_error_null_pointer
                                bra error
                                end

; --------------------------------------------------------------------------------------------
; Append the string of one string object to another.
;
; Parameters:
;  pThis            - the destination string object
;  pSrc             - the source string object.  Can be null, but will return an error code.
; Returns 0 or an error code.
string_object_append            start seg_clib
                                using string_globals
; Define our work area data
                                begin_locals
result                          decl word                                   ; result value inside our local work area
iNewStringLength                decl word
work_area_size                  end_locals

                                debugtag 'append'
                                debugtag 'string_object'
                                sub (4:pThis,4:pSrc),work_area_size

                                testptr <pThis
                                beq null_pointer
                                testptr <pSrc
                                beq null_pointer
; First, get the length of the source string
                                getword [<pSrc],#string_object~length
                                beq empty_source
; Add to the length of the string in the destination
                                clc
                                adc [<pThis]
                                sta <iNewStringLength
; Compare the destination capacity to the length
                                getword [<pThis],#string_object~capacity
                                cmp <iNewStringLength
                                bge copy_characters
; Need to increase the capacity
                                pushptr <pThis
                                pushsword <iNewStringLength
                                jsl string_object_set_capacity
                                bne allocation_error
; We know at this point, the destination capacity is enough to hold the source string.
copy_characters                 anop
                                pushptr [<pSrc],#string_object~str
; Push the destination.  Since we are appending, we have to get the offset to the end of the existing string
                                pushptr [<pThis],#string_object~str,[<pThis]
; Push the length
                                lda [<pSrc]
                                inc a                                    ; Plus 1, to copy the zero-terminator
                                pha
                                jsl copy_memory
; Update the length
                                lda <iNewStringLength
                                sta [<pThis]
empty_source                    lda #0
error                           sta <result
exit                            ret 2:result
null_pointer                    lda #string_error_null_pointer
                                bra error
allocation_error                lda #string_error_allocation
                                bra error
                                end

; --------------------------------------------------------------------------------------------
; Append a zero-terminated string to a string object.
;
; Parameters:
; pThis     - the destination string object
; pSrc      - the source zero terminated string.  Can be null, but will return an error code.
; Returns:
; 0 or error code
string_object_append_zt         start seg_clib
                                using string_globals
; Define our work area data
                                begin_locals
result                          decl word                                   ; result value inside our local work area
iSrcStringLength                decl word
iNewStringLength                decl word
work_area_size                  end_locals

                                debugtag 'append_zt'
                                debugtag 'string_object'
                                sub (4:pThis,4:pSrc),work_area_size

                                testptr <pThis
                                beq null_pointer
                                testptr <pSrc
                                beq null_pointer
                                static_assert_equal string_object~length,0
; First, get the length of the source string
                                string_length [<pSrc]
                                cpy #0
                                beq empty_source
                                sty <iSrcStringLength
; Add to the length of the string in the destination
                                tya
                                clc
                                adc [<pThis]                                ; string_object~length
                                sta <iNewStringLength
; Compare the destination capacity to the length
                                getword [<pThis],#string_object~capacity
                                cmp <iNewStringLength
                                bge copy_characters
; Need to increase the capacity
                                pushptr <pThis
                                pushsword <iNewStringLength
                                jsl string_object_set_capacity
                                bne allocation_error
; We know at this point, the destination capacity is enough to hold the source string.
copy_characters                 anop
                                pushptr <pSrc
; Push the destination.  Since we are appending, we have to get the offset to the end of the existing string
                                pushptr [<pThis],#string_object~str,[<pThis]
; Push the length
                                lda <iSrcStringLength
                                inc a                                    ; Plus 1, to copy the zero-terminator
                                pha
                                jsl copy_memory
; Update the length
                                lda <iNewStringLength
                                sta [<pThis]                            ; string_object~length
empty_source                    lda #0
error                           sta <result
exit                            ret 2:result
null_pointer                    lda #string_error_null_pointer
                                bra error
allocation_error                lda #string_error_allocation
                                bra error
                                end

; --------------------------------------------------------------------------------------------
; Append a character to the end of the string object
;
; Parameters:
;  pThis            - the destination string object
;  wChar            - the character to append, as a WORD.  Only the lower 8 bits will be used
; Returns:
; carry clear if ok, set if an error occurred (allocation issue)
string_object_append_char       start seg_clib
                                using string_globals

                                begin_locals
pBuffer                         decl ptr
work_area_size                  end_locals

                                debugtag 'append_char'
                                debugtag 'string_object'
                                sub (4:pThis,2:wChar),work_area_size

                                getword [<pThis],#string_object~length
                                inc a
                                cmpword [<pThis],#string_object~capacity
                                blt ok_length
                                beq ok_length
; Need to increase the capacity
                                tay
                                pushptr <pThis
                                phy
                                jsl string_object_set_capacity
                                bne allocation_error
ok_length                       anop
                                getptr [<pThis],#string_object~str,<pBuffer
                                getword [<pThis],#string_object~length
                                inc a
                                sta [<pThis]                            ; we know string_object~length is 0
                                tay
                                dey                                     ; length - 1
                                lda <wChar
                                and #$00FF
                                sta [<pBuffer],y                        ; Stores the character and the null terminator at the same time
                                clc
exit                            retkc
allocation_error                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Copy the contents of a string object to an OS string
;
; Parameters:
; pThis             The source string object
; pDest             The the destination string buffer
; iDestCapacity     The destination buffer *character* size.  This does not include the leading length word, it is assumed there is space for that.
; Returns 0 or an error code.
string_object_to_os_string      start seg_clib
                                using string_globals
; Define our work area data
                                begin_locals
result                          decl word                                   ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'to_os_string'
                                debugtag 'string_object'
                                sub (4:pThis,4:pDest,2:iDestCapacity),work_area_size

                                testptr <pThis
                                beq null_pointer
                                testptr <pDest
                                beq null_pointer
; Compare the destination capacity to the length
                                lda <iDestCapacity
                                cmp [<pThis]
                                bge copy_characters
                                bra buffer_too_small
copy_characters                 anop
                                lda [<pThis]
                                sta [<pDest]
                                beq no_size
                                tax
                                pushptr [<pThis],#string_object~str
                                pushptr <pDest,#2
                                phx
                                jsl copy_memory
no_size                         lda #0
error                           sta <result
exit                            ret 2:result
null_pointer                    lda #string_error_null_pointer
                                bra error
buffer_too_small                lda #string_error_buffer_too_small
                                bra error
                                end

; --------------------------------------------------------------------------------------------
; Release the buffer for a string, if it is managed.
;
; If the string is not managed (pool == 0), nothing will be done.
; If the anove case is true, an error will be returned, if the capacity was not already 0, else
; the string was in an unallocate state, which is ok
;
; This is an internal function, so some assumptions will be made
; * The input pointer is valid
;
; Would be nice to maybe not need a stack frame and just pass the pointer in in the registers
; but then you run into needing a local variable and you realized that stack frames are great.
; Could try and 'share' the stack frame with the caller, but that is tricky and would
; be prone to bugs.
;
internal_string_object_free_buffer private seg_clib
                                using string_manager_data
                                using string_globals

; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'object_free_buffer'
                                sub (4:pStr),work_area_size

                                ldy #string_object~info
                                lda [<pStr],y
                                and #string_object_info~pool_mask
                                beq no_pool

                                tax
                                pushptr #global_string_manager
                                pushptr [<pStr],#string_object~str
                                phx
                                jsl string_manager_free_buffer
; Clear things out
clear                           ldy #string_object~info
                                lda [<pStr],y
                                and #(string_object_info~pool_mask*-1)-1            ; Hmm, not sure how to do bit operations on literals, thing like .EOR. seem to be test logic, not bit logic.
                                sta [<pStr],y
                                lda #0
                                putword [<pStr],#string_object~capacity
                                putword [<pStr],#string_object~length
                                putptr [<pStr],#string_object~str

                                stz <result
exit                            ret 2:result

no_pool                         getword [<pStr],#string_object~capacity
                                beq clear                           ; Calling this on an empty, unmanage string is ok, though let's make sure things are clear.
                                lda #string_error_unmanaged         ; Strings seems to be an unmanged string with something in it.  Best to let the caller explicitly clear the string.
                                sta <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Allocate a buffer for a string, with a desired capacity.
; Note that since the underlying allocator is using pooled allocations.
; The final capacity of the string *may* be more that the request.
;
; This is an internal function, so some assumptions will be made
; * The input pointer is valid
; * The string will have no current buffer
;
internal_string_object_alloc_buffer private seg_clib
                                using string_manager_data
                                using string_globals
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
kAllocResult                    decl string_manager_alloc_result_object_size
work_area_size                  end_locals

                                debugtag 'object_alloc_buffer'
                                sub (4:pThis,2:iCapacity),work_area_size

                                pushptr #global_string_manager
                                pushsword <iCapacity
                                pushlocalptr #kAllocResult
                                jsl string_manager_alloc_buffer
                                bne allocation_error
; Could call internal_string_object_attach_buffer from here to reduce duplicate code.
; Buffer
                                lda <kAllocResult+string_manager_alloc_result~ptr
                                putword [<pThis],#string_object~str
                                lda <kAllocResult+string_manager_alloc_result~ptr+2
                                putword [<pThis],#string_object~str+2
; Pool
                                getword [<pThis],#string_object~info
                                and #(string_object_info~pool_mask*-1)-1
                                ora <kAllocResult+string_manager_alloc_result~pool
                                putword [<pThis],#same
; Capacity
                                lda <kAllocResult+string_manager_alloc_result~capacity
                                putword [<pThis],#string_object~capacity

                                stz <result
exit                            anop
                                ret 2:result
allocation_error                lda #string_error_allocation
                                sta <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Attaches an externally allocated buffer
;
; Parameters:
;  pThis        - The string object
;  pAllocResult - An allocation result from the string manager
; This is an internal function, so some assumptions will be made
; * The input pointer is valid
; * The string will have no current buffer
;
internal_string_object_attach_buffer private seg_clib
                                using string_manager_data
                                using string_globals
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                debugtag 'object_attach_buffer'
                                sub (4:pThis,4:pAllocResult),work_area_size
; Buffer
                                getword [<pAllocResult],#string_manager_alloc_result~ptr
                                putword [<pThis],#string_object~str
                                getword [<pAllocResult],#string_manager_alloc_result~ptr+2
                                putword [<pThis],#string_object~str+2
; Pool
                                getword [<pThis],#string_object~info
                                and #(string_object_info~pool_mask*-1)-1
                                ldy #string_manager_alloc_result~pool
                                ora [<pAllocResult],y
                                putword [<pThis],#string_object~info
; Capacity
                                getword [<pAllocResult],#string_manager_alloc_result~capacity
                                putword [<pThis],#string_object~capacity

                                ret
                                end

; -----------------------------------------------------------------------------
; Takes an input word and converts it to BCD.
; The basic idea is from http://www.6502.org/source/integers/hex2dec.htm
;
; Parameters:
;  wValue           value to convert
; Returns:
;  BCD in A/X
word_to_decimal                 start seg_clib

                                begin_locals
dwDecimal                       decl long
work_area_size                  end_locals

                                sub (2:wValue),work_area_size

                                stz <dwDecimal
                                stz <dwDecimal+2

; Overall, this is fairly simple, it is just shifting the bits out the top, and if there is a bit set,
; it uses the BCD table to add the value of that bit.  I just never think of using the BCD mode.

                                sed                 ; Output gets added up in decimal.
                                ldx #(4*15)
loop                            asl <wValue         ; Pop a bit out the top
                                bcc skip            ; not set? Then skip
                                lda <dwDecimal      ; But if the bit was 1,
                                clc
                                adc >table,x         ; Add that bits BCD value to our total
                                sta <dwDecimal
                                lda <dwDecimal+2    ; High word
                                adc >table+2,x
                                sta <dwDecimal+2

skip                            dex             ; Next entry in the table
                                dex
                                dex
                                dex
                                bpl loop

                                cld
                                ret 4:dwDecimal

; These are 32-bit BCD numbers
table                           dc h'01 00 00 00  02 00 00 00  04 00 00 00  08 00 00 00'
                                dc h'16 00 00 00  32 00 00 00  64 00 00 00  28 01 00 00'
                                dc h'56 02 00 00  12 05 00 00  24 10 00 00  48 20 00 00'
                                dc h'96 40 00 00  92 81 00 00  84 63 01 00  68 27 03 00'

                                end

; -----------------------------------------------------------------------------
; Takes an input word and converts it to a bcd string.
;
; Parameters:
;  wValue           value to convert
;  pBuffer          output buffer, must be at least 5 characters.
;  wMinDigits       minimum number of digits. 1-5
; Returns:
;  length of the string.  The string is not null terminated.
word_to_str                     start seg_clib

                                begin_locals
dwDecimal                       decl long
work_area_size                  end_locals

                                debugtag 'word_to_str'
                                sub (2:wValue,4:pBuffer,2:wMinDigits),work_area_size

                                pushsword <wValue
                                jsl word_to_decimal
                                putretptr <dwDecimal

                                lda <wMinDigits
                                cmp #6
                                blt ok1
                                lda #5
ok1                             cmp #1
                                bge ok2
                                lda #1
ok2                             anop
                                sta <wMinDigits
                                sec
                                lda #5
                                sbc <wMinDigits
                                sta <wMinDigits

                                ldy #0                          ; Where we will write to, as well as the final character count.
                                ldx #0
; In the high word, the only significant digit is the lower nybble.
                                lda <dwDecimal+2
                                and #$000F
                                bne char1
                                cpx <wMinDigits
                                blt skip1
char1                           clc
                                adc #'0'
                                shortm
                                sta [<pBuffer],y
                                longm
                                iny
                                stz <wMinDigits                         ; once we write something, set this to 0
skip1                           inx
loop                            anop
                                lda #0
; Get the next digit in the ACC
                                asl <dwDecimal
                                rol a
                                asl <dwDecimal
                                rol a
                                asl <dwDecimal
                                rol a
                                asl <dwDecimal
                                rol a
                                bne char2
                                cpx <wMinDigits
                                blt skip2
char2                           clc
                                adc #'0'
                                shortm
                                sta [<pBuffer],y
                                longm
                                iny
                                stz <wMinDigits                         ; once we write something, set this to 0
skip2                           inx
                                cpx #5
                                blt loop
                                sty <dwDecimal

                                ret 2:dwDecimal
                                end

; -----------------------------------------------------------------------------
; Takes an input word and converts it to a string.
;
; Parameters:
;  wValue           value to convert
;  pBuffer          output buffer, must be at least 4 characters.
;  wMinDigits       minimum number of digits. 1-4
; Returns:
;  length of the string.  The string is not null terminated.
word_to_hex_str                 start seg_clib

                                begin_locals
wCount                          decl word
work_area_size                  end_locals

                                debugtag 'word_to_hex_str'
                                sub (2:wValue,4:pBuffer,2:wMinDigits),work_area_size

                                lda <wMinDigits
                                cmp #5
                                blt ok1
                                lda #4
ok1                             cmp #1
                                bge ok2
                                lda #1
ok2                             anop
                                sta <wMinDigits
                                sec
                                lda #4
                                sbc <wMinDigits
                                sta <wMinDigits

                                stz <wCount
                                ldy #0
; Get the next digit in the ACC
loop                            anop
                                lda #0
                                asl <wValue
                                rol a
                                asl <wValue
                                rol a
                                asl <wValue
                                rol a
                                asl <wValue
                                rol a
                                cmp #0
                                bne non_zero
                                cpy <wMinDigits
                                blt skip
non_zero                        tax
                                lda >hex_to_ascii,x
                                shortm
                                sta [<pBuffer]
                                longm
                                inc <pBuffer
                                bne same_bank
                                inc <pBuffer+2
same_bank                       inc <wCount
                                stz <wMinDigits                         ; once we write something, set this to 0
skip                            iny
                                cpy #4
                                blt loop

                                ret 2:wCount
hex_to_ascii                    dc c'0123456789ABCDEF'
                                end

; -----------------------------------------------------------------------------
; Takes an input dword and converts it to a string.
;
; Parameters:
;  dwValue          value to convert
;  pBuffer          output buffer
;  wMinDigits       minimum number of digits. 1-8
; Returns:
;  length of the string.  The string is not null terminated.
bcd32_to_str                    start seg_clib

                                begin_locals
work_area_size                  end_locals

                                debugtag 'bcd32_to_str'
                                sub (4:dwDecimal,4:pBuffer,2:wMinDigits),work_area_size

                                lda <wMinDigits
                                cmp #9
                                blt ok1
                                lda #8
ok1                             cmp #1
                                bge ok2
                                lda #1
ok2                             anop
                                sta <wMinDigits
                                sec
                                lda #8
                                sbc <wMinDigits
                                sta <wMinDigits

                                ldy #0                          ; Where we will write to, as well as the final character count.
                                ldx #0
; In the high word, the only significant digit is the lower nybble.
loop_high                       anop
                                lda #0
; Get the next digit in the ACC
                                asl <dwDecimal+2
                                rol a
                                asl <dwDecimal+2
                                rol a
                                asl <dwDecimal+2
                                rol a
                                asl <dwDecimal+2
                                rol a
                                bne char1
                                cpx <wMinDigits
                                blt skip1
char1                           clc
                                adc #'0'
                                shortm
                                sta [<pBuffer],y
                                longm
                                iny
                                stz <wMinDigits                         ; once we write something, set this to 0
skip1                           inx
                                cpx #4
                                blt loop_high

loop_low                        anop
                                lda #0
; Get the next digit in the ACC
                                asl <dwDecimal
                                rol a
                                asl <dwDecimal
                                rol a
                                asl <dwDecimal
                                rol a
                                asl <dwDecimal
                                rol a
                                bne char2
                                cpx <wMinDigits
                                blt skip2
char2                           clc
                                adc #'0'
                                shortm
                                sta [<pBuffer],y
                                longm
                                iny
                                stz <wMinDigits                         ; once we write something, set this to 0
skip2                           inx
                                cpx #8
                                blt loop_low
                                sty <dwDecimal

                                ret 2:dwDecimal
                                end

; -----------------------------------------------------------------------------
; Convert a decimal string (not zero terminated), to a hex word value
; Parameters:
; wOffset   - offset into the buffer
; wSize     - length of the string in the buffer
; pBuffer   - buffer with the string in it
; Returns:
; carry clear, value in acc
; carry set, parse error
str_view_decimal_to_word        start seg_clib

                                begin_locals
result                          decl word
wTemp                           decl word
wDigit                          decl word
work_area_size                  end_locals

                                debugtag 'decimal_to_word'
                                sub (2:wOffset,2:wSize,4:pBuffer),work_area_size

                                stz <result

                                ldx <wSize
                                beq error

                                ldy <wOffset
loop                            anop
; Probably could just read off the edge and not bother with with setting the acc size
                                shortm
                                lda [<pBuffer],y
                                longm
                                and #$00ff

                                cmp #'0'
                                blt error
                                cmp #'9'+1
                                bge error
                                sec
                                sbc #'0'
                                sta <wDigit
; multiply the current result by 10
                                lda <result
                                asl a
                                sta <wTemp
                                asl a
                                asl a
                                clc
                                adc <wTemp              ; x8 + x2 = x10
                                adc <wDigit
                                sta <result
                                iny
                                dex
                                bne loop

                                clc
exit                            retkc 2:result
error                           sec
                                bra exit
                                end

; -----------------------------------------------------------------------------
; Convert a decimal string (not zero terminated), to a bcd32 value
; Parameters:
; wOffset   - offset into the buffer
; wSize     - length of the string in the buffer
; pBuffer   - buffer with the string in it
; Returns:
; carry clear, value in acc/x
; carry set, parse error
str_view_decimal_to_bcd32       start seg_clib

                                begin_locals
result                          decl dword
wTemp                           decl word
wDigit                          decl word
work_area_size                  end_locals

                                debugtag 'decimal_to_bcd32'
                                sub (2:wOffset,2:wSize,4:pBuffer),work_area_size

                                stz <result
                                stz <result+2

                                ldx <wSize
                                beq error

                                ldy <wOffset
loop                            anop
; Probably could just read off the edge and not bother with with setting the acc size
                                shortm
                                lda [<pBuffer],y
                                longm
                                and #$00ff

                                cmp #'0'
                                blt error
                                cmp #'9'+1
                                bge error
                                sec
                                sbc #'0'
; get the value in the high nybble
                                xba
                                shiftleft 4
; rol the value in
                                asl a
                                rol <result
                                rol <result+2
                                asl a
                                rol <result
                                rol <result+2
                                asl a
                                rol <result
                                rol <result+2
                                asl a
                                rol <result
                                rol <result+2

                                iny
                                dex
                                bne loop

                                clc
exit                            retkc 4:result
error                           sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Compare a string view, to a zero terminated string
; Parameters:
; wStr1Offset   - the string view offset
; wStr1Size     - the string view size
; pStr1         - the string view buffer
; pStr2         - the zero teminated string
; Returns:
; carry set if the tokenizer is at eob (end-of-buffer)
str_view_compare_to_zt          start seg_clib
                                using textlib_global_data

                                begin_locals
work_area_size                  end_locals

                                debugtag 'str_view_compare_to_zt'

                                sub (2:wStr1Offset,2:wStr1Size,4:pStr1,4:pStr2),work_area_size

                                lda <wStr1Size
                                beq is_zero

; It's going to be easier if I add the offset to the buffer
                                lda <wStr1Offset
                                clc
                                adc <pStr1
                                sta <pStr1
                                lda #0
                                adc <pStr1+2
                                sta <pStr1+2

                                ldy #0
                                shortm
loop                            lda [<pStr2],y
                                beq at_zt
                                cmp [<pStr1],y
                                bne no_match
                                iny
                                cpy <wStr1Size
                                blt loop
; The next character in string 2, must be 0 or no match
                                lda [<pStr2],y
                                longm
                                beq is_match
                                sec
                                bra exit

at_zt                           anop                        ; we hit the zt of the second string, before we reached the length of the first string
no_match                        anop                        ; characters didn't match
                                longm
is_zero                         anop                        ; assuming a zero length input will not match.  Do we want empty == empty to be true?  Hmm.
                                sec
                                bra exit

is_match                        clc
exit                            retkc
                                end

; --------------------------------------------------------------------------------------------
; Compare a string view, a table of string, with a 'short' address.
; Parameters:
; wStr1Offset   - the string view offset
; wStr1Size     - the string view size
; pStr1         - the string view buffer
; wTableSize    - the number of strings in the short table
; pShortTable   - the table of strings.  The table must be a 'short address' table, with the strings in the same bank as the table itself.
; Returns:
; The index of the matching string in A, and the carry clear
; The carry will be set if no match
str_view_compare_to_short_table_zt start seg_clib
                                using textlib_global_data

                                begin_locals
pStr2                           decl ptr
wTableIndex                     decl word
work_area_size                  end_locals

                                debugtag 'str_view_compare_to_short_table_zt'

                                sub (2:wStr1Offset,2:wStr1Size,4:pStr1,2:wTableSize,4:pStrTable),work_area_size

                                lda <wStr1Size
                                ora <wTableSize
                                beq is_zero

; It's going to be easier if I add the offset to the buffer
                                lda <wStr1Offset
                                clc
                                adc <pStr1
                                sta <pStr1
                                lda #0
                                adc <pStr1+2
                                sta <pStr1+2

; All the string should be in the same bank as the table
                                lda <pStrTable+2
                                sta <pStr2+2

                                stz <wTableIndex
table_loop                      lda <wTableIndex
                                asl a
                                tay
                                lda [<pStrTable],y
                                sta <pStr2

                                jsr check_match
                                bcc found_match

                                inc <wTableIndex
                                lda <wTableIndex
                                cmp <wTableSize
                                blt table_loop

found_match                     clc
                                retkc 2:wTableIndex

check_match                     ldy #0
                                shortm
loop                            lda [<pStr2],y
                                beq at_zt
                                cmp [<pStr1],y
                                bne no_match
                                iny
                                cpy <wStr1Size
                                blt loop
; The next character in string 2, must be 0 or no match
                                lda [<pStr2],y
                                longm
                                beq is_match
                                sec
                                rts

at_zt                           anop                        ; we hit the zt of the second string, before we reached the length of the first string
no_match                        anop                        ; characters didn't match
                                longm
is_zero                         anop                        ; assuming a zero length input will not match.  Do we want empty == empty to be true?  Hmm.
                                sec
                                rts

is_match                        clc
                                rts
                                end

; --------------------------------------------------------------------------------------------
; Compare a string view, to a zero terminated string
; Parameters:
; wStrOffset    - the string view offset
; wStrSize      - the string view size
; wChar         - the char to find
; Returns:
; if found, carry clear, and the index in a
str_view_find_char              start seg_clib

                                begin_locals
work_area_size                  end_locals

                                debugtag 'str_view_compare_to_zt'

                                sub (2:wOffset,2:wSize,4:pStr,2:wChar),work_area_size

                                ldx #0
                                lda <wSize
                                beq is_zero

                                ldy <wOffset
                                shortm
loop                            lda [<pStr],y
                                beq at_zt
                                cmp <wChar
                                beq is_match
                                inx
                                iny
                                cpx <wSize
                                blt loop

at_zt                           anop                        ; we hit the zt of the second string, before we reached the length of the first string
no_match                        anop                        ; characters didn't match
                                longm
is_zero                         anop                        ; assuming a zero length input will not match.  Do we want empty == empty to be true?  Hmm.
                                sec
                                bra exit

is_match                        anop
                                longm
                                clc
exit                            anop
                                stx <wChar
                                retkc 2:wChar
                                end

; --------------------------------------------------------------------------------------------
; Append a zero-terminated string to a string buffer
;
; Parameters:
; pDest         - the buffer to append to
; wDestOffset   - the offset in the buffer to start writing to.
; wDestSize     - the total size of the destination buffer.  This includes any zero termination.
; pSource       - the source buffer
; Returns:
; The offset to where the zero terminator was written to in the source buffer
; Carry clear if there was no overflow of the buffer.
str_append                      start seg_clib

                                begin_locals
work_area_size                  end_locals

                                debugtag 'str_append'

                                sub (4:pDest,2:wDestOffset,2:wDestSize,4:pSource),work_area_size

                                ldy <wDestSize
                                beq no_size

; For the rest of this, we want the size-1, because we have to account for the zero-termination
                                dey
                                sty <wDestSize

                                ldy <wDestOffset
                                cpy <wDestSize
                                bge at_end

; Set the databank to the source
                                setdatabanktoptr <pSource

                                shortm
                                ldx <pSource

loop                            getword {x},#0
                                beq done_source
                                sta [<pDest],y
                                inx
                                iny
                                cpy <wDestSize
                                blt loop
; We can always assume there is space for the zero-terminator
done_source                     lda #0
                                sta [<pDest],y
                                longm

                                restoredatabank
                                clc
; Returning the offset in Y
exit                            retkc 2:Y
no_size                         anop
at_end                          anop
                                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Append a string view to a string buffer
;
; Parameters:
; pDest         - the buffer to append to
; wSrcSize      - the size of the source
; wDestOffset   - the offset in the buffer to start writing to.
; wDestSize     - the total size of the destination buffer.  This includes any zero termination.
; pSource       - the source buffer
; Returns:
; The offset to where the zero terminator was written to in the source buffer
; Carry clear if there was no overflow of the buffer.
str_append_view                 start seg_clib

                                begin_locals
work_area_size                  end_locals

                                debugtag 'str_append_view'

                                sub (4:pDest,2:wSrcSize,2:wDestOffset,2:wDestSize,4:pSource),work_area_size

                                ldy <wDestSize
                                beq no_size

; For the rest of this, we want the size-1, because we have to account for the zero-termination
                                dey
                                sty <wDestSize

                                ldy <wDestOffset
                                cpy <wDestSize
                                bge at_end

; Set the databank to the source
                                setdatabanktoptr <pSource

                                shortm
                                ldx <pSource

loop                            dec <wSrcSize
                                beq done_source
                                getword {x},#0
                                sta [<pDest],y
                                inx
                                iny
                                cpy <wDestSize
                                blt loop
; We can always assume there is space for the zero-terminator
done_source                     lda #0
                                sta [<pDest],y
                                longm

                                restoredatabank
                                clc
; Returning the offset in Y
exit                            retkc 2:Y
no_size                         anop
at_end                          anop
                                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Append a zero-terminated string to a string buffer
;
; Parameters:
; pDest         - the buffer to append to
; wDestOffset   - the offset in the buffer to start writing to.
; wDestSize     - the total size of the destination buffer.  This includes any zero termination.
; wValue        - the value to append as a hex string.
; wMinDigits    - minumum digits to show.
; Returns:
; The offset to where the zero terminator was written to in the source buffer
; Carry clear if there was no overflow of the buffer.
str_append_hex_word             start seg_clib
                                using string_globals

                                begin_locals
work_area_size                  end_locals

                                debugtag 'str_append_hex_word'

                                sub (4:pDest,2:wDestOffset,2:wDestSize,2:wValue,2:wMinDigits),work_area_size

                                pushsword <wValue
                                pushptr #string~temp_buffer
                                pushsword <wMinDigits
                                jsl word_to_hex_str
; The above call, didn't null terminate the string.  Gonna be cavilier and just write a word, as there should be plenty of space left in the buffer.
                                tax
                                lda #0
                                sta >string~temp_buffer,x

                                pushptr <pDest
                                pushsword <wDestOffset
                                pushsword <wDestSize
                                pushptr #string~temp_buffer
                                jsl str_append

                                retkc 2:A
                                end


