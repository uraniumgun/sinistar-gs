                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/std.definitions.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm

                            mcopy generated/palette.support.macros

                            longa on
                            longi on

; --------------------------------------------------------------------------------------------
; Set scanline palette
; Params:
;  pPalette         - The palette to apply
;  wSBCPalette      - The SCB palette to apply to, 0 - 15
grlib_set_shr_palette       start seg_grlib
                            using grlib_global_data

                            debugtag 'set_shr_palette'

                            sub (4:pPalette,2:wSBCPalette),0

; use_quickdraw             equ 1

                            testptr <pPalette
                            beq exit
; TODO: Need to collapse the palette if needed
                            getword [<pPalette],#palette~color_format
                            cmp #palette_color_format~collapsed
                            bne exit

                            aif  C:debug~golden_gate<>0,.skip_all
                            aif  C:debug~use_fake_screen<>0,.skip_all
; Set the palette

                            aif C:use_quickdraw<>0,.skip_qd
; Use Quickdraw to set the palette
                            lda <wSBCPalette
                            cmp #16
                            bge exit
                            pushword
                            pushptr <pPalette,#palette~colors
                            _SetColorTable
.skip_qd

                            aif C:use_quickdraw=0,.skip_grlib
; Write to the palette directly
                            lda <wSBCPalette
                            cmp #16
                            bge exit
                            shiftleft 5             ; x 32
                            tax
                            getptr <pPalette,#palette~colors,<pPalette
                            ldy #0
loop                        lda >grlib~shr_palettes,x
                            and #grlb~shr_palette_reserved_mask             ; Apple says the upper bits are reserved and they shouldn't be modified.  Is this really needed?
                            ora [<Palette],y
                            sta >grlib~shr_palettes,x
                            inx
                            inx
                            iny
                            iny
                            cpy #32
                            bne loop
.skip_grlib

.skip_all

exit                        ret
                            end

; --------------------------------------------------------------------------------------------
; Set scanline control bytes for a range
; This will use the mode, color fill and the palette bits only.  It will not change the interrupt flag.
; Params:
;  wBits            - bits to set, in the low byte only
;  wStartLine       - The first line to set
;  wCount           - The number of lines to set.
grlib_set_scb_range         start seg_grlib
                            using grlib_global_data

                            debugtag 'set_scb_range'

                            sub (2:wBits,2:wStartLine,2:wCount),0

                            lda <wStartLine
                            cmp #200
                            bge exit
                            tax
                            clc
                            adc <wCount
                            cmp #201
                            bge exit
                            lsr <wCount
                            bcc even

                            shortm
                            lda >grlib~shr_scbs,x
                            and #grlib~shr_scb_interrupt+grlib~shr_scb_reserved_mask
                            ora <wBits
                            sta >grlib~shr_scbs,x
                            longm
                            inx
                            lda <wCount

even                        beq exit
; Need the lower bits in the upper bits of <wBits
                            shortm              ; 3
                            lda <wBits          ; 4
                            sta <wBits+1        ; 4
                            longm               ; 3

loop                        lda >grlib~shr_scbs,x
                            and #(grlib~shr_scb_interrupt+grlib~shr_scb_reserved_mask)+((grlib~shr_scb_interrupt+grlib~shr_scb_reserved_mask)|8)
                            ora <wBits
                            sta >grlib~shr_scbs,x
                            inx
                            inx
                            dec <wCount
                            bne loop

                            ago .skip
                            lda <wBits
                            shortm
loop                        lda >grlib~shr_scbs,x
                            and #grlib~shr_scb_interrupt+grlib~shr_scb_reserved_mask
                            ora <wBits
                            sta >grlib~shr_scbs,x
                            inx
                            dec <wCount
                            bne loop
                            longm
.skip

exit                        ret
                            end

; --------------------------------------------------------------------------------------------
; Set the palette slot index, for a range of scanline control bytes
; This only set the palette slot
; Params:
;  wPalette         - bits to set, in the low byte only
;  wStartLine       - The first line to set
;  wCount           - The number of lines to set.
grlib_set_scb_palette_range start seg_grlib
                            using grlib_global_data

                            debugtag 'set_scb_palette_range'

                            sub (2:wBits,2:wStartLine,2:wCount),0

                            lda <wBits
                            and #grlib~shr_scb_palette_mask             ; Make sure it is just the palette bits
                            sta <wBits

                            lda <wStartLine
                            cmp #grlib~screen_height
                            bge exit
                            tax
                            clc
                            adc <wCount
                            cmp #grlib~screen_height+1
                            bge exit
                            lsr <wCount
                            bcc even

                            shortm
                            lda >grlib~shr_scbs,x
                            and #grlib~shr_scb_not_palette_mask
                            ora <wBits
                            sta >grlib~shr_scbs,x
                            longm
                            inx
                            lda <wCount

even                        beq exit
; Need the lower bits in the upper bits of <wBits
                            shortm              ; 3
                            lda <wBits          ; 4
                            sta <wBits+1        ; 4
                            longm               ; 3

loop                        lda >grlib~shr_scbs,x
                            and #(grlib~shr_scb_not_palette_mask)+(grlib~shr_scb_not_palette_mask|8)
                            ora <wBits
                            sta >grlib~shr_scbs,x
                            inx
                            inx
                            dec <wCount
                            bne loop

                            ago .skip
                            lda <wBits
                            shortm
loop                        lda >grlib~shr_scbs,x
                            and #grlib~shr_scb_not_palette_mask
                            ora <wBits
                            sta >grlib~shr_scbs,x
                            inx
                            dec <wCount
                            bne loop
                            longm
.skip

exit                        ret
                            end

; --------------------------------------------------------------------------------------------
; Get scanline palette
; Params:
;  pPalette         - The palette to fill
;  wSBCPalette      - The SCB palette to get the colors from, 0 - 15
grlib_get_shr_palette       start seg_grlib
                            using grlib_global_data

                            debugtag 'get_shr_palette'

                            sub (4:pPalette,2:wSBCPalette),0

; use_quickdraw             equ 1

                            testptr <pPalette
                            beq exit
; TODO: Need to collapse the palette if needed
                            getword [<pPalette],#palette~color_format
                            cmp #palette_color_format~collapsed
                            bne exit

                            lda <wSBCPalette
                            cmp #16
                            bge exit
                            shiftleft 5             ; x 32
                            tax
                            getptr <pPalette,#palette~colors,<pPalette
                            ldy #0
loop                        lda >grlib~shr_palettes,x
                            and #grlb~shr_palette_color_mask
                            sta [<pPalette],y
                            inx
                            inx
                            iny
                            iny
                            cpy #32
                            bne loop

exit                        ret
                            end

; -----------------------------------------------------------------------------
; Reserve a shr palette slot.
; Parameters:
; slot          - slot to reserve (0 - 15), or -1, to find an unreserved slot
; Returns:
; Slot number in acc
; carry clear, if slot available, set if none are available
grlib_shr_palette_reserve start seg_grlib
                        using grlib_global_data

                        debugtag 'reserve'
                        debugtag 'palette'

                        begin_locals
result                  decl word
work_area_size          end_locals

                        sub (2:slot),work_area_size

                        stz <result
                        dec <result                     ; Make the result have -1 in it.

                        lda <slot
                        cmp #$ffff
                        bne reserve_specific

                        ldx #0
                        shortm
loop                    lda >grlib~reserved_shr_palettes,x
                        beq found
                        inx
                        cpx #grlib~shr_palette_count
                        bne loop

error                   sec
exit                    longm
exit2                   retkc 2:result
                        longa off
found                   stx <result
                        lda #1
                        sta >grlib~reserved_shr_palettes,x
                        clc
                        bra exit
                        longa on

; reserve a specific slot
reserve_specific        cmp #grlib~shr_palette_count
                        bge exit2                               ; Out of range.  Carry is set, so just exit
                        tax
                        shortm
                        lda >grlib~reserved_shr_palettes,x
                        bne error

                        lda #1
                        sta >grlib~reserved_shr_palettes,x
                        stx <result
                        clc
                        bra exit
                        longa on

                        end

; -----------------------------------------------------------------------------
; Release a reserved shr palette slot
; Returns:
; carry clear, if slot was released, set if was not reserved already
grlib_shr_palette_release_reserve start seg_grlib
                        using grlib_global_data

                        debugtag 'release_reserve'
                        debugtag 'palette'

                        begin_locals
result                  decl word
work_area_size          end_locals

                        sub (2:slot),work_area_size

                        ldx <slot
                        stx <result
                        cpx #grlib~shr_palette_count
                        bge exit2                               ; Out of range.  Carry is set, so just exit

                        shortm
                        lda >grlib~reserved_shr_palettes,x
                        bne ok

                        sec
exit                    longm
exit2                   retkc 2:result
                        longa off
ok                      lda #0
                        sta >grlib~reserved_shr_palettes,x
                        clc
                        bra exit
                        longa on

                        end

; -----------------------------------------------------------------------------
grlib_palette_scb_construct start seg_grlib

                        debugtag 'scb_construct'
                        debugtag 'palette'

                        sub (4:pThis),0

                        lda #16
                        putword [<pThis],#palette~color_count
                        lda #palette_color_format~collapsed
                        putword [<pThis],#palette~color_format
; Put in a gray-scale palette
                        lda #0
                        ldy #palette~colors
loop                    sta [<pThis],y
                        adc #$0111
                        iny
                        iny
                        cpy #sizeof~palette_scb
                        bne loop

                        ret
                        end

; -----------------------------------------------------------------------------
; Copy the input palette to a destination palette, darkening each color
; during the copy.
; This currently just cuts the existing value in half.
; Maybe have an input scalar?
grlib_palette_copy_to_darkened start seg_grlib

                        debugtag 'copy_to_darkened'
                        debugtag 'palette'

                        begin_locals
wTemp                   decl word
work_area_size          end_locals

                        sub (4:pSource,4:pDest),work_area_size

                        getword [<pSource],#palette~color_format
                        cmp #palette_color_format~collapsed
                        bne error
                        getword [<pSource],#palette~color_count
                        cmp #17
                        bge error

; Put in a gray-scale palette
                        ldy #palette~colors
loop                    lda [<pSource],y
                        phy                             ; save our position
; Put some workspace on the stack for the return of the hsv->rgb conversion
                        pha
                        pha
                        pha
; Put some workspace on the stack for the return of the rgb->hsv conversion
                        pha
                        pha
                        pha
; Expand each component to 8 bits and push.  Not the most efficient thing in the universe.
                        tax
                        xba
                        and #$000F
                        shiftleft 4
                        pha                             ; r
                        txa
                        and #$00F0
                        pha                             ; g
                        txa
                        and #$000F
                        shiftleft 4
                        pha                             ; b
                        jsl grlib_rgb_to_hvs

hsv~h                   equ 5
hsv~s                   equ 3
hsv~v                   equ 1

; The HSV components will be on the stack. as well as the space reserved for the return
                        getword {s},#hsv~v
                        lsr a                           ; cut it in half
                        putword {s},#hsv~v
                        jsl grlib_hsv_to_rgb

rgb~r                   equ 5
rgb~g                   equ 3
hsv~b                   equ 1

                        pla                             ; b
                        shiftright 4
                        and #$000F
                        sta <wTemp
                        pla                             ; g
                        and #$00F0
                        ora <wTemp
                        sta <wTemp
                        pla                             ; r
                        shiftleft 4
                        and #$0F00
                        ora <wTemp
                        ply
                        sta [<pDest],y

                        iny
                        iny
                        cpy #sizeof~palette_scb
                        bne loop

error                   ret
                        end

; -----------------------------------------------------------------------------
; Apply a default palette.
grlib_palette_apply_default start seg_grlib

                        pushptr #default_palette
                        pushsword #0
                        jsl grlib_set_shr_palette
                        rtl

default_palette         dc i'16'                                ; palette~color_count
                        dc i'palette_color_format~collapsed'    ; palette~color_format
                        dc i'$0000'
                        dc i'$0223'                             ; 222034
                        dc i'$0d56'                             ; d95763
                        dc i'$0a33'                             ; ac3232
                        dc i'$0853'                             ; 8f563b
                        dc i'$0d72'                             ; df7126
                        dc i'$0878'                             ; 847e87
                        dc i'$0555'                             ; 595652
                        dc i'$0ff3'                             ; fbf236
                        dc i'$09e5'                             ; 99e550
                        dc i'$06b3'                             ; 6abe30
                        dc i'$0396'                             ; 37946e
                        dc i'$0462'                             ; 4b692f
                        dc i'$056e'                             ; 5b6ee1
                        dc i'$069f'                             ; 639bff
                        dc i'$0fff'
                        end
; =============================================================================
; color_cycle_entry functions
; A Color Cycle Entry supports cycling from a start color to and end color.
; The colors are blended using a generated color ramp, currently 32 steps long
; which is is plenty, since the color channel resolution is only 4 bits.
; The cycling of the colors is controlled by a value transform, which can
; have multiple segments, controlling where in the ramp, the color is taken from.
; Having the fixed ramp length, allows for the transform to simply calculate
; a value between 0 and 31, and then just use the integer portion as an index
; into the ramp.
;
; There are some 'basic' transforms that can be applied, but more complex transforms
; can be built.  One limitation is that there is only the single ramp, so
; it is more difficult to cycle between multiple colors.
; One solution would be to have the ramp generator accept multiple colors.
; This would mean that the range was smaller, but a ramp that translated through
; one or two extra colors would probably be ok.

; =============================================================================

; -----------------------------------------------------------------------------
grlib_color_cycle_entry_construct start seg_grlib

                        debugtag 'construct'
                        debugtag 'color_cycle_entry'

                        sub (4:pThis),0

                        pushptr <pThis,#color_cycle_entry~transform
                        jsl value_transform_construct

                        ret
                        end

; -----------------------------------------------------------------------------
grlib_color_cycle_entry_destruct start seg_grlib

                        debugtag 'destruct'
                        debugtag 'color_cycle_entry'

                        sub (4:pThis),0

                        pushptr <pThis,#color_cycle_entry~transform
                        jsl value_transform_destruct

                        ret
                        end

; -----------------------------------------------------------------------------
grlib_color_cycle_entry_set_colors start seg_grlib

                        debugtag 'set_colors'
                        debugtag 'color_cycle_entry'

                        sub (4:pThis,2:wColor1,2:wColor2),0

                        pushptr <pThis,#color_cycle_entry~start
                        pushsword <wColor1
                        pushsword <wColor2
                        jsl grlib_make_color_cycle_range

                        ret
                        end

; -----------------------------------------------------------------------------
; Setup a basic color cycle transform
;
; Parameters:
;  pThis            - the color cycle entry
;  wType            - the type of cycle
;  wTicks           - the amount of time for the whole cycle
;  wLoops           - the number of loops to do, -1 = infinite.
;                     Note that this loop count is inclusive, in that the node is
;                     always played at least once, then the loops are additional passes.
grlib_color_cycle_entry_set_basic_cycle start seg_grlib
                        using value_transform_data

                        debugtag 'set_basic_cycle'
                        debugtag 'color_cycle_entry'

                        begin_locals
pNode                   decl ptr
wUseTransform           decl word
work_area_size          end_locals

                        sub (4:pThis,2:wType,2:wTicks,2:wLoops),work_area_size

                        pushptr <pThis,#color_cycle_entry~transform
                        jsl value_transform_clear_nodes

                        lda #value_transform_node_type~lerp
                        sta <wUseTransform

                        lda <wType
                        cmp #color_cycle_type~up
                        beq is_up
                        cmp #color_cycle_type~up_smoothed
                        beq is_up_smoothed
                        cmp #color_cycle_type~up_down
                        beq is_up_down
                        cmp #color_cycle_type~up_down_smoothed
                        bne unknown_type

                        lda #value_transform_node_type~lerp_s_smoothed
                        sta <wUseTransform

is_up_down              jsr apply_up_down
                        bra exit

is_up_smoothed          lda #value_transform_node_type~lerp_s_smoothed
                        sta <wUseTransform

is_up                   jsr apply_up

exit                    anop
                        retkc
unknown_type            sec
                        bra exit

; =====================================
apply_up                anop
                        pushptr <pThis,#color_cycle_entry~transform
                        pushword <wUseTransform
                        jsl value_transform_append_node_type
                        bcs up_exit
                        putretptr <pNode

                        lda #0
                        putword [<pNode],#value_transform_node~value_start
                        lda #(31|8)
                        putword [<pNode],#value_transform_node~value_end
                        lda <wTicks
                        putword [<pNode],#value_transform_node~tick_length
                        lda <wLoops
                        putword [<pNode],#value_transform_node~loop_count
                        cmp #0
                        beq up_no_loop
                        lda #0
                        putword [<pNode],#value_transform_node~loop_to

up_no_loop              anop
                        pushptr <pNode
                        jsl value_transform_node_apply_values
                        clc
up_exit                 rts

; Set the two stage, up/down cycle
apply_up_down           anop
; The up transform
                        pushptr <pThis,#color_cycle_entry~transform
                        pushword <wUseTransform
                        jsl value_transform_append_node_type
                        bcs up_down_exit
                        putretptr <pNode

                        lda #0
                        putword [<pNode],#value_transform_node~value_start
                        lda #(31|8)
                        putword [<pNode],#value_transform_node~value_end
                        lda <wTicks
                        lsr a
                        adc #0
                        bne up_down_ok_tick1
                        lda #1
up_down_ok_tick1        putword [<pNode],#value_transform_node~tick_length
; Apply the values
                        pushptr <pNode
                        jsl value_transform_node_apply_values

; The down transform
                        pushptr <pThis,#color_cycle_entry~transform
                        pushword <wUseTransform
                        jsl value_transform_append_node_type
                        bcs up_down_exit
                        putretptr <pNode

                        lda #(31|8)
                        putword [<pNode],#value_transform_node~value_start
                        lda #0
                        putword [<pNode],#value_transform_node~value_end
                        lda <wTicks
                        lsr a
                        bne up_down_ok_ticks2
                        lda #1
up_down_ok_ticks2       putword [<pNode],#value_transform_node~tick_length
                        lda <wLoops
                        putword [<pNode],#value_transform_node~loop_count
                        cmp #0
                        beq up_down_no_loop
                        lda #0
                        putword [<pNode],#value_transform_node~loop_to
up_down_no_loop         anop
; Apply the values
                        pushptr <pNode
                        jsl value_transform_node_apply_values

up_down_exit            rts

                        end

; -----------------------------------------------------------------------------
; Update the color cycle entry
; Not currently called, the color cycled palette will do each directly to cut
; down on overhead.
grlib_color_cycle_entry_update start seg_grlib

                        begin_locals
wValue                  decl word
work_area_size          end_locals

                        sub (4:pThis,4:dwTick),work_area_size

                        debugtag 'entry_update'
                        debugtag 'color_cycle'

                        pushptr <pThis,#color_cycle_entry~transform
                        pushdword <dwTick
                        jsl value_transform_update

                        ret
                        end

; -----------------------------------------------------------------------------
; Take two colors and make a color ramp between them
; The ramp length is fixed to 32 steps, with the source color as the first entry
; and the destination color as the last.
;
; Parameters:
; pOut              - a buffer that can hold 32 colors (32 * sizeof(word))
; wColor1           - color to start with, in standard 0444 format
; wColor2           - color to end with, in standard 0444 format
grlib_make_color_cycle_range start seg_grlib
                        using grlib_global_data
                        using math_tables

                        debugtag 'make_color'
                        debugtag 'cycle_range'

                        begin_locals
wTableOffset            decl word
wNegateOffset           decl word
wBlueOffset             decl word
wGreenOffset            decl word
wRedOffset              decl word
wBlueStart              decl word
wGreenStart             decl word
wRedStart               decl word
wPixel                  decl word
work_area_size          end_locals

                        sub (4:pOut,2:wColor1,2:wColor2),work_area_size

                        debugtag 'make_color_cycle_range'

                        lda <wColor1
                        and #grlib~shr_palette_blue_mask
                        shiftright grlib~shr_palette_blue_shift
                        sta <wBlueStart
                        sta <wPixel
                        lda <wColor2
                        and #grlib~shr_palette_blue_mask
                        shiftright grlib~shr_palette_blue_shift
                        jsr get_delta_table_offset
                        sta <wBlueOffset

                        lda <wColor1
                        and #grlib~shr_palette_green_mask
                        shiftright grlib~shr_palette_green_shift
                        sta <wGreenStart
                        sta <wPixel
                        lda <wColor2
                        and #grlib~shr_palette_green_mask
                        shiftright grlib~shr_palette_green_shift
                        jsr get_delta_table_offset
                        sta <wGreenOffset

                        lda <wColor1
                        and #grlib~shr_palette_red_mask
                        shiftright grlib~shr_palette_red_shift
                        sta <wRedStart
                        sta <wPixel
                        lda <wColor2
                        and #grlib~shr_palette_red_mask
                        shiftright grlib~shr_palette_red_shift
                        jsr get_delta_table_offset
                        sta <wRedOffset

                        ldy #0
loop                    ldx <wBlueOffset
                        lda >math~positive_4bits_scaled_over_5bits,x
                        clc
                        adc <wBlueStart
                        sta <wPixel

                        ldx <wGreenOffset
                        lda >math~positive_4bits_scaled_over_5bits,x
                        clc
                        adc <wGreenStart
                        shiftleft grlib~shr_palette_green_shift
                        ora <wPixel
                        sta <wPixel

                        ldx <wRedOffset
                        lda >math~positive_4bits_scaled_over_5bits,x
                        clc
                        adc <wRedStart
                        shiftleft grlib~shr_palette_red_shift
                        ora <wPixel

                        sta [<pOut],y
                        iny
                        iny
                        inc <wBlueOffset
                        inc <wBlueOffset
                        inc <wGreenOffset
                        inc <wGreenOffset
                        inc <wRedOffset
                        inc <wRedOffset
                        cpy #32*2
                        bne loop

                        ret

; Internal function
get_delta_table_offset  anop
                        stz <wNegateOffset
                        stz <wTableOffset

                        sec
                        sbc <wPixel
                        bcs positive
                        eor #$ffff
                        inc a
                        ldx #math~negative_4bits_scaled_over_5bits-math~positive_4bits_scaled_over_5bits
                        stx <wTableOffset

positive                asl a
                        asl a
                        asl a
                        asl a
                        asl a
                        asl a                   ; (delta * 32) * sizeof(word)
                        clc
                        adc <wTableOffset
                        rts

                        end

; =============================================================================
; color_cycled_palette functions

; -----------------------------------------------------------------------------
grlib_color_cycled_palette_construct start seg_grlib

                        sub (4:pThis),0

                        debugtag 'construct'
                        debugtag 'color_cycled_palette'

                        pushptr <pThis,#color_cycled_palette~palette
                        jsl grlib_palette_scb_construct

; Clear memory.
                        ldy #color_cycled_palette~entries
                        lda #0
loop                    sta [<pThis],y
                        iny
                        iny
                        cpy #sizeof~color_cycled_palette
                        bne loop

                        ret
                        end

; -----------------------------------------------------------------------------
grlib_color_cycled_palette_destruct start seg_grlib

                        sub (4:pThis),0

                        debugtag 'palette_destruct'
                        debugtag 'color_cycled'

                        ret
                        end

; -----------------------------------------------------------------------------
; Set a color cycler for a color in the palette
;
; Parameters:
;  pThis            - color cycled palette
;  WColorIndex      - the index in the palete the cycler is for
;  pColorCycleEntry - the color cycler.  Can be null to remove the cycler.
;                     the color cycled palette will NOT own the cycler.
grlib_color_cycled_palette_set_cycle_color start seg_grlib

                        debugtag 'set_cycle_color'
                        debugtag 'color_cycled'

                        sub (4:pThis,2:wColorIndex,4:pColorCycleEntry),0

                        lda <wColorIndex
                        asl a
                        asl a
                        clc
                        adc #color_cycled_palette~entries
                        tay
                        lda <pColorCycleEntry
                        sta [<pThis],y
                        iny
                        iny
                        lda <pColorCycleEntry+2
                        sta [<pThis],y

                        ret
                        end

; -----------------------------------------------------------------------------
; Update the color cycled palette
grlib_color_cycled_palette_update start seg_grlib

                        debugtag 'update'
                        debugtag 'color_cycled_palette'

                        begin_locals
wValue                  decl word
wIndex                  decl word
pColorCycleEntries      decl ptr
pColorCycleEntry        decl ptr
pColors                 decl ptr
work_area_size          end_locals

                        sub (4:pThis,4:dwTick),work_area_size

                        stz <wIndex
                        getptr <pThis,#color_cycled_palette~entries,<pColorCycleEntries
                        getptr <pThis,#color_cycled_palette~palette+palette~colors,<pColors

                        lda <wIndex
loop                    anop
                        asl a
                        asl a
                        tay
                        lda [<pColorCycleEntries],y
                        sta <pColorCycleEntry
                        iny
                        iny
                        lda [<pColorCycleEntries],y
                        sta <pColorCycleEntry+2
                        ora <pColorCycleEntry
                        beq no_change

                        pushptr <pColorCycleEntry,#color_cycle_entry~transform
                        pushdword <dwTick
                        jsl value_transform_update
                        bit #value_transform_state~changed
                        beq no_change

; Get the current value (might want to have the update call return that as well?)
                        pushptr <pColorCycleEntry,#color_cycle_entry~transform
                        pushlocalptr #wValue
                        jsl value_transform_get_current_value

; The transform value is fixed point, get the integer part in the lower bits
;                        brk $02
                        lda <wValue
                        xba
                        and #$1f
                        asl a                       ; need x2
                        clc
                        adc #color_cycle_entry~start
                        tay
                        lda [<pColorCycleEntry],y
                        pha

                        lda <wIndex
                        asl a
                        tay
                        pla
                        sta [<pColors],y

no_change               anop
                        lda <wIndex
                        inc a
                        sta <wIndex
                        cmp #16
                        bne loop

                        ret
                        end

; -----------------------------------------------------------------------------
; Apply the color cycled palette to an shr palette
grlib_color_cycled_palette_apply start seg_grlib

                        debugtag 'apply'
                        debugtag 'color_cycled_palette'

                        begin_locals
work_area_size          end_locals

                        sub (4:pThis,2:wIndex),work_area_size

                        pushptr <pThis,#color_cycled_palette~palette
                        pushsword <wIndex
                        jsl grlib_set_shr_palette
                        ret

                        end

; -----------------------------------------------------------------------------
; Convert an RGB value to HSV
; Components are assumed to be 0-255
;
; Algorithm is from "CG Principals and Practice", though this
; is integer, S and V, being 0-255, rather than 0.0-1.0, and H is also put
; into the same 0-255 range, rather than the traditional 0-359 degrees.

; This is not optimized, so it is a bit slow, but it is clear and simple
;

grlib_rgb_to_hvs        start seg_grlib

                        begin_locals
wMin                    decl word
wDelta                  decl word
work_area_size          end_locals

                        debugtag 'rgb_to_hvs'

                        sub (2:wR,2:wG,2:wB),work_area_size

; Caller instanced results on the stack.  Note using this method, the results have to be defined
; in reverse of how they were pushed.
                        begin_results
wV                      decl word
wS                      decl word
wH                      decl word
                        end_results

; The hue is split into 3 regions, and since we are using 0-255, each will be 85
region_size            equ 85
region_midpoint        equ 43

; Find the min component
                        lda <wR
                        cmp <wG
                        blt min_r_less_g
; r is >= g
                        lda <wG
                        cmp <wB
                        blt min_found               ; if true, g is min
; else b is min
                        lda <wB
                        bra min_found

min_r_less_g            anop
                        cmp <wB
                        blt min_found               ; if true, r is min
; b is the min
                        lda <wB

min_found               anop
                        sta <wMin

; Find max component
                        lda <wR
                        cmp <wG
                        bge max_r_gte_g
; g > r
                        lda <wG
                        cmp <wB
                        bge max_found               ; if true, g is max
; b is max
                        lda <wB
                        bra max_found

max_r_gte_g             anop
                        cmp <wB
                        bge max_found               ; if true, r is max

                        lda <wB
max_found               anop
                        sta <wV

; v is the max component, however if 0 then everything is 0 and we can exit
                        cmp #0
                        bne v_not_0

                        sta <wS
                        sta <wH
                        bra exit

v_not_0                 anop

; s is $ff * (max - min) / v

; get (max - min)
                        sec
                        sbc <wMin
                        sta <wDelta                         ; we will need this later
                        ldx #255
                        jsl math~umul1r2                    ; x 255
                        ldx <wV
                        jsl math~udiv2r2                    ; unsigned div
                        sta <wS
                        cmp #0
                        bne s_not_0
; if s is 0, then h is 0 and we can leave
                        stz <wH
                        bra exit

s_not_0                 anop
; Note, for the regionss, the component subtract is signed.
                        lda <wV                             ; max
                        cmp <wR
                        bne not_r
; Hue is in the first region.
; we want (region_midpoint * (g - b)) / delta.
                        lda <wG
                        sec
                        sbc <wB
                        ldx #region_midpoint
                        jsl math~mul2r2
                        ldx <wDelta
                        jsl math~div2r2
                        and #$00ff
                        sta <wH
                        bra exit

not_r                   anop
                        cmp <wR
                        bne not_g
; Hue is in the second region.
; we want ((region_midpoint * (b - r)) / delta) + region_size.

                        lda <wB
                        sec
                        sbc <wR
                        ldx #43
                        jsl math~mul2r2
                        ldx <wDelta
                        jsl math~div2r2
                        clc
                        adc #region_size                           ; adjust to the second region
                        and #$00ff
                        sta <wH
                        bra exit

not_g                   anop
; Hue is in the third region.
; we want ((region_midpoint * (r - g)) / delta) + (region_size * 2).

                        lda <wR
                        sec
                        sbc <wG
                        ldx #43
                        jsl math~mul2r2
                        ldx <wDelta
                        jsl math~div2r2
                        clc
                        adc #region_size*2                         ; adjust to the third region
                        and #$00ff
                        sta <wH

exit                    anop
                        ret
                        end

; -----------------------------------------------------------------------------
grlib_hsv_to_rgb        start seg_grlib

                        begin_locals
wHalfRegion             decl word
wRemainder              decl word
wP                      decl word
wQ                      decl word
wT                      decl word
work_area_size          end_locals

                        debugtag 'hsv_to_rgb'

                        sub (2:wH,2:wS,2:wV),work_area_size

; Caller instanced results on the stack.  Note using this method, the results have to be defined
; in reverse of how they were pushed.
                        begin_results
wB                      decl word
wG                      decl word
wR                      decl word
                        end_results

                        lda <wS
                        bne s_not_0

; if no saturation, all channels are v
                        lda <wV
                        sta <wR
                        sta <wG
                        sta <wB
                        bra exit

s_not_0                 anop

; The hue is split into 3 regions, and since we are using 0-255, each will be 85
region_size             equ 85
region_midpoint         equ 43

; region = h / region_midpoint;
                        lda <wH
                        ldx #region_midpoint
                        jsl math~udiv2r2
                        sta <wHalfRegion
; multiply the remainer by 6 (region count * 2)
                        lda #6
                        jsl math~umul1r2
                        sta <wRemainder

; p = (($ff - s) * v) >> 8
; ($ff - s) == s ^ $ff == ones-compliment of s
                        lda <wS
                        eor #$00ff
                        ldx <wV
                        jsl math~umul1r2
                        xba
                        and #$00FF
                        sta <wP
; q = (($ff - ((s * remainder) >> 8)) * v) >> 8
                        lda <wS
                        ldx <wRemainder
                        jsl math~umul1r2
                        xba
                        and #$00ff
                        eor #$00ff
                        ldx <wV
                        jsl math~umul1r2
                        xba
                        and #$00FF
                        sta <wQ
; t = (($ff - ((s * ($ff - remainder)) >> 8) * v) >> 8
                        lda <wRemainder
                        eor #$00ff
                        ldx <wS
                        jsl math~umul1r2
                        xba
                        and #$00ff
                        eor #$00ff
                        ldx <wV
                        jsl math~umul1r2
                        xba
                        and #$00FF
                        sta <wT

                        lda <wHalfRegion
                        cmp #6
                        blt ok
                        brk $99
ok                      asl a
                        tax
                        jmp (half_region_table,x)

exit                    ret

half_region_table       anop
                        dc a'hregion_0'
                        dc a'hregion_1'
                        dc a'hregion_2'
                        dc a'hregion_3'
                        dc a'hregion_4'
                        dc a'hregion_5'

hregion_0               anop
; Half-Region 0
                        lda <wV
                        sta <wR
                        lda <wT
                        sta <wG
                        lda <wP
                        sta <wB
                        bra exit
; Half-Region 1
hregion_1               anop
                        lda <wQ
                        sta <wR
                        lda <wV
                        sta <wG
                        lda <wP
                        sta <wB
                        bra exit
; Half-Region 2
hregion_2               anop
                        lda <wP
                        sta <wR
                        lda <wV
                        sta <wG
                        lda <wT
                        sta <wB
                        bra exit
; Half-Region 3
hregion_3               anop
                        lda <wP
                        sta <wR
                        lda <wQ
                        sta <wG
                        lda <wV
                        sta <wB
                        bra exit
; Half-Region 4
hregion_4               anop
                        lda <wT
                        sta <wR
                        lda <wP
                        sta <wG
                        lda <wV
                        sta <wB
                        bra exit
; Half-Region 5
hregion_5               anop
                        lda <wV
                        sta <wR
                        lda <wP
                        sta <wG
                        lda <wQ
                        sta <wB
                        bra exit

                        end
