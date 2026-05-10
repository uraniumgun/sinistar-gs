                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm

                            mcopy generated/framelib.manager.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Get the frame data pointer (shape definition) for the supplied frame
; This gets the 'primary' shape definition, which is a TILE
;
; Parameters:
;  pLibrary     - the library the collection from where the frame came from
;  wFrameID     - the frame ID.
framelib_manager_get_primary_frame_data_ptr start seg_grlib

                            begin_locals
result                      decl ptr
work_area_size              end_locals

                            debugtag 'get_primary_frame_data_ptr'
                            debugtag 'framelib_manager'
                            sub (4:pLibrary,2:wFrameID),work_area_size

                            testptr <pLibrary
                            beq null_pointer

; The frame IDs are relative to the library
                            pushptr <pLibrary
                            pushdword #datalib_type_TILE
                            pushsword #0                                     ; The ID is an index, so nothing in the high word
                            pushsword <wFrameID                              ; and the index in the low word.
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            bcs load_error
                            putretptr <result
exit                        retkc 4:result

load_error                  anop
null_pointer                anop
                            sec
                            clearptr <result
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Release the frame data pointer (shape definition) for the supplied frame
; This does the 'primary' shape definition, which is a TILE
;
; Parameters:
;  pLibrary     - the library the collection from where the frame came from
;  wFrameID     - the frame ID.
framelib_manager_release_primary_frame_data start seg_grlib

                            begin_locals
result                      decl ptr
work_area_size              end_locals

                            debugtag 'release_primary_frame_data'
                            debugtag 'framelib_manager'

                            sub (4:pLibrary,2:wFrameID),work_area_size

                            testptr <pLibrary
                            beq null_pointer

; The frame IDs are relative to the library
                            pushptr <pLibrary
                            pushdword #datalib_type_TILE
                            pushsword #0                                     ; The ID is an index, so nothing in the high word
                            pushsword <wFrameID                              ; and the index in the low word.
                            pushsword #datalib_unload_options~none
                            jsl datalib_library_release_data_ptr

exit                        retkc

null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Get the frame data pointer (shape definition) for the supplied frame
; This gets the 'secondary' shape definition, which is a TILE
;
; Parameters:
;  pLibrary     - the library the collection from where the frame came from
;  wFrameID     - the frame ID.
framelib_manager_get_secondary_frame_data_ptr start seg_grlib

                            begin_locals
result                      decl ptr
work_area_size              end_locals

                            debugtag 'get_secondary_frame_data_ptr'
                            debugtag 'framelib_manager'

                            sub (4:pLibrary,2:wFrameID),work_area_size

                            testptr <pLibrary
                            beq null_pointer

; The frame IDs are relative to the library
                            pushptr <pLibrary
                            pushdword #datalib_type_CTIL
                            pushsword #0                                     ; The ID is an index, so nothing in the high word
                            pushsword <wFrameID                              ; and the index in the low word.
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            bcs load_error

                            putretptr <result
exit                        retkc 4:result

load_error                  anop
null_pointer                anop
                            sec
                            clearptr <result
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Get the frame data pointer (shape definition) for the supplied frame
; This gets the 'secondary' shape definition, which is a TILE
;
; Parameters:
;  pLibrary     - the library the collection from where the frame came from
;  wFrameID     - the frame ID.
framelib_manager_release_secondary_frame_data start seg_grlib

                            begin_locals
result                      decl ptr
work_area_size              end_locals

                            debugtag 'release_secondary_frame_data'
                            debugtag 'framelib_manager'

                            sub (4:pLibrary,2:wFrameID),work_area_size

                            testptr <pLibrary
                            beq null_pointer

; The frame IDs are relative to the library
                            pushptr <pLibrary
                            pushdword #datalib_type_CTIL
                            pushsword #0                                     ; The ID is an index, so nothing in the high word
                            pushsword <wFrameID                              ; and the index in the low word.
                            pushsword #datalib_unload_options~none
                            jsl datalib_library_release_data_ptr

exit                        retkc

null_pointer                anop
                            sec
                            bra exit

                            end


