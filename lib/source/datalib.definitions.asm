; Test for needed globals.
  AIF  C:sizeof~string_object,.past
  ERR 'Must include string.definitions before this file'
.past
  AIF  C:sizeof~vector_definition,.past
  ERR 'Must include container.definitions before this file'
.past
  AIF  C:sizeof~file_descriptor,.past
  ERR 'Must include file.definitions before this file'
.past

; Definitions for the various CYLib structures, both in serialized for and in-memory
;
; This requires the container.definitions.asm to be included before this file
;
; Any simple constants for the datalib, especially ones that are 'user' facing, should be in datalib.constants.asm

datalib_header_version_1_1              gequ $00010001                                            ; We can read version 1.1
datalib_header_version_1_2              gequ $00010002                                            ; or version 1.2

datalib_header_serialized~lib_id        gequ 0                                                    ; ID of library, always cyLIB (CYLB)
datalib_header_serialized~format_id     gequ datalib_header_serialized~lib_id+4                   ; Machine ID format, almost always cyfPC (PC  ). Essentially stating that the data is little-endian
datalib_header_serialized~version       gequ datalib_header_serialized~format_id+4                ; Version # of library format
datalib_header_serialized~type_entry_count gequ datalib_header_serialized~version+4               ; Number of type entries in the library
datalib_header_serialized~data_header_size gequ datalib_header_serialized~type_entry_count+4      ; Size of all the individual 'data' headers.  This does not include the size of the type entries.
sizeof~datalib_header_serialized        gequ datalib_header_serialized~data_header_size+4         ; Size of the serialized header
; Following the above header, the array of types are written out

datalib_type_serialized~id              gequ 0                                                    ; The type's ID
datalib_type_serialized~offset          gequ datalib_type_serialized~id+4                         ; The offset in the read stream, from the start, for this type's data entries
sizeof~datalib_type_serialized          gequ datalib_type_serialized~offset+4

; Following the array of serialized types, the array of all the data entries are written out

; There is a header for a set of data entries for the type
datalib_data_entries_header_serialized~count gequ 0                                               ; Number of data entries for the type
datalib_data_entries_header_serialized~info gequ datalib_data_entries_header_serialized~count+4   ; Info bits
sizeof~datalib_data_entries_header_serialized gequ datalib_data_entries_header_serialized~info+4

; Then an array of data entries, where the count is from the previously read header.
; This is the version 1 data entry, with the embeded 15 character name.  There is a version 2, which had the strings separate
datalib_data_entry_serialized_1~id      gequ 0                                                  ; ID of the data entry
datalib_data_entry_serialized_1~name    gequ datalib_data_entry_serialized_1~id+4               ; Optional 15 character, null terminated, name
datalib_data_entry_serialized_1~offset  gequ datalib_data_entry_serialized_1~name+16            ; Offset, from the stream start, to the data for this entry
datalib_data_entry_serialized_1~size    gequ datalib_data_entry_serialized_1~offset+4           ; Size of the data.
sizeof~datalib_data_entry_serialized_1  gequ datalib_data_entry_serialized_1~size+4

; The version 2 serialized data entry
datalib_data_entry_serialized_2~id      gequ 0                                                  ; ID of the data entry
datalib_data_entry_serialized_2~offset  gequ datalib_data_entry_serialized_2~id+4               ; Offset, from the stream start, to the data for this entry
datalib_data_entry_serialized_2~size    gequ datalib_data_entry_serialized_2~offset+4           ; Size of the data.
datalib_data_entry_serialized_2~flags_1 gequ datalib_data_entry_serialized_2~size+4             ; Flags 1
datalib_data_entry_serialized_2~flags_2 gequ datalib_data_entry_serialized_2~flags_1+2          ; Flags 2
sizeof~datalib_data_entry_serialized_2  gequ datalib_data_entry_serialized_2~flags_2+2

datalib_data_entry_2_flags_1~string_size gequ $00FF                                            ; size of the data entry's string in the metadata buffer
datalib_data_entry_2_flags_1~string_size_shift gequ 0
datalib_data_entry_2_flags_1~extra_data_size gequ $FF00                                        ; size of the data entry's extra data in the metadata buffer
datalib_data_entry_2_flags_1~extra_data_size_shift gequ 8
datalib_data_entry_2_flags_2~compression_type gequ $00FF                                       ; compression type used on the data
datalib_data_entry_2_flags_1~compression_type_shift gequ 0

; A data entry.  Holds a reference to a single piece of loaded data.
datalib_data_entry~id                   gequ 0                                                  ; id of the data.  Unique to the type, in the library, can be an index
datalib_data_entry~name                 gequ datalib_data_entry~id+4                            ; Name of the data
datalib_data_entry~offset               gequ datalib_data_entry~name+sizeof~string_object       ; Offset in the source file, to the data.
datalib_data_entry~size                 gequ datalib_data_entry~offset+4                        ; Size of the data in the source file (loaded data size can be different)
datalib_data_entry~data_ptr             gequ datalib_data_entry~size+4                          ; If not null.  The loaded data, in an unserialize state.
datalib_data_entry~ref_count            gequ datalib_data_entry~data_ptr+4                      ; Number of references on the data.
datalib_data_entry~sub_type             gequ datalib_data_entry~ref_count+4                     ; sub-type for the data.  This is data specific.
datalib_data_entry~last_access          gequ datalib_data_entry~sub_type+4                      ; Last access time-stamp
datalib_data_entry~type_ptr             gequ datalib_data_entry~last_access+4                   ; Parent type pointer
datalib_data_entry~compression_type     gequ datalib_data_entry~type_ptr+4                      ; Type of compression used on disk.  Can be 0, which means none
sizeof~datalib_data_entry               gequ datalib_data_entry~compression_type+2

; The supported compression types
datalib_compression_type~none           gequ 0
datalib_compression_type~lz4            gequ 1
datalib_compression_type~zx0            gequ 2                                                  ; zx0, version 2 format, forward compression.
datalib_compression_type~count          gequ 3                                                  ; keep last, used to validate the type index

; A data type entry.  Holds references to data of the same type
datalib_type_entry~id                   gequ 0
datalib_type_entry~info                 gequ datalib_type_entry~id+4                            ; Info bits.  See datalib_type_entry_info
datalib_type_entry~library_ptr          gequ datalib_type_entry~info+4
datalib_type_entry~translator_ptr       gequ datalib_type_entry~library_ptr+4                   ; The translator (unserializer) for the type's data.  This will always be valid.
datalib_type_entry~data_entries         gequ datalib_type_entry~translator_ptr+4
sizeof~datalib_type_entry               gequ datalib_type_entry~data_entries+sizeof~vector_definition

; datalib_type_entry info bits
datalib_type_entry_info~ordered_data_ids gequ $0001                                               ; If set, the data IDs are ordered (indexed)

; A data library. Holds types of data.
datalib_library~id                      gequ 0                                                    ; ID of the library. Not necessarily unique when there are overrides in the search chain
datalib_library~format_id               gequ datalib_library~id+4                                 ; Format ID of the library
datalib_library~info                    gequ datalib_library~format_id+4                          ; Runtime state info. See datalib_library_info
datalib_library~descriptor_ptr          gequ datalib_library~info+2                               ; Pointer to the descriptor for the library.  Can be null, but usually is not.
datalib_library~type_entries            gequ datalib_library~descriptor_ptr+4                     ; Type entries container
sizeof~datalib_library                  gequ datalib_library~type_entries+sizeof~vector_definition ; Size of the object, this must be last

; datalib_library info bits
datalib_library_info~valid              gequ $0001                                                ; If set, the library entry is valid (it has been unserialized)

; A library descriptor.  This represents a loaded library and the link to its file.
datalib_descriptor~info                 gequ 0                                                    ; Info bits
datalib_descriptor~open_ref_count       gequ datalib_descriptor~info+2                            ; A count of how many open requests have been made.
datalib_descriptor~library_ptr          gequ datalib_descriptor~open_ref_count+2                  ; A pointer to the library.  The header owns this pointer
datalib_descriptor~name                 gequ datalib_descriptor~library_ptr+4                     ; Library name.  This will be the path to the library
datalib_descriptor~file_desc            gequ datalib_descriptor~name+sizeof~string_object         ; The file descriptor
sizeof~datalib_descriptor               gequ datalib_descriptor~file_desc+sizeof~file_descriptor  ; Size of the object, this must be last

datalib_descriptor_info~has_file_ref    gequ $0001                                                ; if set, the descriptor itself, has one of the file references.

; A translator definition.  This is primarily a jump table to the individual handlers
datalib_translator                      gequ 0
datalib_translator_load                 gequ datalib_translator                                   ; Load
datalib_translator_unload               gequ datalib_translator_load+4                            ; Unload
datalib_translator_add_reference        gequ datalib_translator_unload+4                          ; Reference is being added
datalib_translator_remove_reference     gequ datalib_translator_add_reference+4                   ; Reference is being removed
datalib_translator_unload_unused        gequ datalib_translator_remove_reference+4                ; Unload all unused of the type
sizeof~datalib_translator               gequ datalib_translator_unload_unused+4
