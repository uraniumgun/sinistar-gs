                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/shape.definitions.asm

                            mcopy generated/datalib.translator.tile.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
datalib_translator_tile_data data seg_flib

datalib_translator_tile  	dc a4'datalib_translator_tile_load'
                            dc a4'datalib_translator_tile_unload'
                            dc a4'0'                                ; add reference
                            dc a4'0'                                ; remove reference
                            dc a4'0'                                ; unload unused
                            end

; -----------------------------------------------------------------------------
; Initialize the TILE (Pixel shape data) Translator
datalib_translator_tile_initialize start seg_flib
                            using datalib_translator_tile_data

                            debugtag 'tile_initialize'
                            debugtag 'datalib_translator'

                            pushptr #datalib_type_TILE
                            pushptr #datalib_translator_tile
                            jsl datalib_manager_set_default_translator_for_type

                            clc
                            lda #0
                            rtl
                            end

; -----------------------------------------------------------------------------
; Uninitialize the TILE Translator
datalib_translator_tile_uninitialize start seg_flib
                            using datalib_translator_tile_data

                            debugtag 'tile_uninitialize'
                            debugtag 'datalib_translator'

                            pushptr #datalib_type_TILE
                            pushptr #0
                            jsl datalib_manager_set_default_translator_for_type

                            clc
                            lda #0
                            rtl
                            end

; -----------------------------------------------------------------------------
; TILE Translator, Loading
; This will unserialize a TILE data entry
; This does support compressed source data.
datalib_translator_tile_load start seg_flib
                            using datalib_errors
; Define our work area data
                            begin_locals
result                      decl word
pLibrary                    decl ptr
pDescriptor                 decl ptr
pReader                     decl ptr
pBuffer                     decl ptr
dwSize                      decl long
pCompressedBuffer           decl ptr
dwDecompressedSize          decl long
wCompressionType            decl word
work_area_size              end_locals

                            debugtag 'tile_load'
                            debugtag 'datalib_translator'
                            sub (4:pTypeEntry,4:pDataEntry,2:wOptions),work_area_size

; Clear some pointers, it makes it easier to cleanup if there is an error
                            clearptr <pReader
                            clearptr <pBuffer
                            clearptr <pCompressedBuffer
                            stz <result

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
                            cmp #sizeof~shapedef_file_header
                            jlt header_error
; Set the reader offset
                            pushptr <pReader
                            pushptr [<pDataEntry],#datalib_data_entry~offset            ; pushdword
                            jsl file_reader_set_offset
                            bcs error_exit
; The TILE data needs minimal unserialization, which is good for speed.  We currently only have a header, then the remainder of the data is runtime data in one block.
; We know that the header currently consists of just a single word that holds the version number
                            pushptr <pReader
                            jsl file_reader_get_word
                            bcs header_error
                            cmp #shapedef_file_header_current_version
                            bne header_version_error

; Get the compression type, and call the handler for the type
                            getword [<pDataEntry],#datalib_data_entry~compression_type
                            cmp #datalib_compression_type~count
                            bge compression_version_error
                            asl a
                            sta <wCompressionType                       ; stored x2
                            tax
                            jsr (reader_funcs,x)
                            bcs error_exit

; Successfully loaded, put the pointer in the data entry, it will own the pointer
                            lda <pBuffer
                            putptrlow [<pDataEntry],#datalib_data_entry~data_ptr
                            lda <pBuffer+2
                            putptrhigh [<pDataEntry],#datalib_data_entry~data_ptr
; Fill in the datalib_shapedef header
; Back pointer to the data_entry.
                            lda <pDataEntry
                            putptrlow [<pBuffer],#datalib_shapedef~data_entry_ptr
                            lda <pDataEntry+2
                            putptrhigh [<pBuffer],#datalib_shapedef~data_entry_ptr
; Cleanup the file reader
                            pushptr <pReader
                            jsl file_reader_delete

exit                        pushptr <pDescriptor
                            jsl datalib_descriptor_close
not_opened                  anop
                            ret 2:result

error_exit                  sta <result
                            jsr error_cleanup
                            bra exit

unsupported_data_size       lda #datalib_error_unsupported_size
                            bra error_exit

header_error                anop
header_version_error        anop
                            lda #datalib_error_version
                            bra error_exit
compression_version_error   anop
                            lda #datalib_error_unknown_compression
                            bra error_exit

buffer_alloc_error          anop
reader_alloc_error          anop
                            lda #datalib_error_allocation
                            bra error_exit

reader_funcs                dc a2'uncompressed_reader'
                            dc a2'basic_compressed_reader'
                            dc a2'basic_compressed_reader'
;;;
; Local Functions

error_cleanup               pushptr <pReader
                            jsl file_reader_delete
                            pushptr <pBuffer
                            jsl sba_free
                            pushptr <pCompressedBuffer
                            jsl sba_free
                            rts

; Read uncompressed data
uncompressed_reader         anop
; Remove the header from the total size of the data.
                            sec
                            lda <dwSize
                            sbc #sizeof~shapedef_file_header
                            sta <dwSize
; Skipping the high word, as we have already checked that we are not over 64k

; Allocate the buffer, again, we assume < 64k
; We are going to have a 'runtime' header, that will add some additional runtime data to the loaded data.
; This way, we can still do the loading of the data off the disk in one big read, though we already did a partial read for the
; version.
                            clc
                            adc #sizeof~datalib_shapedef
                            pha
                            jsl sba_alloc
                            bcs uncompressed_buffer_allocation_error
                            putretptr <pBuffer
; Read the rest of the shape/sprite/tile data (yes, I can't settle on a name)
                            pushptr <pReader
                            pushptr <pBuffer,#sizeof~datalib_shapedef    ; skip the generated header
                            pushptr <dwSize
                            jsl file_reader_put_in_buffer
                            bcs uncompressed_read_error
                            rts

uncompressed_buffer_allocation_error anop
                            lda #datalib_error_allocation
uncompressed_read_error     sta <result
                            rts

; Read LZ4 or ZX0 compressed data.  Expects wCompressionType to have which compression type, times 2
basic_compressed_reader      anop
; Read the uncompressed size
                            pushptr <pReader
                            jsl file_reader_get_long
                            bcs compressed_read_error
                            cpx #0
                            bne compressed_size_error                   ; only supporting < 64k decompressed size
                            putretptr <dwDecompressedSize

; Remove the header and the decompressed size from the total size of the source data.
                            sec
                            lda <dwSize
                            sbc #sizeof~shapedef_file_header+4
                            sta <dwSize
; Skipping the high word, as we have already checked that we are not over 64k

; Allocate the destination buffer, again, we assume < 64k
; We are going to have a 'runtime' header, that will add some additional runtime data to the loaded data.
; This way, we can still do the loading of the data off the disk in one big read, though we already did a partial read for the
; version.
                            lda <dwDecompressedSize
                            clc
                            adc #sizeof~datalib_shapedef
                            bcs compressed_size_error                   ; overflow?
                            pha
                            jsl sba_alloc
                            bcs compressed_buffer_allocation_error
                            putretptr <pBuffer
; We need a buffer to read the compressed data into as well.  Might be good to have some 'shared' buffer that all decompression can use.
; The problem is, that this is going to be a big buffer, and is certainly not going to actually be a 'small block' and will
; be on the main heap. Because we are allocating this *after* the destination, we *should* be ok, and not cause fragmentation,
; but having some temporary block of a decent size for this might be good.
                            pushsword <dwSize
                            jsl sba_alloc
                            bcs compressed_buffer_allocation_error
                            putretptr <pCompressedBuffer

; Read the compressed data
                            pushptr <pReader
                            pushptr <pCompressedBuffer
                            pushptr <dwSize
                            jsl file_reader_put_in_buffer
                            bcs compressed_read_error
; Decompress the data
; Check which actual decompression to use.
                            ldx <wCompressionType
                            jsr (uncompress_funcs,x)

check_uncompress            cmp <dwDecompressedSize
                            beq ok_decompression
                            assert_brk 'dcmp size'

ok_decompression            anop
                            pushptr <pCompressedBuffer
                            jsl sba_free
                            clc
                            rts

compressed_buffer_allocation_error anop
                            lda #datalib_error_allocation
compressed_read_error       sta <result
                            rts
compressed_size_error       lda #datalib_error_unsupported_size
                            sta <result
                            rts

uncompress_funcs            dc a'error_func'
                            dc a'do_lz4'
                            dc a'do_zx0'

error_func                  brk $01
                            lda #0
                            rts

do_lz4                      anop
                            pushptr <pCompressedBuffer
                            pushptr <pBuffer,#sizeof~datalib_shapedef    ; decompress past the generated header
                            pushsword <dwSize
                            jsl lz4_unpack
                            rts

do_zx0                      anop
                            pushptr <pCompressedBuffer
                            pushptr <pBuffer,#sizeof~datalib_shapedef    ; decompress past the generated header
                            pushsword <dwSize
                            jsl zx0_unpack
                            rts

                            end

; -----------------------------------------------------------------------------
; TILE Translator, Unload
; This will free the data in the data entry
datalib_translator_tile_unload start seg_flib
                            using datalib_errors
; Define our work area data
                            begin_locals
result                      decl word
pData                       decl ptr
work_area_size              end_locals

                            debugtag 'tile_unload'
                            debugtag 'datalib_translator'
                            sub (4:pTypeEntry,4:pDataEntry),work_area_size

; Currently, all that is required is to just release the memory
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
