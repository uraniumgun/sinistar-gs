                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm

                            mcopy generated/asset.control.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; Asset related functions

appassetdata                data seg_app
app_datalib_manifest        ds sizeof~vector_definition
                            end

; ----------------------------------------------------------------------------
; Read a manifest file, that contains what datalibs to open.
; I'm doing a manifest file, just so it is easier to twiddle with what is being
; loaded.  I could probably just embed the file names in the app too.
; Maybe I'll extend this and have the file also contain some other configuration
; metadata.
;
; Parameters:
; pPathnameArray        - a vector of string_objects
; Returns:
; Carry clear on success
read_datalib_manifest       start seg_app

                            begin_locals
failed                      decl word
work_area_size              end_locals

                            debugtag 'read_datalib_manifest'
                            sub (4:pPathNameArray),work_area_size          ; Parameters, plus the amount of space for our local work area

                            lda #1
                            sta <failed                                     ; assume we failed

                            pushptr #manifest_name_object
                            pushptr #manifest_name
                            jsl string_object_construct_zt

                            pushptr #manifest_desc
                            jsl file_descriptor_construct

                            pushptr #manifest_desc
                            pushptr #manifest_name_object
                            jsl file_descriptor_open
                            bne failed_to_open

                            pushptr #manifest_desc
                            jsl file_reader_new_with_desc
                            bcs reader_failed
                            putretptr manifest_reader_ptr
; Get a buffer
                            pushsword manifest_desc+file_descriptor~length
                            jsl sba_alloc
                            bcs allocation_error
                            putretptr manifest_file_buffer_ptr
; Read into it
                            pushptr manifest_reader_ptr
                            pushptr manifest_file_buffer_ptr
                            pushdword manifest_desc+file_descriptor~length
                            jsl file_reader_put_in_buffer
                            bcs read_error
; Parse the filenames
                            pushptr <pPathNameArray
                            pushptr manifest_file_buffer_ptr
                            pushdword manifest_desc+file_descriptor~length
                            jsl string_parse_buffer_to_strings                  ; todo: This should return carry set on a parse error.

                            stz <failed

read_error                  anop
                            pushptr manifest_file_buffer_ptr
                            jsl sba_free

allocation_error            anop
                            pushptr manifest_reader_ptr
                            jsl file_reader_delete

reader_failed               anop
                            pushptr #manifest_desc
                            jsl file_descriptor_close

failed_to_open              anop
                            pushptr #manifest_name_object
                            jsl string_object_destruct

                            lsr <failed                         ; Move the failed flag into the carry
                            retkc

manifest_desc               ds sizeof~file_descriptor
manifest_reader_ptr         ds 4
manifest_file_buffer_ptr    ds 4

manifest_name_object        ds sizeof~string_object

manifest_name               dc c'9:manifest'
                            dc i1'0'

                            end

; ----------------------------------------------------------------------------
; Load all the metadata for a set of datalibs.
; Parameters:
;  pPathnameArray           - vector of string_objects
load_datalib_libraries      start seg_app

                            begin_locals
itr                         decl sizeof~vector_iterator
work_area_size              end_locals

                            debugtag 'load_datalib_libraries'
                            sub (4:pPathNameArray),work_area_size          ; Parameters, plus the amount of space for our local work area

                            testptr <pPathNameArray
                            beq null_pointer

                            pushptr <pPathNameArray
                            pushlocalptr #itr
                            jsl container_vector_front
                            bcs iterator_error

loop                        pushptr <itr+vector_iterator~ptr
                            pushsword #datalib_preload_options~none
                            jsl datalib_manager_add_library
                            bcs add_error
; Need error handling here
                            vector_iterator_next_test_end <itr
                            bne loop

exit                        ret
add_error                   anop
null_pointer                anop
iterator_error              anop
                            assert_brk
                            bra exit
                            end


; ----------------------------------------------------------------------------
open_datalibs               start seg_app
                            using appassetdata
                            using string_globals

                            debugtag 'open_datalibs'

; Make a vector for the datalib paths
                            pushptr #app_datalib_manifest
                            pushptr #string_object
                            jsl container_vector_construct

; Read the datalib paths to load.
                            pushptr #app_datalib_manifest
                            jsl read_datalib_manifest
                            bcs error
; Load them
                            pushptr #app_datalib_manifest
                            jsl load_datalib_libraries

error                       rtl
                            end

; ----------------------------------------------------------------------------
close_datalibs              start seg_app
                            using appassetdata

                            debugtag 'close_datalibs'

                            pushptr #app_datalib_manifest
                            jsl container_vector_destruct

                            rtl
                            end

; ----------------------------------------------------------------------------
load_fonts                  start seg_app
                            using std_objects
                            using appdata

                            debugtag 'load_fonts'

; This is a simple, easy-to-read font
secondary_font_id           equ '0TNF'
; These two are representative of what was in the original game
primary_font_id             equ '2TNF'
teeny_font_id               equ '1TNF'

                            pushdword #datalib_type_FONT
                            pushdword #primary_font_id
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_manager_get_data_ptr
                            bcs failed
; Save it for later
                            putretptr appdata~primary_font_ptr
; Activate it
                            pushretptr
                            jsl grlib_set_active_font_ptr

; Load the teeny font too
                            pushdword #datalib_type_FONT
                            pushdword #teeny_font_id
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_manager_get_data_ptr
                            bcs failed
; Save it for later
                            putretptr appdata~teeny_font_ptr

; Load the secondary font
                            pushdword #datalib_type_FONT
                            pushdword #secondary_font_id
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_manager_get_data_ptr
                            bcs failed
; Save it for later
                            putretptr appdata~secondary_font_ptr

                            clc

exit                        anop
                            rtl

failed                      anop
                            debugger_msg #str_failed_to_find_data
                            sec
                            bra exit

str_failed_to_find_data     dw 'Failed to find font data'
                            end
