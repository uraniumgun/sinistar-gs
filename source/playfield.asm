                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm

                            copy source/playfield.definitions.asm

                            mcopy generated/playfield.macros

                            longa on
                            longi on

; --------------------------------------------------------------------------------------------
playfield_manager_data      data seg_gameplay

; Some cached values for the currently active playfield.
; I may just abandon the allocating of the playfield, and have just one inlined here.
; It is super handy to have globals to values in the playfield, and I'm not going to have
; more than one at a time.
; Really, it would be better to have equates to some of these.

playfield_manager~x_max ds 2                            ; Max X value
playfield_manager~y_max ds 2                            ; Max Y value
playfield_manager~x_distance_wrap_negative ds 2         ; Min X delta
playfield_manager~x_distance_wrap_positive ds 2          ; Max X delta
playfield_manager~y_distance_wrap_negative ds 2         ; Min Y delta
playfield_manager~y_distance_wrap_positive ds 2          ; Max Y delta
playfield_manager~x_min ds 2                            ; Min X value
playfield_manager~y_min ds 2                            ; Min Y value

playfield_manager~width ds 2                            ; Width
playfield_manager~height ds 2                           ; Height

playfield_manager~view_changed  dc i'0'                 ; true, if the view has changed position this frame

; The speed of the view, from the last update.  This is constantly re-calculated, based on
; the player speed, as well as the speed_modifier state.
playfield_manager~view_speed_x dc i'0'                  ; fp16
playfield_manager~view_speed_y dc i'0'                  ; fp16

; This is the view speed, not adjusted for the speed_modifier state
playfield_manager~unadjusted_view_speed_x dc i'0'       ; fp16
playfield_manager~unadjusted_view_speed_y dc i'0'       ; fp16

playfield_view~palette_shr_slot     dc i'$ffff'     ; The palette slot on the shr screen to use for the playfield
playfield_view~palette_shr_slot_offset dc i'0'      ; The palette slot start offset in the shr palette array

playfield_view~palette              ds sizeof~palette_modifier*16

                            end
; --------------------------------------------------------------------------------------------
; Construct an empty playfield
playfield_construct         start seg_gameplay

                            begin_locals
result                      decl word
work_area_size              end_locals
                            debugtag 'construct'
                            debugtag 'playfield'

                            sub (4:pThis),work_area_size

                            lda #0
                            sta <result

                            putword [<pThis],#playfield~bounds+grlib_rect~left
                            putword [<pThis],#playfield~bounds+grlib_rect~top
                            putword [<pThis],#playfield~bounds+grlib_rect~right
                            putword [<pThis],#playfield~bounds+grlib_rect~bottom

                            clc
                            retkc 2:result
                            end

; --------------------------------------------------------------------------------------------
; Destruct a playfield
playfield_destruct          start seg_gameplay

                            begin_locals
work_area_size              end_locals
                            debugtag 'destruct'
                            debugtag 'playfield'

                            sub (4:pThis),work_area_size
                            testptr <pThis
                            beq exit

exit                        ret
                            end

; --------------------------------------------------------------------------------------------
; Set the bounds of the entire playfield
playfield_set_bounds        start seg_gameplay
                            using playfield_manager_data

                            begin_locals
work_area_size              end_locals
                            debugtag 'set_bounds'
                            debugtag 'playfield'

                            sub (4:pThis,2:wLeft,2:wTop,2:wRight,2:wBottom),work_area_size

                            lda <wLeft
                            putword [pThis],#playfield~bounds+grlib_rect~left
                            sta playfield_manager~x_min
                            lda <wTop
                            putword [pThis],#playfield~bounds+grlib_rect~top
                            sta playfield_manager~y_min
                            lda <wRight
                            putword [pThis],#playfield~bounds+grlib_rect~right
                            sta playfield_manager~x_max

                            sec
                            sbc <wLeft
                            sta playfield_manager~width
                            lsr a
                            sta playfield_manager~x_distance_wrap_positive
                            negate a
                            sta playfield_manager~x_distance_wrap_negative

                            lda <wBottom
                            putword [pThis],#playfield~bounds+grlib_rect~bottom
                            sta playfield_manager~y_max

                            sec
                            sbc <wTop
                            sta playfield_manager~height
                            lsr a
                            sta playfield_manager~y_distance_wrap_positive
                            negate a
                            sta playfield_manager~y_distance_wrap_negative

                            ret
                            end

; --------------------------------------------------------------------------------------------
; Construct a view, into a playfield
; This takes an input of the buffer for the playfield_view and its parent playfield.
playfield_view_construct    start seg_gameplay

                            begin_locals
result                      decl word
work_area_size              end_locals
                            debugtag 'construct'
                            debugtag 'playfield_view'

                            sub (4:pThis,4:pPlayfield),work_area_size

                            lda #0
                            sta <result

                            putword [<pThis],#playfield_view~bounds+grlib_rect~left
                            putword [<pThis],#playfield_view~bounds+grlib_rect~top
                            putword [<pThis],#playfield_view~bounds+grlib_rect~right
                            putword [<pThis],#playfield_view~bounds+grlib_rect~bottom

                            lda <pPlayfield
                            putptrlow [<pThis],#playfield_view~playfield_ptr
                            lda <pPlayfield+2
                            putptrhigh [<pThis],#playfield_view~playfield_ptr

                            pushptr <pThis,#playfield_view~sort_list
                            pushsword #playfield~max_entities
                            jsl grlib_entity_sort_list_construct

                            clc
                            retkc 2:result
                            end

; --------------------------------------------------------------------------------------------
playfield_view_destruct     start seg_gameplay

                            begin_locals
work_area_size              end_locals
                            debugtag 'destruct'
                            debugtag 'playfield_view'

                            sub (4:pThis),work_area_size

                            pushptr <pThis,#playfield_view~sort_list
                            jsl grlib_entity_sort_list_destruct

                            ret
                            end

; --------------------------------------------------------------------------------------------
; Set the bounds of a view into a playfield
playfield_view_set_bounds   start seg_gameplay

                            begin_locals
work_area_size              end_locals
                            debugtag 'set_bounds'
                            debugtag 'playfield_view'

                            sub (4:pThis,2:wLeft,2:wTop,2:wRight,2:wBottom),work_area_size

                            lda <wLeft
                            putword [pThis],#playfield_view~bounds+grlib_rect~left
                            lda <wTop
                            putword [pThis],#playfield_view~bounds+grlib_rect~top
                            lda <wRight
                            putword [pThis],#playfield_view~bounds+grlib_rect~right
                            lda <wBottom
                            putword [pThis],#playfield_view~bounds+grlib_rect~bottom

                            ret
                            end

; --------------------------------------------------------------------------------------------
playfield_view_draw         start seg_gameplay
                            using grlib_global_data
                            using grlib_update_rects_data2
                            using playfield_manager_data

                            debugtag 'draw_playfield_view'

;                           keyed_break 2,'view_draw'
; Draw the collision list, which is essentially the on-screen list

; Two methods of drawing are available.
; This function, draws the collision list into each invalidate rect
; This is good, if there are objects on the collision list, that did NOT add themselves
; to the invalidate rects.
;                            jsl playfield_draw_collision_list_into_invalidated_rects

; This function assumes we will be drawing everything, so just draws into the full view.
; This is best, when everything in the collision list, is also covered by an invalidated rect.
                            jsl playfield_draw_collision_list_into_view
; Explosions are drawn separately
                            jsl explosion_entity_manager_draw

                            rtl
                            end

; --------------------------------------------------------------------------------------------
; Set the palette for the playfield.
; This will make a local copy of the colors and use those as the 'default'
; Colors can be changed by gameplay, and can be set to automatically return to the default color.
; This is primarily used to simulate a 'flash'.
; This might be nice to extend to use the color_cycled_palette library
; However, we also don't want to waste a lot of cycles on color slots that we know the game
; will never change
playfield_view_set_palette  start seg_gameplay
                            using playfield_manager_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'set_palette'
                            debugtag 'playfield_view'

                            sub (4:pPalette,2:wSlot),work_area_size

                            setlocaldatabank

                            lda <wSlot
                            sta playfield_view~palette_shr_slot
                            shiftleft 5                             ; 16 * 2
                            sta playfield_view~palette_shr_slot_offset

                            ldx #0
                            ldy #palette~colors
loop                        lda [<pPalette],y
                            sta playfield_view~palette,x
                            lda #1                                  ; this will make it so that the next update call, will apply the base color
                            sta playfield_view~palette+palette_modifier~count_down,x
                            stz playfield_view~palette+palette_modifier~alt_color,x         ; don't really have to clear these next two.
                            stz playfield_view~palette+palette_modifier~pad,x
                            iny
                            iny
                            txa
                            clc
                            adc #sizeof~palette_modifier
                            tax
                            cpy #16*2
                            bne loop

                            restoredatabank

                            ret
                            end

; --------------------------------------------------------------------------------------------
; Apply the palette to the shr palette
playfield_view_apply_palette start seg_gameplay
                            using playfield_manager_data
                            using grlib_global_data

                            debugtag 'apply_palette'
                            debugtag 'playfield_view'

                            setlocaldatabank

                            ldx playfield_view~palette_shr_slot_offset
                            ldy #0
loop                        lda playfield_view~palette+palette_modifier~count_down,y
                            beq next
                            bmi apply
                            dec a
                            sta playfield_view~palette+palette_modifier~count_down,y
                            bne next
; timed out, set back to base
                            lda >grlib~shr_palettes,x
                            and #grlb~shr_palette_reserved_mask             ; Apple says the upper bits are reserved and they shouldn't be modified.  Is this really needed?
                            ora playfield_view~palette+palette_modifier~base_color,y
                            sta >grlib~shr_palettes,x
                            bra next
apply                       anop
                            and #$7fff
                            beq next                                        ; this is actually an error
                            sta playfield_view~palette+palette_modifier~count_down,y
                            lda >grlib~shr_palettes,x
                            and #grlb~shr_palette_reserved_mask
                            ora playfield_view~palette+palette_modifier~alt_color,y
                            sta >grlib~shr_palettes,x

next                        anop
                            inx
                            inx
                            tya
                            clc
                            adc #sizeof~palette_modifier
                            tay
                            cpy #sizeof~palette_modifier*16
                            bne loop

                            restoredatabank

                            rtl
                            end
