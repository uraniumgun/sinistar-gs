                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/string.definitions.asm
                                copy lib/source/tokenizer.definitions.asm

                                mcopy generated/tokenizer.macros

                                longa on
                                longi on
; --------------------------------------------------------------------------------------------
; A simple string tokenizer

; --------------------------------------------------------------------------------------------
; Construct a tokenizer
; Parameters:
; pTokenizer    - the tokenizer to construct
; pBuffer       - the buffer to tokenize.  The tokenizer will not own this buffer, nor will it modify it
;                 It does not have to be null terminated.
; wBufferSize   - the size of the parseable data in the buffer.
tokenizer_construct             start seg_clib
                                using textlib_global_data

                                begin_locals
work_area_size                  end_locals

                                debugtag 'construct_tokenizer'

                                sub (4:pTokenizer,4:pBuffer,2:wBufferSize),work_area_size

                                lda #0
                                putword [<pTokenizer],#tokenizer~offset
                                putword [<pTokenizer],#tokenizer~last_token_offset
                                putword [<pTokenizer],#tokenizer~last_token_size
                                putword [<pTokenizer],#tokenizer~last_char

                                lda <pBuffer
                                putword [<pTokenizer],#tokenizer~buffer
                                lda <pBuffer+2
                                putword [<pTokenizer],#tokenizer~buffer+2
                                lda <wBufferSize
                                putword [<pTokenizer],#tokenizer~size

                                ret
                                end

; --------------------------------------------------------------------------------------------
; Get the next token, starting at the current offset.
; Parameters:
; pTokenizer    - the tokenizer
; Returns:
; carry clear if a token found.  The offset in the buffer in A and the length of the token in X
; carry set if no token found.
tokenizer_get_next              start seg_clib
                                using textlib_global_data

                                begin_locals
pBuffer                         decl ptr
wBufferSize                     decl word
wTokenStart                     decl word
wTokenSize                      decl word
work_area_size                  end_locals

                                debugtag 'get_next_tokenizer'

                                sub (4:pTokenizer),work_area_size

                                stz <wTokenSize

                                getptr [<pTokenizer],#tokenizer~buffer,<pBuffer
                                getword [<pTokenizer],#tokenizer~size
                                sta <wBufferSize
                                getword [<pTokenizer],#tokenizer~offset
                                cmp <wBufferSize
                                blt not_at_end
                                sec
                                bra exit

not_at_end                      anop
; Get the current character
                                tay
                                shortm
                                lda [<pBuffer],y
                                longm
                                and #$00ff
                                beq at_eol                  ; not expecting 0, but check for it anyway

; Skip any separators, as well as testing for the eol
                                jsr skip_separators
                                bcs at_eol

; At start of token
                                sty <wTokenStart
token_loop                      inc <wTokenSize

                                iny
                                shortm
                                lda [<pBuffer],y
                                longm
                                and #$00ff
                                beq end_token                   ; not expecting 0, but check for it anyway

                                cmp #ascii~return
                                beq end_token
                                cmp #ascii~newline
                                beq end_token

; Separator?
                                cmp #' '
                                beq end_token
                                cmp #ascii~tab
                                beq end_token
                                bra token_loop

end_token                       pha
                                tya
                                putword [<pTokenizer],#tokenizer~offset
                                lda <wTokenStart
                                putword [<pTokenizer],#tokenizer~last_token_offset
                                lda <wTokenSize
                                putword [<pTokenizer],#tokenizer~last_token_size
                                pla
                                putword [<pTokenizer],#tokenizer~last_char
                                clc
exit                            retkc 4:wTokenStart

at_eol                          pha
                                tya
                                putword [<pTokenizer],#tokenizer~offset
                                lda #0
                                putword [<pTokenizer],#tokenizer~last_token_offset
                                putword [<pTokenizer],#tokenizer~last_token_size
                                pla
                                putword [<pTokenizer],#tokenizer~last_char
                                sec
                                bra exit

;;
; Advance past any separators, with A being the current character
; Y contains the current offset, and will be advanced past any separtors, stopping at eol or non-separator characters.
; carry will be clear if there are remaining non-separator characters on the line, set if at the eol.
skip_separators                 anop
skip_separator_loop             cmp #ascii~return
                                beq skip_found_eol
                                cmp #ascii~newline
                                beq skip_found_eol

                                cmp #' '
                                beq is_separator
                                cmp #ascii~tab
                                beq is_separator
                                clc
                                rts

is_separator                    iny
                                cpy <wBufferSize
                                bge skip_found_eol

                                shortm
                                lda [<pBuffer],y
                                longm
                                and #$00ff
                                beq skip_found_eol
                                bra skip_separator_loop

skip_found_eol                  sec
                                rts

                                end

; --------------------------------------------------------------------------------------------
; Advance the tokenizer to the next line.
; Parameters:
; pTokenizer    - the tokenizer
; Returns:
; carry set if the tokenizer is at eob (end-of-buffer)
tokenizer_next_line             start seg_clib
                                using textlib_global_data

                                begin_locals
pBuffer                         decl ptr
wBufferSize                     decl word
work_area_size                  end_locals

                                debugtag 'next_line_tokenizer'

                                sub (4:pTokenizer),work_area_size

                                getptr [<pTokenizer],#tokenizer~buffer,<pBuffer
                                getword [<pTokenizer],#tokenizer~size
                                sta <wBufferSize
                                getword [<pTokenizer],#tokenizer~offset
                                cmp <wBufferSize
                                blt not_at_end
                                sec
                                bra exit

not_at_end                      anop
; Get the current character
                                tay
loop                            anop
                                shortm
                                lda [<pBuffer],y
                                longm
                                and #$00ff
                                beq at_eob                  ; not expecting 0, but check for it anyway

                                cmp #ascii~newline
                                beq at_eol
                                cmp #ascii~return
                                beq at_eol
                                iny
                                cpy <wBufferSize
                                blt loop

at_eob                          tya
                                putword [<pTokenizer],#tokenizer~offset
                                sec
exit                            retkc

at_eol                          anop
; Skip all eol characters.  Note this will end up skipping multiple lines, but that is usually what the caller wants
skip_eol                        iny
                                cpy <wBufferSize
                                bge at_eob

eol_loop                        anop
                                shortm
                                lda [<pBuffer],y
                                longm
                                and #$00ff
                                beq at_eob                  ; not expecting 0, but check for it anyway

                                cmp #ascii~newline
                                beq skip_eol
                                cmp #ascii~return
                                beq skip_eol
                                pha
                                tya
                                putword [<pTokenizer],#tokenizer~offset
                                pla
                                putword [<pTokenizer],#tokenizer~last_char
                                clc
                                bra exit

                                end

