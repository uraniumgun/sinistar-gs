; -----------------------------------------------------------------------
; Fill a vertical line, assuming that the line is two pixels wide, with
; one pixel in the right-most pixel in the low byte and the other pixel
; in the left pixel of the high byte
; This is meant to be included, inline, inside a segment so as to
; share patched code between functions that differ, only by the patched
; destination.

                            and #grlib~right_pixel_mask+grlib~high_left_pixel_mask
                            sta >write_pixel_value+1
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.
;                           clc                         ; carry will be clear from asl above
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
write_loop                  anop
write_patch1                lda >$000000,x
                            and #grlib~left_pixel_mask+grlib~high_right_pixel_mask  ; keeping the left pixel in the low byte and the right pixel in the high byte
write_pixel_value           ora #$0000
write_patch2                sta >$000000,x

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

                            dey                         ;finished?
                            bne write_loop

                            rts

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_patch_it                   anop
                            lda <patch_ptr
                            sta >write_patch1+1
                            sta >write_patch2+1
                            shortm
                            lda <patch_ptr+2
                            sta >write_patch1+3
                            sta >write_patch2+3
                            longm

                            rts
