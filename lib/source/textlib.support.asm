                            copy lib/source/debug.definitions.asm
                            mcopy generated/textlib.support.macros

                            longa on
                            longi on

even_col_text_bank          gequ $e10000
odd_col_text_bank           gequ $e00000

; I was thinking about using a buffered screen, but didn't complete the code for this.
; Text is just printed directly to the screen buffers
;textlib~use_buffered_screen gequ 1

; gequ, so the value evaluation is immediate, this helps with the getword macros, where it is tries to figure out if it can use [p] vs. [p],y
textbox_column_layout~width gequ 0
textbox_column_layout~type  gequ textbox_column_layout~width+2
textbox_column_layout~ptr   gequ textbox_column_layout~type+2
sizeof~textbox_column_layout gequ textbox_column_layout~ptr+4

; -----------------------------------------------------------------------------
; Library for writing to the 80-column text screen.
; Not the speediest pile of functions.  They are intended for debug display only.
;
; When writing characters to the directly to the screen, or the primary buffer
; the functions will use a 'text cursor', defined by:
; textbox_primary~cursor_x
; textbox_primary~cursor_y

; And a bounds, defined by:
; textbox_primary~left
; textbox_primary~top
; textbox_primary~right
; textbox_primary~right
;
; The cursor is allowed to be == to either the right or the bottom
; in which case, no writing will occur.
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; Initialize the textlib support
; Note, we are expecting the textlib system to handle error display,
; meaning this is started up very early and should not allocate memory,
; as the memory manager might not even be setup yet.
textlib_initilize           start seg_txtlib
                            using textlib_global_data

                            debugtag 'initilize'
                            debugtag 'textlib'

                            aif C:textlib~use_buffered_screen=0,.skip
                            begin_locals
pBuffer                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size
.skip

                            setlocaldatabank

                            jsl textbox_clear_options

                            stz textbox_primary~left
                            stz textbox_primary~top
                            lda #80
                            sta textbox_primary~right
                            lda #24
                            sta textbox_primary~bottom

; I had ideas of using linear buffer, to 'print' to, then copying to the interleaved screen buffer, but I punted.
                           aif C:textlib~use_buffered_screen=0,.skip

                            lda #(80*24)
                            sta textbox_primary~size
                            jsl allocate_fixed_handle
                            putretptr textbox_primary~buffer_handle
                            putretptr <pBuffer
                            lda [<pBuffer]
                            sta textbox_primary~buffer_ptr
                            ldy #2
                            lda [<pBuffer],y
                            sta textbox_primary~buffer_ptr+2

                            jsl textbox_clear_primary_buffer
.skip
                            restoredatabank

                            aif C:textlib~use_buffered_screen=0,.skip
                            ret
.skip
                            rtl
                            end

; -----------------------------------------------------------------------------
; Uninitialize the textlib
textlib_uninitilize         start seg_txtlib
                            using textlib_global_data

                            debugtag 'uninitilize'
                            debugtag 'textlib'

                            aif C:textlib~use_buffered_screen=0,.skip
                            setlocaldatabank
                            lda textbox_primary~buffer_handle
                            ldx textbox_primary~buffer_handle+2
                            jsl deallocate_fixed_handle
                            restoredatabank
.skip
                            rtl
                            end
; -----------------------------------------------------------------------------
; Set options for the textbox.
; Parameters:
;   bit flag options in the accumulator
;   textbox_option~normal       - turn on normal text
;   textbox_option~inverse      - turn on inverse text
;   textbox_option~no_line_fill - turn off fill to the end of line.
;   textbox_option~line_fill    - turn on fill to the end of line.
;
; Note that some bits are mutually exclusive, and you should have one or none of the pair on
; If one is on, the that option is set, if none are on, then that pair's funcitonality is
; left alone.
textbox_set_options         start seg_txtlib
                            using textlib_global_data

                            debugtag 'set_options'
                            setlocaldatabank

                            tay
                            bit #textbox_option~inverse
                            beq no_inverse                  ; No inverse specified, this does not mean we clear it
                            lda #char_modifier~inverse
                            sta textbox_primary~char_modifier
                            tya
                            bra check_fill

no_inverse                  bit #textbox_option~normal
                            beq check_fill
                            stz textbox_primary~char_modifier

check_fill                  bit #textbox_option~line_fill
                            beq no_line_fill
                            lda #$ffff                      ; set all the bits, so we can just do a bit to test
                            sta textbox_primary~option_line_fill
                            tya
                            bra exit

no_line_fill                bit #textbox_option~no_line_fill
                            beq exit
                            stz textbox_primary~option_line_fill

exit                        restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set individual options for the textbox, just to be quick about it.

; -----------------------------------------------------------------------------
; Set text to inverse
textbox_set_option_inverse  start seg_txtlib
                            using textlib_global_data

                            debugtag 'set_inverse'

                            lda #char_modifier~inverse
                            sta >textbox_primary~char_modifier
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set text to normal
textbox_set_option_normal   start seg_txtlib
                            using textlib_global_data

                            debugtag 'set_normal'

                            lda #0
                            sta >textbox_primary~char_modifier
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set text to auto-fill
textbox_set_option_fill     start seg_txtlib
                            using textlib_global_data

                            debugtag 'set_fill'

                            lda #$ffff
                            sta >textbox_primary~option_line_fill
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set text to auto-fill
textbox_set_option_no_fill  start seg_txtlib
                            using textlib_global_data

                            debugtag 'set_no_fill'

                            lda #0
                            sta >textbox_primary~option_line_fill
                            rtl
                            end

; -----------------------------------------------------------------------------
; Clear options for the textbox, to the defaults.
textbox_clear_options       start seg_txtlib
                            using textlib_global_data

                            debugtag 'clear_options'
                            setlocaldatabank

                            stz textbox_primary~char_modifier
                            stz textbox_primary~option_line_fill

                            restoredatabank
                            rtl
                            end
; -----------------------------------------------------------------------------
; Clear the entire primary buffer
                            aif C:textlib~use_buffered_screen=0,.skip
textbox_clear_primary_buffer start seg_txtlib
                            using textlib_global_data

                            begin_locals
pBuffer                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            lda >textbox_primary~buffer_ptr
                            sta <pBuffer
                            lda >textbox_primary~buffer_ptr+2
                            sta <pBuffer+2

                            lda >textbox_primary~size
                            tay
                            dey
                            dey
                            lda #vidchar~space+(vidchar~space|8)
loop                        sta [<pBuffer],y
                            dey
                            dey
                            bpl loop
                            ret
                            end
.skip

; -----------------------------------------------------------------------------
; Reset the textbox size to the full screen
textbox_reset_size          start seg_txtlib
                            using textlib_global_data

                            debugtag 'reset_size'

                            setlocaldatabank
                            stz textbox_primary~left
                            stz textbox_primary~top
                            lda #80
                            sta textbox_primary~right
                            lda #24
                            sta textbox_primary~bottom
                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the textbox cursor
; The input will be clamped to the textbox bounds.
; Parameters:
; wX        - x cursor position
; wY        - y cursor position.
textbox_set_cursor          start seg_txtlib
                            using textlib_global_data

                            debugtag 'set_cursor'

                            begin_locals
work_area_size              end_locals

                            sub (2:wX,2:wY),work_area_size

                            lda <wX
                            cmp >textbox_primary~right
                            blt ok_right
                            lda >textbox_primary~right
ok_right                    cmp >textbox_primary~left
                            bge ok_left
                            lda >textbox_primary~left
ok_left                     sta >textbox_primary~cursor_x

                            lda <wY
                            cmp >textbox_primary~bottom
                            blt ok_bottom
                            lda >textbox_primary~bottom
ok_bottom                   cmp >textbox_primary~top
                            bge ok_top
                            lda >textbox_primary~top
ok_top                      sta >textbox_primary~cursor_y
                            ret
                            end

; -----------------------------------------------------------------------------
; Set the bounds of the textbox
; The input will be clamped to the screen max.
; The cursor will be set to the top-left
; Passing in the bounds as an x/y,width,height rect
; Parameters:
; wX        - x left
; wY        - y top
; wWidth    - width of box
; wHeight   - height of box
textbox_set_bounds          start seg_txtlib
                            using textlib_global_data

                            debugtag 'set_bounds'

                            begin_locals
work_area_size              end_locals

                            sub (2:wX,2:wY,2:wWidth,2:wHeight),work_area_size

                            setlocaldatabank

                            lda <wX
                            bpl ok_left
                            lda #0
ok_left                     cmp #80
                            blt ok_right
                            lda #79
ok_right                    sta textbox_primary~left
                            sta textbox_primary~cursor_x
                            clc
                            adc <wWidth
                            cmp #81
                            blt ok_width
                            lda #80
ok_width                    sta textbox_primary~right

                            lda <wY
                            bpl ok_top
                            lda #0
ok_top                      cmp #24
                            blt ok_bottom
                            lda #23
ok_bottom                   sta textbox_primary~top
                            sta textbox_primary~cursor_y
                            clc
                            adc <wHeight
                            cmp #25
                            blt ok_height
                            lda #24
ok_height                   sta textbox_primary~bottom

                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; This will set the textbox as a column, from the current bounds.
; This will essentially, just set the textbox_primary~right, to
; textbox_primary~left + width.
; This will reset the cursor to the left
; Parameters:
; wWidth    - width of new column
textbox_set_column          start seg_txtlib
                            using textlib_global_data

                            debugtag 'set_column'

                            begin_locals
work_area_size              end_locals

                            sub (2:wWidth),work_area_size

                            lda >textbox_primary~left
                            sta >textbox_primary~cursor_x
                            clc
                            adc <wWidth
                            cmp #80
                            blt ok
                            lda #80
ok                          sta >textbox_primary~right
                            ret
                            end

; -----------------------------------------------------------------------------
; Assuming that the textbox bounds is set as columns, make a new column of the given size
; The will assume that the current textbox_primary~right, is the end of the column
; and make the textbox_primary~left == textbox_primary~right, then make the new
; textbox_primary~right, textbox_primary~right + width;
; This will reset the cursor to the new left
; Parameters:
; wWidth    - width of new column
textbox_next_column         start seg_txtlib
                            using textlib_global_data

                            debugtag 'next_column'

                            begin_locals
work_area_size              end_locals

                            sub (2:wWidth),work_area_size
                            setlocaldatabank

; Fill to the end?
                            bit textbox_primary~option_line_fill
                            bpl no_fill
                            jsr internal_fill_to_end
no_fill                     anop

                            lda textbox_primary~right
                            sta textbox_primary~left
                            sta textbox_primary~cursor_x
                            clc
                            adc <wWidth
                            cmp #80
                            blt ok
                            lda #80
ok                          sta textbox_primary~right

                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; End column mode.  This will reset the left and right, back to the full width.
; TODO: Maybe keep track of what the left and right was before using columns,
; so we can restore?
textbox_end_columns         start seg_txtlib
                            using textlib_global_data

                            debugtag 'end_columns'

                            setlocaldatabank
; Fill to the end?
                            bit textbox_primary~option_line_fill
                            bpl no_fill
                            jsr internal_fill_to_end
no_fill                     anop

                            lda #0
                            sta textbox_primary~left
                            sta textbox_primary~cursor_x
                            lda #80
                            sta textbox_primary~right
                            restoredatabank

                            rtl
                            end

; -----------------------------------------------------------------------------
; Assuming that the textbox bounds is set as columns, advance to the next line
; and set the bounds textbox_primary~left to 0 and the textbox_primary~right to
; the given size.
; Note that this will not change the top / bottom of the bounds, it will
; move the cursor y to the next line
;
; Parameters:
; wWidth    - width of new column
; Returns carry set, if the y cursor is off the bottom
textbox_next_row_column     start seg_txtlib
                            using textlib_global_data

                            debugtag 'next_row_column'

                            begin_locals
work_area_size              end_locals

                            sub (2:wWidth),work_area_size
                            setlocaldatabank
; Fill to the end first?
                            bit textbox_primary~option_line_fill
                            bpl no_fill
                            jsr internal_fill_to_end
no_fill                     anop

                            lda #0
                            sta textbox_primary~left
                            sta textbox_primary~cursor_x
                            clc
                            adc <wWidth
                            cmp #80
                            blt ok_x
                            lda #80
ok_x                        sta textbox_primary~right

                            lda textbox_primary~cursor_y
                            inc a
                            cmp textbox_primary~bottom
                            bge off_bottom
                            sta textbox_primary~cursor_y
                            clc
exit                        restoredatabank
                            retkc

off_bottom                  lda textbox_primary~bottom
                            sta textbox_primary~cursor_y
                            sec
                            bra exit

                            end

; -----------------------------------------------------------------------------
; Go to the next row, and end any column mode
; Note that this will not change the top / bottom of the bounds, it will
; move the cursor y to the next line
;
; Returns carry set, if the y cursor is off the bottom
textbox_next_row_end_columns start seg_txtlib
                            using textlib_global_data

                            debugtag 'next_row_end_columns'

                            setlocaldatabank
; Setting the right edge back to full, first, so if we do erase, we will erase to the end of the screen.
; Might want to make this an option, or have this happen in a separate call, as we might not want to do this sometimes
; i.e. There is text to the right of the last column that we want to preserve, or we know it is clear and don't want to
; waste the time clearing it.
                            lda #80
                            sta textbox_primary~right
; Fill to the end first?
                            bit textbox_primary~option_line_fill
                            bpl no_fill
                            jsr internal_fill_to_end
no_fill                     anop

                            lda #0
                            sta textbox_primary~left
                            sta textbox_primary~cursor_x

                            lda textbox_primary~cursor_y
                            inc a
                            cmp textbox_primary~bottom
                            bge off_bottom
                            sta textbox_primary~cursor_y
                            restoredatabank
                            clc
                            rtl

off_bottom                  lda textbox_primary~bottom
                            sta textbox_primary~cursor_y
                            restoredatabank
                            sec
                            rtl

                            end

; -----------------------------------------------------------------------------
; Helper function to print a set of columns

; Parameters:
; pLayout   - pointer to the layout to print
;
; The layout is consists of an array of [width, type, pointer/data] entries
; The width, is the width of the column
; The type, is the type of pointer or data that follows
;  - type 0, no data
;  - type 1, string
;  - type 2, 16-bit data, display as hex
;  - type 3, 16-bit data, display as decimal
;  - type 4, pointer to 16-bit data, display as hex
;  - type 5, pointer to 16-bit data, display as decimal
;
; End the layout array, by having a column width of 0
textbox_print_columns       start seg_txtlib
                            using textlib_global_data

                            debugtag 'print_columns'

                            begin_locals
pValue                      decl ptr
work_area_size              end_locals

                            sub (4:pLayout),work_area_size
                            setlocaldatabank

                            getword [<pLayout],#textbox_column_layout~width
                            beq done
                            pha
                            jsl textbox_set_column
                            bra first

loop                        anop
                            getword [<pLayout],#textbox_column_layout~width
                            beq done
                            pha
                            jsl textbox_next_column

first                       getword [<pLayout],#textbox_column_layout~type
                            beq no_value
                            asl a
                            tax
                            jsr (print_funcs,x)
; Next entry (assuming all in the same bank)
no_value                    lda <pLayout
                            clc
                            adc #sizeof~textbox_column_layout
                            sta <pLayout
                            bra loop

done                        anop
                            jsl textbox_next_row_end_columns
                            restoredatabank
                            ret

print_none                  anop
                            rts

print_string                anop
                            pushptr [<pLayout],#textbox_column_layout~ptr
                            jsl textbox_print_string
                            rts

print_16bit_hex             anop
                            pushsword [<pLayout],#textbox_column_layout~ptr
                            jsl textbox_print_hex_word
                            rts

print_16bit_decimal         anop
                            pushsword [<pLayout],#textbox_column_layout~ptr
                            jsl textbox_print_hex_word
                            rts

print_ptr_16bit_hex         anop
                            getptr [<pLayout],#textbox_column_layout~ptr,<pValue
                            lda [<pValue]
                            pha
                            jsl textbox_print_hex_word
                            rts

print_ptr_16bit_decimal     anop
                            getptr [<pLayout],#textbox_column_layout~ptr,<pValue
                            lda [<pValue]
                            pha
                            jsl textbox_print_hex_word
                            rts

print_funcs                 dc a2'print_none'
                            dc a2'print_string'
                            dc a2'print_16bit_hex'
                            dc a2'print_16bit_decimal'
                            dc a2'print_ptr_16bit_hex'
                            dc a2'print_ptr_16bit_decimal'
                            end

; ----------------------------------------- ------------------------------------
; Move the cursor to the next line.
; The cursor y will be clamped to hight - 1.
; Cursor x will always be reset to 0
; Returns:
; carry clear, if the cursor y is on a printable line
; carry set, if the cursor y is off the bottom of the printable area.
textbox_newline             start seg_txtlib
                            using textlib_global_data

                            debugtag 'newline'

                            setlocaldatabank

; Fill to the end first?
                            bit textbox_primary~option_line_fill
                            bpl no_fill
                            jsr internal_fill_to_end
no_fill                     anop

                            lda textbox_primary~left
                            sta textbox_primary~cursor_x
                            lda textbox_primary~cursor_y
                            inc a
                            cmp textbox_primary~bottom
                            bge clamped
                            sta textbox_primary~cursor_y
                            clc
                            restoredatabank
                            rtl

clamped                     anop
                            lda textbox_primary~bottom
                            sta textbox_primary~cursor_y
                            restoredatabank
                            sec
                            rtl

                            end

; -----------------------------------------------------------------------------
; Print a string to the current textbox cursor location
; Parameters:
; pStr      - zero terminated ascii string to print
; The cursor x will be advanced, though clamped to the width
textbox_print_string        start seg_txtlib
                            using textlib_global_data

                            debugtag 'print_string'

                            begin_locals
wCharIndex                  decl word
wWidthRemaining             decl word
wOption                     decl word
work_area_size              end_locals

                            sub (4:pStr),work_area_size
                            lda <pStr+1
                            jeq null_ptr

                            setlocaldatabank
                            lda textbox_primary~char_modifier
                            sta <wOption
; See how many characters we can print
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~cursor_x
                            jcc exit                                ; x cursor is off the right?
                            sta <wWidthRemaining

                            stz <wCharIndex
                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            jge exit                                ; y cursor is off the bottom?
; put line x 2 in x
                            asl a
                            tax
                            lda textbox_primary~cursor_x
                            lsr a
                            bcs loop_odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
; Starting on an even x
loop_even                   ldy <wCharIndex
                            lda [<pStr],y
                            beq done
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            ldy <wCharIndex
                            lda [<pStr],y
                            beq done
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >odd_col_text_bank,x
                            inx
                            dec <wWidthRemaining
                            bne loop_even
                            bra done
                            longa on

loop_odd_start              anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
loop_odd                    ldy <wCharIndex
                            lda [<pStr],y
                            beq done
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >odd_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            ldy <wCharIndex
                            lda [<pStr],y
                            beq done
                            ora <wOption
                            inx
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            bne loop_odd

done                        anop
                            longm

                            lda <wCharIndex
                            clc
                            adc textbox_primary~cursor_x
                            sta textbox_primary~cursor_x

exit                        anop
                            restoredatabank
null_ptr                    ret
                            end

; -----------------------------------------------------------------------------
; Print a single character to the screen at the current
; textbox cursor location.  The cursor_x is advanced, if it does not go over the
; width.
; Parameters:
; wChar     - the character to print.
textbox_print_char          start seg_txtlib
                            using textlib_global_data

                            debugtag 'print_char'

                            begin_locals
work_area_size              end_locals

                            sub (2:wChar),work_area_size
                            setlocaldatabank

                            lda textbox_primary~char_modifier
                            ora <wChar
                            and #$00ff
                            tay

                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            bge done                                ; y cursor off the bottom?
                            asl a
                            tax
                            lda textbox_primary~cursor_x
                            cmp textbox_primary~right
                            bge done                                ; x cursor off the right?
                            lsr a
                            bcs odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
; Starting on an even x
                            shortm
                            lda ascii_to_vidchar,y
                            sta >even_col_text_bank,x
                            bra done
                            longa on

odd_start                   anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            shortm
                            lda ascii_to_vidchar,y
                            sta >odd_col_text_bank,x

done                        anop
                            longm
                            inc textbox_primary~cursor_x
                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Fill from the current cursor x, to the end of the line, with the specified character.
; The cursor x will be advanced to the end of the line
; Parameters:
; wChar     - the character to fill with.
textbox_fill_line           start seg_txtlib
                            using textlib_global_data

                            debugtag 'fill_line'

                            begin_locals
wWidthRemaining             decl word
work_area_size              end_locals

                            sub (2:wChar),work_area_size
                            setlocaldatabank

                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            bge exit                                ; y cursor off the bottom?
                            asl a
                            tax
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~cursor_x
                            bcc exit                                ; x cursor off the right?
                            beq exit

                            sta <wWidthRemaining
; advance the cursor while we have the chance
                            lda textbox_primary~cursor_x
                            lsr a
                            bcs odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
; Starting on an even x
                            lda textbox_primary~char_modifier
                            ora <wChar
                            and #$00ff
                            tay
                            shortm
                            lda ascii_to_vidchar,y
                            ldy <wWidthRemaining
even_loop                   sta >even_col_text_bank,x
                            dey
                            beq done
                            sta odd_col_text_bank,x
                            inx
                            dey
                            bne even_loop
                            bra done
                            longa on

odd_start                   anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda textbox_primary~char_modifier
                            ora <wChar
                            and #$00ff
                            tay
                            shortm
                            lda ascii_to_vidchar,y
                            ldy <wWidthRemaining
odd_loop                    sta >odd_col_text_bank,x
                            dey
                            beq done
                            inx
                            sta >even_col_text_bank,x
                            dey
                            bne odd_loop

done                        anop
                            longm
; Put the cursor x, at the right
                            lda textbox_primary~right
                            sta textbox_primary~cursor_x
exit                        anop
                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Fill from the left to the right, for the specified number of lines
; Parameters:
; wCount    - the number of lines to fill
; wChar     - the character to fill with.
;
textbox_fill_lines          start seg_txtlib
                            using textlib_global_data

                            debugtag 'fill_lines'

                            begin_locals
wLineIndex                  decl word
wWidthRemaining             decl word
work_area_size              end_locals

                            sub (2:wCount,2:wChar),work_area_size
                            setlocaldatabank

                            lda textbox_primary~cursor_y
                            sta <wLineIndex
                            clc
                            adc <wCount
                            bcs bad_lines
                            cmp textbox_primary~bottom
                            blt ok_lines
                            beq ok_lines
bad_lines                   lda textbox_primary~bottom
                            sec
                            sbc textbox_primary~cursor_y
                            sta <wCount
                            beq exit
                            bcc exit
ok_lines                    anop
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~left
                            sta <wWidthRemaining

                            lda textbox_primary~char_modifier
                            ora <wChar
                            and #$00ff                              ; just in case
                            tay
                            lda ascii_to_vidchar,y
                            sta <wChar

line_loop                   lda <wLineIndex
                            asl a
                            tax
                            lda textbox_primary~left
                            lsr a
                            bcs odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
; Starting on an even x
                            shortm
                            lda <wChar
                            ldy <wWidthRemaining
even_loop                   sta >even_col_text_bank,x
                            dey
                            beq line_done
                            sta odd_col_text_bank,x
                            inx
                            dey
                            bne even_loop
                            bra line_done
                            longa on

odd_start                   anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            shortm
                            lda <wChar
                            ldy <wWidthRemaining
odd_loop                    sta >odd_col_text_bank,x
                            dey
                            beq line_done
                            inx
                            sta >even_col_text_bank,x
                            dey
                            bne odd_loop

line_done                   anop
                            longm
                            inc <wLineIndex
                            dec <wCount
                            bne line_loop

exit                        anop
                            lda textbox_primary~left
                            sta textbox_primary~cursor_x
                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Clear all the lines in the textbox to a character
textbox_clear               start seg_txtlib
                            using textlib_global_data

                            debugtag 'clear'

                            begin_locals
wCount                      decl word
wLineIndex                  decl word
wWidthRemaining             decl word
work_area_size              end_locals

                            sub (2:wChar),work_area_size
                            setlocaldatabank

                            lda textbox_primary~bottom
                            sec
                            sbc textbox_primary~top
                            bcc exit
                            beq exit
                            sta <wCount
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~left
                            bcc exit
                            beq exit
                            sta <wWidthRemaining

                            lda textbox_primary~top
                            sta <wLineIndex

                            lda textbox_primary~char_modifier
                            ora <wChar
                            and #$00ff                              ; just in case
                            tay
                            lda ascii_to_vidchar,y
                            sta <wChar

line_loop                   lda <wLineIndex
                            asl a
                            tax
                            lda textbox_primary~left
                            lsr a
                            bcs odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
; Starting on an even x
                            shortm
                            lda <wChar
                            ldy <wWidthRemaining
even_loop                   sta >even_col_text_bank,x
                            dey
                            beq line_done
                            sta odd_col_text_bank,x
                            inx
                            dey
                            bne even_loop
                            bra line_done
                            longa on

odd_start                   anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            shortm
                            lda <wChar
                            ldy <wWidthRemaining
odd_loop                    sta >odd_col_text_bank,x
                            dey
                            beq line_done
                            inx
                            sta >even_col_text_bank,x
                            dey
                            bne odd_loop

line_done                   anop
                            longm
                            inc <wLineIndex
                            dec <wCount
                            bne line_loop

exit                        anop
                            restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Copy what is at the primary text buffer pointer (textbox_primary~buffer_ptr),
; which is a linear buffer, to line 1 of the screen.
;
; Note, nothing seems to use this, and it is not flexible
; Remove or update to at least be able to specify the target line.
                            aif C:textlib~use_buffered_screen=0,.skip
textbox_copy_line_to_screen start seg_txtlib
                            using textlib_global_data

                            debugtag 'copy_line_to_screen'

                            begin_locals
pSrc                        decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            lda >textbox_primary~buffer_ptr
                            sta <pSrc
                            lda >textbox_primary~buffer_ptr+2
                            sta <pSrc+2

                            lda #$0400
                            sta >patch_write1+1
                            sta >patch_write2+1

                            ldy #80-2
                            ldx #40-1
                            shortm
; Write to page 2, these characters appear in the even column
;                           sta >ssw~txtpage2
loop1                       lda [<pSrc],y
patch_write1                sta >odd_col_text_bank,x
                            dey
                            dey
                            dex
                            bpl loop1

; Write to page 1, these character appear in the odd columns
                            ldy #80-1
                            ldx #40-1
;                           sta >ssw~txtpage1
loop2                       lda [<pSrc],y
patch_write2                sta >odd_col_text_bank,x
                            dey
                            dey
                            dex
                            bpl loop2

                            longm
                            ret
                            end
.skip

; -----------------------------------------------------------------------------
; Print a hex word, to the current textbox print cursor.
; The print cursor x will be advanced, thought clamped to the textbox width
; Parameters:
; wValue        - the value to print.  Input is a word, but only the lower byte will be printed
textbox_print_hex_byte      start seg_txtlib
                            using textlib_global_data

                            debugtag 'print_hex_byte'

                            begin_locals
wWidthRemaining             decl word
work_area_size              end_locals

                            sub (2:wValue),work_area_size
                            setlocaldatabank

; See how many characters we can print
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~cursor_x
                            bcc exit                                ; x cursor is off the right?
                            beq exit
                            sta <wWidthRemaining

                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            bge exit                                ; y cursor is off the bottom?
                            asl a
                            tax
                            lda textbox_primary~cursor_x
                            lsr a
                            bcs odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
; Starting on an even x

                            lda <wValue
                            lsr a
                            lsr a
                            lsr a
                            lsr a
                            tay
                            lda hex_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            lda <wValue
                            and #$0f
                            tay
                            lda hex_to_vidchar,y
                            sta >odd_col_text_bank,x
                            bra done
                            longa on

odd_start                   anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
                            lda <wValue
                            lsr a
                            lsr a
                            lsr a
                            lsr a
                            tay
                            lda hex_to_vidchar,y
                            sta >odd_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            inx
                            lda <wValue
                            and #$0f
                            tay
                            lda hex_to_vidchar,y
                            sta >even_col_text_bank,x

done                        anop
                            longm
                            lda textbox_primary~cursor_x
                            clc
                            adc #2
                            cmp textbox_primary~right
                            blt ok
                            lda textbox_primary~right
ok                          sta textbox_primary~cursor_x

exit                        restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Print a hex word, to the current textbox print cursor
; The print cursor x will be advanced, thought clamped to the textbox width
; Parameters:
; wValue        - the value to print
textbox_print_hex_word      start seg_txtlib
                            using textlib_global_data

                            debugtag 'print_hex_word'

                            begin_locals
wWidthRemaining             decl word
work_area_size              end_locals

                            sub (2:wValue),work_area_size
                            setlocaldatabank

; See how many characters we can print
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~cursor_x
                            jcc exit                                ; x cursor is off the right?
                            sta <wWidthRemaining

                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            jge exit                                ; y cursor is off the bottom?
                            asl a
                            tax
                            lda textbox_primary~cursor_x
                            lsr a
                            bcs odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
; Starting on an even x
                            lda <wValue+1
                            lsr a
                            lsr a
                            lsr a
                            lsr a
                            tay
                            lda hex_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            lda <wValue+1
                            and #$0f
                            tay
                            lda hex_to_vidchar,y
                            sta >odd_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            inx

                            lda <wValue
                            lsr a
                            lsr a
                            lsr a
                            lsr a
                            tay
                            lda hex_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            lda <wValue
                            and #$0f
                            tay
                            lda hex_to_vidchar,y
                            sta >odd_col_text_bank,x
                            bra done
                            longa on

odd_start                   anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
                            lda <wValue+1
                            lsr a
                            lsr a
                            lsr a
                            lsr a
                            tay
                            lda hex_to_vidchar,y
                            sta >odd_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            inx
                            lda <wValue+1
                            and #$0f
                            tay
                            lda hex_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            beq done

                            lda <wValue
                            lsr a
                            lsr a
                            lsr a
                            lsr a
                            tay
                            lda hex_to_vidchar,y
                            sta >odd_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            inx
                            lda <wValue
                            and #$0f
                            tay
                            lda hex_to_vidchar,y
                            sta >even_col_text_bank,x

done                        anop
                            longm
                            lda textbox_primary~cursor_x
                            clc
                            adc #4
                            cmp textbox_primary~right
                            blt ok
                            lda textbox_primary~right
ok                          sta textbox_primary~cursor_x

exit                        restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Print a decimal byte at the cursor location.
; Parameters:
; wValue        - the value to print.  Only the lower 8 bits are printed
textbox_print_decimal_byte  start seg_txtlib
                            using textlib_global_data

                            debugtag 'print_decimal_byte'

                            begin_locals
wCharCount                  decl word
wOption                     decl word
wWidthRemaining             decl word
wCharIndex                  decl word
work_area_size              end_locals

                            sub (2:wValue),work_area_size

                            lda <wValue
                            and #$FF
                            pha
                            pushptr #buffer
                            pushsword #3
                            jsl word_to_str
                            sta <wCharCount

                            setlocaldatabank

                            lda textbox_primary~char_modifier
                            sta <wOption
; See how many characters we can print
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~cursor_x
                            jcc exit                                ; x cursor is off the right?
                            cmp <wCharCount
                            blt less_width
                            lda <wCharCount
less_width                  sta <wWidthRemaining

                            stz <wCharIndex
                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            jge exit                                ; y cursor is off the bottom?
; put line x 2 in x
                            asl a
                            tax
                            lda textbox_primary~cursor_x
                            lsr a
                            bcs loop_odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
; Starting on an even x
loop_even                   ldy <wCharIndex
                            lda buffer,y
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            ldy <wCharIndex
                            lda buffer,y
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >odd_col_text_bank,x
                            inx
                            dec <wWidthRemaining
                            bne loop_even
                            bra done
                            longa on

loop_odd_start              anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
loop_odd                    ldy <wCharIndex
                            lda buffer,y
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >odd_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            ldy <wCharIndex
                            lda buffer,y
                            ora <wOption
                            inx
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            bne loop_odd

done                        anop
                            longm

                            lda <wCharIndex
                            clc
                            adc textbox_primary~cursor_x
                            sta textbox_primary~cursor_x

exit                        anop
                            restoredatabank
                            ret

buffer                      ds 5
                            end

; -----------------------------------------------------------------------------
; Print a decimal byte at the cursor location.
; Parameters:
; wValue        - the value to print.
textbox_print_decimal_word  start seg_txtlib
                            using textlib_global_data

                            debugtag 'print_decimal_word'

                            begin_locals
wCharCount                  decl word
wOption                     decl word
wWidthRemaining             decl word
wCharIndex                  decl word
work_area_size              end_locals

                            sub (2:wValue),work_area_size

                            pushsword <wValue
                            pushptr #buffer
                            pushsword #5
                            jsl word_to_str
                            sta <wCharCount

                            setlocaldatabank

                            lda textbox_primary~char_modifier
                            sta <wOption
; See how many characters we can print
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~cursor_x
                            jcc exit                                ; x cursor is off the right?
                            cmp <wCharCount
                            blt less_width
                            lda <wCharCount
less_width                  sta <wWidthRemaining

                            stz <wCharIndex
                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            jge exit                                ; y cursor is off the bottom?
; put line x 2 in x
                            asl a
                            tax
                            lda textbox_primary~cursor_x
                            lsr a
                            bcs loop_odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
; Starting on an even x
loop_even                   ldy <wCharIndex
                            lda buffer,y
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            ldy <wCharIndex
                            lda buffer,y
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >odd_col_text_bank,x
                            inx
                            dec <wWidthRemaining
                            bne loop_even
                            bra done
                            longa on

loop_odd_start              anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            lda #0                                  ; clear the upper bits of A, before we go 'short', because TAY will move all 16 bits, regardless
                            shortm
loop_odd                    ldy <wCharIndex
                            lda buffer,y
                            ora <wOption
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >odd_col_text_bank,x
                            dec <wWidthRemaining
                            beq done
                            ldy <wCharIndex
                            lda buffer,y
                            ora <wOption
                            inx
                            inc <wCharIndex
                            tay
                            lda ascii_to_vidchar,y
                            sta >even_col_text_bank,x
                            dec <wWidthRemaining
                            bne loop_odd

done                        anop
                            longm

                            lda <wCharIndex
                            clc
                            adc textbox_primary~cursor_x
                            sta textbox_primary~cursor_x

exit                        anop
                            restoredatabank
                            ret

buffer                      ds 5
                            end

; -----------------------------------------------------------------------------
; Print a binary byte, with the high bit on the left.
; The print cursor x will be advanced, thought clamped to the textbox width
; Parameters:
; wValue        - the value to print (only uses lower byte)
textbox_print_binary_byte   start seg_txtlib
                            using textlib_global_data

                            debugtag 'print_binary_byte'

                            begin_locals
wWidthRemaining             decl word
wBit                        decl word
work_area_size              end_locals

                            sub (2:wValue),work_area_size
                            setlocaldatabank

                            lda #$80
                            sta <wBit

; See how many characters we can print
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~cursor_x
                            jcc exit                                ; x cursor is off the right?
                            sta <wWidthRemaining

                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            jge exit                                ; y cursor is off the bottom?
                            asl a
                            tax
                            lda textbox_primary~cursor_x
                            lsr a
                            bcs odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
                            shortm
; Starting on an even x
loop_even                   lda <wValue
                            and <wBit
                            beq zero_1
                            lda #vidchar~1
                            bra one_1
zero_1                      lda #vidchar~0
one_1                       anop
                            sta >even_col_text_bank,x
                            lsr <wBit
                            beq done
                            dec <wWidthRemaining
                            beq done

                            lda <wValue
                            and <wBit
                            beq zero_2
                            lda #vidchar~1
                            bra one_2
zero_2                      lda #vidchar~0
one_2                       anop
                            sta >odd_col_text_bank,x
                            lsr <wBit
                            beq done
                            dec <wWidthRemaining
                            beq done
                            inx
                            bra loop_even

                            longa on

odd_start                   anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            shortm
loop_odd                    anop
                            lda <wValue
                            and <wBit
                            beq zero_3
                            lda #vidchar~1
                            bra one_3
zero_3                      lda #vidchar~0
one_3                       anop
                            sta >odd_col_text_bank,x
                            lsr <wBit
                            beq done
                            dec <wWidthRemaining
                            beq done
                            inx
                            lda <wValue
                            and <wBit
                            beq zero_4
                            lda #vidchar~1
                            bra one_4
zero_4                      lda #vidchar~0
one_4                       anop
                            sta >even_col_text_bank,x
                            lsr <wBit
                            beq done
                            dec <wWidthRemaining
                            beq done
                            bra loop_odd

done                        anop
                            longm
                            lda textbox_primary~cursor_x
                            clc
                            adc #8
                            cmp textbox_primary~right
                            blt ok
                            lda textbox_primary~right
ok                          sta textbox_primary~cursor_x

exit                        restoredatabank
                            ret
                            end
; -----------------------------------------------------------------------------
; Write a single character at an x/y location
; Parameters;
; c register - characters to write
; x register - x location
; y register - y location
textscreen_write_char_at    start seg_txtlib
                            using textlib_global_data

                            debugtag 'write_char_at'

                            setlocaldatabank

                            pha
                            tya
                            asl a
                            tay
                            txa
                            lsr a
                            bcs odd
                            clc
                            adc textscreen_ylookup,y
                            tax
                            ply
                            shortm
                            lda ascii_to_vidchar,y
                            sta >even_col_text_bank,x
                            longm
                            restoredatabank
                            rtl
;
odd                         clc
                            adc textscreen_ylookup,y
                            tax
                            ply
                            shortm
                            lda ascii_to_vidchar,y
                            sta >odd_col_text_bank,x
                            longm
                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Helper funtions

; -----------------------------------------------------------------------------
; Fill from the current cursor x, to the end of the line.
; This is an internal function, that assumes the databank is set to local, etc.

internal_fill_to_end        private seg_txtlib
                            using textlib_global_data

                            lda textbox_primary~cursor_y
                            cmp textbox_primary~bottom
                            bge exit                                ; y cursor off the bottom?
                            asl a
                            tax                                     ; line x 2, in x
                            lda textbox_primary~right
                            sec
                            sbc textbox_primary~cursor_x
                            bcc exit                                ; x cursor off the right?
                            beq exit

                            pha                                     ; save width
; advance the cursor while we have the chance
                            ldy textbox_primary~cursor_x            ; we will need this unmodifed, save it
                            phy
                            clc
                            adc textbox_primary~cursor_x
                            sta textbox_primary~cursor_x

; Get the character to fill.
                            ldy #vidchar~space
                            lda textbox_primary~char_modifier
                            beq ok_space
                            ldy #vidchar~inverse~space

ok_space                    pla                                     ; get the cursor x back
                            lsr a
                            bcs odd_start
                            clc
                            adc textscreen_ylookup,x
                            tax
; Starting on an even x
                            shortm
                            tya
                            ply                                     ; get the width back
even_loop                   sta >even_col_text_bank,x
                            dey
                            beq done
                            sta odd_col_text_bank,x
                            inx
                            dey
                            bne even_loop
                            bra done
                            longa on

odd_start                   anop
                            clc
                            adc textscreen_ylookup,x
                            tax
                            shortm
                            tya
                            ply                                     ; get the width back
odd_loop                    sta >odd_col_text_bank,x
                            dey
                            beq done
                            inx
                            sta >even_col_text_bank,x
                            dey
                            bne odd_loop

done                        anop
                            longm
exit                        anop
                            rts

                            end

; -----------------------------------------------------------------------------
textlib_global_data         data seg_txtlib

textbox_primary~left        dc i2'0'
textbox_primary~top         dc i2'0'
textbox_primary~right       dc i2'0'
textbox_primary~bottom      dc i2'0'

                            aif C:textlib~use_buffered_screen=0,.skip
textbox_primary~size        dc i2'0'
textbox_primary~buffer_handle dc i4'0'
textbox_primary~buffer_ptr  dc i4'0'
.skip

textbox_primary~cursor_x    dc i'0'
textbox_primary~cursor_y    dc i'0'

; These are the flags to set to textbox_set_option
; Some bits are mutually exclusive, so one call can toggle an option, or not change its current state
textbox_option~normal       equ $0001
textbox_option~inverse      equ $0002
textbox_option~no_line_fill equ $0004
textbox_option~line_fill    equ $0008

; Data types, for defining what to print.  Kinda printf-like code, in that there is
; also some information on how to display the data.
textbox_data~none               equ 0
textbox_data~string             equ 1
textbox_data~16bit_hex          equ 2
textbox_data~16bit_decimal      equ 3
textbox_data~ptr_16bit_hex      equ 4
textbox_data~ptr_16bit_decimal  equ 5

; These are the internal flags and values to support the options
char_modifier~normal        equ 0
char_modifier~inverse       equ $0080
; This is used to set whether or not to use the inverse
; Put an $0080 in here to display inverse, 0 to display normal.
textbox_primary~char_modifier dc i'0'

; If bit $8000 is on, when printing, after the print is done, the rest of the line
; will be filled with spaces, to the end of the textbox
textbox_primary~option_line_fill dc i'0'

vidchar~upper_set           equ $80
vidchar~at                  equ vidchar~upper_set+$00
vidchar~upper~a             equ vidchar~upper_set+$01
vidchar~upper~b             equ vidchar~upper_set+$02
vidchar~upper~c             equ vidchar~upper_set+$03
vidchar~upper~d             equ vidchar~upper_set+$04
vidchar~upper~e             equ vidchar~upper_set+$05
vidchar~upper~f             equ vidchar~upper_set+$06
vidchar~upper~g             equ vidchar~upper_set+$07
vidchar~upper~h             equ vidchar~upper_set+$08
vidchar~upper~i             equ vidchar~upper_set+$09
vidchar~upper~j             equ vidchar~upper_set+$0a
vidchar~upper~k             equ vidchar~upper_set+$0b
vidchar~upper~l             equ vidchar~upper_set+$0c
vidchar~upper~m             equ vidchar~upper_set+$0d
vidchar~upper~n             equ vidchar~upper_set+$0e
vidchar~upper~o             equ vidchar~upper_set+$0f
vidchar~upper~p             equ vidchar~upper_set+$10
vidchar~upper~q             equ vidchar~upper_set+$11
vidchar~upper~r             equ vidchar~upper_set+$12
vidchar~upper~s             equ vidchar~upper_set+$13
vidchar~upper~t             equ vidchar~upper_set+$14
vidchar~upper~u             equ vidchar~upper_set+$15
vidchar~upper~v             equ vidchar~upper_set+$16
vidchar~upper~w             equ vidchar~upper_set+$17
vidchar~upper~x             equ vidchar~upper_set+$18
vidchar~upper~y             equ vidchar~upper_set+$19
vidchar~upper~z             equ vidchar~upper_set+$1a
vidchar~open_square_bracket equ vidchar~upper_set+$1b
vidchar~backslash           equ vidchar~upper_set+$1c
vidchar~close_square_bracket equ vidchar~upper_set+$1d
vidchar~caret               equ vidchar~upper_set+$1e
vidchar~underscore          equ vidchar~upper_set+$1f

vidchar~inverse~upper_set           equ $00
vidchar~inverse~at                  equ vidchar~inverse~upper_set+$00
vidchar~inverse~upper~a             equ vidchar~inverse~upper_set+$01
vidchar~inverse~upper~b             equ vidchar~inverse~upper_set+$02
vidchar~inverse~upper~c             equ vidchar~inverse~upper_set+$03
vidchar~inverse~upper~d             equ vidchar~inverse~upper_set+$04
vidchar~inverse~upper~e             equ vidchar~inverse~upper_set+$05
vidchar~inverse~upper~f             equ vidchar~inverse~upper_set+$06
vidchar~inverse~upper~g             equ vidchar~inverse~upper_set+$07
vidchar~inverse~upper~h             equ vidchar~inverse~upper_set+$08
vidchar~inverse~upper~i             equ vidchar~inverse~upper_set+$09
vidchar~inverse~upper~j             equ vidchar~inverse~upper_set+$0a
vidchar~inverse~upper~k             equ vidchar~inverse~upper_set+$0b
vidchar~inverse~upper~l             equ vidchar~inverse~upper_set+$0c
vidchar~inverse~upper~m             equ vidchar~inverse~upper_set+$0d
vidchar~inverse~upper~n             equ vidchar~inverse~upper_set+$0e
vidchar~inverse~upper~o             equ vidchar~inverse~upper_set+$0f
vidchar~inverse~upper~p             equ vidchar~inverse~upper_set+$10
vidchar~inverse~upper~q             equ vidchar~inverse~upper_set+$11
vidchar~inverse~upper~r             equ vidchar~inverse~upper_set+$12
vidchar~inverse~upper~s             equ vidchar~inverse~upper_set+$13
vidchar~inverse~upper~t             equ vidchar~inverse~upper_set+$14
vidchar~inverse~upper~u             equ vidchar~inverse~upper_set+$15
vidchar~inverse~upper~v             equ vidchar~inverse~upper_set+$16
vidchar~inverse~upper~w             equ vidchar~inverse~upper_set+$17
vidchar~inverse~upper~x             equ vidchar~inverse~upper_set+$18
vidchar~inverse~upper~y             equ vidchar~inverse~upper_set+$19
vidchar~inverse~upper~z             equ vidchar~inverse~upper_set+$1a
vidchar~inverse~open_square_bracket equ vidchar~inverse~upper_set+$1b
vidchar~inverse~backslash           equ vidchar~inverse~upper_set+$1c
vidchar~inverse~close_square_bracket equ vidchar~inverse~upper_set+$1d
vidchar~inverse~caret               equ vidchar~inverse~upper_set+$1e
vidchar~inverse~underscore          equ vidchar~inverse~upper_set+$1f


vidchar~lower_set           equ $e0
vidchar~accent              equ vidchar~lower_set+$00
vidchar~lower~a             equ vidchar~lower_set+$01
vidchar~lower~b             equ vidchar~lower_set+$02
vidchar~lower~c             equ vidchar~lower_set+$03
vidchar~lower~d             equ vidchar~lower_set+$04
vidchar~lower~e             equ vidchar~lower_set+$05
vidchar~lower~f             equ vidchar~lower_set+$06
vidchar~lower~g             equ vidchar~lower_set+$07
vidchar~lower~h             equ vidchar~lower_set+$08
vidchar~lower~i             equ vidchar~lower_set+$09
vidchar~lower~j             equ vidchar~lower_set+$0a
vidchar~lower~k             equ vidchar~lower_set+$0b
vidchar~lower~l             equ vidchar~lower_set+$0c
vidchar~lower~m             equ vidchar~lower_set+$0d
vidchar~lower~n             equ vidchar~lower_set+$0e
vidchar~lower~o             equ vidchar~lower_set+$0f
vidchar~lower~p             equ vidchar~lower_set+$10
vidchar~lower~q             equ vidchar~lower_set+$11
vidchar~lower~r             equ vidchar~lower_set+$12
vidchar~lower~s             equ vidchar~lower_set+$13
vidchar~lower~t             equ vidchar~lower_set+$14
vidchar~lower~u             equ vidchar~lower_set+$15
vidchar~lower~v             equ vidchar~lower_set+$16
vidchar~lower~w             equ vidchar~lower_set+$17
vidchar~lower~x             equ vidchar~lower_set+$18
vidchar~lower~y             equ vidchar~lower_set+$19
vidchar~lower~z             equ vidchar~lower_set+$1a
vidchar~open_curley_bracket equ vidchar~lower_set+$1b
vidchar~vertical            equ vidchar~lower_set+$1c
vidchar~close_curley_bracket equ vidchar~lower_set+$1d
vidchar~tilde               equ vidchar~lower_set+$1e
vidchar~hatchbox            equ vidchar~lower_set+$1f

vidchar~inverse~lower_set           equ $60
vidchar~inverse~accent              equ vidchar~inverse~lower_set+$00
vidchar~inverse~lower~a             equ vidchar~inverse~lower_set+$01
vidchar~inverse~lower~b             equ vidchar~inverse~lower_set+$02
vidchar~inverse~lower~c             equ vidchar~inverse~lower_set+$03
vidchar~inverse~lower~d             equ vidchar~inverse~lower_set+$04
vidchar~inverse~lower~e             equ vidchar~inverse~lower_set+$05
vidchar~inverse~lower~f             equ vidchar~inverse~lower_set+$06
vidchar~inverse~lower~g             equ vidchar~inverse~lower_set+$07
vidchar~inverse~lower~h             equ vidchar~inverse~lower_set+$08
vidchar~inverse~lower~i             equ vidchar~inverse~lower_set+$09
vidchar~inverse~lower~j             equ vidchar~inverse~lower_set+$0a
vidchar~inverse~lower~k             equ vidchar~inverse~lower_set+$0b
vidchar~inverse~lower~l             equ vidchar~inverse~lower_set+$0c
vidchar~inverse~lower~m             equ vidchar~inverse~lower_set+$0d
vidchar~inverse~lower~n             equ vidchar~inverse~lower_set+$0e
vidchar~inverse~lower~o             equ vidchar~inverse~lower_set+$0f
vidchar~inverse~lower~p             equ vidchar~inverse~lower_set+$10
vidchar~inverse~lower~q             equ vidchar~inverse~lower_set+$11
vidchar~inverse~lower~r             equ vidchar~inverse~lower_set+$12
vidchar~inverse~lower~s             equ vidchar~inverse~lower_set+$13
vidchar~inverse~lower~t             equ vidchar~inverse~lower_set+$14
vidchar~inverse~lower~u             equ vidchar~inverse~lower_set+$15
vidchar~inverse~lower~v             equ vidchar~inverse~lower_set+$16
vidchar~inverse~lower~w             equ vidchar~inverse~lower_set+$17
vidchar~inverse~lower~x             equ vidchar~inverse~lower_set+$18
vidchar~inverse~lower~y             equ vidchar~inverse~lower_set+$19
vidchar~inverse~lower~z             equ vidchar~inverse~lower_set+$1a
vidchar~inverse~open_curley_bracket equ vidchar~inverse~lower_set+$1b
vidchar~inverse~vertical            equ vidchar~inverse~lower_set+$1c
vidchar~inverse~close_curley_bracket equ vidchar~inverse~lower_set+$1d
vidchar~inverse~tilde               equ vidchar~inverse~lower_set+$1e
vidchar~inverse~hatchbox            equ vidchar~inverse~lower_set+$1f


vidchar~special_set         equ $a0
vidchar~space               equ vidchar~special_set+$00
vidchar~exclamation         equ vidchar~special_set+$01
vidchar~double_quote        equ vidchar~special_set+$02
vidchar~hash                equ vidchar~special_set+$03
vidchar~dollar              equ vidchar~special_set+$04
vidchar~percent             equ vidchar~special_set+$05
vidchar~ampersand           equ vidchar~special_set+$06
vidchar~single_quote        equ vidchar~special_set+$07
vidchar~open_paren          equ vidchar~special_set+$08
vidchar~close_paren         equ vidchar~special_set+$09
vidchar~star                equ vidchar~special_set+$0a
vidchar~plus                equ vidchar~special_set+$0b
vidchar~comma               equ vidchar~special_set+$0c
vidchar~minus               equ vidchar~special_set+$0d
vidchar~period              equ vidchar~special_set+$0e
vidchar~forward_slash       equ vidchar~special_set+$0f
vidchar~0                   equ vidchar~special_set+$10
vidchar~1                   equ vidchar~special_set+$11
vidchar~2                   equ vidchar~special_set+$12
vidchar~3                   equ vidchar~special_set+$13
vidchar~4                   equ vidchar~special_set+$14
vidchar~5                   equ vidchar~special_set+$15
vidchar~6                   equ vidchar~special_set+$16
vidchar~7                   equ vidchar~special_set+$17
vidchar~8                   equ vidchar~special_set+$18
vidchar~9                   equ vidchar~special_set+$19
vidchar~colon               equ vidchar~special_set+$1a
vidchar~semi_colon          equ vidchar~special_set+$1b
vidchar~less_than           equ vidchar~special_set+$1c
vidchar~equals              equ vidchar~special_set+$1d
vidchar~greater_than        equ vidchar~special_set+$1e
vidchar~question            equ vidchar~special_set+$1f

vidchar~inverse~special_set         equ $20
vidchar~inverse~space               equ vidchar~inverse~special_set+$00
vidchar~inverse~exclamation         equ vidchar~inverse~special_set+$01
vidchar~inverse~double_quote        equ vidchar~inverse~special_set+$02
vidchar~inverse~hash                equ vidchar~inverse~special_set+$03
vidchar~inverse~dollar              equ vidchar~inverse~special_set+$04
vidchar~inverse~percent             equ vidchar~inverse~special_set+$05
vidchar~inverse~ampersand           equ vidchar~inverse~special_set+$06
vidchar~inverse~single_quote        equ vidchar~inverse~special_set+$07
vidchar~inverse~open_paren          equ vidchar~inverse~special_set+$08
vidchar~inverse~close_paren         equ vidchar~inverse~special_set+$09
vidchar~inverse~star                equ vidchar~inverse~special_set+$0a
vidchar~inverse~plus                equ vidchar~inverse~special_set+$0b
vidchar~inverse~comma               equ vidchar~inverse~special_set+$0c
vidchar~inverse~minus               equ vidchar~inverse~special_set+$0d
vidchar~inverse~period              equ vidchar~inverse~special_set+$0e
vidchar~inverse~forward_slash       equ vidchar~inverse~special_set+$0f
vidchar~inverse~0                   equ vidchar~inverse~special_set+$10
vidchar~inverse~1                   equ vidchar~inverse~special_set+$11
vidchar~inverse~2                   equ vidchar~inverse~special_set+$12
vidchar~inverse~3                   equ vidchar~inverse~special_set+$13
vidchar~inverse~4                   equ vidchar~inverse~special_set+$14
vidchar~inverse~5                   equ vidchar~inverse~special_set+$15
vidchar~inverse~6                   equ vidchar~inverse~special_set+$16
vidchar~inverse~7                   equ vidchar~inverse~special_set+$17
vidchar~inverse~8                   equ vidchar~inverse~special_set+$18
vidchar~inverse~9                   equ vidchar~inverse~special_set+$19
vidchar~inverse~colon               equ vidchar~inverse~special_set+$1a
vidchar~inverse~semi_colon          equ vidchar~inverse~special_set+$1b
vidchar~inverse~less_than           equ vidchar~inverse~special_set+$1c
vidchar~inverse~equals              equ vidchar~inverse~special_set+$1d
vidchar~inverse~greater_than        equ vidchar~inverse~special_set+$1e
vidchar~inverse~question            equ vidchar~inverse~special_set+$1f

vidchar~mousetext_set                   equ $40
vidchar~mousetext~closed_apple          equ vidchar~mousetext_set+$00
vidchar~mousetext~open_apple            equ vidchar~mousetext_set+$01
vidchar~mousetext~pointer               equ vidchar~mousetext_set+$02
vidchar~mousetext~hour_glass            equ vidchar~mousetext_set+$03
vidchar~mousetext~check                 equ vidchar~mousetext_set+$04
vidchar~mousetext~check_inverted        equ vidchar~mousetext_set+$05
vidchar~mousetext~return_inverted       equ vidchar~mousetext_set+$06
vidchar~mousetext~title_bar             equ vidchar~mousetext_set+$07
vidchar~mousetext~left_arrow            equ vidchar~mousetext_set+$08
vidchar~mousetext~ellipses              equ vidchar~mousetext_set+$09
vidchar~mousetext~down_arrow            equ vidchar~mousetext_set+$0a
vidchar~mousetext~up_arrow              equ vidchar~mousetext_set+$0b
vidchar~mousetext~box_bottom            equ vidchar~mousetext_set+$0c
vidchar~mousetext~return                equ vidchar~mousetext_set+$0d
vidchar~mousetext~inverted_block        equ vidchar~mousetext_set+$0e
vidchar~mousetext~scrollbar_left_arrow  equ vidchar~mousetext_set+$0f
vidchar~mousetext~scrollbar_right_arrow equ vidchar~mousetext_set+$10
vidchar~mousetext~scrollbar_down_arrow  equ vidchar~mousetext_set+$11
vidchar~mousetext~scrollbar_up_arrow    equ vidchar~mousetext_set+$12
vidchar~mousetext~horizontal_bar        equ vidchar~mousetext_set+$13
vidchar~mousetext~box_lower_left        equ vidchar~mousetext_set+$14
vidchar~mousetext~arrow_right           equ vidchar~mousetext_set+$15
vidchar~mousetext~hatch_1               equ vidchar~mousetext_set+$16
vidchar~mousetext~hatch_2               equ vidchar~mousetext_set+$17
vidchar~mousetext~folder_left           equ vidchar~mousetext_set+$18
vidchar~mousetext~folder_right          equ vidchar~mousetext_set+$19
vidchar~mousetext~box_right             equ vidchar~mousetext_set+$1a
vidchar~mousetext~diamond               equ vidchar~mousetext_set+$1b
vidchar~mousetext~scrollbar_horizontal  equ vidchar~mousetext_set+$1c
vidchar~mousetext~cross                 equ vidchar~mousetext_set+$1d
vidchar~mousetext~close_box             equ vidchar~mousetext_set+$1e
vidchar~mousetext~box_left              equ vidchar~mousetext_set+$1f

vidchar~non_printable       equ vidchar~hatchbox

ascii_to_vidchar            anop
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~non_printable'
                            dc i1'vidchar~space'            ; Space
                            dc i1'vidchar~exclamation'      ; Exclamation mark
                            dc i1'vidchar~double_quote'     ; Double quotes (or speech marks)
                            dc i1'vidchar~hash'             ; Number sign
                            dc i1'vidchar~dollar'           ; Dollar
                            dc i1'vidchar~percent'          ; Per cent sign
                            dc i1'vidchar~ampersand'        ; Ampersand
                            dc i1'vidchar~single_quote'     ; Single quote
                            dc i1'vidchar~open_paren'       ; Open parenthesis (or open bracket)
                            dc i1'vidchar~close_paren'      ; Close parenthesis (or close bracket)
                            dc i1'vidchar~star'             ; Asterisk
                            dc i1'vidchar~plus'             ; Plus
                            dc i1'vidchar~comma'            ; Comma
                            dc i1'vidchar~minus'            ; Hyphen-minus
                            dc i1'vidchar~period'           ; Period, dot or full stop
                            dc i1'vidchar~forward_slash'    ; Slash or divide
                            dc i1'vidchar~0'                ; Zero
                            dc i1'vidchar~1'                ; One
                            dc i1'vidchar~2'                ; Two
                            dc i1'vidchar~3'                ; Three
                            dc i1'vidchar~4'                ; Four
                            dc i1'vidchar~5'                ; Five
                            dc i1'vidchar~6'                ; Six
                            dc i1'vidchar~7'                ; Seven
                            dc i1'vidchar~8'                ; Eight
                            dc i1'vidchar~9'                ; Nine
                            dc i1'vidchar~colon'            ; Colon
                            dc i1'vidchar~semi_colon'       ; Semicolon
                            dc i1'vidchar~less_than'        ; Less than (or open angled bracket)
                            dc i1'vidchar~equals'           ; Equals
                            dc i1'vidchar~greater_than'     ; Greater than (or close angled bracket)
                            dc i1'vidchar~question'         ; Question mark
                            dc i1'vidchar~at'               ; At sign
                            dc i1'vidchar~upper~a'          ; Uppercase A
                            dc i1'vidchar~upper~b'          ; Uppercase B
                            dc i1'vidchar~upper~c'          ; Uppercase C
                            dc i1'vidchar~upper~d'          ; Uppercase D
                            dc i1'vidchar~upper~e'          ; Uppercase E
                            dc i1'vidchar~upper~f'          ; Uppercase F
                            dc i1'vidchar~upper~g'          ; Uppercase G
                            dc i1'vidchar~upper~h'          ; Uppercase H
                            dc i1'vidchar~upper~i'          ; Uppercase I
                            dc i1'vidchar~upper~j'          ; Uppercase J
                            dc i1'vidchar~upper~k'          ; Uppercase K
                            dc i1'vidchar~upper~l'          ; Uppercase L
                            dc i1'vidchar~upper~m'          ; Uppercase M
                            dc i1'vidchar~upper~n'          ; Uppercase N
                            dc i1'vidchar~upper~o'          ; Uppercase O
                            dc i1'vidchar~upper~p'          ; Uppercase P
                            dc i1'vidchar~upper~q'          ; Uppercase Q
                            dc i1'vidchar~upper~r'          ; Uppercase R
                            dc i1'vidchar~upper~s'          ; Uppercase S
                            dc i1'vidchar~upper~t'          ; Uppercase T
                            dc i1'vidchar~upper~u'          ; Uppercase U
                            dc i1'vidchar~upper~v'          ; Uppercase V
                            dc i1'vidchar~upper~w'          ; Uppercase W
                            dc i1'vidchar~upper~x'          ; Uppercase X
                            dc i1'vidchar~upper~y'          ; Uppercase Y
                            dc i1'vidchar~upper~z'          ; Uppercase Z
                            dc i1'vidchar~open_square_bracket' ;Opening bracket
                            dc i1'vidchar~backslash'        ; Backslash
                            dc i1'vidchar~close_square_bracket' ; Closing bracket
                            dc i1'vidchar~caret'            ; Caret - circumflex
                            dc i1'vidchar~underscore'       ; Underscore
                            dc i1'vidchar~accent'           ; Grave accent
                            dc i1'vidchar~lower~a'          ; Lowercase a
                            dc i1'vidchar~lower~b'          ; Lowercase b
                            dc i1'vidchar~lower~c'          ; Lowercase c
                            dc i1'vidchar~lower~d'          ; Lowercase d
                            dc i1'vidchar~lower~e'          ; Lowercase e
                            dc i1'vidchar~lower~f'          ; Lowercase f
                            dc i1'vidchar~lower~g'          ; Lowercase g
                            dc i1'vidchar~lower~h'          ; Lowercase h
                            dc i1'vidchar~lower~i'          ; Lowercase i
                            dc i1'vidchar~lower~j'          ; Lowercase j
                            dc i1'vidchar~lower~k'          ; Lowercase k
                            dc i1'vidchar~lower~l'          ; Lowercase l
                            dc i1'vidchar~lower~m'          ; Lowercase m
                            dc i1'vidchar~lower~n'          ; Lowercase n
                            dc i1'vidchar~lower~o'          ; Lowercase o
                            dc i1'vidchar~lower~p'          ; Lowercase p
                            dc i1'vidchar~lower~q'          ; Lowercase q
                            dc i1'vidchar~lower~r'          ; Lowercase r
                            dc i1'vidchar~lower~s'          ; Lowercase s
                            dc i1'vidchar~lower~t'          ; Lowercase t
                            dc i1'vidchar~lower~u'          ; Lowercase u
                            dc i1'vidchar~lower~v'          ; Lowercase v
                            dc i1'vidchar~lower~w'          ; Lowercase w
                            dc i1'vidchar~lower~x'          ; Lowercase x
                            dc i1'vidchar~lower~y'          ; Lowercase y
                            dc i1'vidchar~lower~z'          ; Lowercase z
                            dc i1'vidchar~open_curley_bracket' ;Opening brace
                            dc i1'vidchar~vertical'         ; Vertical bar
                            dc i1'vidchar~close_curley_bracket' ; Closing brace
                            dc i1'vidchar~tilde'            ; Equivalency sign - tilde
                            dc i1'vidchar~non_printable'    ; Delete
; Extended ascii (my own), to print mousetext and inverse
                            dc i1'vidchar~mousetext~closed_apple'
                            dc i1'vidchar~mousetext~open_apple'
                            dc i1'vidchar~mousetext~pointer'
                            dc i1'vidchar~mousetext~hour_glass'
                            dc i1'vidchar~mousetext~check'
                            dc i1'vidchar~mousetext~check_inverted'
                            dc i1'vidchar~mousetext~return_inverted'
                            dc i1'vidchar~mousetext~title_bar'
                            dc i1'vidchar~mousetext~left_arrow'
                            dc i1'vidchar~mousetext~ellipses'
                            dc i1'vidchar~mousetext~down_arrow'
                            dc i1'vidchar~mousetext~up_arrow'
                            dc i1'vidchar~mousetext~box_bottom'
                            dc i1'vidchar~mousetext~return'
                            dc i1'vidchar~mousetext~inverted_block'
                            dc i1'vidchar~mousetext~scrollbar_left_arrow'
                            dc i1'vidchar~mousetext~scrollbar_right_arrow'
                            dc i1'vidchar~mousetext~scrollbar_down_arrow'
                            dc i1'vidchar~mousetext~scrollbar_up_arrow'
                            dc i1'vidchar~mousetext~horizontal_bar'
                            dc i1'vidchar~mousetext~box_lower_left'
                            dc i1'vidchar~mousetext~arrow_right'
                            dc i1'vidchar~mousetext~hatch_1'
                            dc i1'vidchar~mousetext~hatch_2'
                            dc i1'vidchar~mousetext~folder_left'
                            dc i1'vidchar~mousetext~folder_right'
                            dc i1'vidchar~mousetext~box_right'
                            dc i1'vidchar~mousetext~diamond'
                            dc i1'vidchar~mousetext~scrollbar_horizontal'
                            dc i1'vidchar~mousetext~cross'
                            dc i1'vidchar~mousetext~close_box'
                            dc i1'vidchar~mousetext~box_left'
; Inverse
                            dc i1'vidchar~inverse~space'            ; Space
                            dc i1'vidchar~inverse~exclamation'      ; Exclamation mark
                            dc i1'vidchar~inverse~double_quote'     ; Double quotes (or speech marks)
                            dc i1'vidchar~inverse~hash'             ; Number sign
                            dc i1'vidchar~inverse~dollar'           ; Dollar
                            dc i1'vidchar~inverse~percent'          ; Per cent sign
                            dc i1'vidchar~inverse~ampersand'        ; Ampersand
                            dc i1'vidchar~inverse~single_quote'     ; Single quote
                            dc i1'vidchar~inverse~open_paren'       ; Open parenthesis (or open bracket)
                            dc i1'vidchar~inverse~close_paren'      ; Close parenthesis (or close bracket)
                            dc i1'vidchar~inverse~star'             ; Asterisk
                            dc i1'vidchar~inverse~plus'             ; Plus
                            dc i1'vidchar~inverse~comma'            ; Comma
                            dc i1'vidchar~inverse~minus'            ; Hyphen-minus
                            dc i1'vidchar~inverse~period'           ; Period, dot or full stop
                            dc i1'vidchar~inverse~forward_slash'    ; Slash or divide
                            dc i1'vidchar~inverse~0'                ; Zero
                            dc i1'vidchar~inverse~1'                ; One
                            dc i1'vidchar~inverse~2'                ; Two
                            dc i1'vidchar~inverse~3'                ; Three
                            dc i1'vidchar~inverse~4'                ; Four
                            dc i1'vidchar~inverse~5'                ; Five
                            dc i1'vidchar~inverse~6'                ; Six
                            dc i1'vidchar~inverse~7'                ; Seven
                            dc i1'vidchar~inverse~8'                ; Eight
                            dc i1'vidchar~inverse~9'                ; Nine
                            dc i1'vidchar~inverse~colon'            ; Colon
                            dc i1'vidchar~inverse~semi_colon'       ; Semicolon
                            dc i1'vidchar~inverse~less_than'        ; Less than (or open angled bracket)
                            dc i1'vidchar~inverse~equals'           ; Equals
                            dc i1'vidchar~inverse~greater_than'     ; Greater than (or close angled bracket)
                            dc i1'vidchar~inverse~question'         ; Question mark
                            dc i1'vidchar~inverse~at'               ; At sign
                            dc i1'vidchar~inverse~upper~a'          ; Uppercase A
                            dc i1'vidchar~inverse~upper~b'          ; Uppercase B
                            dc i1'vidchar~inverse~upper~c'          ; Uppercase C
                            dc i1'vidchar~inverse~upper~d'          ; Uppercase D
                            dc i1'vidchar~inverse~upper~e'          ; Uppercase E
                            dc i1'vidchar~inverse~upper~f'          ; Uppercase F
                            dc i1'vidchar~inverse~upper~g'          ; Uppercase G
                            dc i1'vidchar~inverse~upper~h'          ; Uppercase H
                            dc i1'vidchar~inverse~upper~i'          ; Uppercase I
                            dc i1'vidchar~inverse~upper~j'          ; Uppercase J
                            dc i1'vidchar~inverse~upper~k'          ; Uppercase K
                            dc i1'vidchar~inverse~upper~l'          ; Uppercase L
                            dc i1'vidchar~inverse~upper~m'          ; Uppercase M
                            dc i1'vidchar~inverse~upper~n'          ; Uppercase N
                            dc i1'vidchar~inverse~upper~o'          ; Uppercase O
                            dc i1'vidchar~inverse~upper~p'          ; Uppercase P
                            dc i1'vidchar~inverse~upper~q'          ; Uppercase Q
                            dc i1'vidchar~inverse~upper~r'          ; Uppercase R
                            dc i1'vidchar~inverse~upper~s'          ; Uppercase S
                            dc i1'vidchar~inverse~upper~t'          ; Uppercase T
                            dc i1'vidchar~inverse~upper~u'          ; Uppercase U
                            dc i1'vidchar~inverse~upper~v'          ; Uppercase V
                            dc i1'vidchar~inverse~upper~w'          ; Uppercase W
                            dc i1'vidchar~inverse~upper~x'          ; Uppercase X
                            dc i1'vidchar~inverse~upper~y'          ; Uppercase Y
                            dc i1'vidchar~inverse~upper~z'          ; Uppercase Z
                            dc i1'vidchar~inverse~open_square_bracket' ;Opening bracket
                            dc i1'vidchar~inverse~backslash'        ; Backslash
                            dc i1'vidchar~inverse~close_square_bracket' ; Closing bracket
                            dc i1'vidchar~inverse~caret'            ; Caret - circumflex
                            dc i1'vidchar~inverse~underscore'       ; Underscore
                            dc i1'vidchar~inverse~accent'           ; Grave accent
                            dc i1'vidchar~inverse~lower~a'          ; Lowercase a
                            dc i1'vidchar~inverse~lower~b'          ; Lowercase b
                            dc i1'vidchar~inverse~lower~c'          ; Lowercase c
                            dc i1'vidchar~inverse~lower~d'          ; Lowercase d
                            dc i1'vidchar~inverse~lower~e'          ; Lowercase e
                            dc i1'vidchar~inverse~lower~f'          ; Lowercase f
                            dc i1'vidchar~inverse~lower~g'          ; Lowercase g
                            dc i1'vidchar~inverse~lower~h'          ; Lowercase h
                            dc i1'vidchar~inverse~lower~i'          ; Lowercase i
                            dc i1'vidchar~inverse~lower~j'          ; Lowercase j
                            dc i1'vidchar~inverse~lower~k'          ; Lowercase k
                            dc i1'vidchar~inverse~lower~l'          ; Lowercase l
                            dc i1'vidchar~inverse~lower~m'          ; Lowercase m
                            dc i1'vidchar~inverse~lower~n'          ; Lowercase n
                            dc i1'vidchar~inverse~lower~o'          ; Lowercase o
                            dc i1'vidchar~inverse~lower~p'          ; Lowercase p
                            dc i1'vidchar~inverse~lower~q'          ; Lowercase q
                            dc i1'vidchar~inverse~lower~r'          ; Lowercase r
                            dc i1'vidchar~inverse~lower~s'          ; Lowercase s
                            dc i1'vidchar~inverse~lower~t'          ; Lowercase t
                            dc i1'vidchar~inverse~lower~u'          ; Lowercase u
                            dc i1'vidchar~inverse~lower~v'          ; Lowercase v
                            dc i1'vidchar~inverse~lower~w'          ; Lowercase w
                            dc i1'vidchar~inverse~lower~x'          ; Lowercase x
                            dc i1'vidchar~inverse~lower~y'          ; Lowercase y
                            dc i1'vidchar~inverse~lower~z'          ; Lowercase z
                            dc i1'vidchar~inverse~open_curley_bracket' ;Opening brace
                            dc i1'vidchar~inverse~vertical'         ; Vertical bar
                            dc i1'vidchar~inverse~close_curley_bracket' ; Closing brace
                            dc i1'vidchar~inverse~tilde'            ; Equivalency sign - tilde
                            dc i1'vidchar~non_printable'            ; Delete

ascii~newline                         equ $0a
ascii~return                          equ $0d
ascii~tab                             equ $09
ascii~space                           equ $20
ascii~comma                           equ $2c
ascii~dash                            equ $2d
ascii~period                          equ $2e
ascii~forward_slash                   equ $2f

; Extended ascii values, to map mousetext and inverse characters
ascii~mousetext_set                   equ $80
ascii~mousetext~closed_apple          equ ascii~mousetext_set+$00
ascii~mousetext~open_apple            equ ascii~mousetext_set+$01
ascii~mousetext~pointer               equ ascii~mousetext_set+$02
ascii~mousetext~hour_glass            equ ascii~mousetext_set+$03
ascii~mousetext~check                 equ ascii~mousetext_set+$04
ascii~mousetext~check_inverted        equ ascii~mousetext_set+$05
ascii~mousetext~return_inverted       equ ascii~mousetext_set+$06
ascii~mousetext~title_bar             equ ascii~mousetext_set+$07
ascii~mousetext~left_arrow            equ ascii~mousetext_set+$08
ascii~mousetext~ellipses              equ ascii~mousetext_set+$09
ascii~mousetext~down_arrow            equ ascii~mousetext_set+$0a
ascii~mousetext~up_arrow              equ ascii~mousetext_set+$0b
ascii~mousetext~box_bottom            equ ascii~mousetext_set+$0c
ascii~mousetext~return                equ ascii~mousetext_set+$0d
ascii~mousetext~inverted_block        equ ascii~mousetext_set+$0e
ascii~mousetext~scrollbar_left_arrow  equ ascii~mousetext_set+$0f
ascii~mousetext~scrollbar_right_arrow equ ascii~mousetext_set+$10
ascii~mousetext~scrollbar_down_arrow  equ ascii~mousetext_set+$11
ascii~mousetext~scrollbar_up_arrow    equ ascii~mousetext_set+$12
ascii~mousetext~horizontal_bar        equ ascii~mousetext_set+$13
ascii~mousetext~box_lower_left        equ ascii~mousetext_set+$14
ascii~mousetext~arrow_right           equ ascii~mousetext_set+$15
ascii~mousetext~hatch_1               equ ascii~mousetext_set+$16
ascii~mousetext~hatch_2               equ ascii~mousetext_set+$17
ascii~mousetext~folder_left           equ ascii~mousetext_set+$18
ascii~mousetext~folder_right          equ ascii~mousetext_set+$19
ascii~mousetext~box_right             equ ascii~mousetext_set+$1a
ascii~mousetext~diamond               equ ascii~mousetext_set+$1b
ascii~mousetext~scrollbar_horizontal  equ ascii~mousetext_set+$1c
ascii~mousetext~cross                 equ ascii~mousetext_set+$1d
ascii~mousetext~close_box             equ ascii~mousetext_set+$1e
ascii~mousetext~box_left              equ ascii~mousetext_set+$1f

hex_to_vidchar              anop
                            dc i1'vidchar~0'
                            dc i1'vidchar~1'
                            dc i1'vidchar~2'
                            dc i1'vidchar~3'
                            dc i1'vidchar~4'
                            dc i1'vidchar~5'
                            dc i1'vidchar~6'
                            dc i1'vidchar~7'
                            dc i1'vidchar~8'
                            dc i1'vidchar~9'
                            dc i1'vidchar~upper~a'
                            dc i1'vidchar~upper~b'
                            dc i1'vidchar~upper~c'
                            dc i1'vidchar~upper~d'
                            dc i1'vidchar~upper~e'
                            dc i1'vidchar~upper~f'

textscreen_ylookup          dc i2'$0400'
                            dc i2'$0480'
                            dc i2'$0500'
                            dc i2'$0580'
                            dc i2'$0600'
                            dc i2'$0680'
                            dc i2'$0700'
                            dc i2'$0780'
                            dc i2'$0428'
                            dc i2'$04A8'
                            dc i2'$0528'
                            dc i2'$05A8'
                            dc i2'$0628'
                            dc i2'$06A8'
                            dc i2'$0728'
                            dc i2'$07A8'
                            dc i2'$0450'
                            dc i2'$04D0'
                            dc i2'$0550'
                            dc i2'$05D0'
                            dc i2'$0650'
                            dc i2'$06D0'
                            dc i2'$0750'
                            dc i2'$07D0'
                            end

