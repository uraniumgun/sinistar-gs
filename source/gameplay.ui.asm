                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/app.ui.definitions.asm

                            mcopy generated/gameplay.ui.macros

                            longa on
                            longi on

; Only used in this file and I need two globals
gameplay_ui_bombs_remaining_height gequ +(gameplay_ui_bombs_remaining_row_height*2)+1
gameplay_ui_bombs_remaining_width  gequ +(gameplay_ui_bombs_remaining_col_width*(gameplay_player~max_bomb_count/2))
gameplay_ui_bombs_top_screen_address gequ $2000+(gameplay_ui_bombs_remaining_y*160)
gameplay_ui_ships_top_screen_address gequ $2000+(gameplay_ui_ships_remaining_y*160)

; ----------------------------------------------------------------------------
gameplay_ui_data                    data seg_gameplay

gameplay_ui~last_drawn_bomb_count   ds 2
gameplay_ui~last_drawn_ship_count   ds 2

gameplay_ui~player_score_needs_update ds 2
gameplay_ui~ships_remaining_needs_update ds 2
gameplay_ui~player_bonus_at_needs_update ds 2

; Player messages.  These are displayed in the upper ui, and each player can have a different message
; There is a timer for how long the message is to be displayed, but if it is -1, it will be persisent.  i.e. for game over
gameplay_ui~player_message          ds 2*2
gameplay_ui~player_message_timer    ds 2*2
gameplay_ui~player_message_x        dc i'gameplay_ui_message_player_1_x,gameplay_ui_message_player_2_x'
gameplay_ui~player_offset_x         dc i'0,gameplay_ui_player_2_left_edge-gameplay_ui_player_1_left_edge'
gameplay_ui~player_byte_offset_x    dc i'0,(gameplay_ui_player_2_left_edge-gameplay_ui_player_1_left_edge)/2'
gameplay_ui~player_screen_byte_offset_x dc i'$2000+0,$2000+((gameplay_ui_player_2_left_edge-gameplay_ui_player_1_left_edge)/2)'

; This is filled with the screen byte x offset for an item in the player ui.
gameplay_ui~active_player_byte_offset_x ds 2

; Active ship blinking
gameplay_ui~ship_blink_rate             equ 60*1
gameplay_ui~active_ship_blink_timer     ds 2
gameplay_ui~active_ship_blink_state     ds 2                    ; 0 = show, 1 = hide

; Three lines of text for each message.  A line can be 0, to skip that line
gameplay_ui~player_messages_text1   dc a4'str_sinistar_is'
                                    dc a4'str_mine_crystals'
                                    dc a4'str_crystal_saved'
                                    dc a4'0'
                                    dc a4'0'
                                    dc a4'0'
                                    dc a4'0'
gameplay_ui~player_messages_text2   dc a4'str_now_in'
                                    dc a4'str_to_make'
                                    dc a4'str_for_warp'
                                    dc a4'str_sinibomb_attack'
                                    dc a4'str_sinibomb'
                                    dc a4'str_entering_swarm'
gameplay_ui~player_messages_text3   dc a4'str_scanner_range'
                                    dc a4'str_sinibombs'
                                    dc a4'str_engines'
                                    dc a4'str_damaged_target'
                                    dc a4'str_intercepted'
                                    dc a4'str_of_planetoids'

; Timers for each message, in ticks.  $ffff for no timer.
gameplay_ui~player_message_timers   dc i'5*60'
                                    dc i'5*60'
                                    dc i'5*60'
                                    dc i'5*60'
                                    dc i'5*60'
                                    dc i'5*60'

; Color of all the text.  Maybe have color codes?
gameplay_ui~player_messages_color   dc i'appdata~ui_color~yellow~bits'
                                    dc i'appdata~ui_color~dark_green~bits'
                                    dc i'appdata~ui_color~dark_green~bits'
                                    dc i'appdata~ui_color~dark_green~bits'
                                    dc i'appdata~ui_color~yellow~bits'
                                    dc i'appdata~ui_color~yellow~bits'

gameplay_ui~message_sinistar_in_scanner equ 1
gameplay_ui~message_no_bombs            equ 2
gameplay_ui~message_crystal_saved       equ 3                           ; no it isn't  hehe.
gameplay_ui~message_sinibomb_attack     equ 4                           ; hit sinistar
gameplay_ui~message_sinibomb_intercepted equ 5                          ; hit something else
gameplay_ui~message_planetoid_swarm     equ 6

gameplay_ui~full_screen_palette_slot equ 0

; Track what type of palette is applied to the screen.
; This helps determine if we need a 'screen clear' to prevent colors from flashing.
; This is because, even if we wait for the VBL to change the palette, getting new data to
; the screen is impossible to do in the VBL, especially if it is the entire screen, even with an accelerator.
gameplay_ui~palette_id~unknown      equ 0
gameplay_ui~palette_id~splash       equ 1
gameplay_ui~palette_id~playfield    equ 2
gameplay_ui~palette_id~config       equ 3
gameplay_ui~palette_id~high_score   equ 3

gameplay_ui~palette_applied         dc i'0'

; Set to a known amount, so we don't waste space/time
gameplay_ui~max_reserved_palettes    equ 3

; The reserved palettes, including the playfield one.
gameplay_ui~reserved_palette_count  dc i'0'
gameplay_ui~reserved_palettes       ds 2*gameplay_ui~max_reserved_palettes

gameplay_ui~paused_palettes_copy    ds gameplay_ui~max_reserved_palettes*sizeof~palette_scb
gameplay_ui~paused_palettes_darkened ds gameplay_ui~max_reserved_palettes*sizeof~palette_scb

gameplay_ui~paused_palettes_applied dc i'0'

; Note, currently only have space for 16 characters per line
str_bonus_at                        cstring 'BONUS AT '
str_sinistar_is                     cstring 'SINISTAR IS'
str_now_in                          cstring 'NOW IN'
str_scanner_range                   cstring 'SCANNER RANGE'
str_mine_crystals                   cstring 'MINE CRYSTALS'             ; Original display was MINE CRYSTAL TO MAKE SINIBOMB
str_to_make                         cstring 'TO MAKE'
str_sinibombs                       cstring 'SINIBOMBS'
str_crystal_saved                   cstring 'CRYSTAL SAVED'
str_for_warp                        cstring 'FOR WARP'
str_engines                         cstring 'ENGINES'
str_sinibomb_attack                 cstring 'SINIBOMB ATTACK'
str_damaged_target                  cstring 'DAMAGED TARGET'
str_sinibomb                        cstring 'SINIBOMB'
str_intercepted                     cstring 'INTERCEPTED'
str_entering_swarm                  cstring 'ENTERING SWARM'
str_of_planetoids                   cstring 'OF PLANETOIDS'

                            end

; ----------------------------------------------------------------------------
; Contains UI functions related to in-game.
; This includes the upper and lower sections, as well as any UI that is in the playfield area

; ----------------------------------------------------------------------------
; One time initialization
gameplay_ui_initialize      start seg_gameplay
                            using appdata
                            using grlib_global_data

                            debugtag 'ui_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
; One time, uninitialization
gameplay_ui_uninitialize    start seg_gameplay
                            using appdata
                            using grlib_global_data

                            debugtag 'ui_uninitialize'

                            rtl
                            end


; ----------------------------------------------------------------------------
; Activating a turn
gameplay_ui_turn_activate   start seg_gameplay
                            using appdata
                            using grlib_global_data

                            debugtag 'ui_turn_activate'

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            jsl gameplay_upper_ui_turn_activate
                            jsl gameplay_lower_ui_turn_activate

                            rtl
                            end

; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------

; ----------------------------------------------------------------------------
gameplay_upper_ui_turn_activate private seg_gameplay
                            using appdata
                            using grlib_global_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            debugtag 'upper_ui_turn_activate'

                            setlocaldatabank

; Setup an easy way to get the indent for the UI for the active player

                            lda gameplay_manager~active_player
                            asl a
                            tax
                            lda gameplay_ui~player_byte_offset_x,x
                            sta gameplay_ui~active_player_byte_offset_x

; Setup the active ship blink state
                            lda #gameplay_ui~ship_blink_rate
                            sta gameplay_ui~active_ship_blink_timer
                            stz gameplay_ui~active_ship_blink_state

; Clear the messages
                            ldx #0
loop                        stz gameplay_ui~player_message,x
                            stz gameplay_ui~player_message_timer,x
                            inx
                            inx
                            cpx #gameplay_max_players*2
                            bne loop

                            lda >appdata~ui_upper_shr_palette_slot
                            bpl got_palette

                            pushsword #$ffff
                            jsl gameplay_ui_palette_reserve
                            bcs error
                            sta >appdata~ui_upper_shr_palette_slot

got_palette                 anop
error                       anop
                            jsr gameplay_upper_ui_set_shr_palette
                            jsr gameplay_upper_ui_apply_palette_scbs
                            jsr gameplay_upper_ui_draw_all

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
; Set the shr palette for the upper UI.  Does not set the scbs!
gameplay_upper_ui_set_shr_palette private seg_gameplay
                            using appdata

                            lda >appdata~ui_upper_shr_palette_slot
                            bmi error
                            tax
                            lda >appdata~ui_upper_palette_ptr+2
                            beq use_default                         ; null?  (assuming we would never have a bank 0 address!)
                            pha
                            lda >appdata~ui_upper_palette_ptr
                            pha
doit                        phx

                            jsl grlib_set_shr_palette
error                       anop
                            rts

use_default                 pushptr #appdata~ui_default_palette
                            bra doit

                            end

; ----------------------------------------------------------------------------
; Set the scb palette slot for the upper UI scanlines
gameplay_upper_ui_apply_palette_scbs private seg_gameplay
                            using appdata

                            lda >appdata~ui_upper_shr_palette_slot
                            bmi error

                            pha
                            pushsword #0
                            pushsword #gameplay_ui_top_height
                            jsl grlib_set_scb_palette_range

error                       anop
                            rts

                            end

; ----------------------------------------------------------------------------
; Draw a remaining sinibomb image at a location, specified by X and the databank
; This is done 'compiled sprite'style.
_draw_remaining_sinibomb_at private seg_gameplay

; dc i1'$92,$29'
; dc i1'$29,$92'
; dc i1'$29,$92'
; dc i1'$92,$29'
                            loadpixels $9229
                            sta |$0000,x
                            sta |$0000+(3*160),x

                            loadpixels $2992
                            sta |$0000+(1*160),x
                            sta |$0000+(2*160),x

                            rts

                            end

; ----------------------------------------------------------------------------
; Draw all the remaining sinibombs for a player
; x - offset into the player_states to use
; y - player index (x 2)
_draw_player_remaining_sinibombs private seg_gameplay
                            using appdata
                            using YLookupData
                            using gameplay_manager_data
                            using gameplay_ui_data

; Get the player's left edge byte offset
                            pushsword {y},gameplay_ui~player_screen_byte_offset_x

                            getword {x},gameplay_manager~player_states+player_state~bomb_count
                            beq none

                            tay         ; counter in Y

                            phb
                            pushsword #$0101
                            plb
                            plb

                            cpy #(gameplay_player~max_bomb_count/2)+1
                            bge two_rows

stack_adjust                equ 1                           ; bytes on stack

one_row                     anop
                            lda #(gameplay_ui_bombs_remaining_player_1_x/2)+(gameplay_ui_bombs_remaining_y*160)
                            clc
                            adcword {s},#1+stack_adjust

loop                        tax
                            jsr _draw_remaining_sinibomb_at
                            dey
                            beq done

                            txa
                            clc
                            adc #(gameplay_ui_bombs_remaining_col_width/2)
                            bra loop

two_rows                    anop
; two rows, do the bottom first
                            lda #((gameplay_ui_bombs_remaining_row_height+1)*160)+(gameplay_ui_bombs_remaining_player_1_x/2)+(gameplay_ui_bombs_remaining_y*160)
                            clc
                            adcword {s},#1+stack_adjust

loop2                       tax
                            jsr _draw_remaining_sinibomb_at
                            dey
                            cpy #gameplay_player~max_bomb_count/2
                            beq one_row

                            txa
                            clc
                            adc #(gameplay_ui_bombs_remaining_col_width/2)
                            bra loop2

done                        anop

                            restoredatabank

                            pla                                                 ; clean up stack
                            rts

none                        anop

; Get the player's left edge x offset
                            getword {y},gameplay_ui~player_offset_x
                            putword {s},#1

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~ui_color~yellow~bits
                            jsl grlib_set_font_fore_color

                            pushdword #title_string
                            lda #gameplay_ui_bombs_remaining_player_1_x
                            clc
                            adcword {s},#1+4
                            pha
                            pushsword #gameplay_ui_bombs_remaining_y+8
                            jsl grlib_draw_string

                            pla                                                 ; clean up stack
                            rts

title_string                dc c'EMPTY',i1'0'
                            end

; ----------------------------------------------------------------------------
; Draw a remaining ship image at a location, specified by X and the databank
; This is done 'compiled sprite'style.
_draw_remaining_ship_at     private seg_gameplay

; This is drawing as-if I have to preserve the background, which I really don't
; I can assume the background is $0, and just store all directly.
; I am experimenting with how I might format compiled sprites in the future.
; Change this to just stores, eventually.

; dc i1'$00,$40,$00'
                            lda |$0000,x
                            maskpixels $FF0F
                            orpixels   $0040
                            sta |$0000,x

; dc i1'$00,$20,$00'
                            lda |$0000+(1*160),x
                            maskpixels $FF0F
                            orpixels   $0020
                            sta |$0000+(1*160),x

; dc i1'$02,$F5,$00'
                            lda |$0000+(2*160),x
                            maskpixels $F000
                            orpixels   $02F5
                            sta |$0000+(2*160),x

; dc i1'$52,$F6,$60'
                            loadpixels $52F6
                            sta |$0000+(3*160),x

                            lda |$0000+(3*160)+2,x
                            maskpixels $0FFF
                            orpixels   $6000
                            sta |$0000+(3*160)+2,x

; dc i1'$AA,$5A,$A0'
                            loadpixels $AA5A
                            sta |$0000+(4*160),x

                            lda |$0000+(4*160)+2,x
                            maskpixels $0FFF
                            orpixels   $A000
                            sta |$0000+(4*160)+2,x
                            rts

                            end

; ----------------------------------------------------------------------------
; Erase a remaining ship image at a location, specified by X and the databank

_erase_remaining_ship_at     private seg_gameplay

; The ship is 3 bytes wide. Do overlapping bytes.
; Since we are writing to screen memory (slow), maybe it would be better
; to do all the single bytes separately?  Probably not, I think it is more about the number of writes, rather than
; if it is 8 or 16-bits.

;
                            stz |$0000,x                        ; 5
                            stz |$0000+1,x                      ; 5

;
                            stz |$0000+(1*160),x                ; 5
                            stz |$0000+(1*160)+1,x              ; 5

;
                            stz |$0000+(2*160),x                ; 5
                            stz |$0000+(2*160)+1,x              ; 5

;
                            stz |$0000+(3*160),x                ; 5
                            stz |$0000+(3*160)+1,x              ; 5

;
                            stz |$0000+(4*160),x                ; 5
                            stz |$0000+(4*160)+1,x              ; 5
                            rts

                            end

; ----------------------------------------------------------------------------
; Draw all the remaining ships for a player
; x - offset into the player_states to use
; y - player index (x 2)
_draw_player_remaining_ships private seg_gameplay
                            using gameplay_manager_data
                            using gameplay_ui_data

; Get the player's left edge byte offset
                            pushsword {y},gameplay_ui~player_screen_byte_offset_x

                            getword {x},gameplay_manager~player_states+player_state~ship_count
                            beq none

                            cmp #gameplay_ui_ships_remaining_max_display+1
                            blt ok_count

                            lda #gameplay_ui_ships_remaining_max_display                        ; clamp
ok_count                    tay         ; counter in Y

                            phb
                            pushsword #$0101
                            plb
                            plb

stack_adjust                equ 1                           ; bytes on stack

                            lda #(gameplay_ui_ships_remaining_player_1_x/2)+(gameplay_ui_ships_remaining_y*160)
                            clc
                            adcword {s},#1+stack_adjust

loop                        tax
                            jsr _draw_remaining_ship_at
                            dey
                            beq done

                            txa
                            clc
                            adc #(gameplay_ui_ships_remaining_col_width/2)
                            bra loop

done                        anop

                            restoredatabank

none                        pla
                            rts
                            end

; ----------------------------------------------------------------------------
; Draw the score, in player 1's score area
; Parameters:
; x - offset into the player_states to use
; y - player index (x 2)
_draw_player_score          private seg_gameplay
                            using grlib_global_data
                            using appdata
                            using gameplay_manager_data
                            using gameplay_ui_data

; Get the player's left edge offset
                            pushsword {y},gameplay_ui~player_offset_x

; We can just push this now, for the  draw_bcd32_right
                            pushdword {x},gameplay_manager~player_states+player_state~score

                            lda #appdata~ui_color~red~bits
                            jsl grlib_set_font_fore_color

; Expensive!
                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #grlib~blit_mode_1
                            jsl grlib_set_font_blit_mode

stack_adjust                equ 4                                         ; 4 bytes on the stack ahead of the one we want

                            lda #gameplay_ui_score_player_1_x+gameplay_ui_score_width
                            clc
                            adcword {s},#1+stack_adjust
                            pha
                            pushsword #gameplay_ui_score_y+7                ; account for the font ascent
                            jsl grlib_draw_bcd32_right

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pla                                             ; discard saved player offset x

                            rts
                            end

; ----------------------------------------------------------------------------
; Draw Player 1's next bonus text
; Parameters:
; x - offset into the player_states to use
; y - player index (x 2)
_draw_player_bonus_at       private seg_gameplay
                            using gameplay_manager_data
                            using appdata
                            using grlib_global_data
                            using gameplay_ui_data

; Get the player's left edge offset
                            pushsword {y},gameplay_ui~player_offset_x

                            phx                     ; save the player data offset

                            lda #appdata~ui_color~blue~bits
                            jsl grlib_set_font_fore_color

; Expensive!
                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #grlib~blit_mode_1
                            jsl grlib_set_font_blit_mode

                            pushdword #str_bonus_at

stack_adjust                equ 2+4                 ; bytes on the stack

                            lda #gameplay_ui_bonus_at_player_1_x
                            clc
                            adcword {s},#1+stack_adjust
                            pha
                            pushsword #gameplay_ui_bonus_at_y+appdata~font_teeny~height
                            jsl grlib_draw_string
                            tay                     ; has the draw x offset

                            plx                     ; get the player data offset back
                            pushdword {x},gameplay_manager~player_states+player_state~next_ship_score
                            phy
                            pushsword #gameplay_ui_bonus_at_y+appdata~font_teeny~height
                            jsl grlib_draw_bcd32

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pla                     ; discard saved player left edge

                            rts
                            end

; ----------------------------------------------------------------------------
; Update the message area for a player
; Parameters:
; acc - player index
_update_message             private seg_gameplay
                            using gameplay_manager_data
                            using appdata
                            using grlib_global_data
                            using gameplay_ui_data

                            asl a
                            tax
                            stx player_index
                            lda gameplay_ui~player_message,x
                            jeq no_message

                            dec a
                            asl a
                            sta message_index

                            phx
                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr
                            lda #grlib~blit_mode_1
                            jsl grlib_set_font_blit_mode
                            plx

                            lda gameplay_ui~player_message_x,x
                            pha
                            pushsword #gameplay_ui_message_y
                            pushsword #gameplay_ui_message_width
                            pushsword #gameplay_ui_message_height
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

; line 1
                            ldy message_index
                            lda gameplay_ui~player_messages_color,y
                            jsl grlib_set_font_fore_color
                            lda message_index
                            asl a
                            tay
                            lda gameplay_ui~player_messages_text1+2,y
                            beq no_line1
                            pha
                            lda gameplay_ui~player_messages_text1,y
                            pha
                            ldy player_index
                            lda gameplay_ui~player_message_x,y
                            pha
                            pushsword #gameplay_ui_message_line_1_y
                            jsl grlib_draw_string
; line2
no_line1                    lda message_index
                            asl a
                            tay
                            lda gameplay_ui~player_messages_text2+2,y
                            beq no_line2
                            pha
                            lda gameplay_ui~player_messages_text2,y
                            pha
                            ldy player_index
                            lda gameplay_ui~player_message_x,y
                            pha
                            pushsword #gameplay_ui_message_line_2_y
                            jsl grlib_draw_string

; line3
no_line2                    lda message_index
                            asl a
                            tay
                            lda gameplay_ui~player_messages_text3+2,y
                            beq no_line3
                            pha
                            lda gameplay_ui~player_messages_text3,y
                            pha
                            ldy player_index
                            lda gameplay_ui~player_message_x,y
                            pha
                            pushsword #gameplay_ui_message_line_3_y
                            jsl grlib_draw_string

no_line3                    ldx player_index
                            stz gameplay_ui~player_message,x                        ; clear the message
                            ldy message_index
                            lda gameplay_ui~player_message_timers,y                 ; set the timer
                            sta gameplay_ui~player_message_timer,x
                            bra to_screen

no_message                  lda gameplay_ui~player_message_timer,x
                            beq no_clear
                            bmi no_clear

                            sec
                            sbc gameplay_manager_logic~tick_delta                   ; assume the delta is here.  Maybe pass it in?
                            sta gameplay_ui~player_message_timer,x
                            beq clear
                            bcs no_clear

clear                       stz gameplay_ui~player_message_timer,x

                            lda gameplay_ui~player_message_x,x
                            pha
                            pushsword #gameplay_ui_message_y
                            pushsword #gameplay_ui_message_width
                            pushsword #gameplay_ui_message_height
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

to_screen                   ldx player_index
                            lda gameplay_ui~player_message_x,x
                            pha
                            pushsword #gameplay_ui_message_y
                            pushsword #gameplay_ui_message_width
                            pushsword #gameplay_ui_message_height
                            jsl grlib_alt_screen_to_screen_rect

no_clear                    anop
exit                        anop
                            rts

player_index                ds 2
message_index               ds 2
                            end

; ----------------------------------------------------------------------------
gameplay_ui_set_active_player_message start seg_gameplay
                            using appdata
                            using gameplay_manager_data
                            using gameplay_ui_data

                            setlocaldatabank

                            pha
                            lda gameplay_manager~active_player
                            asl a
                            tax
                            pla
                            sta gameplay_ui~player_message,x
;                            dec a
;                            tay
;                            lda gameplay_ui~player_message_timers,y
;                            sta gameplay_ui~player_message_timer,x

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_upper_ui_draw_all  private seg_gameplay
                            using appdata
                            using gameplay_manager_data
                            using gameplay_ui_data

; We can assume the databank is local

; Erase the ui area
                            pushsword #0
                            pushsword #0
                            pushsword #grlib~screen_width
                            pushsword #gameplay_ui_top_height
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

; Draw player 1
                            ldx #gameplay_manager~player_1_state_offset
                            ldy #0*2
                            jsr _draw_player_remaining_sinibombs

                            ldx #gameplay_manager~player_1_state_offset
                            ldy #0*2
                            jsr _draw_player_remaining_ships

                            ldx #gameplay_manager~player_1_state_offset
                            ldy #0*2
                            jsr _draw_player_score

                            ldx #gameplay_manager~player_1_state_offset
                            ldy #0*2
                            jsr _draw_player_bonus_at

; Check player count
                            lda gameplay_manager~player_count
                            cmp #2
                            blt single_player

; Player 2

                            ldx #gameplay_manager~player_2_state_offset
                            ldy #1*2
                            jsr _draw_player_remaining_sinibombs

                            ldx #gameplay_manager~player_2_state_offset
                            ldy #1*2
                            jsr _draw_player_remaining_ships

                            ldx #gameplay_manager~player_2_state_offset
                            ldy #1*2
                            jsr _draw_player_score

                            ldx #gameplay_manager~player_2_state_offset
                            ldy #1*2
                            jsr _draw_player_bonus_at

single_player               anop

; Draw the fins first
                            jsr draw_scanner_fins

                            jsr draw_upper_frame

                            lda gameplay_manager~active_state+player_state~bomb_count
                            sta gameplay_ui~last_drawn_bomb_count

                            rts

                            end

; ----------------------------------------------------------------------------
draw_upper_frame            private seg_gameplay
                            using appdata
                            using gameplay_manager_data
                            using gameplay_ui_data
; Draw a dividing line
                            pushsword #0
                            pushsword #gameplay_ui_top_height-1
                            pushsword #grlib~screen_width
                            pushsword #1
;                            pushsword #appdata~ui_color~light_gray~bits
                            pushsword gameplay_manager~active_state+player_state~zone_color
                            jsl grlib_alt_screen_fill_rect

; Frame for the scanner
; Should really have the 'rect' draw better exposed.
; Top
                            pushsword #gameplay_ui_scanner_x-2
                            pushsword #gameplay_ui_scanner_y-1
                            pushsword #gameplay_ui_scanner_width+4
                            pushsword #1
                            pushsword gameplay_manager~active_state+player_state~zone_color
                            jsl grlib_alt_screen_fill_rect
; Left
                            pushsword #gameplay_ui_scanner_x-2
                            pushsword #gameplay_ui_scanner_y-1
                            pushsword #2
                            pushsword #gameplay_ui_scanner_height+1
                            pushsword gameplay_manager~active_state+player_state~zone_color
                            jsl grlib_alt_screen_fill_rect
; Right
                            pushsword #gameplay_ui_scanner_x+gameplay_ui_scanner_width
                            pushsword #gameplay_ui_scanner_y-1
                            pushsword #2
                            pushsword #gameplay_ui_scanner_height+1
                            pushsword gameplay_manager~active_state+player_state~zone_color
                            jsl grlib_alt_screen_fill_rect
                            rts
                            end
; ----------------------------------------------------------------------------
gameplay_upper_ui_to_screen start seg_gameplay
                            using appdata
                            using gameplay_ui_data

                            debugtag 'upper_ui_to_screen'

; Copy the entire upper ui area to the screen
                            pushsword #0
                            pushsword #0
                            pushsword #grlib~screen_width
                            pushsword #gameplay_ui_top_height
                            jsl grlib_alt_screen_to_screen_rect

                            lda #0
                            sta >gameplay_ui~player_score_needs_update
                            sta >gameplay_ui~ships_remaining_needs_update
                            sta >gameplay_ui~player_bonus_at_needs_update
                            rtl

                            end

; ----------------------------------------------------------------------------
; Handle a tick for the upper UI.
gameplay_upper_ui_tick      start seg_gameplay
                            using gameplay_manager_data
                            using gameplay_player_logic_data
                            using gameplay_ui_data

                            begin_locals
wLeftEdge                   decl word
wX                          decl word
work_area_size              end_locals

                            debugtag 'upper_ui_tick'

                            sub ,work_area_size

                            setlocaldatabank

                            ldy gameplay_manager~active_player_x2
                            jmi error

; Get the player's left edge offset
                            getword {y},gameplay_ui~player_offset_x
                            sta <wLeftEdge

; Check bomb count
                            lda gameplay_manager~active_state+player_state~bomb_count
                            cmp gameplay_ui~last_drawn_bomb_count
                            beq same_bomb_count

                            sta gameplay_ui~last_drawn_bomb_count

; Erase the area for the remaining bomb count
                            lda #gameplay_ui_bombs_remaining_player_1_x
                            clc
                            adc <wLeftEdge
                            pha
                            sta <wX
                            pushsword #gameplay_ui_bombs_remaining_y
                            pushsword #gameplay_ui_bombs_remaining_width
                            pushsword #gameplay_ui_bombs_remaining_height
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

                            ldx #gameplay_manager~active_player_state_offset
                            ldy gameplay_manager~active_player_x2
                            jsr _draw_player_remaining_sinibombs

                            pushsword <wX
                            pushsword #gameplay_ui_bombs_remaining_y
                            pushsword #gameplay_ui_bombs_remaining_width
                            pushsword #gameplay_ui_bombs_remaining_height
                            jsl grlib_alt_screen_to_screen_rect

same_bomb_count             anop

                            lda gameplay_ui~player_score_needs_update
                            beq same_score

                            lda #gameplay_ui_score_player_1_x
                            clc
                            adc <wLeftEdge
                            pha
                            sta <wX
                            pushsword #gameplay_ui_score_y
                            pushsword #gameplay_ui_score_width
                            pushsword #gameplay_ui_score_height
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

                            ldx #gameplay_manager~active_player_state_offset
                            ldy gameplay_manager~active_player_x2
                            jsr _draw_player_score

                            pushsword <wX
                            pushsword #gameplay_ui_score_y
                            pushsword #gameplay_ui_score_width
                            pushsword #gameplay_ui_score_height
                            jsl grlib_alt_screen_to_screen_rect

                            stz gameplay_ui~player_score_needs_update

same_score                  anop

                            lda gameplay_ui~player_bonus_at_needs_update
                            beq same_bonus

                            lda #gameplay_ui_bonus_at_player_1_x
                            clc
                            adc <wLeftEdge
                            pha
                            sta <wX
                            pushsword #gameplay_ui_bonus_at_y
                            pushsword #gameplay_ui_bonus_at_width
                            pushsword #gameplay_ui_bonus_at_height
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

                            ldx #gameplay_manager~active_player_state_offset
                            ldy gameplay_manager~active_player_x2
                            jsr _draw_player_bonus_at

                            pushsword <wX
                            pushsword #gameplay_ui_bonus_at_y
                            pushsword #gameplay_ui_bonus_at_width
                            pushsword #gameplay_ui_bonus_at_height
                            jsl grlib_alt_screen_to_screen_rect

                            stz gameplay_ui~player_bonus_at_needs_update

same_bonus                  anop

; Update the ship count.  Might not need this, as the screen will change in-between ship count changes.
                            lda gameplay_ui~ships_remaining_needs_update
                            beq same_ship_count

                            lda #gameplay_ui_ships_remaining_player_1_x
                            clc
                            adc <wLeftEdge
                            pha
                            sta <wX
                            pushsword #gameplay_ui_ships_remaining_y
                            pushsword #gameplay_ui_ships_remaining_width
                            pushsword #gameplay_ui_ships_remaining_height
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

                            ldx #gameplay_manager~active_player_state_offset
                            ldy gameplay_manager~active_player_x2
                            jsr _draw_player_remaining_ships

                            pushsword <wX
                            pushsword #gameplay_ui_ships_remaining_y
                            pushsword #gameplay_ui_ships_remaining_width
                            pushsword #gameplay_ui_ships_remaining_height
                            jsl grlib_alt_screen_to_screen_rect

; Reset any blinking
                            lda #gameplay_ui~ship_blink_rate
                            sta gameplay_ui~active_ship_blink_timer
                            stz gameplay_ui~active_ship_blink_state

                            stz gameplay_ui~ships_remaining_needs_update

same_ship_count             anop


; Active ship blinking

; If the player is dying, skip the blinking
                            lda >gameplay_player~is_dead
                            ora >gameplay_player~is_dying
                            beq not_dying
; Make sure it is on
                            lda gameplay_ui~active_ship_blink_state
                            beq no_ship_blink
                            stz gameplay_ui~active_ship_blink_state
                            bra ship_on

not_dying                   lda gameplay_ui~active_ship_blink_timer
                            sec
                            sbc gameplay_manager_logic~tick_delta           ; use the logic tick delta.
                            sta gameplay_ui~active_ship_blink_timer
                            bpl no_ship_blink

                            lda gameplay_ui~active_ship_blink_state
                            beq ship_off
                            stz gameplay_ui~active_ship_blink_state
; Ship on
ship_on                     jsr _get_active_ship_ui_location
                            shr_shadow on,push                               ; we want to draw to the screen as well
                            jsr _draw_remaining_ship_at
                            shr_shadow off,pop
                            bra ship_blinked
; Ship off
ship_off                    inc a
                            sta gameplay_ui~active_ship_blink_state
                            jsr _get_active_ship_ui_location
                            shr_shadow on,push                               ; we want to draw to the screen as well
                            jsr _erase_remaining_ship_at
                            shr_shadow off,pop

ship_blinked                lda #gameplay_ui~ship_blink_rate                ; reset the timer
                            sta gameplay_ui~active_ship_blink_timer
no_ship_blink               anop

; Update the message for the active player
                            lda gameplay_manager~active_player
                            jsr _update_message

error                       anop
                            restoredatabank
                            ret

;;
_get_active_ship_ui_location anop
                            lda gameplay_manager~active_state+player_state~ship_count
                            cmp #gameplay_ui_ships_remaining_max_display+1
                            blt active_ship_ok
                            lda #gameplay_ui_ships_remaining_max_display
active_ship_ok              dec a
                            bpl active_ship_ok2
                            lda #0
active_ship_ok2             ldx #(gameplay_ui_ships_remaining_col_width/2)
                            jsl math~umul1r2
                            clc
                            adc #gameplay_ui_ships_top_screen_address+(gameplay_ui_ships_remaining_player_1_x/2)
                            adc gameplay_ui~active_player_byte_offset_x
                            tax
                            rts

                            end

; ----------------------------------------------------------------------------
; Draw the fins on the left and right of the scanner area.
draw_scanner_fins           private seg_gameplay
                            using appdata
                            using gameplay_manager_data
                            using gameplay_ui_data

                            begin_locals
wX                          decl word
wY                          decl word
wWidth                      decl word
wFinStartY                  decl word
work_area_size              end_locals

                            debugtag 'draw_scanner_fins'

                            lsub ,work_area_size

fin_layer_1_width           equ 14
fin_layer_2_width           equ fin_layer_1_width+3

fin_height                  equ fin_layer_2_width

fin_start_y                 equ gameplay_ui_scanner_y+gameplay_ui_scanner_height-fin_height
fin_vertical_spacing        equ 8

fin_layer_1_color           equ appdata~gameplay_color~dark_green~bits
fin_layer_2_color           equ appdata~gameplay_color~light_blue~bits

; Right Size
                            lda #fin_start_y
                            sta <wFinStartY

right_side_loop             jsr draw_right_fin
                            lda <wFinStartY
                            sec
                            sbc #fin_vertical_spacing
                            sta <wFinStartY
; This is what we want, but gameplay_ui_scanner_y-1 is 0, and the value will wrap
;                           cmp #gameplay_ui_scanner_y-1
;                           bge right_side_loop
                            bpl right_side_loop

; Left side
                            lda #fin_start_y
                            sta <wFinStartY

left_side_loop              jsr draw_left_fin
                            lda <wFinStartY
                            sec
                            sbc #fin_vertical_spacing
                            sta <wFinStartY
                            bpl left_side_loop

                            lret

; Right side

; To make the code a bit simpler, there is going to be a lot of overdraw, but this doesn't need t be super-fast
; The code would also probably be simpler to draw verical lines, but that isn't super efficient, and even though I have
; the cycles, no need to waste them.
draw_right_fin              lda <wFinStartY
                            inc a                   ; layer 2 is one pixel down
                            sta <wY
                            lda #gameplay_ui_scanner_x+gameplay_ui_scanner_width+2
                            sta <wX
                            lda #fin_layer_2_width
                            sta <wWidth

right_layer_2_loop          pushsword <wX
                            pushsword <wY

                            lda <wWidth
                            cmp #fin_layer_1_width          ; we actually don't want the width to go beyond this, but doing this 'clip' makes the loop simpler
                            blt ok_right_width
                            lda #fin_layer_1_width
ok_right_width              pha
                            pushsword #1
                            pushsword #fin_layer_2_color
                            jsl grlib_alt_screen_fill_rect
                            inc <wY
                            dec <wWidth
                            bne right_layer_2_loop

                            lda <wFinStartY
                            sta <wY

                            lda #fin_layer_1_width
                            sta <wWidth

right_layer_1_loop          pushsword <wX
                            pushsword <wY

                            pushsword <wWidth
                            pushsword #1
                            pushsword #fin_layer_1_color
                            jsl grlib_alt_screen_fill_rect
                            inc <wY
                            dec <wWidth
                            bne right_layer_1_loop

                            rts

; Left side

draw_left_fin               lda <wFinStartY
                            inc a                   ; layer 2 is one pixel down
                            sta <wY
                            lda #gameplay_ui_scanner_x-2-fin_layer_2_width
                            sta <wX
                            lda #fin_layer_2_width
                            sta <wWidth

left_layer_2_loop           ldy <wWidth
                            lda <wX
                            cmp #gameplay_ui_scanner_x-2-fin_layer_1_width
                            bge ok_left_width
                            lda #gameplay_ui_scanner_x-2-fin_layer_1_width
                            ldy #fin_layer_1_width
ok_left_width               pha
                            pushsword <wY
                            phy                             ; correct width is in Y
                            pushsword #1
                            pushsword #fin_layer_2_color
                            jsl grlib_alt_screen_fill_rect
                            inc <wY
                            inc <wX
                            dec <wWidth
                            bne left_layer_2_loop

                            lda <wFinStartY
                            sta <wY

                            lda #gameplay_ui_scanner_x-2-fin_layer_1_width
                            sta <wX

                            lda #fin_layer_1_width
                            sta <wWidth

left_layer_1_loop           pushsword <wX
                            pushsword <wY

                            pushsword <wWidth
                            pushsword #1
                            pushsword #fin_layer_1_color
                            jsl grlib_alt_screen_fill_rect
                            inc <wY
                            inc <wX
                            dec <wWidth
                            bne left_layer_1_loop

                            rts

                            end

; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------


; ----------------------------------------------------------------------------
gameplay_lower_ui_turn_activate private seg_gameplay
                            using appdata

                            debugtag 'lower_ui_turn_activate'

                            lda >appdata~ui_lower_shr_palette_slot
                            bpl got_palette

                            pushsword #$ffff
                            jsl gameplay_ui_palette_reserve
                            bcs error
                            sta >appdata~ui_lower_shr_palette_slot

got_palette                 anop
error                       anop
                            jsr gameplay_lower_ui_set_shr_palette
                            jsr gameplay_lower_ui_apply_palette_scbs
                            jsr gameplay_lower_ui_draw_all

                            rtl
                            end

; ----------------------------------------------------------------------------
; Set the shr palette for the lower UI.  Does not set the scbs!
gameplay_lower_ui_set_shr_palette private seg_gameplay
                            using appdata

                            lda >appdata~ui_lower_shr_palette_slot
                            bmi error
                            tax
                            lda >appdata~ui_lower_palette_ptr+2
                            beq use_default                         ; null?  (assuming we would never have a bank 0 address!)
                            pha
                            lda >appdata~ui_lower_palette_ptr
                            pha
doit                        phx

                            jsl grlib_set_shr_palette
error                       anop
                            rts

use_default                 pushptr #appdata~ui_default_palette
                            bra doit

                            end

; ----------------------------------------------------------------------------
; Set the scb palette slot for the lower UI scanlines
gameplay_lower_ui_apply_palette_scbs private seg_gameplay
                            using appdata

                            lda >appdata~ui_lower_shr_palette_slot
                            bmi error

                            pha
                            pushsword #grlib~screen_height-gameplay_ui_bottom_height
                            pushsword #gameplay_ui_bottom_height
                            jsl grlib_set_scb_palette_range

error                       anop
                            rts

                            end

; ----------------------------------------------------------------------------
gameplay_lower_ui_draw_all  private seg_gameplay
                            using appdata
                            using gameplay_manager_data

                            setlocaldatabank

; Erase the ui area (l/r/w/h rect)
                            pushsword #0
                            pushsword #grlib~screen_height-gameplay_ui_bottom_height
                            pushsword #grlib~screen_width
                            pushsword #gameplay_ui_bottom_height
                            pushsword #$0000
                            jsl grlib_alt_screen_fill_rect

                            jsr draw_lower_frame

                            restoredatabank
                            rts

                            end

; ----------------------------------------------------------------------------
draw_lower_frame            private seg_gameplay
                            using appdata
                            using gameplay_manager_data
; Draw a dividing line
                            pushsword #0
                            pushsword #grlib~screen_height-gameplay_ui_bottom_height
                            pushsword #grlib~screen_width
                            pushsword #1
                            pushsword gameplay_manager~active_state+player_state~zone_color
                            jsl grlib_alt_screen_fill_rect
                            rts
                            end
; ----------------------------------------------------------------------------
gameplay_lower_ui_to_screen start seg_gameplay
                            using appdata

                            debugtag 'lower_ui_to_screen'

; Copy the entire lower ui area to the screen
                            pushsword #0
                            pushsword #grlib~screen_height-gameplay_ui_bottom_height
                            pushsword #grlib~screen_width
                            pushsword #gameplay_ui_bottom_height
                            jsl grlib_alt_screen_to_screen_rect

                            rtl

                            end

; ----------------------------------------------------------------------------
; Called to refresh the UI frame when a zone changes, mid game
gameplay_ui_refresh_frame   start seg_gameplay

                            setlocaldatabank

                            jsr draw_upper_frame
                            jsr draw_lower_frame

; This isn't super efficient, as it will be copying a lot more than it needs to.
                            jsl gameplay_upper_ui_to_screen
                            jsl gameplay_lower_ui_to_screen

                            restoredatabank
                            rtl
                            end


; ----------------------------------------------------------------------------
; Apply a palette, with a tracked ID
gameplay_ui_apply_palette   start seg_gameplay
                            using gameplay_ui_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'ui_apply_palette'

                            sub (4:pPalette,2:wSlot,2:wID),work_area_size

                            pushptr <pPalette
                            pushsword <wSlot
                            jsl grlib_set_shr_palette

                            lda <wID
                            sta >gameplay_ui~palette_applied

                            ret

                            end

; ----------------------------------------------------------------------------
; Clear the screen, if the supplied palette ID, is not the one we know is applied
gameplay_ui_clear_screen_if_needed start seg_gameplay
                            using gameplay_ui_data
                            using softswitch_definitions

                            begin_locals
work_area_size              end_locals

                            debugtag 'ui_clear_screen'

                            sub (2:wID,2:wWaitForVBL),work_area_size

                            lda <wID
                            cmp >gameplay_ui~palette_applied
                            beq no_clear

                            lda <wWaitForVBL
                            beq no_wait

                            jsl grlib_wait_one_frame

no_wait                     anop

                            pushsword #0
                            pushsword #0
                            pushsword #grlib~screen_width
                            pushsword #grlib~screen_height
                            pushsword #0
                            jsl grlib_screen_fill_rect

no_clear                    ret

                            end

; -----------------------------------------------------------------------------
; Helper function for when a UI screen is initially shown.
; This assumes that the backbuffer has been filled in with what is to be displayed.
; Parameters:
;  wPaletteID       - a palette ID to apply
gameplay_ui_show_screen     start seg_gameplay
                            using appdata
                            using applib_data
                            using softswitch_definitions
                            using grlib_global_data
                            using playfield_manager_data
                            using gameplay_level_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'ui_show_screen'

                            sub (2:wPaletteID),work_area_size
; Signal we are going to change the palette, which will clear the screen if needed.
; This helps prevent flashing, because we can't draw the screen fast enough.  Sad.
                            pushsword <wPaletteID
                            pushsword #$ffff
                            jsl gameplay_ui_clear_screen_if_needed

; We should do this next bit in the vbl.  We wait for 2, in case we were already in one, we can't tell how far in we were.
                            jsl grlib_wait_one_frame

                            lda <wPaletteID
                            beq palette_error
                            dec a
                            asl a
                            tax
                            jsr (set_palettes,x)

palette_error               anop

                            jsl grlib_alt_screen_to_screen

                            ret

; Using a function to set the palette, just in case we want to do some extra work, but overall, the UI ones are just setting a palette definition.
set_palettes                anop
                            dc a'set_skip'
                            dc a'set_gameplay_palette'
                            dc a'set_config_palette'
                            dc a'set_high_score_palette'

set_skip                    anop
                            rts

set_gameplay_palette        anop
                            lda >gameplay_level~playfield_palette_ptr+2
                            beq palette_not_set
                            pha
                            lda >gameplay_level~playfield_palette_ptr
                            pha
                            pushsword #gameplay_ui~full_screen_palette_slot
                            pushsword <wPaletteID                                   ; track what we are switching to
                            jsl gameplay_ui_apply_palette

                            pushsword #gameplay_ui~full_screen_palette_slot
                            pushsword #0
                            pushsword #grlib~screen_height
                            jsl grlib_set_scb_palette_range
palette_not_set             rts

set_config_palette          anop
                            pushdword #appdata~ui_config_state_palette
                            pushsword #gameplay_ui~full_screen_palette_slot
                            pushsword <wPaletteID                                   ; track what we are switching to
                            jsl gameplay_ui_apply_palette

                            pushsword #gameplay_ui~full_screen_palette_slot
                            pushsword #0
                            pushsword #grlib~screen_height
                            jsl grlib_set_scb_palette_range
                            rts

set_high_score_palette      anop
                            pushdword #appdata~ui_high_score_state_palette
                            pushsword #gameplay_ui~full_screen_palette_slot
                            pushsword <wPaletteID                                   ; track what we are switching to
                            jsl gameplay_ui_apply_palette

                            pushsword #gameplay_ui~full_screen_palette_slot
                            pushsword #0
                            pushsword #grlib~screen_height
                            jsl grlib_set_scb_palette_range
                            rts

                            end

; -----------------------------------------------------------------------------
; Apply the 'paused' palettes to the entire screen
; This will apply a darkened version of all the palettes to the screen
gameplay_ui_apply_paused_palettes start seg_gameplay
                            using appdata
                            using applib_data
                            using gameplay_ui_data

                            begin_locals
spCopy                      decl word
spDarkened                  decl word
wCount                      decl word
wIndex                      decl word
wPalette                    decl word
work_area_size              end_locals

                            debugtag 'apply_paused'

                            sub ,work_area_size

                            setlocaldatabank

                            lda gameplay_ui~paused_palettes_applied
                            bne exit                    ; already applied?

; Copy and darken all the palettes we know are in use, even if they may not be active in the SCBs

                            lda #gameplay_ui~paused_palettes_copy
                            sta <spCopy
                            lda #gameplay_ui~paused_palettes_darkened
                            sta <spDarkened

                            lda gameplay_ui~reserved_palette_count
                            sta <wCount
                            stz <wIndex

loop                        anop
                            ldy <wIndex
                            lda gameplay_ui~reserved_palettes,y
                            sta <wPalette

                            ldx <spCopy
                            ldy <spDarkened
; Make sure the palette header is correct
                            lda #16
                            putword {x},#palette~color_count
                            putword {y},#palette~color_count
                            lda #palette_color_format~collapsed
                            putword {x},#palette~color_format
                            putword {y},#palette~color_format

; Copy the existing SHR palette
                            pushptrhigh #gameplay_ui~paused_palettes_copy
                            pushsword <spCopy
                            pushsword <wPalette
                            jsl grlib_get_shr_palette

; Copy from that, to a darkened palette
                            pushptrhigh #gameplay_ui~paused_palettes_copy
                            pushsword <spCopy
                            pushptrhigh #gameplay_ui~paused_palettes_darkened
                            pushsword <spDarkened
                            jsl grlib_palette_copy_to_darkened

; Apply the darkened palette
                            pushptrhigh #gameplay_ui~paused_palettes_darkened
                            pushsword <spDarkened
                            pushsword <wPalette
                            jsl grlib_set_shr_palette

; Advance
                            lda <spCopy
                            clc
                            adc #sizeof~palette_scb
                            sta <spCopy

                            lda <spDarkened
                            clc
                            adc #sizeof~palette_scb
                            sta <spDarkened

                            inc <wIndex
                            inc <wIndex

                            dec <wCount
                            bne loop

                            lda #1
                            sta gameplay_ui~paused_palettes_applied

exit                        restoredatabank

                            ret
                            end

; -----------------------------------------------------------------------------
; Remove the paused palettes
gameplay_ui_remove_paused_palettes start seg_gameplay
                            using appdata
                            using applib_data
                            using gameplay_ui_data

                            begin_locals
spCopy                      decl word
wCount                      decl word
wIndex                      decl word
wPalette                    decl word
work_area_size              end_locals

                            debugtag 'apply_paused'

                            sub ,work_area_size

                            setlocaldatabank

                            lda gameplay_ui~paused_palettes_applied
                            beq exit

                            lda #gameplay_ui~paused_palettes_copy
                            sta <spCopy

                            lda gameplay_ui~reserved_palette_count
                            sta <wCount
                            stz <wIndex

loop                        anop
                            ldy <wIndex
                            lda gameplay_ui~reserved_palettes,y
                            sta <wPalette

; Apply the copied palette
                            pushptrhigh #gameplay_ui~paused_palettes_copy
                            pushsword <spCopy
                            pushsword <wPalette
                            jsl grlib_set_shr_palette

; Advance
                            lda <spCopy
                            clc
                            adc #sizeof~palette_scb
                            sta <spCopy

                            inc <wIndex
                            inc <wIndex

                            dec <wCount
                            bne loop

                            stz gameplay_ui~paused_palettes_applied

exit                        restoredatabank

                            ret
                            end

; -----------------------------------------------------------------------------
; Reserve a palette slot
; Use this, rather than calling grlib_shr_palette_reserve directly, so
; the slots can be tracked more easily.
gameplay_ui_palette_reserve start seg_gameplay
                            using appdata
                            using applib_data
                            using gameplay_ui_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'ui_palette_reserve'

                            sub (2:wSlot),work_area_size

                            setlocaldatabank

                            lda gameplay_ui~reserved_palette_count
                            cmp #gameplay_ui~max_reserved_palettes
                            bge exit

                            pushsword <wSlot
                            jsl grlib_shr_palette_reserve
                            bcs exit
                            sta <wSlot

                            lda gameplay_ui~reserved_palette_count
                            asl a
                            tax
                            lda <wSlot
                            sta gameplay_ui~reserved_palettes,x
                            inc gameplay_ui~reserved_palette_count

                            clc

exit                        restoredatabank
                            retkc 2:wSlot
                            end

; -----------------------------------------------------------------------------
; Draw a 'text section'
; This is a table of text commands that specify a simple block of text
; with color and formatting information;
; Parameters:
; pSection      - pointer to the text section table
; wLeft         - left edge to draw at
; wY            - y position to draw at
; wYAdvance     - the pixel height to advance for one line of text
;
; Table format is
; int : advance     - Amount to advance the the Y position.
;                     bit 15, signals the end of the table. No other fields have to follow if this is set
;                     bit 14, signals that all the text, to the next non-zero advance, should be centered
;                     bits 0-7, the number of font lines to advance (wYAdvance * this value),
;                     bits 8-13, the number of additional pixel lines to advance
; int : color       - The palette index to set the font color to
;                     bit 15, if set, then do not change the color
; ptr :             - pointer to the text.  Can be null.
;
; Returns:
; a-reg - the next font line (the last font Y position + wYAdvance + 2)
ui_draw_text_section        start seg_gameplay
                            using appdata

                            begin_locals
wX                          decl word
wWidth                      decl word
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
                            bit #ui_text_section~centered
                            beq not_centered

                            and #(ui_text_section~centered*-1)-1
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

; Calculate wX position from the text width for the text on the line (i.e. up to the next line advance)
_calc_centered              anop
                            phy
                            stz <wWidth
                            bra centered_skip_first
centered_loop               anop
; Loop until the end or the next advance
                            getword {y},#section_entry~advance
                            bne centered_done

centered_skip_first         getword {y},#section_entry~text+2
                            beq centered_no_text
                            phy
                            pha
                            getword {y},#section_entry~text
                            pha
                            jsl grlib_get_string_pixel_size
                            clc
                            adc <wWidth
                            sta <wWidth
                            ply

centered_no_text            tya
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
