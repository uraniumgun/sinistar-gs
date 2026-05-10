; A player state definition.  This includes all state that is preserved between player turns.
; This includes the Population table as well as the difficulty state.
player_state                            gequ 0
player_state~ship_count                 gequ player_state                               ; Ships remaining.  (SHIPS)
player_state~bomb_count                 gequ player_state~ship_count+2                  ; Number of bombs the player has (BOMBS)
player_state~score                      gequ player_state~bomb_count+2                  ; Player score, stored as 32-bit BCD! (PSCORE)
player_state~next_ship_score            gequ player_state~score+4                       ; Next ship score, also 32-bit BCD (NSCORE)
player_state~extra_ship_points          gequ player_state~next_ship_score+4             ; The number of points to get the next extra ship (EXTRADD) Note, I'm NOT storing x100 like the original
player_state~extra_ship_add             gequ player_state~extra_ship_points+4           ; The number of points to increment the extra_ship_points (EXTRINC) Note, I'm NOT storing x100 like the original
player_state~next_ship_score_wrapped    gequ player_state~extra_ship_add+4              ; Has the next-ship-score wrapped around? (WRAPFLG)
player_state~sinistar~pieces_built      gequ player_state~next_ship_score_wrapped+2     ; total number of pieces in sinistar
player_state~sinistar~state             gequ player_state~sinistar~pieces_built+2       ; what state is sinistar in?
player_state~sinistars_killed           gequ player_state~sinistar~state+2              ; Number of sinistars killed by the player.  Affects difficulty. (SiniKills)
player_state~difficulty_timer           gequ player_state~sinistars_killed+2            ; Timer value for the difficulty increase. (DTime)
player_state~difficulty_table_ptr       gequ player_state~difficulty_timer+2            ; This is where the active player is, in the difficulty processing.
player_state~warrior_aggression         gequ player_state~difficulty_table_ptr+4        ; warrior aggression (Wagg)
player_state~new_level                  gequ player_state~warrior_aggression+2          ; if set, the player is starting the level for the first time.
player_state~zone_color                 gequ player_state~new_level+2                   ; The zone color.  Used for UI coloring. (ZONECOL)
player_state~use_keyboard               gequ player_state~zone_color+2                  ; if set, the player wants to use the keyboard for input.  NOT mutually exclusive with gamepad
player_state~use_gamepad                gequ player_state~use_keyboard+2                ; if set, the player wants to use the gamepad for input.  Can be 1 or 2.  NOT mutually exclusive with the keyboard
player_state~use_analog_joystick        gequ player_state~use_gamepad+2                 ; if set, the player wants to use the analog joystick.
; Desired population values.
; Note these values are fp16, with the upper 8 bits being the signed integer value of the desired amount.
player_state~desired_pop                gequ player_state~use_analog_joystick+2
player_state~desired_pop~workers        gequ player_state~desired_pop
player_state~desired_pop~warriors       gequ player_state~desired_pop~workers+2
player_state~desired_pop~planetoids1    gequ player_state~desired_pop~warriors+2
player_state~desired_pop~planetoids2    gequ player_state~desired_pop~planetoids1+2
player_state~desired_pop~planetoids3    gequ player_state~desired_pop~planetoids2+2
player_state~desired_pop~planetoids4    gequ player_state~desired_pop~planetoids3+2
player_state~desired_pop~planetoids5    gequ player_state~desired_pop~planetoids4+2

sizeof~player_state                     gequ player_state~desired_pop~planetoids5+2

gameplay_max_players                    gequ 2
gameplay_player~max_bomb_count          gequ 16

