                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.definitions.asm

                            mcopy generated/datalib.translator.default.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
datalib_translator_default_data data seg_flib

datalib_translator_default  dc a4'datalib_translator_default_load'
                            dc a4'datalib_translator_default_unload'
                            dc a4'0'                                ; add reference
                            dc a4'0'                                ; remove reference
                            dc a4'0'                                ; unload unused
                            end

; -----------------------------------------------------------------------------
; Default Translator, Loading
; This will load the data as a single block, with no transformation on the data.
datalib_translator_default_load start seg_flib
                            using datalib_errors
; Define our work area data
                            begin_locals
result                      decl word
pLibrary                    decl ptr
pDescriptor                 decl ptr
pReader                     decl ptr
pBuffer                     decl ptr
dwSize                      decl long
work_area_size              end_locals

                            debugtag 'default_load'
                            debugtag 'datalib_translator'
                            sub (4:pTypeEntry,4:pDataEntry,2:wOptions),work_area_size

; Clear some pointers, it makes it easier to cleanup if there is an error
                            clearptr <pReader
                            clearptr <pBuffer

                            getptr [<pTypeEntry],#datalib_type_entry~library_ptr,<pLibrary
                            getptr [<pLibrary],#datalib_library~descriptor_ptr,<pDescriptor
; Open the descriptor
                            pushptr <pDescriptor
                            jsl datalib_descriptor_open
                            beq opened_ok
                            lda #datalib_error_open_error
                            sta <result
                            brl not_opened
opened_ok                   anop

; Get the datalib_descriptor's embedded file_descriptor and use that to make a file_reader.
                            pushptr <pDescriptor,#datalib_descriptor~file_desc
                            jsl file_reader_new_with_desc
                            jcs reader_alloc_error
                            putretptr <pReader

                            getword [<pDataEntry],#datalib_data_entry~size+2
                            bne unsupported_data_size                                   ; For the moment, no data > 64k.
                            sta <dwSize+2
                            getword [<pDataEntry],#datalib_data_entry~size
                            sta <dwSize
                            pha
                            jsl sba_alloc
                            bcs buffer_alloc_error
                            putretptr <pBuffer

                            pushptr <pReader
                            pushptr [<pDataEntry],#datalib_data_entry~offset            ; Want pushdword to work with this.  pushdword?
                            jsl file_reader_set_offset
                            bcs error_exit

                            pushptr <pReader
                            pushptr <pBuffer
                            pushptr <dwSize
                            jsl file_reader_put_in_buffer
                            bcs error_exit
; Successfully loaded, put the pointer in the data entry, it will own the pointer
                            lda <pBuffer
                            putptrlow [<pDataEntry],#datalib_data_entry~data_ptr
                            lda <pBuffer+2
                            putptrhigh [<pDataEntry],#datalib_data_entry~data_ptr
; Cleanup the file reader
                            pushptr <pReader
                            jsl file_reader_delete

                            lda #0

error_exit                  sta <result
                            pushptr <pDescriptor
                            jsl datalib_descriptor_close
not_opened                  anop
                            ret 2:result

unsupported_data_size       jsr error_cleanup
                            lda #datalib_error_unsupported_size
                            bra error_exit

buffer_alloc_error          anop
reader_alloc_error          anop
                            jsr error_cleanup
                            lda #datalib_error_allocation
                            bra error_exit

error_cleanup               pushptr <pReader
                            jsl file_reader_delete
                            pushptr <pBuffer
                            jsl sba_free
                            rts

                            end

; -----------------------------------------------------------------------------
; Default Translator, Unload
; This will free the data in the data entry
datalib_translator_default_unload start seg_flib
                            using datalib_errors
; Define our work area data
                            begin_locals
result                      decl word
pData                       decl ptr
work_area_size              end_locals

                            debugtag 'default_unload'
                            debugtag 'datalib_translator'
                            sub (4:pTypeEntry,4:pDataEntry),work_area_size

                            stz <result
                            getptr [<pDataEntry],#datalib_data_entry~data_ptr,<pData
                            ora <pData
                            beq null_data_ptr

                            pushptr <pData
                            jsl sba_free
                            clearptr [<pDataEntry],#datalib_data_entry~data_ptr

null_data_ptr               anop
                            ret 2:result
                            end
