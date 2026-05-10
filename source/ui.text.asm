
ui_draw_text_section        start seg_gameplay

                            begin_locals
wX                          decl word
work_area_size              end_locals

                            sub (4:pSection,2:wLeft,2:wY,2:wYAdvance),work_area_size

                            begin_struct
section_entry~advance       decl word
section_entry~color         decl word
section_entry~text          decl ptr
sizeof~section_entry        end_struct

                            setdatabanktoptr <pSection

                            lda <wLeft
                            sta <wX

                            ldy <pSection

section_loop                anop
; Get the advance.  If it is negative, it signals the end of the section
                            getword {y},#section_entry~advance
                            bmi section_done
                            bit #section_advance~centered
                            beq is_centered

                            and #(section_advance~centered*-1)-1
                            beq no_center_advance
                            jsr _advance
no_center_advance           jsr _calc_centered
                            bra no_advance

not_centered                cmp #0
                            beq no_advance

                            jsr _advance
                            lda <wLeft
                            sta <wX

no_advance                  getword {y},#section_entry~color
                            bmi no_color_change
                            asl a
                            tax
                            lda >appdata~palette_index_to_bits,x
                            jsl grlib_set_font_fore_color
                            ldy <pSection

no_color_change             getword {y},#section_entry~text+2
                            beq no_text
                            pha
                            getword {y},#section_entry~text
                            pha
                            pushsword <wX
                            pushsword <wY
                            jsl grlib_draw_string
                            sta <wX

no_text                     lda <pSection
                            clc
                            adc #sizeof~section_entry
                            sta <pSection
                            tay
                            bra section_loop

section_done                anop
; Always advance at the end of the section
                            lda <wY
                            clc
                            adc <wYAdvance
                            adc #2
                            sta <wY
                            restoredatabank

                            ret 2:wY

;
_advance                    anop
                            pha
                            and #$00ff                          ; lower word is the number of lines
                            ldx <wYAdvance
                            jsl math~umul1r2
                            clc
                            adc <wY
                            sta <wY
                            pla
                            xba                                 ; high byte is extra pixels
                            and #$00ff
                            adc <wY
                            sta <wY
                            rts

_calc_centered              anop

                            phy
                            stz <wWidth
centered_loop               anop
; Loop until the end or the next advance
                            getword {y},#section_entry~advance
                            bne centered_done

                            getword {y},#section_entry~text+2
                            beq no_text
                            phy
                            pha
                            getword {y},#section_entry~text
                            pha
                            jsl grlib_get_string_pixel_size
                            clc
                            adc <wWidth
                            sta <wWidth
                            ply

no_text                     tya
                            clc
                            adc #sizeof~section_entry
                            tay
                            bra centered_loop

centered_done               ply

                            lda #320
                            sec
                            sbc <wLeft
                            cmp <wWidth
                            blt too_wide
                            sec
                            sbc <wWidth
                            lsr a
                            clc
                            adc <wLeft
                            sta <wX
                            rts

too_wide                    lda <wLeft
                            sta <wX
                            rts
                            end
