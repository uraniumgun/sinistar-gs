
                            copy lib/source/debug.definitions.asm

                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.font.definitions.asm

                            mcopy generated/grlib.block.font.macros

                            longa on
                            longi on
;
; Font draw functions.
; Design thoughts.
; Based on the block draw functions, however, we know that we will usually be drawing multiple characters
; and they are small blocks, so the functions are geared toward drawing a line of characters, to amortize
; the setup overhead for each character block.  Also, because the 'runs' are small, usually 2 words wide
; maybe up to 4, the setup overhead for patching is rather high in the block draw.
;
; The initial functions do kinda support a variable width font, but there is not yet 'shifted' data, so
; the alignment is a bit off.

; -----------------------------------------------------------------------------
; Draw a string of characters using the current font
;
; Parameters:
; pString       - string to draw
; wX            - x location.
; wY            - y location.  This is at the baseline of the font.
grlib_set_active_font_ptr   start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_set_active_font_ptr'

                            begin_locals
work_area_size              end_locals

                            ssub (4:pFont),work_area_size

                            getword {s},#pFont
                            sta >grlib~active_font_ptr
                            tax
                            getword {s},#pFont+2
                            sta >grlib~active_font_ptr+2
                            tay

                            phd
                            lda >grlib~dp
                            tcd

                            txa
                            sta <grdp~font1+grlib~font_ptr
                            clc
                            adc #font_header~character_tables
                            sta <grdp~font1+grlib~font_character_tables_ptr
; Assuming we never cross a bank boundary
                            tya
                            sta <grdp~font1+grlib~font_ptr+2
                            sta <grdp~font1+grlib~font_character_tables_ptr+2
                            sta <grdp~font1+grlib~font_strike_ptr+2
                            sta <grdp~font1+grlib~font_odd_strike_ptr+2

; Strike pointers
                            getword [<grdp~font1+grlib~font_ptr],#font_header~strike_offset
                            clc
                            adc <grdp~font1+grlib~font_ptr
                            sta <grdp~font1+grlib~font_strike_ptr

                            getword [<grdp~font1+grlib~font_ptr],#font_header~odd_strike_offset
                            beq no_odd_strike
                            clc
                            adc <grdp~font1+grlib~font_ptr
no_odd_strike               sta <grdp~font1+grlib~font_odd_strike_ptr

                            getword [<grdp~font1+grlib~font_ptr],#font_header~char_pix_height
                            sta <grdp~font1+grlib~font_char_pix_height
                            getword [<grdp~font1+grlib~font_ptr],#font_header~row_bytes
                            sta <grdp~font1+grlib~font_strike_rowbytes
                            getword [<grdp~font1+grlib~font_ptr],#font_header~odd_row_bytes
                            sta <grdp~font1+grlib~font_odd_strike_rowbytes
                            getword [<grdp~font1+grlib~font_ptr],#font_header~mask_offset
                            sta <grdp~font1+grlib~font_strike_mask_offset
                            getword [<grdp~font1+grlib~font_ptr],#font_header~odd_mask_offset
                            sta <grdp~font1+grlib~font_odd_strike_mask_offset

                            pld

                            sret
                            end

; -----------------------------------------------------------------------------
; Draw a string of characters using the current font
;
; Parameters:
; pString       - string to draw
; wX            - x location.
; wY            - y location.  This is at the baseline of the font.
; Returns:
; x location after the last character in A
grlib_draw_string           start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_draw_string'

; Some DP values this function will use, in the grdp space
                            begin_struct grdp~caller_scratch_buffer
wX                          decl word
wY                          decl word
pString                     decl ptr
sizeof~locals               end_struct

                            begin_locals
work_area_size              end_locals

                            ssub (4:p~pString,2:p~wX,2:p~wY),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2
; We need to fill in some grlib DP values, but we have our own DP, so do them indirectly.
                            getptr {s},#p~pString+extra_stack,<pString
                            getword {s},#p~wX+extra_stack,<wX

; Draw the font from the baseline
                            getword {s},#p~wY+extra_stack
                            sec
                            sbcword [<grdp~font1+grlib~font_ptr],#font_header~ascent
                            sta <wY

loop                        lda [<pString]              ; Kinda terrible, we will be reading off the edge.
                            and #$FF
                            beq done
                            jsr _draw_char
                            inc <pString                ; Assuming we won't cross a bank boundary
                            bra loop

done                        anop
                            lda <wX                     ; return in a
                            pld

                            sret 2:A
                            end

; -----------------------------------------------------------------------------
; Draw a string of characters using the current font,
; centered within a range
;
; Parameters:
; pString       - string to draw
; wX            - left edge of the horizontal range
; wWidth        - width of the horizontal range
; wY            - y location.  This is at the baseline of the font.
; Returns:
; x location after the last character in A, line height in X
grlib_draw_string_centered  start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_draw_string_centered'

                            begin_locals
result                      decl long
work_area_size              end_locals

                            sub (4:pString,2:wX,2:wWidth,2:wY),work_area_size

                            pushptr <pString
                            jsl grlib_get_string_pixel_size
                            stx <result+2
                            negate a
                            clc
                            adc <wWidth
                            asr_nt 1
                            clc
                            adc <wX
                            sta <wX

                            pushptr <pString
                            pushsword <wX
                            pushsword <wY
                            jsl grlib_draw_string
                            sta <result

                            ret 4:result
                            end

; -----------------------------------------------------------------------------
; Draw a single character using the current font
;
; Parameters:
; wChar         - character to draw
; wX            - x location.
; wY            - y location.  This is at the baseline of the font.
; Returns:
; x location after the last character in A
grlib_draw_char             start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_draw_string'

; Some DP values this function will use, in the grdp space
                            begin_struct grdp~caller_scratch_buffer
wX                          decl word
wY                          decl word
wChar                       decl word
sizeof~locals               end_struct

                            begin_locals
work_area_size              end_locals

                            ssub (2:p~wChar,2:p~wX,2:p~wY),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2
; We need to fill in some grlib DP values, but we have our own DP, so do them indirectly.
                            getword {s},#p~wChar+extra_stack,<wChar
                            getword {s},#p~wX+extra_stack,<wX

; Draw the font from the baseline
                            getword {s},#p~wY+extra_stack
                            sec
                            sbcword [<grdp~font1+grlib~font_ptr],#font_header~ascent
                            sta <wY

                            lda <wChar
                            and #$FF
                            beq done
                            jsr _draw_char

done                        anop
                            lda <wX                     ; return in a
                            pld

                            sret 2:A
                            end

; -----------------------------------------------------------------------------
; Get the pixel size of a string with the current active font
;
; Parameters:
; pString       - string to test
; Returns:
; Pixel width in A, pixel height in X
grlib_get_string_pixel_size start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_string_pixel_size'

; Some DP values this function will use, in the grdp space
                            begin_struct grdp~caller_scratch_buffer
wX                          decl word
wY                          decl word
pString                     decl ptr
sizeof~locals               end_struct

                            begin_locals
work_area_size              end_locals

                            ssub (4:p~pString),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2
; We need to fill in some grlib DP values, but we have our own DP, so do them indirectly.
                            getptr {s},#p~pString+extra_stack,<pString
                            stz <wX
; Get the height of the font
                            getword [<grdp~font1+grlib~font_ptr],#font_header~ascent
                            sta <wY

loop                        lda [<pString]              ; Kinda terrible, we will be reading off the edge.
                            and #$FF
                            beq done
                            jsr _advance_char_width
                            inc <pString                ; Assuming we won't cross a bank boundary
                            bra loop

done                        anop
                            lda <wX                     ; return width in a
                            ldx <wY                     ; return height in x
                            pld

                            sret 4:AX
                            end

; -----------------------------------------------------------------------------
; Draw a 32bit BCD number, left to right
;
; Parameters:
; dwValue       - the bcd value to draw
; wX            - x location.
; wY            - y location.  This is at the baseline of the font.
; Returns:
; x location after the last character in A
grlib_draw_bcd32            start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_draw_bcd32'

; Some DP values this function will use, in the grdp space
                            begin_struct grdp~caller_scratch_buffer
wX                          decl word
wY                          decl word
dwValue                     decl long
                            end_struct

                            begin_locals
work_area_size              end_locals

                            ssub (4:p~dwValue,2:p~wX,2:p~wY),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2
; We need to fill in some grlib DP values, but we have our own DP, so do them indirectly.
                            getword {s},#p~wX+extra_stack,<wX

; Draw the font from the baseline
                            getword {s},#p~wY+extra_stack
                            sec
                            sbcword [<grdp~font1+grlib~font_ptr],#font_header~ascent
                            sta <wY

; Figure out how many digits there are
                            getword {s},#p~dwValue+2+extra_stack
                            sta <dwValue+2
                            beq four_or_fewer
                            ldx #8
                            bit #$f000
                            bne got_count_high
                            dex
                            bit #$0f00
                            bne got_count_high
                            dex
                            bit #$00f0
                            bne got_count_high
                            dex
got_count_high              anop
                            getword {s},#p~dwValue+extra_stack
                            sta <dwValue
                            bra got_count_low

four_or_fewer               anop
                            ldx #1                  ; assume 1 digit, in case we have a value of 0.  May want to support drawing nothing if the caller asks for it.
                            getword {s},#p~dwValue+extra_stack
                            sta <dwValue
                            beq got_count_low
                            ldx #4
                            bit #$f000
                            bne got_count_low
                            dex
                            bit #$0f00
                            bne got_count_low
                            dex
                            bit #$00f0
                            bne got_count_low
                            dex

got_count_low               txa
; future addition, might be to have a minimum digit count passed in.
                            asl a
                            tax
                            beq done                ; support having 0 drawn digits.
                            jsr (digits_table,x)

done                        anop
                            lda <wX                     ; return in a
                            pld

                            sret 2:A

digits_table                dc a2'one'              ; not used
                            dc a2'one'
                            dc a2'two'
                            dc a2'three'
                            dc a2'four'
                            dc a2'five'
                            dc a2'six'
                            dc a2'seven'
                            dc a2'eight'

eight                       anop
                            lda <dwValue+3
                            shiftright 4
                            and #$0F
                            clc
                            adc #'0'
                            jsr _draw_char

seven                       anop
                            lda <dwValue+3
                            and #$0F
                            clc
                            adc #'0'
                            jsr _draw_char

six                         anop
                            lda <dwValue+2
                            shiftright 4
                            and #$0F
                            clc
                            adc #'0'
                            jsr _draw_char

five                        anop
                            lda <dwValue+2
                            and #$0F
                            clc
                            adc #'0'
                            jsr _draw_char

four                        anop
                            lda <dwValue+1
                            shiftright 4
                            and #$0F
                            clc
                            adc #'0'
                            jsr _draw_char

three                       anop
                            lda <dwValue+1
                            and #$0F
                            clc
                            adc #'0'
                            jsr _draw_char

two                         anop
                            lda <dwValue
                            shiftright 4
                            and #$0F
                            clc
                            adc #'0'
                            jsr _draw_char

one                         anop
                            lda <dwValue
                            and #$0F
                            clc
                            adc #'0'
                            jmp _draw_char

                            end


; -----------------------------------------------------------------------------
; Draw a 32bit BCD number, starting at the right and going left
;
; Parameters:
; dwValue       - the bcd value to draw
; wX            - x location.
; wY            - y location.  This is at the baseline of the font.
; Returns:
; x location after the last character in A
grlib_draw_bcd32_right      start seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_draw_bcd32_right'

; Some DP values this function will use, in the grdp space
                            begin_struct grdp~caller_scratch_buffer
wX                          decl word
wY                          decl word
dwValue                     decl long
                            end_struct

                            begin_locals
work_area_size              end_locals

                            ssub (4:p~dwValue,2:p~wX,2:p~wY),work_area_size

; Switch the the grlib DP
                            phd
                            lda >grlib~dp
                            tcd

; to cover the stack usage above
extra_stack                 equ 2
; We need to fill in some grlib DP values, but we have our own DP, so do them indirectly.
                            getword {s},#p~wX+extra_stack,<wX

; Draw the font from the baseline
                            getword {s},#p~wY+extra_stack
                            sec
                            sbcword [<grdp~font1+grlib~font_ptr],#font_header~ascent
                            sta <wY

; Figure out how many digits there are
                            getword {s},#p~dwValue+2+extra_stack
                            sta <dwValue+2
                            beq four_or_fewer
                            ldx #8
                            bit #$f000
                            bne got_count_high
                            dex
                            bit #$0f00
                            bne got_count_high
                            dex
                            bit #$00f0
                            bne got_count_high
                            dex
got_count_high              anop
                            getword {s},#p~dwValue+extra_stack
                            sta <dwValue
                            bra got_count_low

four_or_fewer               anop
                            ldx #1                  ; assume 1 digit, in case we have a value of 0.  May want to support drawing nothing if the caller asks for it.
                            getword {s},#p~dwValue+extra_stack
                            sta <dwValue
                            beq got_count_low
                            ldx #4
                            bit #$f000
                            bne got_count_low
                            dex
                            bit #$0f00
                            bne got_count_low
                            dex
                            bit #$00f0
                            bne got_count_low
                            dex

got_count_low               txa
; future addition, might be to have a minimum digit count passed in.
                            asl a
                            tax
                            beq done                ; support having 0 drawn digits.
                            jsr (digits_table,x)

done                        anop
                            lda <wX                 ; return in a
                            pld

                            sret 2:A

digits_table                dc a2'one'              ; not used
                            dc a2'one'
                            dc a2'two'
                            dc a2'three'
                            dc a2'four'
                            dc a2'five'
                            dc a2'six'
                            dc a2'seven'
                            dc a2'eight'

one                         anop
; 1
                            lda <dwValue
                            and #$0F
                            jmp _draw_digit_right

two                         anop
; 1
                            lda <dwValue
                            and #$0F
                            jsr _draw_digit_right
; 2
                            lda <dwValue
                            shiftright 4
                            and #$0F
                            jmp _draw_digit_right

three                       anop
; 1
                            lda <dwValue
                            and #$0F
                            jsr _draw_digit_right
; 2
                            lda <dwValue
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 3
                            lda <dwValue+1
                            and #$0F
                            jmp _draw_digit_right

four                        anop
; 1
                            lda <dwValue
                            and #$0F
                            jsr _draw_digit_right
; 2
                            lda <dwValue
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 3
                            lda <dwValue+1
                            and #$0F
                            jsr _draw_digit_right
; 4
                            lda <dwValue+1
                            shiftright 4
                            and #$0F
                            jmp _draw_digit_right

five                        anop
; 1
                            lda <dwValue
                            and #$0F
                            jsr _draw_digit_right
; 2
                            lda <dwValue
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 3
                            lda <dwValue+1
                            and #$0F
                            jsr _draw_digit_right
; 4
                            lda <dwValue+1
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 5
                            lda <dwValue+2
                            and #$0F
                            jmp _draw_digit_right

six                         anop
; 1
                            lda <dwValue
                            and #$0F
                            jsr _draw_digit_right
; 2
                            lda <dwValue
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 3
                            lda <dwValue+1
                            and #$0F
                            jsr _draw_digit_right
; 4
                            lda <dwValue+1
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 5
                            lda <dwValue+2
                            and #$0F
                            jsr _draw_digit_right
; 6
                            lda <dwValue+2
                            shiftright 4
                            and #$0F
                            jmp _draw_digit_right

seven                       anop
; 1
                            lda <dwValue
                            and #$0F
                            jsr _draw_digit_right
; 2
                            lda <dwValue
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 3
                            lda <dwValue+1
                            and #$0F
                            jsr _draw_digit_right
; 4
                            lda <dwValue+1
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 5
                            lda <dwValue+2
                            and #$0F
                            jsr _draw_digit_right
; 6
                            lda <dwValue+2
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 7
                            lda <dwValue+3
                            and #$0F
                            jmp _draw_digit_right

eight                       anop
; 1
                            lda <dwValue
                            and #$0F
                            jsr _draw_digit_right
; 2
                            lda <dwValue
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right

; 3
                            lda <dwValue+1
                            and #$0F
                            jsr _draw_digit_right
; 4
                            lda <dwValue+1
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right
; 5
                            lda <dwValue+2
                            and #$0F
                            jsr _draw_digit_right
; 6
                            lda <dwValue+2
                            shiftright 4
                            and #$0F
                            jsr _draw_digit_right

; 7
                            lda <dwValue+3
                            and #$0F
                            jsr _draw_digit_right
; 8
                            lda <dwValue+3
                            shiftright 4
                            and #$0F
                            jmp _draw_digit_right

                            end

; -----------------------------------------------------------------------------
; Draw one character, using grdp~font1
; Expects:
; The character in A
; The DP to be set to the grlib_dp
; dp~wX and dp~wY to be in the grdp scratch space

_draw_char                  private seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_draw_char'

; Carry over equates. Just the ones we use though, which are assumed to be at the top
                            begin_struct grdp~caller_scratch_buffer
wX                          decl word
wY                          decl word
                            end_struct

                            asl a                   ; char code in a, double it.  This will clear the carry for us too.
                            tax
;                           clc
;                           adc #font_table~strike_widths       ; This is 0
                            tay
                            lda [<grdp~font1+grlib~font_character_tables_ptr],y
                            beq invalid_char
                            sta <shape_width

; Set the draw x
                            txa                                     ; 2
;                           clc                                     ; 2 this is already clear
                            adc #font_table~character_offsets       ; 3
                            tay                                     ; 2
                            lda [<grdp~font1+grlib~font_character_tables_ptr],y
                            clc
                            adc <wX
                            sta <draw_x
                            bit #$0001
                            beq even

; Set the pointer to the strike 'shape'

; Odd
                            txa
;                           clc                                     ; carry should already be clear
                            adc #font_table~odd_strike_byte_offsets
                            tay
                            lda <grdp~font1+grlib~font_odd_strike_ptr
                            beq even                                        ; no odd strike
;                           clc                                     ; carry should already be clear
                            adc [<grdp~font1+grlib~font_character_tables_ptr],y
                            sta <shape_ptr
                            lda <grdp~font1+grlib~font_odd_strike_ptr+2
                            sta <shape_ptr+2                                ; not going to cross the bank boundary, just putting the high word in the pointer

                            lda <grdp~font1+grlib~font_odd_strike_rowbytes
                            sta <shape_rowbytes
                            lda <grdp~font1+grlib~font_odd_strike_mask_offset
                            sta <mask_offset

                            inc <shape_width                                ; add one pixel to compensate for the 'shift'
                            bra was_odd
; Even
even                        anop
                            txa
;                           clc                                     ; carry should already be clear
                            adc #font_table~strike_byte_offsets
                            tay
                            lda <grdp~font1+grlib~font_strike_ptr
;                           clc                                     ; carry should already be clear
                            adc [<grdp~font1+grlib~font_character_tables_ptr],y
                            sta <shape_ptr
                            lda <grdp~font1+grlib~font_strike_ptr+2
                            sta <shape_ptr+2                                ; not going to cross the bank boundary, just putting the high word in the pointer

                            lda <grdp~font1+grlib~font_strike_rowbytes
                            sta <shape_rowbytes
                            lda <grdp~font1+grlib~font_strike_mask_offset
                            sta <mask_offset

was_odd                     anop
; Advance the cursor.
                            txa
;                           clc                                     ; carry should already be clear
                            adc #font_table~character_advances
                            tay
                            lda [<grdp~font1+grlib~font_character_tables_ptr],y
;                           clc                                     ; carry should already be clear
                            adc <wX
                            sta <wX
; Set the draw Y
                            lda <wY
                            sta <draw_y

; Do these have to be done per character draw?
                            lda <grdp~font1+grlib~font_char_pix_height
                            sta <shape_height

                            jsl _block_font_draw                        ; In the same file but a difference segment

invalid_char                anop
                            rts

; Code below here doesn't compile
; This is some musing on how to get the characters to draw quicker.
                            ago .skip
_draw_char_8                anop

; Composite a colorized word of a font foreground, with a destination buffer
; 23 bytes
; Blit 2
                            lda |src,y                      ; 6, get the source
                            eor #$ffff                      ; 3, make a mask.  could eliminate with a pre-generated mask
                            and >dest,x                     ; 6, and with the dest
                            sta <temp                       ; 4, temp store
                            lda |src,y                      ; 6, get the source, again
                            and <fore_color                 ; 4, colorize it. could make this an immedate and patch, but patching overhead would eat at the 1 cycle savings
                            ora <temp                       ; 4, merge with dest
                            sta >dest,x                     ; 6, store on dest

; Colorize a word of a font's foreground and background and store in a destination buffer
; 21 bytes
; Blit 3
                            lda |src,y                      ; 6, get the source
                            eor #$ffff                      ; 3, make a mask.  could eliminate with a pre-generated mask
                            and <back_color                 ; 4, colorize the background
                            sta <temp                       ; 4, temp store
                            lda |src,y                      ; 6, get the source, again
                            and <fore_color                 ; 4, colorize it.
                            ora <temp                       ; 4, merge with background
                            sta >dest,x                     ; 6, store on dest

; Colorize a word of a font's foreground, leaving the background as 0, and store in a destination buffer
; 9 Bytes
; Blit 1
                            lda |src,y                      ; 6, get the source, again
                            and <fore_color                 ; 4
                            sta >dest,x                     ; 6, store on dest

; Merge the source with the dest, through a mask
; This requires the mask load, to be patched, per draw.
; It does eliminate the need for 'edge' copy functions, as the edges are dealt with through the mask.
; 14 bytes
; Blit 4
                            lda |mask,y                     ; 6, get the mask
                            and >dest,x                     ; 6, and with the dest
                            ora |src,y                      ; 6, merge the source
                            sta >dest,x                     ; 6, store on dest
; Merge the source with the dest, through a mask.
; The mask is inverted, and a test is made to see if the mask is 0, and the rest of the
; copy is skipped if so, because the mask would be $FFFF, meaning the destination would not change.
; Could potentially speed up shapes that had a lot of dead space.
; It adds 5 cycles to a copy, if it does the copy, but saves 15 over the non-tested copy
; function above, if it skips the copy.
; Seems like it would be advantageous if 1 in 3 copies where skipped.
; This requires the mask load, to be patched, per draw.
; 17 bytes
                            lda |mask,y                     ; 6, get the mask
                            beq next                        ; 2-3
                            eor #$ffff                      ; 3
                            and >dest,x                     ; 6, and with the dest
                            ora |src,y                      ; 6, merge the source
                            sta >dest,x                     ; 6, store on dest
next                        anop

; Some similar thoughts on the masked copy, but with the mask 'interleaved'
; with the data.  This has the advantage of not needing patching, per draw
; but has issues with clipping, in that we have to deal with the fact that
; the data would have alignment issues.  i.e. The offset in Y, would have to
; be even whenever we wanted to do word-sized copying.
; This could be done, but would add to the overhead of figuring out the alignment
; and then doing byte-sized copies in between, making the code more complex

; Composite a colorized word of a font foreground, with a destination buffer
; This version assumes there is an interleaved mask for the source.
; Has issues with clipping.
; 20 bytes
                            lda |src+2,y                    ; 6, get the mask
                            and >dest,x                     ; 6, and with the dest
                            sta <temp                       ; 4, temp store
                            lda |src,y                      ; 6, get the source
                            and <fore_color                 ; 4, colorize it. could make this an immedate and patch, but patching overhead would eat at the 1 cycle savings
                            ora <temp                       ; 4, merge with dest
                            sta >dest,x                     ; 6, store on dest

; Merge the source with the dest, through a mask that is interleaved
; Has issues with clipping.
; 14 bytes
                            lda |src+2,y                    ; 6, get the mask
                            and >dest,x                     ; 6, and with the dest
                            ora |src,y                      ; 6, merge the source
                            sta >dest,x                     ; 6, store on dest
; Merge the source with the dest, through a mask that is interleaved.
; This assumes the mask is inverted, and if it is 0, it skips drawing
; Has issues with clipping.
; 17 bytes
                            lda |src+2,y                    ; 6, get the mask
                            beq next                        ; 2-3
                            eor #$ffff                      ; 3
                            and >dest,x                     ; 6, and with the dest
                            ora |src,y                      ; 6, merge the source
                            sta >dest,x                     ; 6, store on dest
next                        anop

.skip
                            end

; -----------------------------------------------------------------------------
; Draw one digit, right justified, using grdp~font1
; Expects:
; The digit in A (0 - 9)
; The DP to be set to the grlib_dp
; wX and wY to be in the grdp scratch space
; The input wX is assumed to be the right edge and the digit will be drawn
; to the left of it and advance the cursor to the left.

_draw_digit_right           private seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_draw_digit_right'

; Carry over equates. Just the ones we use though, which are assumed to be at the top
                            begin_struct grdp~caller_scratch_buffer
wX                          decl word
wY                          decl word
                            end_struct

; This is just a copy of _draw_char.  I would hope we could make something a bit faster, because we have a
; limited range of characters to choose from.

                            clc
                            adc #'0'
                            asl a                   ; char code in a, double it.  This will clear the carry for us too.
                            tax
;                           clc
;                           adc #font_table~strike_widths               ; this is 0
                            tay
                            lda [<grdp~font1+grlib~font_character_tables_ptr],y
                            beq invalid_char
                            sta <shape_width

; Adjust the cursor to the left
                            txa
;                           clc                                     ; carry should already be clear
                            adc #font_table~character_advances
                            tay
                            lda <wX
                            sec
                            sbc [<grdp~font1+grlib~font_character_tables_ptr],y
                            sta <wX
; Set the draw x
                            txa
                            clc
                            adc #font_table~character_offsets
                            tay
                            lda <wX
;                           clc                                     ; carry should already be clear
                            adc [<grdp~font1+grlib~font_character_tables_ptr],y
                            sta <draw_x
                            bit #$0001
                            beq even
; Odd
                            txa
;                           clc                                     ; carry should already be clear
                            adc #font_table~odd_strike_byte_offsets
                            tay
                            lda <grdp~font1+grlib~font_odd_strike_ptr
                            beq even                                        ; no odd strike
;                           clc                                     ; carry should already be clear
                            adc [<grdp~font1+grlib~font_character_tables_ptr],y
                            sta <shape_ptr
                            lda <grdp~font1+grlib~font_odd_strike_ptr+2
                            sta <shape_ptr+2                                ; not really going to cross the bank boundary, just puttting the high word in the pointer

                            lda <grdp~font1+grlib~font_odd_strike_rowbytes
                            sta <shape_rowbytes
                            lda <grdp~font1+grlib~font_odd_strike_mask_offset
                            sta <mask_offset

                            inc <shape_width                                ; add one pixel to compensate for the 'shift'
                            bra was_odd
; Even
even                        anop
                            txa
;                           clc                                     ; carry should already be clear
                            adc #font_table~strike_byte_offsets
                            tay
                            lda <grdp~font1+grlib~font_strike_ptr
;                           clc                                     ; carry should already be clear
                            adc [<grdp~font1+grlib~font_character_tables_ptr],y
                            sta <shape_ptr
                            lda <grdp~font1+grlib~font_strike_ptr+2
                            sta <shape_ptr+2                                ; not going to cross the bank boundary, just putting the high word in the pointer

                            lda <grdp~font1+grlib~font_strike_rowbytes
                            sta <shape_rowbytes
                            lda <grdp~font1+grlib~font_strike_mask_offset
                            sta <mask_offset
was_odd                     anop
; Set the draw Y
                            lda <wY
                            sta <draw_y

; Do these have to be done per character draw?
                            lda <grdp~font1+grlib~font_char_pix_height
                            sta <shape_height

                            jsl _block_font_draw                        ; In the same file but a different segment

invalid_char                anop
                            rts
                            end

; -----------------------------------------------------------------------------
; Advance dp~wX by the width of a character, using grdp~font1
; Expects:
; The character in A
; The DP to be set to the grlib_dp
; dp~wX to be in the grdp scratch space

_advance_char_width         private seg_grlib

                            using grlib_global_equates
                            using grlib_global_data

                            debugtag '_advance_char_width'

; Carry over equates. Just the ones we use though, which are assumed to be at the top
                            begin_struct grdp~caller_scratch_buffer
wX                          decl word
wY                          decl word
                            end_struct

                            asl a                   ; char code in a, double it.  This will clear the carry for us too.
                            tax
;                           clc
;                           adc #font_table~strike_widths       ; This is 0
                            tay
                            lda [<grdp~font1+grlib~font_character_tables_ptr],y
                            beq invalid_char

; Advance the cursor.
                            txa
;                           clc                                     ; carry should already be clear
                            adc #font_table~character_advances
                            tay
                            lda [<grdp~font1+grlib~font_character_tables_ptr],y
;                           clc                                     ; carry should already be clear
                            adc <wX
                            sta <wX

invalid_char                anop
                            rts
                            end

;------------------------------------------------------------------------------
; Draw a character in a block font.
; This will clip against the global clip rect
; Assumes the DP is already set to the grlib DP
;
; Parameter:
; <shape_ptr        - pointer to the font data
; <shape_width      - Pixel width of the characatrer
; <shape_height     - Pixel height of the characer
; <draw_x           - draw location x
; <draw_y           - draw location y
_block_font_draw            start seg_grlib_blit            ; note, same segment as the blit functions
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_block_shape_jmps
                            using math_tables

                            debugtag '_block_font_draw'
; Hmm, I 'know' that the DP is correct, however, the jmps into the blit tables, have an assumed DP and databank on the stack.
; I should probably get rid of those.
                            phd
;                           lda >grlib~dp
;                           tcd

                            setlocaldatabank

                            stz |data_has_left_edge

                            lda <shape_width
                            sta <area_width
                            lsr a
                            adc #0
                            sta <shape_byte_width

                            lda <shape_height
                            sta <area_height

; Clip the rect that is defined by <draw_x, <draw_y, <area_width, <area_height
                            jsl _clip_shape_coords
                            bcs exit

; Clipping will have set, shape_x_offset and shape_y_offset
                            lda <shape_y_offset
                            beq no_y_indent
; Multiply the byte width * the offset
;                            ldx <shape_rowbytes
;                            jsl math~umul1r2
                            inline~umul1r2 <shape_rowbytes,Y
                            clc
                            adc <shape_ptr
                            sta <shape_ptr

no_y_indent                 lda <shape_x_offset
                            beq no_x_indent
                            lsr a
                            adc #0                                       ; round up
                            adc <shape_ptr
                            sta <shape_ptr

no_x_indent                 lda |data_has_left_edge
                            bne has_left_edge
; Data has no left edge, how about the right?
                            lda <shape_width
                            bit #1
                            beq no_left_or_right_edge
                            sec
                            sbc <shape_x_offset
                            cmp <area_width
                            beq has_right_edge
;                           blt has_right_edge                          ; Shoudn't be possible to be less
; No left or right edge
no_left_or_right_edge       anop
                            ldx <font_blit_func
                            jmp (wb_jmps,x)
;                           jsr _altscr_block_shape_blit_1_wb_unrolled
exit                        anop
                            restoredatabank
                            pld
                            rtl

; Draw using a function that supports right edges
has_right_edge              anop
                            ldx <font_blit_func
                            jmp (re_jmps,x)
;                           jsr _altscr_block_shape_blit_1_re_unrolled
;                           restoredatabank
;                           pld
;                           rtl

; If we are using odd pixel data, then we have a left edge to deal with
has_left_edge               anop
                            lda <shape_x_offset
                            bne clipped_left                            ; did we clip the left?
; shape_x_offset is 0, so we have a left edge, and it wasn't clipped
                            lda <shape_width                            ; in pixels
                            bit #1
                            bne just_left_edge                          ; if the width is *odd*, we have no right edge. We only have left and right edges with even pixel data
                            cmp <area_width                             ; We didn't clip on the left, so if the <area_width is not equal to the <shape_width, we clipped on the right
                            bne just_left_edge

; Draw using a function that a left and right edge
                            ldx <font_blit_func
                            jmp (lre_jmps,x)
;                           jsr _altscr_block_shape_blit_1_lre_unrolled
;                           restoredatabank
;                           pld
;                           rtl

just_left_edge              anop
; Draw using a function that a left edge
                            ldx <font_blit_func
                            jmp (le_jmps,x)
;                           jsr _altscr_block_shape_blit_1_le_unrolled
;                           restoredatabank
;                           pld
;                           rtl

; Clipped the left edge, so we can igonore that, but we may still have right edge
clipped_left                anop
                            lda <shape_width                            ; in pixels
                            bit #1
                            bne clipped_left_and_no_right               ; if the width is *odd*, we have no right edge. We only have left and right edges with even pixel data
                            sec
                            sbc <shape_x_offset
                            cmp <area_width
                            beq has_right_edge                          ; If equal to, we didn't clip, so the right edge is there.
;                           blt has_right_edge                          ; Shouldn't be possible to be less.

; Clipped the right edge, so just whole bytes
                            ldx <font_blit_func
                            jmp (wb_jmps,x)
;                           jsr _altscr_block_shape_blit_1_wb_unrolled
;                           restoredatabank
;                           pld
;                           rtl

clipped_left_and_no_right   anop
                            dec <area_width                             ; We are taking one off the width, because the original <shape_width was odd, meaning the odd-shifted data didn't result in more bytes
                            ldx <font_blit_func
                            jmp (wb_jmps,x)
;                           jsr _altscr_block_shape_blit_1_wb_unrolled
;                           restoredatabank
;                           pld
;                           rtl
data_has_left_edge          ds 2
                            end

