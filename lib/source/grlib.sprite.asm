                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/grlib.update.rects.definitions.asm

                            mcopy generated/grlib.sprite.macros

                            longa on
                            longi on

; --------------------------------------------------------------------------------------------
; Sprites are a struct that contains a shape pointer, its desired draw location
; and the shape's bounding rect.  It also contains information about where the sprite was
; last drawn, if at all.
; A sprite can be thought of as a shape with positional information that helps
; with drawing and erasing the shape.
; Sprites are also usually expected to move around, i.e. one or more of them is used to
; be the visual representation of some app/game object.
; Sprites may be used for some UI elements, but usually, those are at a fixed position
; and would be better served with more direct control of how they are drawn.
; Most sprites will be draw into a 'playfield' and are usually part of a sorted draw list.


; -----------------------------------------------------------------------------
; Construct a sprite
; Parameters:
; pThis             the sprite
; Returns:
; Nothing
sprite_construct            start seg_grlib
                            using sprite_manager_errors

                            debugtag 'sprite_construct'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            setdatabanktoptr <pThis

                            ldx <pThis
                            putzero {x},#sprite~primary_shape_ptr
                            putzero {x},#sprite~primary_shape_ptr+2
                            putzero {x},#sprite~secondary_shape_ptr
                            putzero {x},#sprite~secondary_shape_ptr+2
                            putzero {x},#sprite~info

; Leaving the rest uninitialized for the moment
                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Construct a sprite
; Parameters:
; X has short pointer
; Assumes bank is already set correctly.
; Returns:
; Nothing
sprite_construct_implicit   start seg_grlib

;                           debugtag 'construct_implicit'

                            putzero {x},#sprite~primary_shape_ptr
                            putzero {x},#sprite~primary_shape_ptr+2
                            putzero {x},#sprite~secondary_shape_ptr
                            putzero {x},#sprite~secondary_shape_ptr+2
                            putzero {x},#sprite~info

                            rtl
                            end

; -----------------------------------------------------------------------------
sprite_destruct             start seg_grlib
                            debugtag 'sprite_destruct'

                            begin_locals
result                      decl word                                           ; result value inside our local work area
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit

                            lda #$dddd
                            putptr [<pThis],#sprite~primary_shape_ptr
                            putptr [<pThis],#sprite~secondary_shape_ptr

exit                        anop
                            ret
                            end

; --------------------------------------------------------------------------------------------
; Allocate a new sprite object.
; This allocates from the sprite managers fixed pool.
;
; Parameters: none
; Returns:
; if carry clear, the pointer to the object, will not be null
; if carry set, null
sprite_new                  start seg_grlib
                            using sprite_manager_data
; Define our work area data
                            begin_locals
result                      decl ptr                                ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'sprite_new'

                            sub ,work_area_size

                            pushptr #global_sprite_manager+sprite_manager~pool
                            jsl fixed_buffer_pool_alloc
                            bcs allocation_error
                            putretptr <result
                            pushretptr
                            jsl sprite_construct
                            clc                                     ; no error
exit                        retkc 4:result
allocation_error            anop
                            clearptr <result
                            sec                                     ; error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Deallocate a sprite object.
; Note that this will destruct a sprite that is not owned by the manager correctly.
;
; Parameters:
; pThis             - the sprite pointer.
; Returns:
; nothing
sprite_delete               start seg_grlib
                            using sprite_manager_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'sprite_delete'

                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit

                            pushptr <pThis
                            jsl sprite_destruct

; It is safe to call this with a pointer the buffer does not own
                            pushptr #global_sprite_manager+sprite_manager~pool
                            pushptr <pThis
                            jsl fixed_buffer_pool_free

exit                        ret
                            end

; -----------------------------------------------------------------------------
; Reset the contents of a sprite
; Parameters:
; pThis             the sprite
sprite_reset                start seg_grlib
                            using sprite_manager_errors

                            debugtag 'sprite_reset'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq null_pointer

                            lda #0
                            putptr [<pThis],#sprite~primary_shape_ptr
                            putptr [<pThis],#sprite~secondary_shape_ptr
                            putword [<pThis],#sprite~info
; Leaving the rest uninitialized for the moment

                            clc
exit                        anop
                            retkc
null_pointer                sec
                            bra exit
                            end

; ------------------------------------------------------------------------------
; This will add the the sprite's erase rect and draw rect to the erase/update rects.
; This should be called when the sprite is at its final destination for the frame.
; i.e. It is not going to move any more.  If it does, then invalidate would need
; to be called again, however, there would be an update rect queued up, that
; was not needed.
;
; Parameters:
; pSprite   the sprite to invalidate.
; wX        x coord for the sprite, in view coords
; wY        y coord for the sprite, in view coords
;
; Returns:
; carry clear, the sprite's draw rect, was added to the update rects.
; carry set, the  sprite's draw rect, was not, added to the update rects (clipped)
; This is useful to see if the sprite is off the screen.
;
; WARNING: To speed this up a bit, the caller is responsible for cleaning the parameters
;          pushed to the stack!
grlib_invalidate_sprite     start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'invalidate_sprite'

                            begin_locals
work_area_size              end_locals

                            ssub (4:pSprite,2:wX,2:wY),work_area_size

                            phd
                            phb                                             ; 3

stack_adjust                equ 3                                           ; adjustment, based on the 3 bytes we have on the stack above

                            shortm                                          ; 3
                            lda <pSprite+2+stack_adjust,s                   ; 4, get the sprite bank
                            pha                                             ; 3
                            longm                                           ; 3
                            plb                                             ; 4

                            getword {s},#pSprite+stack_adjust               ; y will point to the sprite
                            tay

                            lda >grlib~dp                                   ; Set the grlib~dp
                            tcd

                            getword {y},#sprite~info
                            static_assert_equal sprite~info~needs_erase,$8000
;                           bit #sprite~info~needs_erase
                            bpl no_erase                                    ; we can just go on the negative flag
; Clear flag
                            eor #sprite~info~needs_erase
                            putword {y},#sprite~info

; Put the erase values into the erase rects
                            static_assert_equal urlib_group~erase,0
;                           lda #urlib_group~erase
;                           sta <urdp~group
                            stz <urdp~group
                            getword {y},#sprite~erase~left
                            sta <urdp~left
                            getword {y},#sprite~erase~top
                            sta <urdp~top
                            getword {y},#sprite~erase~right
                            sta <urdp~right
                            getword {y},#sprite~erase~bottom
                            sta <urdp~bottom
                            jsl grlib_add_screen_space_rect_to_update_always_merge

; We will need to put the erase rect in the update rects, however, if we are going to draw something
; it would be best to just add a merged rect of the draw and erase rect.
                            getword {s},#pSprite+stack_adjust               ; restore the sprite pointer
                            tay
                            brl has_erase                                   ; go to the draw rect pathway that knows there is an erase rect

no_erase                    anop
; We may need a flag here, signifying that the sprite is to be drawn or not, i.e. it has been removed.

; Get the pointer to the shape table. We are going to be as quick as possible with testing
; and just assume if the high word is 0, then the whole pointer is null.  i.e. No shape data in bank 0.
                            getword {y},#sprite~primary_shape_ptr+2
                            beq offscreen_exit

; Add the draw rect to the update
; This doesn't do any drawing, it is just signifying that we will eventually draw to that area.
; This will also update the bounds rect.  I'm not currently transferring the rect to the erase rect.
; That will be done when the sprite is actually drawn.

                            ago .skip_no_origin
                            getword {y},#sprite~info                        ; this test cost 5+8+3, and it is rare that we don't have origin relative drawing.  Hmm...
                            bit #sprite~info~origin_relative
                            jeq upper_left
.skip_no_origin

                            getword {s},#wX+stack_adjust
                            sec
                            sbcword {y},#sprite~offset_x
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4
                            cmp <urdp~max~right                             ; 4
                            bsge clipped
                            putword {y},#sprite~bounds~left
                            sta <urdp~left

                            getword {s},#wY+stack_adjust
                            sec
                            sbcword {y},#sprite~offset_y
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge clipped
                            putword {y},#sprite~bounds~top
                            sta <urdp~top

                            getword {y},#sprite~width
                            clc
                            adc <urdp~left
                            cmp <urdp~max~left                              ; 4
                            bslt clipped
                            putword {y},#sprite~bounds~right
                            sta <urdp~right

                            getword {y},#sprite~height
                            clc
                            adc <urdp~top
                            cmp <urdp~max~top                               ; 4
                            bslt clipped
                            putword {y},#sprite~bounds~bottom
                            sta <urdp~bottom

                            lda #urlib_group~update*2
                            sta <urdp~group

                            jsl grlib_add_screen_space_rect_to_update_always_merge

exit                        anop
                            restoredatabank
                            pld
;                           sretkc
                            rtl

; Clipped.  Do stack cleanup and exit
clipped                     anop
offscreen_exit              restoredatabank                                 ; 4
                            pld                                             ; 5
;                           sretcs                                          ; 36
                            sec
                            rtl

                            ago .skip_no_origin
; Draw location is from the upper left
upper_left                  lda #urlib_group~update*2
                            sta <urdp~group

                            getword {s},#wX+stack_adjust
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4
                            cmp <urdp~max~right                             ; 4
                            bsge clipped
                            putword {y},#sprite~bounds~left
                            sta <urdp~left

                            getword {s},#wY+stack_adjust
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge clipped
                            putword {y},#sprite~bounds~top
                            sta <urdp~right

                            getword {y},#sprite~width
                            clc
                            adc <urdp~left
                            cmp <urdp~max~left                              ; 4
                            bslt clipped
                            putword {y},#sprite~bounds~right
                            sta <urdp~right

                            getword {y},#sprite~height
                            clc
                            adc <urdp~top
                            cmp <urdp~max~top                               ; 4
                            bslt clipped
                            putword {y},#sprite~bounds~bottom
                            sta <urdp~bottom
                            jsl grlib_add_screen_space_rect_to_update_always_merge
                            restoredatabank
                            pld
;                           sretkc
                            rtl
.skip_no_origin
;;;;
; Pathway, if there there was an erase

has_erase                    anop
; Get the pointer to the shape table. We are going to be as quick as possible with testing
; and just assume if the high word is 0, then the whole pointer is null.  i.e. No shape data in bank 0.
                            getword {y},#sprite~primary_shape_ptr+2
                            beq just_erase

; Add the draw rect to the update
; This pathway assumes that the sprite~erase rect also needs to be added to the update rects, and will merge the draw and erase rect
; Note, this doesn't test for overlap, and if there isn't any, this can end up adding a rect, larger than what is desired.

                            ago .skip_no_origin
                            getword {y},#sprite~info
                            bit #sprite~info~origin_relative
                            jeq upper_left_with_erase
.skip_no_origin

                            getword {s},#wX+stack_adjust
                            sec
                            sbcword {y},#sprite~offset_x
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4
                            cmp <urdp~max~right                             ; 4
                            bsge just_erase
                            putword {y},#sprite~bounds~left
                            cmpword {y},#sprite~erase~left
                            bslt draw_left_ok
                            getword {y},#sprite~erase~left
draw_left_ok                sta <urdp~left

                            getword {s},#wY+stack_adjust
                            sec
                            sbcword {y},#sprite~offset_y
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge just_erase
                            putword {y},#sprite~bounds~top
                            cmpword {y},#sprite~erase~top
                            bslt draw_top_ok
                            getword {y},#sprite~erase~top
draw_top_ok                 sta <urdp~top

                            getword {y},#sprite~width
                            clc
                            adcword {y},#sprite~bounds~left
                            cmp <urdp~max~left                              ; 4
                            bslt just_erase
                            putword {y},#sprite~bounds~right
                            cmpword {y},#sprite~erase~right
                            bsge draw_right_ok
                            getword {y},#sprite~erase~right
draw_right_ok               sta <urdp~right

                            getword {y},#sprite~height
                            clc
                            adcword {y},#sprite~bounds~top
                            cmp <urdp~max~top                               ; 4
                            bslt just_erase
                            putword {y},#sprite~bounds~bottom
                            cmpword {y},#sprite~erase~bottom
                            bsge draw_bottom_ok
                            getword {y},#sprite~erase~bottom
draw_bottom_ok              sta <urdp~bottom

                            lda #urlib_group~update*2
                            sta <urdp~group

                            jsl grlib_add_screen_space_rect_to_update_always_merge

                            restoredatabank
                            pld
;                           sret                                            ; if we got here, then we were not clipped, so return carry clear
                            clc
                            rtl

; The draw rect was clipped, but we had an erase rect.  Just add the erase rect to the update rects
just_erase                  anop
                            lda #urlib_group~update*2
                            sta <urdp~group
                            getword {y},#sprite~erase~left
                            sta <urdp~left
                            getword {y},#sprite~erase~top
                            sta <urdp~top
                            getword {y},#sprite~erase~right
                            sta <urdp~right
                            getword {y},#sprite~erase~bottom
                            jsl grlib_add_screen_space_rect_to_update_always_merge

                            restoredatabank
                            pld
;                           sretcs
                            sec
                            rtl

                            ago .skip_no_origin
upper_left_with_erase       anop

                            getword {s},#wX+stack_adjust
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_x              ; 4
                            cmp <urdp~max~right                             ; 4
                            bsge just_erase
                            putword {y},#sprite~bounds~left
                            cmpword {y},#sprite~erase~left
                            bslt draw_left_ok_ul
                            getword {y},#sprite~erase~left
draw_left_ok_ul             sta <urdp~left

                            getword {s},#wY+stack_adjust
                            clc                                             ; 2
                            adc <urdp~to_screen_space_offset_y              ; 4
                            cmp <urdp~max~bottom                            ; 4
                            bsge just_erase
                            putword {y},#sprite~bounds~top
                            cmpword {y},#sprite~erase~top
                            bslt draw_top_ok_ul
                            getword {y},#sprite~erase~top
draw_top_ok_ul              sta <urdp~right

                            getword {y},#sprite~width
                            clc
                            adcword {y},#sprite~bounds~left
                            cmp <urdp~max~left                              ; 6
just_erase_hitch            bslt just_erase
                            putword {y},#sprite~bounds~right
                            cmpword {y},#sprite~erase~right
                            bsge draw_right_ok_ul
                            getword {y},#sprite~erase~right
draw_right_ok_ul            sta <urdp~right

                            getword {y},#sprite~height
                            clc
                            adcword {y},#sprite~bounds~top
                            cmp <urdp~max~top                               ; 4
                            bslt just_erase_hitch
                            putword {y},#sprite~bounds~bottom
                            cmpword {y},#sprite~erase~bottom
                            bsge draw_bottom_ok_ul
                            getword {y},#sprite~erase~bottom
draw_bottom_ok_ul           sta <urdp~bottom
                            lda #urlib_group~update*2
                            sta <urdp~group
                            jsl grlib_add_screen_space_rect_to_update_always_merge

                            restoredatabank
                            pld
;                           sret                                            ; if we get here, then we were not clipped, so return carry clear
                            clc
                            rtl
.skip_no_origin
                            end

; -----------------------------------------------------------------------------
; Loop over the the rects in the erase group of the Update Rects
; and erase them with the background pixels.
;
; A scrolling playfield style game, may not even bother doing this at all,
; instead relying on a custom background draw function to draw first, to do
; any erasing.
; Might also want to have a way to specify that the background is a simple
; solid color, which would be faster.
;
grlib_erase_invalidated_rects start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data

                            debugtag 'erase_invalidated_rects'

; Going to use the grlib DP values
                            phd
                            lda >grlib~dp
                            tcd

                            setlocaldatabank

;                           keyed_break 4,'_erase_invalidated_rects'

                            ldx #urlib_group~erase*2
                            lda update_rects_count,x
                            beq no_rects

                            sta wRectCount
                            lda update_rects_group_offset,x
                            sta wRectsOffset
                            tax

loop                        anop
; Horizontal
                            lda update_rects~left,x
                            sta <draw_x
                            cmp <clipx_right
                            bsge clipped                                         ; Our x greater than our right clip, if so, it is entirely clipped
                            lda update_rects~right,x
                            cmp <clipx_left
                            bsle clipped                                        ; Is the right x of the area, less than or equal the left clip, if so, it is entirely clipped
                            sta <area_width                                     ; really has the right edge for now
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the width will not go to 0 or less.
                            cmp <clipx_right
                            bsle ok_right                                        ; Is the right x of the area less than the right clip?
                            lda <clipx_right
                            sta <area_width
ok_right                    anop
                            lda <draw_x
                            cmp <clipx_left
                            bsge ok_left                                         ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <clipx_left
                            sta <draw_x
ok_left                     anop
; Vertical
                            lda update_rects~top,x
                            sta <draw_y
                            cmp <clipy_bottom
                            bsge clipped                                        ; Our y greater than our bottom clip, if so, it is entirely clipped
                            lda update_rects~bottom,x
                            sta <area_height
                            cmp <clipy_top
                            bsle clipped                                        ; Is the bottom y of the area, less that the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the height will not go to 0 or less.
                            cmp <clipy_bottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
                            lda <clipy_bottom
                            sta <area_height

ok_bottom                   anop
                            lda <draw_y
                            cmp <clipy_top
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <clipy_top                                     ; Set the y to the top clip
                            sta <draw_y

ok_top                      anop
; Get the width/height
                            lda <area_width
                            sec
                            sbc <draw_x
                            sta <area_width
                            lda <area_height
                            sec
                            sbc <draw_y
                            sta <area_height

; Might want to support erasing to a color?  It would be faster, if there is no background image.
                            jsr   _back_buffer_to_alt_screen_area_unrolled

clipped                     anop
                            ldx wRectsOffset
                            inx
                            inx
                            stx wRectsOffset

                            dec wRectCount
                            bne loop

no_rects                    restoredatabank
                            pld
                            rtl

; Locals
wRectCount                  ds 2
wRectsOffset                ds 2
                            end

; -----------------------------------------------------------------------------
; Loop over the the rects in the erase group of the Update Rects
; and fill them with a color (pattern)
;
; Parameters:
; ACC - color to fill with (full word)
grlib_fill_invalidated_rects start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data

                            debugtag 'fill_invalidated_rects'

                            tay
; Going to use the grlib DP values
                            phd
                            lda >grlib~dp
                            tcd

                            sty <scratch_word

                            setlocaldatabank

                            ldx #urlib_group~update*2        ; urlib_group~erase
                            lda update_rects_count,x
                            beq no_rects

                            sta wRectCount
                            lda update_rects_group_offset,x
                            sta wRectsOffset
                            tax

loop                        anop
; Horizontal
                            lda update_rects~left,x
                            sta <draw_x
                            cmp <clipx_right
                            bsge clipped                                         ; Our x greater than our right clip, if so, it is entirely clipped
                            lda update_rects~right,x
                            cmp <clipx_left
                            bsle clipped                                        ; Is the right x of the area, less than or eqaul to the left clip, if so, it is entirely clipped
                            sta <area_width                                     ; really has the right edge for now
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the width will not go to 0 or less.
                            cmp <clipx_right
                            bsle ok_right                                        ; Is the right x of the area less than the right clip?
                            lda <clipx_right
                            sta <area_width
ok_right                    anop
                            lda <draw_x
                            cmp <clipx_left
                            bsge ok_left                                         ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <clipx_left
                            sta <draw_x
ok_left                     anop
; Vertical
                            lda update_rects~top,x
                            sta <draw_y
                            cmp <clipy_bottom
                            bsge clipped                                        ; Our y greater than our bottom clip, if so, it is entirely clipped
                            lda update_rects~bottom,x
                            sta <area_height
                            cmp <clipy_top
                            bsle clipped                                        ; Is the bottom y of the area, less than or equal to the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the height will not go to 0 or less.
                            cmp <clipy_bottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
                            lda <clipy_bottom
                            sta <area_height

ok_bottom                   anop
                            lda <draw_y
                            cmp <clipy_top
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <clipy_top                                     ; Set the y to the top clip
                            sta <draw_y

ok_top                      anop
; Get the width/height
                            lda <area_width
                            sec
                            sbc <draw_x
                            sta <area_width
                            lda <area_height
                            sec
                            sbc <draw_y
                            sta <area_height

                            lda <scratch_word
                            jsr _altscr_fill_rect

clipped                     anop
                            ldx wRectsOffset
                            inx
                            inx
                            stx wRectsOffset

                            dec wRectCount
                            bne loop

no_rects                    restoredatabank
                            pld
                            rtl

; Locals
wRectCount                  ds 2
wRectsOffset                ds 2
                            end

; -----------------------------------------------------------------------------
; Loop over the the queued erase rects, and fill them with a color (pattern)
;
; Parameters:
; ACC - color to fill with (full word)
grlib_fill_queued_erase_rects start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data

                            debugtag 'fill_queued_erase_rects'

; Some DP values this function will use, in the grdp space
                            begin_struct grdp~caller_scratch_buffer
wRectCount                  decl word
wRectsOffset                decl word
sizeof~locals               end_struct

                            tay
; Going to use the grlib DP values
                            phd
                            lda >grlib~dp
                            tcd

                            sty <scratch_word

                            setlocaldatabank

                            lda update_rects_queued~erase_insert_offset
                            jeq no_rects
                            lsr a
                            sta <wRectCount

                            ldx #0
                            stx <wRectsOffset

loop                        anop
; The erase rects are in screen-space, but are not clipped to the clip rect yet.
; They can have negative values, if off the left or top.
; Horizontal
                            lda update_rects_queued~erase_rects~left,x
                            cmp <clipx_right
                            bsge clipped                                        ; Our x greater than our right clip, if so, it is entirely clipped
                            ldy update_rects_queued~erase_rects~right,x
                            cpy <clipx_left
                            bsle clipped                                        ; Is the right x of the area, less than or equal to the left clip, if so, it is entirely clipped
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the width will not go to 0 or less.
                            cpy <clipx_right
                            bsle ok_right                                       ; Is the right x of the area less than the right clip?
                            ldy <clipx_right
ok_right                    sty <area_width                                     ; width has the right edge for now
; Clip the left
                            cmp <clipx_left
                            bsge ok_left                                        ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <clipx_left
ok_left                     lsr a                                               ; make into bytes
                            sta <draw_x

; Vertical
                            lda update_rects_queued~erase_rects~top,x
                            cmp <clipy_bottom
                            bsge clipped                                        ; Our y greater than our bottom clip, if so, it is entirely clipped
                            ldy update_rects_queued~erase_rects~bottom,x
                            cpy <clipy_top
                            bsle clipped                                        ; Is the bottom y of the area, less than or equal to the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the height will not go to 0 or less.
                            cpy <clipy_bottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
                            ldy <clipy_bottom
ok_bottom                   sty <area_height
; Clip the top
                            cmp <clipy_top
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <clipy_top                                      ; Set the y to the top clip
ok_top                      sta <draw_y

; Get the width/height
                            lda <area_width
                            lsr a                                               ; make into bytes
                            adc #0                                              ; round up
                            sec
                            sbc <draw_x
                            sta <area_width                                     ; width will be bytes

                            lda <area_height
                            sec
                            sbc <draw_y
                            sta <area_height

                            lda <scratch_word
;                           jsr _altscr_fill_rect
; The draw_x and the width has been made into bytes so we can directly call the whole-byte function.
; Doing full bytes, even if it is drawing a bit more, is quicker than trying to be pixel precise.

; We have two options for doing the actual fill, _altscr_fill_area_wb_unrolled, which uses STA
; and _altscr_fill_area_push_words, which uses a re-mapped stack and PHA.  The latter is faster,
; but it has some setup overhead, and it shuts off interrupts.
; Profiles have shown that it doesn't speed up things as much as I would like, and can be slower
; with smaller rects.
; Playing on-real-hardware, at 2.8Mhz, subjectively feels a bit better with the push_words and
; I didn't notice any audio dropouts.
; It might be worth it to test the size of the rect and call _altscr_fill_area_push_words, only
; if it is above a certain size.  That adds overhead to this loop though.

; Also, using push_words, precludes using a non-shadowed alt_screen.  Maybe support patching this in?
;                           jsr _altscr_fill_area_wb_unrolled
                            jsr _altscr_fill_area_push_words

clipped                     anop
                            ldx <wRectsOffset
                            inx
                            inx
                            stx <wRectsOffset

                            dec <wRectCount
                            bne loop

no_rects                    restoredatabank
                            pld
                            rtl
                            end

; -----------------------------------------------------------------------------
; Loop over the the rects in the update group of the Update Rects
; and transfer them to the screen
grlib_update_invalidated_rects start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data

                            debugtag 'update_invalidated_rects'

; Going to use the grlib DP values
                            phd
                            lda >grlib~dp
                            tcd

                            setlocaldatabank

                            ldx #urlib_group~update*2
                            lda update_rects_count,x
                            beq no_rects

                            sta wRectCount

                            lda update_rects_group_offset,x
                            sta wRectsOffset
                            tax

loop                        anop
; Horizontal
                            lda update_rects~left,x
                            sta <draw_x
                            cmp <clipx_right
                            bsge clipped                                         ; Our x greater than our right clip, if so, it is entirely clipped
                            lda update_rects~right,x
                            cmp <clipx_left
                            bsle clipped                                        ; Is the right x of the area, less than or equal to the left clip, if so, it is entirely clipped
                            sta <area_width                                     ; really has the right edge for now
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the width will not go to 0 or less.
                            cmp <clipx_right
                            bsle ok_right                                        ; Is the right x of the area less than the right clip?
                            lda <clipx_right
                            sta <area_width
ok_right                    anop
                            lda <draw_x
                            cmp <clipx_left
                            bsge ok_left                                         ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <clipx_left
                            sta <draw_x
ok_left                     anop
; Vertical
                            lda update_rects~top,x
                            sta <draw_y
                            cmp <clipy_bottom
                            bsge clipped                                        ; Our y greater than our bottom clip, if so, it is entirely clipped
                            lda update_rects~bottom,x
                            sta <area_height
                            cmp <clipy_top
                            bsle clipped                                        ; Is the bottom y of the area, less than or equal to the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the height will not go to 0 or less.
                            cmp <clipy_bottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
                            lda <clipy_bottom
                            sta <area_height

ok_bottom                   anop
                            lda <draw_y
                            cmp <clipy_top
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <clipy_top                                     ; Set the y to the top clip
                            sta <draw_y

ok_top                      anop
; Get the width/height
                            lda <area_width
                            sec
                            sbc <draw_x
                            sta <area_width
                            lda <area_height
                            sec
                            sbc <draw_y
                            sta <area_height

                            jsr _transfer_area_to_screen_unrolled

clipped                     anop
                            ldx wRectsOffset
                            inx
                            inx
                            stx wRectsOffset

                            dec wRectCount
                            bne loop

no_rects                    restoredatabank
                            pld
                            rtl

; Locals
wRectCount                  ds 2
wRectsOffset                ds 2

                            end

; -----------------------------------------------------------------------------
; Loop over the the queued updates rects, and transfer them to the screen
grlib_update_queued_rects   start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data

                            debugtag 'update_queued_rects'

; Some DP values this function will use, in the grdp space
                            begin_struct grdp~caller_scratch_buffer
wRectCount                  decl word
wRectsOffset                decl word
sizeof~locals               end_struct

; Going to use the grlib DP values
                            phd
                            lda >grlib~dp
                            tcd

                            setlocaldatabank

                            lda update_rects_queued~update_insert_offset
                            beq no_rects

                            lsr a
                            sta <wRectCount

                            ldx #0
                            stx <wRectsOffset

loop                        anop
; Horizontal
                            lda update_rects_queued~update_rects~left,x
                            cmp <clipx_right
                            bsge clipped                                         ; Our x greater than our right clip, if so, it is entirely clipped
                            ldy update_rects_queued~update_rects~right,x
                            cpy <clipx_left
                            bsle clipped                                        ; Is the right x of the area, less than or equal to the left clip, if so, it is entirely clipped
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the width will not go to 0 or less.
                            cpy <clipx_right
                            bsle ok_right                                       ; Is the right x of the area less than the right clip?
                            ldy <clipx_right
ok_right                    sty <area_width                                     ; width has the right edge for now
; Clip left edge
                            cmp <clipx_left
                            bsge ok_left                                         ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <clipx_left
ok_left                     sta <draw_x

; Vertical
                            lda update_rects_queued~update_rects~top,x
                            cmp <clipy_bottom
                            bsge clipped                                        ; Our y greater than our bottom clip, if so, it is entirely clipped
                            ldy update_rects_queued~update_rects~bottom,x
                            cpy <clipy_top
                            bsle clipped                                        ; Is the bottom y of the area, less than or equal to the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the height will not go to 0 or less.
                            cpy <clipy_bottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
                            ldy <clipy_bottom
ok_bottom                   sty <area_height
; Clip top edge
                            cmp <clipy_top
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <clipy_top                                     ; Set the y to the top clip
ok_top                      sta <draw_y

; Get the width/height
                            lda <area_width
                            sec
                            sbc <draw_x
                            sta <area_width
                            lda <area_height
                            sec
                            sbc <draw_y
                            sta <area_height

; Not supporting non-shadowed memory alt_screen
;                           jsr _transfer_area_to_screen_unrolled_noclip
                            jsr _PEI_shadow_area_to_screen_unrolled

clipped                     anop
                            ldx <wRectsOffset
                            inx
                            inx
                            stx <wRectsOffset

                            dec <wRectCount
                            bne loop

no_rects                    restoredatabank
                            pld
                            rtl
                            end

; -----------------------------------------------------------------------------
; Draw a single sprite to the screen
;
; Parameters:
;  pSprite              - sprite to draw
;  wX                   - x location
;  wY                   - y location
grlib_draw_sprite           start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data

                            debugtag 'draw_sprite'

                            begin_locals
work_area_size              end_locals

                            ssub (4:p~pSprite,2:p~wX,2:p~wY),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd
; save the data bank too
                            phb

; to cover the stack usage above
extra_stack                 equ 3

; Set the data bank to the sprite
                            shortm
                            getword {s},#p~pSprite+2+extra_stack
                            pha
                            longm
                            plb

                            getword {s},#p~pSprite+extra_stack
                            tax                                     ; x will have the short pointer to the sprite

                            getword {x},#sprite~primary_shape_ptr
                            putword <shape_ptr
                            getword {x},#sprite~primary_shape_ptr+2
                            putword <shape_ptr+2

                            getword {x},#sprite~info
                            bit #sprite~info~origin_relative
                            beq upper_left

                            getword {s},#p~wX+extra_stack,
                            sec
                            ldy #shapedef~origin_x
                            sbc [<shape_ptr],y
                            putword <draw_x

                            getword {s},#p~wY+extra_stack
                            sec
                            ldy #shapedef~origin_y
                            sbc [<shape_ptr],y
                            putword <draw_y
                            bra origin_relative

upper_left                  getword {s},#p~wX+extra_stack
                            putword <draw_x

                            getword {s},#p~wY+extra_stack
                            putword <draw_y

origin_relative             getword [<shape_ptr],#shapedef~width
                            putword <shape_width

                            getword [<shape_ptr],#shapedef~height
                            putword <shape_height

                            getword {x},#sprite~bounds~left
                            putword {x},#sprite~erase~left
                            getword {x},#sprite~bounds~top
                            putword {x},#sprite~erase~top
                            getword {x},#sprite~bounds~right
                            putword {x},#sprite~erase~right
                            getword {x},#sprite~bounds~bottom
                            putword {x},#sprite~erase~bottom

                            getword {x},#sprite~info
                            ora #sprite~info~needs_erase
                            putword {x},#sprite~info

; See if the shape will be clipped at all
                            lda <draw_x
                            cmp <clipx_left
                            bslt is_clipped
                            clc
                            adc <shape_width
                            dec a                           ; -1 to compensate for the bge test
                            cmp <clipx_right
                            bsge is_clipped

                            lda <draw_y
                            cmp <clipy_top
                            bslt is_clipped
                            clc
                            adc <shape_height
                            dec a                           ; -1 to compensate for the bge test
                            cmp <clipy_bottom
                            bsge is_clipped
; The shape is not clipped, we can switch to the shape the does not support clipping
                            getword {x},#sprite~secondary_shape_ptr+2
                            beq not_clipped                 ; null high word == null pointer
                            putword <shape_ptr+2
                            getword {x},#sprite~secondary_shape_ptr
                            putword <shape_ptr

is_clipped                  anop
not_clipped                 anop

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
                            bra exit

not_block                   anop
                            cmp #shape_data_type~compiled_basic
                            bne not_compiled_basic

; compiled basic
                            jsl _compiled_basic_shape_draw

not_compiled_basic          anop
exit                        anop
                            plb
                            pld
                            sret
                            end

; -----------------------------------------------------------------------------
; Iterate over the update rects, drawing any sprites that overlap a rect.
; This can result in a sprite getting drawn more than once, but it should be clipped
; so that it will never overdraw itself.
;
; First implementation will use a simple pointer array to the sprites.
; A later implementation should use something that is sorted by the sprite's
; Y position, as well as have some way to test bounds.
; In the long run, the list passed to this function should *not* include anything that
; was not potentially on screen.  i.e. As sprites move around, they need to add/remove
; themselves from a 'screen' list.  At least the ones in any kind of extended playfield.
;
; This function should be considered deprecated, or at least, somewhat specialized
; such as for drawing UI sprites.
;
; Parameters:
;  pSpritePtrArray      - array of sprite pointers
;  wSpriteCount         - number of sprites in the array
                            ago .deprecated
grlib_draw_sprites_into_invalidated_rects start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data

                            debugtag 'draw_into'
                            debugtag 'invalidated_rects'

                            begin_locals
wLeft                       decl word
wRight                      decl word
wTop                        decl word
wBottom                     decl word
wClipLeft                   decl word
wClipRight                  decl word
wClipTop                    decl word
wClipBottom                 decl word
wRectCount                  decl word
wRectsOffset                decl word
wSpriteIndex                decl word
pSprite                     decl ptr
pShape                      decl ptr
pGRValues                   decl ptr
work_area_size              end_locals

                            sub (4:pSpritePtrArray,2:wSpriteCount),work_area_size

; We need to fill in some grlib DP values, but we have our own DP, so do them indirectly.
                            lda >grlib~dp
                            sta <pGRValues
                            stz <pGRValues+2

; Copy the clip rect, we will need it a lot
                            getword [<pGRValues],#clipx_left
                            sta <wClipLeft
                            getword [<pGRValues],#clipx_right
                            sta <wClipRight
                            getword [<pGRValues],#clipy_top
                            sta <wClipTop
                            getword [<pGRValues],#clipy_bottom
                            sta <wClipBottom

; Using local bank data
                            setlocaldatabank

                            ldx #urlib_group~update*2
                            lda update_rects_count,x
                            beq no_rects

                            sta <wRectCount
                            lda update_rects_group_offset,x
                            sta <wRectsOffset
                            tax

loop                        anop
; Horizontal
                            lda update_rects~left,x
                            sta <wLeft
                            cmp <wClipRight
                            bsge clipped                                         ; Our x greater than our right clip, if so, it is entirely clipped
                            lda update_rects~right,x
                            cmp <wClipLeft
                            bsle clipped                                        ; Is the right x of the area, less than or equal to the left clip, if so, it is entirely clipped
                            sta <wRight
; Something falls within the x clip
; Note, we can be assured that as we do further clipping, the width will not go to 0 or less.
                            cmp <wClipRight
                            bsle ok_right                                        ; Is the right x of the area less than the right clip?
                            lda <wClipRight
                            sta <WRight
ok_right                    anop
                            lda <wLeft
                            cmp <wClipLeft
                            bsge ok_left                                         ; Is the left x of the area, greater than or equal to our left clip?
; Some part of the left side is off the clip
                            lda <wClipLeft
                            sta <wLeft
ok_left                     anop
; Vertical
                            lda update_rects~top,x
                            sta <wTop
                            cmp <wClipBottom
                            bsge clipped                                        ; Our y greater than our bottom clip, if so, it is entirely clipped
                            lda update_rects~bottom,x
                            sta <wBottom
                            cmp <wClipTop
                            bsle clipped                                        ; Is the bottom y of the area, less than or equal to the top clip, if so, it is entirely clipped
; Something falls within the y clip
; Note, we can be assured that as we do further clipping, the height will not go to 0 or less.
                            cmp <wClipBottom
                            bsle ok_bottom                                      ; Is the bottom y of the area less than the bottom clip?
                            lda <wClipBottom
                            sta <wBottom

ok_bottom                   anop
                            lda <wTop
                            cmp <wClipTop
                            bsge ok_top                                         ; Is the top y of the area, greater than or equal to our top clip?
; Some part of the top side is off the clip
                            lda <wClipTop                                      ; Set the y to the top clip
                            sta <wTop

ok_top                      anop
; We now have the clipped rect locally.  See what sprites overlap it
                            jsr _draw_sprites

clipped                     anop
                            ldx <wRectsOffset
                            inx
                            inx
                            stx <wRectsOffset

                            dec <wRectCount
                            bne loop

no_rects                    restoredatabank
                            ret

; - Local ---------------------------------------------------------------------
; Making this a local function, just so its more readable, and we have less need for long branches
_draw_sprites               anop
                            stz <wSpriteIndex
                            lda #0

_draw_sprite_loop           asl a
                            asl a
                            tay
                            lda [<pSpritePtrArray],y
                            sta <pSprite
                            iny
                            iny
                            lda [<pSpritePtrArray],y
                            sta <pSprite+2

                            getword [<pSprite],#sprite~bounds~left
                            cmp <wRight
                            jsge sprite_clipped

                            lda <wLeft
                            ldy #sprite~bounds~right
                            cmp [<pSprite],y
                            jsge sprite_clipped

                            getword [<pSprite],#sprite~bounds~top
                            cmp <wBottom
                            jsge sprite_clipped

                            lda <wTop
                            ldy #sprite~bounds~bottom
                            cmp [<pSprite],y
                            jsge sprite_clipped

; The sprite falls in the rect, draw it

                            getword [<pSprite],#sprite~primary_shape_ptr
                            sta <pShape
                            putword [<pGRValues],#shape_ptr
                            getword [<pSprite],#sprite~primary_shape_ptr+2
                            sta <pShape+2
                            putword [<pGRValues],#shape_ptr+2

                            getword [<pSprite],#sprite~info
                            bit #sprite~info~origin_relative
                            beq upper_left

                            getword [<pSprite],#sprite~x
                            sec
                            ldy #shapedef~origin_x
                            sbc [<pShape],y
                            putword [<pGRValues],#draw_x

                            getword [<pSprite],#sprite~y
                            sec
                            ldy #shapedef~origin_y
                            sbc [<pShape],y
                            putword [<pGRValues],#draw_y
                            bra origin_relative

upper_left                  getword [<pSprite],#sprite~x
                            putword [<pGRValues],#draw_x

                            getword [<pSprite],#sprite~y
                            putword [<pGRValues],#draw_y

origin_relative             getword [<pShape],#shapedef~width
                            putword [<pGRValues],#shape_width

                            getword [<pShape],#shapedef~height
                            putword [<pGRValues],#shape_height

                            getword [<pSprite],#sprite~bounds~left
                            putword [<pSprite],#sprite~erase~left
                            getword [<pSprite],#sprite~bounds~top
                            putword [<pSprite],#sprite~erase~top
                            getword [<pSprite],#sprite~bounds~right
                            putword [<pSprite],#sprite~erase~right
                            getword [<pSprite],#sprite~bounds~bottom
                            putword [<pSprite],#sprite~erase~bottom

                            getword [<pSprite],#sprite~info
                            ora #sprite~info~needs_erase
                            sta [<pSprite],y

                            getword [<pShape],#shapedef~type
                            cmp #shape_data_type~prle
                            bne not_prle
; prle shape
                            jsl _prle_shape_draw
                            bra sprite_next

not_prle                    cmp #shape_data_type~block
                            bne not_block
; block/solid shape
                            jsl _block_shape_draw
not_block                   anop

sprite_clipped              anop
sprite_next                 lda <wSpriteIndex
                            inc a
                            sta <wSpriteIndex
                            cmp <wSpriteCount
                            jlt _draw_sprite_loop

                            rts
                            end
.deprecated
