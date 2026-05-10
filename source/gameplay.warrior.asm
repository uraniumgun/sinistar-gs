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

                            copy source/gameplay.constants.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/warrior.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm

                            mcopy generated/gameplay.warrior.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the warriors.

; An option to make the game a bit easier, by preventing the warrior from being
; able to immediately shooting again on its next update tick (task list 8)
modification~inhibit_every_shot gequ 1

; ----------------------------------------------------------------------------

gameplay_warrior_logic_data    data seg_gameplay

; Rate at which animation is updated
gameplay_warrior_update~update_rate equ 2

; Orbit factor (mininum orbit distance)
gameplay_warrior_orbit_factor    equ 6                 ; IORBIT in the original, which was 6
gameplay_warrior_drift_orbit_factor equ 8

gameplay_warrior_turret_direction_count gequ 8

gameplay_warrior_min_attack_distance    gequ 40

; Thw lower 4 bits are a count down for the warrior's shooting inhibitor, in its personality field
personality~shooting_inhibitor_count equ $000f
personality~turret_locked       equ $0080

; A common multiplier for the warrior orbits. (WorkOrbit)
; This is periodically randomised, and is either 1 or -1, to change the direction of the orbit.
gameplay_warrior_orbit_multiplier    dc i'-1'

gameplay_warrior_task            equ 0
gameplay_warrior_task~entity_ptr equ gameplay_warrior_task
sizeof~gameplay_warrior_task     equ gameplay_warrior_task~entity_ptr+4

id_warrior_mission_drift        equ 0
id_warrior_mission_tail         equ 1
id_warrior_mission_intercept    equ 2
id_warrior_mission_attack       equ 3
id_warrior_mission_mine         equ 4
id_warrior_mission_count        equ 5                   ; keep last

; The jump table to the warrior's missions.
gameplay_warrior_logic~mission_table anop
                            dc a'gameplay_warrior_mission_drift'
                            dc a'gameplay_warrior_mission_tail'
                            dc a'gameplay_warrior_mission_intercept'
                            dc a'gameplay_warrior_mission_attack'
                            dc a'gameplay_warrior_mission_mine'

; Original values from stblworker.  Yes, it used the worker table in the original code
gameplay_warrior_logic~orbit_speed_table anop
                            dc i'1536|2,(65|4),acceleration_function~3'
                            dc i'0800|2,(42|4),acceleration_function~2'
                            dc i'0384|2,(25|4),acceleration_function~1'
                            dc i'0320|2,(24|4),acceleration_function~1'
                            dc i'0256|2,(22|4),acceleration_function~1'
                            dc i'0192|2,(18|4),acceleration_function~1'
                            dc i'0128|2,(12|4),acceleration_function~1'
                            dc i'0064|2,(07|4),acceleration_function~3'
                            dc i'0000|2,(03|4),acceleration_function~4'

; Based on stblminer from the original.  In the original, if the Warrior is the lead 'attacker', it attacks like the mining mission.
gameplay_warrior_logic~attack_speed_table anop
                            dc i'1024,($80|4),acceleration_function~4'
                            dc i'gameplay_warrior_min_attack_distance+256,($30|4),acceleration_function~4'
                            dc i'gameplay_warrior_min_attack_distance+96,($20|4),acceleration_function~4'
                            dc i'gameplay_warrior_min_attack_distance+24,($10|4),acceleration_function~3'
                            dc i'gameplay_warrior_min_attack_distance+0,($08|4),acceleration_function~3'
                            dc i'gameplay_warrior_min_attack_distance-16,($00|4),acceleration_function~2'
                            dc i'gameplay_warrior_min_attack_distance-32,($00|4),acceleration_function~1'
                            dc i'0000,($fff|4),acceleration_function~4'

; Warrior Intercept mission speed table.  Original table (stblW1)
gameplay_warrior_logic~intercept_speed_table anop
                            dc i'$7fff,$0FFF,acceleration_function~3'
                            dc i'0512,$0450,acceleration_function~4'
                            dc i'0256,$03C5,acceleration_function~4'
                            dc i'0128,$0320,acceleration_function~3'
                            dc i'0064,$0200,acceleration_function~3'
                            dc i'0032,$0180,acceleration_function~2'
                            dc i'0016,$00E0,acceleration_function~2'
                            dc i'0000,$0090,acceleration_function~1'

; Warrior aggression level. 0 = least aggressive, gameplay_warrior~max_aggression most aggressive.
; This affects how often they shoot at the player.
gameplay_warrior~max_aggression equ $007f

                            end

; ----------------------------------------------------------------------------
; Gameplay Logic initialization for a new warrior
; Parameters:
; x-reg         - short pointer to the entity
gameplay_warrior_initialize  start seg_gameplay
                            using appdata
                            using warrior_entity_data
                            using gameplay_warrior_logic_data
                            using applib_data
                            using task_manager_data

                            debugtag 'warrior_initialize'

                            begin_locals
pTaskData                   decl ptr
wTemp                       decl word
spThis                      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            stx <spThis

                            pushsword #task_list_8_offset
                            pushptr #gameplay_task_warrior_logic_tick
                            pushsword #sizeof~gameplay_warrior_task
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

; Add the entity to the task data
                            lda <spThis
                            putptrlow [<pTaskData],#gameplay_warrior_task~entity_ptr
                            lda #^entities_root
                            putptrhigh [<pTaskData],#gameplay_warrior_task~entity_ptr

; Add the task, to the entity, in the task1 slot
                            ldx <spThis
                            lda <pTaskData
                            putptrlow {x},>entities_root+playfield_entity~task1_ptr
                            lda <pTaskData+2
                            putptrhigh {x},>entities_root+playfield_entity~task1_ptr

                            jsr _warrior_get_shoot_inhibit
                            sta <wTemp
                            ldx <spThis
                            getword {x},>entities_root+playfield_entity~personality
                            and #(personality~shooting_inhibitor_count*-1)-1
                            ora <wTemp
                            putword {x},>entities_root+playfield_entity~personality

error                       anop
                            ret
                            end

; ----------------------------------------------------------------------------
; Task callback for warrior logic
; For efficiency, this will set the databank to the entities_root so that
; all warrior logic can assume that it is set and do short addressing on
; the entities.
gameplay_task_warrior_logic_tick start seg_gameplay
                            using appdata
                            using warrior_entity_data
                            using gameplay_warrior_logic_data
                            using applib_data

                            debugtag 'task_warrior_logic_tick'

                            begin_locals
spEntity                    decl word
wTemp                       decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

; Set the databank to the entities pool
                            setdatabanktolabel entities_root

                            getword [<pTaskData],#gameplay_warrior_task~entity_ptr
                            sta <spEntity
                            tay
; Adjust the shooting inhibitor
                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq not_on_screen                                   ; not on screen?

                            getword {y},#playfield_entity~personality
                            bit #personality~shooting_inhibitor_count
                            beq at_zero
                            dec a
                            putword {y},#playfield_entity~personality
at_zero                     anop

; Note, it the original, it called upddtc, which is my gameplay_responder_update_distance, *before* calling the mission
; This is different, that the Workers, where that is called in the missions.  I'm currently leaving the call in the mission
; as I don't have the caller here (I could get it), and also, I thought that all missions didn't require a caller, like a drift mission.

; Call the mission code.
                            getword {y},#playfield_entity~mission_id
                            asl a
                            tax
                            jsr (gameplay_warrior_logic~mission_table,x)

                            restoredatabank
                            ret

not_on_screen               anop
; It would be great if this was called only once, when the warrior goes off screen, rather than every time,
; because it is wasting cycles.
                            getword {y},#playfield_entity~personality
                            bne at_zero                 ; I'm going to try not resetting this, unless it is 0.
;                           bit #$000c                  ; well, I guess I can skip if it has some reasonably high value, either left over, or was set (the min is 5 in the calculation)
;                           bne at_zero
                            and #(personality~shooting_inhibitor_count*-1)-1
                            sta <wTemp
                            jsr _warrior_get_shoot_inhibit      ; to be honest, this is so small, I should just make a macro out of it, and inline it.
                            ora <wTemp
                            putword {y},#playfield_entity~personality  ; I know that _warrior_get_shoot_inhibit doesn't change Y
                            bra at_zero

                            end

; ----------------------------------------------------------------------------
; Handle the drift mission.  This will fire at the player, randomly.
; Parameters:
;  entity short pointer in y
;
; This function assumes the databank is where the entities_root is
gameplay_warrior_mission_drift private seg_gameplay
                            using gameplay_warrior_logic_data
                            using grlib_global_data
                            using gameplay_entity_data
                            using player_entity_data

                            debugtag 'mission_drift'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
; y already has the entity, get the target short pointer in x
                            ldx #player_entity_instance
                            jsr _warrior_update_aim_to_target

                            ldy <spEntity
                            inline_entity_test_should_think {y}       ; like the original, we will see if we should 'think' or not
                            bcs exit

                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq not_on_screen

                            jsr _test_warrior_shoot
                            blt no_shoot

                            ldx #player_entity_instance
                            jsr _gameplay_warrior_shoot

not_on_screen               anop
no_shoot                    anop
exit                        anop
                            lret

                            end

; ----------------------------------------------------------------------------
; Warrior Tail/Orbit Mission Logic
; Parameters:
;  entity short pointer in y
;
; This function assumes the databank is where the entities_root is
gameplay_warrior_mission_tail private seg_gameplay
                            using appdata
                            using warrior_entity_data
                            using player_entity_data
                            using gameplay_warrior_logic_data
                            using gameplay_level_data
                            using grlib_global_data

                            debugtag 'mission_tail'

                            begin_locals
spEntity                    decl word
spTargetEntity              decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
                            getword {y},#playfield_entity~caller_sptr
                            beq invalid_caller

                            sta <spTargetEntity
                            tax

; Take this opportunity to update the caller distance.
                            inline_responder_update_distance {y},{x}

; y (entity), x (target) are already setup
                            jsr _warrior_update_aim_to_target

; Call the orbit code
                            ldy <spEntity
                            ldx <spTargetEntity
                            jsr _warrior_orbit_target

invalid_caller              anop
                            lret
                            end

; ----------------------------------------------------------------------------
; Intercept logic.  This is for intercepting a crystal.
; Parameters:
;  entity short pointer in y
;
; This function assumes the databank is where the entities_root is
gameplay_warrior_mission_intercept private seg_gameplay
                            using appdata
                            using warrior_entity_data
                            using gameplay_warrior_logic_data
                            using gameplay_level_data

                            debugtag 'mission_intercept'

                            begin_locals
spEntity                    decl word
spTargetEntity              decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
                            getword {y},#playfield_entity~caller_sptr
                            beq invalid_caller

                            sta <spTargetEntity
                            tax

; Take this opportunity to update the caller distance.
                            inline_responder_update_distance {y},{x}

; Get the velocity to the target.
                            pushptr #gameplay_warrior_logic~intercept_speed_table
                            inline_entity_push_target_distance {y},{x}
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <spEntity
                            ldx <spTargetEntity
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda >gameplay_warrior_logic~intercept_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

invalid_caller              anop

                            lret
                            end

; ----------------------------------------------------------------------------
; Attack Mission.  Always attacks the player
; Parameters:
;  entity short pointer in y
;
; This function assumes the databank is where the entities_root is
gameplay_warrior_mission_attack private seg_gameplay
                            using appdata
                            using warrior_entity_data
                            using gameplay_warrior_logic_data
                            using gameplay_level_data
                            using gameplay_entity_data
                            using player_entity_data

                            debugtag 'mission_attack'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

                            lsub ,work_area_size             ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
; Assuming that the target is always the player
                            ldx #player_entity_instance
                            jsr _warrior_update_aim_to_target

; Update the caller distance.
                            ldy <spEntity
                            ldx #player_entity_instance
                            inline_responder_update_distance {y},{x}

                            inline_entity_test_should_think {y}         ; like the original, we will see if we should 'think' or not
                            bcs exit

; In the original code, an entity can be assured that all its siblings are the same type.  I'm not doing that
; right now, but maybe I should?  Because of this, I need to see if this entity is the last Warrior, so search
                            getword {y},#playfield_entity~next_sibling_sptr
                            beq is_leader                               ; the leader is the last in the chain.
; See if there are other warrior that follow us
next_sibling                tax
                            getword {x},#playfield_entity~type
                            cmp #entity_type~warrior
                            beq not_leader
                            getword {x},#playfield_entity~next_sibling_sptr
                            bne next_sibling

is_leader                   ldx #player_entity_instance
                            jsr _warrior_attack_target
                            bra exit

not_leader                  anop
; Just do what the 'tail' code does
                            ldx #player_entity_instance
                            jsr _warrior_orbit_target

; Make the game a bit easier, and prevent the warrior from immediately shooting again.
                            aif C:modification~inhibit_every_shot=0,.skip
                            bcs exit
                            jsr _warrior_get_shoot_inhibit
                            ldy <spEntity
                            ora |playfield_entity~personality,y
                            putword {y},#playfield_entity~personality
.skip

not_on_screen               anop
exit                        anop
                            lret
                            end

; ----------------------------------------------------------------------------
; Mine a Planetoid Mission
; Parameters:
;  entity short pointer in y
;
; This function assumes the databank is where the entities_root is
gameplay_warrior_mission_mine private seg_gameplay
                            using appdata
                            using warrior_entity_data
                            using gameplay_warrior_logic_data
                            using gameplay_level_data

                            debugtag 'mission_mine'

                            begin_locals
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

; Todo
                            brk $99

;                            generate_rnd16
;                            bit #1                          ; 1 in 2, to do the mission
;                            beq no_shoot

                            lret
                            end

; ----------------------------------------------------------------------------
; Do a warrior shoot test
; Returns carry set == shoot
; Preserves x and y
_test_warrior_shoot         private seg_gameplay
                            using gameplay_warrior_logic_data
                            using gameplay_manager_data

                            phx
                            phy
; See if the warrior should shoot.  Since it is on screen, and the player is always on screen, we can assume it can see the player.
                            generate_rnd16
; Get a 0-159 range, by using a random byte as 1/n and multiply it by our range, and just take the high byte.
; This calculation is from the original code and the ranges are designed to give 1/5 to a 1/1 chance of shooting, based on the warrior agression level.
                            and #$00ff
                            inline~umul1r2 #gameplay_warrior~max_aggression+32+1,Y     ; 160, with the default values
                            xba
                            and #$00ff
                            sta >patch_roll+1
                            lda >gameplay_manager~active_state+player_state~warrior_aggression+1 ; the high byte is the integer portion
                            and #$00ff          ; Set to $002f, to make it max out at 1 in 2 chance
                            clc
                            adc #32
patch_roll                  cmp #0
; Caller should test the carry bit, set == shoot. Note backward from original, because on the 6809 CMP, does SUB and on the 6809, the carry for sub operations means a carry happened, unlike the 6502, where it is clear if it happend.
                            ply
                            plx
                            rts

                            end

; ----------------------------------------------------------------------------
; Update to target
; Parameters:
;  entity short pointer in y
;  target short pointer in x
;
; This function assumes the databank is where the entities_root is
_warrior_update_aim_to_target private seg_gameplay
                            using gameplay_warrior_logic_data
                            using grlib_global_data

                            debugtag 'update_to_target'

                            begin_locals
spEntity                    decl word
wPrevTargetAngle            decl word
wCurrentTargetAngle         decl word
wWantAimDirection           decl word
work_area_size              end_locals

                            lsub ,work_area_size

                            sty <spEntity

;                           keyed_break 3,'aim'

                            getword {y},#playfield_entity~target_angle
                            sta <wPrevTargetAngle

; Get the angle, from the source, to the target
                            getword {x},#playfield_entity~grentity+grlib_entity~x
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~x
                            pha
                            getword {x},#playfield_entity~grentity+grlib_entity~y
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~y
                            plx
                            jsl math~vec2_angle
                            sta <wCurrentTargetAngle
                            ldy <spEntity                                       ; get the entity pointer back in y
                            putword {y},#playfield_entity~target_angle

; Update our running average
                            sec
                            sbc <wPrevTargetAngle
                            clc
                            adcword {y},#playfield_entity~target_angle_change_avg
                            asr_nt 1                                            ; use the asr, that assumes N is correctly set.
                            inc a
                            and #$fffe
                            putword {y},#playfield_entity~target_angle_change_avg
; Aim ahead of the target
                            asl a
                            clc
                            adc <wCurrentTargetAngle
                            and #$00ff
                            shiftright 3                                        ; shift to direction range
; We only have 8 visual directions, lock to only those directions
                            static_assert_equal gameplay_warrior_turret_direction_count,8
                            bcc was_less_than_half
                            inc a                                               ; round up
                            inc a
was_less_than_half          and #32-4                                           ; then make sure it is divisible by 4
                            sta <wWantAimDirection

; Is this secretly the player? (Demo mode)
                            getword {y},#playfield_entity~type
                            cmp #entity_type~player
                            beq is_player

                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq not_on_screen                                   ; not on screen?  Leave it alone

                            getword {y},#playfield_entity~turret_direction
                            tax                                                 ; x will have our current value
                            sec
                            sbc <wWantAimDirection
                            beq at_lock
                            bcs larger
; smaller
                            negate a
                            cmp #playfield_entity~direction_range/2
                            bge counter_clockwise
clockwise                   txa
                            clc
                            adc #4                                              ; 4 == one 'visual' click
                            bra new_aim

larger                      anop
                            cmp #playfield_entity~direction_range/2
                            bge clockwise
counter_clockwise           txa
                            sec
                            sbc #4

new_aim                     anop
                            and #playfield_entity~direction_range_mask
                            putword {y},#playfield_entity~turret_direction

                            getword {y},#playfield_entity~personality
                            and #(personality~turret_locked*-1)-1
                            putword {y},#playfield_entity~personality
                            bra exit

at_lock                     getword {y},#playfield_entity~personality
                            ora #personality~turret_locked
                            putword {y},#playfield_entity~personality

not_on_screen               anop
exit                        lret
is_player                   anop
; This needs to adjust the aim for the player in demo mode
                            bra exit
                            end
; ----------------------------------------------------------------------------
; Have a warrior attempt to shoot at something.
; This will check for on-screen, and inhibition, and will possibly not shoot
; Parameters:
; y-reg         - the short pointer to the warrior (note, in attract mode, this can be the player)
; x-reg         - the short pointer to the target
; Returns:
; Carry set, did not shoot.
_gameplay_warrior_shoot     private seg_gameplay
                            using appdata
                            using gameplay_warrior_logic_data
                            using grlib_global_data
                            using shot_entity_data
                            using gameplay_sound_data
                            debugtag 'warrior_shoot'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

                            lsub ,work_area_size

                            sty <spEntity

                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq not_on_screen

                            getword {x},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq not_on_screen

; In the original, there is a test to see if the warrior is within the 'hard scrolling borders'
                            getword {y},#playfield_entity~mission_id
                            cmp #id_warrior_mission_mine
                            beq ok_shoot
                            getword {y},#playfield_entity~personality
                            bit #personality~shooting_inhibitor_count
                            bne inhibited
; Inhibitor down to 0, we can shoot
;                            keyed_break 4,'shoot'
                            getword {y},#playfield_entity~type
                            cmp #entity_type~player
                            beq ok_shoot_player                ; the player can just shoot

; Note that the following does not animate the turret, it just checks to see what its current position is
; Get the angle, from the source, to the target
; First, turn the coordinates, into a delta

; KWG: In the original code, SHOOT.SRC, it actually looks like it goes through the motions of
; doing this calculation, then not actually using the result.
; Maybe I am missing something?  Some side effect? I don't want to waste cycles, so I have disabled the code.
                            ago .disabled
                            getword {x},#playfield_entity~grentity+grlib_entity~x
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~x
                            pha
                            getword {x},#playfield_entity~grentity+grlib_entity~y
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~y
                            plx
                            jsl math~vec2_angle
; We only have 8 visual directions, lock to only those directions
                            static_assert_equal gameplay_warrior_turret_direction_count,8
                            shiftright 3                                        ; shift to direction range

                            ldy <spEntity
                            sec
                            sbcword {y},#playfield_entity~turret_direction
                            bpl positive
                            negate a
positive                    cmp #2                      ; aligned or one on either side?
                            bge not_aligned             ; in the original, this just branches to the line below it, and doesn't skip out.
.disabled

; Are we 'locked'
                            getword {y},#playfield_entity~personality
                            bit #personality~turret_locked
                            beq not_aligned

; We are ok to shoot
ok_shoot                    anop
                            pushsword #shot_entity_type_id_warrior
                            pushsword {y},#playfield_entity~grentity+grlib_entity~x
                            pushsword {y},#playfield_entity~grentity+grlib_entity~y
                            pushsword {y},#playfield_entity~turret_direction
; Not adjusting the speed of the shot with the speed of the source.  The problem is that with the warrior
; they can shoot in a different direction that they are facing, and applying their speed, makes for
; some very 'slow' shots, which are bad because they linger and the player can run into them.
; It does make for an interesting shot pattern though, so maybe revisit this and support a 'minimum' speed?
                            pushsword {y},#playfield_entity~speed_x
                            pushsword {y},#playfield_entity~speed_y
;                           pushsword #0
;                           pushsword #0
                            jsl shot_entity_manager_add_shot

                            pushsword #id_sfx~warrior_shot
                            jsl sndlib_play_sfx
                            clc
                            bra exit
;                            lda #appdata~ui_color~white~bits
;                            bra put_color

not_aligned                 anop
;                            lda #appdata~ui_color~red~bits
;                            bra put_color
not_on_screen               anop
;                            lda #appdata~ui_color~black~bits
;                            bra put_color
inhibited                   anop
;                            lda #appdata~ui_color~blue~bits
;put_color                   sta >$e12000
                            sec
exit                        lretkc
; Special player-doing-the-shooting
ok_shoot_player             anop
                            pushsword #shot_entity_type_id_player
                            pushsword {y},#playfield_entity~grentity+grlib_entity~x
                            pushsword {y},#playfield_entity~grentity+grlib_entity~y
                            pushsword {y},#playfield_entity~turret_direction
                            pushsword {y},#playfield_entity~speed_x
                            pushsword {y},#playfield_entity~speed_y
                            jsl shot_entity_manager_add_shot
                            pushsword #id_sfx~player_shot
                            jsl sndlib_play_sfx
                            clc
                            bra exit
                            end

; ----------------------------------------------------------------------------
; Attack a target
; Parameters:
;  entity short pointer in y
;  target entity short pointer in x
_warrior_attack_target      private seg_gameplay
                            using appdata
                            using gameplay_warrior_logic_data
                            using grlib_global_data

                            debugtag 'attack_target'

                            begin_locals
spEntity                    decl word
spTargetEntity              decl word
wDistanceX                  decl word
wDistanceY                  decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr

                            sty <spEntity
                            stx <spTargetEntity

                            pushptr #gameplay_warrior_logic~attack_speed_table
                            getword {x},#playfield_entity~grentity+grlib_entity~x
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~x
                            sta <wDistanceX
                            pha
                            getword {x},#playfield_entity~grentity+grlib_entity~y
                            sec
                            sbcword {y},#playfield_entity~grentity+grlib_entity~y
                            sta <wDistanceY
                            pha
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <spEntity
                            ldx <spTargetEntity
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda >gameplay_warrior_logic~attack_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

; On screen?
                            ldy <spEntity
                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            beq not_on_screen

                            lda <wDistanceX
                            bpl pos_x
                            negate a
pos_x                       cmp #gameplay_warrior_min_attack_distance*2
                            bge too_far
                            lda <wDistanceY
                            bpl pos_y
                            negate a
pos_y                       cmp #gameplay_warrior_min_attack_distance*2
                            bge too_far
; In range

; Note this is how it was in the original, where it did the 1-in-2 test.
; This is because the 'lead' attacker, attacked using the 'mining' pathway.
                            generate_rnd16
                            bit #$8000                      ; 1 in 2, to do the mission
                            beq no_shoot

; More 'mining' pathway code, i.e check if the target is the player, if not, then we are mining.
                            ldx <spTargetEntity
                            getword {x},#playfield_entity~type
                            cmp #entity_type~player
                            bne not_player                  ; if not the player, just shoot

; Is player, do another test to shoot.
                            jsr _test_warrior_shoot
                            blt no_shoot

not_player                  jsr _gameplay_warrior_shoot     ; y (entity) and x (target) should be setup already
; Make the game a bit easier, and prevent the warrior from immediately shooting again.
                            aif C:modification~inhibit_every_shot=0,.skip
                            bcs no_shoot
                            jsr _warrior_get_shoot_inhibit
                            ldy <spEntity
                            ora |playfield_entity~personality,y
                            putword {y},#playfield_entity~personality
.skip

not_on_screen               anop
;                            lda #appdata~ui_color~black~bits
;                            bra put_color
no_shoot                    anop
;                            lda #$9e9e
;                            bra put_color
too_far                     anop
;                            lda #appdata~ui_color~yellow~bits
;put_color                   sta >$e12000
exit                        anop
                            lret

                            end

; ----------------------------------------------------------------------------
; Orbit a target
; Parameters:
;  entity short pointer in y
;  target short pointer in x
;
; Note, this also shoots at the player, if avaialble, regardless of the target.
; This helps if orbiting Sinistar as a guard.
; Note, this returns carry clear if the warrior shot at the target, set if not
_warrior_orbit_target       private seg_gameplay
                            using gameplay_warrior_logic_data
                            using grlib_global_data
                            using player_entity_data

                            debugtag 'orbit_target'

                            begin_locals
spEntity                    decl word
spTargetEntity              decl word
wDistanceX                  decl word
wDistanceY                  decl word
; The next four entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            lsub ,work_area_size     ; note, lsub, as this is accessed through a jsr table.

                            sty <spEntity
                            stx <spTargetEntity
                            pushsword {y},#playfield_entity~grentity+grlib_entity~x
                            pushsword {y},#playfield_entity~grentity+grlib_entity~y
                            pushsword {x},#playfield_entity~grentity+grlib_entity~x
                            pushsword {x},#playfield_entity~grentity+grlib_entity~y
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            pushsword #gameplay_warrior_orbit_factor
                            pushsword >gameplay_warrior_orbit_multiplier
                            jsl playfield_get_orbital_distance_speculative
                            sta <wDistanceX
                            stx <wDistanceY

                            pushptr #gameplay_warrior_logic~orbit_speed_table
                            pushsword <wDistanceX
                            pushsword <wDistanceY
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <spEntity
                            ldx <spTargetEntity
                            pushsword {x},#playfield_entity~speed_x
                            pushsword {x},#playfield_entity~speed_y
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda >gameplay_warrior_logic~orbit_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

; Always shooting at the player
                            ldy <spEntity
                            ldx #player_entity_instance
                            jsr _gameplay_warrior_shoot

exit                        anop
                            lretkc      ; returning the carry, to tell if a shot was fired

                            end

; ----------------------------------------------------------------------------
; Initialize the warrior shooting inhibiter.
; This is a countdown of updates, the warrior has to do
; before it is allowed to shoot.
; This is set when the warrior goes off screen, and then counts down
; when it comes back on.
_warrior_get_shoot_inhibit  private seg_gameplay
                            using gameplay_manager_data

                            debugtag 'get_shoot_inhibit'

; The original code seemed to be inverting the aggression range, with a ones-compliment,
; and looping over that, simulating a divide by 40, by adding 40, and, and incrementing a counter,
; on overflow.  The end result was to get the inverted aggression to work out to 1 to 4,
; so that least aggressive would have an inhibit timer of 4 (a base value) + 4, so 8 as a max, and 5 as minimum.
; I think I can replicate it close enough by just inverting and dividing by 32 and adding 1

                            lda #$007f
                            sep #%00100001                      ; set short-m, as well as the carry
                            longa off
; Subtract the integer portion of the aggression value.
                            sbc >gameplay_manager~active_state+player_state~warrior_aggression+1
                            longm
                            shiftright 5
                            clc
; note, this will make the value 5 to 8, however, there are a full 4 bits of range, so it could be increased.
                            adc #1+4
                            rts

                            end

; -----------------------------------------------------------------------------
; Initialize the warriors for gameplay, this is pre-state activation
gameplay_warriors_initialize start seg_gameplay
                            using warrior_entity_manager_data

                            debugtag 'warriors_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_warriors_uninitialize start seg_gameplay
                            using gameplay_warrior_logic_data

                            debugtag 'warrior_uninitialize'

                            jsl warrior_entity_manager_remove_all

                            rtl
                            end

; -----------------------------------------------------------------------------
; Turn deactivation
gameplay_warriors_turn_deactivate start seg_gameplay
                            using warrior_entity_manager_data

                            debugtag 'warriors_turn_deactivate'

                            jsl warrior_entity_manager_remove_all
; The population function will add the warriors later in the state activation

                            rtl
                            end

; ----------------------------------------------------------------------------
; Check the population of warriors and add more if needed
; Parameters:
; wMax      - max number to add
; wEdge     - add at the edges of the sector
; Returns:
; number added
gameplay_warriors_check_population start seg_gameplay
                            using appdata
                            using warrior_entity_data
                            using warrior_entity_manager_data
                            using gameplay_warrior_logic_data
                            using gameplay_level_data
                            using gameplay_manager_data
                            using playfield_manager_data

                            debugtag 'warriors_check_population'

                            begin_locals
wCount                      decl word
result                      decl word
work_area_size              end_locals

                            sub (2:wMax,2:wEdge),work_area_size

                            setlocaldatabank

                            stz <result
; Get the desired amount.  Pass this in too?
                            lda gameplay_manager~active_state+player_state~desired_pop~warriors     ; fp16 value
                            bmi no_extra                                ; test for negative
                            xba
                            and #$00ff                                  ; integer portion
                            sec
                            sbc >warrior_entity_count
                            bcc no_extra                                ; 0 or negative?
                            beq no_extra
; A, has ours deficit
                            cmp <wMax                   ; clamp to max limit
                            blt ok
                            lda <wMax
                            beq no_extra
ok                          sta <wCount
                            sta <result

                            lda <wEdge
                            bne loop_edge

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

                            jsl warrior_entity_manager_add_warrior

                            dec <wCount
                            bne loop
                            bra no_extra

; Add to the edges
loop_edge                   anop
                            jsl gameplay_generate_random_edge_location
                            pha         ; x coordinate
                            phx         ; y coordinate
                            jsl warrior_entity_manager_add_warrior

                            dec <wCount
                            bne loop_edge

no_extra                    anop
                            restoredatabank

                            ret 2:result
                            end
