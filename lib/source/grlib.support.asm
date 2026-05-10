                            copy lib/source/debug.definitions.asm
                            copy lib/source/shape.definitions.asm
                            mcopy generated/grlib.support.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; General graphics related functions including starting up and
; shutting down the grlib system.
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Initialize the library.  This does not initialize graphics/buffers
grlib_initialize            start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates
                            debugtag 'grlib_initialize'

; Test for some compile-time debug flags
                            AIF  C:debug~golden_gate<>0,.noskip
                            AIF  C:debug~use_fake_screen<>0,.noskip
                            lda #grlib~switch_on
                            AGO .skip
.noskip
                            lda #grlib~switch_off
.skip
                            sta >grlib~wait_for_vbl

; Initialize some DP values
                            phd
                            lda >grlib~dp
                            tcd

                            stz <block_shape_blit_func
                            stz <block_shape_blit_func

                            pld

                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the blit mode for the block shape functions
;
; Parameters:
; blit mode in acc.
;
grlib_set_block_shape_blit_mode start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates

                            debugtag 'grlib_set_block_shape_blit_mode'

                            asl a                       ; 2, we will want it * 2
                            tay                         ; 2
                            lda >grlib~dp               ; 6
                            tax                         ; 2
                            tya                         ; 2
                            sta >block_shape_blit_func,x ; 6
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the blit mode for the font functions
;
; Parameters:
; blit mode in acc.
;
grlib_set_font_blit_mode    start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates

                            debugtag 'grlib_set_font_blit_mode'

                            asl a                       ; 2, we will want it * 2
                            tay                         ; 2
                            lda >grlib~dp               ; 6
                            tax                         ; 2
                            tya                         ; 2
                            sta >font_blit_func,x       ; 6

                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the font foreground color.
; This is not the quickest way of setting it, and it is advisable to
; set it directly, if changing it often.
;
; Parameters:
; color pattern in acc.
;
grlib_set_font_fore_color   start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates

                            debugtag 'grlib_set_font_fore_color'

; Using long addressing and the X register for where the DP is.
; This would be so much better, if I could get the DP address directly into X
; but I can't be sure of the current data bank.  Hmm.
; Could patch a ldx #dp with dp, once we know it, but if we are doing that, why not just patch the complete address into an sta.

                            tay                         ; 2
                            lda >grlib~dp               ; 6
                            tax                         ; 2
                            tya                         ; 2
                            sta >fore_color,x           ; 6

                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the font background color.
; This is not the quickest way of setting it, and it is advisable to
; set it directly, if changing it often.
;
; Parameters:
; blit mode in acc.
;
grlib_set_font_back_color   start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates

                            debugtag 'grlib_set_font_back_color'

                            tay                         ; 2
                            lda >grlib~dp               ; 6
                            tax                         ; 2
                            tya                         ; 2
                            sta >back_color,x           ; 6

                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the pointer to the back buffer to use for the graphics library.
; This is primarily used for the source for erase operations.
;
; Parameters
; pBuffer           buffer to use.  The library does not own this buffer.
grlib_set_back_buffer       start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates

                            begin_locals
work_area_size              end_locals

                            debugtag 'grlib_set_back_buffer'
                            ssub (4:pBuffer),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2

                            getword {s},#pBuffer+extra_stack
                            putword <back_ptr
                            sta >grlib~back_ptr

                            getword {s},#pBuffer+2+extra_stack
                            putword <back_ptr+2
                            sta >grlib~back_ptr+2

                            pld
                            sret
                            end

; -----------------------------------------------------------------------------
; Set the alternate screen buffer to use for the graphics library.
; Optimally, this should point to the shadowed screen location at $012000
; If it is, transfers from the alternate screen to the real screen will be
; done more efficiently.
;
; Parameters
; pBuffer           buffer to use.  The library does not own this buffer.
grlib_set_alt_screen_buffer start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates

                            begin_locals
work_area_size              end_locals

                            debugtag 'grlib_set_alt_screen_buffer'
                            ssub (4:pBuffer),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2

                            lda #0
                            sta >grlib~altscr_is_shadowed

                            getword {s},#pBuffer+extra_stack
                            tax
                            putword <altscr_ptr
                            sta >grlib~altscr_ptr
                            getword {s},#pBuffer+2+extra_stack
                            putword <altscr_ptr+2
                            sta >grlib~altscr_ptr+2

; If we got the shadow memory for the alt-screen, set a flag
                            cpx #grlib~shadowed_shr_screen
                            bne not_shadowed
                            cmp #^grlib~shadowed_shr_screen
                            bne not_shadowed
                            lda #grlib~switch_on
                            sta >grlib~altscr_is_shadowed
;
not_shadowed                anop
                            pld
                            sret
                            end

; -----------------------------------------------------------------------------
; Set the target screen buffer to use for the graphics library.
; Normally, this is the 'real' screen, but it can be set to regular
; memory.  This is used when profiling / running without graphics (golden gate)
;
; Parameters
; pBuffer           buffer to use.  The library does not own this buffer.
grlib_set_target_screen_buffer start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates

                            begin_locals
work_area_size              end_locals

                            debugtag 'grlib_set_target_screen_buffer'
                            ssub (4:pBuffer),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2
;
                            lda #0
                            sta >grlib~targetscr_is_visible

                            getword {s},#pBuffer+extra_stack
                            tax
                            putword <targetscr_ptr
                            sta >grlib~targetscr_ptr
                            getword {s},#pBuffer+2+extra_stack
                            putword <targetscr_ptr+2
                            sta >grlib~targetscr_ptr+2

; If we are using the 'real' screen, set a flag
                            cpx #grlib~shr_screen
                            bne not_visible
                            cmp #^grlib~shr_screen
                            bne not_visible
                            lda #grlib~switch_on
                            sta >grlib~targetscr_is_visible
;
not_visible                 anop
                            pld
                            sret
                            end

; -----------------------------------------------------------------------------
; Initialize functions that have at least some partial static patching needs.
; This needs to be called *after* buffers have been setup, such as
; the altscr_ptr and back_ptr
grlib_initialize_patching   start seg_grlib
                            using grlib_global_data

                            debugtag 'grlib_initialize_patching'
                            phd
                            lda >grlib~dp
                            tcd

                            jsr _restore_area_initialize_patch
                            jsr _transfer_area_to_scree_initialize_patch
                            jsr _restore_area_unrolled_initialize_patch
                            jsr _transfer_area_to_screen_unrolled_initialize_patch
                            jsr _shadow_area_to_screen_unrolled_initialize_patch

; Alt-screen block fill
                            jsr _altscr_fill_area_wb_unrolled_initialize_patch
                            jsr _altscr_fill_area_le_unrolled_initialize_patch
                            jsr _altscr_fill_area_re_unrolled_initialize_patch
                            jsr _altscr_fill_area_lre_unrolled_initialize_patch

                            jsr _altscr_vline_initialize_patch
                            jsr _altscr_vline_left_right_initialize_patch

; 'Real' screen block fill
                            jsr _screen_fill_area_wb_unrolled_initialize_patch
                            jsr _screen_fill_area_le_unrolled_initialize_patch
                            jsr _screen_fill_area_re_unrolled_initialize_patch
                            jsr _screen_fill_area_lre_unrolled_initialize_patch

                            jsr _screen_vline_initialize_patch
                            jsr _screen_vline_left_right_initialize_patch
; back screen block fill
                            jsr _back_fill_area_wb_unrolled_initialize_patch
                            jsr _back_fill_area_le_unrolled_initialize_patch
                            jsr _back_fill_area_re_unrolled_initialize_patch
                            jsr _back_fill_area_lre_unrolled_initialize_patch

                            jsr _back_vline_initialize_patch
                            jsr _back_vline_left_right_initialize_patch
; Blit 0
                            jsl _altscr_block_shape_blit_0_wb_initialize_patch
                            jsl _altscr_block_shape_blit_0_le_initialize_patch
                            jsl _altscr_block_shape_blit_0_re_initialize_patch
                            jsl _altscr_block_shape_blit_0_lre_initialize_patch
; Blit 1
                            jsl _altscr_block_shape_blit_1_wb_initialize_patch
                            jsl _altscr_block_shape_blit_1_le_initialize_patch
                            jsl _altscr_block_shape_blit_1_re_initialize_patch
                            jsl _altscr_block_shape_blit_1_lre_initialize_patch
; Blit 2
                            jsl _altscr_block_shape_blit_2_wb_initialize_patch
                            jsl _altscr_block_shape_blit_2_le_initialize_patch
                            jsl _altscr_block_shape_blit_2_re_initialize_patch
                            jsl _altscr_block_shape_blit_2_lre_initialize_patch

; Blit 4
                            jsl _altscr_block_shape_blit_4_wb_initialize_patch

; Patch the prle draw functions
                            jsr _patch_pack_plot_destination
                            jsr _patch_pack_plot_clipped_destination

                            pld
                            rtl
                            end
; -----------------------------------------------------------------------------
; Set the master clipping rectangle.
; The input will be validated to fit the screen boundries and will also
; be adjusted so that the horizontal coordinates are even, we don't support
; clipping mid-byte.
; The rectangle tests, assume the right and bottom edges are *exclusive*, that is
; the are outside the clipping area.
;
; Parameters:
;  wLeft            - left edge.  This will be adjusted by -1, if odd
;  wTop             - top edge
;  wRight           - right edge.  This will be adjusted by +1, if odd.
;  wBottom          - bottom edge.
grlib_set_clip_rect         start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates

                            debugtag 'grlib_set_clip_rect'
                            begin_locals
work_area_size              end_locals

                            ssub (2:wLeft,2:wTop,2:wRight,2:wBottom),work_area_size
; Validate
; Left < right, top < bottom
; Clamp to screen boundry
; Left and right are even, we don't support odd clipping, so we don't have to split bytes.

; The clamping will not cause the rect to go bigger that it was specified, only smaller and it can
; result in an invalid rect, which is what we want.  If the caller specifies a clip rect that is off screen, we want
; to set the clip rect to an empty rect.

                            getword {s},#wLeft
                            bpl left_not_off_left
                            lda #0
                            putword {s},#wLeft
                            bra check_right
left_not_off_left           cmp #320+1
                            blt check_right
                            lda #320
                            putword {s},#wLeft

check_right                 anop
                            getword {s},#wRight
                            bpl right_not_off_left
                            lda #0
                            putword {s},#wRight
                            bra check_top
right_not_off_left          cmp #320+1
                            blt check_top
                            lda #320
                            putword {s},#wRight

check_top                   anop
                            getword {s},#wTop
                            bpl top_not_off_top
                            lda #0
                            putword {s},#wTop
                            bra check_bottom
top_not_off_top             cmp #200+1
                            blt check_bottom
                            lda #200
                            putword {s},#wTop

check_bottom                 anop
                            getword {s},#wBottom
                            bpl bottom_not_off_top
                            lda #0
                            putword {s},#wBottom
                            bra check_width
bottom_not_off_top          cmp #200+1
                            blt check_width
                            lda #200
                            putword {s},#wBottom

check_width                 anop
                            getword {s},#wRight
                            cmpword {s},#wLeft
                            bge check_height
                            putword {s},#wLeft

check_height                anop
                            getword {s},#wBottom
                            cmpword {s},#wTop
                            bge check_even
                            putword {s},#wTop

check_even                  anop

                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2

                            getword {s},#wLeft+extra_stack
                            and #$FFFE
                            putword <clipx_left
; For the right, we will round up, if odd
                            getword {s},#wRight+extra_stack
                            bit #1
                            beq is_even
                            inc a
is_even                     putword <clipx_right
                            getword {s},#wTop+extra_stack
                            putword <clipy_top
                            getword {s},#wBottom+extra_stack
                            putword <clipy_bottom

                            pld

                            sret
                            end

; -----------------------------------------------------------------------------
; Clip the values in <draw_x, <draw_y, <area_width, <area_height to the clip rect
;
; This will assume that draw_x, draw_y are signed values.
; The clip rect is treated as signed, though it must have positive values, with
; a max right of 320 and bottom of 200.
; The output will be a valid screen-space area.
;
; Returns:
; carry clear, if the values are valid
; carry set, if no part of the resulting coordiates fall inside the clip rect.
_clip_coords                start seg_grlib
                            using grlib_global_equates

                            debugtag '_clip_coords'

                            lda <draw_x
                            cmp <clipx_right
                            bsge off_right                                      ; Our x greater than our right clip, if so, it is entirely clipped
                            clc
                            adc <area_width
                            cmp <clipx_left
                            bsle off_left                                       ; Is the right x of the area, less than or equal to the left clip, if so, it is entirely clipped
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the <area_width will not go to 0 or less.
                            cmp <clipx_right
                            bsle ok_right                                       ; Is the right x of the area less than the right clip?
; Part of the area is off the right clip
                            sec
                            sbc <clipx_right
; Subtract what is hanging off, from the width
                            negate a
                            clc
                            adc <area_width
                            sta <area_width
ok_right                    anop
                            lda <draw_x
                            cmp <clipx_left
                            bsge ok_left                                        ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <clipx_left
                            sec
                            sbc <draw_x
                            negate a
                            clc
                            adc <area_width
                            sta <area_width
                            lda <clipx_left                                     ; Set the x to the left clip
                            sta <draw_x

ok_left                     anop
; Do the Y/Height
                            lda <draw_y
                            cmp <clipy_bottom
                            bsge off_bottom                                     ; Our y greater than our bottom clip, if so, it is entirely clipped
                            clc
                            adc <area_height
                            cmp <clipy_top
                            bsle off_top                                        ; Is the bottom y of the area, less than or equal to the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the <area_height will not go to 0 or less.
                            cmp <clipy_bottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
; Part of the area is off the bottom clip
                            sec
                            sbc <clipy_bottom
; Subtract what is hanging off, from the height
                            negate a
                            clc
                            adc <area_height
                            sta <area_height
ok_bottom                   anop
                            lda <draw_y
                            cmp <clipy_top
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <clipy_top
                            sec
                            sbc <draw_y
                            negate a
                            clc
                            adc <area_height
                            sta <area_height
                            lda <clipy_top                                     ; Set the y to the top clip
                            sta <draw_y

ok_top                      anop
                            clc
                            rts
off_right                   anop
off_left                    anop
off_top                     anop
off_bottom                  anop
                            sec
                            rts
                            end

; -----------------------------------------------------------------------------
; Clip the values in <draw_x, <draw_y, <area_width, <area_height to the clip rect.
;
; This version assumes that the input coordinates define a shape's rect and
; will also output <shape_x_offset and <shape_y_offset to signify what amount
; of the left and top part of the shape to skip
;
; This will assume that draw_x, draw_y are signed values.
; The clip rect is treated as signed, though it must have positive values, with
; a max right of 320 and bottom of 200.
; The output will be a valid screen-space area.
;
; Returns:
; carry clear, if the values are valid
; carry set, if no part of the resulting coordiates fall inside the clip rect.
_clip_shape_coords          start seg_grlib
                            using grlib_global_equates

                            debugtag '_clip_shape_coords'
; KWG: I can see one issue with the implementation, is that at this point I'm assuming

                            stz <shape_x_offset
                            stz <shape_y_offset

                            lda <draw_x
                            cmp <clipx_right
                            bsge off_right                                      ; Our x greater than our right clip, if so, it is entirely clipped
                            clc
                            adc <area_width
                            cmp <clipx_left
                            bsle off_left                                       ; Is the right x of the area, less than or equal to the left clip, if so, it is entirely clipped
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the <area_width will not go to 0 or less.
                            cmp <clipx_right
                            bsle ok_right                                       ; Is the right x of the area less than the right clip?
; Part of the area is off the right clip
                            sec
                            sbc <clipx_right
; Subtract what is hanging off, from the width
                            negate a
                            clc
                            adc <area_width
                            sta <area_width
ok_right                    anop
                            lda <draw_x
                            cmp <clipx_left
                            bsge ok_left                                        ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <clipx_left
                            sec
                            sbc <draw_x
                            sta <shape_x_offset
                            lda <area_width
                            sec
                            sbc <shape_x_offset
                            sta <area_width
                            lda <clipx_left                                     ; Set the x to the left clip
                            sta <draw_x

ok_left                     anop
; Do the Y/Height
                            lda <draw_y
                            cmp <clipy_bottom
                            bsge off_bottom                                     ; Our y greater than our bottom clip, if so, it is entirely clipped
                            clc
                            adc <area_height
                            cmp <clipy_top
                            bsle off_top                                        ; Is the bottom y of the area, less than or equal the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the <area_height will not go to 0 or less.
                            cmp <clipy_bottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
; Part of the area is off the bottom clip
                            sec
                            sbc <clipy_bottom
; Subtract what is hanging off, from the height
                            negate a
                            clc
                            adc <area_height
                            sta <area_height
ok_bottom                   anop
                            lda <draw_y
                            cmp <clipy_top
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <clipy_top
                            sec
                            sbc <draw_y
                            sta <shape_y_offset
                            lda <area_height
                            sec
                            sbc <shape_y_offset
                            sta <area_height
                            lda <clipy_top                                     ; Set the y to the top clip
                            sta <draw_y

ok_top                      anop
                            clc
                            rtl
off_right                   anop
off_left                    anop
off_top                     anop
off_bottom                  anop
                            sec
                            rtl
                            end
; -----------------------------------------------------------------------------
; Copy the entire alternate screen buffer to the back buffer
; This does not use the clipping rect.
;
; This is not optimized, but is not called often.
; -----------------------------------------------------------------------------
grlib_alt_screen_to_back_buffer start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            phd
                            lda >grlib~dp
                            tcd

; Use patched code like grlib_screen_to_alt_screen?
                            ldy #$7cfe          ;copy the whole 32k
c1                          lda [<altscr_ptr],y
                            sta [<back_ptr],y
                            dey
                            dey
                            bpl c1

                            pld
                            rtl
                            end
; -----------------------------------------------------------------------------
; Copy the entire real screen to the alternate screen buffer
; This does not use the clipping rect.
;
; This is not optimized, but is not called often.
; -----------------------------------------------------------------------------
grlib_screen_to_alt_screen  start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            phd
                            lda >grlib~dp
                            tcd

; long addressing is faster than [zp] adressing by one cycle.
; Should unroll the loop too.
                            lda <altscr_ptr
                            sta mod+1
                            lda <targetscr_ptr
                            sta c1+1
                            shortm
                            lda <altscr_ptr+2
                            sta mod+3
                            lda <targetscr_ptr+2
                            sta c1+3
                            longm
                            ldx #$7cfe          ;copy the whole 32k
c1                          lda >$000000,x
mod                         sta >$ffffff,x
                            dex
                            dex
                            bpl   c1

                            pld
                            rtl
                            end
; -----------------------------------------------------------------------------
; Copy the entire back buffer to the alternate screen buffer
; This does not use the clipping rect.
;
; It does use the optimized copy function
; -----------------------------------------------------------------------------
grlib_back_buffer_to_alt_screen start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            phd
                            lda >grlib~dp
                            tcd

                            stz <draw_x
                            stz <draw_y
                            lda #320
                            sta <area_width
                            lda #200
                            sta <area_height
                            jsr _back_buffer_to_alt_screen_area_unrolled

                            AGO .skip
; Unoptimized code for reference
                            ldy #$7cfe          ;copy the whole 32k
c1                          lda [<back_ptr],y
                            sta [<altscr_ptr],y
                            dey
                            dey
                            bpl c1
.skip
                            pld
                            rtl
                            end
; -----------------------------------------------------------------------------
; Copy the entire alternate screen to the real screen.
; This does not use the clipping rect.
;
; This does use the optimized transfer code.
; -----------------------------------------------------------------------------
grlib_alt_screen_to_screen  start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag 'grlib_alt_screen_to_screen'
                            phd
                            lda >grlib~dp
                            tcd

                            stz <draw_x
                            stz <draw_y
                            lda #320
                            sta <area_width
                            lda #200
                            sta <area_height
                            jsr _transfer_area_to_screen_unrolled_noclip

; The un-optimized code, for reference
                            AGO .skip
                            lda   <altscr_ptr
                            sta   mod+1
                            lda   <targetscr_ptr
                            sta   mod2+1
                            shortm
                            lda   <altscr_ptr+2
                            sta   mod+3
                            lda   <targetscr_ptr+2
                            sta   mod2+3
                            longm
                            ldx   #$7cfe          ;copy the whole 32k
mod                         lda   >$ffffff,x
mod2                        sta   >$000000,x
                            dex
                            dex
                            bpl   mod
.skip

                            pld
                            rtl

                            end

; ----------------------------------------------------------------------
; Copy a rect on the alt-screen to the real screen
; Parameters:
;  wLeft            - pixel X
;  wTop             - pixel y
;  wWidth           - pixel width
;  wHeight          - pixel height
;
grlib_alt_screen_to_screen_rect start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag 'grlib_alt_screen_to_screen_rect'

                            begin_locals
work_area_size              end_locals

                            ssub (2:wLeft,2:wTop,2:wWidth,2:wHeight),work_area_size

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

                            jsr _clip_coords
                            bcs exit
                            jsr _transfer_area_to_screen_unrolled_noclip

exit                        anop
                            pld
                            sret

                            end

; ----------------------------------------------------------------------
; Copy a rect on the alt-screen to the real screen
; This assumes everything is already setup.  i.e. DP, grlib variables
grlib_custom_alt_screen_to_screen_rect start seg_grlib

                            jsr _clip_coords
                            bcs exit
                            jsr _transfer_area_to_screen_unrolled_noclip

exit                        anop
                            rtl

                            end

; ----------------------------------------------------------------------
; Copy a rect on the alt-screen to the real screen
; This assumes everything is already setup.  i.e. DP, grlib variables
grlib_custom_alt_screen_to_screen_rect_noclip start seg_grlib

                            jsr _transfer_area_to_screen_unrolled_noclip

exit                        anop
                            rtl

                            end

; -----------------------------------------------------------------------------
; Turn on the SHR screen
grlib_set_shr_mode          start seg_grlib
                            using grlib_global_data
                            using softswitch_definitions

                            debugtag 'grlib_set_shr_mode'

                            lda #grlib~switch_off
                            sta >grlib~in_text_mode
                            shortm
                            lda >ssw~newvid
                            ora #ssw~newvid~shr+ssw~newvid~shr_mmap
                            sta >ssw~newvid
                            longm

                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the text mode on or off.
; This assumes that when text mode is off, the app wants the SHR screen visible
;
; Parameters:
; acc - 0 for off, 1 for on.
grlib_set_text_mode         start seg_grlib
                            using grlib_global_data
                            using textlib_global_data
                            using softswitch_definitions

vidtext~bank0_page1         equ $e00400
vidtext~bank1_page1         equ $e00400

                            cmp #0
                            beq want_off
; Turn on.
                            lda >grlib~in_text_mode
                            bmi exit                        ; Already on

                            shortm
                            lda >ssw~newvid
                            and #(ssw~newvid~shr*-1)-1      ; Turn off SHR, but note, we are leaving the memory mapping on
                            sta >ssw~newvid
                            sta >ssw~txtset
                            sta >ssw~setaltchar
                            longm
                            lda #grlib~switch_on
                            sta >grlib~in_text_mode
exit                        rtl
want_off                    lda >grlib~in_text_mode
                            bpl exit                        ; already off
                            shortm
                            lda >ssw~newvid
                            ora #ssw~newvid~shr+ssw~newvid~shr_mmap
                            sta >ssw~newvid
                            longm
                            lda #grlib~switch_off
                            sta >grlib~in_text_mode
                            rtl

newvid                      ds 1
rd80vid                     ds 1
                            end

; -----------------------------------------------------------------------------
; Wait for a complete cycle of the frame.
grlib_wait_one_frame        start seg_grlib
                            using grlib_global_data
                            using softswitch_definitions

; We are going to waste a lot of time, we might as well be quick about it.
; Set DP to the soft-switch page, and use DP addressing
                            phd
                            lda #$c000
                            tcd
                            shortm
                            lda <$19            ; ssw~rdvbl
                            bpl not_in_vbl     ; If bit 7 is off, we are not in the VBL (See Tech Note #40 !)
; Already in, and we don't know how far in, so wait for it to finish
vbl_wait                    lda <$19
                            bmi vbl_wait
; Now wait for the next one.
not_in_vbl                  lda <$19
                            bpl not_in_vbl
                            longm
                            pld
                            rtl

                            end
; -----------------------------------------------------------------------------
softswitch_definitions      data seg_grlib

ssw~bank                    equ $00c000         ; The bank that all the soft-switches are in.  Handy for mapping the DP to the bank, for quicker access of switches, mainly when writing to the DOC

ssw~kbd_data                equ $00c000
ssw~kbd_data~new_data       equ %10000000
ssw~kbd_data~ascii_mask     equ %01111111

; Write (or read) to clear last keyboard data.  Can be 16-bit, as $c010-c01f works.
ssw~kbd_strobe              equ $00c010

ssw~mouse_data              equ $00c024
ssw~mouse~button0           equ %10000000       ; If 1, button 0 down
ssw~mouse~move_delta_mask   equ %01111111       ; Delta of mouse movement, with bit-6 being the sign.  Must be read twice in a row, once for Y, the second returns X

ssw~key_modifiers           equ $00c025
ssw~key_down_apple          equ %10000000
ssw~key_down_option         equ %01000000
ssw~modifer_key_latch       equ %00100000       ; If 1, then the modfier switch was read, but there is no new key in kbd_data.  This can be used to detect a key up / release for the last character in kbd_data
ssw~key_down_keypad         equ %00010000       ; Any key is down on the keypad.  Used to differentiate between top row numbers and the number pad?  Probably
ssw~key_down_repeat         equ %00001000       ; The repeat of a key has started.
ssw~key_down_caps_lock      equ %00000100
ssw~key_down_control        equ %00000010
ssw~key_down_shift          equ %00000001

ssw~adb_status              equ $00c027
ssw~adb_status~mouse_full           equ %10000000
ssw~adb_status~mouse_interrupts     equ %01000000
ssw~adb_status~data_full            equ %00100000
ssw~adb_status~data_interrupts      equ %00010000
ssw~adb_status~keyboard_full        equ %00001000
ssw~adb_status~keyboard_interrupts  equ %00000100
ssw~adb_status~mouse_xy             equ %00000010
ssw~adb_status~command_full         equ %00000001

ssw~txtset                  equ $00c051
ssw~clr80vid                equ $00c00c
ssw~set80vid                equ $00c00d
ssw~rd80vid                 equ $00c01f
ssw~rdvbl                   equ $00c019	        ; If 1, then NOT in VBL, according to the HW Reference, but Tech Note #40 seems to invert the logic.
ssw~clraltchar              equ $00c00e
ssw~setaltchar              equ $00c00f

ssw~newvid                  equ $00c029
ssw~newvid~shr              equ %10000000
ssw~newvid~shr_mmap         equ %01000000       ; If 1, the shr memory is linear, else it is interleaved, like the standard-hires mode
ssw~newvid~dhr_bw           equ %00100000
ssw~newvid~reserved         equ %00011110
ssw~newvid~128k_bank_latch  equ %00000001

; See IIgs Technote #36
ssw~vertical_vid_counter    equ $00c02e         ; Vertical video beam location (upper 8 bits, of a 9-bit value)
; The full range is 7D-FF, with 80-E3 being in view.  The resolution (scan line / 2).
; Note, the low-bit of the 9-bit value is in the high-bit of the horizontal counter.
ssw~horizontal_vid_counter  equ $00c02f         ; Horizontal video beam location.
; Bits 0-5 bits are the horizontal position, with bit 6, being on, if the beam is in view, off if in the horizontal blanking.
; Bit 7 is the low-bit of the vertical beam position.
; Note that sampling this value, can give a quick random number between 0 and $3f.

ssw~shadow                  equ $00c035
ssw~shadow~lang_card_inhibit  equ %01000000
ssw~shadow~textpage2_inhibit  equ %00100000     ; Only on 1mb IIgs boxes (ROM 03)
ssw~shadow~aux_hires_inhibit  equ %00010000     ; Inhibts any hires area in the aux ($01) bank
ssw~shadow~shr_inhibit        equ %00001000
ssw~shadow~hirespage2_inhibit equ %00000100     ; Inhibits hires page 2 for both banks ($00 and $01)
ssw~shadow~hirespage1_inhibit equ %00000010     ; Inhibits hires page 1 for both banks ($00 and $01)
ssw~shadow~textpage1_inhibit  equ %00000001     ; Inhibits text page 1 for both banks ($00 and $01)

ssw~speed_reg               equ $00c036
ssw~speed_reg~shadow_all_banks equ %00100000
ssw~speed_reg~power_on      equ %01000000
ssw~speed_reg~fast          equ %10000000

ssw~txtpage1                equ $00c054
ssw~txtpage2                equ $00c055

ssw~state_reg               equ $00c068
ssw~state_reg~intcxrom      equ %00000001       ; If this bit is 1, the internal ROM at $CxOO is selected. If this bit is 0, the peripheral-card ROM at CxOO is selected.
ssw~state_reg~rombank       equ %00000010       ; The ROM bank select switch must always be 0. To maintain system integrity, do not modify this bit.
ssw~state_reg~lcbnk2        equ %00000100       ; If this bit is 1, language-card RAM bank 1 is selected. If this bit is 0, language-card RAM bank 2 is selected.
ssw~state_reg~rdrom         equ %00001000       ; If this bit is 1, the selected language-card ROM is read-enabled. If this bit is 0, the selected language-card RAM bank is read-enabled.
ssw~state_reg~ramwrt        equ %00010000       ; If this bit is 1, auxiliary RAM bank is write-enabled. If this bit is 0, main RAM bank is write-enabled.
ssw~state_reg~ramrd         equ %00100000       ; If this bit is 1, auxiliary RAM bank is read-enabled. If this bit is 0, main RAM bank is read-enabled.
ssw~state_reg~page2         equ %01000000       ; If this bit is 1, text Page 2 is selected. If this bit is 0, text Page 1 is selected.
ssw~state_reg~altzp         equ %10000000       ; If this bit is 1, then bank-switched memory, stack, and direct page are in main memory. If this bit is 0, then bank-switched memory, stack, and direct page are in auxiliary memory.

ssw~button_0                equ $00c061
ssw~button_1                equ $00c062
ssw~button_2                equ $00c063
ssw~button_3                equ $00c060         ; Yes, correct address.

ssw~paddle_0                equ $00c064         ; high bit on, while timer is active.
ssw~paddle_1                equ $00c065         ; high bit on, while timer is active.
ssw~paddle_2                equ $00c066         ; high bit on, while timer is active.
ssw~paddle_3                equ $00c067         ; high bit on, while timer is active.

ssw~paddle_trigger          equ $00c070         ; read or write to trigger the paddle reading timer.

                            end



