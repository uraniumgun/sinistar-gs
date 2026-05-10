                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm

                            mcopy generated/datalib.translator.frmc.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
datalib_translator_frmc_data data seg_flib

datalib_translator_frmc  	dc a4'datalib_translator_frmc_load'
                            dc a4'datalib_translator_frmc_unload'
                            dc a4'0'                                ; add reference
                            dc a4'0'                                ; remove reference
                            dc a4'0'                                ; unload unused
                            end

; -----------------------------------------------------------------------------
; Initialize the FRMC (Frame Collection) Translator
datalib_translator_frmc_initialize start seg_flib
                            using datalib_translator_frmc_data

                            debugtag 'frmc_initialize'
                            debugtag 'datalib_translator'

                            pushptr #datalib_type_FRMC
                            pushptr #datalib_translator_frmc
                            jsl datalib_manager_set_default_translator_for_type

                            clc
                            lda #0
                            rtl
                            end

; -----------------------------------------------------------------------------
; Uninitialize the FRMC Translator
datalib_translator_frmc_uninitialize start seg_flib
                            using datalib_translator_frmc_data

                            debugtag 'frmc_uninitialize'
                            debugtag 'datalib_translator'

                            pushptr #datalib_type_FRMC
                            pushptr #0
                            jsl datalib_manager_set_default_translator_for_type

                            clc
                            lda #0
                            rtl
                            end

; -----------------------------------------------------------------------------
; FRMC Translator, Loading
; This will unserialize a FRMC data entry
datalib_translator_frmc_load start seg_flib
                            using datalib_errors
; Define our work area data
                            begin_locals
result                      decl word
pLibrary                    decl ptr
pDescriptor                 decl ptr
pReader                     decl ptr
pBuffer                     decl ptr
dwSize                      decl long
dwOffset                    decl long
pSets                       decl ptr
pSet                        decl ptr
pLists                      decl ptr
pList                       decl ptr
work_area_size              end_locals

                            debugtag 'frmc_load'
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
                            jne unsupported_data_size                                   ; For the moment, no data > 64k.
                            sta <dwSize+2
                            getword [<pDataEntry],#datalib_data_entry~size
                            sta <dwSize
                            cmp #sizeof~framelib_collection_file_header
                            jlt header_error
; Set the reader offset
                            pushptr <pReader
                            pushptr [<pDataEntry],#datalib_data_entry~offset            ; pushdword
                            jsl file_reader_set_offset
                            jcs error_exit
; We know that the header currently consists of just a single word that holds the version number
                            pushptr <pReader
                            jsl file_reader_get_word
                            jcs header_error
                            cmp #framelib_collection_file_header_current_version
                            jne header_version_error
; Remove the header from the total size of the data.
                            sec
                            lda <dwSize
                            sbc #sizeof~framelib_collection_file_header
                            sta <dwSize
                            lda <dwSize+2
                            sbc #0
                            sta <dwSize+2
; Allocate the buffer (we assume < 64k)
; We are going to have a 'runtime' header, that will add some additional runtime data to the loaded data.
; This way, we can still do the loading of the data off the disk in one big read, though we already did a partial read for the
; version.
                            lda <dwSize
                            clc
                            adc #sizeof~framelib_collection~runtime_header
                            pha
                            jsl sba_alloc
                            jcs buffer_alloc_error
                            putretptr <pBuffer
; Read the rest of the shape/sprite/tile data (yes, I can't settle on a name)
                            pushptr <pReader
                            pushptr <pBuffer,#sizeof~framelib_collection~runtime_header    ; skip the generated header
                            pushptr <dwSize
                            jsl file_reader_put_in_buffer
                            bcs error_exit
; Successfully loaded.
; Fixup all the offsets into pointers
                            jsr _pointer_fixup_collection
; put the pointer in the data entry, it will own the pointer
                            lda <pBuffer
                            putptrlow [<pDataEntry],#datalib_data_entry~data_ptr
                            lda <pBuffer+2
                            putptrhigh [<pDataEntry],#datalib_data_entry~data_ptr
; Fill in the datalib_shapedef header
; Back pointer to the data_entry.
                            lda <pDataEntry
                            putptrlow [<pBuffer],#framelib_collection~data_entry_ptr
                            lda <pDataEntry+2
                            putptrhigh [<pBuffer],#framelib_collection~data_entry_ptr
; and to the library.
                            lda <pLibrary
                            putptrlow [<pBuffer],#framelib_collection~library_ptr
                            lda <pLibrary+2
                            putptrhigh [<pBuffer],#framelib_collection~library_ptr
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
header_error                anop
header_version_error        anop
                            jsr error_cleanup
                            lda #datalib_error_version
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

; -------------------------------------------------------------------------------
; Fixup the offsets in the serialize data into pointers
_pointer_fixup_collection   anop

; The offset in the save data doesn't know about the runtime header, add that into
; what we will adjust the offsets with.
                            lda <pBuffer
                            clc
                            adc #sizeof~framelib_collection~runtime_header
                            sta <dwOffset
                            lda <pBuffer+2
                            adc #0
                            sta <dwOffset+2
; There are two arrays at the end of the collection
; An array of framelib_collection_set_entry * framelib_collection~unique_count
; The second array is a *short* offset to the set definition, we will fixup that into a short pointer

                            getword [<pBuffer],#framelib_collection~unique_count
                            beq no_sets

; Adjust the first array
                            tax
                            ldy #framelib_collection~sets+framelib_collection_set_entry~offset
offset_loop                 lda [<pBuffer],y
                            clc
                            adc #sizeof~framelib_collection~runtime_header
                            sta [<pBuffer],y
                            tya
                            clc
                            adc #sizeof~framelib_collection_set_entry
                            tay
                            dex
                            bne offset_loop

; Adjust the second array
                            getword [<pBuffer],#framelib_collection~total_count
                            pha                                             ; will need this again
                            tax

; Adjust the total_set_offset, to accomodate the runtime header.
                            getword [<pBuffer],#framelib_collection~total_set_offset
                            clc
                            adc #sizeof~framelib_collection~runtime_header
                            putword [<pBuffer],#same

; Get a pointer to the beginning of the total sets array
                            clc
                            adc <pBuffer
                            sta <pSets
                            lda <pBuffer+2                                  ; we don't support this crossing a bank boundary
                            sta <pSets+2

                            ldy #0
; Convert the short offsets into short pointers
set_loop                    lda [<pSets],y
                            clc
                            adc <dwOffset
                            sta [<pSets],y
                            iny
                            iny
                            dex
                            bne set_loop

; Now loop back over the sets and fixup their internal pointers
                            lda <pSets+2                                ; all sub-objects are in the same bank
                            sta <pSet+2

                            plx
                            ldy #0
set_loop2                   lda [<pSets],y
                            sta <pSet
                            jsr _pointer_fixup_set
                            iny
                            iny
                            dex
                            bne set_loop2
no_sets                     rts

_pointer_fixup_set          anop
                            phy
                            phx

                            getptr <pSet,#framelib_set~lists,<pLists
                            getword [<pSet],#framelib_set~count
                            beq no_lists
                            tax
                            phx
;
                            ldy #0
; Convert the offsets into pointers
list_loop                   lda [<pLists],y
                            clc
                            adc <dwOffset
                            sta [<pLists],y
                            iny
                            iny
                            lda [<pLists],y
                            adc <dwOffset+2
                            sta [<pLists],y
                            iny
                            iny
                            dex
                            bne list_loop
; Now loop back over the sets and fixup their internal pointers
                            plx
                            ldy #0
list_loop2                  lda [<pLists],y
                            sta <pList
                            iny
                            iny
                            lda [<pLists],y
                            sta <pList+2
                            jsr _pointer_fixup_list
                            iny
                            iny
                            dex
                            bne list_loop2

                            plx
                            ply
no_lists                    rts

_pointer_fixup_list         anop
                            phy

                            lda #0
                            putptr [<pList],#framelib_list~data_ptr         ; Just make sure the cached data_ptr is clear.

                            ply
                            rts

                            end

; -----------------------------------------------------------------------------
; FRMC Translator, Unload
; This will free the data in the data entry
datalib_translator_frmc_unload start seg_flib
                            using datalib_errors
; Define our work area data
                            begin_locals
result                      decl word
pData                       decl ptr
work_area_size              end_locals

                            debugtag 'frmc_unload'
                            debugtag 'datalib_translator'
                            sub (4:pTypeEntry,4:pDataEntry),work_area_size

                            stz <result
                            getptr [<pDataEntry],#datalib_data_entry~data_ptr,<pData
                            ora <pData
                            beq null_data_ptr
; Call the destruct
                            pushptr <pData
                            jsl framelib_collection_destruct

                            pushptr <pData
                            jsl sba_free
                            clearptr [<pDataEntry],#datalib_data_entry~data_ptr

null_data_ptr               anop
                            ret 2:result
                            end

