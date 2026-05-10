;------------------------------------------------------------------------------
; Low-Level Block Shape Functions.
; This file is intended to be included in a parent file, in an enclosing named function
; The function must define an equ for grlib~blit_op, to define what type of blit is to be used.
;
; Op 0:
; This copies the source, with no transformation
;
; lda |src,y                      ; 6, get the source
; sta >dest,x                     ; 6, store on backgroud

; Op 1:
; This colorizes the source, then stores the result
;
; lda |src,y                      ; 6, get the source
; and <fore_color                 ; 4
; sta >dest,x                     ; 6, store on backgroud

                            aif  C:grlib~blit_op<>0,.skip
                            MNOTE 'grlib~blit_op needs to be defined'
.skip

;------------------------------------------------------------------------------
; Copy a block shape to the alt screen buffer
;
; This is the whole-byte version.  No edges!
;
; This is a post clipping function!
; This is does not currently 'tile' the shape by repeating the data.
; It might turn into that, or might be done in another variation of this code.
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

                            lsr <draw_x
; Convert the pixel width into a byte width
                            lda <area_width
                            lsr a
                            adc #0
                            sta <area_width
                            bit #1
                            jne odd_byte_width

; This section assumes there is an even # of bytes across
; acc already has the number of bytes, so number of words * 2
                            tax                         ; We can use the value as an index into our multiplcation table

                            aif  grlib~blit_op<>4,.skip
; Blit 4, needs to patch the mask source
                            lda #even_patch_mask_end        ; 3
                            sec                             ; 2
                            sbc >math~mul6_80,x             ; 6

                            sta |patch_even_mask_jump+1     ; 5

                            lda <mask_offset                ; 4
                            clc                             ; 2
                            adc <area_width                 ; 4
                            sbc #1                          ; 3, we know the carry is clear, so this will - 2, and leave the carry on, which we want.
patch_even_mask_jump        jmp even_patch_mask_end         ; 3
                            UnrolledPatchMaskLoad 1,14,80,even_run_end          ; 8 cycles per patch
even_patch_mask_end         anop
.skip

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
                            aif  grlib~blit_op<>4,.skip
                            sbc >math~mul14_80,x
.skip
                            sta |patch_even_jump+1

; Patch the advance to the next line of pixel data
                            lda <shape_rowbytes       ; advance to the next line
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
                            phb                         ; 3
                            shortm                      ; 3
                            lda <shape_ptr+2            ; 3
                            pha                         ; 3
                            plb                         ; 4
                            longm                       ; 3

                            ldy <shape_ptr
                            jmp patch_even_jump         ; skip into the loop

; Insert the unrolled loop
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
; Blit 4
                            aif  grlib~blit_op<>4,.skip
                            UnrolledBlockShapeBlit4 160,80
.skip
*
even_run_end                anop
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

                            tax                         ; use as an index into a special multiplication table

                            aif  grlib~blit_op<>4,.skip
; Blit 4 needs to patch the mask source
                            dex                         ; -1, we know it was odd
                            lda #odd_patch_mask_end
                            sec
                            sbc >math~mul6_80,x

                            sta |patch_odd_mask_jump+1

                            lda <mask_offset
                            clc
                            adc <area_width
                            sbc #1                          ; 3, we know the carry is clear, so this will - 2, and leave the carry on, which we want.
patch_odd_mask_jump         jmp odd_patch_mask_end
                            UnrolledPatchMaskLoad 1,14,79,blit_4_odd_run_end
odd_patch_mask_end          anop
                            inc a                       ; dec'ed it one too many at the end of the unrolled loop.
                            sta |blit_4_patch_mask_load_0+1
                            inx
.skip
; We know a is odd, but our table accounts for the extra size the last entry, so increment to include it as if it were a word
                            inx

                            lda #odd_run_end
                            sec
                            aif  grlib~blit_op<>0,.skip
                            sbc >math~mul7plus4_80,x    ; Use the special multiplication table that takes into account, the 'odd' one is wrapped in sep/rep, add that separately
.skip
                            aif  grlib~blit_op<>1,.skip
                            sbc >math~mul9plus4_80,x    ; Use the special multiplication table that takes into account, the 'odd' one is wrapped in sep/rep, add that separately
.skip
                            aif  grlib~blit_op<>2,.skip
                            sbc >math~mul23plus4_80,x   ; Use the special multiplication table that takes into account, the 'odd' one is wrapped in sep/rep, add that separately
.skip
                            aif  grlib~blit_op<>4,.skip
                            sbc >math~mul14plus4_80,x   ; Use the special multiplication table that takes into account, the 'odd' one is wrapped in sep/rep, add that separately
.skip
                            sta |patch_odd_jump+1

; Patch the advance to the next line of pixel data
                            lda <shape_rowbytes        ; advance to the next line
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

; Insert the unrolled loop
patch_odd_unrolled          anop
; Blit 0
                            aif  grlib~blit_op<>0,.skip
                            UnrolledBlockCopyShapeLineLoop 159,79
; The last pair just does a byte
                            shortm
                            lda |$0000,y
                            sta >$000000,x
                            longm
.skip
; Blit 1
                            aif  grlib~blit_op<>1,.skip
                            UnrolledBlockShapeBlit1 159,79,<fore_color
; The one just does a byte
                            shortm
                            lda |$0000,y
                            and <fore_color
                            sta >$000000,x
                            longm
.skip
; Blit 2
                            aif  grlib~blit_op<>2,.skip
                            UnrolledBlockShapeBlit2 159,79,<fore_color,<scratch_word
; The one just does a byte
                            shortm
                            lda |$0000,y                ; get the source
                            eor #$ff                    ; make a mask.  could eliminate with a pre-generated mask
                            nop                         ; adding a nop, so that the size and opcode placement of this code is the same as it is in 'long' mode
                            and >$000000,x              ; and with the dest
                            sta <scratch_word           ; temp store
                            lda |$0000,y                ; get the source, again
                            and <fore_color             ; colorize it. If immediate 3
                            ora <scratch_word           ; merge with background
                            sta >$000000,x              ; store on background
                            longm
.skip
; Blit 4
                            aif  grlib~blit_op<>4,.skip
                            UnrolledBlockShapeBlit4 159,79
blit_4_odd_run_end          anop
; The one just does a byte
                            shortm
blit_4_patch_mask_load_0    lda |$0000,y                ; get the mask
                            and >$000000,x              ; and with the dest
                            ora |$0000,y                ; merge the source
                            sta >$000000,x              ; store on background
                            longm
.skip
*
odd_run_end                 anop

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

