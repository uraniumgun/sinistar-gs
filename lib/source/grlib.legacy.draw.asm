                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.legacy.draw.params.asm
                            copy lib/source/shape.definitions.asm
                            mcopy generated/grlib.legacy.draw.macros

                            longa on
                            longi on

; ------------------------------------------------------------------------------
; This file contains what was the original draw/erase/update code from
; way back in 1987, 3/27/87 to be exact, when I started it.
; The code isn't exactly the same, it was updated and used to get things going
; however, the code in here is superseded by the sprite structure, which is
; very similar in spirit, but is used in conjunction with the update rects
; to do the complete erase/draw/update cycle.
;
; The functions in here are still useful for testing as they are simple and
; self-contained.  However, since each call controls just one shape, having
; multiple shapes would end up being inefficient if they overlapped.

; Comment out the line below to enable.
                        ago .disabled
; ------------------------------------------------------------------------------
; Draw a frame of an animation, using an input parameter list
;
; Parameters:
;  The animation parameter list in A/X
;
; Parm List format
; +0          Address of the shape table (long)
; +4          Frame # to draw (word)
; +6          X coord of draw (word)
; +8          Y coord of draw (word)
; +10         Erase x coord (word)
; +12         Erase y coord (word)
; +14         Erase width in pixels (word)
; +16         Erase height (word)
; +18         Secondary erase values (erase values from previous erase)
; +26         Info (word)
;              bit 15 signifies that there is something to erase
;              bit 14 signifies that there was something erased
;               in the last erase_frame call. Secondary erase values
;               are now valid and should be included in the update routine
;              bit 13 signifies there was something drawn in the last
;               grlib_draw_frame call.
;              bit 0 - 12 reserved
grlib_draw_frame            start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag 'grlib_draw_frame'
                            profile_function_begin

                            phd
                            pha
                            lda >grlib~dp
                            tcd
                            pla
                            sta <param_ptr
                            stx <param_ptr+2

;                           keyed_break 6,'_draw_frame'
; Signify there is something to erase.
                            ldy #anmdraw_def~info
                            lda #anmdraw_def~info~needs_erase+anmdraw_def~info~has_drawn
                            ora [<param_ptr],y
                            sta [<param_ptr],y
; Set the pointer to the shape table
                            getptr [<param_ptr],#anmdraw_def~shape_ptr,<shape_ptr

; Set x/y, and the erase rectangle

; The unclipped rect ends up going into the erase rect.  Please fix.
                            getword [<param_ptr],#anmdraw_def~x,<draw_x
                            putword [<param_ptr],#anmdraw_def~erase~x            ; Copy to the erase X
                            getword [<param_ptr],#anmdraw_def~y,<draw_y
                            putword [<param_ptr],#anmdraw_def~erase~y            ; Copy to the erase Y
                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            putword [<param_ptr],#anmdraw_def~erase~w            ; Copy width to the erase width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height
                            putword [<param_ptr],#anmdraw_def~erase~h            ; Copy height to the erase width

                            getword [<shape_ptr],#shapedef~type
                            cmp #shape_data_type~prle
                            bne not_prle
; prle shape
                            jsl _prle_shape_draw
                            bra exit

not_prle                    cmp #shape_data_type~block
                            bne not_block
; block/solid shape
                            jsl _block_shape_draw
not_block                   anop

exit                        pld
                            profile_function_end
                            rtl
                            profile_function_add_symbol
                            end
; ---------------------------------------------------------------------
; Check if there is a frame to erase, if so move the erase values to
; the secondary locations and erase the shape.
; Parameters:
;  Address of the animation parameters in A/X
; ---------------------------------------------------------------------
grlib_erase_frame           start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data

                            debugtag 'grlib_erase_frame'
                            profile_function_begin
                            phd
                            pha
                            lda >grlib~dp
                            tcd
                            pla
                            sta <param_ptr
                            stx <param_ptr+2

;                           keyed_break 5,'_erase_frame'

                            lda #anmdraw_def~info~needs_erase
                            ldy #anmdraw_def~info
                            and [<param_ptr],y
                            jeq none
                            lda [<param_ptr],y
                            eor #anmdraw_def~info~needs_erase           ;shut off bit
                            ora #anmdraw_def~info~has_erased
                            sta [<param_ptr],y
; Clip the values, so the copy operation doesn't have to deal with it.
; Get the width and height first, we are going to need the values as we try and clip the values
                            getword [<param_ptr],#anmdraw_def~erase~w,<area_width
                            getword [<param_ptr],#anmdraw_def~erase~h,<area_height

                            getword [<param_ptr],#anmdraw_def~erase~x,<draw_x
                            cmp <clipx_right
                            jsge off_right                                      ; Our x greater than our right clip, if so, it is entirely clipped
                            clc
                            adc <area_width
                            cmp <clipx_left
                            jsle off_left                                       ; Is the right x of the area, less than or equal to the left clip, if so, it is entirely clipped
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

ok_left                     putword [<param_ptr],#anmdraw_def~secondary_erase~x
                            lda <area_width
                            putword [<param_ptr],#anmdraw_def~secondary_erase~w
; Do the Y/Height
                            getword [<param_ptr],#anmdraw_def~erase~y,<draw_y
                            cmp <clipy_bottom
                            bsge off_bottom                                     ; Our y greater than our bottom clip, if so, it is entirely clipped
                            clc
                            adc <area_height
                            cmp <clipy_top
                            bsle off_top                                        ; Is the bottom y of the area, less that the top clip, if so, it is entirely clipped
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
                            bsge ok_top                                        ; Is the top y of the area, greater than or equal to our top clip?
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

ok_top                      putword [<param_ptr],#anmdraw_def~secondary_erase~y
                            lda <area_height
                            putword [<param_ptr],#anmdraw_def~secondary_erase~h

                            jsr _back_buffer_to_alt_screen_area_unrolled

off_right                   anop
off_left                    anop
off_top                     anop
off_bottom                  anop
none                        pld
                            profile_function_end
                            rtl
                            profile_function_add_symbol
                            end

; ----------------------------------------------------------------------
; Update the real screen buffer from the alt-screen buffer.
;
; Look at a parameter list and see if anything was erased or drawn
; If so move the areas that were effected from the alt. buffer to
; the real screen.  If both an erase an draw occured see if the overlap
; of the areas is enough to warrant combining the areas and copying
; as one.  If not then do them separately.
;
; Parameters:
;  Pointer to the animation parameter list in A/X
;----------------------------------------------------------------------
grlib_update_screen         start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using softswitch_definitions

                            debugtag 'grlib_update_screen'
                            profile_function_begin

; This function is using local data.
                            setlocaldatabank

                            phd
                            pha
                            lda >grlib~dp
                            tcd
                            pla
                            sta <param_ptr
                            stx <param_ptr+2

; Put the dimensions in simple variables for easy access

                            getword [<param_ptr],#anmdraw_def~erase~w,w1
                            lsr a
                            sta half_w1
                            getword [<param_ptr],#anmdraw_def~secondary_erase~w,w2
                            lsr a
                            sta half_w2

                            getword [<param_ptr],#anmdraw_def~erase~x,x1
                            getword [<param_ptr],#anmdraw_def~secondary_erase~x,x2

                            getword [<param_ptr],#anmdraw_def~erase~h,h1
                            lsr a
                            sta half_h1
                            getword [<param_ptr],#anmdraw_def~secondary_erase~h,h2
                            lsr a
                            sta half_h2

                            getword [<param_ptr],#anmdraw_def~erase~y,y1
                            getword [<param_ptr],#anmdraw_def~secondary_erase~y,y2

                            getword [<param_ptr],#anmdraw_def~info              ;get info byte
                            pha
                            and #anmdraw_def~info~has_erased     ;something erased?
                            sta is_erased
                            pla
                            pha
                            and #anmdraw_def~info~has_drawn
                            sta is_drawn
                            pla
                            and #((anmdraw_def~info~has_drawn+anmdraw_def~info~has_erased)*-1)-1        ; Clear the bits
                            sta [<param_ptr],y

                            lda is_drawn
                            jeq not_drawn

; Well we know there is a draw, how about an erase
;
                            lda is_erased
                            jeq just_drawn

; There was both an erase and a draw, have to compare the areas and
; see if they overlap enough.

; All values *should* be positive at the this point.

                            lda #0
                            sta is_half_x
                            sta is_half_y

; Figure out which x is greater

                            lda x1
                            cmp x2
                            blt x_less

; x1 >= x2, so if x1 - x2 > w2 then they don't overlap!

                            ldy x2
                            sty least_x
                            sec
                            sbc x2
                            cmp w2
                            bge hitch           ;no_overlap

; Does it overlap a lot?

                            cmp half_w2
                            bge check_y         ;the overlap is less than half
                            dec is_half_x       ;set flag
                            bra check_y
; ----------------------------------------------------------

;  x2 >= x1, so if x2 - x1 > w1 then they don't overlap

x_less                      sta least_x
                            lda x2
                            sec
                            sbc x1
                            cmp w1
                            bge hitch           ;no_overlap

                            cmp half_w1
                            bge check_y
                            dec is_half_x

; ----------------------------------------------------------

; figure out which y is greater

check_y                     lda y1
                            cmp y2
                            blt y_less
                            ldy y2
                            sty least_y
; y1 >= y2, so if y1 - y2 > h2 then they don't overlap!
                            sec
                            sbc y2
                            cmp h2
                            bge hitch           ;no_overlap

; Does it overlap a lot?

                            cmp half_h2
                            bge done_check      ;the overlap is less than half
                            dec is_half_y       ;set flag
                            bra done_check
; ----------------------------------------------------------

; y2 >= y1, so if y2 - y1 > h1 then they don't overlap

y_less                      sta least_y
                            lda y2
                            sec
                            sbc y1
                            cmp h1
hitch                       bge no_overlap

                            cmp half_h1
                            bge done_check
                            dec is_half_y
; ----------------------------------------------------------

; Done with the range check, if we get here then they overlap at least
; a little.  Now check and see if both x and y ranges overlap less than
; %50 if so, do them separate, if not set as one big area and transfer

done_check                  lda is_half_x
                            bmi ok_xrange      ;x made it so that's good enough
                            lda is_half_y
                            bpl no_overlap     ;y didn't make it either, do separatly

; Set as one big area and transfer!

ok_xrange                   lda least_x
                            sta <draw_x
                            lda x1
                            clc
                            adc w1
                            sta big_edge
                            lda x2
                            clc
                            adc w2
                            cmp big_edge
                            bge larger_right
                            lda big_edge
larger_right                sec
                            sbc least_x
                            sta <area_width

                            lda least_y
                            sta <draw_y
                            lda y1
                            clc
                            adc h1
                            sta big_edge
                            lda y2
                            clc
                            adc h2
                            cmp big_edge
                            bge larger_bottom
                            lda big_edge
larger_bottom               sec
                            sbc least_y
                            sta <area_height

                            bit grlib~wait_for_vbl
                            bpl skip_vbl
; Wait until we are in the VBL.
                            shortm
scanc                       lda >ssw~rdvbl
                            bpl scanc       ; If bit 7 is off, we are not in the VBL
                            longm

skip_vbl                    jsr _transfer_area_to_screen_unrolled
                            pld
                            restoredatabank
                            profile_function_end
                            rtl
; Do a erase and draw
no_overlap                  anop
; Do the erase area
                            lda x2
                            sta <draw_x
                            lda y2
                            sta <draw_y
                            lda w2
                            sta <area_width
                            lda h2
                            sta <area_height
                            jsr _transfer_area_to_screen_unrolled
; Jump to the draw area copy
                            jmp do_draw
; ----------------------------------------------------------
; Nothing was drawn, how about erased?
not_drawn                   lda is_erased
                            beq exit                    ;nothing erased or drawn
; Do the erase area
                            lda x2
                            sta <draw_x
                            lda y2
                            sta <draw_y
                            lda w2
                            sta <area_width
                            lda h2
                            sta <area_height
                            jsr _transfer_area_to_screen_unrolled
exit                        pld
                            restoredatabank
                            profile_function_end
                            rtl
; If we come to this label, we know that something was drawn, but nothing was erased
just_drawn                  anop

do_draw                     lda x1
                            sta <draw_x
                            lda y1
                            sta <draw_y
                            lda w1
                            sta <area_width
                            lda h1
                            sta <area_height
                            jsr _transfer_area_to_screen_unrolled
                            pld
                            restoredatabank
                            profile_function_end
                            rtl

; Some temporary vars

x1                          ds    2
x2                          ds    2
y1                          ds    2
y2                          ds    2
h1                          ds    2
h2                          ds    2
w1                          ds    2
w2                          ds    2
half_h1                     ds    2
half_h2                     ds    2
half_w1                     ds    2
half_w2                     ds    2
is_half_x                   ds    2
is_half_y                   ds    2
big_edge                    ds    2
least_x                     ds    2
least_y                     ds    2
is_drawn                    ds    2
is_erased                   ds    2

                            profile_function_add_symbol
                            end
.disabled
