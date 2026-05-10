                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            mcopy generated/grlib.blockshape.macros

                            longa on
                            longi on

;------------------------------------------------------------------------------
; Draw a block/solid shape.
; This will clip against the global clip rect
;
; Parameter:
; <shape_ptr        - pointer to the shape data
; <shape_width      - shape's pixel width
; <shape_height     - shape's pixel height
; <draw_x           - draw location x
; <draw_y           - draw location y
_block_shape_draw           start seg_grlib_blit
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_block_shape_jmps
                            using math_tables

                            debugtag '_block_shape_draw'
; If we are doing a profile, we have to do this little hack, because of the way we normally jump out
                            AIF C:debug~profile=0,.skip
                            profile_function_begin
                            jsl profile_entry
                            profile_function_end
                            rtl
profile_entry               anop
.skip

                            phd
                            lda >grlib~dp
                            tcd

                            setlocaldatabank

;                           keyed_break 0,'_block_shape_draw'

                            stz |data_has_left_edge
                            stz <scratch_word

                            lda <shape_width
                            sta <area_width
                            lsr a
                            adc #0                                      ; round up
                            sta <shape_byte_width                       ; byte width
                            sta <shape_rowbytes                         ; rowbytes is the same

                            lda <shape_height
                            sta <area_height

; Before clipping, see if we need to use the pre-shifted data
                            lda <draw_x
                            bit #1
                            beq no_shifted
                            ldy #shapedef~odd_data_offset
                            lda [<shape_ptr],y
                            beq no_shifted
; setup any mask mask offset, gotta do this now, before adjusting the pointer
                            tax
                            ldy #shapedef~odd_mask_offset
                            lda [<shape_ptr],y
                            sta <mask_offset
                            txa

                            clc
                            adc <shape_ptr
                            sta <shape_ptr
                            lda <shape_width
                            bit #1
                            bne width_is_odd
                            inc <scratch_word
                            inc <shape_byte_width                       ; The pixel width was even, but adding the 1 pixel indent will make it one byte wider
                            inc <shape_rowbytes                         ; rowbytes is the same
width_is_odd                anop
                            inc |data_has_left_edge
                            bra has_shifted
no_shifted                  anop
; setup any mask mask offset
                            ldy #shapedef~even_mask_offset
                            lda [<shape_ptr],y
                            sta <mask_offset
; Skip the header
                            lda <shape_ptr
                            clc
                            adc #sizeof~shapedef_header
                            sta <shape_ptr
has_shifted                 anop
; Clip the rect that is defined by <draw_x, <draw_y, <area_width, <area_height
                            jsl _clip_shape_coords
                            bcs exit

                            lda <shape_y_offset
                            beq no_y_indent
; Multiply the byte width * the offset
; Use fast'ish multiply, input must both be 8 bit!
;                            ldx <shape_rowbytes
;                            jsl math~umul1r2
                            inline~umul1r2 <shape_rowbytes,Y
                            clc
                            adc <shape_ptr
                            sta <shape_ptr

no_y_indent                 anop
; Get the blit mode index
                            ldx <block_shape_blit_func
                            bne not_copy_blit
; If this is a copy blit, translate that to a masked blit, if needed
                            lda <mask_offset
                            beq not_copy_blit
                            ldx #grlib~blit_mode_4*2

not_copy_blit               anop
                            lda <shape_x_offset
                            beq no_x_indent
                            lsr a
                            adc #0                                       ; round up
                            adc <shape_ptr
                            sta <shape_ptr

no_x_indent                 lda |data_has_left_edge
                            bne has_left_edge
; Data has no left edge, how about the right?
                            lda <shape_width
                            bit #1
                            beq no_left_or_right_edge
                            sec
                            sbc <shape_x_offset
                            cmp <area_width
                            beq has_right_edge
;                           blt has_right_edge                          ; Shoudn't be possible to be less
; No left or right edge
no_left_or_right_edge       anop
                            jmp (wb_jmps,x)
;                           jsr _altscr_block_shape_blit_0_wb_unrolled
exit                        anop
                            restoredatabank
                            pld
                            rtl

; Draw using a function that supports right edges
has_right_edge              anop
                            jmp (re_jmps,x)
;                           jsr _altscr_block_shape_blit_0_re_unrolled
;                           restoredatabank
;                           pld
;                           rtl

; If we are using odd pixel data, then we have a left edge to deal with
has_left_edge               anop
                            lda <shape_x_offset
                            bne clipped_left                            ; did we clip the left?
; shape_x_offset is 0, so we have a left edge, and it wasn't clipped
                            lda <shape_width                            ; in pixels
                            bit #1
                            bne just_left_edge                          ; if the width is *odd*, we have no right edge. We only have left and right edges with even pixel data
                            cmp <area_width                             ; We didn't clip on the left, so if the <area_width is not equal to the <shape_width, we clipped on the right
                            bne just_left_edge

; Draw using a function that a left and right edge
                            jmp (lre_jmps,x)
;                           jsr _altscr_block_shape_blit_0_lre_unrolled
;                           restoredatabank
;                           pld
;                           rtl

just_left_edge              anop
; Draw using a function that a left edge
                            jmp (le_jmps,x)
;                           jsr _altscr_block_shape_blit_0_le_unrolled
;                           restoredatabank
;                           pld
;                           rtl

; Clipped the left edge, so we can igonore that, but we may still have right edge
clipped_left                anop
                            lda <shape_width                            ; in pixels
                            bit #1
                            bne clipped_left_and_no_right               ; if the width is *odd*, we have no right edge. We only have left and right edges with even pixel data
                            sec
                            sbc <shape_x_offset
                            cmp <area_width
                            beq has_right_edge                          ; If equal to, we didn't clip, so the right edge is there.
;                           blt has_right_edge                          ; Shouldn't be possible to be less.

; Clipped the right edge, so just whole bytes
                            jmp (wb_jmps,x)
;                           jsr _altscr_block_shape_blit_0_wb_unrolled
;                           restoredatabank
;                           pld
;                           rtl

clipped_left_and_no_right   anop
                            dec <area_width                             ; We are taking one off the width, because the original <shape_width was odd, meaning the odd-shifted data didn't result in more bytes
                            jmp (wb_jmps,x)
;                           jsr _altscr_block_shape_blit_0_wb_unrolled
;                           restoredatabank
;                           pld
;                           rtl
data_has_left_edge          ds 2
                            profile_function_add_symbol
                            end

; -----------------------------------------------------------------------------
grlib_block_shape_jmps      data seg_grlib_blit

wb_jmps                     dc a2'wb_blit_0_func'
                            dc a2'wb_blit_1_func'
                            dc a2'wb_blit_2_func'
                            dc a2'null_blit_func'
                            dc a2'wb_blit_4_func'

re_jmps                     dc a2're_blit_0_func'
                            dc a2're_blit_1_func'
                            dc a2're_blit_2_func'
                            dc a2'null_blit_func'
                            dc a2'wb_blit_4_func'           ; Only need a Whole Byte function for this blit

le_jmps                     dc a2'le_blit_0_func'
                            dc a2'le_blit_1_func'
                            dc a2'le_blit_2_func'
                            dc a2'null_blit_func'
                            dc a2'wb_blit_4_func'           ; Only need a Whole Byte function for this blit

lre_jmps                    dc a2'lre_blit_0_func'
                            dc a2'lre_blit_1_func'
                            dc a2'lre_blit_2_func'
                            dc a2'null_blit_func'
                            dc a2'wb_blit_4_func'           ; Only need a Whole Byte function for this blit
                            end

null_blit_func              private seg_grlib_blit
                            restoredatabank
                            pld
                            rtl
                            end

wb_blit_0_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_0_wb_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

re_blit_0_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_0_re_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

le_blit_0_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_0_le_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

lre_blit_0_func             private seg_grlib_blit
                            jsr _altscr_block_shape_blit_0_lre_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

; Blit 1

wb_blit_1_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_1_wb_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

re_blit_1_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_1_re_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

le_blit_1_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_1_le_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

lre_blit_1_func             private seg_grlib_blit
                            jsr _altscr_block_shape_blit_1_lre_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

; Blit 2
wb_blit_2_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_2_wb_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

re_blit_2_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_2_re_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

le_blit_2_func              private seg_grlib_blit
                            jsr _altscr_block_shape_blit_2_le_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

lre_blit_2_func             private seg_grlib_blit
                            jsr _altscr_block_shape_blit_2_lre_unrolled
                            restoredatabank
                            pld
                            rtl
                            end

; Blit 4
; Only need a Whole Byte function for this blit
wb_blit_4_func              private seg_grlib_blit
                            using grlib_global_equates
; For shifted data that is an even number of pixel wide, we need to add an extra to the area_width
; This is because the edge functions, which blit 4 does not use, assume extra width.  I think.
; I feel like this is a hack.
                            lda <scratch_word
                            beq even
                            inc <area_width
even                        anop
                            jsr _altscr_block_shape_blit_4_wb_unrolled
                            restoredatabank
                            pld
                            rtl
                            end
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
_altscr_block_shape_blit_0_wb_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using YLookupData
                            using math_tables

                            debugtag '_blit_0_wb_unrolled'
                            debugtag '_altscr_block_shape'

grlib~blit_op               equ 0

                            copy lib/source/grlib.block.shape.blit.wb.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_0_wb_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_shape_store_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_shape_store_odd

                            rtl

; Takes the address in <altscr_ptr and patches the unrolled word move code
; lda |$0000,y
; sta >$000000,x        <altscr_ptr
; going downward to 0
_patch_unrolled_word_shape_store_even anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4
                            lda <altscr_ptr
                            jsr _grlib_shape_store_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #6                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_store_patch_high_wb_even
                            rts
; -----------------------------------------------------------------------------
; Takes the address in <altscr_ptr and patches the unrolled word move code
; lda |$0000,y
; sta >$000000,x        <altscr_ptr
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4
                            lda <altscr_ptr
                            jsr _grlib_shape_store_patch_low_wb_odd

; Patch the high byte (bank) of the store
                            ldy #6                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_store_patch_high_wb_odd
                            rts

                            end

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
_altscr_block_shape_blit_0_le_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using YLookupData
                            using math_tables

                            debugtag '_blit_0_le_unrolled'
                            debugtag '_altscr_block_shape'

grlib~blit_op               equ 0

                            copy lib/source/grlib.block.shape.blit.le.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_0_le_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_shape_store_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_shape_store_odd

                            rtl

; Takes the address in <altscr_ptr and patches the unrolled word move code
; lda |$0000,y
; sta >$000000,x        <altscr_ptr
; going downward to 0
_patch_unrolled_word_shape_store_even anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4
                            lda <altscr_ptr
                            inc a                           ; adjusting by 2, so that the last patched value in the unrolled loop is address + 2
                            inc a
                            jsr _grlib_shape_store_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #6                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_store_patch_high_wb_even

                            lda <altscr_ptr
                            sta >patch_even_le_load+1
                            sta >patch_even_le_store+1
                            shortm
                            lda <altscr_ptr+2
                            sta >patch_even_le_load+3
                            sta >patch_even_le_store+3
                            longm

                            rts
; -----------------------------------------------------------------------------
; Takes the address in <altscr_ptr and patches the unrolled word move code
; lda |$0000,y
; sta >$000000,x        <altscr_ptr
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4
                            lda <altscr_ptr
                            inc a                           ; adjusting by 1, so the last patched value in the unrolled loop is address + 1
                            jsr _grlib_shape_store_patch_low_wb_even    ; Also note, we are calling the even patcher, we will patch the odd entry separately

; Patch the high byte (bank) of the store
                            ldy #6                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_store_patch_high_wb_even

                            lda <altscr_ptr
                            sta >patch_odd_le_load+1
                            sta >patch_odd_le_store+1
                            shortm
                            lda <altscr_ptr+2
                            sta >patch_odd_le_load+3
                            sta >patch_odd_le_store+3
                            longm

                            rts

                            end

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
_altscr_block_shape_blit_0_lre_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData
                            using math_tables

                            debugtag '_blit_0_lre_unrolled'
                            debugtag '_altscr_block_shape'

;                            keyed_break 2,'_blit_0_lre_unrolled'

grlib~blit_op               equ 0

                            copy lib/source/grlib.block.shape.blit.lre.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_0_lre_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_shape_store_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_shape_store_odd

                            rtl

; Takes the address in <altscr_ptr and patches the unrolled word move code
; lda |$0000,y
; sta >$000000,x        <altscr_ptr
; going downward to 0
_patch_unrolled_word_shape_store_even anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4
                            lda <altscr_ptr
                            inc a                           ; we want this case to go to an offset of 1
                            jsr _grlib_shape_store_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #6                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_store_patch_high_wb_even

                            lda <altscr_ptr
                            sta >patch_even_le_load+1
                            sta >patch_even_le_store+1
                            sta >patch_even_re_load+1
                            sta >patch_even_re_store+1
                            shortm
                            lda <altscr_ptr+2
                            sta >patch_even_le_load+3
                            sta >patch_even_le_store+3
                            sta >patch_even_re_load+3
                            sta >patch_even_re_store+3
                            longm

                            rts
; -----------------------------------------------------------------------------
; Takes the address in <altscr_ptr and patches the unrolled word move code
; lda |$0000,y
; sta >$000000,x        <altscr_ptr
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4
                            lda <altscr_ptr
                            inc a                                       ; inc by 2 so patch ends at addres + 2
                            inc a
                            jsr _grlib_shape_store_patch_low_wb_even    ; calling the even version, we patch the extra bytes manually

; Patch the high byte (bank) of the store
                            ldy #6                                      ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_store_patch_high_wb_even   ; calling the even version, we patch the extra bytes manually

                            lda <altscr_ptr
                            sta >patch_odd_le_load+1
                            sta >patch_odd_le_store+1
                            sta >patch_odd_re_load+1
                            sta >patch_odd_re_store+1
                            shortm
                            lda <altscr_ptr+2
                            sta >patch_odd_le_load+3
                            sta >patch_odd_le_store+3
                            sta >patch_odd_re_load+3
                            sta >patch_odd_re_store+3
                            longm

                            rts

                            end

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
_altscr_block_shape_blit_0_re_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData
                            using math_tables

                            debugtag 'blit_0_re_unrolled'
                            debugtag '_altscr_block_shape'

;                            keyed_break 3,'blit_0_re_unrolled'

grlib~blit_op               equ 0

                            copy lib/source/grlib.block.shape.blit.re.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_0_re_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_shape_store_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_shape_store_odd

                            rtl

; Takes the address in <altscr_ptr and patches the unrolled word move code
; lda |$0000,y
; sta >$000000,x        <altscr_ptr
; going downward to 0
_patch_unrolled_word_shape_store_even anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4
                            lda <altscr_ptr
                            jsr _grlib_shape_store_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #6                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_store_patch_high_wb_even

                            lda <altscr_ptr
                            sta >patch_even_re_load+1
                            sta >patch_even_re_store+1
                            shortm
                            lda <altscr_ptr+2
                            sta >patch_even_re_load+3
                            sta >patch_even_re_store+3
                            longm

                            rts
; -----------------------------------------------------------------------------
; Takes the address in <altscr_ptr and patches the unrolled word move code
; lda |$0000,y
; sta >$000000,x        <altscr_ptr
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4
                            lda <altscr_ptr
                            jsr _grlib_shape_store_patch_low_wb_odd

; Patch the high byte (bank) of the store
                            ldy #6                                      ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_store_patch_high_wb_odd

                            lda <altscr_ptr
                            sta >patch_odd_re_load+1
                            sta >patch_odd_re_store+1
                            shortm
                            lda <altscr_ptr+2
                            sta >patch_odd_re_load+3
                            sta >patch_odd_re_store+3
                            longm

                            rts
                            end

; -----------------------------------------------------------------------------
; Helper functions for patching
_grlib_shape_store_helpers  start seg_grlib_blit
                            using grlib_global_equates

; Whole Byte versions
; These assume they are patching
;   lda |$0000,y
;   sta >$000000,x
; 7 opcodes total

; -----------------------------------------------------------------------------
_grlib_shape_store_patch_low_wb_even entry
                            clc
                            adc #(320/2)-2                  ; max bytes on a screen line - 2
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            sec
patch_wb_loop1              anop
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; Unrolled loop, 7 bytes for all the opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_wb_loop1
                            rts

_grlib_shape_store_patch_high_wb_even entry
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            shortm
patch_wb_loop2              anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            iny                             ; Unrolled loop, 7 bytes for the opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_wb_loop2
                            longm
                            rts
; -----------------------------------------------------------------------------
_grlib_shape_store_patch_low_wb_odd  entry
                            clc
                            adc #(320/2)-3                  ; max bytes on a screen line - 3
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            sec
patch_wb_loop1_odd          anop
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; Unrolled loop, 7 bytes for the opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_wb_loop1_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            clc
                            adc #1                          ; We also subtracted too much, put one back
                            sta [<patch_ptr],y
                            rts

_grlib_shape_store_patch_high_wb_odd entry
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            shortm
patch_wb_loop2_odd          anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            iny                             ; Unrolled loop, 7 bytes for the opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_wb_loop2_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            sta [<patch_ptr],y
                            longm
                            rts

; These assume they are patching
;   lda |$0000,y
;   and <fore_color
;   sta >$000000,x
; 9 opcodes total

; -----------------------------------------------------------------------------
_grlib_shape_blit_1_patch_low_wb_even entry
                            clc
                            adc #(320/2)-2                  ; max bytes on a screen line - 2
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            sec
patch_blit_1_wb_loop1       anop
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; Unrolled loop, 9 bytes for all the opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_blit_1_wb_loop1
                            rts

_grlib_shape_blit_1_patch_high_wb_even entry
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            shortm
patch_blit_1_wb_loop2       anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            iny                             ; Unrolled loop, 9 bytes for the opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_blit_1_wb_loop2
                            longm
                            rts
; -----------------------------------------------------------------------------
_grlib_shape_blit_1_patch_low_wb_odd entry
                            clc
                            adc #(320/2)-3                  ; max bytes on a screen line - 3
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            sec
patch_blit_1_wb_loop1_odd   anop
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; Unrolled loop, 9 bytes for the opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_blit_1_wb_loop1_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            clc
                            adc #1                          ; We also subtracted too much, put one back
                            sta [<patch_ptr],y
                            rts

_grlib_shape_blit_1_patch_high_wb_odd entry
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            shortm
patch_blit_1_wb_loop2_odd    anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            iny                             ; Unrolled loop, 9 bytes for the opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_blit_1_wb_loop2_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            sta [<patch_ptr],y
                            longm
                            rts

; These assume they are patching
;
;   lda |$0000,y            3
;   eor #$ffff              3
;   and >$ffffff,x          4
;   sta <temp               2
;   lda |$0000,y            3
;   and <mask               2
;   ora <temp               2
;   sta >$ffffff,x          4

; 23 opcodes total, and 2 patches in each.  The second patch is 13 bytes past the first patch

; -----------------------------------------------------------------------------
_grlib_shape_blit_2_patch_low_wb_even entry
                            clc
                            adc #(320/2)-2                  ; max bytes on a screen line - 2
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            sec
patch_blit_2_wb_loop1       anop
                            sta [<patch_ptr],y
                            iny                             ; 13 bytes to the second patch
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; 10 more to get to the next block
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_blit_2_wb_loop1
                            rts

_grlib_shape_blit_2_patch_high_wb_even entry
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            shortm
patch_blit_2_wb_loop2       anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            iny                             ; 13 bytes to the second patch
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            sta [<patch_ptr],y
                            iny                             ; 10 more to get to the next block
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_blit_2_wb_loop2
                            longm
                            rts
; -----------------------------------------------------------------------------
_grlib_shape_blit_2_patch_low_wb_odd entry
                            clc
                            adc #(320/2)-3                  ; max bytes on a screen line - 3
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            sec
patch_blit_2_wb_loop1_odd   anop
                            sta [<patch_ptr],y
                            iny                             ; 13 bytes to the second patch
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; 10 more to get to the next block
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_blit_2_wb_loop1_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            clc
                            adc #1                          ; We also subtracted too much, put one back
                            sta [<patch_ptr],y
                            iny                             ; 13 bytes to the second patch
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            sta [<patch_ptr],y
                            rts

_grlib_shape_blit_2_patch_high_wb_odd entry
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            shortm
patch_blit_2_wb_loop2_odd    anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            iny                             ; 13 bytes to the second patch
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            sta [<patch_ptr],y
                            iny                             ; 10 more to get to the next block
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_blit_2_wb_loop2_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            sta [<patch_ptr],y
                            iny                             ; 13 bytes to the second patch
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            sta [<patch_ptr],y
                            longm
                            rts

; These assume they are patching
;
;        lda |$ffff,y                    ; 3
;        and >$ffffff,x                  ; 4
;        ora |offset-2,y                 ; 3
;        sta >$ffffff,x                  ; 4

; 14 opcodes total, and 2 patches in each.  The second patch is 7 bytes past the first patch

; -----------------------------------------------------------------------------
_grlib_shape_blit_4_patch_low_wb_even entry
                            clc
                            adc #(320/2)-2                  ; max bytes on a screen line - 2
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            sec
patch_blit_4_wb_loop1       anop
                            sta [<patch_ptr],y
                            inyn 7                          ; 7 bytes to the second patch
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            inyn 7                          ; 7 more to get to the next block
                            dex
                            bne patch_blit_4_wb_loop1
                            rts

_grlib_shape_blit_4_patch_high_wb_even entry
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            shortm
patch_blit_4_wb_loop2       anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            inyn 7                          ; 7 bytes to the second patch
                            sta [<patch_ptr],y
                            inyn 7                          ; 7 more to get to the next block
                            dex
                            bne patch_blit_4_wb_loop2
                            longm
                            rts
; -----------------------------------------------------------------------------
_grlib_shape_blit_4_patch_low_wb_odd entry
                            clc
                            adc #(320/2)-3                  ; max bytes on a screen line - 3
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            sec
patch_blit_4_wb_loop1_odd   anop
                            sta [<patch_ptr],y
                            inyn 7                          ; 7 bytes to the second patch
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            inyn 7                          ; 7 more to get to the next block
                            dex
                            bne patch_blit_4_wb_loop1_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            clc
                            adc #1                          ; We also subtracted too much, put one back
                            sta [<patch_ptr],y
                            inyn 7                          ; 7 bytes to the second patch
                            sta [<patch_ptr],y
                            rts

_grlib_shape_blit_4_patch_high_wb_odd entry
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            shortm
patch_blit_4_wb_loop2_odd   anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            inyn 7                          ; 7 bytes to the second patch
                            sta [<patch_ptr],y
                            inyn 7                          ; 7 more to get to the next block
                            dex
                            bne patch_blit_4_wb_loop2_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            sta [<patch_ptr],y
                            inyn 7                           ; 7 bytes to the second patch
                            sta [<patch_ptr],y
                            longm
                            rts

                            end
