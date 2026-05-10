                        copy lib/source/debug.definitions.asm

                        mcopy generated/zx0.macros

                        longa on
                        longi on

; -------------------------------------------------------------------------------
; ZX0 Decompression
;
; This based on the Salvador Decompress C code.
;
; This assumes the destination buffer is large enough for the decompressed data.
; This assumes that the format is the ZX0 V2 format (FLG_IS_INVERTED flag set in the Salvador compressor)
; This assumes that the compression is FORWARD (FLG_IS_BACKWARD is off in the Salvador compressor)
;
; Parameters:
; pSource       - long address of the source compressed data
; pDest         - long address of the destination buffer
; wSourceSize   - length of the source compressed buffer
;
; Returns:
; carry clear and length of decompressed data in acc.
; carry set on error.
;

zx0_unpack              start seg_flib

; Define our work area data
                        begin_locals
wMatchWithOffset        decl word
wCurBit                 decl word
wBits                   decl word
wMatchOffset            decl word
wMatchLen               decl word
wMatchOffsetPrefix      decl word
wValue                  decl word
pSourceEnd              decl ptr
pDestStart              decl ptr
work_area_size          end_locals

                        debugtag 'zx0_unpack'
                        sub (4:pSource,4:pDest,2:wSourceSize),work_area_size

                        setlocaldatabank
; Using the MVN opcode to move bytes around, patch the bank
                        shortm
                        lda <pSource+2
                        sta patch_bank+2                ; source bank goes into the high-byte of the move opcode
                        lda <pDest+2
                        sta patch_bank+1                ; dest bank goes into the low-byte
                        sta patch_bank2+1               ; the second move is a dest-to-dest copy
                        sta patch_bank2+2
                        longm

                        stz <wCurBit                    ; Values are 0-7, and we are testing, post decrement
                        stz <wBits
                        lda #1
                        sta <wMatchOffset
; Store and end pointer
                        lda <pSource
                        clc
                        adc <wSourceSize
                        sta <pSourceEnd
; Not expecting to cross a bank.  Could leave this out
                        lda <pSource+2
                        adc #0
                        sta <pSourceEnd+2
; Save the starting location, so we can return the size
                        lda <pDest
                        sta <pDestStart

; Always start with a literal
                        bra has_literal

loop                    anop
                        jsr read_bit
;                       bvs error_exit
                        bcs has_match_with_offset

has_literal             anop
; Next value is the number of literals
                        jsr read_elias

; Should check source / dest ranges here.
; Copy the literals
                        ldx <pSource
                        ldy <pDest
                        dec a                           ; size - 1
patch_bank              mvn $AA,$BB                     ; use mvn, so X and Y advance, and we can just store there state when the copy is complete

                        stx <pSource
                        sty <pDest
; Read match-with-offset bit
                        jsr read_bit
;                       bvs error_exit
                        bcc no_match_with_offset

has_match_with_offset   anop
; Read the high byte of the offset
                        jsr read_elias_inverted
                        cmp #256
                        beq done
                        dec a
                        shiftleft 7
                        sta <wMatchOffset
; Check the source against the end for safety?

; The low byte is just stored as-is, no encoding
                        lda [<pSource]
                        and #$00ff                      ; strip off the high bits
                        sta <wMatchOffsetPrefix
                        inc <pSource
                        lsr a
; We want 127 - A, so negate A and add 127
                        negate a
                        clc
                        adc #127
                        ora <wMatchOffset
                        inc a
                        sta <wMatchOffset
                        jsr read_elias_prefix
                        inc a
                        sta <wMatchLen
                        bra copy_match_bytes

no_match_with_offset    anop
                        jsr read_elias
                        sta <wMatchLen

copy_match_bytes        anop
; Copy bytes from back in the decompressed buffer, to the current location
; We should check if the source / dest offsets are out of range.
                        lda <pDest
                        sec
                        sbc <wMatchOffset
                        tax                                 ; source in x
                        ldy <pDest                          ; destination in y
                        lda <wMatchLen
                        dec a                               ; length - 1
patch_bank2             mvn $AA,$BB

                        sty <pDest                          ; save the destination position
                        bra loop

error_exit              sec
                        stz <pDestStart
                        bra exit

; Done with the decompression.
done                    anop
                        lda <pDest
                        sec
                        sbc <pDestStart
                        sta <pDestStart                     ; the length of the decompressed data
                        clc

exit                    plb

                        retkc 2:pDestStart

;; Local Functions

; Read an elias coded value at the current location.
; zx0 uses a type of Elias Gamma Coding for packing its numbers
; https://en.wikipedia.org/wiki/Elias_gamma_coding
; However the bits are interlaced.  This seems to work more like a stop-bit.
; A bit of 0, means the next bit is 'valid', and should be shifted in.
; A bit of 1, means stop.
; The reading always assumes at least a value of 1 to start, since
; a length of 0 is not needed and the compressor always starts with
; a literal, so there will never be an offset of 0.
;

; Assumes we will not read a value larger that 16-bits.
read_elias              anop
                        lda #1                              ; starting value of 1
                        sta <wValue

read_elias_loop         jsr read_bit
                        bcs read_elias_done
; The next bit is part of the value.
                        jsr read_bit
                        rol <wValue
                        bra read_elias_loop

read_elias_done         lda <wValue
                        rts

; Read an elias gamma value at the current location,
; inverting the bits.
; Assumes we will not read a value larger that 16-bits.
read_elias_inverted     anop
                        lda #1
                        sta <wValue

read_elias_inv_loop     jsr read_bit
                        bcs read_elias_inv_done
; The next bit is part of the value.
                        jsr read_bit_inverted
                        rol <wValue
                        bra read_elias_inv_loop

read_elias_inv_done     lda <wValue
                        rts

; Read an elias gamma value at the current location
; This assumes the the first bit has already been read
; and is in wMatchOffsetPrefix
; Assumes we will not read a value larger that 16-bits.
read_elias_prefix       anop
                        lda #1
                        bit <wMatchOffsetPrefix         ; test the prefix bit
                        bne prefix_set                  ; it is set, so just return the 1
                        sta <wValue

                        jsr read_bit
                        rol <wValue

read_elias_prefix_loop  jsr read_bit
                        bcs read_elias_prefix_done
; The next bit is part of the value.
                        jsr read_bit
                        rol <wValue
                        bra read_elias_prefix_loop

read_elias_prefix_done  lda <wValue
prefix_set              rts

; Read a bit from the current bit cache.
; wCurBit  -   contains the bit counter remaining in the caches byte
; wBits    -   contains the current bits.  This is 16-bit, but only the lower 8-bits are used.
; pSource  -   is the current read position.
; pSourceEnd - is the end of the read buffer
;
; Returns carry clear if the bit was 0, carry set if it was 1
; overflow flag is set, if the read was off the end of the source buffer
;
read_bit                anop

                        shortm                      ; 3
                        dec <wCurBit                ; 6
                        bmi next_byte               ; 2-3
; Read the next bit in the cached byte, into the carry flag
                        asl <wBits                  ; 6
                        longm                       ; 3
                        rts

                        longa off                   ; let the assembler know we are still in 8-bit mode
next_byte               anop
; Test to see if we are at the end.  Only checking the short-pointer.
;                       longm
;                       lda <pSource
;                       cmp <pSourceEnd
;                       bge read_bit_end            ; reached the end?
;                       shortm

                        lda #7                      ; 2 set that we are on the 7th bit
                        sta <wCurBit                ; 4
; Not at the end, read the bits
                        lda [<pSource]              ; 6 get the bits.  Yes, this can read one past the end
                        asl a                       ; 2 shift up
                        sta <wBits                  ; 4 store remaining bits
                        longm                       ; 3
                        inc <pSource                ; 6 next byte in the source
                        rts

read_bit_end            sep #%01000001              ; sev and sec in one
                        rts

; Same as read_bit, but the source bit is inverted
read_bit_inverted       anop

                        shortm
                        dec <wCurBit
                        bmi next_byte_inv
; Read the next bit in the cached byte, into the carry flag, flipping its state.
                        asl <wBits                  ; 6
                        longm                       ; 3
                        bcs do_clc                  ; 2-3
                        sec                         ; 2
                        rts
do_clc                  clc                         ; 2
                        rts

                        longa off                   ; let the assembler know we are still in 8-bit mode
next_byte_inv           anop
; Test to see if we are at the end.  Only checking the short-pointer.
;                       longm
;                       lda <pSource
;                       cmp <pSourceEnd
;                       bge read_bit_end            ; reached the end?
;                       shortm
; Not at the end, read the bits
                        lda #7                      ; set that we are on the 7th bit
                        sta <wCurBit
                        lda [<pSource]              ; get the bits
                        asl a                       ; shift up
                        sta <wBits                  ; store remaining bits
                        longm
                        inc <pSource                ; next byte in the source
                        bcs do_clc
                        sec
                        rts


read_bit_inv_end        sep #%01000001              ; sev and sec in one
                        rts

                        end



