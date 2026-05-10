; -----------------------------------------------------------------------
; Fill Area, assuming there is a left edge on each line (LE), unrolled.
; This is meant to be included, inline, inside a segment so as to
; share patched code between functions that differ, only by the patched
; destination.

; Patch in the fill pattern
                            sta >patch_even_load+1
                            sta >patch_odd_load+1
                            shortm
                            and #grlib~right_pixel_mask
                            sta >patch_even_merge_edge+1
                            sta >patch_odd_merge_edge+1
                            longm

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
; That are patched so that the X can access any location in the buffers.
patch_even_unrolled         StoreLineLoop 80
*
even_run_end                anop

                            shortm
patch_even_load_edge        lda >$000000,x
                            and #grlib~left_pixel_mask
patch_even_merge_edge       ora #$00
patch_even_store_edge       sta >$000000,x
                            longm

                            dey                         ;finished?
                            beq even_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax
patch_even_load             lda #$0000
patch_even_jump             jmp |even_run_end

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
;                           clc                         ; asl will have cleared this
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
; That are patched so that the X can access any location in the buffers.
patch_odd_unrolled          StoreLineLoop 79
; The last just does a byte
                            shortm
                            sta >$000000,x
                            longm
*
odd_run_end                 anop
; Do the edge.  It is noted, that we just did another single-byte above, so why not merge them and do a word?
; Well, we have to support that the 'run' will resolve to 0, at least for now.  What we might want to do is to special case
; <area_width being 0 and just call the vline function, then we *could* assume that we could do a word.
                            shortm
patch_odd_load_edge         lda >$000000,x
                            and #grlib~left_pixel_mask
patch_odd_merge_edge        ora #$00
patch_odd_store_edge        sta >$000000,x
                            longm

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
                            pushsword #1                         ; data adress offset, here we are making the unrolled stop at offset 1, the left-edge is separate
                            pushsword #80                        ; patch count
                            jsr _grlib_patch_unrolled_word_store_even

                            pushptr #patch_odd_unrolled         ; starting address of the code to patch
                            pushsword #1                         ; offset in the code to patch, usually 1 to skip the opcode, but can be more
                            pushptr <patch_ptr                  ; data address to patch in
                            pushsword #1                         ; data adress offset, here we are making the unrolled stop at offset 1, the left-edge is separate
                            pushsword #80                        ; patch count
                            jsr _grlib_patch_unrolled_word_store_odd

                            lda <patch_ptr
                            sta >patch_even_load_edge+1
                            sta >patch_even_store_edge+1
                            sta >patch_odd_load_edge+1
                            sta >patch_odd_store_edge+1
                            shortm
                            lda <patch_ptr+2
                            sta >patch_even_load_edge+3
                            sta >patch_even_store_edge+3
                            sta >patch_odd_load_edge+3
                            sta >patch_odd_store_edge+3
                            longm

                            rts
