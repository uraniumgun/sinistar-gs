                            aif  C:grlib~blit_op<>0,.skip
                            MNOTE 'grlib~blit_op needs to be defined'
.skip

;------------------------------------------------------------------------------
; Copy a block shape to the alt screen buffer
;
; This function assumes there is a 'right-edge', where the last byte keeps the
; right-most pixel from the target buffer and merges in the left pixel
;
; This is a post clipping function!
; This is does not currently 'tile' the shape by repeating the data.
; It might turn into that, or might be done in another variation of this code.
; This function assumes there is at least 1 pixel to draw, i.e. <shape_width and <area_width are not 0
;
; Parameters:
;  <shape_ptr       - shape data.  This should point to the first line if the first clipped byte in the shape.
;                     i.e. if the shape is clipped by 2 lines on the top and 4 bytes on the left, the shape_ptr
;                     should be shape_base_ptr + (byte_width(shape_width) * 2) + 4
;  <shape_width     - the pixel width of the shape data
;  <shape_byte_width - the advance (byte) to the next row in the shape.
;  <area_width      - Width to draw, in pixels.  This can be less that the shape_width, but should not be more.
;  <area_height     - Height to draw, in pixels. This can be less that the shape_height, but should not be more.
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;

; Pixel x to byte x
                            lsr <draw_x
; Convert the pixel width into a byte width
                            lda <area_width
                            lsr a
                            adc #0
                            sta <area_width
                            bit #1
                            jeq odd_byte_width          ; Note, if *even* we are going to the odd byte section, because it will be odd whole bytes, plus the right edge

; We come here with an odd number of bytes total, but we are doing the right edge separate, so the total whole bytes is even

; The lda/sta is 7 bytes, per word
; acc already has the number of bytes, so number of words * 2

                            dec a                       ; - 1, for the right edge byte

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
; Note, <shape_ptr, will have already been indented for any left clipping
                            lda <area_width             ; bytes to draw, rounded up
                            dec a                       ; point to the last source byte on the line
                            sta >patch_even_y_advance1+1
                            sta >patch_even_x_advance1+1
                            negate a
                            clc
                            adc #160
                            sta >patch_even_x_advance2+1
; For the y advance from the end adjustment.
                            lda <shape_rowbytes
                            sec
                            sbc <area_width
                            inc a
                            sta >patch_even_y_advance2+1

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
                            UnrolledBlockCopyShapeLineLoop 160,80
.skip
; Blit 1
                            aif  grlib~blit_op<>1,.skip
                            UnrolledBlockShapeBlit1 160,80,<fore_color
.skip
; Blit 2
                            aif  grlib~blit_op<>2,.skip
                            UnrolledBlockShapeBlit2 160,80,<fore_color,<scratch_word
.skip
even_run_end                anop
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
; The last pair is a word, since we are doing a mask of the source, we don't have to do the grlib~right_pixel_mask, as it will be part of the source mask
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
                            dec <area_height            ; finished?
                            beq even_done

                            txa
patch_even_x_advance2       adc #0                      ; Move to the next line.  No need for a clc, the carry should be clear
                            tax
                            tya
patch_even_y_advance2       adc #0
                            tay
patch_even_jump             jmp |even_run_end

even_done                   plb
                            rts
;-------------------------------------------------------------
; This loop operates if there is an odd number of *whole* bytes across
odd_byte_width              anop
; We come in here with a even value, but we are doing the right byte separate, so the whole bytes are odd
; We don't have to do anything to a, because the odd value adjustment is in the table

                            tax
                            lda #odd_run_end
                            sec
                            aif  grlib~blit_op<>0,.skip
                            sbc >math~mul7plus4_80,x   ; Using the special table that has the extra 4 bytes for the last one, built in.
.skip
                            aif  grlib~blit_op<>1,.skip
                            sbc >math~mul9plus4_80,x   ; Using the special table that has the extra 4 bytes for the last one, built in.
.skip
                            aif  grlib~blit_op<>2,.skip
                            sbc >math~mul23plus4_80,x   ; Using the special table that has the extra 4 bytes for the last one, built in.
.skip
                            sta >patch_odd_jump+1

; Patch the advance to the next line of pixel data
; Note, <shape_ptr, will have already been indented for any left clipping
                            lda <area_width             ; bytes to draw, rounded up
                            dec a                       ; point to the last source byte on the line
                            sta >patch_odd_y_advance1+1
                            sta >patch_odd_x_advance1+1
                            negate a
                            clc
                            adc #160
                            sta >patch_odd_x_advance2+1
; For the y advance from the end adjustment.
                            lda <shape_rowbytes
                            sec
                            sbc <area_width
                            inc a
                            sta >patch_odd_y_advance2+1

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
                            UnrolledBlockCopyShapeLineLoop 159,79
; Manually add the odd byte.  This will be patched by the standard shape copy patcher
                            shortm
                            lda |$0000,y
                            sta >$000000,x
                            longm
.skip
; Blit 1
                            aif  grlib~blit_op<>1,.skip
                            UnrolledBlockShapeBlit1 159,79,<fore_color
; Manually do the odd byte.
                            shortm
                            lda |$0000,y
                            and <fore_color
                            sta >$000000,x
                            longm
.skip
                            aif  grlib~blit_op<>2,.skip
                            UnrolledBlockShapeBlit2 159,79,<fore_color,<scratch_word
; Manually do the odd byte.
                            shortm
; The last pair is a word, since we are doing a mask of the source, we don't have to do the grlib~left_pixel_mask, as it will be part of the source mask
                            lda |$0000,y                ; get the source
                            eor #$ff                    ; make a mask.  could eliminate with a pre-generated mask
                            nop                         ; nop to make this code the same size and position of the 'long' version
                            and >$000000,x              ; and with the dest
                            sta <scratch_word           ; temp store
                            lda |$0000,y                ; get the source, again
                            and <fore_color             ; colorize it. If immediate 3
                            ora <scratch_word           ; merge with background
                            sta >$000000,x              ; store on background
                            longm
.skip
odd_run_end                 anop
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
.skip
; Blit 1
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
                            aif  grlib~blit_op<>2,.skip
                            shortm
; The last pair is a word, since we are doing a mask of the source, we don't have to do the grlib~right_pixel_mask, as it will be part of the source mask
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
patch_odd_y_advance2        adc #0
                            tay
patch_odd_jump              jmp |odd_run_end

odd_done                    plb
                            rts

