                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm

                            copy lib/source/shape.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
; -----------------------------------------------------------------------------
; Startup / Shutdown data for the app
; -----------------------------------------------------------------------------
appdata                     data seg_app

app_state~startup           equ 0               ; showing the startup screen
app_state~frontend          equ 1               ; manager state, that coordinates the other states. Doesn't show anything on its own.
app_state~player_turn_start equ 2               ; showing the turn start splash screen, possibly with a completed Sinistar on it, and giving a taunt.
app_state~gameplay          equ 3               ; showing playfield.  Can be in a 'paused' state, after the player has died, possibly showing 'game over'.  Can also be in demo mode
app_state~high_scores       equ 4               ; showing the high scores
app_state~enter_score       equ 5               ; showing the high score name enter screen
app_state~tutorial          equ 6               ; showing the tutorial screen
app_state~input_overview    equ 7               ; showing the tutorial screen
app_state~copyright         equ 8               ; showing copyright screen.
app_state~credits           equ 9               ; showing credits / special thanks screen.
app_state~demo              equ 10              ; showing demo of gameplay
app_state~config            equ 11              ; showing the configuration screen

appdata~pending_state       dc i'0'
appdata~current_state       dc i'-1'
appdata~previous_state      dc i'-1'

appdata~exit_requested      dc i'0'

appdata~state_activate_table anop
                            dc a4'0'            ; app_state~startup
                            dc a4'frontend_state_activate'                  ; app_state~frontend
                            dc a4'turn_start_state_activate'                ; app_state~player_turn_start
                            dc a4'gameplay_manager_state_activate'          ; app_state~gameplay
                            dc a4'high_score_state_activate'                ; app_state~high_scores
                            dc a4'enter_score_state_activate'               ; app_state~enter_score
                            dc a4'tutorial_state_activate'                  ; app_state~tutorial
                            dc a4'input_overview_state_activate'            ; app_state~input_overview
                            dc a4'copyright_state_activate'                 ; app_state~copyright
                            dc a4'credits_state_activate'                   ; app_state~credits
                            dc a4'0'            ; app_state~demo
                            dc a4'config_state_activate'                    ; app_state~config

appdata~state_deactivate_table anop
                            dc a4'0'            ; app_state~startup
                            dc a4'0'            ; app_state~frontend
                            dc a4'0'            ; app_state~player_turn_start
                            dc a4'0'            ; app_state~gameplay
                            dc a4'0'            ; app_state~high_scores
                            dc a4'0'            ; app_state~enter_score
                            dc a4'0'            ; app_state~tutorial
                            dc a4'0'            ; app_state~input_overview
                            dc a4'0'            ; app_state~copyright
                            dc a4'0'            ; app_state~credits
                            dc a4'0'            ; app_state~demo
                            dc a4'0'            ; app_state~config

appdata~state_tick_table    anop
                            dc a4'0'            ; app_state~startup
                            dc a4'frontend_state_tick'                      ; app_state~frontend
                            dc a4'turn_start_state_tick'                    ; app_state~player_turn_start
                            dc a4'gameplay_manager_state_tick'              ; app_state~gameplay
                            dc a4'high_score_state_tick'                    ; app_state~high_scores
                            dc a4'enter_score_state_tick'                   ; app_state~enter_score
                            dc a4'tutorial_state_tick'                      ; app_state~tutorial
                            dc a4'input_overview_state_tick'                ; app_state~input_overview
                            dc a4'copyright_state_tick'                     ; app_state~copyright
                            dc a4'credits_state_tick'                       ; app_state~credits
                            dc a4'0'            ; app_state~demo
                            dc a4'config_state_tick'                        ; app_state~config

; Tracks the ticks when paused.
appdata~last_paused_tick    ds 4
appdata~last_paused_tick_delta ds 2

appdata~back_handle         dc i4'0'
appdata~altscr_handle       dc i4'0'
appdata~targetscr_handle    dc i4'0'            ; This is used when the app is running without accessing the 'real' screen.  Used with profiling.

; Handle to allocated ZP space for the tools (Quickdraw, if we have that enabled)
appdata~tool_zp_handle      dc i4'0'
appdata~tool_zp             ds 2                ; The ZP location

; The shr palette slots for the upper and lower UI
appdata~ui_upper_shr_palette_slot dc i'$ffff'
appdata~ui_lower_shr_palette_slot dc i'$ffff'

appdata~ui_upper_palette_ptr dc a4'0'
appdata~ui_lower_palette_ptr dc a4'0'

appdata~ui_default_palette  dc i'16'                                ; count
                            dc i'palette_color_format~collapsed'    ; format
; UI Colors.  Right now, this is just a repeat of the playfield palette, mainly because I sometimes have to show playfield
; images, in the UI.  I'm going to keep them separate, in case I do want to fiddle with the palette.
; The allure of having per-scanline palettes, leaves open the possibility of having animated / different colors in the top UI section.
                            dc i'$0000'
                            dc i'$0fd0'
                            dc i'$0ffa'
                            dc i'$0dba'
                            dc i'$0bba'
                            dc i'$099a'
                            dc i'$046a'
                            dc i'$0000'         ; available
                            dc i'$0000'         ; available
                            dc i'$022f'
                            dc i'$0045'
                            dc i'$0625'
                            dc i'$0b00'
                            dc i'$0f00'
                            dc i'$0000'         ; available
                            dc i'$0fff'

; The Gameplay colors.  This is pretty much the exact palette from the original, except white and yellow are swapped, so white is last
appdata~gameplay_color~black~bits       equ $0000
appdata~gameplay_color~yellow~bits      equ $1111
appdata~gameplay_color~light_yellow~bits equ $2222
appdata~gameplay_color~tan~bits         equ $3333
appdata~gameplay_color~light_gray~bits  equ $4444
appdata~gameplay_color~blue_gray~bits   equ $5555
appdata~gameplay_color~light_blue~bits  equ $6666
appdata~gameplay_color~effect1~bits     equ $7777
appdata~gameplay_color~effect2~bits     equ $8888
appdata~gameplay_color~blue~bits        equ $9999
appdata~gameplay_color~dark_green~bits  equ $aaaa
appdata~gameplay_color~purple~bits      equ $bbbb
appdata~gameplay_color~dark_red~bits    equ $cccc
appdata~gameplay_color~red~bits         equ $dddd
appdata~gameplay_color~effect3~bits     equ $eeee
appdata~gameplay_color~white~bits       equ $ffff

; The gameplay colors, as just an index
appdata~gameplay_color~black~index      equ $0
appdata~gameplay_color~yellow~index     equ $1
appdata~gameplay_color~light_yellow~index equ $2
appdata~gameplay_color~tan~index        equ $3
appdata~gameplay_color~light_gray~index equ $4
appdata~gameplay_color~blue_gray~index  equ $5
appdata~gameplay_color~light_blue~index equ $6
appdata~gameplay_color~effect1~index    equ $7
appdata~gameplay_color~effect2~index    equ $8
appdata~gameplay_color~blue~index       equ $9
appdata~gameplay_color~dark_green~index equ $a
appdata~gameplay_color~purple~index     equ $b
appdata~gameplay_color~dark_red~index   equ $c
appdata~gameplay_color~red~index        equ $d
appdata~gameplay_color~effect3~index    equ $e
appdata~gameplay_color~white~index      equ $f

; The palette used with the Config State.  Mostly the same as the default UI one.
appdata~ui_config_state_palette dc i'16'                                ; count
                                dc i'palette_color_format~collapsed'    ; format
                                dc i'$0000'
                                dc i'$0fd0'
                                dc i'$0ffa'
                                dc i'$0dba'
                                dc i'$0bba'
                                dc i'$099a'
                                dc i'$046a'
                                dc i'$0005'
                                dc i'$0000'
                                dc i'$022f'
                                dc i'$0045'
                                dc i'$0625'
                                dc i'$0b00'
                                dc i'$0f00'
                                dc i'$0000'
                                dc i'$0fff'

; The palette used with the High Score State.  Mostly the same as the default UI one.
appdata~ui_high_score_state_palette dc i'16'                            ; count
                                dc i'palette_color_format~collapsed'    ; format
                                dc i'$0000'
                                dc i'$0fd0'
                                dc i'$0ffa'
                                dc i'$0dba'
                                dc i'$0bba'
                                dc i'$099a'
                                dc i'$046a'
                                dc i'$0005'
                                dc i'$0000'
                                dc i'$022f'
                                dc i'$0045'
                                dc i'$0625'
                                dc i'$0b00'
                                dc i'$0f00'
                                dc i'$0000'
                                dc i'$0fff'

; This extends the 4-bit value to 16-bits
appdata~palette_index_to_bits   dc i'$0000'
                                dc i'$1111'
                                dc i'$2222'
                                dc i'$3333'
                                dc i'$4444'
                                dc i'$5555'
                                dc i'$6666'
                                dc i'$7777'
                                dc i'$8888'
                                dc i'$9999'
                                dc i'$aaaa'
                                dc i'$bbbb'
                                dc i'$cccc'
                                dc i'$dddd'
                                dc i'$eeee'
                                dc i'$ffff'

; These colors are stuffed into color index 0, to replace the background color during the turn start screen
appdata~palette_color~dark_blue         equ $0005
appdata~palette_color~dark_red          equ $0500
appdata~palette_color~black             equ $0000

appdata~font_primary~height             equ 8
appdata~font_primary~space_width        equ 5

appdata~font_teeny~height               equ 5
appdata~font_teeny~space_width          equ 4

appdata~font_secondary~height           equ 8
appdata~font_secondary~space_width      equ 5


appdata~use_sndlib          dc i'1'                         ; whether or not to use the sound library.  This will be updated by the config on load.

appdata~wait_time           dc i'0'
appdata~paused              dc i'0'
appdata~debug_update_rects  dc i'0'                         ; Options flag to turn on update-rect debugging.
appdata~debug_collision_rects dc i'0'                       ; Options flag to turn on collision-rect debugging.

appdata~primary_font_ptr    dc i4'0'
appdata~teeny_font_ptr      dc i4'0'
appdata~secondary_font_ptr  dc i4'0'

; These are adjustable from the user configuration
appdata~sound_disabled      dc i'0'                         ; All sound is disabled
appdata~attract_sound_disabled dc i'0'                      ; Sound is dsabled just in attract mode
appdata~fps_pip             dc i'0'                         ; if true, we show th FPS Pip in the upper right (yellow = 60fps, blue = 30fps, red <= 20fps)
appdata~fps_limiter         dc i'0'                         ; if true, we always wait at least 2 ticks per frame update (30 fps)
                            end

; -----------------------------------------------------------------------------
; This data segment is specifically defined so that we can use the OMF system to map access to commonly used data.
; Note that this also requests that the data segment is aligned so that starts on a bank boundary.
; This will allow the pointer reference to the data be interchangeably used used with long or short absolute addressing,
; where the index  register is used as a short-pointer, and the address in code, is used as the struct offset.
; It also allows for long-indirect addressing, with the 4-byte DP address and Y used as the compile-time struct offset
                            align $10000
appdata_segment_data        data seg_app1
; This should be first, so the resulting address ins $BB0000
entities_root               entry                           ; used when making an absolute long reference to an entity, so that the OMF system is going to just remap to the bank.

; This is here so that the first item in the segment (entity_buffers), does not start
; at $0000 in the bank, so that we can still check for 'null' on a short-pointer.
appdata_segment_pad         ds 2

; Note, using 'entry' declarations, just so I don't have to put using statements everywhere

entities_buffer_size        equ 32768
entity_buffers              ds entities_buffer_size
player_entity_instance      entry                           ; the static location for the player entity
                            ds sizeof~player_entity

                            end
