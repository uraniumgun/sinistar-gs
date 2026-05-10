; -----------------------------------------------------------------------
; Fill a vertical line, assuming that just the left-most pixel will be filled
; This is meant to be included, inline, inside a segment so as to
; share patched code between functions that differ, only by the patched
; destination.

; Write the left pixel
                            and #grlib~left_pixel_mask
                            shortm
                            sta >write_left_pixel_value+1
                            longm
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.
;                           clc                         ; carry will be clear from asl above
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
write_left_loop             anop
                            shortm
write_left_patch1           lda >$000000,x
                            and #grlib~right_pixel_mask  ; keeping the right pixel
write_left_pixel_value      ora #$00
write_left_patch2           sta >$000000,x
                            longm

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

                            dey                         ;finished?
                            bne write_left_loop

                            rts
