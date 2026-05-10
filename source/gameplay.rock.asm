                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            copy source/task.definitions.asm
                            copy source/gameplay.constants.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/rock.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/gameplay.player.definitions.asm

                            mcopy generated/gameplay.rock.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the rocks.

; ----------------------------------------------------------------------------

gameplay_rock_logic_data    data seg_gameplay

gameplay_rock_task_data             equ sizeof~task_control                         ; Starting with support for sleep commands
gameplay_rock_task_data~entity_ptr  equ gameplay_rock_task_data        ; Pointer to the entity
sizeof~gameplay_rock_task_data      equ gameplay_rock_task_data~entity_ptr+4

offscreen_mining_probability        equ 192                             ; out of 256, so 2/3 chance
offscreen_mining_distance           equ 32                              ; original was 32

                            end

; ----------------------------------------------------------------------------
; Initialize the rocks for gameplay, this is pre-state activation
gameplay_rocks_initialize   start seg_gameplay

                            debugtag 'rocks_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_rocks_uninitialize start seg_gameplay
                            using gameplay_rock_logic_data
                            using gameplay_level_data

                            debugtag 'rocks_uninitialize'

                            jsl rock_entity_manager_remove_all

                            rtl
                            end

; ----------------------------------------------------------------------------
; Deactivate the turn
gameplay_rocks_turn_deactivate start seg_gameplay
                            using rock_entity_manager_data

                            debugtag 'rocks_turn_deactivate'

                            jsl rock_entity_manager_remove_all
; The population function will add the rocks later in the state activation

                            rtl
                            end

; ----------------------------------------------------------------------------
; Check the population of rocks, and add more if needed
; Parameters:
; wMax      - max number to add
; wEdge     - add at the edges of the sector
; Returns:
; number added
gameplay_rocks_check_population start seg_gameplay
                            using appdata
                            using rock_entity_data
                            using rock_entity_manager_data
                            using gameplay_rock_logic_data
                            using gameplay_level_data
                            using gameplay_manager_data
                            using playfield_manager_data

                            debugtag 'rocks_check_population'

                            begin_locals
wType                       decl word
wCount                      decl word
result                      decl word
work_area_size              end_locals

                            sub (2:wMax,2:wEdge),work_area_size

                            setlocaldatabank

                            stz <result
                            stz <wType

                            aif C:debug~use_profile_state=0,.skip
                            lda gameplay_manager~static_profile
                            bpl not_profile

                            lda >rock_entity_count
                            bne no_extra

not_profile                 anop
.skip
                            lda #0

; This is a bit different from the others, in that this needs to check population by rock type.
type_loop                   asl a
                            tax
                            lda gameplay_manager~active_state+player_state~desired_pop~planetoids1,x         ; fp16
                            bmi next_type
                            xba
                            and #$00ff                                  ; integer portion
                            sec
                            sbc >rock_entity_variation_count,x
                            bcc next_type
                            beq next_type

                            cmp <wMax                                   ; clamp to max limit
                            blt ok
                            lda <wMax
                            beq no_extra
ok                          sta <wCount
                            clc
                            adc <result
                            sta <result
                            lda <wMax
                            sec
                            sbc <wCount
                            sta <wMax

                            jsr add_type

next_type                   inc <wType
                            lda <wType
                            cmp #rock_entity~variation_max
                            bne type_loop

no_extra                    anop
                            restoredatabank
                            ret 2:result

; Add <wCount of <wType
add_type                    anop
                            lda <wEdge
                            bne loop_edge
                            aif C:debug~use_profile_state=0,.skip
                            lda gameplay_manager~static_profile
                            bmi populate_profile
.skip

loop                        anop
; Make sure we can do the range optimizations
                            static_assert_not_equal gameplay_playfield_width_mask,0
                            static_assert_not_equal gameplay_playfield_height_mask,0

                            generate_rnd16
                            and #gameplay_playfield_width_mask
                            clc
                            adc #gameplay_playfield_min_x
                            pha                         ; x coord
                            generate_rnd16
                            and #gameplay_playfield_height_mask
                            clc
                            adc #gameplay_playfield_min_y
                            pha                         ; y coord

                            pushsword <wType
                            jsl rock_entity_manager_add_rock

                            dec <wCount
                            bne loop
                            rts

; Add to the edges
loop_edge                   anop
                            jsl gameplay_generate_random_edge_location
                            pha         ; x coordinate
                            phx         ; y coordinate
                            pushsword <wType
                            jsl rock_entity_manager_add_rock

                            dec <wCount
                            bne loop_edge
                            rts

                            aif C:debug~use_profile_state=0,.skip
populate_profile            anop

profile_loop                anop
                            lda >rock_entity_count
                            cmp #3
                            blt on_screen
; Offscreen
                            jsl gameplay_generate_random_edge_location
                            pha         ; x coordinate
                            phx         ; y coordinate
                            pushsword <wType
                            jsl rock_entity_manager_add_rock

                            dec <wCount
                            bne profile_loop
                            rts

on_screen                   anop
                            generate_rnd16
; Get an random range
                            and #$00ff
                            ldx #gameplay_ui_playfield_width/2                      ; must div, because this trick only works for 0-255 ranges
                            jsl math~umul1r2
                            xba
                            and #$00ff
                            asl a                                                   ; back to pixels
                            clc
                            adc #-gameplay_ui_playfield_center_x
                            pha                         ; x coord
                            generate_rnd16
                            and #$00ff
                            ldx #gameplay_ui_playfield_height
                            jsl math~umul1r2
                            xba
                            and #$00ff
                            clc
                            adc #-gameplay_ui_playfield_center_y
                            pha                         ; y coord

                            pushsword <wType
                            jsl rock_entity_manager_add_rock

                            dec <wCount
                            bne profile_loop
                            rts
.skip
                            end

; ----------------------------------------------------------------------------
; Initialize the rock entity
; Parameters:
; x-reg     - short pointer to entity
gameplay_rock_initialize    start seg_gameplay
                            using rock_entity_data
                            using gameplay_rock_logic_data
                            using task_manager_data

                            debugtag 'rock_initialize'

                            begin_locals
pTaskData                   decl ptr
spThis                      decl word
work_area_size              end_locals

                            sub ,work_area_size

; Only Planetoid type 5, gets an AI task
; Note, this assumption is from the original code, probably to limit tasks
; I could check the characteristic definition and see if the AI type is ai_type_planetoid, and assign tasks based on that.
; Unlike the original, I do not rely on the AI type to determine what basic type the entity is, I have a separate entity type for that.
                            getword {x},>entities_root+playfield_entity~characteristic_id
                            cmp #id_characteristic_planetoid_5
                            bne exit

                            stx <spThis

                            jsl gameplay_caller_initialize

                            pushsword #task_list_64_offset
                            pushptr #gameplay_task_rock_logic_tick
                            pushsword #sizeof~gameplay_rock_task_data
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

                            ldx <spThis
; Put the caller pointer into the task data (should fix this so it only stores the lower byte)
                            txa
                            putptrlow [<pTaskData],#gameplay_rock_task_data~entity_ptr
                            lda #^entities_root
                            putptrhigh [<pTaskData],#gameplay_rock_task_data~entity_ptr

; And the task pointer, into the caller.  Using the task2 slot
                            lda <pTaskData
                            putptrlow {x},>entities_root+playfield_entity~task2_ptr
                            lda <pTaskData+2
                            putptrhigh {x},>entities_root+playfield_entity~task2_ptr

error                       anop
exit                        anop
                            ret
                            end
; -----------------------------------------------------------------------------
gameplay_task_rock_logic_tick start seg_gameplay
                            using task_manager_data
                            using rock_entity_data
                            using rock_entity_manager_data
                            using gameplay_rock_logic_data

                            debugtag 'rock_logic_tick'

                            begin_locals
wFoundWarrior               decl word
spWorker                    decl ptr
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

; Set the databank to the entities pool
                            setdatabanktolabel entities_root

                            getword [<pTaskData],#gameplay_rock_task_data~entity_ptr
                            tay                 ; entity short pointer in Y

; This handles off-screen 'mining'

; Is the rock on screen?
                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            bne exit            ; do nothing

; Do we have a worker responding to us?
                            getword {y},#playfield_entity~responder_quota+responder_type~worker
                            beq exit            ; nope
; And a warrior?
                            getword {y},#playfield_entity~responder_quota+responder_type~warrior
                            beq exit            ; nope

; See if we do a mining check
                            generate_rnd16
                            and #$00ff
                            cmp #offscreen_mining_probability
                            bge exit            ; not this time

                            stz <wFoundWarrior
                            stz <spWorker
; Responders are in a linked list.
                            getword {y},#playfield_entity~responder_root_sptr
                            beq exit            ; this shouldn't happen

; Responder short pointer will be in X
responder_loop              tax
; Check the distance
                            getword {x},#playfield_entity~caller_dist_x
                            cmp #offscreen_mining_distance
                            bge next_responder
                            getword {x},#playfield_entity~caller_dist_y
                            cmp #offscreen_mining_distance
                            bge next_responder

; This responder is close enough
                            getword {x},#playfield_entity~type
                            cmp #entity_type~warrior
                            bne not_warrior
                            inc <wFoundWarrior                              ; we just want this to be non-zero
                            bra next_responder
; It has to be a worker.
not_warrior                 lda <spWorker
                            bne next_responder                              ; already have a worker
                            getword {x},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            bne next_responder                              ; on screen?  if so, skip him
                            stx <spWorker

next_responder              anop
                            lda <wFoundWarrior
                            beq no_warrior_yet
; We have a warrior responder
                            lda <spWorker
                            bne give_crystal                                ; and a worker responder, give them a crystal (off screen)

no_warrior_yet              getword {x},#playfield_entity~next_sibling_sptr
                            bne responder_loop

exit                        restoredatabank
                            ret

give_crystal                pushsword <spWorker
                            jsl gameplay_worker_give_crystal
                            bra exit

                            end

; -----------------------------------------------------------------------------
; See if this rock wants to eject a crystal
; Parameters:
;  entity short pointer in the X register
; Also assumes that the databank is set to the entities_root
gameplay_rock_entity_eject_crystal start seg_gameplay
                            using appdata
                            using rock_entity_data
                            using rock_entity_manager_data
                            using gameplay_rock_logic_data
                            using gameplay_level_data
                            using gameplay_entity_data

                            debugtag 'eject_crystal'

                            begin_locals
wTemp                       decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

; Is the scale high enough?
                            getword [<pTaskData],#vibrate_task~scale
                            sec
                            sbc #gameplay_vibrate_scale_min_crystal_eject
                            bcc no
                            beq no

; Random chance, proportional to where we are on the scale
                            sta <wTemp
                            generate_rnd16
                            and #$00ff
                            cmp <wTemp
                            bge no
; Yes!
; The planetoid loses mass for each crystal.
                            getword {x},#playfield_entity~personality
                            sec
                            sbc #gameplay_planetoid_crystal_mass_reduction
                            bcs ok_mass
                            lda #0
ok_mass                     putword {x},#playfield_entity~personality

; Crystal ejection also dampens the vibration.
                            getword [<pTaskData],#same          ; y should still be set to vibrate_task~scale
                            lsr a
                            putword [<pTaskData],#same

                            pushsword {x},#playfield_entity~grentity+grlib_entity~x
                            pushsword {x},#playfield_entity~grentity+grlib_entity~y
; Give the crystal a small random velocity
                            generate_rnd16
                            and #$00ff
                            sec
                            sbc #$0080
                            pha

                            generate_rnd16
                            and #$00ff
                            sec
                            sbc #$0080
                            pha

                            jsl crystal_entity_manager_add_crystal

no                          anop
                            ret
                            end

; -----------------------------------------------------------------------------
; Shatter the rock
; Parameters:
; x-reg         - short pointer to the entity
;
; Function can assume databank is set to entities_root
gameplay_rock_entity_shatter start seg_gameplay
                            using gameplay_sound_data

                            debugtag 'shatter_gameplay_rock_entity'

; Push for explosion_entity_manager_add_explosion, while we have the pointer handy
                            pushptrhigh #entities_root
                            phx

                            jsl playfield_entity_mark_for_removal

; Put a rock explosion in its place.
                            jsl explosion_entity_manager_add_explosion

                            pushsword #id_sfx~explosion
                            jsl sndlib_play_sfx

                            rtl
                            end
