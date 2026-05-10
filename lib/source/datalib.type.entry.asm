                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.definitions.asm

                            mcopy generated/datalib.type.entry.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
datalib_type_entry_data     data seg_flib

datalib_type_entry          dc i2'sizeof~datalib_type_entry'
                            dc a4'datalib_type_entry~vtable'

datalib_type_entry~vtable   dc a4'datalib_type_entry_construct'
                            dc a4'0'    ; copy
                            dc a4'0'    ; move
                            dc a4'datalib_type_entry_destruct'
                            end

; -----------------------------------------------------------------------------
; Construct an empty type entry
datalib_type_entry_construct start seg_flib
                            using datalib_data_entry_data

; Define our work area data
                            begin_locals
result                      decl word                                           ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'construct'
                            debugtag 'datalib_type_entry'
                            sub (4:pThis),work_area_size

                            lda #0
                            putlong [<pThis],#datalib_type_entry~id
                            putlong [<pThis],#datalib_type_entry~info
                            putlong [<pThis],#datalib_type_entry~library_ptr
                            putlong [<pThis],#datalib_type_entry~translator_ptr

; Initialize the data entries array
                            pushptr <pThis,#datalib_type_entry~data_entries
                            pushptr #datalib_data_entry
                            jsl container_vector_construct

                            stz <result
                            ret 2:result
                            end

; -----------------------------------------------------------------------------
; Destruct a type entry
datalib_type_entry_destruct start seg_flib
; Define our work area data
                            begin_locals
result                      decl word                                           ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'destruct'
                            debugtag 'datalib_type_entry'
                            sub (4:pThis),work_area_size

                            pushptr <pThis,#datalib_type_entry~data_entries
                            jsl container_vector_destruct

                            stz <result
                            ret 2:result
                            end

; --------------------------------------------------------------------------------------------
; Allocate a new datalib_type_entry object.
;
; Parameters: none
; Returns:
; if carry clear, the pointer to the object, will not be null
; if carry set, null
datalib_type_entry_new      start seg_flib
; Define our work area data
                            begin_locals
result                      decl ptr                            ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'new'
                            debugtag 'datalib_type_entry'
                            sub ,work_area_size

                            pushsword #sizeof~datalib_type_entry
                            jsl sba_alloc
                            bcs allocation_error
                            sta <result
                            stx <result+2

                            phx
                            pha
                            jsl datalib_type_entry_construct
                            clc                                 ; no error
exit                        retkc 4:result
allocation_error            anop
                            clearptr <result
                            sec                                 ; error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Deallocate a datalib_type_entry object.
;
; Parameters:
; pThis     - pointer to a datalib_type_entry
; Returns: nothing
datalib_type_entry_delete   start seg_flib
; Define our work area data
                            begin_locals
work_area_size              end_locals

                            debugtag 'delete'
                            debugtag 'datalib_type_entry'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit

                            pushptr <pThis
                            jsl datalib_type_entry_destruct

                            pushptr <pThis
                            jsl sba_free

exit                        ret
                            end

; --------------------------------------------------------------------------------------------
; Attach the default translator for the type
datalib_type_entry_attach_default_translator start seg_flib

                            begin_locals
work_area_size              end_locals

                            debugtag 'attach_default_translator'
                            debugtag 'datalib_type_entry'
                            sub (4:pThis),work_area_size

                            pushptr [<pThis],#datalib_type_entry~id
                            jsl datalib_manager_get_default_translator_for_type

                            putptrlow [<pThis],#datalib_type_entry~translator_ptr
                            txa
                            putptrhigh [<pThis],#datalib_type_entry~translator_ptr
                            ret
                            end
; --------------------------------------------------------------------------------------------
; Find a data entry
; Parameters:
;  pThis        - the type entry
;  hDataID      - the data ID
datalib_type_entry_find_data_entry start seg_flib

                            begin_locals
pDataEntry                  decl ptr
itr                         decl sizeof~vector_iterator
work_area_size              end_locals

                            debugtag 'find_data_entry'
                            debugtag 'datalib_type_entry'
                            sub (4:pThis,4:hDataID),work_area_size

                            getword [<pThis],#datalib_type_entry~info
                            bit #datalib_type_entry_info~ordered_data_ids
                            bne ordered_ids
; Linear search
                            pushptr <pThis,#datalib_type_entry~data_entries
                            pushlocalptr #itr
                            jsl container_vector_front
                            Jne empty
loop                        anop
                            getword [<itr],#datalib_data_entry~id
                            cmp <hDataID
                            bne nope
                            getword [<itr],#datalib_data_entry~id+2
                            cmp <hDataID+2
                            beq found

nope                        vector_iterator_next_test_end <itr
                            bne loop
                            bra not_found
found                       clc
                            retkc 4:itr                                       ; Return here, for linear search loop, since we already have the pointer in itr

; The IDs are ordered, so we can do a lookup
ordered_ids                 anop
                            lda <hDataID+2
                            bne bad_ordered_id

                            pushptr <pThis,#datalib_type_entry~data_entries
                            pushsword <hDataID
                            jsl container_vector_data_at
                            bcs out_of_range
                            putretptr <pDataEntry

exit                        retkc 4:pDataEntry
bad_ordered_id              anop
out_of_range                anop
empty                       anop
not_found                   anop
                            clearptr <pDataEntry
                            sec
                            bra exit

                            end
; --------------------------------------------------------------------------------------------
; Get a data entry by index
; Parameters:
;  pThis        - the type entry
;  wIndex       - the data entry index
datalib_type_entry_get_data_entry_by_index start seg_flib

                            begin_locals
pDataEntry                  decl ptr
itr                         decl sizeof~vector_iterator
work_area_size              end_locals

                            debugtag 'get_data_entry_by_index'
                            debugtag 'datalib_type_entry'
                            sub (4:pThis,2:wIndex),work_area_size

                            pushptr <pThis,#datalib_type_entry~data_entries
                            pushsword <wIndex
                            jsl container_vector_data_at
                            putretptr <pDataEntry

                            retkc 4:pDataEntry

                            end
; --------------------------------------------------------------------------------------------
; Unserialize a type entry.
; This will just do the basic data of the type entry, it will not do its data entries.
;
; Parameters:
; pThis     - pointer to a datalib_type_entry
; pReader   - pointer to a file_reader

; Returns:
; 0 or error code
_datalib_type_entry_unserialize start seg_flib
                            using file_manager_errors
                            using object_errors
; Define our work area data
                            begin_locals
result                      decl word
pData                       decl ptr
work_area_size              end_locals

                            debugtag 'unserialize'
                            debugtag 'datalib_type_entry'
                            sub (4:pThis,4:pReader),work_area_size

                            testptr <pThis
                            beq null_pointer

                            testptr <pReader
                            beq null_pointer

                            pushptr <pReader
                            pushsword #sizeof~datalib_type_serialized
                            jsl file_reader_get_buffered_data
                            bcs read_error
                            putretptr <pData

; Making an assumption that the IDs are in the same position
                            getword [<pData],#datalib_type_serialized~id
                            sta [<pThis]
                            getword [<pData],#datalib_type_serialized~id+2
                            sta [<pThis],y
                            pushptr <pThis
                            jsl datalib_type_entry_attach_default_translator
; There is also an offset to the data entries for the type, but we are going to ignore it, and assume they will be unserialized later
                            lda #0
error_exit                  sta <result
                            ret 2:result
null_pointer                lda #object_error_null_pointer
                            bra error_exit
read_error                  lda #file_manager_error_read_error
                            bra error_exit
                            end

; --------------------------------------------------------------------------------------------
; Unserialize the data entries for a type entry.
;
; Parameters:
; pThis     - pointer to a datalib_type_entry
; pReader   - pointer to a file_reader
; wVersion  - the version of the data entries.  1 or 2

; Returns:
; 0 or error code
_datalib_type_entry_unserialize_data_entries start seg_flib
                            using datalib_errors
                            using file_manager_errors
                            using object_errors
; Define our work area data
                            begin_locals
result                      decl word
pData                       decl ptr
iDataEntries                decl long
itr                         decl sizeof~vector_iterator
work_area_size              end_locals

                            debugtag 'unserialize_data_entries'
                            debugtag 'datalib_type_entry'
                            sub (4:pThis,4:pReader,2:wVersion),work_area_size

                            testptr <pThis
                            jeq null_pointer

                            testptr <pReader
                            jeq null_pointer
; Read a header
                            pushptr <pReader
                            pushsword #sizeof~datalib_data_entries_header_serialized
                            jsl file_reader_get_buffered_data
                            bcs read_error
                            putretptr <pData
; Get the count.  We error out if >64k
                            getword [<pData],#datalib_data_entries_header_serialized~count
                            sta <iDataEntries
                            getword [<pData],#datalib_data_entries_header_serialized~count+2
                            bne unsupported_count                                   ; Not supporting >64k data entries for a type.  This shouldn't be an issue for a small project, but...
; Get the info bits for the type.
                            getword [<pData],#datalib_data_entries_header_serialized~info
                            putword [<pThis],#datalib_type_entry~info
                            getword [<pData],#datalib_data_entries_header_serialized~info+2
                            putword [<pThis],#datalib_type_entry~info+2
; Resize our vector
                            pushptr <pThis,#datalib_type_entry~data_entries
                            pushsword <iDataEntries
                            jsl container_vector_resize
                            bne error_exit

                            pushptr <pThis,#datalib_type_entry~data_entries
                            pushlocalptr #itr
                            jsl container_vector_front
                            bne error_exit

                            lda <wVersion
                            beq read_error
                            dec a
                            asl a
                            tax
                            jsr (reader_funcs,x)
                            bcs read_error

                            lda #0
error_exit                  sta <result
exit                        ret 2:result

null_pointer                lda #object_error_null_pointer
                            bra error_exit
read_error                  lda #file_manager_error_read_error
                            bra error_exit
unsupported_count           debugger_msg #datalib_error_msg_unsupported_size
                            lda #datalib_error_unsupported_size
                            bra error_exit

reader_funcs                dc a2'v1_loop, v2_loop'

;;;

;; Version 1 data entry
v1_loop                     anop
                            pushptr <pReader
                            pushsword #sizeof~datalib_data_entry_serialized_1
                            jsl file_reader_get_buffered_data
                            jcs v1_read_error
                            putretptr <pData
; ID
                            getword [<pData],#datalib_data_entry_serialized_1~id
                            putlonglow [<itr],#datalib_data_entry~id
                            getword [<pData],#datalib_data_entry_serialized_1~id+2
                            putlonghigh [<itr],#datalib_data_entry~id
; Copy the name
                            pushptr <itr,#datalib_data_entry~name
                            pushptr <pData,#datalib_data_entry_serialized_1~name
                            jsl string_object_copy_zt
; Offset
                            getword [<pData],#datalib_data_entry_serialized_1~offset
                            putlonglow [<itr],#datalib_data_entry~offset
                            getword [<pData],#datalib_data_entry_serialized_1~offset+2
                            putlonghigh [<itr],#datalib_data_entry~offset
; Size
                            getword [<pData],#datalib_data_entry_serialized_1~size
                            putlonglow [<itr],#datalib_data_entry~size
                            getword [<pData],#datalib_data_entry_serialized_1~size+2
                            putlonghigh [<itr],#datalib_data_entry~size
; Attach parent
                            lda <pThis
                            putptrlow [<itr],#datalib_data_entry~type_ptr
                            lda <pThis+2
                            putptrhigh [<itr],#datalib_data_entry~type_ptr
; Next
                            vector_iterator_next_test_end <itr
                            jne v1_loop
                            clc
v1_read_error               rts

;; Version 2
;; The data entry is smaller, and has meta data to string information after all the headers.

v2_loop                     anop
                            pushptr <pReader
                            pushsword #sizeof~datalib_data_entry_serialized_2
                            jsl file_reader_get_buffered_data
                            bcs v2_read_error
                            putretptr <pData
; ID
                            getword [<pData],#datalib_data_entry_serialized_2~id
                            putlonglow [<itr],#datalib_data_entry~id
                            getword [<pData],#datalib_data_entry_serialized_2~id+2
                            putlonghigh [<itr],#datalib_data_entry~id
; Offset
                            getword [<pData],#datalib_data_entry_serialized_2~offset
                            putlonglow [<itr],#datalib_data_entry~offset
                            getword [<pData],#datalib_data_entry_serialized_2~offset+2
                            putlonghigh [<itr],#datalib_data_entry~offset
; Size
                            getword [<pData],#datalib_data_entry_serialized_2~size
                            putlonglow [<itr],#datalib_data_entry~size
                            getword [<pData],#datalib_data_entry_serialized_2~size+2
                            putlonghigh [<itr],#datalib_data_entry~size
; Flags
                            getword [<pData],#datalib_data_entry_serialized_2~flags_2
                            and #datalib_data_entry_2_flags_2~compression_type
                            putword [<itr],#datalib_data_entry~compression_type

; Attach parent
                            lda <pThis
                            putptrlow [<itr],#datalib_data_entry~type_ptr
                            lda <pThis+2
                            putptrhigh [<itr],#datalib_data_entry~type_ptr
; Next
                            vector_iterator_next_test_end <itr
                            bne v2_loop
                            clc
v2_read_error               rts

                            end
