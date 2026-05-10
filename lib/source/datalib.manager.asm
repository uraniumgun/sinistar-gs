                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy 13/Ainclude/E16.Memory

                            mcopy generated/datalib.manager.macros

                            longa on
                            longi on
; --------------------------------------------------------------------------------------------
; Data Library functions
; These functions manage sets of data, divided into types and data entries for those types.
;
; The manager holds an array of libraries of data, through a descriptor structure, which
; links to a file that holds the data for the library.
;
; Libraries hold one or more type entries, and their associated data entries.
; Callers request data by type-id and data-id, which are a semi-unique identifier for a piece
; of data.  Registered libraries are searched in reverse order for the matching type/data
; pair.  This allows for overriding data entries.  It is possible for interdependent data
; entries to explicitly request data from the same library, which is the reason for the
; semi-unique nature of the type/data id pair.  The latter is usually used with TILE frames
; referenced by IMAG definitions.
;
; Primary Object Hierarchy:
; datalib_manager       - owns the master list of open descriptors
;                         queries for type/data entries search all open descriptors
; datalib_descriptor    - holds the file reference to a library's data as well as owns the pointer
;                         to the datalib_library.
; datalib_library       - contains an array of datalib_type_entry objects.
;                         queries on the types and data are only within the library itself
; datalib_type_entry    - contains an array of datalib_data_entry objects.
; datalib_translator    - a helper function table object, that is used to load/unload/reference
;                         a type of data.  It's primary function is to take the serialize data
;                         and turn it into runtime data.
;
; Most interaction is through the datalib_manager, so that data entries used by the application
; can come from any loaded file.  Some interaction is directly with the datalib_library.
; Applications usually do not have to interact with the datalib_descriptor, it is automatically
; created and destroy when opening/closing libraries through the datalib_manager.
; --------------------------------------------------------------------------------------------
; Global data section
datalib_manager_globals     data seg_flib

datalib_manager~initialized dc i'0'                                  ; Non-zero, if the manager is initialized

; Options
datalib_manager_option~keep_files_open dc i'0'                       ; if non-zero, then any libraries, added to the manager, will keep their files open.

; The vector of descriptors (pointer vector)
datalib_manager~descriptors ds sizeof~vector_definition
; The vector of registered type translators
datalib_manager~translators ds sizeof~vector_definition

; The descriptor object definition
datalib_object~descriptor   dc i'sizeof~datalib_descriptor'
                            dc a4'datalib_descriptor~vtable'

datalib_descriptor~vtable   anop
                            dc a4'datalib_descriptor_construct'
                            dc a4'0'                            ; Don't want copy or move constructor.  Maybe point to functions that will fall into the debugger?
                            dc a4'0'
                            dc a4'datalib_descriptor_destruct'

; Translator registration
datalib_translator_registration gequ 0
datalib_translator_registration~type_id gequ datalib_translator_registration
datalib_translator_registration~translator_ptr gequ datalib_translator_registration~type_id+4
sizeof~datalib_translator_registration gequ datalib_translator_registration~translator_ptr+4

; The descriptor object definition
datalib_object~translator_registration dc i'sizeof~datalib_translator_registration'
                            dc a4'0'    ; No vtable, the default bit-wise operations are fine

                            end
; --------------------------------------------------------------------------------------------
datalib_errors              data seg_flib

datalib_error_read_error    equ system_id_datalib+1
datalib_error_unsupported_size equ system_id_datalib+2
datalib_error_version       equ system_id_datalib+3
datalib_error_allocation    equ system_id_datalib+4
datalib_error_unregistered_library equ system_id_datalib+5
datalib_error_null_ptr      equ system_id_datalib+6
datalib_error_type_not_found equ system_id_datalib+7
datalib_error_data_not_found equ system_id_datalib+8
datalib_error_data_bad      equ system_id_datalib+9
datalib_error_data_load_failed equ system_id_datalib+10
datalib_error_open_error    equ system_id_datalib+11
datalib_error_type_header_read_error equ system_id_datalib+12
datalib_error_data_header_read_error equ system_id_datalib+13
datalib_error_unknown_compression equ system_id_datalib+14

datalib_manager_error_msg_initialization_failed anop
                            dw 'datalib_manager: initialization failed'
datalib_manager_error_msg_failed_to_open_library anop
                            dw 'datalib_manager: failed to open library'
datalib_manager_error_msg_unserializtion_failed anop
                            dw 'datalib_manager: failed to load library'
datalib_manager_error_msg_version anop
                            dw 'datalib_manager: library version unsupported'
datalib_error_msg_unsupported_size anop
                            dw 'datalib: unsupported size'
datalib_error_msg_reference_overflow anop
                            dw 'datalib: reference count overflow'
datalib_error_msg_reference_underflow anop
                            dw 'datalib: reference count underflow'
datalib_error_msg_load_error anop
                            dw 'datalib: failed to load data'
datalib_manager_error_msg_unregistered_library anop
                            dw 'datalib: unregistered library'
datalib_manager_error_msg_corrupt anop
                            dw 'datalib_manager: library corrupt'

; Location breadcrumbs
datalib_location_library_read equ system_id_datalib+1
datalib_location_library_tile equ system_id_datalib+2
datalib_location_library_ctil equ system_id_datalib+3
datalib_location_library_wave equ system_id_datalib+4

                            end

; --------------------------------------------------------------------------------------------
; Initialize the CYLib Manager
datalib_manager_initialize  start seg_flib
                            using datalib_manager_globals

                            debugtag 'initialize'
                            debugtag 'datalib_manager'

; Initialize the vector of descriptors
                            pushptr #datalib_manager~descriptors
                            pushptr #datalib_object~descriptor
                            jsl container_ptr_vector_construct

; Initialize the vector of type translators
                            pushptr #datalib_manager~translators
                            pushptr #datalib_object~translator_registration
                            jsl container_vector_construct
; Reserve some space.
                            pushptr #datalib_manager~translators
                            pushsword #16
                            jsl container_vector_set_capacity

; Set the options defaults
                            lda #1
                            sta >datalib_manager_option~keep_files_open

                            lda #1
                            sta >datalib_manager~initialized

exit                        anop
                            lda #0
                            rtl
                            end

; --------------------------------------------------------------------------------------------
; Initialize the CYLib Manager
datalib_manager_uninitialize  start seg_flib
                            using datalib_manager_globals

                            debugtag 'uninitialize'
                            debugtag 'datalib_manager'
                            lda >datalib_manager~initialized
                            beq exit

; Uninitialize the vector of descriptors
                            pushptr #datalib_manager~descriptors
                            jsl container_ptr_vector_destruct

; Uninitialize the vector of translators
                            pushptr #datalib_manager~translators
                            jsl container_vector_destruct

exit                        anop
                            lda #0
                            rtl
                            end

; --------------------------------------------------------------------------------------------
; Add a descriptor for a library.
; Add a library file to the library descriptor list.
; This will add the library to the top of the descriptor list which
; means it will be searched first, when fully opened
; * This will NOT open the library file.
; * This will NOT add a library more than once.
;
; This is used only to reserve a library's place in the search order,
; use datalib_manager_add_library to add a library and open it.
;
; Params:
; psoFilePath       - File path string.  Can be a partial path.  Must be a string_object
; Returns:
; The descriptor pointer or null
datalib_manager_add_descriptor    start seg_flib
                                using datalib_manager_globals
; Define our work area data
                                begin_locals
pDescriptor                     decl ptr
pLibrary                        decl ptr
work_area_size                  end_locals

                                debugtag 'add_descriptor'
                                debugtag 'datalib_manager'
                                sub (4:psoFilePath),work_area_size

                                pushptr <psoFilePath
                                jsl datalib_manager_find_descriptor_by_name
                                putretptr <pDescriptor
                                ora <pDescriptor+2
                                bne exit                                        ; Already exists, just return the pointer
; Make a new one
                                jsl datalib_descriptor_new
                                bcs allocation_error1
                                putretptr <pDescriptor
; Add an empty library.  It will not be opened yet.
                                jsl datalib_library_new
                                bcs allocation_error2
                                putretptr <pLibrary
; Put the parent descriptor link into the library.  The library will not own the pointer
                                lda <pDescriptor
                                putptrlow [<pLibrary],#datalib_library~descriptor_ptr
                                lda <pDescriptor+2
                                putptrhigh [<pLibrary],#datalib_library~descriptor_ptr
; Put the library pointer in the descriptor.  The descriptor will own the pointer
                                lda <pLibrary
                                putptrlow [<pDescriptor],#datalib_descriptor~library_ptr
                                lda <pLibrary+2
                                putptrhigh [<pDescriptor],#datalib_descriptor~library_ptr
; Put the name into an object
                                pushptr <pDescriptor,#datalib_descriptor~name
                                pushptr <psoFilePath
                                jsl string_object_copy

; Add the new descriptor pointer to the ptr_vector, it will take ownership of it.
                                pushptr #datalib_manager~descriptors
                                pushptr <pDescriptor
                                jsl container_ptr_vector_move_back

exit                            anop
                                clc
error_exit                      retkc 4:pDescriptor
allocation_error2               anop
                                pushptr <pDescriptor
                                jsl datalib_descriptor_delete
allocation_error1               anop
                                clearptr <pDescriptor
                                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Remove a descriptor for a library.
; This will delete the library and remove the descriptor from the master list.
; This is not normally called directly.  Use the datalib_manager_remove_library.
;
; Params:
; pDescriptor
;
; Returns:
; 0 or error code
datalib_manager_remove_descriptor start seg_flib
                                using datalib_manager_globals
                                using datalib_errors
; Define our work area data
                                begin_locals
result                          decl word
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

                                debugtag 'remove_descriptor'
                                debugtag 'datalib_manager'
                                sub (4:pDescriptor),work_area_size

; Find the matching descriptor in the vector and remove it
                                pushptr #datalib_manager~descriptors
                                pushlocalptr #itr
                                jsl container_ptr_vector_front
                                bne error_exit                                  ; Will return an error if empty too.  Probably should be good and check the size before calling front.

loop                            anop
; Pointers the same?
                                lda [<itr]
                                eor <pDescriptor
                                ldy #2
                                eor [<itr],y
                                eor <pDescriptor+2
                                bne skip

; Erase the entry.  This will call delete on the object
                                pushptr #datalib_manager~descriptors
                                pushlocalptr #itr
                                jsl container_ptr_vector_erase
                                bra exit

skip                            anop
                                vector_iterator_next_test_end <itr
                                bne loop

error_exit                      anop
                                debugger_msg #datalib_manager_error_msg_unregistered_library
                                lda #datalib_error_unregistered_library
exit                            sta <result
                                ret 2:result
                                end

; --------------------------------------------------------------------------------------------
; Find a descriptor by path name.
;
; Params:
; pFilePath     - File path string.  Can be a partial path
; Returns:
; The descriptor pointer or null
datalib_manager_find_descriptor_by_name start seg_flib
                                using datalib_manager_globals
; Define our work area data
                                begin_locals
result                          decl word
pName                           decl ptr
pDescriptor                     decl ptr
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

                                debugtag 'find_desc_by_name'
                                debugtag 'datalib_manager'
                                sub (4:pFilePath),work_area_size

                                testptr <pFilePath
                                jeq error_exit

                                pushptr #datalib_manager~descriptors
                                pushlocalptr #itr                               ; Note, this is a special case, where we need to push the full 'long' address of a location in out current local variable space.
                                jsl container_ptr_vector_front
                                bne error_exit                                  ; Will return an error if empty too.  Probably should be good and check the size before calling front.

loop                            anop
                                getptr [<itr],#0,<pDescriptor                   ; We are using a pointer vector, so get the descriptor pointer from the iterator.  Not checking for null, I know I am not pushing empty ones in the vector
                                getptr [<pDescriptor],#datalib_descriptor~name,<pName
                                ora <pName
                                beq skip
; Strings the same?
                                pushptr <pFilePath
                                pushptr <pName
                                jsl string_object_is_equal
                                bne skip
; Yes
                                getptr <pDescriptor,<result
                                bra exit

skip                            anop
                                vector_iterator_next <itr
                                vector_iterator_equals_end <itr
                                bne loop
                                clearptr <result
exit                            anop
                                clc
                                retkc 4:result

error_exit                      anop
                                clearptr <result
                                sec
                                retkc 4:result
                                end

; --------------------------------------------------------------------------------------------
; Get a descriptor by index
;
; Params:
; iIndex        - index of the descriptor to get.
; Returns:
; The pointer to the descriptor or null
datalib_manager_get_descriptor_by_index start seg_flib
                                using datalib_manager_globals
; Define our work area data
                                begin_locals
result                          decl ptr                                          ; result value inside our local work area
work_area_size                  end_locals

                                sub (2:iIndex),work_area_size

                                retkc 4:result
                                end


; --------------------------------------------------------------------------------------------
; Add a library file to the library descriptor list
; This will add the library to the top of the descriptor list which
; means it will be searched first.  This will also load the library
; header and, optionally, keep the library file open.
;
; This will NOT add a library more than once
;
; This will reopen and recreate a library if a library description with
; the matching name is already in the list but the library is currently
; closed.  In this case, the library will keep its current position
; in the search list.
;
; Params:
; psoFilePath       - path to the library file.  Must be a string_object (or null)
; iPreloadOptions   - pre-load options
; Returns:
; If carry flag is clear, the pointer to the library
; If carry flag is set, null
datalib_manager_add_library     start seg_flib
                                using datalib_manager_globals
                                using datalib_errors
; Define our work area data
                                begin_locals
result                          decl ptr                                           ; result value inside our local work area
pDescriptor                     decl ptr
work_area_size                  end_locals

                                debugtag 'add_library'
                                debugtag 'datalib_manager'
                                sub (4:psoFilePath,2:iPreloadOptions),work_area_size

                                testptr <psoFilePath
                                jeq null_pointer

                                pushptr <psoFilePath
                                jsl datalib_manager_add_descriptor
                                bcs null_pointer
                                putretptr <pDescriptor
; Get the library
                                getptr [<pDescriptor],#datalib_descriptor~library_ptr,<result
                                getword [<result],#datalib_library~info
                                bit #datalib_library_info~valid                         ; Is the library already unserialized?
                                bne already_unserialized
; Unserialize the library
; Open the file
                                pushptr <pDescriptor
                                jsl datalib_descriptor_open
                                bne failed_to_open

                                pushptr <result
                                jsl _datalib_library_unserialize
                                bne unserialization_error

; Do we want to keep the file open?
                                lda >datalib_manager_option~keep_files_open
                                beq close_file

; Yes, flag that the description itself, holds one of the references.
                                getword [<pDescriptor],#datalib_descriptor~info
                                ora #datalib_descriptor_info~has_file_ref
                                putword [<pDescriptor],#datalib_descriptor~info
                                bra done

close_file                      anop
                                pushptr <pDescriptor
                                jsl datalib_descriptor_close

done                            anop
already_unserialized            anop
                                clc
exit                            anop
                                retkc 4:result

failed_to_open                  anop
                                pushsword #datalib_error_open_error
                                pushptr [<psoFilePath],#string_object~str
                                jsl system_error_handle_error_with_string
null_pointer                    anop
error_exit                      anop
                                clearptr <result
                                sec
                                bra exit

unserialization_error           lda #datalib_error_data_load_failed
                                jsl system_error_handle_error

                                pushptr <pDescriptor
                                jsl datalib_manager_remove_descriptor

                                pushptr <pDescriptor
                                jsl datalib_descriptor_close

                                bra error_exit
                                end

; --------------------------------------------------------------------------------------------
; Remove a library.
; This will delete the library, by deleting its descriptor.
;
; Params:
; pLibrary          - The library pointer
;
; Returns:

datalib_manager_remove_library  start seg_flib
                                using datalib_manager_globals
                                using datalib_errors
; Define our work area data
                                begin_locals
result                          decl word
pDescriptor                     decl ptr
work_area_size                  end_locals

                                debugtag 'remove_library'
                                debugtag 'datalib_manager'
                                sub (4:pLibrary),work_area_size

                                testptr <pLibrary
                                beq null_pointer

; Just get the descriptor and remove that.
                                getptr [<pLibrary],#datalib_library~descriptor_ptr,<pDescriptor
                                ora <pDescriptor
                                beq no_descriptor

                                pushptr <pDescriptor
                                jsl datalib_manager_remove_descriptor

exit                            sta <result
                                ret 2:result

; Assume it is an unconnected library, though this really shouldn't happen.
no_descriptor                   anop
                                pushptr <pLibrary
                                jsl datalib_library_delete
                                bra exit
null_pointer                    anop
                                lda #datalib_error_null_ptr
                                bra exit
                                end
; --------------------------------------------------------------------------------------------
; Get the default translator for a type.
; Parameters:
;  hTypeID         - the type ID
; Returns:
;  Pointer to the type translator.  This will always return a valid translator.
datalib_manager_get_default_translator_for_type start seg_flib
                                using datalib_manager_globals
                                using datalib_translator_default_data

; Define our work area data
                                begin_locals
result                          decl ptr                                        ; result value inside our local work area
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

                                debugtag 'get_default_translator'
                                debugtag 'datalib_manager'
                                sub (4:hTypeID),work_area_size

; Find the type in the registration vector
                                pushptr #datalib_manager~translators
                                pushlocalptr #itr
                                jsl container_vector_front
                                bne empty                                       ; Will return an error if empty too.

loop                            anop
; type-id the same?
                                getword [<itr],#datalib_translator_registration~type_id
                                eor <hTypeID
                                ldy #datalib_translator_registration~type_id+2
                                eor [<itr],y
                                eor <hTypeID+2
                                bne skip

                                getptr [<itr],#datalib_translator_registration~translator_ptr,<result
                                bra exit

skip                            anop
                                vector_iterator_next_test_end <itr
                                bne loop
; Not in, use the default
empty                           lda #datalib_translator_default
                                sta <result
                                lda #^datalib_translator_default
                                sta <result+2

exit                            clc
                                retkc 4:result

                                end

; --------------------------------------------------------------------------------------------
; Register a translator for a type.
; If the type is already regististered, this will replace that type's translator.
; Pass in a nullptr for the translator to remove the type translator.
;
; Parameters:
;  hTypeID         - the type ID
;  pTranslator     - the translator defintion.  Note it is assumed that this is a fixed pointer
;                    this function does not make a copy of the translator, and just stores the input pointer.
; Returns:
;  0 or error code
datalib_manager_set_default_translator_for_type start seg_flib
                                using datalib_manager_globals
                                using datalib_translator_default_data

; Define our work area data
                                begin_locals
result                          decl word
itr                             decl sizeof~vector_iterator
new_entry                       decl sizeof~datalib_translator_registration
work_area_size                  end_locals

                                debugtag 'set_default_translator'
                                debugtag 'datalib_manager'
                                sub (4:hTypeID,4:pTranslator),work_area_size

; See if the translator is already in the list
                                pushptr #datalib_manager~translators
                                pushlocalptr #itr
                                jsl container_vector_front
                                bne add_new                                  ; Will return an error if empty too.

loop                            anop
; type-id the same?
                                getword [<itr],#datalib_translator_registration~type_id
                                eor <hTypeID
                                ldy #datalib_translator_registration~type_id+2
                                eor [<itr],y
                                eor <hTypeID+2
                                bne skip

; Already in, just replace the entry's pointer, or if the new pointer is null, remove it.
                                testptr <pTranslator
                                beq remove

                                lda <pTranslator
                                putptrlow [<itr],#datalib_translator_registration~translator_ptr
                                lda <pTranslator+2
                                putptrhigh [<itr],#datalib_translator_registration~translator_ptr
                                bra exit

remove                          anop
                                pushptr #datalib_manager~translators
                                pushlocalptr #itr
                                jsl container_vector_erase
                                bra exit

skip                            anop
                                vector_iterator_next_test_end <itr
                                bne loop
; Not in.  Add it.
add_new                         testptr <pTranslator
                                beq exit

                                lda <hTypeID
                                sta <new_entry+datalib_translator_registration~type_id
                                lda <hTypeID+2
                                sta <new_entry+datalib_translator_registration~type_id+2
                                lda <pTranslator
                                sta <new_entry+datalib_translator_registration~translator_ptr
                                lda <pTranslator+2
                                sta <new_entry+datalib_translator_registration~translator_ptr+2

                                pushptr #datalib_manager~translators
                                pushlocalptr #new_entry
                                jsl container_vector_copy_back

exit                            stz <result
                                clc
                                retkc 2:result

                                end

; --------------------------------------------------------------------------------------------
; Get a data entry with the specified type-id/data-id
; This will search all open libraries for the data.
; Use this function if you need to have the data entry returned, else use datalib_manager_get_data_ptr
; if you just need the data pointer.
; Using this function is primarily for when you will need additional related data the requires
; knowing what library the data came from.
;
; Parameters:
;  hTypeID          - the type ID
;  hDataID          - the data ID
;  wLoadOptions     - load options for the data.
;
; Returns:
;  if carry clear, the data_entry pointer in A/X
;  if carry set, the error code in A
datalib_manager_get_data_entry  start seg_flib
                                using datalib_manager_globals
                                using datalib_errors

                                begin_locals
result                          decl ptr
wLibraryCount                   decl word
pDescriptor                     decl ptr
pLibrary                        decl ptr
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

                                debugtag 'get_data_entry'
                                debugtag 'datalib_manager'
                                sub (4:hTypeID,4:hDataID,2:wLoadOptions),work_area_size

                                clearptr <result

                                lda >datalib_manager~descriptors+vector_definition~size
                                jeq error_exit
                                sta <wLibraryCount

                                pushptr #datalib_manager~descriptors
                                pushlocalptr #itr
                                jsl container_ptr_vector_back                   ; We search backward.
                                bne error_exit

loop                            anop
                                getptr [<itr],#0,<pDescriptor                   ; We are using a pointer vector, so get the descriptor pointer from the iterator.  Not checking for null, I know I am not pushing empty ones in the vector
                                getptr [<pDescriptor],#datalib_descriptor~library_ptr,<pLibrary
                                ora <pLibrary
                                beq skip

                                pushptr <pLibrary
                                pushptr <hTypeID                                        ; pushdword
                                pushptr <hDataID                                        ; pushdword
                                jsl datalib_library_find_data_entry
                                bcc found

skip                            ptr_vector_data_ptr_prev <itr
                                dec <wLibraryCount
                                bne loop
                                bra error_exit
; Do any load request
found                           putretptr <result
                                pushretptr
                                pushsword <wLoadOptions
                                jsl _datalib_library_get_data_entry_data_ptr
                                clc
exit                            retkc 4:result
error_exit                      sec
; Do I really want to have the error code in A?  Maybe a 'last error' global for the datalib_manager is better.
                                lda #datalib_error_data_not_found
                                sta <result
                                bra exit

                                end

; --------------------------------------------------------------------------------------------
; Get the data pointer for specified type-id/data-id
; This will search all open libraries for the data.
;
; Parameters:
;  hTypeID          - the type ID
;  hDataID          - the data ID
;  wLoadOptions     - load options for the data.
;
; Returns:
;  if carry clear, the data_entry pointer in A/X
;  if carry set, the error code in A
datalib_manager_get_data_ptr    start seg_flib
                                using datalib_manager_globals
                                using datalib_errors

                                begin_locals
result                          decl ptr
wLibraryCount                   decl word
pDescriptor                     decl ptr
pLibrary                        decl ptr
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

                                debugtag 'get_data_entry'
                                debugtag 'datalib_manager'
                                sub (4:hTypeID,4:hDataID,2:wLoadOptions),work_area_size

                                clearptr <result

                                lda >datalib_manager~descriptors+vector_definition~size
                                jeq error_exit
                                sta <wLibraryCount

                                pushptr #datalib_manager~descriptors
                                pushlocalptr #itr
                                jsl container_ptr_vector_back                   ; We search backward.
                                bne error_exit

loop                            anop
                                getptr [<itr],#0,<pDescriptor                   ; We are using a pointer vector, so get the descriptor pointer from the iterator.  Not checking for null, I know I am not pushing empty ones in the vector
                                getptr [<pDescriptor],#datalib_descriptor~library_ptr,<pLibrary
                                ora <pLibrary
                                beq skip

                                pushptr <pLibrary
                                pushptr <hTypeID                                        ; pushdword
                                pushptr <hDataID                                        ; pushdword
                                jsl datalib_library_find_data_entry
                                bcc found

skip                            ptr_vector_data_ptr_prev <itr
                                dec <wLibraryCount
                                bne loop
                                bra error_exit
; Do any load request
found                           pushretptr
                                pushsword <wLoadOptions
                                jsl _datalib_library_get_data_entry_data_ptr
                                bcs load_error
                                putretptr <result
                                clc
exit                            retkc 4:result
error_exit                      sec
; Do I really want to have the error code in A?  Maybe a 'last error' global for the datalib_manager is better.
                                lda #datalib_error_data_not_found
                                sta <result
                                bra exit
load_error                      lda #datalib_error_data_load_failed
                                sta <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Find the datalib entry, for a specified type-id/data-id
; This will search all open libraries for the data.
;
; Parameters:
;  hTypeID          - the type ID
;  hDataID          - the data ID
;
; Returns:
;  if carry clear, the datalib_data_entry pointer will be in A/X
;  if carry set, the error code in A
datalib_manager_find_data_entry start seg_flib
                                using datalib_manager_globals
                                using datalib_errors

                                begin_locals
result                          decl ptr
wLibraryCount                   decl word
pDescriptor                     decl ptr
pLibrary                        decl ptr
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

                                debugtag 'find_data_entry'
                                debugtag 'datalib_manager'
                                sub (4:hTypeID,4:hDataID),work_area_size

                                clearptr <result

                                lda >datalib_manager~descriptors+vector_definition~size
                                jeq error_exit
                                sta <wLibraryCount

                                pushptr #datalib_manager~descriptors
                                pushlocalptr #itr
                                jsl container_ptr_vector_back                   ; We search backward.
                                bne error_exit

loop                            anop
                                getptr [<itr],#0,<pDescriptor                   ; We are using a pointer vector, so get the descriptor pointer from the iterator.  Not checking for null, I know I am not pushing empty ones in the vector
                                getptr [<pDescriptor],#datalib_descriptor~library_ptr,<pLibrary
                                ora <pLibrary
                                beq skip

                                pushptr <pLibrary
                                pushptr <hTypeID                                        ; pushdword
                                pushptr <hDataID                                        ; pushdword
                                jsl datalib_library_find_data_entry
                                bcc found

skip                            ptr_vector_data_ptr_prev <itr
                                dec <wLibraryCount
                                bne loop
                                bra error_exit
;
found                           putretptr <result
                                clc
exit                            retkc 4:result
error_exit                      sec
; Do I really want to have the error code in A?  Maybe a 'last error' global for the datalib_manager is better.
                                lda #datalib_error_data_not_found
                                sta <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Return the nth data ID of a type ID
; This will search all open libraries for the data.
;
; Parameters:
;  hTypeID          - the type ID
;  wIndex           - the index
;
; Returns:
;  if carry clear, the data ID in A/X
;  if carry set, the error code in A
datalib_manager_get_type_data_id_by_index start seg_flib
                                using datalib_manager_globals
                                using datalib_errors

                                begin_locals
result                          decl ptr
wLibraryCount                   decl word
pDescriptor                     decl ptr
pLibrary                        decl ptr
pTypeEntry                      decl ptr
pDataEntry                      decl ptr
itr                             decl sizeof~vector_iterator
work_area_size                  end_locals

; This function does a pretty bute-force search.  If this is going to be something that is called a lot,
; the manager should keep a runtime array.

                                debugtag 'get_type_data_id_by_index'
                                debugtag 'datalib_manager'
                                sub (4:hTypeID,2:wIndex),work_area_size

                                clearptr <result

                                lda >datalib_manager~descriptors+vector_definition~size
                                jeq error_exit
                                sta <wLibraryCount

                                pushptr #datalib_manager~descriptors
                                pushlocalptr #itr
                                jsl container_ptr_vector_back                   ; We search backward.
                                jne error_exit

loop                            anop
                                getptr [<itr],#0,<pDescriptor                   ; We are using a pointer vector, so get the descriptor pointer from the iterator.  Not checking for null, I know I am not pushing empty ones in the vector
                                getptr [<pDescriptor],#datalib_descriptor~library_ptr,<pLibrary
                                ora <pLibrary
                                beq skip

                                pushptr <pLibrary
                                pushptr <hTypeID                                        ; pushdword
                                jsl datalib_library_find_type_entry
                                bcc found_type

skip                            ptr_vector_data_ptr_prev <itr
                                dec <wLibraryCount
                                bne loop
                                bra error_exit

found_type                      putretptr <pTypeEntry
                                getword [<pTypeEntry],#datalib_type_entry~data_entries+vector_definition~size
                                cmp <wIndex
                                bge found_index
; It's not in this library
                                eor #$FFFF                                      ; negate
                                sec                                             ; add an extra to complete the negate
                                adc <wIndex                                     ; add to the index
                                sta <wIndex
                                bra skip

found_index                     anop
                                pushptr <pTypeEntry,#datalib_type_entry~data_entries
                                pushsword <wIndex
                                jsl container_vector_data_at
                                bcs error_exit                                  ; Shouldn't happen, but.
                                putretptr <pDataEntry
                                getptr [<pDataEntry],#datalib_data_entry~id,<result
                                clc
exit                            retkc 4:result
error_exit                      sec
; Do I really want to have the error code in A?  Maybe a 'last error' global for the datalib_manager is better.
                                lda #datalib_error_data_not_found
                                sta <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Get an array of data IDs for a type ID
; This will search all open libraries for the data.
;
; This function does a pretty bute-force search.  If this is going to be something that is called a lot,
; the manager should keep a runtime array.
;
; Parameters:
;  hTypeID          - the type ID
;  pVector          - pointer to a container_vector of longs
;
; Returns:
;  if carry clear, the number of entries found in a
;  if carry set, an error occured
datalib_manager_get_type_data_ids start seg_flib
                                using datalib_manager_globals
                                using datalib_errors

                                begin_locals
result                          decl word
wLibraryCount                   decl word
pDescriptor                     decl ptr
pLibrary                        decl ptr
pTypeEntry                      decl ptr
pDataEntry                      decl ptr
hID                             decl long
libItr                          decl sizeof~vector_iterator
typeItr                         decl sizeof~vector_iterator
work_area_size                  end_locals

                                debugtag 'get_type_data_ids'
                                debugtag 'datalib_manager'
                                sub (4:hTypeID,4:pVector),work_area_size

                                lda >datalib_manager~descriptors+vector_definition~size
                                jeq error_exit
                                sta <wLibraryCount

                                pushptr #datalib_manager~descriptors
                                pushlocalptr #libItr
                                jsl container_ptr_vector_back                           ; We search backward.
                                jne error_exit

library_loop                    anop
                                getptr [<libItr],#0,<pDescriptor                        ; We are using a pointer vector, so get the descriptor pointer from the iterator.  Not checking for null, I know I am not pushing empty ones in the vector
                                getptr [<pDescriptor],#datalib_descriptor~library_ptr,<pLibrary
                                ora <pLibrary
                                beq skip_library

                                pushptr <pLibrary
                                pushptr <hTypeID                                        ; pushdword
                                jsl datalib_library_find_type_entry
                                bcc found_type

skip_library                    ptr_vector_data_ptr_prev <libItr
                                dec <wLibraryCount
                                bne library_loop
                                bra done

found_type                      putretptr <pTypeEntry

                                pushptr <pTypeEntry,#datalib_type_entry~data_entries
                                pushlocalptr #typeItr
                                jsl container_ptr_vector_front
                                bne skip_library

data_entry_loop                 getptr [<typeItr],#datalib_data_entry~id,<hID
                                pushptr <pVector
                                pushptr <hID
                                jsl container_dword_vector_push_back_unique
                                vector_iterator_next_test_end <typeItr
                                bne data_entry_loop
                                bra skip_library

done                            getword [<pVector],#vector_definition~size
                                sta <result
                                clc
exit                            retkc 4:result
error_exit                      sec
                                stz <result
                                bra exit
                                end
