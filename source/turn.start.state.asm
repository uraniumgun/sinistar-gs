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
                            copy lib/source/sndlib.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/app.debug.definitions.asm
                            copy source/app.ui.definitions.asm

                            mcopy generated/turn.start.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; The Turn Start screen

turn_start_state_data       data seg_gameplay

turn_start_state~last_tick  ds 4
turn_start_state~tick_delta ds 2
turn_start_state~countdown  ds 2
turn_start_state~color_cycle_timer ds 2

turn_start_state~in_game_over ds 2

turn_start_state~update_rate equ 1

tss~sinistar_part_count equ 20           ; all the pieces
tss~sinistar_center_piece_offset equ 0+(tss~sinistar_part_count-1)*4

tss~sinistar_x              equ 160
tss~sinistar_y              equ 110

tss~sinistar_mouth_x        equ tss~sinistar_x-12
tss~sinistar_mouth_y        equ tss~sinistar_y+28

tss~sinistar_eyebrow_x      equ tss~sinistar_x-12
tss~sinistar_eyebrow_y      equ tss~sinistar_y+4

tss~sinistar_update_x       equ tss~sinistar_x-16
tss~sinistar_update_y       equ tss~sinistar_y+2
tss~sinistar_update_width   equ 32
tss~sinistar_update_height  equ 38

tss~piece_offsets           dc i'tss~sinistar_x-06,tss~sinistar_y+00,tss~sinistar_x+06,tss~sinistar_y+00'
                            dc i'tss~sinistar_x-12,tss~sinistar_y+04,tss~sinistar_x+14,tss~sinistar_y+04'
                            dc i'tss~sinistar_x-15,tss~sinistar_y+16,tss~sinistar_x+19,tss~sinistar_y+16'
                            dc i'tss~sinistar_x-16,tss~sinistar_y+26,tss~sinistar_x+18,tss~sinistar_y+26'
                            dc i'tss~sinistar_x-12,tss~sinistar_y+38,tss~sinistar_x+14,tss~sinistar_y+38'
                            dc i'tss~sinistar_x-01,tss~sinistar_y+40,tss~sinistar_x+05,tss~sinistar_y+40'

                            dc i'tss~sinistar_x-05,tss~sinistar_y+12,tss~sinistar_x+09,tss~sinistar_y+12'
                            dc i'tss~sinistar_x-09,tss~sinistar_y+24,tss~sinistar_x+09,tss~sinistar_y+24'
                            dc i'tss~sinistar_x+00,tss~sinistar_y+33,tss~sinistar_x-03,tss~sinistar_y+32'
                            dc i'tss~sinistar_x+03,tss~sinistar_y+32,tss~sinistar_x+01,tss~sinistar_y+24'

tss~sinistar_ui_entities    anop
                            ds tss~sinistar_part_count*4

                            end
; ----------------------------------------------------------------------------
turn_start_state_initialize start seg_gameplay
                            using appdata

                            debugtag 'turn_state_initialize'
                            setlocaldatabank

                            jsr _allocate_sinistar

                            restoredatabank

                            rtl
                            end

; ----------------------------------------------------------------------------
turn_start_state_uninitialize start seg_gameplay
                            using appdata

                            debugtag 'turn_state_uninitialize'
                            setlocaldatabank

                            jsr _deallocate_sinistar

                            restoredatabank

                            rtl
                            end

; ----------------------------------------------------------------------------
turn_start_state_activate   start seg_gameplay
                            using appdata
                            using applib_data
                            using turn_start_state_data
                            using gameplay_level_data
                            using softswitch_definitions
                            using grlib_global_data
                            using sinistar_entity_data
                            using playfield_manager_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            debugtag 'turn_state_activate'

                            begin_locals
wTemp                       decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            stz turn_start_state~in_game_over
                            stz turn_start_state~color_cycle_timer

; Check to see if a player is currently active.
; If so, we will see if they have any more ships and if not, setup the 'game over' sequence.
; If they do have ships, we will see if there is a player 2 and switch to them.
; If there isn't another player, we will just show the status screen.
; If there is no active player, we will assume this is the first time through and activate
; the player.
                            lda gameplay_manager~active_player
                            bpl has_player
; No active player, set player 0 active
                            pushsword #0
                            jsl gameplay_activate_player
                            jsr _show_player
                            bra exit

has_player                  anop
                            lda gameplay_manager~active_state+player_state~ship_count
                            bne has_ships
                            jsr _show_game_over
                            bra exit

has_ships                   anop
                            pushsword #sfx_stop_option~cancel_callback
                            jsl sndlib_stop_all_sfx
                            lda gameplay_manager~active_player
                            jsl gameplay_manager_get_next_player
                            bcs exit                                    ; shouldn't happen, but..
                            pha
                            jsl gameplay_deactivate_player              ; deactivate the player, even if we are switching to the same player, as this will make sure the active state is copied to the player state.
                            jsl gameplay_activate_player
                            jsr _show_player

exit                        anop
                            restoredatabank
                            ret
                            end
; ----------------------------------------------------------------------------
turn_start_state_tick       start seg_gameplay
                            using appdata
                            using applib_data
                            using turn_start_state_data
                            using gameplay_manager_data

                            debugtag 'turn_state_tick'

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            setlocaldatabank

; Get the tick delta
                            lda >applib~current_tick
                            sec
                            sbc turn_start_state~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc turn_start_state~last_tick+2
                            bne timer_expired                       ; If this happened, we got stuck for quite a while
                            cpx #turn_start_state~update_rate
                            blt done

do_update                   lda >applib~current_tick
                            sta turn_start_state~last_tick
                            lda >applib~current_tick+2
                            sta turn_start_state~last_tick+2

; X has the tick delta, lower word
                            txa
                            sta turn_start_state~tick_delta
                            negate a
                            clc
                            adc turn_start_state~countdown
                            sta turn_start_state~countdown
                            beq timer_expired
                            bpl continue                           ; still more to go?
;
timer_expired               anop
                            lda turn_start_state~in_game_over       ; were we doing the 'game over' for the previous player?
                            bne next_player
; start play for the current player
                            lda #app_state~gameplay
                            sta >appdata~pending_state
                            bra done

continue                    anop
; Do other updates, while waiting
                            lda turn_start_state~in_game_over
                            bne no_sinistar_update
                            lda gameplay_manager~active_state+player_state~sinistar~state
                            beq no_sinistar_update
; Update Sinistar animation
                            pushsword turn_start_state~tick_delta
                            jsr turn_start_state_update_sinistar

no_sinistar_update          jsl snes_max_read_controller                    ; read the button state for the controller, if enabled.
                            jsl get_key_press
                            beq no_keypress
                            cmp #key~esc
                            beq timer_expired
                            cmp #key~space
                            beq timer_expired
                            pha
                            jsl handle_common_keypresses
no_keypress                 anop
; Do some housekeeping
                            jsl applib_update_fps
                            jsl appdebug_update_text_screen

done                        anop
                            restoredatabank
                            rtl

next_player                 jsl gameplay_manager_get_next_player
                            bcs game_over
                            stz turn_start_state~in_game_over
                            pha
                            jsl gameplay_deactivate_player
                            jsl gameplay_activate_player
                            jsr _show_player
                            bra done

game_over                   anop
                            jsl gameplay_deactivate_player                  ; make sure the player is deactivated
                            jsl gameplay_manager_end_game

                            lda #app_state~enter_score
                            sta >appdata~pending_state
                            bra done

                            end

;;

; ----------------------------------------------------------------------------
; Show the current player's status screen
_show_player                private seg_gameplay
                            using appdata
                            using applib_data
                            using turn_start_state_data
                            using gameplay_level_data
                            using softswitch_definitions
                            using grlib_global_data
                            using sinistar_entity_data
                            using playfield_manager_data
                            using gameplay_sound_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            debugtag '_show_player'

                            begin_locals
wTemp                       decl word
wPieces                     decl word
work_area_size              end_locals

                            lsub ,work_area_size

text_y_offset               equ 74

turn_start_text_y_offset    equ 50

                            lda #appdata~gameplay_color~black~bits
                            jsl grlib_fill_alt_screen

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            ldx #turn_start_text_y_offset
                            jsr _draw_player_text

                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~blue~bits
                            jsl grlib_set_font_fore_color

; You have...

; Convert the bomb count to a string.  This is not quick, but we are not animating anything
                            lda gameplay_manager~active_state+player_state~bomb_count
                            pha
                            pushdword #string_num1
                            pushsword #1
                            jsl word_to_str
                            tax
                            stz string_num1,x           ; null terminate the string

                            ldx #0
                            lda gameplay_manager~active_state+player_state~bomb_count
                            cmp #1
                            beq one_sinibomb
                            ldx #4
one_sinibomb                lda str_sinibombs_plural_table,x
                            sta sinibombs_patch
                            lda str_sinibombs_plural_table+2,x
                            sta sinibombs_patch+2

; Sinistar has...
                            lda gameplay_manager~active_state+player_state~sinistar~pieces_built
                            ldx gameplay_manager~active_state+player_state~sinistar~state
                            beq is_building                 ; being built?
; Don't count the center pieces
                            sec
                            sbc #sinistar_center_pieces
                            bcs is_building                 ; check for underflow (shouldn't normally happen)
                            lda #0

is_building                 pha
                            pha
                            pushdword #string_num2
                            pushsword #1
                            jsl word_to_str
                            tax
                            stz string_num2,x               ; null terminate

                            ldx #0
                            pla                             ; get the count back
                            cmp #1
                            beq one_piece
                            ldx #4
one_piece                   lda str_pieces_plural_table,x
                            sta pieces_patch
                            lda str_pieces_plural_table+2,x
                            sta pieces_patch+2

; Draw the section text
                            pushptr #you_have_section
                            pushsword #0
                            pushsword #text_y_offset
                            pushsword #appdata~font_teeny~height+4
                            jsl ui_draw_text_section

; a-reg has the next line
                            clc
                            adc #4                              ; add a bit more space
                            tay

; "Mine crystals to make sinibombs"
                            lda gameplay_manager~active_state+player_state~sinistar~pieces_built
                            cmp #2
                            blt no_mine_text
;
                            pushptr #mine_crystals_section
                            pushsword #0
                            phy
                            pushsword #appdata~font_teeny~height+4
                            jsl ui_draw_text_section

no_mine_text                anop

                            pushsword gameplay_manager~active_state+player_state~sinistar~state
                            pushsword gameplay_manager~active_state+player_state~sinistar~pieces_built
                            jsr turn_start_state_draw_sinistar

no_sinistar                 anop

; Signal we are going to change the palette, which will clear the screen if needed.
; This helps prevent flashing, because we can't draw the screen fast enough.  Sad.
                            pushsword #gameplay_ui~palette_id~playfield
                            pushsword #$ffff
                            jsl gameplay_ui_clear_screen_if_needed

; We should do this next bit in the vbl
                            jsl grlib_wait_one_frame

; We are going to use the same palette as the gameplay field, since we may be showing Sinistar, so we will need his colors correct.
; We are changing all the SCBs, because we don't want to assume what the previous state was

                            lda >playfield_view~palette_shr_slot
                            bmi palette_error
                            tax
                            lda gameplay_level~playfield_palette_ptr+2
                            beq palette_error
                            pha
                            lda gameplay_level~playfield_palette_ptr
                            pha
                            phx
                            pushsword #gameplay_ui~palette_id~playfield             ; track what we are switching to
                            jsl gameplay_ui_apply_palette

                            pushword >playfield_view~palette_shr_slot
                            pushsword #0
                            pushsword #grlib~screen_height
                            jsl grlib_set_scb_palette_range

; However, we are going to change color 0, to a different color, depending on whether sinistar is complete or not.

                            ldx #appdata~palette_color~dark_blue
                            lda gameplay_manager~active_state+player_state~sinistar~state
                            beq not_alive                               ; 0 is building.
                            ldx #appdata~palette_color~dark_red
not_alive                   stx <wTemp

                            lda >playfield_view~palette_shr_slot
                            shiftleft 5             ; x 32
                            tax
                            lda >grlib~shr_palettes,x
                            and #grlb~shr_palette_reserved_mask             ; Apple says the upper bits are reserved and they shouldn't be modified.  Is this really needed?
                            ora <wTemp
                            sta >grlib~shr_palettes,x

palette_error               anop

                            jsr _show_kill_count

                            jsl grlib_alt_screen_to_screen

; Play Sinistar speech after we flip the screen

                            lda gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_alive
                            bne no_speech

                            jsl gameplay_sinistar_stop_speech

                            pushsword #id_sfx~beware_i_live
                            jsl gameplay_sinistar_play_speech

no_speech                   anop
                            lda >applib~current_tick
                            sta turn_start_state~last_tick
                            lda >applib~current_tick+2
                            sta turn_start_state~last_tick+2

                            lda #60*5
                            sta turn_start_state~countdown

                            lret

;; Show Sinistars killed / zone.
;; Not done on the first level
kill_text_y_offset          equ 50

_show_kill_count            anop

                            lda gameplay_manager~active_state+player_state~sinistars_killed
                            beq first_zone              ; we don't show this on the first zone

                            pha
                            pushdword #string_num1
                            pushsword #1
                            jsl word_to_str
                            tax
                            stz string_num1,x           ; null terminate the string

                            ldx #0
                            lda gameplay_manager~active_state+player_state~sinistars_killed
                            cmp #1
                            beq one_sinistar
                            ldx #4
one_sinistar                lda str_sinistar_plural_table,x
                            sta smashed_sinistars_patch
                            lda str_sinistar_plural_table+2,x
                            sta smashed_sinistars_patch+2

; Set the zone name
                            lda gameplay_manager~active_state+player_state~sinistars_killed
                            and #$03                    ; rotates through 4 zone names
                            asl a
                            asl a
                            tax
                            lda str_level_table,x
                            sta zone_patch
                            lda str_level_table+2,x
                            sta zone_patch+2

; Draw the section text
                            pushptr #kill_and_level_section
                            pushsword #0
                            pushsword #kill_text_y_offset
                            pushsword #appdata~font_teeny~height+4
                            jsl ui_draw_text_section

first_zone                  rts

you_have_section            anop
                            dc i'ui_text_section~centered'
                            dc i'appdata~gameplay_color~blue~index'
                            dc a4'string1'

                            dc i'0'
                            dc i'appdata~gameplay_color~red~index'
                            dc a4'string_num1'

                            dc i'0'
                            dc i'appdata~gameplay_color~blue~index'
sinibombs_patch             dc a4'0'

                            dc i'ui_text_section~centered+1'
                            dc i'appdata~gameplay_color~blue~index'
                            dc a4'string3'

                            dc i'0'
                            dc i'appdata~gameplay_color~red~index'
                            dc a4'string_num2'

                            dc i'0'
                            dc i'appdata~gameplay_color~blue~index'
pieces_patch                dc a4'0'

                            dc i'ui_text_section~end_section'

;
mine_crystals_section       anop
                            dc i'ui_text_section~centered'
                            dc i'appdata~gameplay_color~red~index'
                            dc a4'string5'

                            dc i'ui_text_section~end_section'

;
kill_and_level_section      anop
                            dc i'ui_text_section~centered'
                            dc i'appdata~gameplay_color~blue_gray~index'
                            dc a4'string6'

                            dc i'0'
                            dc i'appdata~gameplay_color~red~index'
                            dc a4'string_num1'

                            dc i'0'
                            dc i'appdata~gameplay_color~blue_gray~index'
smashed_sinistars_patch     dc a4'0'

                            dc i'ui_text_section~centered+1'
                            dc i'appdata~gameplay_color~blue_gray~index'
                            dc a4'string8'

                            dc i'0'
                            dc i'appdata~gameplay_color~red~index'
zone_patch                  dc a4'0'

                            dc i'0'
                            dc i'appdata~gameplay_color~blue_gray~index'
                            dc a4'string9'

                            dc i'ui_text_section~end_section'


string1                     cstring 'YOU HAVE '
string2                     cstring ' SINIBOMBS'
string2a                    cstring ' SINIBOMBS'
string3                     cstring 'SINISTAR HAS '
string4                     cstring ' PIECE'
string4a                    cstring ' PIECES'
string5                     cstring 'MINE CRYSTALS TO MAKE SINIBOMBS'
string6                     cstring 'YOU HAVE SMASHED '
string7                     cstring ' SINISTAR'
string7a                    cstring ' SINISTARS'
string8                     cstring 'NOW IN '
string9                     cstring ' ZONE'

str_level1                  cstring 'VOID'
str_level2                  cstring 'WORKER'
str_level3                  cstring 'WARRIOR'
str_level4                  cstring 'PLANETOIDS'

str_sinibombs_plural_table  dc a4'string2'
                            dc a4'string2a'

str_pieces_plural_table     dc a4'string4'
                            dc a4'string4a'

str_sinistar_plural_table   dc a4'string7'
                            dc a4'string7a'

str_level_table             dc a4'str_level1'
                            dc a4'str_level2'
                            dc a4'str_level3'
                            dc a4'str_level4'

string_num1                 ds 7            ; one more than we need, so we can null terminate by writing a word
string_num2                 ds 7
                            end

; ----------------------------------------------------------------------------
; Show the Game Over screen
_show_game_over             private seg_gameplay
                            using appdata
                            using applib_data
                            using turn_start_state_data
                            using softswitch_definitions
                            using grlib_global_data
                            using gameplay_manager_data
                            using gameplay_ui_data

                            debugtag '_show_game_over'

game_over_text_y_offset     equ gameplay_ui_top_height+60

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            ldx #game_over_text_y_offset
                            jsr _draw_player_text

                            lda #appdata~gameplay_color~light_yellow~bits
                            jsl grlib_set_font_fore_color

text1_width                 equ 62
text1_x_offset              equ 0+(320-text1_width)/2
text1_y_offset              equ 60

                            pushdword #str_game_over
                            pushsword #text1_x_offset
                            pushsword #text1_y_offset
                            jsl grlib_draw_string

; We should do this next bit in the vbl
                            jsl grlib_wait_one_frame

                            pushsword #gameplay_ui_playfield_left
                            pushsword #gameplay_ui_playfield_top
                            pushsword #gameplay_ui_playfield_width
                            pushsword #gameplay_ui_playfield_height

                            jsl grlib_alt_screen_to_screen_rect

; Stars are draw directly to the screen, so draw them again
                            jsl stars_manager_update

                            lda >applib~current_tick
                            sta turn_start_state~last_tick
                            lda >applib~current_tick+2
                            sta turn_start_state~last_tick+2

                            lda #60*4
                            sta turn_start_state~countdown

                            lda #1
                            sta turn_start_state~in_game_over

                            rts

str_game_over               cstring 'GAME OVER'
                            end

; ----------------------------------------------------------------------------
; Draw Player 1 or Player 2, if this is not a single player game.
; Parameters:
; x     - contains the y offset to draw the player
_draw_player_text           private seg_gameplay
                            using appdata
                            using applib_data
                            using turn_start_state_data
                            using gameplay_manager_data
                            using gameplay_ui_data

; This will draw "Player N", if this game has more than one player, else we don't show player info.

player_text_width           equ 54
player_text_x_offset        equ 0+(320-player_text_width)/2

                            lda gameplay_manager~player_count
                            cmp #2
                            blt single_player

                            stx y_offset

                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_player
                            pushsword #player_text_x_offset
                            pushsword y_offset
                            jsl grlib_draw_string
                            clc
                            adc #appdata~font_primary~space_width
                            tax
                            lda gameplay_manager~active_player
                            clc
                            adc #'1'                                ; ok, ok.   9 players, max.  Change to print a bcd32 when needed ;)
                            pha
                            phx
                            pushsword y_offset
                            jsl grlib_draw_char

single_player               rts

str_player                  cstring 'PLAYER'
y_offset                    ds 2
                            end

; -----------------------------------------------------------------------------
; Allocate UI entities for each Sinistar part we will draw.
; Might be overkill.  I just use one in the Tutorial screen and re-use it.
_allocate_sinistar          private seg_gameplay
                            using sinistar_entity_data
                            using ui_entity_data
                            using turn_start_state_data

                            begin_locals
wIndex                      decl word
work_area_size              end_locals

                            lsub ,work_area_size

                            stz <wIndex

loop                        pushptr #ui_entity_object
                            jsl object_new
                            pushretptr                      ; save for the load call
; Save in our table
                            pha
                            lda <wIndex
                            asl a
                            asl a
                            tay
                            pla
                            sta tss~sinistar_ui_entities,y
                            txa
                            sta tss~sinistar_ui_entities+2,y

; Load the image
                            pushptr #sinistar_entity_image_collection_id
                            pushsword #framelib_set_id_walk
                            lda <wIndex
                            cmp #tss~sinistar_part_count-1
                            blt outer
                            lda #sinistar_piece_center
outer                       pha
                            jsl ui_entity_load

                            inc <wIndex
                            lda <wIndex
                            cmp #tss~sinistar_part_count
                            blt loop

                            lret

                            end

; -----------------------------------------------------------------------------
_deallocate_sinistar        private seg_gameplay
                            using sinistar_entity_data
                            using ui_entity_data
                            using turn_start_state_data

                            begin_locals
wIndex                      decl word
work_area_size              end_locals

                            lsub ,work_area_size

                            lda #0
                            sta <wIndex

loop                        asl a
                            asl a
                            tay
                            pushptr {y},tss~sinistar_ui_entities
                            pushptr #ui_entity_object
                            jsl object_delete

                            inc <wIndex
                            lda <wIndex
                            cmp #tss~sinistar_part_count
                            blt loop

                            lret

                            end

; -----------------------------------------------------------------------------
; Draw Sinistar.
; Note, this is shared with the copyright screen, which uses it to draw him as well.
turn_start_state_draw_sinistar start seg_gameplay
                            using sinistar_entity_data
                            using ui_entity_data
                            using turn_start_state_data
                            using gameplay_manager_data

                            begin_locals
wIndex                      decl word
wCount                      decl word
work_area_size              end_locals

                            lsub (2:wSinistarState,2:wSinistarPiecesBuilt),work_area_size

; Not going to animate the eyebrow, just have it set in the 'normal' position
                            lda #sinistar_eyebrow_normal
                            sta >sinistar_eyebrow_position

                            lda <wSinistarState
                            bne is_alive

; Building loop
                            lda <wSinistarPiecesBuilt
                            beq exit
                            sta <wCount

                            lda #0
                            sta <wIndex

loop                        asl a
                            asl a
                            tay
                            pushptr {y},tss~sinistar_ui_entities
                            lda tss~piece_offsets,y
                            pha
                            lda tss~piece_offsets+2,y
                            pha
                            jsl grlib_draw_sprite

                            inc <wIndex
                            lda <wIndex
                            dec <wCount

                            bne loop
                            bra exit

is_alive                    anop
                            lda <wSinistarPiecesBuilt
; Don't count the center pieces
                            sec
                            sbc #sinistar_center_pieces
                            bcc just_center
                            beq just_center

                            sta <wCount
                            lda #0
                            sta <wIndex

loop2                       asl a
                            asl a
                            tay
                            pushptr {y},tss~sinistar_ui_entities
                            lda tss~piece_offsets,y
                            pha
                            lda tss~piece_offsets+2,y
                            pha
                            jsl grlib_draw_sprite

                            inc <wIndex
                            lda <wIndex
                            dec <wCount

                            bne loop2
; Draw the center piece
just_center                 pushdword tss~sinistar_ui_entities+tss~sinistar_center_piece_offset
                            pushsword tss~piece_offsets+tss~sinistar_center_piece_offset
                            pushsword tss~piece_offsets+tss~sinistar_center_piece_offset+2
                            jsl grlib_draw_sprite

exit                        lret

                            end

; -----------------------------------------------------------------------------
turn_start_state_update_sinistar start seg_gameplay
                            using grlib_global_data
                            using grlib_global_equates
                            using appdata
                            using sinistar_entity_data
                            using ui_entity_data
                            using playfield_manager_data
                            using turn_start_state_data
                            using gameplay_manager_data
                            using gameplay_sinistar_logic_data

                            begin_locals
work_area_size              end_locals

                            lsub (2:wTickDelta),work_area_size

; Do the effect3 color cycling
                            lda turn_start_state~color_cycle_timer
                            clc
                            adc <wTickDelta
                            sta turn_start_state~color_cycle_timer
                            lsr a
                            lsr a
                            and #%00000110
                            tay
                            lda >playfield_view~palette_shr_slot_offset
                            clc
                            adc #appdata~gameplay_color~effect3~index*2
                            tax
                            lda >grlib~shr_palettes,x
                            and #grlb~shr_palette_reserved_mask
                            ora gameplay_sinistar~effect_cycle_color,y
                            sta >grlib~shr_palettes,x

                            lda <wTickDelta
                            jsl gameplay_sinistar_update_speech_anim

                            phd
                            lda >grlib~dp
                            tcd

; Draw animated parts, the mouth and the eyebrows.

                            stz <clipx_left
                            stz <clipy_top
                            lda #320
                            sta <clipx_right
                            lda #200
                            sta <clipy_bottom

                            lda #tss~sinistar_mouth_x
                            sta <draw_x

                            lda #tss~sinistar_mouth_y
                            sta <draw_y

                            lda >sinistar_mouth_position
                            tax
; Should be able to use secondary shapes, if there
                            getword {x},>sinistar_mouth_secondary_shape_ptrs+2
                            beq mouth_use_primary
                            sta <shape_ptr+2
                            getword {x},>sinistar_mouth_secondary_shape_ptrs
                            sta <shape_ptr

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            jsl _compiled_basic_shape_draw
                            bra draw_eyebrow

mouth_use_primary           getword {x},>sinistar_mouth_primary_shape_ptrs+2
                            sta <shape_ptr+2
                            getword {x},>sinistar_mouth_primary_shape_ptrs
                            sta <shape_ptr

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            jsl _block_shape_draw

draw_eyebrow                anop
; Eyebrow
                            lda #tss~sinistar_eyebrow_x
                            sta <draw_x

                            lda #tss~sinistar_eyebrow_y
                            sta <draw_y

                            lda >sinistar_eyebrow_position
                            tax
; Should be able to use secondary (compiled) shape, if there
                            getword {x},>sinistar_eyebrow_secondary_shape_ptrs+2
                            beq eyebrow_use_primary
                            sta <shape_ptr+2
                            getword {x},>sinistar_eyebrow_secondary_shape_ptrs
                            sta <shape_ptr

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            jsl _compiled_basic_shape_draw
                            bra update_screen

eyebrow_use_primary         getword {x},>sinistar_eyebrow_primary_shape_ptrs+2
                            sta <shape_ptr+2
                            getword {x},>sinistar_eyebrow_primary_shape_ptrs
                            sta <shape_ptr

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width
                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            jsl _block_shape_draw

update_screen               anop
                            lda #tss~sinistar_update_x
                            sta <draw_x
                            lda #tss~sinistar_update_y
                            sta <draw_y
                            lda #tss~sinistar_update_width
                            sta <area_width
                            lda #tss~sinistar_update_height
                            sta <area_height

                            jsl grlib_custom_alt_screen_to_screen_rect_noclip

                            pld
                            lret
                            end
