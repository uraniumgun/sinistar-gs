                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            mcopy generated/grlib.block.shape.blit.4.macros

                            longa on
                            longi on

; Note that blit 4 is a masked blit, and does not need the the implicit blit functions for re/le/lre
; It is assumed that the mask in the source will be correct for those situations

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
_altscr_block_shape_blit_4_wb_unrolled start seg_grlib_blit
                            using grlib_global_equates
                            using YLookupData
                            using math_tables

                            debugtag '_blit_4_wb_unrolled'
                            debugtag '_altscr_block_shape'

grlib~blit_op               equ 4

                            copy lib/source/grlib.block.shape.blit.wb.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_block_shape_blit_4_wb_initialize_patch entry

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
                            ldy #4                          ; first store offset
                            lda <altscr_ptr
                            jsr _grlib_shape_blit_4_patch_low_wb_even

; Patch the high byte (bank) of the store
                            ldy #4+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_4_patch_high_wb_even
                            rts
; -----------------------------------------------------------------------------
; Takes the address in <altscr_ptr and patches the unrolled word move code
; This is the odd version, so it will have <altscr_ptr + (160-3)
; going downward to 1, then the last in wrapped in a sep
_patch_unrolled_word_shape_store_odd anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the store
                            ldy #4                          ; first store offset
                            lda <altscr_ptr
                            jsr _grlib_shape_blit_4_patch_low_wb_odd

; Patch the high byte (bank) of the store
                            ldy #4+2                        ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_shape_blit_4_patch_high_wb_odd
                            rts

                            end

