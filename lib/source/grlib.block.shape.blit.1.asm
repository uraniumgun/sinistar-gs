                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            mcopy generated/grlib.block.shape.blit.1.macros

                            longa on
                            longi on
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
;  <fore_color       - colorizing mask for the source
;
_altscr_block_shape_blit_1_wb_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using YLookupData
                            using math_tables

                            debugtag '_blit_1_wb_unrolled'
                            debugtag '_altscr_block_shape'

grlib~blit_op               equ 1

                            copy lib/source/grlib.block.shape.blit.wb.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_1_wb_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_shape_store_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_shape_store_odd

                            rtl

; Takes the address in <altscr_ptr and patches the unrolled word move code
_patch_unrolled_word_shape_store_even anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #6                          ; store is 6 bytes in
                            lda <altscr_ptr
                            jsr _grlib_shape_blit_1_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #6+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_1_patch_high_wb_even
                            rts
; -----------------------------------------------------------------------------
; Takes the address in <altscr_ptr and patches the unrolled word move code
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #6                          ; store is 6 bytes in
                            lda <altscr_ptr
                            jsr _grlib_shape_blit_1_patch_low_wb_odd

; Patch the high byte (bank) of the store
                            ldy #6+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_1_patch_high_wb_odd
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
;  <fore_color       - colorizing mask for the source
;
_altscr_block_shape_blit_1_le_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using YLookupData
                            using math_tables

                            debugtag '_blit_1_le_unrolled'
                            debugtag '_altscr_block_shape'

grlib~blit_op               equ 1

                            copy lib/source/grlib.block.shape.blit.le.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_1_le_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_shape_store_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_shape_store_odd

                            rtl

; Takes the address in <altscr_ptr and patches the unrolled word move code
; going downward to 0
_patch_unrolled_word_shape_store_even anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #6                          ; store is 6 bytes in
                            lda <altscr_ptr
                            inc a                           ; adjusting by 2, so that the last patched value in the unrolled loop is address + 2
                            inc a
                            jsr _grlib_shape_blit_1_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #6+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_1_patch_high_wb_even

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
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #6                          ; store is 6 bytes in
                            lda <altscr_ptr
                            inc a                           ; adjusting by 1, so the last patched value in the unrolled loop is address + 1
                            jsr _grlib_shape_blit_1_patch_low_wb_even    ; Also note, we are calling the even patcher, we will patch the odd entry separately

; Patch the high byte (bank) of the store
                            ldy #6+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_1_patch_high_wb_even

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
;  <fore_color       - colorizing mask for the source
;
_altscr_block_shape_blit_1_lre_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData
                            using math_tables

                            debugtag '_blit_1_le_unrolled'
                            debugtag '_altscr_block_shape'

;                           keyed_break 2,'_lre_unrolled'

grlib~blit_op               equ 1

                            copy lib/source/grlib.block.shape.blit.lre.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_1_lre_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_shape_store_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_shape_store_odd

                            rtl

; Takes the address in <altscr_ptr and patches the unrolled word move code
; going downward to 0
_patch_unrolled_word_shape_store_even anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #6                          ; store is 6 bytes in
                            lda <altscr_ptr
                            inc a                           ; we want this case to go to an offset of 1
                            jsr _grlib_shape_blit_1_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #6+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_1_patch_high_wb_even

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
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #6                          ; store is 6 bytes in
                            lda <altscr_ptr
                            inc a                                       ; inc by 2 so patch ends at addres + 2
                            inc a
                            jsr _grlib_shape_blit_1_patch_low_wb_even   ; calling the even version, we patch the extra bytes manually

; Patch the high byte (bank) of the store
                            ldy #6+2                                    ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_1_patch_high_wb_even   ; calling the even version, we patch the extra bytes manually

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
;  <fore_color       - colorizing mask for the source
;
_altscr_block_shape_blit_1_re_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData
                            using math_tables

                            debugtag '_blit_1_lre_unrolled'
                            debugtag '_altscr_block_shape'

;                           keyed_break 3,'_re_unrolled'

grlib~blit_op               equ 1

                            copy lib/source/grlib.block.shape.blit.re.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_1_re_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_shape_store_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_shape_store_odd

                            rtl

; Takes the address in <altscr_ptr and patches the unrolled word move code
; going downward to 0
_patch_unrolled_word_shape_store_even anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #6                          ; store is 6 bytes in
                            lda <altscr_ptr
                            jsr _grlib_shape_blit_1_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #6+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_1_patch_high_wb_even

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
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #6                          ; store is 6 bytes in
                            lda <altscr_ptr
                            jsr _grlib_shape_blit_1_patch_low_wb_odd

; Patch the high byte (bank) of the store
                            ldy #6+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_1_patch_high_wb_odd

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
