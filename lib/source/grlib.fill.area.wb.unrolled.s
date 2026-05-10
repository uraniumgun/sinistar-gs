; -----------------------------------------------------------------------
; Fill Area Whole Bytes (WB), unrolled.
; This is meant to be included, inline, inside a segment so as to
; share patched code between functions that differ, only by the patched
; destination.

; Patch in the fill pattern
                            sta >patch_even_load+1
                            sta >patch_odd_load+1

                            lda <area_width
                            bit #1
                            jne odd_byte_width
; If we get here, we start on an even pixel, so the left most pixel in the byte and we have an even number
; of bytes across, which will be at least 2, meaning we can do this in whole words.

; The sta is conveniently 4 bytes.
; acc already has the number of bytes, so number of words * 2, so we just need to asl one more times to get 4
                            asl a
; Invert and add to the run end, to get the jump location.  Not doing a clc, the asl above will have cleared it.
                            negate a
                            adc #even_run_end
                            sta >patch_even_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            jmp patch_even_load         ; skip the update of X on the first one, we have the correct value

; Insert the unrolled loop
; this 80 of
;        sta >$000000,x
; That are patched so that the X can access any location in the buffer.
patch_even_unrolled         StoreLineLoop 80
*
even_run_end                anop
*
                            dey                         ;finished?
                            beq even_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax
patch_even_load             lda #$0000
patch_even_jump             jmp |even_run_end           ; per-line overhead is 17 cycles

even_done                   rts
;--------------------------------------------
; If we get here, we start on an even pixel on the left, and have an even number of pixels across,
; but it is not divisible by 4, so an odd number of bytes.  We can do N number of words, then
; a final byte
odd_byte_width              anop
                            dec a                       ; Strip off the odd count
; acc already has the number of bytes, so number of words * 2, so we just need to asl one more times to get 4
                            asl a
; The 'odd' one is wrapped in sep/rep, add that separately
;                           clc                             ; asl will have cleared this
                            adc #4+2+2
; Invert and add to the run end, to get the jump location.  Not doing a clc, the asl above will have cleared it.
                            negate a
                            adc #odd_run_end
                            sta >patch_odd_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            jmp patch_odd_load         ; skip the update of X on the first one, we have the correct value

; Insert the unrolled loop
; this 79 of
;        sta >$000000,x
; That are patched so that the X can access any location in the buffer.
patch_odd_unrolled          StoreLineLoop 79
; The last just does a byte
                            shortm
                            sta >$000000,x
                            longm
*
odd_run_end                 anop

                            dey                         ;finished?
                            beq odd_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

patch_odd_load              lda #$0000
patch_odd_jump              jmp |odd_run_end

odd_done                    rts

; -----------------------------------------------------------------------------
_patch_it                   anop

                            pushptr #patch_even_unrolled        ; starting address of the code to patch
                            pushsword #1                         ; offset in the code to patch, usually 1 to skip the opcode, but can be more
                            pushptr <patch_ptr                  ; data address to patch in
                            pushsword #0                         ; data adress offset
                            pushsword #80                        ; patch count
                            jsr _grlib_patch_unrolled_word_store_even

                            pushptr #patch_odd_unrolled
                            pushsword #1                         ; offset in the code to patch, usually 1 to skip the opcode, but can be more
                            pushptr <patch_ptr                 ; data address to patch in
                            pushsword #0                         ; data adress offset
                            pushsword #80                        ; patch count
                            jsr _grlib_patch_unrolled_word_store_odd
                            rts

