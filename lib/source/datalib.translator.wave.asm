                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/sndlib.definitions.asm
                            copy lib/source/sndlib.riff.definitions.asm

                            mcopy generated/datalib.translator.wave.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Datalb translator, for WAVE data.
; This will support reading wavetable data in different formats,
; though mainly the header.  i.e.  RIFF vs. custom
; -----------------------------------------------------------------------------
datalib_translator_wave_data data seg_flib

datalib_translator_wave  	dc a4'datalib_translator_wave_load'
                            dc a4'datalib_translator_wave_unload'
                            dc a4'0'                                ; add reference
                            dc a4'0'                                ; remove reference
                            dc a4'0'                                ; unload unused
                            end

; -----------------------------------------------------------------------------
; Initialize the WAVE Translator
datalib_translator_wave_initialize start seg_flib
                            using datalib_translator_wave_data

                            debugtag 'wave_initialize'
                            debugtag 'datalib_translator'

                            pushptr #datalib_type_wave
                            pushptr #datalib_translator_wave
                            jsl datalib_manager_set_default_translator_for_type

                            clc
                            lda #0
                            rtl
                            end

; -----------------------------------------------------------------------------
; Uninitialize the wave Translator
datalib_translator_wave_uninitialize start seg_flib
                            using datalib_translator_wave_data

                            debugtag 'wave_uninitialize'
                            debugtag 'datalib_translator'

                            pushptr #datalib_type_wave
                            pushptr #0
                            jsl datalib_manager_set_default_translator_for_type

                            clc
                            lda #0
                            rtl
                            end

; -----------------------------------------------------------------------------
; WAVE Translator, Loading
; This supports compressed sources, though this does not support
; any compression that can remain compressed and streamed.
datalib_translator_wave_load start seg_flib
                            using datalib_errors

; Define our work area data
                            begin_locals
result                      decl word
pLibrary                    decl ptr
pDescriptor                 decl ptr
pReader                     decl ptr
pBuffer                     decl ptr
dwSize                      decl long
dwChunkSize                 decl long
pChunk                      decl ptr
wChannelCount               decl word
wSampleRate                 decl word
wHeaderSize                 decl word
wCompressionType            decl word
pSampleBuffer               decl ptr
pCompressedBuffer           decl ptr
dwCompressedSize            decl long
dwDecompressedSize          decl long
dwValidationChecksum        decl long
dwReadChecksum              decl long
work_area_size              end_locals

                            debugtag 'wave_load'
                            debugtag 'datalib_translator'

                            sub (4:pTypeEntry,4:pDataEntry,2:wOptions),work_area_size

                            lda #datalib_location_library_wave
                            jsl system_error_push_location

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
                            sta <dwSize+2
                            getword [<pDataEntry],#datalib_data_entry~size
                            sta <dwSize
; Set the reader offset
                            pushptr <pReader
                            pushdword [<pDataEntry],#datalib_data_entry~offset
                            jsl file_reader_set_offset
                            bcs error_exit
; Supporting multiple header type, though we are assuming that we can tell the difference between then by reading the first dword
                            pushptr <pReader
                            jsl file_reader_get_long
                            bcs header_error

                            cmp #riff_header~typeid
                            bne not_riff
                            cpx #^riff_header~typeid
                            bne not_riff
                            jsr read_riff
                            bcc read_ok
                            bra unsupported_data_type

not_riff                    anop
                            cmp #wave_header~typeid_wave
                            bne unsupported_data_type
                            cpx #^wave_header~typeid_wave
                            bne unsupported_data_type

                            jsr read_wave
                            bcs unsupported_data_type

read_ok                     anop
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

unsupported_data_type       jsr error_cleanup
                            lda #datalib_error_unsupported_size
                            bra error_exit
header_error                anop
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
                            rts

; -----------------------------
; Read the riff header and load the wavetable data
read_riff                   anop
                            pushptr <pReader
                            jsl file_reader_get_long
;                           putretptr <dwRiffFileSize

                            pushptr <pReader
                            jsl file_reader_get_long
                            cmp #riff_header~typeid_format_wave
                            bne riff_wave_header_error
                            cpx #^riff_header~typeid_format_wave
                            bne riff_wave_header_error

                            stz <wChannelCount
                            stz <wSampleRate

riff_loop                   pushptr <pReader
                            jsl file_reader_get_long
                            cmp #riff_chunk~typeid_fmt
                            bne chunk_not_fmt
                            cpx #^riff_chunk~typeid_fmt
                            bne chunk_not_fmt

; fmt chunk
                            pushptr <pReader
                            jsl file_reader_get_long

                            pushptr <pReader                    ; assuming this will not disturb A
                            pha                                 ; push the size of the fmt chunk.  It should be 16.
                            jsl file_reader_get_buffered_data
                            bcs riff_wave_header_error
                            putretptr <pChunk
                            getword [<pChunk],#riff_chunk_fmt~type
; Check that this is PCM data
                            cmp #riff_chunk_fmt~typeid_pcm
                            bne riff_wave_header_error
; Check the sample size
                            getword [<pChunk],#riff_chunk_fmt~bits_per_sample
                            cmp #8                              ; Not doing any downsampling, at least not at this time
                            bne riff_wave_header_error

                            getword [<pChunk],#riff_chunk_fmt~channels
                            sta <wChannelCount
                            cmp #1
                            beq riff_one_channel
                            brk $01                     ;  Hmm, I gotta figure out how it will store the data, if it is 2 channels.
                            bra riff_wave_header_error
riff_one_channel            anop
                            getword [<pChunk],#riff_chunk_fmt~samples_per_second
                            sta <wSampleRate
                            bra riff_loop

chunk_not_fmt               anop
                            cmp #riff_chunk~typeid_data
                            bne skip_chunk
                            cpx #^riff_chunk~typeid_data
                            beq chunk_is_data

skip_chunk                  anop
                            pushptr <pReader
                            jsl file_reader_get_long

                            pushptr <pReader                    ; assuming this will not disturb A
                            pha                                 ; push the size of the chunk and read it.  This will essentially skip it.
                            jsl file_reader_get_buffered_data
                            bcc riff_loop
                            rts

riff_wave_header_error      sec
                            rts

chunk_is_data               anop
; data chunk
                            pushptr <pReader
                            jsl file_reader_get_long
                            putretptr <dwChunkSize

; Add in the space we will need at the front for the runtime header

                            lda <wChannelCount
                            beq riff_channel_error      ; no channels?  We probably didn't read the fmt chunk.

                            shiftleft 3                 ; * 8
                            clc
                            adc #sizeof~wavetable_definition
                            sta <wHeaderSize
                            adc <dwChunkSize            ; Do we want to pad the end with 8 0x00's (stop bytes) ?
                            tay
                            lda #0
                            adc <dwChunkSize+2
                            tax
                            tya

                            jsl allocate_long_fixed_handle
                            bcs riff_allocation_error
                            putretptr <pChunk           ; use this for dereference
                            getword [<pChunk],#0
                            sta <pBuffer
                            getword [<pChunk],#2
                            sta <pBuffer+2

                            lda <wSampleRate
                            putword [<pBuffer],#wavetable_definition~sample_rate
                            lda <wChannelCount
                            putword [<pBuffer],#wavetable_definition~channels

; This needs to work for more than one channel, if we are going to support that for riffs, but I don't
; know how it is storing that on export.  It needs to be back to back, not interleaved.
; If there are 2 data chunks, the allocation will be more complex.

                            ldy #wavetable_definition~size
                            lda <dwChunkSize
                            sta [<pBuffer],y
                            iny
                            iny
                            lda <dwChunkSize+2
                            sta [<pBuffer],y
                            iny
                            iny

; Set the offset to point to the sample buffer
                            lda <pBuffer
                            clc
                            adc <wHeaderSize
                            sta [<pBuffer],y
                            sta <pSampleBuffer
                            iny
                            iny
                            lda <pBuffer+2
                            adc #0
                            sta [<pBuffer],y
                            sta <pSampleBuffer+2

; Read the rest of the data
; We are allowing for pre-processing to have been done to compress the chunk data (samples)
; The chunk size will still reflect the uncompressed data size.
                            getword [<pDataEntry],#datalib_data_entry~compression_type
                            cmp #datalib_compression_type~count
                            bge compression_version_error
                            asl a
                            sta <wCompressionType                       ; stored x2
                            tax
                            jsr (riff_sample_reader_funcs,x)
                            bcc riff_done

; Read error.  Toss the buffer
compression_version_error   anop
                            lda <pBuffer
                            ldx <pBuffer+2
                            jsl deallocate_long_fixed_handle_ptr
                            clearptr <pBuffer
                            brk $99

riff_allocation_error       anop
riff_channel_error          anop
                            sec

riff_done                   rts

riff_sample_reader_funcs    dc a2'riff_uncompressed_reader'
                            dc a2'riff_basic_compressed_reader'
                            dc a2'riff_basic_compressed_reader'

; Uncompressed, just read into the buffer
riff_uncompressed_reader    anop
                            pushptr <pReader
                            pushptr <pSampleBuffer
                            pushdword <dwChunkSize
                            jsl file_reader_put_in_buffer
                            rts

; Read LZ4 or ZX0 compressed data.  Expects wCompressionType to have which compression type, times 2
riff_basic_compressed_reader anop
; Read the uncompressed size.  Note that this *must* be what we just read for the chunk size, as that was
; already used to allocate the destination buffer.  Maybe just not serialize this?
                            pushptr <pReader
                            jsl file_reader_get_long
                            bcs compressed_read_error
                            cpx #0
                            bne compressed_size_error                   ; only supporting < 64k decompressed size
                            putretptr <dwDecompressedSize
; Because the RIFF header is a variable size, and because the file reader doesn't currently have a 'get_offset' function,
; the next dword is the size of the compressed data
                            pushptr <pReader
                            jsl file_reader_get_long
                            bcs compressed_read_error
                            putretptr <dwCompressedSize

; We need a buffer to read the compressed data into as well.  Might be good to have some 'shared' buffer that all decompression can use
                            cpx #0
                            bne compressed_size_error
                            pha                                         ; assuming that the compressed size is less that 64k
                            jsl sba_alloc
                            bcs compressed_buffer_allocation_error
                            putretptr <pCompressedBuffer

; Get a CRC32 of the uncompressed data
                            pushptr <pReader
                            jsl file_reader_get_long
                            bcs compressed_read_error
                            putretptr <dwValidationChecksum
; Read the compressed data
                            pushptr <pReader
                            pushptr <pCompressedBuffer
                            pushdword <dwCompressedSize
                            jsl file_reader_put_in_buffer
                            bcs compressed_read_error
; Decompress the data
; Check which actual decompression to use.  If it gets more than 2, then use a jmp table.
                            ldx <wCompressionType
                            jsr (uncompress_funcs,x)

check_uncompress            cmp <dwDecompressedSize
                            beq ok_decompression
                            assert_brk
ok_decompression            anop
; Debug.  Validate the buffer against the checksum
;                           jsr validate_buffer

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
                            sec
                            rts

uncompress_funcs            dc a'error_func'
                            dc a'do_lz4'
                            dc a'do_zx0'

error_func                  brk $01
                            lda #0
                            rts

do_lz4                      anop
                            pushptr <pCompressedBuffer
                            pushptr <pSampleBuffer
                            pushsword <dwCompressedSize
                            jsl lz4_unpack
                            rts

do_zx0                      anop
                            pushptr <pCompressedBuffer
                            pushptr <pSampleBuffer
                            pushsword <dwCompressedSize
                            jsl zx0_unpack
                            rts

; Optional validation of the buffer checksum
validate_buffer             anop
                            pushptr <pSampleBuffer
                            pushsword <dwDecompressedSize
                            jsl calculate_crc32
                            putretptr <dwReadChecksum
                            cmp <dwValidationChecksum
                            bne checksum_error
                            cpx <dwValidationChecksum+2
                            bne checksum_error
                            clc
                            rts

checksum_error              anop
                            assert_brk 'snd chksum'
                            sec
                            rts

; -----------------------------------
read_wave                   anop
                            sec
                            rts

                            end

; -----------------------------------------------------------------------------
; WAVE Translator, Unload
; This will free the data in the data entry
datalib_translator_wave_unload start seg_flib
                            using datalib_errors
; Define our work area data
                            begin_locals
result                      decl word
pData                       decl ptr
work_area_size              end_locals

                            debugtag 'wave_unload'
                            debugtag 'datalib_translator'

                            sub (4:pTypeEntry,4:pDataEntry),work_area_size

; Currently, all that is required is to just release the memory
                            stz <result
                            getword [<pDataEntry],#datalib_data_entry~data_ptr+2
                            tax
                            beq null_data_ptr           ; Assuming if the high word is 0, then it was null
                            getword [<pDataEntry],#datalib_data_entry~data_ptr

                            jsl deallocate_long_fixed_handle_ptr

                            clearptr [<pDataEntry],#datalib_data_entry~data_ptr

null_data_ptr               anop
                            ret 2:result
                            end
