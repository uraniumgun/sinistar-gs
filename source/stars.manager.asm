                            copy lib/source/debug.definitions.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            copy source/playfield.entity.definitions.asm
                            copy source/playfield.definitions.asm

                            mcopy generated/stars.manager.macros

                            longa on
                            longi on

; Turn this on to have the star placement do some validation
;debug_star_placement        gequ 1

; -----------------------------------------------------------------------------
stars_manager_data          data seg_entity

max_star_count              equ 10

star_types                  dc i'$0660'
                            dc i'$0CC0'

stars_screen_width          ds 2
stars_screen_width_negative ds 2
stars_screen_height         ds 2
stars_screen_height_negative ds 2
stars_screen_x              ds 2
stars_screen_y              ds 2

; These addresses will be relative to the top of the screen, i.e. $0000
stars_screen_start_address  ds 2
stars_screen_end_address    ds 2
stars_screen_v_bottom_address ds 2          ; address of the beginning of the last line
stars_screen_byte_width     ds 2
stars_screen_byte_offset    ds 2

stars~move_accum_x          ds 2
stars~move_accum_y          ds 2

; Vertical relative addresses for each star
star_v_addresses            ds max_star_count*2
; Horizontal relative addresses, from left edge, in pixels
star_h_addresses            ds max_star_count*2

; Screen relative address of each star
star_addresses              ds max_star_count*2
; Pixel values for each star.  Note these are word values, but only the lower byte is used
star_values                 ds max_star_count*2
; Pixel values for each star, when on an even pixel.  Note these are word values, but only the lower byte is used
star_even_values            ds max_star_count*2
; Pixel values for each star, when on an odd pixel.  Note these are word values, but only the lower byte is used
star_odd_values             ds max_star_count*2

                            end

; -----------------------------------------------------------------------------
stars_manager_initialize    start seg_entity

                            debugtag 'stars_initialize'

                            rtl
                            end

; -----------------------------------------------------------------------------
stars_manager_uninitialize  start seg_entity
                            using stars_manager_data

                            debugtag 'stars_uninitialize'

                            rtl
                            end

; -----------------------------------------------------------------------------
stars_manager_turn_activate start seg_entity
                            using appdata
                            using stars_manager_data
                            using gameplay_level_data
                            using applib_data
                            using YLookupData
                            using grlib_update_rects_data2

                            debugtag 'stars_turn_activate'

                            setlocaldatabank

                            jsr stars_manager_patch

                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~left
                            sta stars_screen_x
                            lsr a
                            sta stars_screen_byte_offset

                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~right
                            sec
                            sbc stars_screen_x
                            sta stars_screen_width
                            tax
                            lsr a
                            sta stars_screen_byte_width
                            txa
                            negate a
                            sta stars_screen_width_negative

                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~top
                            sta stars_screen_y

                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~bottom
                            sec
                            sbc stars_screen_y
                            sta stars_screen_height
                            negate a
                            sta stars_screen_height_negative

                            lda stars_screen_y
                            asl a
                            tax
                            lda >gYLookup,x
                            clc
                            adc stars_screen_byte_offset
                            sta stars_screen_start_address

                            lda stars_screen_height
                            asl a
                            tax
                            lda >gYLookup,x
                            clc
                            adc stars_screen_start_address
                            sta stars_screen_v_bottom_address
                            adc stars_screen_byte_width
                            sta stars_screen_end_address

                            jsr _stars_rebuild

                            stz stars~move_accum_x
                            stz stars~move_accum_y

                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
stars_manager_update        start seg_entity
                            using appdata
                            using grlib_global_data
                            using grlib_global_equates
                            using stars_manager_data
                            using gameplay_level_data
                            using playfield_manager_data
                            using applib_data
                            using grlib_update_rects_data2
                            using YLookupData

                            debugtag 'update'
                            debugtag 'stars_manager'

                            begin_struct grdp~caller_scratch_buffer
wXAddPixels                 decl word
wYAddBytes                  decl word
wYAddLines                  decl word
wPixelIsOdd                 decl word
wTemp                       decl word
                            end_struct

;                           keyed_break 3,'update_stars'

; Use the grlib_dp scratch space
                            phd
                            lda >grlib~dp
                            tcd

                            setlocaldatabank
                            shortm
; Erase old stars. Note that this does a copy from the back buffer, even if we didn't draw the star in that position on the previous pass
; This is ok, since we are copying what is on the backbuffer, and we want what is there regardless.
                            ldy #2*(max_star_count-1)
erase_loop                  ldx star_addresses,y
 aif C:debug_star_placement=0,.skip
                            cpx #$7d00
                            blt ok_erase_address
                            brk $03
ok_erase_address            anop
.skip
patch_erase_backbuffer_read lda $ffffff,x                       ; Get from back, buffer
                            sta grlib~real_screen_address,x     ; put on the screen.
                            dey
                            dey
                            bpl erase_loop

                            longm

                            lda >playfield_manager~view_changed             ; If there was no change in the view, do not apply the movement.
                            jeq done_move

; Calculate the amount to 'scroll' the star locations
;                           keyed_break 5

                            stz <wXAddPixels
                            stz <wYAddBytes

                            lda >playfield_manager~view_speed_x
                            beq do_y
                            clc
                            adc stars~move_accum_x                          ; add to the accumulator, which contains any left over fractional value from the last move
                            tax
                            bmi neg_x_add
; Adding a positive value to X
                            and #$00ff                                      ; save the fractional part for next time
                            sta stars~move_accum_x
                            txa
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            sta <wXAddPixels
                            bra do_y

; Adding a negative value to X
neg_x_add                   and #$00ff                                      ; save the fractional part for next time
; Setup rounding correction. -0.5 is $ff80, and -1 is $ff00, so if there is any factional part
; we want the integer conversion to round toward 0, not away.  Use the carry flag and an add of 0, to adjust the value
                            clc
                            beq neg_x_no_round_correction
                            sec
                            ora #$ff00                                      ; sign extend, though not if 0, there is no -0
neg_x_no_round_correction   anop
                            sta stars~move_accum_x
                            txa
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            adc #$0000                                      ; rounding correction
                            sta <wXAddPixels

do_y                        anop
                            lda >playfield_manager~view_speed_y
                            beq next
                            clc
                            adc stars~move_accum_y                          ; add to the accumulator, which contains any left over fractional value from the last move
                            bmi neg_y_add                                   ; have to handle negative numbers differently, because we will need to sign extend
; Adding a positive value to Y
                            tax
                            and #$00ff                                      ; save the fractional part for next time
                            sta stars~move_accum_y
                            txa
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            sta <wYAddLines
                            asl a
                            tax
                            lda >gYLookup,x
                            sta <wYAddBytes
                            bra next

; Adding a negative value to Y
neg_y_add                   tax
                            and #$00ff                                      ; save the fractional part for next time
; Setup rounding correction. The factional part is always positive, so -0.5 is $ff80, and -1 is $ff00, so if there is any factional part
; we want the integer conversion to round toward 0, not away.  Use the carry flag and an add of 0, to adjust the value
                            clc
                            beq neg_y_no_round_correction
                            sec
                            ora #$ff00                                      ; sign extend, though not if 0, there is no -0
neg_y_no_round_correction   anop
                            sta stars~move_accum_y
                            txa
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            adc #$0000                                      ; rounding correction
                            sta <wYAddLines
                            negate a
                            asl a
                            tax
                            lda >gYLookup,x
                            negate a
                            sta <wYAddBytes
next                        anop

; Do the moves.
                            ldy #2*(max_star_count-1)           ; Y will have the star offset
move_loop                   lda star_v_addresses,y
                            clc
                            adc <wYAddBytes
                            cmp stars_screen_end_address
                            bge off_bottom
                            cmp stars_screen_start_address
                            jlt off_top

                            sta star_v_addresses,y
                            sta <wTemp

                            lda star_h_addresses,y
                            clc
                            adc <wXAddPixels
                            bmi off_left
                            cmp stars_screen_width
                            bge off_right

                            sta star_h_addresses,y
                            lsr a                               ; to bytes
; Get the correct pixel value into X
                            bcc even_x
                            ldx star_odd_values,y
                            bra odd_x
even_x                      ldx star_even_values,y
odd_x                       anop
; Update the full address of the star
                            clc
                            adc <wTemp
 aif C:debug_star_placement=0,.skip
                            cmp #$7d00
                            blt range_ok1
                            brk $04
range_ok1                   anop
.skip
                            sta star_addresses,y
; Update the pixel value to draw
                            txa
                            sta star_values,y

next_move                   dey
                            dey
                            bpl move_loop
                            brl done_move

off_left                    jmp _get_random_wrap_left
off_right                   jmp _get_random_wrap_right

; The star has moved off the bottom, replace it at the top
off_bottom                  anop
; Get a random horizontal value, I am cheating, and always getting an even value
                            jsl math~rnd_generate
                            and #$00FF
                            cmp stars_screen_byte_width
                            blt ok_x_bottom
x_clip_loop                 sec
                            sbc stars_screen_byte_width
                            cmp stars_screen_byte_width
                            bge x_clip_loop
ok_x_bottom                 sta <wTemp                                      ; horizontal byte
                            asl a                                           ; to pixels
                            sta star_h_addresses,y
; Get a random vertical value, in the scroll range.
                            lda >math~rnd_seed+2
; Multiply the max of the range, by 0-255, and take the upper byte, to convert to a value in the range, expensive, but effective.
                            and #$00ff
                            ldx <wYAddLines
 aif C:debug_star_placement=0,.skip
                            bpl ob_is_pos
                            brk $0c
ob_is_pos                   anop
.skip
                            jsl math~umul1r2
                            xba
                            and #$00ff
 aif C:debug_star_placement=0,.skip
                            cmp stars_screen_height
                            blt range_ok2
                            brk $05
range_ok2                   anop
.skip
                            asl a
                            tax
                            lda >gYLookup,x
                            clc
                            adc stars_screen_start_address
                            sta star_v_addresses,y
                            clc
                            adc <wTemp
 aif C:debug_star_placement=0,.skip
                            cmp #$7d00
                            blt range_ok3
                            brk $06
range_ok3                   anop
.skip
                            sta star_addresses,y
; Pick a random star type
                            lda >math~rnd_seed+1
                            and #$02
                            tax
                            lda star_types,x
                            sta star_even_values,y
                            sta star_values,y                               ; we always pick an even horizontal position
                            xba
                            sta star_odd_values,y
                            bra next_move

; The star has moved off the top, replace it at the bottom
off_top                     anop
; Get a random horizontal value, I am cheating, and always getting an even value
                            jsl math~rnd_generate
                            and #$00FF
                            cmp stars_screen_byte_width
                            blt ok_x_top
x_clip_loop2                sec
                            sbc stars_screen_byte_width
                            cmp stars_screen_byte_width
                            bge x_clip_loop2
ok_x_top                    sta <wTemp                          ; horizontal byte
                            asl a                               ; to pixels
                            sta star_h_addresses,y
; Get a random vertical value, in the scroll range.
                            lda >math~rnd_seed+2
; Multiply the max of the range, by 0-255, and take the upper byte, to convert to a value in the range, expensive, but effective.
                            and #$00ff
                            tax
                            lda <wYAddLines
 aif C:debug_star_placement=0,.skip
                            bmi ot_is_negative
                            brk $0b
ot_is_negative              anop
.skip
                            negate a                            ; the range was negative
                            jsl math~umul1r2
                            xba
                            and #$00ff
 aif C:debug_star_placement=0,.skip
                            cmp stars_screen_height
                            blt range_ok4
                            brk $07
range_ok4                   anop
.skip
                            asl a
                            tax
                            lda >gYLookup,x
                            negate a                            ; make negative, so we subtract from the end.
                            clc
                            adc stars_screen_v_bottom_address
                            sta star_v_addresses,y
                            adc <wTemp                          ; add the horizontal in
 aif C:debug_star_placement=0,.skip
                            cmp #$7d00
                            blt range_ok5
                            brk $08
range_ok5                   anop
.skip
                            sta star_addresses,y
; Pick a random star type
                            lda >math~rnd_seed+1
                            and #$02
                            tax
                            lda star_types,x
                            sta star_even_values,y
                            sta star_values,y                   ; we always pick an even one.
                            xba
                            sta star_odd_values,y
                            brl next_move

done_move                   anop

                            shortm
; Draw stars
                            ldy #2*(max_star_count-1)
draw_loop                   ldx star_addresses,y
 aif C:debug_star_placement=0,.skip
                            cpx #$7d00
                            blt ok_draw_address
                            brk $02
ok_draw_address             anop
.skip
patch_draw_backbuffer_read  lda $ffffff,x                       ; Get from back, buffer
                            bne no_draw                         ; something there?
                            lda star_values,y
                            sta >grlib~real_screen_address,x     ; put on the screen.
no_draw                     dey
                            dey
                            bpl draw_loop

                            longm

                            restoredatabank
                            pld
                            rtl

_get_random_wrap_left       anop
                            jsl math~rnd_generate
; Multiply the max of the range, by 0-255, and take the upper byte, to convert to a value in the range, expensive, but effective.
                            and #$00ff
                            tax
                            lda <wXAddPixels
                            negate a                            ; the range was negative
                            and #$00ff                          ; We have to clamp to a max of 255, for the x, for this mul trick to work.
                            jsl math~umul1r2
                            xba
                            and #$00ff
                            inc a                               ; could get rid of this, if we have stars_screen_width_minus_one precalculated
                            negate a                            ; make negative, so we subtract from the end.
                            clc
                            adc stars_screen_width
                            sta star_h_addresses,y
                            lsr a
                            sta <wTemp
; Pick a random star type
                            bcc even_star_left

;                           jsl math~rnd_generate
                            lda >math~rnd_seed
                            and #$02
                            tax
                            lda star_types,x
                            sta star_even_values,y
                            xba
                            sta star_odd_values,y
                            sta star_values,y
                            bra _wrap_left_do_y

even_star_left              anop
;                           jsl math~rnd_generate
                            lda >math~rnd_seed
                            and #$02
                            tax
                            lda star_types,x
                            sta star_even_values,y
                            sta star_values,y
                            xba
                            sta star_odd_values,y
;
_wrap_left_do_y             lda >math~rnd_seed+2
                            and #$00ff
                            cmp stars_screen_height
                            blt ok_y_left
y_clip_loop                 sec
                            sbc stars_screen_height
                            cmp stars_screen_height
                            bge y_clip_loop
ok_y_left                   asl a
                            tax
                            lda >gYLookup,x
                            clc
                            adc stars_screen_start_address
                            sta star_v_addresses,y
                            adc <wTemp
 aif C:debug_star_placement=0,.skip
                            cmp #$7d00
                            blt range_ok6
                            brk $09
range_ok6                   anop
.skip
                            sta star_addresses,y
                            jmp next_move

_get_random_wrap_right      anop
; Would be nice to not always put the star at the far edge, we can put it within the wXAddPixels range.
                            jsl math~rnd_generate
                            and #$00ff
                            tax
                            lda <wXAddPixels
                            and #$00ff
                            jsl math~umul1r2
                            xba
                            and #$00ff
                            sta star_h_addresses,y
                            lsr a
                            sta <wTemp
; Pick a random star type
                            bcc even_star_right
;                           jsl math~rnd_generate
                            lda >math~rnd_seed
                            and #$02
                            tax
                            lda star_types,x
                            sta star_even_values,y
                            xba
                            sta star_odd_values,y
                            sta star_values,y
                            bra _wrap_right_do_y

even_star_right             anop
;                           jsl math~rnd_generate
                            lda >math~rnd_seed
                            and #$02
                            tax
                            lda star_types,x
                            sta star_even_values,y
                            sta star_values,y
                            xba
                            sta star_odd_values,y
;
_wrap_right_do_y            anop
                            lda >math~rnd_seed+2
                            and #$00ff
                            cmp stars_screen_height
                            bge y_clip_loop
                            asl a
                            tax
                            lda >gYLookup,x
                            clc
                            adc stars_screen_start_address
                            sta star_v_addresses,y
                            adc <wTemp
 aif C:debug_star_placement=0,.skip
                            cmp #$7d00
                            blt range_ok7
                            brk $0a
range_ok7                   anop
.skip
                            sta star_addresses,y
                            jmp next_move

stars_manager_patch         entry
                            phd
                            lda >grlib~dp
                            tcd

                            shortm
                            lda <altscr_ptr+2
                            sta >patch_erase_backbuffer_read+3
                            sta >patch_draw_backbuffer_read+3
                            longm
                            lda <altscr_ptr
                            sta >patch_erase_backbuffer_read+1
                            sta >patch_draw_backbuffer_read+1

                            pld
                            rts

                            end

; -----------------------------------------------------------------------------
; Rebuild all the stars.  The assumes the previous ones were erased!
_stars_rebuild              private seg_entity
                            using appdata
                            using stars_manager_data
                            using gameplay_level_data
                            using applib_data
                            using YLookupData

                            debugtag 'stars_rebuild'

                            begin_locals
wTempAddress                decl word
wStarOffset                 decl word
work_area_size              end_locals

                            lsub ,work_area_size

                            lda #(max_star_count-1)*2
                            sta <wStarOffset

loop                        anop
; Y random value
                            jsl math~rnd_generate
                            and #$00ff
                            ldx stars_screen_height
                            jsl math~umul1r2
                            xba
                            and #$00ff
                            asl a
                            tax
                            lda >gYLookup,x
                            clc
                            adc stars_screen_start_address
                            sta <wTempAddress

; X Random value
                            jsl math~rnd_generate
                            and #$00ff
                            ldx stars_screen_byte_width         ; going to cheat, and pick a random byte position
                            jsl math~umul1r2
                            xba
                            and #$00ff
                            asl a                               ; to pixels
                            ldx <wStarOffset
                            sta star_h_addresses,x              ; store horizontal address
                            clc
                            adc <wTempAddress
                            sta star_addresses,x                ; final address for the star
                            lda <wTempAddress
                            sta star_v_addresses,x              ; store the vertical address

; Pick a random star type
                            lda >math~rnd_seed+2
                            and #$02
                            tay
                            lda star_types,y
                            sta star_even_values,x
                            sta star_values,x                   ; we picked an even X
                            xba
                            sta star_odd_values,x

                            dec <wStarOffset
                            dec <wStarOffset
                            bpl loop

                            lret
                            end
