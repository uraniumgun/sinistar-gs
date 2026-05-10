                    copy lib/source/debug.definitions.asm
                    copy lib/source/system.ids.asm
                    copy lib/source/object.definitions.asm
                    copy lib/source/sndlib.riff.definitions.asm

                    mcopy generated/sndlib.riff.macros

                    longa on
                    longi on

; -----------------------------------------------------------------------------
; Functions to read a RIFF header for audio files.

; -----------------------------------------------------------------------------
; This assumes the input pHeader, is pointing to the top of the RIFF header.
; It also assumes all of the file is in memory.
riff_find_chunk     start seg_flib

                    begin_locals
pEnd                decl ptr
work_area_size      end_locals

                    sub (4:pHeader,4:chunkID),work_area_size

; Note, we are going to assume that we don't support files over 64k total.

; Get a pointer to the end of the file, so we can know to stop, in case there is some issue with the header.
; Though if the header is wrong, maybe the size is wrong too.
                    getword [<pHeader],#master_riff_header~total_size
                    clc
                    adc #8
                    adc <pHeader
                    putword <pEnd
                    lda <pHeader+2
                    sta <pEnd+2

; Point to the first chunk header
                    lda <pHeader
                    clc
                    adc #sizeof~master_riff_header
                    sta <pHeader

loop                getword [<pHeader]
                    cmp <chunkID
                    bne next_chunk
                    getword [<pHeader],#2
                    cmp <chunkID+2
                    beq found

next_chunk          getword [<pHeader],#4
                    clc
                    adc #8
                    adc <pHeader
                    sta <pHeader
                    cmp <pEnd
                    blt loop

                    stz <pHeader
                    stz <pHeader+2
                    sec
                    bra exit

; Return will point to the length
found               lda <pHeader
                    clc
                    adc #4
                    sta <pHeader
                    clc

exit                retkc 4:pHeader
                    end
