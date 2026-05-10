                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/fixed.buffer.pool.definitions.asm
                                copy lib/source/grlib.definitions.asm
                                copy lib/source/grlib.sprite.definitions.asm
                                copy lib/source/framelib.definitions.asm
                                copy lib/source/grlib.entity.definitions.asm
                                copy lib/source/grlib.entity.sort.definitions.asm

                                copy source/app.system.ids.asm
                                copy source/task.definitions.asm
                                copy source/playfield.definitions.asm
                                copy source/playfield.entity.definitions.asm
                                copy source/explosion.entity.definitions.asm
                                copy source/gameplay.constants.asm
                                copy source/gameplay.entity.characteristic.definitions.asm

                                mcopy generated/explosion.entity.manager.macros

                                longa on
                                longi on

; Manager for all the 'explosion' entities

; --------------------------------------------------------------------------------------------
explosion_entity_manager_data   data seg_entity

; Entity Manager object
explosion_entity_manager~pool   gequ 0
sizeof~explosion_entity_manager gequ explosion_entity_manager~pool+sizeof~fixed_buffer_pool

; Player explosion part counts
player_primary_fragments_count equ 7
player_secondary_fragments_count equ 10     ; This is per wave
player_secondary_fragment_waves equ 4

; Warrior explosion
warrior_explosion_fragments_count equ 10

; Rock explosion
rock_explosion_small_fragments_count equ 3
rock_explosion_medium_fragments_count equ 5
rock_explosion_large_fragments_count equ 7

global_explosion_entity_manager_is_initialized dc i'0'

; The global entity manager
global_explosion_entity_manager ds sizeof~explosion_entity_manager

explosion~player_secondary_task_ptr dc a4'0'
explosion~player_streaks_task_ptr   dc a4'0'


explosion~player_secondary_task_data    begin_struct
explosion~player_secondary_task_data~x  decl word           ; x location for the explosion
explosion~player_secondary_task_data~y  decl word           ; y location for the explosion
explosion~player_secondary_task_data~count decl word        ; the number of waves to generate
sizeof~explosion~player_secondary_task_data end_struct

max_explosion_entity_count      equ 64
explosion_entity_count          dc i'0'
explosion_entity_array          ds max_explosion_entity_count*2

explosion_entity_next_remove_index dc i'0'
explosion_entity_remove_count      dc i'0'
explosion_entity_remove_array      ds max_explosion_entity_count*2

; The animation timers.  Note this is per-frame of the image.  The basic explosion has 3, the warrior fragment has 4
; No animation for the rock fragments
explosion_animation~basic   equ 4
explosion_animation~warrior equ 8
explosion_animation~player_fragment2 equ 2

explosion~stream_task_data              begin_struct
explosion~streak_task_data~x            decl word           ; x location for the explosion
explosion~streak_task_data~y            decl word           ; y location for the explosion
explosion~streak_task_data~waves_remaining decl word        ; the number of waves to generate
explosion~streak_task_data~wave_timer   decl word           ; timer for the next wave
explosion~streak_task_data~life_timer   decl word           ; timer for the entire sequence
sizeof~explosion~streak_task_data       end_struct

explosion~streak_life_timer equ 24                          ; passes through the task
explosion~streak_wave_timer equ 2
explosion~streak_waves      equ 3
explosion~streaks_per_wave  equ 10
explosion~max_streaks       equ explosion~streaks_per_wave*explosion~streak_waves

; Number of active streaks
explosion~streak_count      dc i'0'

; Struct of arrays style
streak_nodes~x              ds 2*explosion~max_streaks
streak_nodes~y              ds 2*explosion~max_streaks
streak_nodes~speed_x        ds 2*explosion~max_streaks
streak_nodes~speed_y        ds 2*explosion~max_streaks
streak_nodes~move_accum_x   ds 2*explosion~max_streaks
streak_nodes~move_accum_y   ds 2*explosion~max_streaks
streak_nodes~address        ds 2*explosion~max_streaks
streak_nodes~pixel_value    ds 2*explosion~max_streaks

; The cycled streak colors (RGB)
explosion~streak_colors     anop
                            dc i'$0000' ;%00000000
                            dc i'$0022' ;%01001000
                            dc i'$0248' ;%10010001
                            dc i'$042F' ;%11001010
                            dc i'$0808' ;%10000100
                            dc i'$0C02' ;%01000110
                            dc i'$0F00' ;%00000111
                            dc i'$0F40' ;%00010111
                            dc i'$0F84' ;%01100111
                            dc i'$0FA8' ;%10101111
                            dc i'$0FFF' ;%11111111
                            dc i'$0FFF' ;%11111111

                                end
; --------------------------------------------------------------------------------------------
; Initialize the global explosion entity manager.
;
explosion_entity_manager_initialize start seg_entity
                                using explosion_entity_manager_data

                                debugtag 'initialize'
                                debugtag 'explosion_entity_manager'

                                lda >global_explosion_entity_manager_is_initialized
                                bne is_initialized

                                setlocaldatabank

; Pre-load images
                                jsl explosion_entity_preload_images

                                lda #1
                                sta global_explosion_entity_manager_is_initialized
                                stz explosion~streak_count

                                restoredatabank

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
explosion_entity_manager_uninitialize start seg_entity
                                using explosion_entity_manager_data

                                debugtag 'uninitialize'
                                debugtag 'explosion_entity_manager'

                                lda >global_explosion_entity_manager_is_initialized
                                beq exit

                                setlocaldatabank

                                pushptr explosion~player_secondary_task_ptr
                                jsl task_manager_free_task
                                clearptr explosion~player_secondary_task_ptr

                                pushptr explosion~player_streaks_task_ptr
                                jsl task_manager_free_task
                                clearptr explosion~player_streaks_task_ptr

                                stz global_explosion_entity_manager_is_initialized
                                stz explosion~streak_count
                                restoredatabank

exit                            anop
                                rtl

                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
explosion_entity_manager_turn_deactivate start seg_entity
                                using explosion_entity_manager_data

                                debugtag 'turn_deativate'
                                debugtag 'explosion_entity_manager'

                                setlocaldatabank
; Make sure any tasks that are not tied to entities are cleared.
                                pushptr explosion~player_secondary_task_ptr
                                jsl task_manager_free_task
                                clearptr explosion~player_secondary_task_ptr

                                pushptr explosion~player_streaks_task_ptr
                                jsl task_manager_free_task
                                clearptr explosion~player_streaks_task_ptr

                                jsl explosion_entity_manager_remove_all

                                stz explosion~streak_count
                                restoredatabank

                                rtl

                                end

; ----------------------------------------------------------------------------
; Add a explosion to the playfield, using a source entity for starting information
; Parameters:
; pSrcEntity    - the entity that is exploding.
explosion_entity_manager_add_explosion start seg_entity
                            using appdata
                            using grlib_update_rects_data2
                            using explosion_entity_data
                            using explosion_entity_manager_data
                            using gameplay_level_data
                            using gameplay_entity_data
                            using gameplay_sound_data
                            using task_manager_data

                            debugtag 'explosion_add'

                            begin_locals
spEntity                    decl word
pTaskData                   decl ptr
wSlotIndex                  decl word
wEntityCount                decl word
wCenterX                    decl word
wCenterY                    decl word
work_area_size              end_locals

                            sub (4:pSrcEntity),work_area_size

                            setlocaldatabank

; Everything needs the center location, so get it now
                            getword [<pSrcEntity],#playfield_entity~grentity+grlib_entity~x
                            sta <wCenterX
                            getword [<pSrcEntity],#playfield_entity~grentity+grlib_entity~y
                            sta <wCenterY

                            getword [<pSrcEntity],#playfield_entity~characteristic_id
                            tax
                            lda >characteristics_table+gameplay_entity_characteristic~explosion_type,x
                            asl a
                            tax
                            jsr (explosion_type_subtable,x)

                            restoredatabank
                            ret

;;;; Basic explosion
; Used by workers
basic_explosion             anop
                            lda explosion_entity_count
                            cmp #max_explosion_entity_count
                            blt basic_ok
                            rts

basic_ok                    asl a
                            sta <wSlotIndex

                            pushsword #explosion_image~basic
                            pushsword #explosion_variation~default
                            jsl explosion_entity_new
                            bcs error

                            inc explosion_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta explosion_entity_array,y

                            tax

                            lda <wCenterX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wCenterY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

; Set animation speed
                            lda #explosion_animation~basic
                            putword {x},>entities_root+playfield_entity~frame_animation_timer
                            putword {x},>entities_root+playfield_entity~frame_animation_rate

                            inline_entity_add_to_playfield {>x}

; Copy over the direction and speed
                            getword [<pSrcEntity],#playfield_entity~direction
                            putword {x},>entities_root+playfield_entity~direction
                            putword {x},>entities_root+playfield_entity~desired_direction

                            getword [<pSrcEntity],#playfield_entity~speed_x
                            putword {x},>entities_root+playfield_entity~speed_x
                            getword [<pSrcEntity],#playfield_entity~speed_y
                            putword {x},>entities_root+playfield_entity~speed_y

; The rest of the explosion setup will be done when its mission code is updated.
error                       anop
                            rts

;;; Rock explosion
; This puts 4 - 8 small rocks (drawn as explosion entities) that speed away from the
; center of the explosion.
rock_explosion_small        anop
                            lda #rock_explosion_small_fragments_count
                            bra rock_explosion_start
rock_explosion_medium       anop
                            lda #rock_explosion_medium_fragments_count
                            bra rock_explosion_start
rock_explosion_large        anop
                            lda #rock_explosion_large_fragments_count

rock_explosion_start        sta <wEntityCount


rock_explosion_loop         lda explosion_entity_count
                            cmp #max_explosion_entity_count
                            blt rock_ok
                            rts

rock_ok                     asl a
                            sta <wSlotIndex

                            pushsword #explosion_image~rock
                            pushsword #explosion_variation~default
                            jsl explosion_entity_new
                            bcs rock_error

                            inc explosion_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta explosion_entity_array,y

; Set a random direction and speed
                            pha
                            generate_rnd16
                            and #direction~range-1                          ; Random direction
                            pha

                            get_quick_rnd16
                            and #15                                         ; there are 4 fractional levels, per integer level, so this is 0 - 3.75
                            clc
                            adc #speed~2_00                                 ; plus a minimum
                            pha
                            jsl playfield_entity_set_speed

                            ldx <spEntity
                            lda <wCenterX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wCenterY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

                            dec <wEntityCount
                            bne rock_explosion_loop

rock_error                  anop
                            rts

;;; Warrior explosion
; This puts 10 small fragments at center of the explosion.
warrior_explosion           anop
                            lda #warrior_explosion_fragments_count
                            sta <wEntityCount

warrior_explosion_loop      lda explosion_entity_count
                            cmp #max_explosion_entity_count
                            blt warrior_ok
                            rts

warrior_ok                  asl a
                            sta <wSlotIndex

                            pushsword #explosion_image~warrior
                            pushsword #explosion_variation~default
                            jsl explosion_entity_new
                            bcs warrior_error

                            inc explosion_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta explosion_entity_array,y

; Set a random direction and speed
                            pha
                            generate_rnd16
                            tay
                            and #direction~range-1                           ; Random direction, from the low-byte
                            pha

                            tya                                             ; Random speed, from the high bu=yte
                            xba
                            and #$07                                        ; there are 4 fractional levels, per integer level, so this is 0 - 1.75
                            clc
                            adc #speed~2_00                                 ; Add a minumum speed
                            pha
                            jsl playfield_entity_set_speed


; Set the animation speed.
; Randomize these a bit, so they fade at different times

                            get_quick_rnd16
                            and #$0007
                            clc
                            adc #explosion_animation~warrior
                            ldx <spEntity
                            putword {x},>entities_root+playfield_entity~frame_animation_timer
                            putword {x},>entities_root+playfield_entity~frame_animation_rate

                            lda <wCenterX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wCenterY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

                            dec <wEntityCount
                            bne warrior_explosion_loop

warrior_error               anop
                            rts

;;; Player explosion
; This is complicated.
; * There is a basic explosion at the center.
; * Then there are the ship 'fragments', which I'm going to do like the warrior explosion framgments.
; * Then there are the extra framement, which are again, like warrior explosion framgments
;   though these cycle their animation in a loop and don't die until off screen.
;   Also, these are staggered into 4 waves.
; * Then there are streaks.  These are single pixels that radiate out, drawing with pixel value $E
;   which is one of the effects colors, and that effect color is cycled through the overall
;   explosion time.

player_explosion            anop

; Put the basic explosion at the center
                            jsr basic_explosion
; The the player fragments
                            jsr player_fragments
; The secondary fragments
                            jsr player_secondary_fragments
; The streaks
                            jsr player_streaks
; Play the first part of the explosion sound
                            pushsword #id_sfx~player_explosion_1
                            jsl sndlib_play_sfx

                            rts


; Primary fragments
player_fragments            anop
                            lda #player_primary_fragments_count
                            sta <wEntityCount

player_fragment_loop        lda explosion_entity_count
                            cmp #max_explosion_entity_count
                            blt player_fragment_ok
                            rts

player_fragment_ok          asl a
                            sta <wSlotIndex

                            pushsword #explosion_image~player_fragment
                            pushsword #explosion_variation~default
                            jsl explosion_entity_new
                            bcs player_fragment_error

                            inc explosion_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta explosion_entity_array,y

                            tax

                            lda <wCenterX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wCenterY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

; Set a random direction and speed
                            phx
                            generate_rnd16
                            tay
                            and #direction~range-1                           ; Random direction, from the low-byte
                            pha

                            tya                                             ; Random speed, from the high byte
                            xba
                            and #$07                                        ; there are 4 fractional levels, per integer level, so this is 0 - 1.75
                            clc
                            adc #speed~1_00                                 ; Add a minumum speed
                            pha
                            jsl playfield_entity_set_speed

                            dec <wEntityCount
                            bne player_fragment_loop

player_fragment_error       anop
                            rts

; Secondary fragments
; These are generated in a task, to allow for creating several waves of them

player_secondary_fragments  pushsword #task_list_4_offset
                            pushptr #_task_player_secondary_fragments
                            pushsword #sizeof~explosion~player_secondary_task_data
                            jsl task_manager_create_task
                            putretptr explosion~player_secondary_task_ptr
                            putretptr <pTaskData
                            lda <wCenterX
                            putword [<pTaskData],#explosion~player_secondary_task_data~x
                            lda <wCenterY
                            putword [<pTaskData],#explosion~player_secondary_task_data~y
                            lda #player_secondary_fragment_waves
                            putword [<pTaskData],#explosion~player_secondary_task_data~count
                            rts

; The 'streaks' task
player_streaks              pushsword #task_list_2_offset
                            pushptr #_task_player_streaks
                            pushsword #sizeof~explosion~streak_task_data
                            jsl task_manager_create_task
                            putretptr explosion~player_streaks_task_ptr
                            putretptr <pTaskData
; We want the sceen space coordinates
                            lda <wCenterX
                            clc
                            adc >update_rect_to_screen_space_offset_x
                            putword [<pTaskData],#explosion~streak_task_data~x
                            lda <wCenterY
                            clc
                            adc >update_rect_to_screen_space_offset_y
                            putword [<pTaskData],#explosion~streak_task_data~y
                            lda #explosion~streak_waves
                            putword [<pTaskData],#explosion~streak_task_data~waves_remaining
                            lda #0                                      ; set the wave timer to 0, so we get the first wave right away.
                            putword [<pTaskData],#explosion~streak_task_data~wave_timer
                            lda #explosion~streak_life_timer
                            putword [<pTaskData],#explosion~streak_task_data~life_timer

                            rts

;;;; Null Explosion
; Doesn't do anything.
null_explosion              anop
                            rts

explosion_type_subtable     anop
                            dc a2'null_explosion'
                            dc a2'basic_explosion'
                            dc a2'rock_explosion_small'
                            dc a2'rock_explosion_medium'
                            dc a2'rock_explosion_large'
                            dc a2'warrior_explosion'
                            dc a2'player_explosion'
                            dc a2'null_explosion'   ; sinstar framement.  Only handled in the 'at' instancer

                            end

;;;

; ----------------------------------------------------------------------------
; Update the player secondary fragment waves
_task_player_secondary_fragments private seg_entity
                            using explosion_entity_manager_data
                            using gameplay_level_data
                            using gameplay_sound_data
                            using task_manager_data

                            debugtag 'update_difficulty'

                            begin_locals
wEntityCount                decl word
wSlotIndex                  decl word
wCenterX                    decl word
wCenterY                    decl word
spEntity                    decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

                            getword [<pTaskData],#explosion~player_secondary_task_data~x
                            sta <wCenterX
                            getword [<pTaskData],#explosion~player_secondary_task_data~y
                            sta <wCenterY

                            lda #player_secondary_fragments_count
                            sta <wEntityCount

loop                        lda explosion_entity_count
                            cmp #max_explosion_entity_count
                            jge done

                            asl a
                            sta <wSlotIndex

                            pushsword #explosion_image~player_fragment2
                            pushsword #explosion_variation~default
                            jsl explosion_entity_new
                            bcs error

                            inc explosion_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta explosion_entity_array,y

; Set a random direction and speed
                            pha
                            generate_rnd16
                            tay
                            and #direction~range-1                          ; Random direction, from the low-byte
                            pha

                            tya                                             ; Random speed, from the high bu=yte
                            xba
                            and #$07                                        ; there are 4 fractional levels, per integer level, so this is 0 - 1.75
                            clc
                            adc #speed~3_00                                 ; Add a minumum speed
                            pha
                            jsl playfield_entity_set_speed

; Set the animation speed, slightly randomized
                            get_quick_rnd16
                            and #$0003
                            clc
                            adc #explosion_animation~player_fragment2
                            ldx <spEntity
                            putword {x},>entities_root+playfield_entity~frame_animation_timer
                            putword {x},>entities_root+playfield_entity~frame_animation_rate

                            lda <wCenterX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wCenterY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

                            dec <wEntityCount
                            bne loop

error                       anop

                            getword [<pTaskData],#explosion~player_secondary_task_data~count
                            dec a
                            beq done
                            putword [<pTaskData],#same

; Play the second part of the explosion sound
                            cmp #1
                            bne exit

                            pushsword #id_sfx~player_explosion_2
                            jsl sndlib_play_sfx

exit                        restoredatabank
                            ret

; Clear the task
done                        pushptr <pTaskData
                            jsl task_manager_free_task
                            clearptr explosion~player_secondary_task_ptr
                            bra exit

                            end

; ----------------------------------------------------------------------------
; Update the player secondary streaks
_task_player_streaks        private seg_entity
                            using YLookupData
                            using explosion_entity_manager_data
                            using playfield_manager_data
                            using gameplay_level_data
                            using task_manager_data

                            debugtag 'update_difficulty'

                            begin_locals
wEntityCount                decl word
wSlotIndex                  decl word
wCenterX                    decl word
wCenterY                    decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

streak_pixel_high           equ $70
streak_pixel_low            equ $07

                            setlocaldatabank
; Check the overall timer
                            getword [<pTaskData],#explosion~streak_task_data~life_timer
                            dec a
                            jeq done
                            putword [<pTaskData],#same

palette_modifier~color_7    equ sizeof~palette_modifier*7

                            and #$fffe
                            tax
                            lda explosion~streak_colors,x
                            sta >playfield_view~palette+palette_modifier~alt_color+palette_modifier~color_7     ; color slot 7
                            lda #palette_modifier~new_count_down+4                                              ; high-bit set to apply on the next frame, and the lower bits are the frame countdown (4)
                            sta >playfield_view~palette+palette_modifier~count_down+palette_modifier~color_7

; Time to make a streak wave?
                            getword [<pTaskData],#explosion~streak_task_data~waves_remaining
                            tax
                            beq no_new_wave

                            getword [<pTaskData],#explosion~streak_task_data~wave_timer
                            beq new_wave
                            dec a
                            putword [<pTaskData],#same
                            bne no_new_wave

new_wave                    lda #explosion~streak_wave_timer                ; reset the timer
                            putword [<pTaskData],#same

                            dex                                             ; decrement the waves
                            txa
                            putword [<pTaskData],#explosion~streak_task_data~waves_remaining

; These are screen coordinates
                            getword [<pTaskData],#explosion~streak_task_data~x
                            sta <wCenterX
                            getword [<pTaskData],#explosion~streak_task_data~y
                            sta <wCenterY

                            lda #explosion~streaks_per_wave
                            sta <wEntityCount

create_loop                 lda explosion~streak_count
                            cmp #explosion~max_streaks
                            bge done_create

                            asl a
                            sta <wSlotIndex
                            tax
                            stz streak_nodes~move_accum_x,x
                            stz streak_nodes~move_accum_y,x
                            lda #1                                          ; seeding with a non-zero value, so that it will be re-calculated.
                            sta streak_nodes~address,x

; Get a random direction
; Get a random velocity
; Apply some amount of that to get the starting position

                            generate_rnd16
                            tay
                            and #direction~range-1                          ; Random direction, from the low-byte
                            pha

                            tya                                             ; Random speed, from the high bu=yte
                            xba
                            and #$07                                        ; there are 4 fractional levels, per integer level, so this is 0 - 1.75
                            clc
                            adc #speed~3_00                                 ; Add a minumum speed
                            pha
                            jsl playfield_get_speed

                            ldy <wSlotIndex
                            sta streak_nodes~speed_x,y
                            txa
                            sta streak_nodes~speed_y,y

; Set the animation speed, slightly randomized
                            get_quick_rnd16
                            and #$0003
                            asl a
                            tax
                            jsr (_add_offset,x)

                            inc explosion~streak_count

                            dec <wEntityCount
                            bne create_loop

done_create                 anop
no_new_wave                 anop

;;; Move all the stream nodes
                            lda explosion~streak_count
                            jeq move_done
                            asl a
                            tay
move_skip                   dey
                            dey
                            jmi move_done

move_loop                   anop
                            getword {y},#streak_nodes~address
                            beq move_skip

                            getword {y},#streak_nodes~speed_x
;streak_speed_patch_x        entry
;                            nop
                            beq do_y
                            clc
                            adcword {y},#streak_nodes~move_accum_x          ; add to the accumulator, which contains any left over fractional value from the last move
                            tax
                            bmi neg_x_add
; Adding a positive value to X
                            and #$00ff                                      ; save the fractional part for next time
                            putword {y},#streak_nodes~move_accum_x
                            txa
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            clc
                            adcword {y},#streak_nodes~x
                            putword {y},#streak_nodes~x
; Check to see if it is off the right.
                            cmp #gameplay_ui_playfield_right
                            bslt do_y
;
                            bra node_done

; Adding a negative value to X
neg_x_add                   and #$00ff                                      ; save the fractional part for next time
; Setup rounding correcion. -0.5 is $ff80, and -1 is $ff00, so if there is any factional part
; we want the integer conversion to round toward 0, not away.  Use the carry flag and an add of 0, to adjust the value
                            clc
                            beq neg_x_no_round_correction
                            sec
                            ora #$ff00                                      ; sign extend, though not if 0, there is no -0
neg_x_no_round_correction   anop
                            putword {y},#streak_nodes~move_accum_x
                            txa
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            adc #$0000                                      ; rounding correction
                            clc
                            adcword {y},#streak_nodes~x
                            putword {y},#streak_nodes~x
;                           gameplay_ui_playfield_left == 0
                            bpl do_y
;
                            bra node_done
do_y                        anop
                            getword {y},#streak_nodes~speed_y
;streak_speed_patch_y        entry
;                            nop
                            clc
                            adcword {y},#streak_nodes~move_accum_y          ; add to the accumulator, which contains any left over fractional value from the last move
                            bmi neg_y_add                                   ; have to handle negative numbers differently, because we will need to sign extend
; Adding a positive value to Y
                            tax
                            and #$00ff                                      ; save the fractional part for next time
                            putword {y},#streak_nodes~move_accum_y
                            txa
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            and #$00ff
                            clc
                            adcword {y},#streak_nodes~y
                            putword {y},#streak_nodes~y
                            cmp #gameplay_ui_playfield_bottom
                            bslt move_apply
;
                            bra node_done

; Adding a negative value to Y
neg_y_add                   tax
                            and #$00ff                                      ; save the fractional part for next time
; Setup rounding correcion. The factional part is always postive, so -0.5 is $ff80, and -1 is $ff00, so if there is any factional part
; we want the integer conversion to round toward 0, not away.  Use the carry flag and an add of 0, to adjust the value
                            clc
                            beq neg_y_no_round_correction
                            sec
                            ora #$ff00                                      ; sign extend, though not if 0, there is no -0
neg_y_no_round_correction   anop
                            putword {y},#streak_nodes~move_accum_y
                            txa
                            xba                                             ; we only want to add the integer portion, move to the lower bits
                            ora #$ff00                                      ; sign extend
                            adc #$0000                                      ; rounding correction
                            clc
                            adcword {y},#streak_nodes~y
                            putword {y},#streak_nodes~y
                            cmp #gameplay_ui_playfield_top
                            bsge move_apply
;
node_done                   anop
                            lda #0
                            putword {y},#streak_nodes~address               ; so it wont' draw
                            bra move_next

move_apply                  anop
                            getword {y},#streak_nodes~y
                            asl a
                            tax
                            getword {y},#streak_nodes~x
                            lsr a
                            bcs move_odd
                            adc >gYLookup,x
                            putword {y},#streak_nodes~address
                            lda #streak_pixel_low
                            putword {y},#streak_nodes~pixel_value
                            bra move_even
move_odd                    anop
                            clc
                            adc >gYLookup,x
                            putword {y},#streak_nodes~address
                            lda #streak_pixel_high
                            putword {y},#streak_nodes~pixel_value

move_next                   anop
move_even                   anop
                            dey
                            dey
                            jpl move_loop
move_done                   anop

exit                        restoredatabank
                            ret

done                        pushptr <pTaskData
                            jsl task_manager_free_task
                            stz explosion~streak_count
                            clearptr explosion~player_streaks_task_ptr
                            bra exit


_add_offset                 dc a'_add_offset_1'
                            dc a'_add_offset_2'
                            dc a'_add_offset_3'
                            dc a'_add_offset_4'

_add_offset_1               anop
                            lda streak_nodes~speed_x,y
                            asr_nt 8
                            clc
                            adc <wCenterX
                            sta streak_nodes~x,y
                            lda streak_nodes~speed_y,y
                            asr_nt 8
                            clc
                            adc <wCenterY
                            sta streak_nodes~y,y
                            rts

_add_offset_2               anop
                            clc
                            lda streak_nodes~speed_x,y
                            adc streak_nodes~speed_x,y
                            asr_nt 8
                            clc
                            adc <wCenterX
                            sta streak_nodes~x,y
                            clc
                            lda streak_nodes~speed_y,y
                            adc streak_nodes~speed_y,y
                            asr_nt 8
                            clc
                            adc <wCenterY
                            sta streak_nodes~y,y
                            rts

_add_offset_3               anop
                            clc
                            lda streak_nodes~speed_x,y
                            adc streak_nodes~speed_x,y
                            adc streak_nodes~speed_x,y
                            asr_nt 8
                            clc
                            adc <wCenterX
                            sta streak_nodes~x,y
                            clc
                            lda streak_nodes~speed_y,y
                            adc streak_nodes~speed_y,y
                            adc streak_nodes~speed_y,y
                            asr_nt 8
                            clc
                            adc <wCenterY
                            sta streak_nodes~y,y
                            rts

_add_offset_4               anop
                            clc
                            lda streak_nodes~speed_x,y
                            adc streak_nodes~speed_x,y
                            adc streak_nodes~speed_x,y
                            adc streak_nodes~speed_x,y
                            asr_nt 8
                            clc
                            adc <wCenterX
                            sta streak_nodes~x,y
                            clc
                            lda streak_nodes~speed_y,y
                            adc streak_nodes~speed_y,y
                            adc streak_nodes~speed_y,y
                            adc streak_nodes~speed_y,y
                            asr_nt 8
                            clc
                            adc <wCenterY
                            sta streak_nodes~y,y
                            rts

                            end


; ----------------------------------------------------------------------------
; Draw the player explosion streak dots.
; This just draws the latest dots.  This is outside the task, so the dots
; get priority drawing, since they are drawn directly to the screen.
explosion_streaks_draw      start seg_entity
                            using explosion_entity_manager_data

                            lda >explosion~streak_count
                            beq draw_none
                            setlocaldatabank
                            dec a
                            asl a
                            tay
                            shortm
draw_loop                   ldx streak_nodes~address,y          ; address value of 0 == skip.  Maybe use negative instead?
                            beq no_draw
                            lda streak_nodes~pixel_value,y
                            sta >grlib~real_screen_address,x     ; put on the screen.  Yes, I'm going to just draw black in the non-lit pixel, rather than merging.
no_draw                     dey
                            dey
                            bpl draw_loop
                            longm
                            restoredatabank

draw_none                   anop
                            rtl
                            end

; ----------------------------------------------------------------------------
; Add an explosion at a specified location
; Just does a warrior style one, but maybe rework the above functions to
; go through here, so that other explosions can be added that don't need
; a source entity?
explosion_entity_manager_add_explosion_at start seg_entity
                            using appdata
                            using explosion_entity_data
                            using explosion_entity_manager_data
                            using gameplay_level_data
                            using gameplay_manager_data
                            using applib_data

                            debugtag 'add_explosion_at'

                            begin_locals
spEntity                    decl word
wEntityCount                decl word
wSlotIndex                  decl word
work_area_size              end_locals

                            sub (2:wX,2:wY,2:wType,2:wVariationOverride),work_area_size

                            setlocaldatabank

                            getword <wType
                            asl a
                            tax
                            jsr (explosion_type_subtable,x)

                            restoredatabank
                            ret

explosion_type_subtable     anop
                            dc a2'null_explosion'
                            dc a2'basic_explosion'
                            dc a2'null_explosion' ; rock_explosion_small
                            dc a2'null_explosion' ; rock_explosion_medium
                            dc a2'null_explosion' ; rock_explosion_large'
                            dc a2'warrior_explosion'
                            dc a2'null_explosion' ; player_explosion
                            dc a2'sinistar_fragment_explosion'

;;;; Basic explosion
basic_explosion             anop
                            lda explosion_entity_count
                            cmp #max_explosion_entity_count
                            blt basic_ok
                            rts

basic_ok                    asl a
                            sta <wSlotIndex

                            pushsword #explosion_image~basic
                            pushsword #explosion_variation~default
                            jsl explosion_entity_new
                            bcs error

                            inc explosion_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta explosion_entity_array,y

                            lda <wX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

; Set animation speed
                            lda #explosion_animation~basic
                            putword {x},>entities_root+playfield_entity~frame_animation_timer
                            putword {x},>entities_root+playfield_entity~frame_animation_rate

                            inline_entity_add_to_playfield {>x}

; The rest of the explosion setup will be done when its mission code is updated.
error                       anop
                            rts

;;; Warrior explosion
; This puts 10 small fragments at center of the explosion.
warrior_explosion           anop
                            lda #10
                            sta <wEntityCount

warrior_explosion_loop      lda explosion_entity_count
                            cmp #max_explosion_entity_count
                            blt warrior_ok
                            rts

warrior_ok                  asl a
                            sta <wSlotIndex

                            pushsword #explosion_image~warrior
                            pushsword <wVariationOverride
                            jsl explosion_entity_new
                            bcs warrior_error

                            inc explosion_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta explosion_entity_array,y

; Set a random direction and speed
                            pha
                            generate_rnd16
                            tay
                            and #direction~range-1                           ; Random direction, from the low-byte
                            pha

                            tya                                             ; Random speed, from the high bu=yte
                            xba
                            and #$07                                        ; there are 4 fractional levels, per integer level, so this is 0 - 1.75
                            clc
                            adc #speed~2_00                                 ; Add a minumum speed
                            pha
                            jsl playfield_entity_set_speed

; Set the animation speed.
; Randomize these a bit, so they fade at different times

                            get_quick_rnd16
                            and #$0007
                            clc
                            adc #explosion_animation~warrior
                            ldx <spEntity
                            putword {x},>entities_root+playfield_entity~frame_animation_timer
                            putword {x},>entities_root+playfield_entity~frame_animation_rate

                            lda <wX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

                            dec <wEntityCount
                            bne warrior_explosion_loop

warrior_error               rts

;;;; Sinistar fragment explosion
sinistar_fragment_explosion anop
                            lda explosion_entity_count
                            cmp #max_explosion_entity_count
                            blt sinistar_fragment_ok
                            rts

sinistar_fragment_ok        asl a
                            sta <wSlotIndex

                            pushsword #explosion_image~sinistar_fragment
                            pushsword <wVariationOverride
                            jsl explosion_entity_new
                            bcs sinistar_fragment_error

                            inc explosion_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta explosion_entity_array,y

                            lda <wX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

; Set a random direction and speed
                            phx
                            jsl math~rnd_generate
                            tay
                            and #direction~range-1                           ; Random direction, from the low-byte
                            pha

                            tya                                             ; Random speed, from the high byte
                            xba
                            and #$03                                        ; there are 4 fractional levels, per integer level, so this is 0 - 0.75
                            clc
                            adc #speed~1_00                                 ; Add a minumum speed
                            pha
                            jsl playfield_entity_set_speed

; Set animation speed
                            ldx <spEntity
;                            lda #explosion_animation~sinistar_fragment
;                            putword {x},>entities_root+playfield_entity~frame_animation_timer
;                            putword {x},>entities_root+playfield_entity~frame_animation_rate

                            inline_entity_add_to_playfield {>x}

; The rest of the explosion setup will be done when its mission code is updated.
sinistar_fragment_error     anop
                            rts

;;;; Null Explosion
; Doesn't do anything.
null_explosion              anop
                            rts

                            end

; ----------------------------------------------------------------------------
explosion_entity_manager_remove_all start seg_entity
                            using explosion_entity_data
                            using explosion_entity_manager_data
                            using gameplay_level_data

                            debugtag 'remove_all'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Delete all the allocated rocks
                            lda explosion_entity_count
                            beq none
                            dec a
                            asl a
                            tax

loop                        phx

                            lda explosion_entity_array,x
                            sta <spEntity
                            tax
; Remove from playfield
                            jsl explosion_entity_remove_from_playfield
; Delete
                            ldx <spEntity
                            jsl explosion_entity_delete

                            plx
                            dex
                            dex
                            bpl loop

done                        anop
                            stz explosion_entity_count

none                        anop
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; This updates the animation of all, on screen explosions.
gameplay_all_explosions_update_tick start seg_entity
                            using appdata
                            using explosion_entity_data
                            using explosion_entity_manager_data
                            using gameplay_level_data
                            using gameplay_manager_data
                            using applib_data

                            debugtag 'explosions_update_tick'

                            begin_locals
spEntity                    decl word
wLastEntitySlot             decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Loop over the explosions, backward.
                            lda explosion_entity_count
                            beq done_update
                            dec a
                            asl a
                            tax

loop                        phx

; Only need the short pointer in this loop
                            lda explosion_entity_array,x
                            sta <spEntity
                            tax

; Is this set to be removed?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi on_removal_list

                            bit #playfield_entity~state_first_update
                            beq update_state
; First update, we don't want to adjust any position or frame, just draw it
                            and #((playfield_entity~state_first_update*-1)-1)
                            putword {x},>entities_root+playfield_entity~state_flags
                            bra just_draw

update_state                anop
; No need to update the direction, it will not change
;                            jsl playfield_entity_update_direction

;                           ldx <spEntity
                            jsl playfield_entity_update_position

; Update the animation
                            ldx <spEntity
                            jsl playfield_entity_frame_change
                            cpx #1
                            beq ok_animation                        ; looped animation, just move on
                            cmp #frame_change~no_crossing
                            beq ok_animation

; One cycle of the animation, and we are complete
                            ldx <spEntity
                            jsl playfield_entity_mark_for_removal
                            bra on_removal_list

just_draw                   anop
ok_animation                anop
; Update the framelib values
                            ldx <spEntity
                            getword {x},>entities_root+grlib_entity~changed
                            beq no_framelib_update

                            setdatabanktolabel entities_root
                            jsl grlib_entity_update_framelib
                            restoredatabank
; Invalidate
                            ldx <spEntity
no_framelib_update          anop
                            jsl playfield_entity_invalidate_sprite_no_collision             ; NOT adding to collision list
                            bcc still_on_screen
; If we are offscreen, then remove
                            ldx <spEntity
                            jsl playfield_entity_mark_for_removal

still_on_screen             anop

on_removal_list             anop
                            plx
                            dex
                            dex
                            bpl loop

done_update                 anop

; Do any removals
                            lda explosion_entity_remove_count
                            beq done_remove
                            dec a
                            asl a
                            tax

loop_remove                 phx

; We will need to know the last slot index
                            lda explosion_entity_count
                            dec a
                            asl a
                            sta <wLastEntitySlot

                            lda explosion_entity_remove_array,x
                            sta <spEntity
                            tax

                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_removed_from_screen
                            bne already_removed_from_screen

                            jsl playfield_entity_invalidate_sprite_no_collision
                            ldx <spEntity

already_removed_from_screen anop
; Get the slot we are in
                            getword {x},>entities_root+playfield_entity~manager_slot_index
                            pha
                            jsl explosion_entity_remove_from_playfield

                            ldx <spEntity
                            jsl explosion_entity_delete         ; do the delete

                            ply                                 ; get the slot index back
                            cpy <wLastEntitySlot
                            beq is_last_slot                    ; last slot?
; Move the last, into the vacated slot
                            ldx <wLastEntitySlot
                            lda explosion_entity_array,x
                            sta explosion_entity_array,y
                            stz explosion_entity_array,x
; Update the moved entity's slot index
                            tax
                            tya
                            putword {x},>entities_root+playfield_entity~manager_slot_index
is_last_slot                dec explosion_entity_count

                            plx
                            dex
                            dex
                            bpl loop_remove

done_remove                 anop
                            stz explosion_entity_remove_count
                            stz explosion_entity_next_remove_index

                            restoredatabank

                            ret
                            end

; ----------------------------------------------------------------------------
; Explicit draw of all the explosions on its internal 'visible' list.
; Explosions do not use the collision list for drawing.
explosion_entity_manager_draw start seg_entity
                            using explosion_entity_manager_data

                            debugtag 'explosions_draw'

                            lda >explosion_entity_count
                            beq none
                            tay
                            ldx #explosion_entity_array
                            jsl playfield_draw_entity_list_into_view

none                        rtl
                            end

