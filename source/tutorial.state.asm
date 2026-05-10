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

                            copy source/gameplay.constants.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/ui.entity.definitions.asm
                            copy source/app.debug.definitions.asm

                            mcopy generated/tutorial.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; The Tutorial screen

tutorial_state_data         data seg_gameplay

tutorial_state~display_time equ 60*10

tutorial_state~last_tick  ds 4
tutorial_state~countdown  ds 2

tutorial_state~update_rate equ 1
                            end
; ----------------------------------------------------------------------------
tutorial_state_initialize   start seg_gameplay
                            using appdata

                            debugtag 'tutorial_state_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
tutorial_state_activate     start seg_gameplay
                            using appdata
                            using applib_data
                            using tutorial_state_data
                            using softswitch_definitions
                            using grlib_global_data
                            using sinistar_entity_data
                            using rock_entity_data
                            using warrior_entity_data
                            using worker_entity_data
                            using crystal_entity_data
                            using playfield_manager_data
                            using gameplay_level_data
                            using gameplay_player_logic_data
                            using gameplay_manager_data
                            using ui_entity_data
                            using gameplay_ui_data

                            debugtag 'tutorial_state_activate'

                            begin_locals
wX                          decl word
wY                          decl word
wSpaceWidth                 decl word
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

image_to_text_x             equ 20
image_to_text_y             equ 4
image_to_next_y             equ 26

planetoid_offset_x          equ 100
planetoid_offset_y          equ 22
planetoid_text_x_offset     equ planetoid_offset_x+image_to_text_x
planetoid_text_y_offset     equ planetoid_offset_y+image_to_text_y

worker_offset_x             equ planetoid_offset_x
worker_offset_y             equ planetoid_offset_y+image_to_next_y
worker_text_x_offset        equ worker_offset_x+image_to_text_x
worker_text_y_offset        equ worker_offset_y+image_to_text_y

crystal_offset_x            equ planetoid_offset_x
crystal_offset_y            equ worker_offset_y+image_to_next_y
crystal_text_x_offset       equ crystal_offset_x+image_to_text_x
crystal_text_y_offset       equ crystal_offset_y+image_to_text_y

warrior_offset_x            equ planetoid_offset_x
warrior_offset_y            equ crystal_offset_y+image_to_next_y
warrior_text_x_offset       equ warrior_offset_x+image_to_text_x
warrior_text_y_offset       equ warrior_offset_y+image_to_text_y

sinistar_offset_x           equ planetoid_offset_x
sinistar_offset_y           equ warrior_offset_y+image_to_next_y
sinistar_text_x_offset      equ sinistar_offset_x+image_to_text_x
sinistar_text_y_offset      equ sinistar_offset_y+image_to_text_y

destroy_sinistar_text1_width    equ 130
destroy_sinistar_text1_x_offset equ 0+(320-destroy_sinistar_text1_width)/2
destroy_sinistar_text1_y_offset equ sinistar_text_y_offset+20

destroy_sinistar_text2_x_offset equ 120
destroy_sinistar_text2_y_offset equ destroy_sinistar_text1_y_offset+12

start_text1_width           equ 140
start_text1_x_offset        equ 0+(320-start_text1_width)/2
start_text1_y_offset        equ destroy_sinistar_text2_y_offset+11

start_text2_width           equ 116
start_text2_x_offset        equ 0+(320-start_text2_width)/2
start_text2_y_offset        equ start_text1_y_offset+8

start_text3_width           equ 140
start_text3_x_offset        equ 0+(320-start_text3_width)/2
start_text3_y_offset        equ start_text2_y_offset+8

start_text4_width           equ 140
start_text4_x_offset        equ 0+(320-start_text3_width)/2
start_text4_y_offset        equ start_text3_y_offset+8

version_text_x_offset       equ 4
version_text_y_offset       equ 200-1

                            lda #appdata~gameplay_color~black~bits
                            jsl grlib_fill_alt_screen

                            lda #grlib~blit_mode_2
                            jsl grlib_set_font_blit_mode

                            pushptr >appdata~teeny_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~font_teeny~space_width                 ; setup our space width for the points drawing
                            sta <wSpaceWidth

; Need one object to draw some images
                            pushptr #ui_entity_object
                            jsl object_new
;                           bcs failed
                            putretptr <pEntity

; Draw the scores for the 5 main things we can shoot at.
; Probably could make this into a table and loop over that, but I'm lazy.

; Draw the planetoid
                            pushretptr
                            pushptr #rock_entity_image_collection_id
                            pushsword #framelib_set_id_walk
                            pushsword #1                                        ; the mid-sized planetoid
                            jsl ui_entity_load

                            pushptr <pEntity
                            pushsword #planetoid_offset_x
                            pushsword #planetoid_offset_y
                            jsl grlib_draw_sprite

                            lda #appdata~gameplay_color~tan~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_planetoids
                            pushsword #planetoid_text_x_offset
                            lda #planetoid_text_y_offset
                            sta <wY
                            pha
                            jsl grlib_draw_string
; Draw the points

                            ldy #gameplay_score~planetoid
                            ldx #^gameplay_score~planetoid
                            jsr _draw_points

; Draw the worker

                            pushptr <pEntity
                            pushptr #worker_entity_image_collection_id
                            pushsword #framelib_set_id_walk
                            pushsword #0
                            jsl ui_entity_load

                            pushptr <pEntity
                            pushsword #worker_offset_x
                            pushsword #worker_offset_y
                            jsl grlib_draw_sprite

                            lda #appdata~gameplay_color~tan~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_worker
                            pushsword #worker_text_x_offset
                            lda #worker_text_y_offset
                            sta <wY
                            pha
                            jsl grlib_draw_string
; Draw the points
                            ldy #gameplay_score~kill_worker
                            ldx #^gameplay_score~kill_worker
                            jsr _draw_points

; Draw the Crystal

                            pushptr <pEntity
                            pushptr #crystal_entity_image_collection_id
                            pushsword #framelib_set_id_walk
                            pushsword #0
                            jsl ui_entity_load

                            pushptr <pEntity
                            pushsword #crystal_offset_x
                            pushsword #crystal_offset_y
                            jsl grlib_draw_sprite

                            lda #appdata~gameplay_color~tan~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_crystals
                            pushsword #crystal_text_x_offset
                            lda #crystal_text_y_offset
                            sta <wY
                            pha
                            jsl grlib_draw_string
; Draw the points
                            ldy #gameplay_score~capture_crystal
                            ldx #^gameplay_score~capture_crystal
                            jsr _draw_points

; Draw the Warrior

                            pushptr <pEntity
                            pushptr #warrior_entity_image_collection_id
                            pushsword #framelib_set_id_walk
                            pushsword #0
                            jsl ui_entity_load

                            pushptr <pEntity
                            pushsword #warrior_offset_x
                            pushsword #warrior_offset_y
                            jsl grlib_draw_sprite

                            lda #appdata~gameplay_color~tan~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_warrior
                            pushsword #warrior_text_x_offset
                            lda #warrior_text_y_offset
                            sta <wY
                            pha
                            jsl grlib_draw_string
; Draw the points
                            ldy #gameplay_score~kill_warrior
                            ldx #^gameplay_score~kill_warrior
                            jsr _draw_points

; Draw the Sinistar Part

                            pushptr <pEntity
                            pushptr #sinistar_entity_image_collection_id
                            pushsword #framelib_set_id_walk
                            pushsword #0
                            jsl ui_entity_load

                            pushptr <pEntity
                            pushsword #sinistar_offset_x
                            pushsword #sinistar_offset_y
                            jsl grlib_draw_sprite

                            lda #appdata~gameplay_color~tan~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_sinistar1
                            pushsword #sinistar_text_x_offset
                            lda #sinistar_text_y_offset
                            sta <wY
                            pha
                            jsl grlib_draw_string
; Draw the points
                            ldy #gameplay_score~kill_sinistar_part
                            ldx #^gameplay_score~kill_sinistar_part
                            jsr _draw_points

                            lda #appdata~gameplay_color~light_yellow~bits
                            jsl grlib_set_font_fore_color

; The 'how to start' text
                            pushdword #str_press_fire
                            pushsword #0
                            pushsword #320
                            pushsword #start_text1_y_offset
                            jsl grlib_draw_string_centered

                            pushdword #str_press_1_or_2
                            pushsword #0
                            pushsword #320
                            pushsword #start_text2_y_offset
                            jsl grlib_draw_string_centered

                            pushdword #str_press_C
                            pushsword #0
                            pushsword #320
                            pushsword #start_text3_y_offset
                            jsl grlib_draw_string_centered

                            pushdword #str_press_I
                            pushsword #0
                            pushsword #320
                            pushsword #start_text4_y_offset
                            jsl grlib_draw_string_centered

; Version

                            lda #appdata~gameplay_color~blue_gray~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_version
                            pushsword #version_text_x_offset
                            pushsword #version_text_y_offset
                            jsl grlib_draw_string

; Score for destroying Sinistar
                            pushptr >appdata~primary_font_ptr
                            jsl grlib_set_active_font_ptr

                            lda #appdata~gameplay_color~red~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_sinistar2
                            pushsword #destroy_sinistar_text1_x_offset
                            pushsword #destroy_sinistar_text1_y_offset
                            jsl grlib_draw_string

                            lda #destroy_sinistar_text2_y_offset
                            sta <wY
                            lda #appdata~font_primary~space_width
                            sta <wSpaceWidth

                            lda #destroy_sinistar_text2_x_offset
                            ldy #gameplay_score~kill_sinistar
                            ldx #^gameplay_score~kill_sinistar
                            jsr _draw_points

; Clean up
                            pushptr <pEntity
                            pushptr #ui_entity_object
                            jsl object_delete

                            pushsword #gameplay_ui~palette_id~playfield         ; using a copy of the playfield palette, as we are drawing playfield images
                            jsl gameplay_ui_show_screen

                            lda >applib~current_tick
                            sta tutorial_state~last_tick
                            lda >applib~current_tick+2
                            sta tutorial_state~last_tick+2

                            lda #tutorial_state~display_time
                            sta tutorial_state~countdown

                            restoredatabank
                            ret

;; Local Functions

_draw_points                anop
; Assume A has the x offset from the last print
                            clc
                            adc #appdata~font_teeny~space_width
                            sta <wX                      ; save the X position
; X/Y has the points
                            phx
                            phy

                            lda #appdata~gameplay_color~blue~bits
                            jsl grlib_set_font_fore_color

; points, already on stack
                            pushsword <wX
                            pushsword <wY
                            jsl grlib_draw_bcd32
                            clc
                            adc <wSpaceWidth
                            sta <wX

                            lda #appdata~gameplay_color~blue_gray~bits
                            jsl grlib_set_font_fore_color

                            pushdword #str_points
                            pushsword <wX
                            pushsword <wY
                            jsl grlib_draw_string
                            rts

str_points                  cstring 'POINTS'
str_planetoids              cstring 'PLANETOIDS'
str_worker                  cstring 'WORKER'
str_crystals                cstring 'CRYSTALS'
str_warrior                 cstring 'WARRIOR'
str_sinistar1               cstring 'SINISTAR PIECES'
str_sinistar2               cstring 'DESTROY THE SINISTAR'
str_press_fire              cstring 'PRESS FIRE BUTTON TO SEE HIGH SCORE'
str_press_1_or_2            cstring 'PRESS START OR 1 OR 2 TO PLAY'
str_press_C                 cstring 'PRESS SELECT OR C FOR CONFIGURATION'
str_press_I                 cstring 'PRESS I FOR INFORMATION'
str_version                 cstring 'VERSION 0.5'
                            end

; ----------------------------------------------------------------------------
tutorial_state_tick         start seg_gameplay
                            using appdata
                            using applib_data
                            using tutorial_state_data

                            debugtag 'tutorial_state_tick'

                            jsl applib_update_tick_count
                            jsl sndlib_manager_update

                            setlocaldatabank

; Get the tick delta
                            lda >applib~current_tick
                            sec
                            sbc tutorial_state~last_tick
                            tax
                            lda >applib~current_tick+2
                            sbc tutorial_state~last_tick+2
                            bne timer_expired                       ; If this happened, we got stuck for quite a while
                            cpx #tutorial_state~update_rate
                            blt done

do_update                   lda >applib~current_tick
                            sta tutorial_state~last_tick
                            lda >applib~current_tick+2
                            sta tutorial_state~last_tick+2

; X has the tick delta, lower word
                            txa
                            negate a
                            clc
                            adc tutorial_state~countdown
                            sta tutorial_state~countdown
                            beq timer_expired
                            bpl continue                           ; still more to go?
;
timer_expired               anop
                            pushsword #app_state~tutorial
                            jsl frontend_set_next_state
                            bcc done
; restart
restart                     lda #tutorial_state~display_time
                            sta tutorial_state~countdown

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
