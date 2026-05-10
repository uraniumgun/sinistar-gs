
                            aif  C:grlib~blit_op<>0,.skip
                            MNOTE 'grlib~blit_op needs to be defined'
.skip

;------------------------------------------------------------------------------
; Copy a block shape to the alt screen buffer
;
; This function assumes the there is a 'left-edge', where the first byte
; keeps the left-most pixel from the target buffer and merges in the right pixel.
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
;  <shape_width     - the pixel width of the shape data.
;  <shape_rowbytes  - the advance (byte) to the next row in the shape.
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
                            jne odd_byte_width

; This routine assumes there is an even # of bytes across

; The lda/sta is 7 bytes, per word
; acc already has the number of bytes, so number of words * 2

                            dec a                       ; - 2, the last pair is special
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
                            lda <shape_rowbytes
                            sta >patch_even_add+1

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
                            UnrolledBlockCopyShapeLineLoop 162,80
even_run_end                anop
; The last pair is a word
patch_even_le_load          lda >$000000,x
                            and #grlib~left_pixel_mask
                            ora |$0000,y
patch_even_le_store         sta >$000000,x
.skip
; Blit 1
                            aif  grlib~blit_op<>1,.skip
                            UnrolledBlockShapeBlit1 162,80,<fore_color
even_run_end                anop
; The last pair is a word
                            lda |$0000,y
                            and <fore_color
                            sta <scratch_word
patch_even_le_load          lda >$000000,x
                            and #grlib~left_pixel_mask
                            ora <scratch_word
patch_even_le_store         sta >$000000,x
.skip
; Blit 2
                            aif  grlib~blit_op<>2,.skip
                            UnrolledBlockShapeBlit2 162,80,<fore_color,<scratch_word
even_run_end                anop
; The last pair is a word, since we are doing a mask of the source, we don't have to do the grlib~left_pixel_mask, as it will be part of the source mask
                            lda |$0000,y                ; get the source
                            eor #$ffff                  ; make a mask.  could eliminate with a pre-generated mask
patch_even_le_load          and >$000000,x              ; and with the dest
                            sta <scratch_word           ; temp store
                            lda |$0000,y                ; get the source, again
                            and <fore_color             ; colorize it. If immediate 3
                            ora <scratch_word           ; merge with background
patch_even_le_store         sta >$000000,x              ; store on background
.skip
*
                            dec <area_height            ; finished?
                            beq even_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax
                            tya
patch_even_add              adc #$0000
                            tay
patch_even_jump             jmp |even_run_end

even_done                   plb
                            rts
;-------------------------------------------------------------
; This loop operates if there is an odd number of bytes across
odd_byte_width              anop
                            dec a                       ; We know we were odd, so dec to be even
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
                            lda <shape_byte_width
                            sta >patch_odd_add+1

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
                            UnrolledBlockCopyShapeLineLoop 161,80
odd_run_end                 anop
; The last pair just does a byte
                            shortm
patch_odd_le_load           lda >$000000,x
                            and #grlib~left_pixel_mask
                            ora |$0000,y
patch_odd_le_store          sta >$000000,x
                            longm
.skip
; Blit 1
                            aif  grlib~blit_op<>1,.skip
                            UnrolledBlockShapeBlit1 161,80,<fore_color
odd_run_end                 anop
; The last pair just does a byte
                            shortm
                            lda |$0000,y
                            and <fore_color
                            sta <scratch_word
patch_odd_le_load           lda >$000000,x
                            and #grlib~left_pixel_mask
                            ora <scratch_word
patch_odd_le_store          sta >$000000,x
                            longm
.skip
; Blit 2
                            aif  grlib~blit_op<>2,.skip
                            UnrolledBlockShapeBlit2 161,80,<fore_color,<scratch_word
odd_run_end                 anop
; The last pair just does a byte
                            shortm
                            lda |$0000,y                ; get the source
                            eor #$ff                    ; make a mask.  could eliminate with a pre-generated mask
patch_odd_le_load           and >$000000,x              ; and with the dest
                            sta <scratch_word           ; temp store
                            lda |$0000,y                ; get the source, again
                            and <fore_color             ; colorize it. If immediate 3
                            ora <scratch_word           ; merge with background
patch_odd_le_store          sta >$000000,x              ; store on background
                            longm
.skip
                            dec <area_height            ; finished?
                            beq odd_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax
                            tya
patch_odd_add               adc #$0000
                            tay
patch_odd_jump              jmp |odd_run_end

odd_done                    plb
                            rts
