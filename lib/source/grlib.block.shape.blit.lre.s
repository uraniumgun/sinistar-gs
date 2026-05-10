                            aif  C:grlib~blit_op<>0,.skip
                            MNOTE 'grlib~blit_op needs to be defined'
.skip

;------------------------------------------------------------------------------
; Copy a block shape to the alt screen buffer
;
; This function assumes the there is a 'left-edge', where the first byte
; keeps the left-most pixel from the target buffer and merges in the right pixel.
; It also assumes there is a 'right-edge', where the last byte keeps the
; right-most pixel from the target buffer and merges in the left pixel
;
; This is a post clipping function!
; This is does not currently 'tile' the shape by repeating the data.
; It might turn into that, or might be done in another variation of this code.
; This function assumes there is at least 1 pixel to draw, i.e. <shape_width and <area_width are not 0
; We can also assume, that since there is a left and right edge, no horizontal clipping has been done,
; since if there was, one of the edges would not be needed
;
; Parameters:
;  <shape_ptr       - shape data.  This should point to the first line if the first clipped byte in the shape.
;                     i.e. if the shape is clipped by 2 lines on the top and 4 bytes on the left, the shape_ptr
;                     should be shape_base_ptr + (byte_width(shape_width) * 2) + 4
;  <shape_width     - the pixel width of the shape data
;  <shape_byte_width - the width of the shape in bytes
;  <shape_rowbytes  - the advance (byte) to the next row in the shape.
;  <area_width      - Width to draw, in pixels.  This can be less that the shape_width, but should not be more.
;  <area_height     - Height to draw, in pixels. This can be less that the shape_height, but should not be more.
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;

; Pixel x to byte x
                            lsr <draw_x
                            lda <shape_byte_width                   ; We know that we are not clipped horizontally, so use the pre-calculated byte width
                            bit #1
                            jne odd_byte_width

; This section assumes there is an even # of bytes across
; So really, this code will never be run.  The reason is that we only have a left and right edge when the pixel width of
; the source data is even, but we are using the odd-shifted data, so the byte width ends up being odd.
; Also, we know that we are not clipped, because that would remove one of the edges, and another function would have been called
; I'm leaving in this section for completeness.

; The lda/sta is 7 bytes, per word
; acc already has the number of bytes, so number of words * 2

                            dec a                       ; - 2, there is a byte on either side.
                            dec a

                            tax
; Patch where we will jump into the unrolled loop
                            lda #even_run_end
                            sec
                            aif  grlib~blit_op<>0,.skip
                            sbc >math~mul7_256,x
.skip
                            aif  grlib~blit_op<>1,.skip
                            sbc >math~mul9_80,x
.skip
                            aif  grlib~blit_op<>2,.skip
                            sbc >math~mul23_80,x
.skip
                            sta >patch_even_jump+1

; Patch the advance to the next line of pixel data
                            lda <shape_byte_width       ; We know that we are not clipped horizontally, so use the pre-calculated byte width
                            dec a                       ; point to the last byte on the line
                            sta >patch_even_y_advance1+1
                            sta >patch_even_x_advance1+1
                            negate a
                            pha
                            clc
                            adc #160
                            sta >patch_even_x_advance2+1
                            pla
                            clc
                            adc <shape_rowbytes
                            sta >patch_even_y_advance2+1
; Note we can assume that we can just advance y to the next byte to get to the beginning of the next line, because there is no clipping on the left.

; Get the destination offset
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; carry will be clear from asl above
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

; Save the data bank, we will set it to where the sprite data lives.
                            phb
                            shortm
                            lda <shape_ptr+2
                            pha
                            plb
                            longm

                            ldy <shape_ptr
                            jmp patch_even_jump         ; skip into the loop

patch_even_unrolled         anop
; Blit 0
                            aif  grlib~blit_op<>0,.skip
                            UnrolledBlockCopyShapeLineLoop 161,80
even_run_end                anop
; The left edge
                            shortm
patch_even_le_load          lda >$000000,x
                            and #grlib~left_pixel_mask
                            ora |$0000,y
patch_even_le_store         sta >$000000,x
                            longm
.skip
; Blit 1
                            aif  grlib~blit_op<>1,.skip
                            UnrolledBlockShapeBlit1 161,80,<fore_color
even_run_end                anop
; The left edge
                            shortm
                            lda |$0000,y
                            and <fore_color
                            sta <scratch_word
patch_even_le_load          lda >$000000,x
                            and #grlib~left_pixel_mask
                            ora <scratch_word
patch_even_le_store         sta >$000000,x
                            longm
.skip
; Blit 2
                            aif  grlib~blit_op<>2,.skip
                            UnrolledBlockShapeBlit2 161,80,<fore_color,<scratch_word
even_run_end                anop
; The left edge
                            shortm
; The last pair is a word, since we are doing a mask of the source, we don't have to do the grlib~left_pixel_mask, as it will be part of the source mask
                            lda |$0000,y                ; get the source
                            eor #$ff                    ; make a mask.  could eliminate with a pre-generated mask
patch_even_le_load          and >$000000,x              ; and with the dest
                            sta <scratch_word           ; temp store
                            lda |$0000,y                ; get the source, again
                            and <fore_color             ; colorize it. If immediate 3
                            ora <scratch_word           ; merge with background
patch_even_le_store         sta >$000000,x              ; store on background
                            longm
.skip
; The right egde.  The x and y need to be adjusted
                            txa
patch_even_x_advance1       adc #0                      ; This will be patched to advance to the right edge *byte*
                            tax
                            tya
patch_even_y_advance1       adc #0
                            tay
; Blit 0
                            aif  grlib~blit_op<>0,.skip
                            shortm
patch_even_re_load          lda >$000000,x
                            and #grlib~right_pixel_mask
                            ora |$0000,y
patch_even_re_store         sta >$000000,x
                            longm
.skip
; Blit 1
                            aif  grlib~blit_op<>1,.skip
                            shortm
                            lda |$0000,y
                            and <fore_color
                            sta <scratch_word
patch_even_re_load          lda >$000000,x
                            and #grlib~right_pixel_mask
                            ora <scratch_word
patch_even_re_store         sta >$000000,x
                            longm
.skip
; Blit 2
                            aif  grlib~blit_op<>2,.skip
                            shortm
                            lda |$0000,y                ; get the source
                            eor #$ff                    ; make a mask.  could eliminate with a pre-generated mask
patch_even_re_load          and >$000000,x              ; and with the dest
                            sta <scratch_word           ; temp store
                            lda |$0000,y                ; get the source, again
                            and <fore_color             ; colorize it. If immediate 3
                            ora <scratch_word           ; merge with background
patch_even_re_store         sta >$000000,x              ; store on background
                            longm
.skip
*
                            dec <area_height            ; finished?
                            beq even_done

                            txa
patch_even_x_advance2       adc #0                      ; Move to the next line.  No need for a clc, the carry should be clear
                            tax
                            tya
patch_even_y_advance2       adc #0                      ; Move to the next line.  No need for a clc, the carry should be clear
                            tay
patch_even_jump             jmp |even_run_end

even_done                   plb
                            rts
;-------------------------------------------------------------
; This loop operates if there is an odd number of bytes across
odd_byte_width              anop
                            dec a                       ; Make positive, this will account for the right side byte
                            dec a                       ; dec another 2 bytes, as we are doing the left side byte, as a whole word, which will leave the middle section as words too.
                            dec a
; The above would be 1 cycles quicker to do a sec then sbc #3

                            tax
                            lda #odd_run_end
                            sec
                            aif  grlib~blit_op<>0,.skip
                            sbc >math~mul7_256,x
.skip
                            aif  grlib~blit_op<>1,.skip
                            sbc >math~mul9_80,x
.skip
                            aif  grlib~blit_op<>2,.skip
                            sbc >math~mul23_80,x
.skip
                            sta >patch_odd_jump+1

; Patch the advance to the next line of pixel data
                            lda <shape_byte_width       ; We know that we are not clipped horizontally, so use the pre-calculated byte width
                            dec a                       ; point to the last source byte on the line
                            sta >patch_odd_y_advance1+1
                            sta >patch_odd_x_advance1+1
                            negate a
                            pha
                            clc
                            adc #160
                            sta >patch_odd_x_advance2+1
                            pla
                            clc
                            adc <shape_rowbytes
                            sta >patch_odd_y_advance2+1
; Note we can assume that we can just advance y to the next byte to get to the beginning of the next line, because there is no clipping on the left.

; Get the destination offset
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; carry will be clear from asl above
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

; Save the data bank, we will set it to where the sprite data lives.
                            phb
                            shortm
                            lda <shape_ptr+2
                            pha
                            plb
                            longm

                            ldy <shape_ptr
                            jmp patch_odd_jump         ; skip the update of X on the first one, we have the correct value

patch_odd_unrolled          anop
; Blit 0
                            aif  grlib~blit_op<>0,.skip
                            UnrolledBlockCopyShapeLineLoop 162,80
odd_run_end                 anop
; With an odd number and bytes, but left and right edges, that means that the left side is a whole word, 1 whole byte and the edge byte
patch_odd_le_load           lda >$000000,x
                            and #grlib~left_pixel_mask
                            ora |$0000,y
patch_odd_le_store          sta >$000000,x
.skip
; Blit 1
                            aif  grlib~blit_op<>1,.skip
                            UnrolledBlockShapeBlit1 162,80,<fore_color
odd_run_end                 anop
; With an odd number and bytes, but left and right edges, that means that the left side is a whole word, 1 whole byte and the edge byte
                            lda |$0000,y
                            and <fore_color
                            sta <scratch_word
patch_odd_le_load           lda >$000000,x
                            and #grlib~left_pixel_mask
                            ora <scratch_word
patch_odd_le_store          sta >$000000,x
.skip
; Blit 2
                            aif  grlib~blit_op<>2,.skip
                            UnrolledBlockShapeBlit2 162,80,<fore_color,<scratch_word
odd_run_end                 anop
; With an odd number and bytes, but left and right edges, that means that the left side is a whole word, 1 whole byte and the edge byte
; We don't have to do the grlib~left_pixel_mask, as it will be part of the source mask
                            lda |$0000,y                ; get the source
                            eor #$ffff                  ; make a mask.  could eliminate with a pre-generated mask
patch_odd_le_load           and >$000000,x              ; and with the dest
                            sta <scratch_word           ; temp store
                            lda |$0000,y                ; get the source, again
                            and <fore_color             ; colorize it. If immediate 3
                            ora <scratch_word           ; merge with background
patch_odd_le_store          sta >$000000,x              ; store on background

.skip
; The right egde.  The x and y need to be adjusted
                            txa
patch_odd_x_advance1        adc #0
                            tax
                            tya
patch_odd_y_advance1        adc #0
                            tay
; Blit 0
                            aif  grlib~blit_op<>0,.skip
                            shortm
patch_odd_re_load           lda >$000000,x
                            and #grlib~right_pixel_mask
                            ora |$0000,y
patch_odd_re_store          sta >$000000,x
                            longm
; Blit 1
.skip
                            aif  grlib~blit_op<>1,.skip
                            shortm
                            lda |$0000,y
                            and <fore_color
                            sta <scratch_word
patch_odd_re_load           lda >$000000,x
                            and #grlib~right_pixel_mask
                            ora <scratch_word
patch_odd_re_store          sta >$000000,x
                            longm
.skip
; Blit 2
.skip
                            aif  grlib~blit_op<>2,.skip
                            shortm
                            lda |$0000,y                ; get the source
                            eor #$ff                    ; make a mask.  could eliminate with a pre-generated mask
patch_odd_re_load           and >$000000,x              ; and with the dest
                            sta <scratch_word           ; temp store
                            lda |$0000,y                ; get the source, again
                            and <fore_color             ; colorize it. If immediate 3
                            ora <scratch_word           ; merge with background
patch_odd_re_store          sta >$000000,x              ; store on background
                            longm
.skip
*
                            dec <area_height            ; finished?
                            beq odd_done

                            txa
patch_odd_x_advance2        adc #0                      ; Move to the next line.  No need for a clc, the carry should be clear
                            tax
                            tya
patch_odd_y_advance2        adc #0                      ; Move to the next line.  No need for a clc, the carry should be clear
                            tay
patch_odd_jump              jmp |odd_run_end

odd_done                    plb
                            rts




