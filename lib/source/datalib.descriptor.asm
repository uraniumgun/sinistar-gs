                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.definitions.asm
                            copy 13/Ainclude/E16.Memory

                            mcopy generated/datalib.descriptor.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Construct an empty descriptor
datalib_descriptor_construct start seg_flib
; Define our work area data
                            begin_locals
result                      decl word                                           ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'construct'
                            debugtag 'datalib_descriptor'
                            sub (4:pDescriptor),work_area_size

                            lda #0
                            putword [<pDescriptor],#datalib_descriptor~info
                            putword [<pDescriptor],#datalib_descriptor~open_ref_count
                            putword [<pDescriptor],#datalib_descriptor~library_ptr
; Initialize the name
                            pushptr <pDescriptor,#datalib_descriptor~name
                            jsl string_object_construct
; Initialize the file descriptor
                            pushptr <pDescriptor,#datalib_descriptor~file_desc
                            jsl file_descriptor_construct

                            stz <result
                            ret 2:result
                            end

; -----------------------------------------------------------------------------
; Destruct a descriptor
datalib_descriptor_destruct start seg_flib
; Define our work area data
                            begin_locals
work_area_size              end_locals

                            debugtag 'destruct'
                            debugtag 'datalib_descriptor'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit
; Delete the library
                            pushptr [<pThis],#datalib_descriptor~library_ptr
                            jsl datalib_library_delete
; Delete the embeded file descriptor
                            pushptr <pThis,#datalib_descriptor~file_desc
                            jsl file_descriptor_destruct
; Delete the embeded name string_object
                            pushptr <pThis,#datalib_descriptor~name
                            jsl string_object_destruct

exit                        ret
                            end

; -----------------------------------------------------------------------------
; Allocate and construct an empty descriptor
; Returns:
; if carry clear, the descriptor (will not be null)
; if carry set, null
datalib_descriptor_new      start seg_flib
; Define our work area data
                            begin_locals
result                      decl ptr                                           ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'new'
                            debugtag 'datalib_descriptor'
                            sub ,work_area_size

                            pushsword #sizeof~datalib_descriptor
                            jsl sba_alloc
                            bcs allocation_error
                            sta <result
                            stx <result+2
                            phx
                            pha
                            jsl datalib_descriptor_construct
; Should test to see if the new failed and deallocate.
                            clc                                             ; no error
exit                        anop
                            retkc 4:result
allocation_error            clearptr <result
                            sec                                             ; error
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Delete the descriptor
datalib_descriptor_delete   start seg_flib
; Define our work area data
                            begin_locals
work_area_size              end_locals

                            debugtag 'delete'
                            debugtag 'datalib_descriptor'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit
                            pushptr <pThis
                            jsl datalib_descriptor_destruct
                            pushptr <pThis
                            jsl sba_free
exit                        ret
                            end

; -----------------------------------------------------------------------------
; Open the file associated with the descriptor
; This uses a reference counting system to track open / close calls
; This allows the file descriptor to only be open when needed.
datalib_descriptor_open     start seg_flib
; Define our work area data
                            begin_locals
result                      decl word
work_area_size              end_locals

                            debugtag 'open'
                            debugtag 'datalib_descriptor'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit
; Is it already open?
                            pushptr <pThis,#datalib_descriptor~file_desc
                            jsl file_descriptor_is_open
                            bne exit
; Open the file
                            pushptr <pThis,#datalib_descriptor~file_desc
                            pushptr <pThis,#datalib_descriptor~name
                            jsl file_descriptor_open
                            bne failed_to_open

exit                        anop
; Add a reference
                            getword [<pThis],#datalib_descriptor~open_ref_count
                            inc a
                            sta [<pThis],y

                            stz <result
error_exit                  ret 2:result
failed_to_open              sta <result
                            bra error_exit
                            end

; -----------------------------------------------------------------------------
; Close the file associated with the descriptor
datalib_descriptor_close     start seg_flib
; Define our work area data
                            begin_locals
result                      decl word
work_area_size              end_locals

                            debugtag 'close'
                            debugtag 'datalib_descriptor'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit

                            getword [<pThis],#datalib_descriptor~open_ref_count
                            beq error_ref
                            dec a
                            sta [<pThis],y
                            bne exit
; Is it already closed?
                            pushptr <pThis,#datalib_descriptor~file_desc
                            jsl file_descriptor_is_open
                            beq error_closed
; Close the file
                            pushptr <pThis,#datalib_descriptor~file_desc
                            jsl file_descriptor_close
                            bne failed_to_close

exit                        stz <result
error_exit                  ret 2:result
failed_to_close             sta <result
                            bra error_exit
error_ref                   anop
                            debugger_msg #datalib_descriptor_msg_error_ref
                            lda #1
                            bra failed_to_close
error_closed                anop
                            debugger_msg #datalib_descriptor_msg_error_closed
                            lda #1
                            bra failed_to_close

datalib_descriptor_msg_error_ref dw 'datalib_descriptor: ref count already 0'
datalib_descriptor_msg_error_closed dw 'datalib_descriptor: already closed'

                            end
