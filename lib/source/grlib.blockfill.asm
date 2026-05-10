                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            mcopy generated/grlib.blockfill.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------
; Fill the entire alt_screen with a word pattern
; This does not obey the cip rect
; Parameters:
;  ACC contains fill pattern
grlib_fill_alt_screen       start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag 'grlib_fill_alt_screen'
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
                            jsr _altscr_fill_rect

                            pld
                            profile_function_end
                            rtl
                            profile_function_add_symbol
                            end

; ----------------------------------------------------------------------
; Fill a rect on the alt-screen with the pattern in the acc
; Parameters:
;  wLeft            - pixel X
;  wTop             - pixel y
;  wWidth           - pixel width
;  wHeight          - pixel height
;  wColor           - color pattern.  This is 4 pixels in a row.
;
grlib_alt_screen_fill_rect  start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag 'grlib_fill_alt_screen_rect'

                            begin_locals
work_area_size              end_locals

                            profile_function_begin

                            ssub (2:wLeft,2:wTop,2:wWidth,2:wHeight,2:wColor),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2

                            getword {s},#wLeft+extra_stack
                            putword <draw_x
                            getword {s},#wTop+extra_stack
                            putword <draw_y
                            getword {s},#wWidth+extra_stack
                            putword <area_width
                            getword {s},#wHeight+extra_stack
                            putword <area_height
                            getword {s},#wColor+extra_stack
                            putword <scratch_word

                            jsr _clip_coords
                            bcs exit
                            lda <scratch_word
                            jsr _altscr_fill_rect

exit                        anop
                            pld
                            profile_function_end
                            sret

                            profile_function_add_symbol
                            end

; ----------------------------------------------------------------------
; Draw a 1 pixel wide, framed rect on the alt-screen
; Parameters:
;  ACC contains fill pattern
;  <draw_x          - pixel X
;  <draw_y          - pixel y
;  <area_width      - pixel width
;  <area_height     - pixel height
;
grlib_alt_screen_draw_rect  start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag 'grlib_screen_draw_rect'

saved_color                 equ 1
saved_height                equ 3
saved_width                 equ 5
saved_y                     equ 7
saved_x                     equ 9
locals_end                  equ saved_x+2-1

                            pei <draw_x
                            pei <draw_y
                            pei <area_width
                            pei <area_height
                            pha                                 ; color

                            lda #1
                            sta <area_height
                            lda saved_color,s
                            jsr _altscr_fill_rect               ; horizntal top

                            lda saved_y,s
                            clc
                            adc saved_height,s
                            dec a
                            sta <draw_y
                            lda saved_width,s
                            sta <area_width
                            lda saved_x,s
                            sta <draw_x
                            lda saved_color,s
                            jsr _altscr_fill_rect               ; horizontal bottom

                            lda saved_x,s
                            sta <draw_x
                            lda saved_y,s
                            sta <draw_y
                            lda saved_height,s
                            sta <area_height
                            lda #1
                            sta <area_width
                            lda saved_color,s
                            jsr _altscr_fill_rect               ; vertical left

                            lda saved_x,s
                            clc
                            adc saved_width,s
                            dec a
                            sta <draw_x
                            lda saved_y,s
                            sta <draw_y
                            lda saved_height,s
                            sta <area_height
                            lda #1
                            sta <area_width
                            lda saved_color,s
                            jsr _altscr_fill_rect               ; vertical right

; Clean up stack
                            tsc
                            clc
                            adc #locals_end
                            tcs

                            rtl
                            end

; ---------------------------------------------------------------------------------------
_altscr_fill_rect           start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_altscr_fill_rect'
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
                            jmp _altscr_fill_area_wb_unrolled
single_pixel_left           jmp _altscr_vline_left

even_left_odd_pixel_right   anop
; Even pixel start, but an odd number of pixels wide, so we have a 'right edge' to deal with
                            jmp _altscr_fill_area_re_unrolled

; Our left edge starts on an odd pixel, so we have at least a 'left edge' to deal with
odd_left                    lsr <area_width
                            beq single_pixel_right
                            bcs odd_left_odd_pixel_right
; We have an even number of pixels, but since we are starting on an off pixel, we have a 'left edge' and 'right edge' to deal with
                            dec <area_width
                            beq two_pixel_left_right
                            jmp _altscr_fill_area_lre_unrolled
single_pixel_right          jmp _altscr_vline_right
two_pixel_left_right        jmp _altscr_vline_left_right

; We have an odd number of pixels, but since we are starting on an odd pixel, we only have a 'left edge' to deal with.
odd_left_odd_pixel_right    anop
                            jmp _altscr_fill_area_le_unrolled
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
_altscr_fill_area_wb_unrolled  start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag 'wb_altscr_fill_area'

; Include the shared body of the function
                            copy lib/source/grlib.fill.area.wb.unrolled.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_fill_area_wb_unrolled_initialize_patch entry

                            lda <altscr_ptr
                            sta <patch_ptr
                            lda <altscr_ptr+2
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
_altscr_fill_area_re_unrolled  start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag 're_altscr_fill_area'

; Include the shared body of the function
                            copy lib/source/grlib.fill.area.re.unrolled.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_fill_area_re_unrolled_initialize_patch entry

                            lda <altscr_ptr
                            sta <patch_ptr
                            lda <altscr_ptr+2
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
_altscr_fill_area_le_unrolled start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag 'le_altscr_fill_area'

; Include the shared body of the function
                            copy lib/source/grlib.fill.area.le.unrolled.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_fill_area_le_unrolled_initialize_patch entry

                            lda <altscr_ptr
                            sta <patch_ptr
                            lda <altscr_ptr+2
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
_altscr_fill_area_lre_unrolled start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag 'lre_altscr_fill_area'

; Include the shared body of the function
                            copy lib/source/grlib.fill.area.lre.unrolled.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_fill_area_lre_unrolled_initialize_patch entry

                            lda <altscr_ptr
                            sta <patch_ptr
                            lda <altscr_ptr+2
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

_altscr_vline               start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData

                            lsr <draw_x
                            bcs write_right_pixel
_altscr_vline_left          entry

; Include the shared body of the function
                            copy lib/source/grlib.vline.left.s

; ----------------------------------------------------------------

_altscr_vline_right         entry
; Include the shared body of the function
                            copy lib/source/grlib.vline.right.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_vline_initialize_patch entry
                            lda <altscr_ptr
                            sta <patch_ptr
                            lda <altscr_ptr+2
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

_altscr_vline_left_right    start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData

; Include the shared body of the function
                            copy lib/source/grlib.vline.left.right.s

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_altscr_vline_left_right_initialize_patch entry
                            lda <altscr_ptr
                            sta <patch_ptr
                            lda <altscr_ptr+2
                            sta <patch_ptr+2

                            jsr _patch_it
                            rts

                            end

;------------------------------------------------------------------------------
; This assumes that the altscr_ptr is pointing to the shadowed SHR area
; which allows us to map bank 0 to bank 1 and store the input word
; using a sequence of PHA opcodes.
;
; This only does whole words, so it may do more horizontal area than what is passed in.
;
; This is a post-clipping function.
; Note the horizontal coordinate input must already be in bytes
;
; Parameters:
;  <area_width      - Width of area in bytes.
;  <area_height     - Height of the area, in pixels
;  <draw_x           - X coordinate, in bytes
;  <draw_y           - Y coordinate, in pixels
;
_altscr_fill_area_push_words start seg_grlib
                            using grlib_global_equates
                            using YLookupData
                            using softswitch_definitions

pause_for_interrupts_count  equ 8

                            tay                                         ; save the patten to draw
                            lda <area_width
; We want the width to be in whole words
                            lsr a                                       ; word width
                            adc #0                                      ; increase if odd
                            asl a                                       ; back to bytes
                            tax                                         ; save the word width * 2, for later
                            sta <area_width                             ; updated byte width
; Make sure we are not off the edge.  This fixes the case where when we extend to words, the last byte is off the edge
; We will then move the left edge down one, so there will be an extra erased byte on the left.
                            adc <draw_x
                            cmp #161                                    ; 160 + 1, so we can use a blt
                            blt ok_right
                            sec
                            sbc #160
                            negate a
                            clc
                            adc <draw_x
                            sta <draw_x
ok_right                    anop

; Get the number of lines before we panic and turn the interrupts back on for a bit, so we don't stall the audio, etc.
; Note, x-reg has the word width from above
                            lda >pha_interrupt_breather_lines,x
                            cmp <area_height
                            jlt need_breather

; No breather needed, we can skip dealing with the countdown

; Save the stack
                            tsc
                            sta >patch_saved_stack_ptr_a_1+1

; Calculate the amount to add to the stack to move it to the next line
; We assume that the stack will be left pointing one less than the last byte it wrote
; so we do the full line width + area width, so that it is in the correct position
                            lda <area_width
                            clc
                            adc #160
                            sta >patch_stack_adjust_a+1

                            txa                                         ; number of bytes
                            lsr a                                       ; need words
                            negate a
                            clc
                            adc #run_end_a
                            sta >patch_jump_a+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x                             ; Get the memory offset for the line.
;                           clc                                         ; carry will be clear from asl above
                            adc #$2000
                            adc <draw_x                                 ; a-reg now has the offset to the first byte on the line we want to copy
; Stack goes backward
                            adc <area_width
                            dec a                                       ; stack points to first byte to write

                            ldx <area_height                            ; x will count down the height
; Hold our breath!
                            sei
; Set the stack
                            tcs

; Set to read/write bank 1
; Swapping into 8-bit mode, even though it will take 6 cycles. This should be within 1 cycle of the
; 16-bit read trick (ssw~state_reg+1 is not a functioning switch, so reading and writing to it should be 'safe'),
; The savings from working with 8 bit values (-3) and the fact that the sta will be a byte, which will update the slow-ram,
; and that should 2 'fast' cycles faster than writing 16-bits to slow-ram.
; I feel better about not writing to undocumented soft-switches, and it reduces the warnings shown in some emulators
                            shortm
                            lda >ssw~state_reg
                            ora #(ssw~state_reg~ramwrt)                 ; setting to just write.  Not sure if it is better than also setting the read
                            sta >ssw~state_reg
                            longm                                       ; 18 cycles to change the state.  Also triggers a 1Mhz slowdown.  Boo.
;
                            tya                         ; y-reg has pattern
                            jmp patch_jump_a            ; go!

                            PHALineLoop 80
run_end_a                   anop

                            dex
                            beq done_a                  ; finished?

                            tsc
patch_stack_adjust_a        adc #$0000                  ; Move stack pointer
                            tcs

                            tya                         ; y-reg has pattern
patch_jump_a                jmp |run_end_a              ; per line overhead is 16

done_a                      anop
; Set to read/write bank 0
                            shortm
                            lda >ssw~state_reg
                            and #((ssw~state_reg~ramwrt)*-1)-1
                            sta >ssw~state_reg
                            longm                       ; 18 cycles to change the state.  Also triggers a 1Mhz slowdown.  Boo.
patch_saved_stack_ptr_a_1   lda  #$0000
                            tcs
                            cli

                            rts

;;;;
; This code is the same as above, except we use the x register for a countdown for
; the number of lines to process before we briefly re-enable the interrupts.

need_breather               anop
                            setlocaldatabank            ; It will help us enough to have the databank local, to overcome the 14 cycles it will cost to set it

                            sta patch_breather_1+1
; Patch the pattern in
                            sty patch_pattern_b+1
                            tay                         ; breather countdown in y-reg, for later
; Save the stack
                            tsc
                            sta patch_saved_stack_ptr_b_1+1
                            sta patch_saved_stack_ptr_b_2+1

; Calculate the amount to add to the stack to move it to the next line
; We assume that the stack will be left pointing one less than the last byte it wrote
; so we do the full line width + area width, so that it is in the correct position
                            lda <area_width
                            clc
                            adc #160
                            sta patch_stack_adjust_b+1

                            txa                                         ; number of bytes
                            lsr a                                       ; need words
                            negate a
                            clc
                            adc #run_end_b
                            sta patch_jump_b+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x                             ; Get the memory offset for the line.
;                           clc                                         ; carry will be clear from asl above
                            adc #$2000
                            adc <draw_x                                 ; a-reg now has the offset to the first byte on the line we want to copy
; Stack goes backward
                            adc <area_width
                            dec a                                       ; stack points to first byte to write

                            tyx                                         ; breather countdown -> x-reg
                            ldy <area_height                            ; y-reg will count down the height
; Hold our breath!
                            sei
; Set the stack
                            tcs

; Set to read/write bank 1
; Swapping into 8-bit mode, even though it will take 6 cycles. This should be within 1 cycle of the
; 16-bit read trick (ssw~state_reg+1 is not a functioning switch, so reading and writing to it should be 'safe'),
; The savings from working with 8 bit values (-3) and the fact that the sta will be a byte, which will update the slow-ram,
; and that should 2 'fast' cycles faster than writing 16-bits to slow-ram.
; I feel better about not writing to undocumented soft-switches, and it reduces the warnings shown in some emulators
                            shortm
                            lda >ssw~state_reg
                            ora #(ssw~state_reg~ramwrt)                 ; setting to just write.  Not sure if it is better than also setting the read
                            sta >ssw~state_reg
                            longm
;
; Breather countdown is still in y-reg
                            jmp patch_pattern_b             ; go!

                            PHALineLoop 80
run_end_b                   anop

                            dey
                            beq done_b                      ; finished?

                            dex
                            beq pause_for_interrupts

                            tsc
patch_stack_adjust_b        adc #$0000                      ; Move stack pointer
                            tcs

patch_pattern_b             lda #0
patch_jump_b                jmp |run_end_b                  ; per-line overhead is 21 cycles

pause_for_interrupts        anop
                            tsx                             ; 2 gotta save our place
patch_saved_stack_ptr_b_1   lda  #$0000                     ; 3
                            tcs                             ; 2
; Set to read/write bank 0
                            shortm                          ; 3
                            lda >ssw~state_reg              ; 5
                            and #((ssw~state_reg~ramwrt)*-1)-1 ; 2
                            sta >ssw~state_reg              ; 5
                            longa on
; Interrupts back on, as well as setting M back to 16 bits
;                           cli
                            rep #%00100100              ; ..m..i..  3
                            nop                         ; 2 do we need this?
; Hope that was enough time!
;                           sei
                            sep #%00100100              ; ..m..i..     3
; Set to read/write bank 1
                            longa off
                            lda >ssw~state_reg          ; 5
                            ora #(ssw~state_reg~ramwrt) ; 3
                            sta >ssw~state_reg          ; 5
                            longm
                            txa                         ; 2 put the stack back in a-reg, it will get added to and back in the stack later
patch_breather_1            ldx #pause_for_interrupts_count ; 3 restore the interrupt countdown
                            bra patch_stack_adjust_b    ; 3
; 51 cycles total for the interrupt 'breather'

done_b                      anop
; Set to read/write bank 0
                            shortm
                            lda >ssw~state_reg
                            and #((ssw~state_reg~ramwrt)*-1)-1
                            sta >ssw~state_reg
                            longm
patch_saved_stack_ptr_b_2   lda  #$0000
                            tcs
                            cli

                            restoredatabank
                            rts

; Index table where the input is the number if PHA opcodes that will be used
; and the output is the number of lines to process before a breather is in order
; The table is targeting a max of 3072 cycles between pauses
pha_interrupt_breather_lines anop
    dc i'$00c8,$007a,$0069,$005d,$0053,$004a,$0044,$003e,$0039,$0035,$0032,$002f,$002c,$002a,$0027,$0025'
    dc i'$0024,$0022,$0021,$001f,$001e,$001d,$001c,$001b,$001a,$0019,$0018,$0017,$0017,$0016,$0015,$0015'
    dc i'$0014,$0014,$0013,$0013,$0012,$0012,$0011,$0011,$0010,$0010,$0010,$000f,$000f,$000f,$000e,$000e'
    dc i'$000e,$000e,$000d,$000d,$000d,$000d,$000c,$000c,$000c,$000c,$000c,$000b,$000b,$000b,$000b,$000b'
    dc i'$000b,$000a,$000a,$000a,$000a,$000a,$000a,$000a,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009'
    dc i'$0009'
                            end


