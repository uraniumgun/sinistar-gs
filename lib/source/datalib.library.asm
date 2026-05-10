                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy 13/Ainclude/E16.Memory

                            mcopy generated/datalib.library.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
datalib_library_data        data seg_flib

datalib_library             dc i2'sizeof~datalib_library'
                            dc a4'datalib_library~vtable'

datalib_library~vtable      dc a4'datalib_library_construct'
                            dc a4'0'    ; copy
                            dc a4'0'    ; move
                            dc a4'datalib_library_destruct'
                            end

; --------------------------------------------------------------------------------------------
; Construct a datalub_library at the supplied address
;
; Parameters:
; pThis         - pointer to a datalib_library
; Returns:
; 0 or error code.
datalib_library_construct   start seg_flib
                            using datalib_type_entry_data

; Define our work area data
                            begin_locals
result                      decl word                                          ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'construct'
                            debugtag 'datalib_library'
                            sub (4:pThis),work_area_size

                            lda #0
                            putlong [<pThis],#datalib_library~id
                            putlong [<pThis],#datalib_library~format_id
                            putword [<pThis],#datalib_library~info
                            putptr [<pThis],#datalib_library~descriptor_ptr

                            pushptr <pThis,#datalib_library~type_entries
                            pushptr #datalib_type_entry
                            jsl container_ptr_vector_construct

                            stz <result

                            ret 2:result

                            end

; --------------------------------------------------------------------------------------------
; Destruct a datalub_library
;
; Parameters:
; pThis         - pointer to a datalib_library
; Returns:
; 0 or error code.
datalib_library_destruct    start seg_flib
                            using datalib_type_entry_data

; Define our work area data
                            begin_locals
result                      decl word                                          ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'destruct'
                            debugtag 'datalib_library'
                            sub (4:pThis),work_area_size

                            pushptr <pThis,#datalib_library~type_entries
                            jsl container_ptr_vector_destruct

                            stz <result
                            ret 2:result

                            end

; --------------------------------------------------------------------------------------------
; Allocate a new datalib_library object.
;
; Parameters: none
; Returns:
; if carry clear, the library(will not be null)
; if carry set, null
datalib_library_new         start seg_flib
; Define our work area data
                            begin_locals
result                      decl ptr                                          ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'new'
                            debugtag 'datalib_library'
                            sub ,work_area_size

                            pushsword #sizeof~datalib_library
                            jsl sba_alloc
                            bcs allocation_error
                            sta <result
                            stx <result+2

                            phx
                            pha
                            jsl datalib_library_construct
                            clc                                             ; no error
exit                        retkc 4:result
allocation_error            anop
                            clearptr <result
                            sec                                             ; error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Deallocate a new datalib_library object.
;
; Parameters:
; pThis     - pointer to a datalib_library
; Returns: nothing
datalib_library_delete      start seg_flib
; Define our work area data
                            begin_locals
result                      decl word
work_area_size              end_locals

                            debugtag 'delete'
                            debugtag 'datalib_library'
                            sub (4:pThis),work_area_size

                            stz <result
                            testptr <pThis
                            beq exit

                            pushptr <pThis
                            jsl datalib_library_destruct
                            beq next
                            sta <result

next                        pushptr <pThis
                            jsl sba_free
                            beq exit
                            sta <result

exit                        ret 2:result
                            end

; --------------------------------------------------------------------------------------------
; Find a type entry.
;
; Parameters:
; hTypeID                   - The type ID
; Returns:
; if carry is clear, the type entry pointer
; if carry is set, null.
datalib_library_find_type_entry start seg_flib
                            using datalib_errors

                            begin_locals
pTypeEntry                  decl ptr
pTypeEntries                decl ptr
pTypesPtrArray              decl ptr
iTypeEntryCount             decl word
work_area_size              end_locals

                            debugtag 'find_type_entry'
                            debugtag 'datalib_library'
                            sub (4:pThis,4:hTypeID),work_area_size

                            getptr <pThis,#datalib_library~type_entries,<pTypeEntries       ; Going to need this more than once, to store it
                            getword [<pTypeEntries],#vector_definition~size                 ; the type count
                            beq empty
                            sta <iTypeEntryCount
; Linear search through the vector.  Sad.  Usually not too many types though.
; Since this is a pointer vector, I'm going to iterate through the buffer directly.
                            pushptr <pTypeEntries
                            jsl container_ptr_vector_data
                            putretptr <pTypesPtrArray

loop                        getptr [<pTypesPtrArray],#0,<pTypeEntry
                            getword [<pTypeEntry],#datalib_type_entry~id
                            cmp <hTypeID
                            bne nope
                            getword [<pTypeEntry],#datalib_type_entry~id+2
                            cmp <hTypeID+2
                            beq found

nope                        ptr_vector_data_ptr_next <pTypesPtrArray

                            dec <iTypeEntryCount
                            bne loop
                            bra not_found

found                       clc                                         ; Signal the pointer is valid
exit                        retkc 4:pTypeEntry
empty                       anop
not_found                   anop
                            sec                                         ; Signal the pointer is null
                            clearptr <pTypeEntry
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Find a data entry.
; The data in the entry may not be loaded.
;
; Parameters:
; pThis                     - the library
; hTypeID                   - the type ID
; hDataID                   - the data id
; Returns:
; if carry is clear, the data entry pointer
; if carry is set, null.
datalib_library_find_data_entry start seg_flib
                            using datalib_errors

                            begin_locals
pDataEntry                  decl ptr
work_area_size              end_locals

                            debugtag 'find_data_entry'
                            debugtag 'datalib_library'
                            sub (4:pThis,4:hTypeID,4:hDataID),work_area_size

                            pushptr <pThis
                            pushptr <hTypeID                            ; pushdword
                            jsl datalib_library_find_type_entry
                            bcs not_found
                            pushretptr                                  ; push the found type pointer
                            pushptr <hDataID                            ; pushdword
                            jsl datalib_type_entry_find_data_entry
                            bcs not_found
                            putretptr <pDataEntry
                            clc                                         ; Signal the pointer is valid
error_exit                  retkc 4:pDataEntry
not_found                   clearptr <pDataEntry                        ; carry should already be set when we get here
                            bra error_exit

                            end

; --------------------------------------------------------------------------------------------
; Get the data entry's data.
; This will load the data if it is not already.
; Should this be just an internal function?
; It doesn't have 'this' passed in, as the data entry can get its parent type, and library.
; Should this be a data_entry function then?  I really don't like to have leaf-nodes doing
; high-level work.  Maybe put this in the manager section?
;
; Parameters:
; pDataEntry                - The data entry to get the data from.
; wOptions                  - Options for getting the data
; Returns:
; if carry is clear, the data entry pointer
; if carry is set, null.
_datalib_library_get_data_entry_data_ptr start seg_flib
                            using datalib_errors

                            begin_locals
pData                       decl ptr
work_area_size              end_locals

                            debugtag 'get_data_entry_data_ptr'
                            debugtag 'datalib_library'
                            sub (4:pDataEntry,2:wOptions),work_area_size

                            testptr <pDataEntry
                            beq null_pointer

                            getptr [<pDataEntry],#datalib_data_entry~data_ptr,<pData
                            ora <pData
                            bne loaded

                            pushptr <pDataEntry
                            pushsword <wOptions
                            jsl _datalib_library_load_data_entry
                            bne load_error
; Put the data pointer into the return value
                            getptr [<pDataEntry],#datalib_data_entry~data_ptr,<pData

loaded                      lda <wOptions
                            bit #datalib_load_options~reference
                            beq no_reference
; For the moment, I'm just going to assume the reference count will be in the lower word
                            ldy #datalib_data_entry~ref_count
                            lda [<pDataEntry],y
                            inc a
                            sta [<pDataEntry],y
                            beq reference_overflow
no_reference                anop
                            clc
error_exit                  retkc 4:pData

null_pointer                anop
                            clearptr <pData
                            sec
                            bra error_exit
load_error                  anop
                            debugger_msg #datalib_error_msg_load_error
                            clearptr <pData
                            sec
                            bra error_exit
reference_overflow          anop
                            debugger_msg #datalib_error_msg_reference_overflow
                            bra no_reference
                            end

; --------------------------------------------------------------------------------------------
; Release the data for a data entry.
; This will decrement the reference count and will only delete the data if it goes to 0
;
; Parameters:
; pDataEntry                - The data entry to get the data from.
; wOptions                  - see datalib_unload_options
; Returns:
; if carry is clear, on success.
_datalib_library_release_data_entry_data_ptr start seg_flib
                            using datalib_errors

                            begin_locals
work_area_size              end_locals

                            debugtag 'release_data_entry_data_ptr'
                            debugtag 'datalib_library'

                            sub (4:pDataEntry,2:wOptions),work_area_size

                            testptr <pDataEntry
                            beq null_pointer

                            getword [<pDataEntry],#datalib_data_entry~data_ptr+1
                            beq not_loaded

; Only doing the lower word of the reference count.  Do we need a full 32-bits?
                            getword [<pDataEntry],#datalib_data_entry~ref_count
                            beq unload
                            dec a
                            putword [<pDataEntry],#same
                            bne not_loaded

unload                      pushptr <pDataEntry
;                           pushsword <wOptions
                            jsl _datalib_library_unload_data_entry

not_loaded                  clc
error_exit                  retkc

null_pointer                anop
                            sec
                            bra error_exit
                            end

; --------------------------------------------------------------------------------------------
; Get a pointer to a data entry's data.
;
; Parameters:
; pThis                     - the library
; hTypeID                   - The type ID
; hDataID                   - The data id
; wOptions                  - Options for getting the data, see datalib_load_options
; Returns:
; if carry is clear, the data entry pointer
; if carry is set, null.
datalib_library_get_data_ptr start seg_flib
                            using datalib_errors

                            begin_locals
pData                       decl ptr
work_area_size              end_locals

                            debugtag 'get_data_ptr'
                            debugtag 'datalib_library'
                            sub (4:pThis,4:hTypeID,4:hDataID,2:wOptions),work_area_size

                            pushptr <pThis
                            pushptr <hTypeID                                        ; pushdword
                            pushptr <hDataID                                        ; pushdword
                            jsl datalib_library_find_data_entry
                            bcs search_error
                            pushretptr
                            pushsword <wOptions
                            jsl _datalib_library_get_data_entry_data_ptr
                            putretptr <pData

error_exit                  retkc 4:pData
search_error                anop
                            clearptr <pData
                            sec
                            bra error_exit
                            end

; --------------------------------------------------------------------------------------------
; Release a data entry's data.  This will decrement a reference on the data entry
; and if it is 0, it will be unloaded
;
; Parameters:
; pThis                     - the library
; hTypeID                   - The type ID
; hDataID                   - The data id
; wOptions                  - Options for getting the data, see datalib_unload_options
; Returns:
; if carry is clear on success.
datalib_library_release_data_ptr start seg_flib
                            using datalib_errors

                            begin_locals
work_area_size              end_locals

                            debugtag 'release_data_ptr'
                            debugtag 'datalib_library'
                            sub (4:pThis,4:hTypeID,4:hDataID,2:wOptions),work_area_size

                            pushptr <pThis
                            pushdword <hTypeID
                            pushdword <hDataID
                            jsl datalib_library_find_data_entry
                            bcs search_error
                            pushretptr
                            pushsword <wOptions
                            jsl _datalib_library_release_data_entry_data_ptr

search_error                anop
                            retkc
                            end

; --------------------------------------------------------------------------------------------
; Load the data for a data entry
; This is an internal function, and some error checking is assumed to be done by the caller.
; This relies on the type data translator that is registered for the type, to do the load.
;
; Parameters:
; pDataEntry                - the data entry to load the data for.
; wOptions                  - Options for getting the data
; Returns:
; 0 or error code
_datalib_library_load_data_entry start seg_flib
                            using datalib_errors

                            begin_locals
result                      decl word
pTypeEntry                  decl ptr
pTypeTranslator             decl ptr
pFunc                       decl ptr
work_area_size              end_locals

                            debugtag 'load_data_entry'
                            debugtag 'datalib_library'
                            sub (4:pDataEntry,2:wOptions),work_area_size
; Not checking for null
; Not checking to see if there is already a data pointer
; Assuming the data entry has a type and it is valid
                            getptr [<pDataEntry],#datalib_data_entry~type_ptr,<pTypeEntry
                            getptr [<pTypeEntry],#datalib_type_entry~translator_ptr,<pTypeTranslator
                            getptr [<pTypeTranslator],#datalib_translator_load,<pFunc

                            lda <pFunc
                            sta >patch_func+1
                            shortm
                            lda <pFunc+2
                            sta >patch_func+3
                            longm

                            pushptr <pTypeEntry
                            pushptr <pDataEntry
                            pushsword <wOptions
patch_func                  jsl >$000000

                            sta <result
                            ret 2:result
                            end

; --------------------------------------------------------------------------------------------
; Unload the data for a data entry.
; This is an internal function, and some error checking is assumed to be done by the caller.
; This relies on the type data translator that is registered for the type, to do the load.
; This does not check the reference count, it will always unload
;
; Parameters:
; pDataEntry                - the data entry to load the data for.
; Returns:
; 0 or error code
_datalib_library_unload_data_entry start seg_flib
                            using datalib_errors

                            begin_locals
result                      decl word
pTypeEntry                  decl ptr
pTypeTranslator             decl ptr
pFunc                       decl ptr
work_area_size              end_locals

                            debugtag 'unload_data_entry'
                            debugtag 'datalib_library'
                            sub (4:pDataEntry),work_area_size

                            stz <result
; Not checking for null
; Assuming the data entry has a type and it is valid
; We will early out if the data_ptr is null already.
                            testptr [<pDataEntry],#datalib_data_entry~data_ptr
                            beq null_data_ptr

                            getptr [<pDataEntry],#datalib_data_entry~type_ptr,<pTypeEntry
                            getptr [<pTypeEntry],#datalib_type_entry~translator_ptr,<pTypeTranslator
                            getptr [<pTypeTranslator],#datalib_translator_unload,<pFunc

                            lda <pFunc
                            sta >patch_func+1
                            shortm
                            lda <pFunc+2
                            sta >patch_func+3
                            longm

                            pushptr <pTypeEntry
                            pushptr <pDataEntry
patch_func                  jsl >$000000
                            sta <result
; Note, we are assuming that the translator cleared the data_ptr in the data entry

null_data_ptr               anop
                            ret 2:result
                            end

; --------------------------------------------------------------------------------------------
; Unserialize the library
; This will unserialize the type definitions and the associated data definitions.
; It will not unserialize the data from the data definitions.
;
; Parameters:
; pThis     - pointer to a datalib_library
; Returns: nothing
_datalib_library_unserialize start seg_flib
                            using datalib_errors
                            using object_errors
; Define our work area data
                            begin_locals
result                      decl word
pDescriptor                 decl ptr
pReader                     decl ptr
pData                       decl ptr
pTypeEntries                decl ptr
pTypeEntry                  decl ptr
pTypesPtrArray              decl ptr
iVersionLow                 decl word
iVersionHigh                decl word
iTypeEntryCount             decl word
wReaderVersion              decl word
work_area_size              end_locals

                            debugtag 'unserialize'
                            debugtag 'datalib_library'
                            sub (4:pThis),work_area_size

                            clearptr <pReader

                            testptr <pThis
                            jeq null_pointer
; Get the library's datalib_descriptor
                            getptr [<pThis],#datalib_library~descriptor_ptr,<pDescriptor
; Get the datalib_descriptor's embedded file_descriptor and use that to make a file_reader.
                            pushptr <pDescriptor,#datalib_descriptor~file_desc
                            jsl file_reader_new_with_desc
                            jcs reader_alloc_error
                            putretptr <pReader
; TODO: Set the file_reader's 'mark'

; Ask the file read to buffer an amount of data, and return a pointer to it.
                            pushptr <pReader
                            pushsword #sizeof~datalib_header_serialized
                            jsl file_reader_get_buffered_data
                            jcs data_error
                            putretptr <pData
; Some parts of the serialized header is at the same offset as the runtime, so we will make some assumptions, so we don't load Y with the same value
;
                            getword [<pData],#datalib_header_serialized~lib_id
                            sta [<pThis]
                            getword [<pData],#datalib_header_serialized~lib_id+2
                            sta [<pThis],y
;
                            getword [<pData],#datalib_header_serialized~format_id
                            sta [<pThis],y
                            getword [<pData],#datalib_header_serialized~format_id+2
                            sta [<pThis],y
; Get the version, which is a 32-bit value, major version in the top
                            getword [<pData],#datalib_header_serialized~version+2
                            cmp #^datalib_header_version_1_1
                            jne version_error
; Minor version in the bottom.  We support 1 or 2
                            getword [<pData],#datalib_header_serialized~version
                            cmp #datalib_header_version_1_1
                            beq ok_version
                            cmp #datalib_header_version_1_2
                            jne version_error
ok_version                  sta <wReaderVersion
; Most values are longs, but we are not expecting the value to contain more that what would be in a word
                            getword [<pData],#datalib_header_serialized~type_entry_count
                            sta <iTypeEntryCount
                            jeq empty
                            getword [<pData],#datalib_header_serialized~type_entry_count+2
                            jne unsupported_size_error                                          ; Not supporting >64k of types (this isn't a thing, even on the PC)
; Reserve space in the type's array
                            getptr <pThis,#datalib_library~type_entries,<pTypeEntries        ; Going to need this more than once, to store it

                            pushptr <pTypeEntries
                            pushsword <iTypeEntryCount
                            jsl container_ptr_vector_set_capacity
                            jne type_alloc_error

type_read_loop              anop
; Allocate a new type entry
                            jsl datalib_type_entry_new
                            jcs type_alloc_error
                            putretptr <pTypeEntry

                            pushptr <pTypeEntry
                            pushptr <pReader
                            jsl _datalib_type_entry_unserialize
                            jne type_unserialize_error
; Attach the parent library reference
                            lda <pThis
                            putptrlow [<pTypeEntry],#datalib_type_entry~library_ptr
                            lda <pThis+2
                            putptrhigh [<pTypeEntry],#datalib_type_entry~library_ptr

                            pushptr <pTypeEntries
                            pushptr <pTypeEntry
                            jsl container_ptr_vector_move_back

                            dec <iTypeEntryCount
                            bne type_read_loop

; We should now be up to where we read the data entries for the types.
; Would be nice to validate the read position...
                            getword [<pTypeEntries],#vector_definition~size      ; Re-get the type count
                            sta <iTypeEntryCount
; Since this is a pointer vector, I'm going to iterate through the buffer directly.  Probably should make some support macros for this type of iteration.
                            pushptr <pTypeEntries
                            jsl container_ptr_vector_data
                            putretptr <pTypesPtrArray

data_entry_read_loop        anop
                            pushptr [<pTypesPtrArray],#0
                            pushptr <pReader
                            pushsword <wReaderVersion
                            jsl _datalib_type_entry_unserialize_data_entries
                            bne data_entry_unserialize_error

                            ptr_vector_data_ptr_next <pTypesPtrArray

                            dec <iTypeEntryCount
                            bne data_entry_read_loop

empty                       anop
                            lda #0
reader_alloc_error          anop
type_alloc_error            anop
exit                        anop
                            sta <result
; Cleanup
                            pushptr <pReader
                            jsl file_reader_delete
                            ret 2:result

null_pointer                lda #object_error_null_pointer
                            bra error_exit
data_error                  anop
                            lda #datalib_error_data_bad
                            bra error_exit
version_error               anop
                            lda #datalib_error_version
                            bra error_exit
type_unserialize_error      anop
; delete the allocated entry that failed to unserialize
                            pushptr <pTypeEntry
                            jsl datalib_type_entry_delete
                            lda #datalib_error_type_header_read_error
                            bra error_exit
data_entry_unserialize_error anop
                            lda #datalib_error_data_header_read_error
                            bra error_exit
unsupported_size_error      lda #datalib_error_unsupported_size
;                           bra error_exit

error_exit                  anop
                            jsl system_error_handle_error
                            bra exit

                            end
