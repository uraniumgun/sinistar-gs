                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/input.constants.asm
                            copy lib/source/file.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/ui.entity.definitions.asm
                            copy source/app.debug.definitions.asm

                            mcopy generated/high.score.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; The High Score screen

high_score_state_data       data seg_gameplay

high_score_state~display_time equ 60*10

high_score_state~last_tick  ds 4
high_score_state~countdown  ds 2

high_score_state~update_rate equ 1

; A definition for high score entry
                            begin_struct
score_def~score             decl dword              ; The 32bit BCD
score_def~initials          decl dword              ; 3 character initials, plus a 0, to round to 4 bytes
sizeof~score_def            end_struct

max_high_scores             equ 30

high_scores_changed         ds 2                    ; if not 0, the high scores have changed and need saving.

high_scores_filename        cstring '9:high.scores'

; These are saved
high_scores                 ds sizeof~score_def*max_high_scores
; These are just for the session
todays_high_scores          ds sizeof~score_def*max_high_scores

; Last Scores Offsets
; These are used to display the score in the red.
; For the 'saved' table
player_last_high_score_saved_table_index ds 2*2          ; index+1 into the table that should be 'red' for each player, using 0 if none.
; For the 'todays' table
player_last_high_score_todays_table_index ds 2*2

str_high_scores_sinistar    cstring 'SINI-STAR'
str_score_index_postfix     cstring '> '
str_saved_high_scores_title cstring 'SINIMMORTALS'          ; Not sure why the original had two m's, seems like one was enough.
str_todays_high_scores_title cstring 'SURVIVORS TODAY'
str_null_score_entry        cstring '000'

; The default scores for the "today's high scores section"
; These are from the original.  See HSTDIM.ASM from the historical source archive.

default_high_scores         anop
                            cstring 'GOD'
                            cstring 'KAY'
                            cstring 'HEC'
                            cstring 'SAM'
                            cstring 'KVD'
                            cstring 'N-F'
                            cstring 'KJF'
                            cstring 'KAG'
                            cstring 'FRG'
                            cstring 'YAK'
                            cstring 'JJK'
                            cstring 'KFL'
                            cstring 'PJM'
                            cstring 'DOC'
                            cstring 'JLM'
                            cstring 'E-Z'
                            cstring '=M='
                            cstring 'TIM'
                            cstring 'JRN'
                            cstring 'TOM'
                            cstring 'PFZ'
                            cstring 'RTP'
                            cstring 'BFD'
                            cstring 'MBS'
                            cstring 'MRS'
                            cstring 'EJS'
                            cstring 'STU'
                            cstring 'WIT'
                            cstring 'MOM'
                            cstring 'FAC'

                            end
; ----------------------------------------------------------------------------
high_score_state_initialize start seg_gameplay
                            using appdata
                            using high_score_state_data

                            debugtag 'high_score_state_initialize'

                            jsl high_score_reset
                            jsl high_score_read

                            rtl
                            end

; ----------------------------------------------------------------------------
high_score_state_activate   start seg_gameplay
                            using appdata
                            using applib_data
                            using high_score_state_data
                            using grlib_global_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            debugtag 'high_score_state_activate'

                            begin_locals
wX                          decl word
wY                          decl word
dwBCDScoreIndex             decl dword
spScores                    decl word
wScoreTableIndex            decl word
wRow1Y                      decl word
wColCountdown               decl word
wRowCountdown               decl word
wLastScorePlayer1Index      decl word
wLastScorePlayer2Index      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

top_score_score_x                       equ 120
top_score_initials_x                    equ 140
top_score_title_x                       equ 180
top_score_y                             equ 20

high_scores_saved_title_text_width      equ 79
high_scores_saved_title_text_x          equ 0+(320-high_scores_saved_title_text_width)/2
high_scores_saved_title_text_y          equ 40

high_scores_col_1_x                     equ 44
high_scores_initials_offset_x           equ 10
high_scores_score_offset_x              equ 60
high_scores_col_offset                  equ 80
high_scores_saved_start_y               equ 50

todays_high_scores_title_text_width     equ 100
todays_high_scores_title_text_x         equ 0+(320-todays_high_scores_title_text_width)/2
todays_high_scores_title_text_y         equ 120

todays_high_scores_col_1_x              equ high_scores_col_1_x
todays_high_scores_start_y              equ 130

                            lda #appdata~gameplay_color~effect1~bits
                            jsl grlib_fill_alt_screen

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~white~bits
                            jsl grlib_set_font_fore_color

                            pushdword high_scores+score_def~score
                            pushsword #top_score_score_x
                            pushsword #top_score_y
                            jsl grlib_draw_bcd32_right

                            pushdword #high_scores+score_def~initials
                            pushsword #top_score_initials_x
                            pushsword #top_score_y
                            jsl grlib_draw_string

                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_high_scores_sinistar
                            pushsword #top_score_title_x
                            pushsword #top_score_y
                            jsl grlib_draw_string

; Saved High Scores

; Title
                            pushptr #str_saved_high_scores_title
                            pushsword #high_scores_saved_title_text_x
                            pushsword #high_scores_saved_title_text_y
                            jsl grlib_draw_string

; The table
                            lda #high_scores
                            sta <spScores
                            lda #high_scores_col_1_x
                            sta <wX
                            lda #high_scores_saved_start_y
                            sta <wRow1Y
                            lda player_last_high_score_saved_table_index
                            sta <wLastScorePlayer1Index
                            lda player_last_high_score_saved_table_index+2
                            sta <wLastScorePlayer2Index
                            jsr draw_score_table

; Today's High Scores

; Title
                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

                            pushptr #str_todays_high_scores_title
                            pushsword #todays_high_scores_title_text_x
                            pushsword #todays_high_scores_title_text_y
                            jsl grlib_draw_string

; The table
                            lda #todays_high_scores
                            sta <spScores
                            lda #todays_high_scores_col_1_x
                            sta <wX
                            lda #todays_high_scores_start_y
                            sta <wRow1Y
                            lda player_last_high_score_todays_table_index
                            sta <wLastScorePlayer1Index
                            lda player_last_high_score_todays_table_index+2
                            sta <wLastScorePlayer2Index
                            jsr draw_score_table

; Show the screen
                            pushsword #gameplay_ui~palette_id~high_score
                            jsl gameplay_ui_show_screen

                            getdword >applib~current_tick,high_score_state~last_tick

                            lda #high_score_state~display_time
                            sta high_score_state~countdown

                            restoredatabank
                            ret

draw_score_table            anop

                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #1
                            sta <wScoreTableIndex                   ; for checking to see if the entry needs to be in red
                            sta <dwBCDScoreIndex                    ; for displaying the entry on screen
                            stz <dwBCDScoreIndex+2
                            lda #3                                  ; 3 columns
                            sta <wColCountdown

column_loop                 anop
                            lda #10                                 ; 10 rows
                            sta <wRowCountdown

                            lda <wRow1Y
                            sta <wY

row_loop                    anop
                            lda #appdata~gameplay_color~blue_gray~bits
                            jsl grlib_set_font_fore_color

                            pushdword <dwBCDScoreIndex
                            pushsword <wX
                            pushsword <wY
                            jsl grlib_draw_bcd32_right              ; need a bcd16_right

                            pushdword #str_score_index_postfix
                            pushsword <wX
                            pushsword <wY
                            jsl grlib_draw_string

; If the entry is one of the 'last scores', so in red
                            lda <wScoreTableIndex
                            cmp <wLastScorePlayer1Index
                            beq show_red
                            cmp <wLastScorePlayer2Index
                            bne show_yellow
show_red                    lda #appdata~gameplay_color~red~bits
                            bra set_entry_color
show_yellow                 lda #appdata~gameplay_color~light_yellow~bits
set_entry_color             jsl grlib_set_font_fore_color
; Initials
; Is the a null entry?
                            ldy #score_def~initials
                            lda (<spScores),y
                            beq null_initials
; Normal entry
                            pea high_scores|-16
                            lda <spScores
                            clc
                            adc #score_def~initials
                            pha
                            lda <wX
                            clc
                            adc #high_scores_initials_offset_x
                            pha
                            pushsword <wY
                            jsl grlib_draw_string
; Score
                            ldy #score_def~score+2
                            lda (<spScores),y
                            pha
                            ldy #score_def~score
                            lda (<spScores),y
                            pha
                            lda <wX
                            clc
                            adc #high_scores_score_offset_x
                            pha
                            pushsword <wY
                            jsl grlib_draw_bcd32_right
                            bra next

null_initials               anop
                            pushdword #str_null_score_entry
                            lda <wX
                            clc
                            adc #high_scores_initials_offset_x
                            pha
                            pushsword <wY
                            jsl grlib_draw_string

next                        inc <wScoreTableIndex
; Advance the display index
                            sed
                            lda <dwBCDScoreIndex
                            clc
                            adc #1
                            sta <dwBCDScoreIndex
                            cld

; Advance the entry pointer
                            lda <spScores
                            clc
                            adc #sizeof~score_def
                            sta <spScores

; Next row
                            lda <wY
                            clc
                            adc #appdata~font_teeny~height+1
                            sta <wY

                            dec <wRowCountdown
                            jne row_loop

; Next column
                            lda <wX
                            clc
                            adc #high_scores_col_offset
                            sta <wX

                            dec <wColCountdown
                            jne column_loop
                            rts

                            end

; ----------------------------------------------------------------------------
high_score_state_tick       start seg_gameplay
                            using appdata
                            using applib_data
                            using high_score_state_data

                            debugtag 'high_score_state_tick'

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            setlocaldatabank

; Get the tick delta
                            lda >applib~current_tick
                            sec
                            sbc high_score_state~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc high_score_state~last_tick+2
                            bne timer_expired                       ; If this happened, we got stuck for quite a while
                            cpx #high_score_state~update_rate
                            blt done

do_update                   lda >applib~current_tick
                            sta high_score_state~last_tick
                            lda >applib~current_tick+2
                            sta high_score_state~last_tick+2

; X has the tick delta, lower word
                            txa
                            negate a
                            clc
                            adc high_score_state~countdown
                            sta high_score_state~countdown
                            beq timer_expired
                            bpl continue                           ; still more to go?
;
timer_expired               anop
                            pushsword #app_state~high_scores
                            jsl frontend_set_next_state
                            bcc done
; restart
restart                     lda #high_score_state~display_time
                            sta high_score_state~countdown

continue                    anop
; Do other updates, while waiting
                            jsl snes_max_read_controller                    ; read the button state for the controller, if enabled.
                            jsl get_key_press
                            beq no_keypress
                            cmp #key~space
                            beq timer_expired
; Call the parent state, regardless of a key press or not, it may check the gamepad.
no_keypress                 anop
                            pha
                            jsl frontend_state_handle_input
; Do some housekeeping
                            jsl applib_update_fps
                            jsl appdebug_update_text_screen

done                        anop
                            restoredatabank
                            rtl

                            end

; ----------------------------------------------------------------------------
; Reset the high scores, both "saved" and "today's"
high_score_reset            start seg_gameplay
                            using high_score_state_data

                            debugtag 'high_score_reset'

                            setlocaldatabank
; Clear the scores to the defaults

; The saved high scores are zeroed out, as well as the initials.
                            ldx #sizeof~score_def*max_high_scores-8
loop                        stz high_scores+score_def~score,x
                            stz high_scores+score_def~score+2,x
                            stz high_scores+score_def~initials,x
                            stz high_scores+score_def~initials+2,x
                            txa
                            sec
                            sbc #sizeof~score_def
                            tax
                            bpl loop

; The markers for the last high scores too
                            stz player_last_high_score_saved_table_index
                            stz player_last_high_score_saved_table_index+2
                            stz player_last_high_score_todays_table_index
                            stz player_last_high_score_todays_table_index+2

                            jsr fill_default_high_scores

                            lda #1
                            sta high_scores_changed                                 ; set that the saved high scores have changed
                            restoredatabank

                            rtl
                            end

; -----------------------------------------------------------------------------
fill_default_high_scores    private seg_gameplay
                            using high_score_state_data

                            begin_locals
wBCDScore                   decl word
work_area_size              end_locals

                            lsub ,work_area_size

; From the original, the starting score is 19045, in bcd.
; It then reduces this value after each entry, though in a way that has a bit of a periodic pattern to it,
; rather than a fixed value.
; I didn't quite replicate the way the initials are chosen, the original had a small table of starting offsets into the table
; and picked from a random one of those as the start.  I'm just picking a random starting offset in the whole list and
; going from there.

starting_score              equ $9045

                            lda #starting_score
                            sta <wBCDScore

; Pick a random location in the table to start at
                            jsl math~rnd_generate
                            and #$00ff
                            ldx #max_high_scores
                            jsl math~umul1r2
                            xba                                         ; upper byte is the contains a mod of the count
                            and #$00ff

                            asl a
                            asl a
                            tax

                            ldy #0
loop                        lda default_high_scores,x
                            sta todays_high_scores+score_def~initials,y
                            lda default_high_scores+2,x
                            sta todays_high_scores+score_def~initials+2,y
                            lda #$0001
                            sta todays_high_scores+score_def~score+2,y
                            lda <wBCDScore
                            sta todays_high_scores+score_def~score,y
; So the original did this bit of odd code, even though they have 16-bit decimal math available.
; This will essentially subtract 365 in decimal, but it will do it on the lower byte, and the upper byte separately and with no carry.
; It also uses add so the value wraps, to perform the subtraction.  The result is that it sometimes subtracts 365 and sometimes 265.
; I guess this makes it so the values are not obviously in a sequence.  Overall, we just want the upper byte to go down, the lower one
; really doesn't matter what it is.
; I'm keen to replicate the look of the original, so...
                            sed
                            shortm
                            lda <wBCDScore
                            clc
                            adc #$35
                            sta <wBCDScore
                            lda <wBCDScore+1
                            clc
                            adc #$97                                ; subtract 3, by adding 97 and wrapping
                            sta <wBCDScore+1
                            longm
                            cld

                            tya
                            clc
                            adc #sizeof~score_def
                            cmp #sizeof~score_def*max_high_scores
                            bge done
                            tay
                            txa
                            clc
                            adc #4
                            tax
                            cpx #4*max_high_scores
                            blt loop
                            ldx #0                  ; set to the first entry
                            bra loop

done                        lret

                            end

; -----------------------------------------------------------------------------
; Check to see if a score could be added to one of the high score tables.
; Note, an input of 0 will always return 'no'.
;
; Parameters:
;   dwScore       - the 32-bit BCD score.
; Returns:
; carry clear, yes, set, no
high_score_check            start seg_gameplay
                            using high_score_state_data

                            begin_locals
spScoreTable                decl word
wIndex                      decl word
work_area_size              end_locals

                            sub (4:dwScore),work_area_size

                            setlocaldatabank

; A score of zero doesn't get recorded.  This also allows for just clearing the player state scores for players that are not in the game.
                            lda <dwScore
                            ora <dwScore+2
                            bne not_zero
                            sec
                            bra exit

not_zero                    ldy #high_scores
                            jsr is_high_score
                            bcc exit

                            ldy #todays_high_scores
                            jsr is_high_score
exit                        restoredatabank
                            retkc

;;
is_high_score               anop
                            sty <spScoreTable
                            lda #max_high_scores
                            sta <wIndex

loop                        lda <dwScore+2
                            cmpword {y},#score_def~score+2
                            blt next
                            beq check_low
; we are greater
                            clc
                            rts
check_low                   lda <dwScore
                            cmpword {y},#score_def~score
                            blt next
; we are greater or equal
                            clc
                            rts

next                        tya
                            clc
                            adc #sizeof~score_def
                            tay
                            dec <wIndex
                            bne loop
                            sec
                            rts

                            end

; -----------------------------------------------------------------------------
; Add a score to the high score tables
; Parameters:
;   dwPlayer      - player index (0 or 1)
;   dwInitials    - the initials to add.  A three character string, upper case please.
;   dwScore       - the 32-bit BCD score.
;
high_score_add              start seg_gameplay
                            using high_score_state_data

                            begin_locals
spScoreTable                decl word
wIndex                      decl word
work_area_size              end_locals

                            sub (2:wPlayer,4:dwInitials,4:dwScore),work_area_size

                            setlocaldatabank

                            asl <wPlayer

; Add to the saved high scores
                            ldy #high_scores
                            jsr add_to_table
                            ldy <wPlayer
                            sta player_last_high_score_saved_table_index,y
                            cmp #0
                            beq not_changed
                            inc high_scores_changed                         ; if not 0, mark that the high_scores changed
; If player 2, we need to see if we inserted before any player 1 score and push theirs up.
                            cpy #0
                            beq not_changed
                            cmp player_last_high_score_saved_table_index
                            beq push_up                                     ; same location, push up
                            bge not_changed                                 ; greater, we're ok
push_up                     lda player_last_high_score_saved_table_index
                            inc a
                            cmp #max_high_scores+1
                            blt ok_shift
                            lda #0                                          ; off the end
ok_shift                    sta player_last_high_score_saved_table_index
not_changed                 anop

; Add to the "today's" scores
                            ldy #todays_high_scores
                            jsr add_to_table
                            ldy <wPlayer
                            sta player_last_high_score_todays_table_index,y
; Need to do the same check to see if we pushed player 1's index
                            cmp #0
                            beq exit
                            cpy #0
                            beq exit
                            cmp player_last_high_score_todays_table_index
                            beq push_todays_up                              ; same location, push up
                            bge exit                                        ; greater, we're ok
push_todays_up              lda player_last_high_score_todays_table_index
                            inc a
                            cmp #max_high_scores+1
                            blt ok_shift_todays
                            lda #0                                          ; off the end
ok_shift_todays             sta player_last_high_score_todays_table_index
exit                        anop

                            restoredatabank
                            ret

;;
; Local function to add to a high score table
; Returns the index the score was added at
add_to_table                anop
                            stz <wIndex
                            sty <spScoreTable

loop                        lda <dwScore+2
                            cmpword {y},#score_def~score+2
                            blt next
                            beq check_low
                            bra found
check_low                   lda <dwScore
                            cmpword {y},#score_def~score
                            bge found

next                        tya
                            clc
                            adc #sizeof~score_def
                            tay
                            inc <wIndex
                            lda <wIndex
                            cmp #max_high_scores
                            blt loop
                            stz <wIndex
                            bra not_in_table

; We are greater than or equal to the current entry.  Insert!
found                       phy

; point X to end - 2
                            lda #(max_high_scores-2)*sizeof~score_def
                            clc
                            adc <spScoreTable
                            tax
; and Y to end - 1
                            clc
                            adc #sizeof~score_def
                            tay

                            lda #max_high_scores-1
                            sec
                            sbc <wIndex
                            beq was_last
                            shiftleft 3                 ; sizeof~score_def == 8
                            dec a                       ; mvp wants size - 1
                            mvp high_scores,high_scores ; This is just using the bank

was_last                    anop
; Put in the new score / initials
                            ply
                            lda <dwScore
                            putword {y},#score_def~score
                            lda <dwScore+2
                            putword {y},#score_def~score+2
                            lda <dwInitials
                            putword {y},#score_def~initials
                            lda <dwInitials+2
                            putword {y},#score_def~initials+2

                            inc <wIndex                 ; return one-based index

not_in_table                lda <wIndex
                            rts
                            end

; -----------------------------------------------------------------------------
; Write the saved high scores.
; This will check the high_scores_changed, to see if the scores need saving
; and will reset it to 0, after writing.
high_score_write            start seg_gameplay
                            using file_manager_data
                            using high_score_state_data

                            begin_locals
pFileWriter                 decl ptr
file_desc                   decl sizeof~file_descriptor
name_object                 decl sizeof~string_object
work_area_size              end_locals

                            debugtag 'high_score_write'
                            sub ,work_area_size

                            setlocaldatabank
                            lda high_scores_changed
                            beq skip_save

                            pushlocalptr #name_object
                            pushptr #high_scores_filename
                            jsl string_object_construct_zt

                            pushlocalptr #file_desc
                            jsl file_descriptor_construct

                            pushlocalptr #file_desc
                            pushlocalptr #name_object
                            pushsword #file_option~write
                            pushsword #file_type~game_document
                            pushsword #0
                            jsl file_descriptor_create
                            bne failed_to_create

                            pushlocalptr #file_desc
                            jsl file_writer_new_with_desc
                            bcs failed_new_file_writer
                            putretptr <pFileWriter

                            jsr write_high_scores_to_buffer

                            pushptr <pFileWriter
                            jsl file_writer_delete                      ; this will flush the buffer

                            pushlocalptr #file_desc
                            jsl file_descriptor_destruct                ; close the file

                            pushlocalptr #name_object
                            jsl string_object_destruct

skip_save                   clc
exit                        anop
                            restoredatabank
                            retkc

failed_to_create            pushlocalptr #name_object
                            jsl string_object_destruct
                            sec
                            bra exit

failed_new_file_writer      anop
                            pushlocalptr #file_desc
                            jsl file_descriptor_destruct
                            bra failed_to_create        ; clean up the string too.

;; Local function
write_high_scores_to_buffer anop

                            pushptr <pFileWriter                        ; assumes that ACC will not change
                            pushptr #high_scores
                            pushsword #sizeof~score_def*max_high_scores
                            jsl file_writer_append
                            bcs failed_write
                            stz high_scores_changed
failed_write                rts

                            end

; -----------------------------------------------------------------------------
high_score_read             start seg_gameplay
                            using textlib_global_data
                            using high_score_state_data

                            begin_locals
failed                      decl word
pReader                     decl ptr
wBufferSize                 decl word
file_desc                   decl sizeof~file_descriptor
name_object                 decl sizeof~string_object
work_area_size              end_locals

                            debugtag 'high_score_read'
                            sub ,work_area_size

                            setlocaldatabank

                            lda #1
                            sta <failed                                     ; assume we failed

                            pushlocalptr #name_object
                            pushptr #high_scores_filename
                            jsl string_object_construct_zt

                            pushlocalptr #file_desc
                            jsl file_descriptor_construct

                            pushlocalptr #file_desc
                            pushlocalptr #name_object
                            jsl file_descriptor_open
                            bne failed_to_open

                            pushlocalptr #file_desc
                            jsl file_reader_new_with_desc
                            bcs reader_failed
                            putretptr <pReader
; Is the file size correct
                            lda <file_desc+file_descriptor~length
                            cmp #sizeof~score_def*max_high_scores
                            bne reader_failed

                            pushptr <pReader
                            pushptr #high_scores
                            pushdword #sizeof~score_def*max_high_scores
                            jsl file_reader_put_in_buffer
                            bcs read_error
; Parse
                            jsr validate_scores
                            stz <failed

read_error                  anop

reader_failed               anop
                            pushlocalptr #file_desc
                            jsl file_descriptor_close

failed_to_open              anop
                            pushlocalptr #name_object
                            jsl string_object_destruct

                            restoredatabank
                            lsr <failed                         ; Move the failed flag into the carry
                            retkc

;; Local funciton
validate_scores             anop
                            ldy #0
; Make sure the initial has a 0 at after the third character
validate_loop               lda high_scores+score_def~initials+2,y
                            and #$00FF
                            sta high_scores+score_def~initials+2,y
; Maybe validate that the score is BCD?
                            tya
                            clc
                            adc #sizeof~score_def
                            tay
                            cpy #sizeof~score_def*max_high_scores
                            blt validate_loop

                            stz high_scores_changed
                            rts
                            end
