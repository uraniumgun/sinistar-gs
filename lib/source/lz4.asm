; LZ4 Decompression code
                    copy lib/source/debug.definitions.asm

                    mcopy generated/lz4.macros

                    longa on
                    longi on

; -------------------------------------------------------------------------------
; This based on the Brutal Deluxe Sample code.
; - Formatting has changed
; - The code is ssub based
; - The interface uses stack parameters, mostly to allow it so that the destination
;   doesn't have to be at the start of a bank.
;
; Parameters:
; pSource   - long address of the source compressed data
; pDest     - long address of the destination buffer
; wSourceSize - length of the source compressed buffer
;
; Returns: Length of unpacked data in A

lz4_unpack          start seg_flib

; Define our work area data
                    begin_locals
work_area_size      end_locals

                    debugtag 'lz4_unpack'
                    ssub (4:pSource,4:pDest,2:wSourceSize),work_area_size

                    setlocaldatabank

stack_adjust        equ 1

; Patch in the banks
                    shortm
                    lda <pSource+2+stack_adjust,s
                    sta literal_3+2                         ; source for the move literal
                    sta readToken+3                         ; source for the token reader
                    sta match_1+3                           ; source for the match offset
                    sta getLength_1+3                       ; source for the read length
                    lda <pDest+2+stack_adjust,s
                    sta literal_3+1                         ; dest for the move literal
                    sta match_5+1                           ; source for the move matched from uncompressed
                    sta match_5+2                           ; dest for the move matched from uncompressed
                    longm

                    getword {s},#pSource+stack_adjust
                    tax                                     ; source data offset in X
                    clc
                    adcword {s},#wSourceSize+stack_adjust   ; add the size.
                    sta limit+1                             ; set the compare for the end of the source buffer
                    getword {s},#pDest+stack_adjust
                    tay

readToken           lda  >$AA0000,x        ; Read Token Byte
                    inx
                    sta  match_2+1
; ----------------
literal             and  #$00F0             ; >>> Process Literal Bytes <<<
                    beq  limit              ; No Literal
                    cmp  #$00F0
                    bne  literal_1
                    jsr  getLengthLit       ; Compute Literal Length with next bytes
                    bra  literal_2
literal_1           lsr  a                  ; Literal Length use the 4 bit
                    lsr  a
                    lsr  a
                    lsr  a
; --
literal_2           dec  a                 ; Copy A+1 Bytes
literal_3           mvn  $AA0000,$BB0000   ; Copy Literal Bytes from packed data buffer
                    phk                    ; X and Y are auto incremented
                    plb                    ; Have to restore the DBR, because the move opcodes change it to the destination
; ----------------
limit               cpx  #$AAAA            ; End Of Packed Data buffer ?
                    beq  exit
; ----------------
match               tya                    ; >>> Process Match Bytes <<<
                    sec
match_1             sbc >$AA0000,X         ; Match Offset
                    inx
                    inx
                    sta  match_4+1
; --
match_2             lda  #$0000             ; Current Token Value
                    and  #$000F
                    cmp  #$000F
                    bne  match_3
                    jsr  getLengthMat       ; Compute Match Length with next bytes
match_3             clc
                    adc  #$0003             ; Minimum Match Length is 4 (-1 for the MVN)
; --
                    phx
match_4             ldx  #$AAAA            ; Match Byte Offset
match_5             mvn  $BB0000,$BB0000   ; Copy Match Bytes from unpacked data buffer
                    phk                    ; X and Y are auto incremented
                    plb
                    plx
; ----------------
                    bra  readToken
; ----------------
; Sub functions
getLengthLit        lda  #$000F            ; Compute Variable Length (Literal or Match)
getLengthMat        sta  getLength_2+1
getLength_1         lda >$AA0000,X         ; Read Length Byte
                    inx
                    and  #$00FF
                    cmp  #$00FF
                    bne  getLength_3
                    clc
getLength_2         adc  #$000F
                    sta  getLength_2+1
                    bra  getLength_1
getLength_3         adc  getLength_2+1
                    rts
; ----------------
exit                anop
                    tya
                    sec
                    sbcword {s},#pDest+stack_adjust     ; A = Length of unpacked data.  Helpful for validation

                    restoredatabank
                    sret 2:A
                    end
