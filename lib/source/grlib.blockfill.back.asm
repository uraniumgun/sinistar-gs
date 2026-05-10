                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            mcopy generated/grlib.blockfill.back.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------
; Fill the entire back buffer with a word pattern
; This does not obey the cip rect
; Parameters:
;  ACC contains fill pattern
grlib_fill_back_buffer      start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag 'grlib_fill_back_buffer'
                            profile_function_begin

                            tax

                            phd
                            lda >grlib~dp
                            tcd

                            stz <draw_x
                            stz <draw_y
                            lda #320
                            sta <area_width
                            lda #200
                            sta <area_height
                            txa
                            jsr _back_fill_rect

                            pld
                            profile_function_end
                            rtl
                            profile_function_add_symbol
                            end

; ---------------------------------------------------------------------------------------
_back_fill_rect             start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_back_fill_rect'
; Pixel x to byte x
                            lsr <draw_x
                            bcs odd_left

; Our left edge, starts at an even pixel.
even_left                   anop
; Convert the pixel width into a byte width
                            lsr <area_width
                            beq single_pixel_left
                            bcs even_left_odd_pixel_right
; Our right edge is an even number of pixels from the left, which means we have whole bytes
                            jmp _back_fill_area_wb_unrolled
single_pixel_left           jmp _back_vline_left

even_left_odd_pixel_right   anop
; Even pixel start, but an odd number of pixels wide, so we have a 'right edge' to deal with
                            jmp _back_fill_area_re_unrolled

; Our left edge starts on an odd pixel, so we have at least a 'left edge' to deal with
odd_left                    lsr <area_width
                            beq single_pixel_right
                            bcs odd_left_odd_pixel_right
; We have an even number of pixels, but since we are starting on an off pixel, we have a 'left edge' and 'right edge' to deal with
                            dec <area_width
                            beq two_pixel_left_right
                            jmp _back_fill_area_lre_unrolled
single_pixel_right          jmp _back_vline_right
two_pixel_left_right        jmp _back_vline_left_right

; We have an odd number of pixels, but since we are starting on an odd pixel, we only have a 'left edge' to deal with.
odd_left_odd_pixel_right    anop
                            jmp _back_fill_area_le_unrolled
                            rts
                            end

;------------------------------------------------------------------------------
; Fill an area, with a pattern (WB Version)
;
; This version is using an unrolled inner loop, where a jump into the unrolled loop
; is calculated and patched in.  The patch only has to be done once per call
; and the jump cost 6 cycles per line, but the savings is 9 cycles per store.
;
; This version expects the input x and width to be in BYTES and does
; whole bytes only. It will do an odd number of bytes wide.
;
; Parameters:
;  ACC              - holds the fill pattern
;  <area_width      - Width of area in bytes.
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in bytes
;  <draw_y           - Y coordinate, in pixels
;
_back_fill_area_wb_unrolled  start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag 'wb_back_fill_area'

; Include the shared body of the function
                            copy lib/source/grlib.fill.area.wb.unrolled.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_back_fill_area_wb_unrolled_initialize_patch entry

                            lda <back_ptr
                            sta <patch_ptr
                            lda <back_ptr+2
                            sta <patch_ptr+2

                            jsr _patch_it
                            rts

                            end

;------------------------------------------------------------------------------
; Fill an area, with a pattern (RE Version)
;
; This version is using an unrolled inner loop, where a jump into the unrolled loop
; is calculated and patched in.  The patch only has to be done once per call
; and the jump cost 6 cycles per line, but the savings is 9 cycles per store.
;
; This version expects the input x and width to be in BYTES and assumes that there
; is a 'right edge' to deal with
;
; Parameters:
;  ACC              - holds the fill pattern
;  <area_width      - Width of area in bytes.  Note, this should NOT include the byte
;                     that the 'right edge' is part of.  This must be at least 1
;  <area_height     - Height of the area
;  <draw_x          - X coordinate, in bytes
;  <draw_y          - Y coordinate, in pixels
;
_back_fill_area_re_unrolled  start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag 're_back_fill_area'

; Include the shared body of the function
                            copy lib/source/grlib.fill.area.re.unrolled.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_back_fill_area_re_unrolled_initialize_patch entry

                            lda <back_ptr
                            sta <patch_ptr
                            lda <back_ptr+2
                            sta <patch_ptr+2

                            jsr _patch_it
                            rts

                            end

;------------------------------------------------------------------------------
; Fill an area, with a pattern (LE Version)
;
; This version is using an unrolled inner loop, where a jump into the unrolled loop
; is calculated and patched in.  The patch only has to be done once per call
; and the jump cost 6 cycles per line, but the savings is 9 cycles per store.
;
; This version expects the input x and width to be in BYTES and also
; assumes it will have a *left* edge, where it will keep the leftmost pixel
; and change just the right pixel in the byte
;
; Parameters:
;  ACC              - holds the fill pattern
;  <area_width      - Width of area in bytes.  This should NOT include the edge byte.
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in bytes
;  <draw_y           - Y coordinate, in pixels
;
_back_fill_area_le_unrolled start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag 'le_back_fill_area'

; Include the shared body of the function
                            copy lib/source/grlib.fill.area.le.unrolled.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_back_fill_area_le_unrolled_initialize_patch entry

                            lda <back_ptr
                            sta <patch_ptr
                            lda <back_ptr+2
                            sta <patch_ptr+2

                            jsr _patch_it
                            rts
                            end

;------------------------------------------------------------------------------
; Fill an area, with a pattern (LRE Version)
;
; This version is using an unrolled inner loop, where a jump into the unrolled loop
; is calculated and patched in.  The patch only has to be done once per call
; and the jump cost 6 cycles per line, but the savings is 9 cycles per store.
;
; This version expects the input x and width to be in BYTES and assumes that there
; is a 'left edge' and a 'right edge' to deal with
;
; Parameters:
;  ACC              - holds the fill pattern
;  <area_width      - Width of area in bytes.  Note, this should NOT include the
;                     bytes that the 'left edge' and 'right edge' are part of.
;                     This value must be at least 1
;  <area_height     - Height of the area
;  <draw_x          - X coordinate, in bytes
;  <draw_y          - Y coordinate, in pixels
;
_back_fill_area_lre_unrolled start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag 'lre_back_fill_area'

; Include the shared body of the function
                            copy lib/source/grlib.fill.area.lre.unrolled.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_back_fill_area_lre_unrolled_initialize_patch entry

                            lda <back_ptr
                            sta <patch_ptr
                            lda <back_ptr+2
                            sta <patch_ptr+2

                            jsr _patch_it
                            rts

                            end

; -----------------------------------------------------------------------------
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Draw a vertical line.
; The input is expected to be clipped.
; This loop is not unrolled, though it is patched.
;
; Parameters:
;  acc the pixel color to draw.  The value should be in the high and low nybble.
;  draw_x       - pixel x
;  draw_y       - pixel y
;  area_height  - height of line

_back_vline                 start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData

                            lsr <draw_x
                            bcs write_right_pixel
_back_vline_left          entry

; Include the shared body of the function
                            copy lib/source/grlib.vline.left.s

; ----------------------------------------------------------------

_back_vline_right         entry
; Include the shared body of the function
                            copy lib/source/grlib.vline.right.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_back_vline_initialize_patch entry
                            lda <back_ptr
                            sta <patch_ptr
                            lda <back_ptr+2
                            sta <patch_ptr+2

                            jsr _patch_it
                            rts
                            end

; -----------------------------------------------------------------------------
; Draw a vertical line.
; This version assumes that it will be drawing a two pixel wide vline
; with one pixel in right pixel of the byte at <draw_x and one pixel
; in the left pixel in <draw_x + 1
;
; The input is expected to be clipped.
; This loop is not unrolled, though it is patched.
;
; Parameters:
;  acc the pixel color to draw.  The value should be in the high and low nybble.
;  draw_x       - byte offset.
;  draw_y       - pixel y
;  area_height  - height of line

_back_vline_left_right      start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData

; Include the shared body of the function
                            copy lib/source/grlib.vline.left.right.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_back_vline_left_right_initialize_patch entry
                            lda <back_ptr
                            sta <patch_ptr
                            lda <back_ptr+2
                            sta <patch_ptr+2

                            jsr _patch_it
                            rts

                            end
