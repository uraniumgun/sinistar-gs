                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.definitions.asm

                            mcopy generated/datalib.data.entry.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
datalib_data_entry_data     data seg_flib

datalib_data_entry          dc i2'sizeof~datalib_data_entry'
                            dc a4'datalib_data_entry~vtable'

datalib_data_entry~vtable   dc a4'datalib_data_entry_construct'
                            dc a4'0'    ; copy
                            dc a4'0'    ; move
                            dc a4'datalib_data_entry_destruct'
                            end

; -----------------------------------------------------------------------------
; Construct an empty data entry
datalib_data_entry_construct start seg_flib

; Define our work area data
                            begin_locals
result                      decl word                                           ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'construct'
                            debugtag 'datalib_data_entry'
                            sub (4:pThis),work_area_size

                            setdatabanktoptr <pThis

                            ldx <pThis
                            putzero {x},#datalib_data_entry~id
                            putzero {x},#datalib_data_entry~id+2
                            putzero {x},#datalib_data_entry~offset
                            putzero {x},#datalib_data_entry~offset+2
                            putzero {x},#datalib_data_entry~size
                            putzero {x},#datalib_data_entry~size+2
                            putzero {x},#datalib_data_entry~data_ptr
                            putzero {x},#datalib_data_entry~data_ptr+2
                            putzero {x},#datalib_data_entry~ref_count
                            putzero {x},#datalib_data_entry~ref_count+2
                            putzero {x},#datalib_data_entry~sub_type
                            putzero {x},#datalib_data_entry~sub_type+2
                            putzero {x},#datalib_data_entry~last_access
                            putzero {x},#datalib_data_entry~last_access+2
                            putzero {x},#datalib_data_entry~type_ptr
                            putzero {x},#datalib_data_entry~type_ptr+2
                            putzero {x},#datalib_data_entry~compression_type

                            pushptr <pThis,#datalib_data_entry~name
                            jsl string_object_construct

                            restoredatabank

                            stz <result
                            ret 2:result
                            end

; -----------------------------------------------------------------------------
; Destruct a data entry
datalib_data_entry_destruct start seg_flib

; Define our work area data
                            begin_locals
result                      decl word                                           ; result value inside our local work area
pTypeEntry                  decl ptr
work_area_size              end_locals

                            debugtag 'destruct'
                            debugtag 'datalib_data_entry'
                            sub (4:pThis),work_area_size

                            pushptr <pThis
                            jsl _datalib_library_unload_data_entry

                            pushptr <pThis,#datalib_data_entry~name
                            jsl string_object_destruct

                            stz <result
                            ret 2:result
                            end

; --------------------------------------------------------------------------------------------
; Allocate a new datalib_data_entry object.
;
; Parameters: none
; Returns:
; if carry clear, the pointer to the object, will not be null
; if carry set, null
datalib_data_entry_new      start seg_flib

; Define our work area data
                            begin_locals
result                      decl ptr                                ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'new'
                            debugtag 'datalib_data_entry'
                            sub ,work_area_size

                            pushsword #sizeof~datalib_data_entry
                            jsl sba_alloc
                            bcs allocation_error
                            sta <result
                            stx <result+2

                            phx
                            pha
                            jsl datalib_data_entry_construct
                            clc                                     ; no error
exit                        retkc 4:result
allocation_error            anop
                            clearptr <result
                            sec                                     ; error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Deallocate a datalib_data_entry object.
;
; Parameters:
; pThis     - pointer to a datalib_data_entry
; Returns: nothing
datalib_data_entry_delete   start seg_flib

; Define our work area data
                            begin_locals
work_area_size              end_locals

                            debugtag 'delete'
                            debugtag 'datalib_data_entry'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit

                            pushptr <pThis
                            jsl datalib_data_entry_destruct

                            pushptr <pThis
                            jsl sba_free

exit                        ret
                            end
