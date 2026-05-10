                            copy lib/source/debug.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/grlib.definitions.asm

                            copy lib/source/grlib.update.rects.definitions.asm
                            mcopy generated/grlib.update.rects.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
grlib_update_rects_data     data seg_grlib
                            using grlib_global_equates

max_update_rect_groups      equ 2
max_update_rect_count       equ 64

; An update rect.  It has the standard rect at the front, but then width/height and half width/height values
; after the rect, to speed up compares
update_rect~left            gequ 0
update_rect~top             gequ update_rect~left+2
update_rect~right           gequ update_rect~top+2
update_rect~bottom          gequ update_rect~right+2
update_rect~width           gequ update_rect~bottom+2
update_rect~height          gequ update_rect~width+2
update_rect~half_width      gequ update_rect~height+2
update_rect~half_height     gequ update_rect~half_width+2
sizeof~update_rect          gequ update_rect~half_height+2           ; 16 bytes total.  Keep it that way for easy indexing

; We are using two sets of update rects.
; One for any area that needs an erase call, and one for areas that need to be updated.
; The update areas, always contain the erase areas.  The erase areas can be used as clip-rects
; on subsequent passes to draw into.  The draws then get added to the update group.
; This allows for block-shapes/fills, to just set the update rect, and not require an erase
; that will just be filled in completely
;
; Prle shape -
;  First draw - add rect erase and update
;  Movement   - add old rect to erase and update, add new rect to erase and update
;
; Solid shape -
;  First draw - add rect to update
;  Movement   - add old rect to update, add eor of old rect and new rect to erase, add new rect to update.
;
; The question is, will there be a enough of a win, with the 'not erasing under a solid', to cancel out the
; needing to add to multiple rect lists.
; Also, in the 'play field', will there be a lot of solid shapes?  Usually those are UI.
;
; Also of note, is that the update rects, along with the clip-rect and anything that uses
; them, needs to use signed comparisons.  The overall view rects and the clip rects themselves
; are always positive numbers, but sprite bounds, need to be able to go off the edge, in all
; directions, and still compare properly.

; Below are the arrays of update rect members.  i.e. struct of arrays.
; This allows for advancing to the next rect index to always be just 2 bytes.
; This makes for quicker advancing, since the index register can be advanced by 2,
; or finding an index is just one asl.  The downside is that since the rect is
; spread out, using indirect addressing is not efficient, but this shouldn't
; be an issue, as we can always do absolute addressing.
;
; Each member array is number of groups * (2 * max_update_rect_count).

update_rect_field_array_group_size  equ 2*max_update_rect_count
update_rect_field_array_total_size  equ max_update_rect_groups*update_rect_field_array_group_size

update_rects                        anop

update_rects~left                   ds update_rect_field_array_total_size
update_rects~top                    ds update_rect_field_array_total_size
update_rects~right                  ds update_rect_field_array_total_size
update_rects~bottom                 ds update_rect_field_array_total_size
update_rects~width                  ds update_rect_field_array_total_size
update_rects~height                 ds update_rect_field_array_total_size
update_rects~half_width             ds update_rect_field_array_total_size
update_rects~half_height            ds update_rect_field_array_total_size

update_rects_count                  ds 2*max_update_rect_groups
update_rects_group_offset           ds 2*max_update_rect_groups

; Struct in grdp space for update rect functions
                                    begin_struct grdp~caller_scratch_buffer
urdp~group                          decl word
urdp~left                           decl word
urdp~top                            decl word
urdp~right                          decl word
urdp~bottom                         decl word

urdp~group_offset                   decl word
urdp~least_x                        decl word
urdp~least_y                        decl word
urdp~is_half_x                      decl word
urdp~is_half_y                      decl word
urdp~width                          decl word
urdp~half_width                     decl word
urdp~height                         decl word
urdp~half_height                    decl word
sizeof~urdp~scratch_buffer          end_struct

; Queued, non-coalesced/merged rects.

max_queued_update_rect_count        equ 128
update_rects_queued_size            equ 2*max_queued_update_rect_count

; The offset to the start of either the erase or update rects
update_rects_queued~start_offsets dc i'0,update_rects_queued_size'

; The next insert offset (essentially count*2)
update_rects_queued~insert_offsets  anop
update_rects_queued~erase_insert_offset ds 2
update_rects_queued~update_insert_offset ds 2

; The rect fields, each is separate (struct of arrays) and
; the erase/update also alternate, to match the way the merge update rects
; are stored, so a single offset can get to either type, if needed.
update_rects_queued~rects~left      anop
update_rects_queued~erase_rects~left ds update_rects_queued_size
update_rects_queued~update_rects~left ds update_rects_queued_size

update_rects_queued~rects~top       anop
update_rects_queued~erase_rects~top ds update_rects_queued_size
update_rects_queued~update_rects~top ds update_rects_queued_size

update_rects_queued~rects~right     anop
update_rects_queued~erase_rects~right ds update_rects_queued_size
update_rects_queued~update_rects~right ds update_rects_queued_size

update_rects_queued~rects~bottom    anop
update_rects_queued~erase_rects~bottom ds update_rects_queued_size
update_rects_queued~update_rects~bottom ds update_rects_queued_size

                                    end

; -----------------------------------------------------------------------------
; Did I split this because of the (now fixed) linker bug?
grlib_update_rects_data2            data seg_grlib

; The current view space origin for the update rects.  Valid after grlib_set_update_rect_origin is called.
; These will always be positive values, inside the world space.
update_rects_origin_x               dc i'0'
update_rects_origin_y               dc i'0'

; Map a view space update rect, to its screen space coordinates.  Valid after grlib_set_update_rect_origin is called.
update_rect_to_screen_space_offset_x dc i'0'
update_rect_to_screen_space_offset_y dc i'0'

; maximum rect bounds / ranges.  This is in screen space coordinates
update_rect_max                     anop
update_rect_max~left                dc i'0'
update_rect_max~top                 dc i'0'
update_rect_max~right               dc i'0'
update_rect_max~bottom              dc i'0'
update_rect_max~width               dc i'0'
update_rect_max~height              dc i'0'
update_rect_max~half_width          dc i'0'
update_rect_max~half_height         dc i'0'

; maximum rect in world space, adjusted to the view origin
; This is kept up to date, as the view origin is moved around
update_rect_max_origin              anop
update_rect_max_origin~left         ds 2
update_rect_max_origin~top          ds 2
update_rect_max_origin~right        ds 2
update_rect_max_origin~bottom       ds 2
;update_rect_max_origin~width        ds 2
;update_rect_max_origin~height       ds 2

; An exclusion test rect.  This is the rect_max, but inflated a specifed amount
; so that if the draw location of a sprite were to be outside this rect, then we
; can quickly say that the sprite will not be on screen.
update_rect_exclude~left            dc i'0'
update_rect_exclude~top             dc i'0'
update_rect_exclude~right           dc i'0'
update_rect_exclude~bottom          dc i'0'
update_rect_exclude~width           dc i'0'
update_rect_exclude~height          dc i'0'

; World size, and wrapping
; The origin wrap is always a negative number.  This helps detect that a converted screen space value needs to be 'wrapped'
                            aif grlib~support_coordinate_wrapping=0,.skip_wrapping
update_rect_origin_wrap~x           ds 2    ; screen space width - world width
update_rect_origin_wrap~y           ds 2    ; screen space height - world height
update_rect_origin_wrap_inverted~x  ds 2    ; world width - screen space width
update_rect_origin_wrap_inverted~y  ds 2    ; world height - screen space height
; The size of the world space
update_rect_world~width             ds 2
update_rect_world~height            ds 2
; Inverted sizes
update_rect_world~width_inverted    ds 2
update_rect_world~height_inverted   ds 2
.skip_wrapping
                                    end

; -----------------------------------------------------------------------------
; Initialize the Update Rects system
grlib_update_rects_initialize   start seg_grlib

                            using grlib_update_rects_data

                            debugtag 'initialize'
                            debugtag 'update_rects'

                            setlocaldatabank

                            lda #0
                            ldx #0
loop                        stz |update_rects_count,x
                            sta |update_rects_group_offset,x
                            clc
                            adc #update_rect_field_array_group_size
                            inx
                            inx
                            cpx #max_update_rect_groups*2
                            bne loop

                            pushsword #0
                            pushsword #0
                            pushsword #320
                            pushsword #200
                            jsl grlib_set_max_update_rect
                            pushsword #0
                            pushsword #0
                            jsl grlib_set_update_rect_origin

                            stz update_rects_queued~erase_insert_offset
                            stz update_rects_queued~update_insert_offset

                            restoredatabank

                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the maximum screen space update rect.
grlib_set_max_update_rect   start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'grlib_set_max_update_rect'
                            sub (2:wLeft,2:wTop,2:wRight,2:wBottom),0

exclusion_size_x            equ 100
exclusion_size_y            equ 80

                            setlocaldatabank

                            ldx grlib~dp                                ; going to save some values on the dp

                            lda <wLeft
                            sta update_rect_max~left
                            sta >urdp~max~left,x                        ; save on the grlib_dp too

                            lda <wTop
                            sta update_rect_max~top
                            sta >urdp~max~top,x                         ; save on the grlib_dp too

                            lda <wRight
                            sta update_rect_max~right
                            sta >urdp~max~right,x                       ; save on the grlib_dp too
                            sec
                            sbc <wLeft
                            sta update_rect_max~width
                            lsr a
                            sta update_rect_max~half_width

                            lda <wBottom
                            sta update_rect_max~bottom
                            sta >urdp~max~bottom,x                      ; save on the grlib_dp too
                            sec
                            sbc <wTop
                            sta update_rect_max~height
                            lsr a
                            sta update_rect_max~half_height

; Set the exclusion size
                            lda <wLeft
                            sec
                            sbc #exclusion_size_x
                            sta update_rect_exclude~left
                            lda <wTop
                            sec
                            sbc #exclusion_size_y
                            sta update_rect_exclude~top

                            lda <wRight
                            clc
                            adc #exclusion_size_x
                            sta update_rect_exclude~right
                            sec
                            sbc update_rect_exclude~left
                            sta update_rect_exclude~width

                            lda <wBottom
                            clc
                            adc #exclusion_size_y
                            sta update_rect_exclude~bottom
                            sec
                            sbc update_rect_exclude~top
                            sta update_rect_max~height

                            restoredatabank

                            ret
                            end

; -----------------------------------------------------------------------------
; Set the wrapping values for the update rects.
; This is the point where a rect that is added to the update rects, is wrapped
; so that if the view is partially off the bottom, or right, an object in
; world space at the top or left, will appear in the final screen space coordinates.
;
; The input is usually
; x = the view width - the world width
; y = the view height - the world height

grlib_set_update_rect_world_size start seg_grlib
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'grlib_set_update_rect_world_size'
                            sub (2:wWidth,2:wHeight),0

                            aif grlib~support_coordinate_wrapping=0,.skip_wrapping
                            setlocaldatabank

                            lda update_rect_max~width
                            sec
                            sbc <wWidth
                            sta update_rect_origin_wrap~x
                            negate a
                            sta update_rect_origin_wrap_inverted~x
                            lda update_rect_max~height
                            sec
                            sbc <wHeight
                            sta update_rect_origin_wrap~y
                            negate a
                            sta update_rect_origin_wrap_inverted~y

                            lda <wWidth
                            sta update_rect_world~width
                            negate a
                            sta update_rect_world~width_inverted
                            lda <wHeight
                            sta update_rect_world~height
                            negate a
                            sta update_rect_world~height_inverted

                            restoredatabank
.skip_wrapping

                            ret
                            end

; -----------------------------------------------------------------------------
; Set the current "origin" of the view screen.
; This is the current view port if the screen scrolls around a larger
; coordinate system.
grlib_set_update_rect_origin start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'grlib_set_update_rect_origin'
                            sub (2:wX,2:wY),0

                            setlocaldatabank
                            ldx grlib~dp                                ; storing some values on the DP too
; Make an offset max rect for easy checking in add rect
                            lda <wX
                            sta update_rects_origin_x
                            sta update_rect_max_origin~left
                            lda update_rect_max~left
                            sec
                            sbc update_rects_origin_x
                            sta update_rect_to_screen_space_offset_x
                            sta >urdp~to_screen_space_offset_x,x        ; save on the grlib_dp

                            lda <wY
                            sta update_rects_origin_y
                            sta update_rect_max_origin~top
                            lda update_rect_max~top
                            sec
                            sbc update_rects_origin_y
                            sta update_rect_to_screen_space_offset_y
                            sta >urdp~to_screen_space_offset_y,x        ; save on the grlib_dp

;                           lda update_rect_max~bottom
;                           sec
;                           sbc update_rect_max~top
;                           sta update_rect_max_origin~height
                            lda update_rect_max~height
                            clc
                            adc update_rect_max_origin~top
                            sta update_rect_max_origin~bottom

;                           lda update_rect_max~right
;                           sec
;                           sbc update_rect_max~left
;                           sta update_rect_max_origin~width
                            lda update_rect_max~width
                            clc
                            adc update_rect_max_origin~left
                            sta update_rect_max_origin~right

                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
grlib_clear_update_rects    start seg_grlib
                            using grlib_update_rects_data

                            debugtag 'grlib_clear_update_rects'
                            sub (2:wGroup),0

                            setlocaldatabank
                            lda <wGroup
                            asl a
                            tax
                            stz update_rects_count,x

                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
grlib_get_update_rect       start seg_grlib
                            using grlib_update_rects_data

                            debugtag 'grlib_get_update_rect'
                            sub (2:wGroup,2:wIndex,4:pDest),0

                            setlocaldatabank
                            lda <wGroup
                            asl a
                            tax
                            lda <wIndex
                            cmp update_rects_count,x
                            bge range_error

                            asl a                                   ; x size of field
                            clc
                            adc update_rects_group_offset,x
                            tax
                            lda update_rects~left,x
                            putword [<pDest],#grlib_rect~left
                            lda update_rects~top,x
                            putword [<pDest],#grlib_rect~top
                            lda update_rects~right,x
                            putword [<pDest],#grlib_rect~right
                            lda update_rects~bottom,x
                            putword [<pDest],#grlib_rect~bottom
                            clc
exit                        restoredatabank
                            retkc
range_error                 lda #0
                            putword [<pDest],#grlib_rect~left
                            putword [<pDest],#grlib_rect~top
                            putword [<pDest],#grlib_rect~right
                            putword [<pDest],#grlib_rect~bottom
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Add a rect to the update list, rect must fall in update_rect_max_origin to get added,
; which is the view space bounds.
; Set update_rect_max_origin with grlib_set_max_update_rect and grlib_set_update_rect_origin.
;
; Parameters:
; wGroup        - group to add to
; wLeft         - left pixel location
; wTop          - top pixel location
; wRight        - right pixel location, exclusive
; wBottom       - bottom pixel location, exclusive
;
; Returns:
; carry clear, the rect was added
; carry set, the rect was completely clipped
grlib_add_rect_to_update    start seg_grlib
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'add_rect_to_update'

                            begin_locals
least_x                     decl word
least_y                     decl word
is_half_x                   decl word
is_half_y                   decl word
width                       decl word
half_width                  decl word
height                      decl word
half_height                 decl word
count                       decl word
work_area_size              end_locals

                            sub (2:wGroup,2:wLeft,2:wTop,2:wRight,2:wBottom),work_area_size

                            setlocaldatabank

                            lda update_rect_max_origin~right
                            cmp <wLeft
                            bslt clipped
                            lda <wRight
                            cmp update_rect_max_origin~left
                            bslt clipped
                            lda update_rect_max_origin~bottom
                            cmp <wTop
                            bslt clipped
                            lda <wBottom
                            cmp update_rect_max_origin~top
                            bsge not_clipped

clipped                     sec
                            brl exit

not_clipped                 anop
; Offset the rect, to translate it to screen-space.  Possible optimization of patching the adds, when the update_rect_to_screen_space_offset is calculated
                            lda <wTop
                            clc
                            adc update_rect_to_screen_space_offset_y
                            sta <wTop

                            lda <wBottom
                            clc
                            adc update_rect_to_screen_space_offset_y
                            sta <wBottom

                            lda <wLeft
                            clc
                            adc update_rect_to_screen_space_offset_x
                            sta <wLeft

                            lda <wRight
                            clc
                            adc update_rect_to_screen_space_offset_x
                            sta <wRight

; Clip to max screen rect.  Possible optimization of patching in the loads of the update_rect_max, when it is setup.

                            lda update_rect_max~top
                            cmp <wTop
                            bslt ok_top
                            sta <wTop

ok_top                      lda update_rect_max~bottom
                            cmp <wBottom
                            bsge ok_bottom
                            sta <wBottom

ok_bottom                   lda update_rect_max~left
                            cmp <wLeft
                            bslt ok_left
                            sta <wLeft

ok_left                     lda update_rect_max~right
                            cmp <wRight
                            bsge ok_right
                            sta <wRight

ok_right                    anop

                            lda <wRight
                            sec
                            sbc <wLeft
                            sta <width
                            beq clipped                             ; go to zero or inverted?
                            bmi clipped

                            lsr a
                            sta <half_width

                            lda <wBottom
                            sec
                            sbc <wTop
                            sta <height
                            beq clipped
                            bmi clipped

                            lsr a
                            sta <half_height

                            lda <wGroup
                            asl a
                            sta <wGroup
                            tax
                            lda update_rects_count,x
                            bne has_rects
; First rect
first_rect                  anop
                            ldx <wGroup
                            lda #1
                            sta update_rects_count,x
; Get the offset to the first rect in the group
                            lda update_rects_group_offset,x
                            tax
; Set it
                            lda <wLeft
                            sta update_rects~left,x
                            lda <wTop
                            sta update_rects~top,x
                            lda <wRight
                            sta update_rects~right,x
                            lda <wBottom
                            sta update_rects~bottom,x
                            lda <width
                            sta update_rects~width,x
                            lda <height
                            sta update_rects~height,x
                            lda <half_width
                            sta update_rects~half_width,x
                            lda <half_height
                            sta update_rects~half_height,x

                            clc
                            brl exit

has_rects                   anop
                            sta <count

; See if the rect overlaps any of the other rects more than
; 50%, if so, make a union of it and re-add it to the list

                            ldx <wGroup
                            lda update_rects_group_offset,x
                            tax

loop                        lda update_rects~right,x
                            cmp <wLeft
                            bslt no_overlap
                            lda <wRight
                            cmp update_rects~left,x
                            bslt no_overlap
                            lda update_rects~bottom,x
                            cmp <wTop
                            bslt no_overlap
                            lda <wBottom
                            cmp update_rects~top,x
                            bsge has_overlap

no_overlap                  anop
                            inx
                            inx
                            dec <count
                            bne loop
; Add a new rect
                            brl add_new

has_overlap                 anop
                            stz <is_half_x
                            stz <is_half_y

; Figure out which x is greater

                            lda <wLeft
                            cmp update_rects~left,x
                            bslt x_less

* x1 >= x2, so if x1 - x2 > w2 then they don't overlap!

                            ldy update_rects~left,x
                            sty <least_x
                            sec
                            sbc <least_x
;                            cmp update_rects~width,x
;                            bge hitch           ;no_overlap

* Does it overlap a lot?

                            cmp update_rects~half_width,x
                            bsge check_y         ;the overlap is less than half
                            dec <is_half_x       ;set flag
                            bra check_y
*--------------------------

* x2 >= x1, so if x2 - x1 > w1 then they don't overlap

x_less                      sta <least_x
                            lda update_rects~left,x
                            sec
                            sbc <wLeft
;                            cmp <width
;                            bge hitch           ;no_overlap

                            cmp <half_width
                            bsge check_y
                            dec <is_half_x

* ----------------------------------------------------------

* figure out which y is greater

check_y                     lda <wTop
                            cmp update_rects~top,x
                            bslt y_less
                            ldy update_rects~top,x
                            sty <least_y
* y1 >= y2, so if y1 - y2 > h2 then they don't overlap!
                            sec
                            sbc <least_y
;                            cmp update_rects~height,x
;                            bge hitch           ;no_overlap

* Does it overlap a lot?

                            cmp update_rects~half_height,x
                            bsge done_check      ;the overlap is less than half
                            dec <is_half_y      ;set flag
                            bra done_check
*--------------------------

* y2 >= y1, so if y2 - y1 > h1 then they don't overlap

y_less                      sta <least_y
                            lda update_rects~top,x
                            sec
                            sbc <wTop
;                            cmp <height
;hitch                       bge no_overlap

                            cmp <half_height
                            bsge done_check
                            dec <is_half_y
*--------------------------
*
done_check                  lda <is_half_x
                            and <is_half_y
                            bpl no_overlap

; Make a new, merged rectangle and re-add

                            lda <least_x
                            sta <wLeft                                  ; new left

; Find the larger right edge
                            lda <wRight
                            cmp update_rects~right,x
                            bsge larger_right
                            lda update_rects~right,x
                            sta <wRight                                 ; new right
larger_right                sec
                            sbc <least_x
                            sta <width                                  ; new width
                            lsr a
                            sta <half_width                             ; new half-width

                            lda <least_y
                            sta <wTop                                   ; new top

; Find the larger bottom edge
                            lda <wBottom
                            cmp update_rects~bottom,x
                            bsge larger_bottom
                            lda update_rects~bottom,x
                            sta <wBottom                                ; new bottom
larger_bottom               sec
                            sbc <least_y
                            sta <height                                 ; new height
                            lsr a
                            sta <half_height

; Move the last rect into the current spot
                            ldy <wGroup
                            lda update_rects_count,y
                            cmp #1
                            jeq first_rect                              ; Only one in there, so just store what we have and exit

                            dec a
                            pha
; Get Y to point to the last entry
                            asl a                                   ; x size of field
                            clc
                            adc update_rects_group_offset,y
                            tay
                            lda update_rects~left,y
                            sta update_rects~left,x
                            lda update_rects~top,y
                            sta update_rects~top,x
                            lda update_rects~right,y
                            sta update_rects~right,x
                            lda update_rects~bottom,y
                            sta update_rects~bottom,x
                            lda update_rects~width,y
                            sta update_rects~width,x
                            lda update_rects~height,y
                            sta update_rects~height,x
                            lda update_rects~half_width,y
                            sta update_rects~half_width,x
                            lda update_rects~half_height,y
                            sta update_rects~half_height,x
                            pla
                            ldx <wGroup
                            sta update_rects_count,x
                            brl has_rects

exit                        restoredatabank
                            retkc

add_new                     anop
                            ldx <wGroup
                            lda update_rects_count,x
                            cmp #max_update_rect_count
                            beq add_max
; Get x to have the offset to the last one
                            asl a                                   ; x size of field
                            clc
                            adc update_rects_group_offset,x
                            tax
                            lda <wLeft
                            sta update_rects~left,x
                            lda <wTop
                            sta update_rects~top,x
                            lda <wRight
                            sta update_rects~right,x
                            lda <wBottom
                            sta update_rects~bottom,x
                            lda <width
                            sta update_rects~width,x
                            lda <height
                            sta update_rects~height,x
                            lda <half_width
                            sta update_rects~half_width,x
                            lda <half_height
                            sta update_rects~half_height,x
                            ldx <wGroup
                            inc update_rects_count,x
                            clc
                            brl exit

add_max                     anop
                            ldx <wGroup
                            lda #1
                            sta update_rects_count,x
                            lda update_rects_group_offset,x
                            tax
                            lda update_rect_max~left
                            sta update_rects~left,x
                            lda update_rect_max~top
                            sta update_rects~top,x
                            lda update_rect_max~right
                            sta update_rects~right,x
                            lda update_rect_max~bottom
                            sta update_rects~bottom,x
                            lda update_rect_max~width
                            sta update_rects~width,x
                            lda update_rect_max~height
                            sta update_rects~height,x
                            lda update_rect_max~half_width
                            sta update_rects~half_width,x
                            lda update_rect_max~half_height
                            sta update_rects~half_height,x
                            clc
                            brl exit

                            end

; -----------------------------------------------------------------------------
; Add a rect to the update list, rect must fall in update_rect_max to get added,
; which is the screen space bounds.
;
; Parameters:
; wGroup        - group to add to
; wLeft         - left pixel location
; wTop          - top pixel location
; wRight        - right pixel location, exclusive
; wBottom       - bottom pixel location, exclusive
grlib_add_screen_space_rect_to_update start seg_grlib
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'add_screen_space_rect'

                            begin_locals
least_x                     decl word
least_y                     decl word
is_half_x                   decl word
is_half_y                   decl word
width                       decl word
half_width                  decl word
height                      decl word
half_height                 decl word
count                       decl word
work_area_size              end_locals

                            sub (2:wGroup,2:wLeft,2:wTop,2:wRight,2:wBottom),work_area_size

                            setlocaldatabank

; Clip to max screen rect.  Possible optimization of patching in the loads of the update_rect_max, when it is setup.

                            lda update_rect_max~top
                            cmp <wTop
                            bslt ok_top
                            sta <wTop

ok_top                      lda update_rect_max~bottom
                            cmp <wBottom
                            bsge ok_bottom
                            sta <wBottom

ok_bottom                   lda update_rect_max~left
                            cmp <wLeft
                            bslt ok_left
                            sta <wLeft

ok_left                     lda update_rect_max~right
                            cmp <wRight
                            bsge ok_right
                            sta <wRight

ok_right                    anop
                            lda <wRight
                            sec
                            sbc <wLeft
                            sta <width
                            beq clipped                             ; go to zero or inverted?
                            bmi clipped

                            lsr a
                            sta <half_width

                            lda <wBottom
                            sec
                            sbc <wTop
                            sta <height
                            beq clipped
                            bmi clipped

                            lsr a
                            sta <half_height

                            lda <wGroup
                            asl a
                            sta <wGroup
                            tax
                            lda update_rects_count,x
                            bne has_rects
; First rect
first_rect                  anop
                            ldx <wGroup
                            lda #1
                            sta update_rects_count,x
; Get the offset to the first rect in the group
                            lda update_rects_group_offset,x
                            tax
; Set it
                            lda <wLeft
                            sta update_rects~left,x
                            lda <wTop
                            sta update_rects~top,x
                            lda <wRight
                            sta update_rects~right,x
                            lda <wBottom
                            sta update_rects~bottom,x
                            lda <width
                            sta update_rects~width,x
                            lda <height
                            sta update_rects~height,x
                            lda <half_width
                            sta update_rects~half_width,x
                            lda <half_height
                            sta update_rects~half_height,x

clipped                     restoredatabank
                            ret

has_rects                   anop
                            sta <count

; See if the rect overlaps any of the other rects more than
; 50%, if so, make a union of it and re-add it to the list

                            ldx <wGroup
                            lda update_rects_group_offset,x
                            tax

loop                        lda update_rects~right,x
                            cmp <wLeft
                            bslt no_overlap
                            lda <wRight
                            cmp update_rects~left,x
                            bslt no_overlap
                            lda update_rects~bottom,x
                            cmp <wTop
                            bslt no_overlap
                            lda <wBottom
                            cmp update_rects~top,x
                            bsge has_overlap

no_overlap                  anop
                            inx
                            inx
                            dec <count
                            bne loop
; Add a new rect
                            brl add_new

has_overlap                 anop
                            stz <is_half_x
                            stz <is_half_y

; Figure out which x is greater

                            lda <wLeft
                            cmp update_rects~left,x
                            bslt x_less

* x1 >= x2, so if x1 - x2 > w2 then they don't overlap!

                            ldy update_rects~left,x
                            sty <least_x
                            sec
                            sbc <least_x
;                            cmp update_rects~width,x
;                            bge hitch           ;no_overlap

* Does it overlap a lot?

                            cmp update_rects~half_width,x
                            bsge check_y         ;the overlap is less than half
                            dec <is_half_x       ;set flag
                            bra check_y
*--------------------------

* x2 >= x1, so if x2 - x1 > w1 then they don't overlap

x_less                      sta <least_x
                            lda update_rects~left,x
                            sec
                            sbc <wLeft
;                            cmp <width
;                            bge hitch           ;no_overlap

                            cmp <half_width
                            bsge check_y
                            dec <is_half_x

* ----------------------------------------------------------

* figure out which y is greater

check_y                     lda <wTop
                            cmp update_rects~top,x
                            bslt y_less
                            ldy update_rects~top,x
                            sty <least_y
* y1 >= y2, so if y1 - y2 > h2 then they don't overlap!
                            sec
                            sbc <least_y
;                            cmp update_rects~height,x
;                            bge hitch           ;no_overlap

* Does it overlap a lot?

                            cmp update_rects~half_height,x
                            bsge done_check      ;the overlap is less than half
                            dec <is_half_y      ;set flag
                            bra done_check
*--------------------------

* y2 >= y1, so if y2 - y1 > h1 then they don't overlap

y_less                      sta <least_y
                            lda update_rects~top,x
                            sec
                            sbc <wTop
;                            cmp <height
;hitch                       bge no_overlap

                            cmp <half_height
                            bsge done_check
                            dec <is_half_y
*--------------------------
*
done_check                  lda <is_half_x
                            and <is_half_y
                            bpl no_overlap

; Make a new, merged rectangle and re-add

                            lda <least_x
                            sta <wLeft                                  ; new left

; Find the larger right edge
                            lda <wRight
                            cmp update_rects~right,x
                            bsge larger_right
                            lda update_rects~right,x
                            sta <wRight                                 ; new right
larger_right                sec
                            sbc <least_x
                            sta <width                                  ; new width
                            lsr a
                            sta <half_width                             ; new half-width

                            lda <least_y
                            sta <wTop                                   ; new top

; Find the larger bottom edge
                            lda <wBottom
                            cmp update_rects~bottom,x
                            bsge larger_bottom
                            lda update_rects~bottom,x
                            sta <wBottom                                ; new bottom
larger_bottom               sec
                            sbc <least_y
                            sta <height                                 ; new height
                            lsr a
                            sta <half_height

; Move the last rect into the current spot
                            ldy <wGroup
                            lda update_rects_count,y
                            cmp #1
                            jeq first_rect                              ; Only one in there, so just store what we have and exit

                            dec a
                            pha
; Get Y to point to the last entry
                            asl a                                   ; x size of field
                            clc
                            adc update_rects_group_offset,y
                            tay
                            lda update_rects~left,y
                            sta update_rects~left,x
                            lda update_rects~top,y
                            sta update_rects~top,x
                            lda update_rects~right,y
                            sta update_rects~right,x
                            lda update_rects~bottom,y
                            sta update_rects~bottom,x
                            lda update_rects~width,y
                            sta update_rects~width,x
                            lda update_rects~height,y
                            sta update_rects~height,x
                            lda update_rects~half_width,y
                            sta update_rects~half_width,x
                            lda update_rects~half_height,y
                            sta update_rects~half_height,x
                            pla
                            ldx <wGroup
                            sta update_rects_count,x
                            brl has_rects

exit                        restoredatabank
                            ret

add_new                     anop
                            ldx <wGroup
                            lda update_rects_count,x
                            cmp #max_update_rect_count
                            beq add_max
; Get x to have the offset to the last one
                            asl a                                   ; x size of field
                            clc
                            adc update_rects_group_offset,x
                            tax
                            lda <wLeft
                            sta update_rects~left,x
                            lda <wTop
                            sta update_rects~top,x
                            lda <wRight
                            sta update_rects~right,x
                            lda <wBottom
                            sta update_rects~bottom,x
                            lda <width
                            sta update_rects~width,x
                            lda <height
                            sta update_rects~height,x
                            lda <half_width
                            sta update_rects~half_width,x
                            lda <half_height
                            sta update_rects~half_height,x
                            ldx <wGroup
                            inc update_rects_count,x
                            brl exit

add_max                     anop
                            ldx <wGroup
                            lda #1
                            sta update_rects_count,x
                            lda update_rects_group_offset,x
                            tax
                            lda update_rect_max~left
                            sta update_rects~left,x
                            lda update_rect_max~top
                            sta update_rects~top,x
                            lda update_rect_max~right
                            sta update_rects~right,x
                            lda update_rect_max~bottom
                            sta update_rects~bottom,x
                            lda update_rect_max~width
                            sta update_rects~width,x
                            lda update_rect_max~height
                            sta update_rects~height,x
                            lda update_rect_max~half_width
                            sta update_rects~half_width,x
                            lda update_rect_max~half_height
                            sta update_rects~half_height,x
                            brl exit

                            end

; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Add a rect to the update list, rect must fall in update_rect_max_origin to get added,
; which is the view space bounds.
; Set update_rect_max_origin with grlib_set_max_update_rect and grlib_set_update_rect_origin.
;
; This version always merges overlapping rects, not matter the amount of overlap.
;
; Parameters:
; wGroup        - group to add to
; wLeft         - left pixel location
; wTop          - top pixel location
; wRight        - right pixel location, exclusive
; wBottom       - bottom pixel location, exclusive
;
; Returns:
; carry clear, the rect was added
; carry set, the rect was completely clipped
grlib_add_rect_to_update_always_merge start seg_grlib
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'add_rect_to_update'

                            begin_locals
least_x                     decl word
least_y                     decl word
is_half_x                   decl word
is_half_y                   decl word
width                       decl word
half_width                  decl word
height                      decl word
half_height                 decl word
count                       decl word
wTemp                       decl word
work_area_size              end_locals

                            sub (2:wGroup,2:wLeft,2:wTop,2:wRight,2:wBottom),work_area_size

                            setlocaldatabank

; Offset the rect, to translate it to screen-space.  Possible optimization of patching the adds, when the update_rect_to_screen_space_offset is calculated

                            aif grlib~support_coordinate_wrapping=0,.skip_wrapping
; The version that supports wrapping
                            lda <wTop
                            sta <wTemp
                            clc
                            adc update_rect_to_screen_space_offset_y
                            cmp update_rect_origin_wrap~y
                            bsge no_wrap_top
                            clc
                            adc update_rect_world~height
                            sta <wTop
; We have to wrap the whole rect.
                            lda <wBottom
                            clc
                            adc update_rect_to_screen_space_offset_y
                            clc
                            adc update_rect_world~height
                            sta <wBottom
                            bra wrapped_top

no_wrap_top                 sta <wTop

                            lda <wBottom
                            clc
                            adc update_rect_to_screen_space_offset_y
                            cmp update_rect_origin_wrap~y
                            bsge no_wrap_bottom
                            clc
                            adc update_rect_world~height
no_wrap_bottom              sta <wBottom

wrapped_top                 anop
                            lda <wLeft
                            clc
                            adc update_rect_to_screen_space_offset_x
                            cmp update_rect_origin_wrap~x
                            bsge no_wrap_left
                            clc
                            adc update_rect_world~width
                            sta <wLeft
                            lda <wRight
                            clc
                            adc update_rect_to_screen_space_offset_x
                            clc
                            adc update_rect_world~width
                            sta <wRight
                            bra wrapped_left

no_wrap_left                sta <wLeft

                            lda <wRight
                            clc
                            adc update_rect_to_screen_space_offset_x
                            cmp update_rect_origin_wrap~x
                            bsge no_wrap_right
                            clc
                            adc update_rect_world~width
no_wrap_right               sta <wRight

wrapped_left                anop
.skip_wrapping
                            aif grlib~support_coordinate_wrapping<>0,.skip_no_wrapping
; This version does not support wrapping
                            lda <wTop
                            clc
                            adc update_rect_to_screen_space_offset_y
                            sta <wTop

                            lda <wBottom
                            clc
                            adc update_rect_to_screen_space_offset_y
                            sta <wBottom

                            lda <wLeft
                            clc
                            adc update_rect_to_screen_space_offset_x
                            sta <wLeft

                            lda <wRight
                            clc
                            adc update_rect_to_screen_space_offset_x
                            sta <wRight
.skip_no_wrapping

; Clip to max screen rect.  Possible optimization of patching in the loads of the update_rect_max, when it is setup.

                            lda update_rect_max~top
                            cmp <wTop
                            bslt ok_top
                            sta <wTop

ok_top                      lda update_rect_max~bottom
                            cmp <wBottom
                            bsge ok_bottom
                            sta <wBottom

ok_bottom                   lda update_rect_max~left
                            cmp <wLeft
                            bslt ok_left
                            sta <wLeft

ok_left                     lda update_rect_max~right
                            cmp <wRight
                            bsge ok_right
                            sta <wRight

ok_right                    anop

                            lda <wRight
                            sec
                            sbc <wLeft
                            sta <width
                            beq clipped                             ; go to zero or inverted?
                            bmi clipped

                            lsr a
                            sta <half_width

                            lda <wBottom
                            sec
                            sbc <wTop
                            sta <height
                            beq clipped
                            bmi clipped

                            lsr a
                            sta <half_height

                            lda <wGroup
                            asl a
                            sta <wGroup
                            tax
                            lda update_rects_count,x
                            bne has_rects
; First rect
first_rect                  anop
                            ldx <wGroup
                            lda #1
                            sta update_rects_count,x
; Get the offset to the first rect in the group
                            lda update_rects_group_offset,x
                            tax
; Set it
                            lda <wLeft
                            sta update_rects~left,x
                            lda <wTop
                            sta update_rects~top,x
                            lda <wRight
                            sta update_rects~right,x
                            lda <wBottom
                            bpl ok_bottom_first
                            brk $07
ok_bottom_first             anop
                            sta update_rects~bottom,x
                            lda <width
                            sta update_rects~width,x
                            lda <height
                            sta update_rects~height,x
                            lda <half_width
                            sta update_rects~half_width,x
                            lda <half_height
                            sta update_rects~half_height,x

                            clc
                            brl exit
clipped                     sec
                            brl exit

has_rects                   anop
                            sta <count

; See if the rect overlaps any of the other rects.
; If so, make a union of it and re-add it to the list

                            ldx <wGroup
                            lda update_rects_group_offset,x
                            tax

loop                        lda update_rects~right,x
                            cmp <wLeft
                            bslt no_overlap
                            lda <wRight
                            cmp update_rects~left,x
                            bslt no_overlap
                            lda update_rects~bottom,x
                            cmp <wTop
                            bslt no_overlap
                            lda <wBottom
                            cmp update_rects~top,x
                            bsge has_overlap

no_overlap                  anop
                            inx
                            inx
                            dec <count
                            bne loop
; Add a new rect
                            brl add_new

has_overlap                 anop
; Figure out which x is least

                            lda <wLeft
                            cmp update_rects~left,x
                            bslt x_less
                            lda update_rects~left,x
x_less                      sta <least_x

* figure out which y is greater

                            lda <wTop
                            cmp update_rects~top,x
                            bslt y_less
                            lda update_rects~top,x
y_less                      sta <least_y

; Make a new, merged rectangle and re-add

                            lda <least_x
                            sta <wLeft                                  ; new left

; Find the larger right edge
                            lda <wRight
                            cmp update_rects~right,x
                            bsge larger_right
                            lda update_rects~right,x
                            sta <wRight                                 ; new right
larger_right                sec
                            sbc <least_x
                            sta <width                                  ; new width
                            lsr a
                            sta <half_width                             ; new half-width

                            lda <least_y
                            sta <wTop                                   ; new top

; Find the larger bottom edge
                            lda <wBottom
                            cmp update_rects~bottom,x
                            bsge larger_bottom
                            lda update_rects~bottom,x
                            sta <wBottom                                ; new bottom
larger_bottom               sec
                            sbc <least_y
                            sta <height                                 ; new height
                            lsr a
                            sta <half_height

; Move the last rect into the current spot
                            ldy <wGroup
                            lda update_rects_count,y
                            cmp #1
                            jeq first_rect                              ; Only one in there, so just store what we have and exit

                            dec a
                            pha
; Get Y to point to the last entry
                            asl a                                   ; x size of field
                            clc
                            adc update_rects_group_offset,y
                            tay
                            lda update_rects~left,y
                            sta update_rects~left,x
                            lda update_rects~top,y
                            sta update_rects~top,x
                            lda update_rects~right,y
                            sta update_rects~right,x
                            lda update_rects~bottom,y
                            sta update_rects~bottom,x
                            lda update_rects~width,y
                            sta update_rects~width,x
                            lda update_rects~height,y
                            sta update_rects~height,x
                            lda update_rects~half_width,y
                            sta update_rects~half_width,x
                            lda update_rects~half_height,y
                            sta update_rects~half_height,x
                            pla
                            ldx <wGroup
                            sta update_rects_count,x
                            brl has_rects

exit                        restoredatabank
                            retkc

add_new                     anop
                            ldx <wGroup
                            lda update_rects_count,x
                            cmp #max_update_rect_count
                            beq add_max
; Get x to have the offset to the last one
                            asl a                                   ; x size of field
                            clc
                            adc update_rects_group_offset,x
                            tax
                            lda <wLeft
                            sta update_rects~left,x
                            lda <wTop
                            sta update_rects~top,x
                            lda <wRight
                            sta update_rects~right,x
                            lda <wBottom
                            sta update_rects~bottom,x
                            lda <width
                            sta update_rects~width,x
                            lda <height
                            sta update_rects~height,x
                            lda <half_width
                            sta update_rects~half_width,x
                            lda <half_height
                            sta update_rects~half_height,x
                            ldx <wGroup
                            inc update_rects_count,x
                            clc
                            brl exit

add_max                     anop
                            ldx <wGroup
                            lda #1
                            sta update_rects_count,x
                            lda update_rects_group_offset,x
                            tax
                            lda update_rect_max~left
                            sta update_rects~left,x
                            lda update_rect_max~top
                            sta update_rects~top,x
                            lda update_rect_max~right
                            sta update_rects~right,x
                            lda update_rect_max~bottom
                            sta update_rects~bottom,x
                            lda update_rect_max~width
                            sta update_rects~width,x
                            lda update_rect_max~height
                            sta update_rects~height,x
                            lda update_rect_max~half_width
                            sta update_rects~half_width,x
                            lda update_rect_max~half_height
                            sta update_rects~half_height,x
                            clc
                            brl exit

                            end

; -----------------------------------------------------------------------------
; Add a rect to the update list, rect must fall in update_rect_max to get added,
; which is the screen space bounds.
;
; This version always merges rects, if there is any overlap.
; This also skips any calculation and storing of the rect's width/height

; Parameters are passed directly into the grdp space this function uses
; urdp~group    - group to add to (x 2)
; urdp~left     - left pixel location
; urdp~top      - top pixel location
; urdp~right    - right pixel location, exclusive
; urdp~bottom   - bottom pixel location, exclusive
;
; This function also assumes the DP is already set to grlib~dp
grlib_add_screen_space_rect_to_update_always_merge start seg_grlib
                            using grlib_global_data
                            using grlib_global_equates
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'add_clipped_screen_space_rect'

                            setlocaldatabank

;                           phd
;                           lda >grlib~dp
;                           tcd

; Clip to max screen rect.  Possible optimization of patching in the loads of the update_rect_max, when it is setup.

; Even though the input rect is in screen-space, we still assume that it is not clipped to screen space yet
; so we will check that and we must do signed comparisons
                            lda <urdp~max~top
                            cmp <urdp~top
                            bslt ok_top
                            sta <urdp~top

ok_top                      lda <urdp~max~bottom
                            cmp <urdp~bottom
                            bsge ok_bottom
                            sta <urdp~bottom

ok_bottom                   lda <urdp~max~left
                            cmp <urdp~left
                            bslt ok_left
                            sta <urdp~left

ok_left                     lda <urdp~max~right
                            cmp <urdp~right
                            bsge ok_right
                            sta <urdp~right

ok_right                    anop
; Once we are clipped, we can assume that the values are unsigned.
                            lda <urdp~left
                            cmp <urdp~right
                            bge clipped                             ; go to zero or inverted?

                            lda <urdp~top
                            cmp <urdp~bottom
                            bge clipped

                            ldx <urdp~group
                            lda update_rects_count,x
                            bne has_rects
; First rect
first_rect                  anop
                            lda #1
                            sta update_rects_count,x
; Get the offset to the first rect in the group
                            lda update_rects_group_offset,x
                            tax
; Set it
                            lda <urdp~left
                            sta update_rects~left,x
                            lda <urdp~top
                            sta update_rects~top,x
                            lda <urdp~right
                            sta update_rects~right,x
                            lda <urdp~bottom
                            sta update_rects~bottom,x
exit                        clc
;                           pld
                            restoredatabank
                            rtl

clipped                     sec
;                           pld
                            restoredatabank
                            rtl

hitch_to_add_new            jmp add_new

has_rects                   anop
                            tay                             ; y will be the rect counter

; See if the rect overlaps any of the other rects.
; if so, make a union of it and re-add it to the list.
; This loop is done a lot, so trying to optimize for the case where all rects are checked

                            lda update_rects_group_offset,x
                            sta <urdp~group_offset
                            tax
                            bra start_check

no_overlap                  dey
                            beq hitch_to_add_new

                            inx                             ; + field size
                            inx

start_check                 lda update_rects~right,x
                            cmp <urdp~left
                            bslt no_overlap
                            lda <urdp~right
                            cmp update_rects~left,x
                            bslt no_overlap
                            lda update_rects~bottom,x
                            cmp <urdp~top
                            bslt no_overlap
                            lda <urdp~bottom
                            cmp update_rects~top,x
                            bslt no_overlap

; Make a new, merged rectangle and re-add

; Find the larger bottom edge
;                           lda <urdp~bottom                                ; we know this was the last thing in A, so don't need to load it
                            cmp update_rects~bottom,x
                            bsge larger_bottom
                            lda update_rects~bottom,x
                            sta <urdp~bottom                                ; new bottom
larger_bottom               anop

; Figure out which x is greater

                            lda <urdp~left
                            cmp update_rects~left,x
                            bslt x_less
                            lda update_rects~left,x
                            sta <urdp~left                                  ; new left
x_less                      anop

                            lda <urdp~top
                            cmp update_rects~top,x
                            bslt y_less
                            lda update_rects~top,x
                            sta <urdp~top                                   ; new top
y_less                      anop

; Find the larger right edge
                            lda <urdp~right
                            cmp update_rects~right,x
                            bsge larger_right
                            lda update_rects~right,x
                            sta <urdp~right                                 ; new right
larger_right                anop


; Move the last rect into the current spot, to erase the rect that is now merged.
                            ldy <urdp~group
                            lda update_rects_count,y
                            cmp #1
                            bne not_first_rect
                            tyx
                            jmp first_rect                                  ; Only one in there, so just store what we have, and exit

not_first_rect              dec a
                            sta update_rects_count,y
                            pha
; Get Y to point to the last entry
                            asl a                                           ; x field size
                            clc
                            adc <urdp~group_offset
                            tay
                            lda update_rects~left,y
                            sta update_rects~left,x
                            lda update_rects~top,y
                            sta update_rects~top,x
                            lda update_rects~right,y
                            sta update_rects~right,x
                            lda update_rects~bottom,y
                            sta update_rects~bottom,x
; Start over adding the newly merged rect
                            ply                                             ; get the count into y
                            ldx <urdp~group_offset                          ; get the offset to the first rect
                            jmp start_check                                 ; start again

add_new                     anop
                            ldx <urdp~group
                            lda update_rects_count,x
                            cmp #max_update_rect_count
                            beq add_max
                            inc update_rects_count,x
; Get x to have the offset to the last one
                            asl a                                           ; x field size
                            clc
                            adc <urdp~group_offset
                            tax
                            lda <urdp~left
                            sta update_rects~left,x
                            lda <urdp~top
                            sta update_rects~top,x
                            lda <urdp~right
                            sta update_rects~right,x
                            lda <urdp~bottom
                            sta update_rects~bottom,x
; exit
                            clc
;                           pld
                            restoredatabank
                            rtl

add_max                     anop
                            ldx <urdp~group
                            lda #1
                            sta update_rects_count,x
                            lda update_rects_group_offset,x
                            tax
                            lda update_rect_max~left
                            sta update_rects~left,x
                            lda update_rect_max~top
                            sta update_rects~top,x
                            lda update_rect_max~right
                            sta update_rects~right,x
                            lda update_rect_max~bottom
                            sta update_rects~bottom,x
; exit
                            clc
;                           pld
                            restoredatabank
                            rtl

                            end

; -----------------------------------------------------------------------------
; Do some debug operations, before updating the screen.
; This should be called when all the erase/drawing has been done, but the screen has
; not been updated.
; Parameters:
; wOptions - bit 0, off = skip, on = test other bits
;            bit 1, off = pause for a few frames, then continue, on = wait for keypress
; Returns:
; carry set, if the user pressed ESC during a wait.
grlib_update_rects_pre_update start seg_grlib
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'pre_update'
                            debugtag 'grlib_update_rects'

                            begin_locals
wCount                      decl word
wColor                      decl word
wHitESC                     decl word
wX                          decl word
wY                          decl word
wWidth                      decl word
wHeight                     decl word
work_area_size              end_locals

                            sub (2:wOptions),work_area_size
                            clc
                            lda <wOptions
                            beq exit

                            setlocaldatabank

                            stz <wHitESC
; Debug, show the erase/update rects
                            lda #$FFFF
                            sta <wColor
                            lda #urlib_group~erase
                            jsr draw_rects
                            bcc next
                            inc <wHitESC
next                        lda #$DDDD
                            sta <wColor
                            lda #urlib_group~update
                            jsr draw_rects
                            bcc next2
                            inc <wHitESC
next2                       anop
                            restoredatabank
                            clc
                            lda <wHitESC
                            beq exit
                            sec
exit                        retkc

; - Local ---------------------------------------------------------------------
draw_rects                  asl a
                            tax
                            lda update_rects_count,x
                            clc
                            sta <wCount
                            beq no_rects

                            lda update_rects_group_offset,x
                            tax

rect_loop                   phx
                            lda update_rects~left,x
                            cmp #320
                            blt ok_x
                            brk $01
ok_x                        pha
                            sta <wX
                            lda update_rects~top,x
                            cmp #200
                            blt ok_y
                            brk $02
ok_y                        pha
                            sta <wY
                            lda update_rects~right,x
                            sec
                            sbc <wX                 ; update_rects~left,x
                            beq bad_width
                            bcs ok_width
bad_width                   brk $03
ok_width                    pha
                            clc
                            adc <wX
                            cmp #321
                            blt ok_right
                            brk $04

ok_right                    lda update_rects~bottom,x
                            sec
                            sbc <wY                 ; update_rects~top,x
                            beq bad_height
                            bcs ok_height
bad_height                  brk $05
ok_height                   pha
                            clc
                            adc <wY
                            cmp #201
                            blt ok_bottom
                            brk $06
ok_bottom                   anop
                            pushsword <wColor
                            pushsword #0
                            jsl grlib_draw_debug_rect
                            plx
                            inx                     ; + field size
                            inx
                            dec <wCount
                            bne rect_loop

                            lda <wOptions
                            jsl grlib_debug_pause
no_rects                    rts
                            end

; -----------------------------------------------------------------------------
; This is called at the end of the frame
grlib_update_rects_frame_end start seg_grlib
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'frame_end'
                            debugtag 'grlib_update_rects'

                            setlocaldatabank
; Clear the update rects
                            ldx #urlib_group~erase*2
                            stz update_rects_count,x
                            ldx #urlib_group~update*2
                            stz update_rects_count,x

                            stz update_rects_queued~erase_insert_offset
                            stz update_rects_queued~update_insert_offset

                            debug_stats_jsr _debug_show_draw_info

                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Explicitly clear all the update rects
grlib_update_rects_clear    start seg_grlib
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            debugtag 'rects_clear'
                            debugtag 'grlib_update'

                            setlocaldatabank
; Clear the update rects
                            ldx #urlib_group~erase*2
                            stz update_rects_count,x
                            ldx #urlib_group~update*2
                            stz update_rects_count,x

                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Do some debug operations, before updating the screen.
; This should be called when all the erase/drawing has been done, but the screen has
; not been updated.
; Parameters:
; wOptions - bit 0, off = skip, on = test other bits
;            bit 1, off = pause for a few frames, then continue, on = wait for keypress
; Returns:
; carry set, if the user pressed ESC during a wait.
grlib_queued_update_rects_pre_update start seg_grlib
                            using grlib_update_rects_data
                            using grlib_update_rects_data2
                            using grlib_global_data
                            using grlib_global_equates

                            debugtag 'pre_update'
                            debugtag 'grlib_update_rects'

                            begin_locals
wCount                      decl word
wColor                      decl word
wHitESC                     decl word
wX                          decl word
wY                          decl word
wWidth                      decl word
wHeight                     decl word
wClipLeft                   decl word
wClipRight                  decl word
wClipTop                    decl word
wClipBottom                 decl word
work_area_size              end_locals

                            sub (2:wOptions),work_area_size
                            clc
                            lda <wOptions
                            beq exit

                            setlocaldatabank

; Get the clip rect.  Not exactly fast, but this is a debug function
                            lda >grlib~dp
                            tax
                            lda >clipx_left,x
                            sta <wClipLeft
                            lda >clipx_right,x
                            sta <wClipRight
                            lda >clipy_top,x
                            sta <wClipTop
                            lda >clipy_bottom,x
                            sta <wClipBottom

                            stz <wHitESC
; Debug, show the erase/update rects
                            lda #$FFFF
                            sta <wColor
                            lda #urlib_group~erase
                            jsr draw_rects
                            bcc next
                            inc <wHitESC
next                        lda #$DDDD
                            sta <wColor
                            lda #urlib_group~update
                            jsr draw_rects
                            bcc next2
                            inc <wHitESC
next2                       anop
                            restoredatabank
                            clc
                            lda <wHitESC
                            beq exit
                            sec
exit                        retkc

; - Local ---------------------------------------------------------------------
; The input rects are not clipped, and they are signed.
draw_rects                  asl a
                            tax
                            lda update_rects_queued~insert_offsets,x
                            lsr a
                            sta <wCount
                            beq no_rects

                            lda update_rects_queued~start_offsets,x
                            tax

rect_loop                   phx
                            lda update_rects_queued~rects~left,x
                            cmp <wClipRight
                            bsge clipped
                            cmp <wClipLeft
                            bsge ok_x
                            lda <wClipLeft
ok_x                        sta <wX

                            lda update_rects_queued~rects~top,x
                            cmp <wClipBottom
                            bsge clipped
                            cmp <wClipTop
                            bsge ok_y
                            lda <wClipTop
ok_y                        sta <wY

                            lda update_rects_queued~rects~right,x
                            cmp <wClipLeft
                            bsle clipped
                            cmp <wClipRight
                            bslt ok_right
                            lda <wClipRight
ok_right                    sta <wWidth             ; really the right for now

                            lda update_rects_queued~rects~bottom,x
                            cmp <wClipTop
                            bsle clipped
                            cmp <wClipBottom
                            bslt ok_bottom
                            lda <wClipBottom
ok_bottom                   sta <wHeight

                            sec
                            sbc <wY
                            beq clipped
                            bcc clipped
                            sta <wHeight

                            lda <wWidth
                            sec
                            sbc <wX
                            beq clipped
                            bcc clipped
                            sta <wWidth

                            pushsword <wX
                            pushsword <wY
                            pushsword <wWidth
                            pushsword <wHeight
                            pushsword <wColor
                            pushsword #0
                            jsl grlib_draw_debug_rect   ; draws an 'inclusive' rect

clipped                     plx
                            inx                     ; + field size
                            inx
                            dec <wCount
                            bne rect_loop

                            lda <wOptions
                            jsl grlib_debug_pause
no_rects                    rts
                            end

; -----------------------------------------------------------------------------
; Quick hack to show when the clipped vs. unclipped functions are being used per frame
_debug_show_draw_info       private seg_grlib
                            using grlib_global_data

                            lda grlib~prle_clipped_draw_count
                            beq no_clipped

                            stz grlib~prle_clipped_draw_count
                            lda #$FFFF
                            sta >$e12000
                            bra check_unclipped

no_clipped                  anop
                            lda >$012000
                            sta >$e12000

check_unclipped             anop
                            lda grlib~prle_unclipped_draw_count
                            beq no_unclipped

                            stz grlib~prle_unclipped_draw_count
                            lda #$FFFF
                            sta >$e12002
                            bra exit

no_unclipped                anop
                            lda >$012002
                            sta >$e12002

exit                        rts
                            end
