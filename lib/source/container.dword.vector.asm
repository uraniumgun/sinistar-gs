
                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy 13/Ainclude/E16.Memory
                            mcopy generated/container.dword.vector.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Push back a unique dword into the vector.
;
; Parameters:
;  pThis        - the vector
;  dwData       - the data to add, if not already in the vector
container_dword_vector_push_back_unique start seg_clib
                        begin_locals
result                  decl word                                           ; result value inside our local work area
pData                   decl ptr
work_area_size          end_locals

                        debugtag 'push_back_unique'
                        debugtag 'dword_vector'
                        sub (4:pThis,4:dwData),work_area_size             ; Parameters, plus the amount of space for our local work area

                        stz <result

                        getword [<pThis],#vector_definition~size
                        beq add
                        tax
                        getptr [<pThis],#vector_definition~data_ptr,<pData
                        ldy #0
loop                    lda [<pData],y
                        iny
                        iny
                        cmp <dwData
                        bne skip
                        lda [<pData],y
                        cmp <dwData+2
                        beq found
skip                    iny
                        iny
                        dex
                        bne loop
; Not found
add                     pushptr <pThis
                        pushptr <dwData
                        jsl container_dword_vector_copy_back
                        sta <result
found                   ret 2:result
                        end

; --------------------------------------------------------------------------------------------
; Copy a dword the end of the vector.
; This is a specialize call that assumes the contents of the vector is a dword.
; This will be validated.
; The vector's capacity will be increased, if needed and if allowed.
; Note, on resizing, the whole vector can end up moving to a new memory location!
;
; Params:
;	pThis           - long pointer (4 bytes) to a vector_definition
;	dwData          - dword (4 bytes)
; Returns: acc - 0 on success, > 0 is error code.
container_dword_vector_copy_back start seg_clib
                        using container_errors

; Define our work area data
                        begin_locals
result                  decl word                                               ; result value inside our local work area
iDestIndex              decl word
iDestOffset             decl word
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'copy_back'
                        debugtag 'dword_vector'
                        sub (4:pThis,4:dwData),work_area_size           ; Parameters, plus the amount of space for our local work area

                        stz <result
; Check for null pointers
                        testptr <pThis
                        jeq null_pointer
; Validate that this is a dword-sized vector
                        getword [<pThis],#vector_definition~object_definition+object_definition~size
                        cmp #4
                        bne wrong_size

                        getword [<pThis],#vector_definition~size        ; Get the size
                        ldy #vector_definition~capacity
                        cmp [<pThis],y
                        blt has_space
; Need to increase the capacity
                        lda [<pThis],y       ; Get the current capacity
                        ldy #vector_definition~growth_size
                        clc
                        adc [<pThis],y
                        bcs resize_overflow     ; Too much!
                        tay
                        pushdword <pThis
                        phy
                        jsl container_vector_set_capacity               ; todo: call a dword specific capacity set?
                        bne error_exit
                        lda [<pThis]          ; Get the current size back
has_space               anop
                        sta <iDestIndex             ; The destination *index*
                        asl a
                        asl a                       ; * 4
                        sta <iDestOffset

                        getptr [<pThis],#vector_definition~data_ptr,<pTemp,<iDestOffset

                        lda <dwData
                        sta [<pTemp]
                        ldy #2
                        lda <dwData+2
                        sta [<pTemp],y

                        lda <iDestIndex
                        inc a
                        sta [<pThis]          ; Store the new size (number of elements)

exit                    anop
                        ret 2:result

resize_overflow         lda #container_error_resize_overflow
                        bra error_exit
null_pointer            anop
                        lda #container_error_null_pointer
                        bra error_exit
wrong_size              lda #container_error_size_mismatch
error_exit              anop
                        sta <result
                        bra exit
                        end
