; The font format:
; It is somewhat modeled on the CYFont format, which was itself modeled on the IIgs font format
; so, full circle.  It is a pixel map font, not a bit map, and the pixels are standard 4-bit
; as we are only supporting 320x200 mode.  The font pixels are either 0 or F, though I may
; support pre-colored pixels.  The font 'strike' is one row, so the top pixel for all the characters
; are on the same line.
;
; The offset and width tables at the end of the header define all 256 possible characters (we are sticking with EFIGS!)
; I thought about having it only use a range of first to last character, but really, the arrays are not what is taking
; up a lot of space and having them fixed is simpler.

; On disk, this version number is the first word
font_file_header_current_version        gequ 1

font_file_header                        gequ 0
sizeof~font_file_header                 gequ font_file_header+2

font_header~info                        gequ 0
font_header~char_pix_width              gequ font_header~info+2
font_header~char_pix_height             gequ font_header~char_pix_width+2
font_header~row_bytes                   gequ font_header~char_pix_height+2      ; The number of bytes to the next row of pixels
font_header~odd_row_bytes               gequ font_header~row_bytes+2            ; The number of bytes to the next row of pixels, in the odd strike
font_header~ascent                      gequ font_header~odd_row_bytes+2        ; The number of pixels that are above the baseline of the font
font_header~decent                      gequ font_header~ascent+2               ; The number of pixels that are below the baseline of the font
font_header~first_char                  gequ font_header~decent+2               ; First printable character in the strike
font_header~last_char                   gequ font_header~first_char+2           ; Last printable character + 1 in the strike
font_header~strike_offset               gequ font_header~last_char+2            ; Offset, from the top of the header, to the strike pixel data.  Usually right after the header, but don't assume so.
font_header~odd_strike_offset           gequ font_header~strike_offset+2        ; Offset, from the top of the header, to the odd strike data
font_header~mask_offset                 gequ font_header~odd_strike_offset+2    ; Offset, from the start of the strike data, to the mask offset.  If 0, there is no mask.
font_header~odd_mask_offset             gequ font_header~mask_offset+2          ; Offset, from the start of the odd strike data, to the mask offset.  If 0, there is no mask.
; The start of character array tables.  Each is (256 * 2) bytes
font_header~character_tables            gequ font_header~odd_mask_offset+2
font_table~strike_widths                gequ 0
font_header~strike_widths               gequ font_header~character_tables+font_table~strike_widths ; An array of words, with the pixel width of the character.  Can all be the same in a mono-spaced font, though 0 means no character defined for the index
font_table~character_offsets            gequ 1*(256*2)
font_header~character_offsets           gequ font_header~character_tables+font_table~character_offsets ; Number of pixels to offset the x draw position, before drawing the character
font_table~character_advances           gequ 2*(256*2)
font_header~character_advances          gequ font_header~character_tables+font_table~character_advances ; Number of pixels to advance the x draw position, after drawing the character.  Does not include the offset.
font_table~strike_byte_offsets          gequ 3*(256*2)
font_header~strike_byte_offsets         gequ font_header~character_tables+font_table~strike_byte_offsets ; An array of words, with the *byte* offset to the character's first pixel.  This has an entry for all 256 possible characters
font_table~odd_strike_byte_offsets      gequ 4*(256*2)
font_header~odd_strike_byte_offsets     gequ font_header~character_tables+font_table~odd_strike_byte_offsets ; An array of words, with the *byte* offset to the character's first pixel in the odd strike.  This has an entry for all 256 possible characters
sizeof~font_header                      gequ font_header~odd_strike_byte_offsets+(256*2)
; The pixelmap for the font is immediately after the header

; Font Info Bits
;
; If set, the strike pixels are packed, in that they use the minimum number of pixels.
; The character_offsets need to be used, to position the character before drawing
; and the character_advances should be used to move the position to where the next
; character should be placed.
; If this is off, the characters are pre-offset in the strike and the pixels
; in the strike, contain the 'dead space' on the left, up to what the offset would be,
; and on the right, up to the defined width.
; It will mean that strike_widths and character_advances will be the same and
; all the offsets in the offset table are 0, however, this does *not* mean
; each character is the same width.  Check the mono_spaced flag for that.
; Note that packed or not, for the IIgs format, the font strike has
; the first pixel of the character, always in the left-most pixel,
; i.e. it is formatted to draw correctly on 'even' X values.
font_header~info~packed_strike          gequ $0001
; If set, all the widths of the characters are the same, char_pix_width.
; If this is off, char_pix_width is the maximum width of a character.
font_header~info~mono_spaced            gequ $0002

; Definition of some of the pointers when a font is 'active'
; These are usually offsets from a DP value.

grlib~font_dp_def                       gequ 0
grlib~font_ptr                          gequ grlib~font_dp_def
grlib~font_character_tables_ptr         gequ grlib~font_ptr+4                   ; Pointer to the top of the character tables.
grlib~font_strike_ptr                   gequ grlib~font_character_tables_ptr+4
grlib~font_odd_strike_ptr               gequ grlib~font_strike_ptr+4
grlib~font_char_pix_height              gequ grlib~font_odd_strike_ptr+4
grlib~font_strike_rowbytes              gequ grlib~font_char_pix_height+2
grlib~font_strike_mask_offset           gequ grlib~font_strike_rowbytes+2
grlib~font_odd_strike_rowbytes          gequ grlib~font_strike_mask_offset+2
grlib~font_odd_strike_mask_offset       gequ grlib~font_odd_strike_rowbytes+2
sizeof~grlib~font_dp_def                gequ grlib~font_odd_strike_mask_offset+2
