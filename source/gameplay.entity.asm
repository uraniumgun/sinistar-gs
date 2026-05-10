                            copy lib/source/debug.definitions.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm

                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/collision.definitions.asm
                            copy source/explosion.entity.definitions.asm

                            mcopy generated/gameplay.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
gameplay_entity_data        data seg_gameplay
                            using gameplay_caller_logic_data

; Maximum vibration scale amount
gameplay_vibrate_scale_max  equ 96
; Minimum vibration, at which a crystal is ejected
gameplay_vibrate_scale_min_crystal_eject equ 16
; Amount of mass lost, per crystal mined
gameplay_planetoid_crystal_mass_reduction equ 8

; Shared personality bit
personality~think_flag      equ $0020

; The characteristics supported.  These are not necessarily in the order of the entity_type list
; There can be multiple characteristics that slot into an entity type, to change the behavior
; See the gameplay.entity.characteristics.asm file for information on the fields
characteristics_table       anop
; id_characteristic_default
                            dc i'ai_type_invalid'
                            dc i'0'
                            dc i'collision_type~none'
                            dc i'explosion_type~none'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_player
                            dc i'ai_type_player'                ; ai_type
                            dc i'5'                             ; mass
gameplay_player~collision_type entry                            ; bit of a hack to have a place to disable player collisions
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~player'
                            dc a4'0'                            ; leave sector func
; id_characteristic_worker
                            dc i'ai_type_workers'               ; ai_type
                            dc i'1'                             ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~basic'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_warrior
                            dc i'ai_type_warriors'              ; ai_type
                            dc i'2'                             ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~warrior'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_player_shot
                            dc i'ai_type_invalid'               ; ai_type
                            dc i'0'                             ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~none'
                            dc a4'0'                            ; leave sector func
; id_characteristic_warrior_shot
                            dc i'ai_type_invalid'               ; ai_type
                            dc i'0'                             ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~none'
                            dc a4'0'                            ; leave sector func
; id_characteristic_worker_with_crystal
                            dc i'ai_type_workers'               ; ai_type
                            dc i'1'                             ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~basic'
                            dc a4'gameplay_worker_with_crystal_leave_sector' ; leave sector func
; id_characteristic_crystal
                            dc i'ai_type_crystal'               ; ai_type
                            dc i'1'                             ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~none'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_explosion
                            dc i'ai_type_invalid'               ; ai_type
                            dc i'0'                             ; mass
                            dc i'collision_type~none'           ; collision type
                            dc i'explosion_type~none'
                            dc a4'0'                            ; leave sector func
; id_characteristic_planetoid_1
                            dc i'ai_type_invalid'               ; ai_type
                            dc i'60'                            ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~rock_medium'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_planetoid_2
                            dc i'ai_type_invalid'               ; ai_type
                            dc i'$50'                           ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~rock_medium'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_planetoid_3
                            dc i'ai_type_invalid'               ; ai_type
                            dc i'30'                            ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~rock_small'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_planetoid_4
                            dc i'ai_type_invalid'               ; ai_type
                            dc i'50'                            ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~rock_medium'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_planetoid_5
                            dc i'ai_type_planetoid'             ; ai_type
                            dc i'90'                            ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~rock_large'
                            dc a4'gameplay_entity_default_leave_sector' ; leave sector func
; id_characteristic_sinistar
                            dc i'ai_type_sinistar'              ; ai_type
                            dc i'255'                           ; mass
                            dc i'collision_type~normal_no_collide_same' ; collision type
                            dc i'explosion_type~none'
                            dc a4'gameplay_sinistar_leave_sector' ; leave sector func
; id_characteristic_bomb
                            dc i'ai_type_bomb'                  ; ai_type
                            dc i'1'                             ; mass
                            dc i'collision_type~normal'         ; collision type
                            dc i'explosion_type~basic'
                            dc a4'gameplay_bomb_leave_sector'   ; leave sector func
                            end

; ----------------------------------------------------------------------------
; Task callback for vibrating something.
; This uses a 'scale' for how violent the vibrate is.
; The vibrate task is split into three parts, each is run on a seprate pass of the task.
; Step 1, use the current scale to get an x / y delta, and add that to the objects speed.
; Step 2, reverse the delta calculated in step 1, and add that to the objects speed,
;         this essentially pops it to the other side.
; Step 3, remove the delta from the speed and set the delta to 0, then look to see if a
;         crystal should be thrown, or the object should be shattered.
;         Also, damp the scale, then go back to step 1.
gameplay_task_vibrate       start seg_gameplay
                            using appdata
                            using applib_data
                            using gameplay_entity_data

                            debugtag 'task_vibrate'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

step_1_index                equ 0*2
step_2_index                equ 1*2
step_3_index                equ 2*2

vibrate_damping             equ 2

                            sub (4:pTaskData),work_area_size


; Set the databank to the entities pool
                            setdatabanktolabel entities_root

                            getword [<pTaskData],#vibrate_task~entity_ptr
                            sta <spEntity
                            tay

; Is the object on the collision list?  If so, it is on screen.
                            getword {y},#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            jeq off_screen

                            getword [<pTaskData],#vibrate_task~step
                            tax
                            ldy <spEntity                                           ; get the entity short pointer back
                            jmp (step_table,x)

; This randomizes the direction of the vibration offset, then adds it to the speed
step_1                      anop
                            tyx
step_loop                   getword [<pTaskData],#vibrate_task~scale
                            shiftleft 3                                             ; original code shifted by 2 (* 4), but that doesn't move it around enough.
                            pha
                            jsr adjust_value
                            putword [<pTaskData],#vibrate_task~delta_x
                            clc
                            adcword {x},#playfield_entity~speed_x
                            putword {x},#playfield_entity~speed_x                   ; does this need a cap?
                            pla
                            jsr adjust_value
                            putword [<pTaskData],#vibrate_task~delta_y
                            clc
                            adcword {x},#playfield_entity~speed_y
                            putword {x},#playfield_entity~speed_y                   ; does this need a cap?

; zap these
                            putzero {x},#playfield_entity~move_accum_x
                            putzero {x},#playfield_entity~move_accum_y

                            lda #step_2_index                                       ; step the jump table to the next step
                            putword [<pTaskData],#vibrate_task~step

                            brl exit

; This reverses the last vibration offset
step_2                      anop
                            tyx
                            getword [<pTaskData],#vibrate_task~delta_x
                            negate a
                            putword [<pTaskData],#same
                            asl a                                                   ; double it to go to the opposite 'side'
                            clc
                            adcword {x},#playfield_entity~speed_x
                            putword {x},#playfield_entity~speed_x                   ; does this need a cap?

                            getword [<pTaskData],#vibrate_task~delta_y
                            negate a
                            putword [<pTaskData],#same
                            asl a                                                   ; double it to go to the opposite 'side'
                            clc
                            adcword {x},#playfield_entity~speed_y
                            putword {x},#playfield_entity~speed_y                   ; does this need a cap?

                            lda #step_3_index                                       ; step the jump table to the next step
                            putword [<pTaskData],#vibrate_task~step
                            bra exit

step_3                      anop
; Remove the vibration
                            tyx
                            getword [<pTaskData],#vibrate_task~delta_x
                            negate a
                            clc
                            adcword {x},#playfield_entity~speed_x
                            putword {x},#playfield_entity~speed_x

                            getword [<pTaskData],#vibrate_task~delta_y
                            negate a
                            clc
                            adcword {x},#playfield_entity~speed_y
                            putword {x},#playfield_entity~speed_y

                            lda #0
                            putword [<pTaskData],#vibrate_task~delta_x
                            putword [<pTaskData],#vibrate_task~delta_y

; Is this a planetoid?
                            getword {x},#playfield_entity~type
                            cmp #entity_type~planetoid
                            bne not_planetoid

; Yes, see if we eject a crystal.
                            pushptr <pTaskData
                            jsl gameplay_rock_entity_eject_crystal      ; assumes entity sptr is in X
; Damp the vibration
                            ldx <spEntity
                            getword [<pTaskData],#vibrate_task~scale
                            sec
                            sbc #vibrate_damping
                            putword [<pTaskData],#same
                            beq over                                    ; went to 0?
                            bcc over                                    ; or negative? Then we are done.
                            cmp #gameplay_vibrate_scale_max
                            jlt step_loop                                  ; if not at max, keep going.
; At max
                            jsl gameplay_rock_entity_shatter
; Restore the x reg
                            ldx <spEntity

over                        anop
                            lda #0
                            putword [<pTaskData],#vibrate_task~scale
                            putptr {x},#playfield_entity~vibration_task_ptr
                            pushptr <pTaskData
                            jsl task_manager_free_task

exit                        restoredatabank
                            ret

not_planetoid               anop
                            getword [<pTaskData],#vibrate_task~scale
                            sec
                            sbc #vibrate_damping*2
                            putword [<pTaskData],#same
                            beq over                                    ; went to 0?
                            bcc over                                    ; or negative? Then we are done.
                            cmp #gameplay_vibrate_scale_max
                            jlt step_loop                               ; if not at max, keep going.
                            bra over

off_screen                  anop
                            tyx
                            getword [<pTaskData],#vibrate_task~scale
                            sec
                            sbc #vibrate_damping
                            putword [<pTaskData],#same
                            beq over                                    ; went to 0?
                            bcc over                                    ; or negative? Then we are done.
                            bra exit

step_table                  anop
                            dc a2'step_1'
                            dc a2'step_2'
                            dc a2'step_3'

; -------------
adjust_value                anop
                            cmp #0
                            beq no_adjust
; Randomly invert it
                            pha
                            generate_rnd16
                            lsr a
                            pla
                            bcc no_negate
                            negate a
no_negate                   anop
; Randomly scale it
                            pha
                            generate_rnd16
                            lsr a
                            pla
                            bcc no_scale
; div by 2, signed.  Well I know the carry is set, so if the value is negative, just ror it
; else clear the carry, then ror it.
                            bmi negative_scale
                            clc
negative_scale              ror a
no_scale                    anop
no_adjust                   anop
                            rts

                            end

; -----------------------------------------------------------------------------
; Add vibration to an entity.
; This will increase its vibration, based on its mass and will
; start a task to handle the vibration update (if one has not already be started)
; Parameters:
;  Entity short pointer in x
gameplay_entity_add_vibration start seg_gameplay
                            using math_tables
                            using gameplay_entity_data
                            using task_manager_data

                            begin_locals
spThis                      decl word
wVibrationAdd               decl word
pTaskData                   decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            stx <spThis
; Going to use long addressing to access the entity, there isn't enough access to overcome the overhead of setting and restoring the bank (20 cycles)
                            getword {x},>entities_root+playfield_entity~type
                            cmp #entity_type~planetoid
                            beq is_planetoid
; Fixed amount
                            lda #gameplay_vibrate_scale_max/2
                            bra not_planetoid

is_planetoid                anop
; Get the current mass from the personality member (assumes this is a planetoid, which stores it there)
                            getword {x},>entities_root+playfield_entity~personality
                            shiftright 4            ; div by 16
                            bne not_zero
                            lda #1
not_zero                    anop
                            asl a
                            tax
; Invert it, so that it takes longer to ramp up vibration on larger objects
                            lda >math~inverse_256,x
                            ldx <spThis                     ; get this back before the branch
                            shiftright 2                    ; scale it
                            bne ok_scale
                            lda #1
not_planetoid               anop
ok_scale                    anop
                            sta <wVibrationAdd

                            getword {x},>entities_root+playfield_entity~vibration_task_ptr+2
                            beq no_task
                            sta <pTaskData+2
                            getword {x},>entities_root+playfield_entity~vibration_task_ptr
                            sta <pTaskData
                            bra has_task
; Need to add a new task
no_task                     pushsword #task_list_4_offset
                            pushptr #gameplay_task_vibrate
                            pushsword #sizeof~vibrate_task_data
                            jsl task_manager_create_task
                            bcs error

                            putretptr <pTaskData

; Add the entity to the task data
                            lda <spThis
                            tax
                            putptrlow [<pTaskData],#vibrate_task~entity_ptr
                            lda #^entities_root
                            putptrhigh [<pTaskData],#vibrate_task~entity_ptr
                            lda #0
                            putword [<pTaskData],#vibrate_task~step

; Add the task, to the entity
                            lda <pTaskData
                            putptrlow {x},>entities_root+playfield_entity~vibration_task_ptr
                            lda <pTaskData+2
                            putptrhigh {x},>entities_root+playfield_entity~vibration_task_ptr

has_task                    getword [<pTaskData],#vibrate_task~scale
                            cmp #gameplay_vibrate_scale_max
                            bge skip
                            clc
                            adc <wVibrationAdd
                            putword [<pTaskData],#same

skip                        anop
error                       anop
                            ret
                            end

; -----------------------------------------------------------------------------
; Handle gameplay related destruction of an entity
; Parameters:
;  short pointer to the entity in Y
gameplay_entity_on_destruct start seg_gameplay

                            debugtag 'gameplay_entity_on_destruct'

                            phy
                            jsl gameplay_caller_remove_all_reponders
                            ply
                            phy
                            jsl gameplay_responder_remove_from_caller

; Make sure there is no vibration task still attached
                            plx
                            getword {x},>entities_root+playfield_entity~vibration_task_ptr+2
                            beq no_vibration
                            pha
                            getword {x},>entities_root+playfield_entity~vibration_task_ptr
                            pha
                            jsl task_manager_free_task

no_vibration                rtl

                            end

; -----------------------------------------------------------------------------
; In the original code, this function looked to see if the entity was on screen, and returned 'true'
; If it was off screen, it toggled a bit in the 'personality', and returned true or false, based on that.
; This was to 'slow down' the entity's 'thinking', when off screen.
;
; Overall, this is actually ripe for being an inline function.
;
; Parameters:
;  entity short pointer in x
; returns carry clear if yes, set if no
; Will not change X or Y
gameplay_entity_test_should_think start seg_gameplay
                            using gameplay_entity_data

; Fix me.  This should assume that the databank is set to the entities, but that will require fixing all the callers.
                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            bne on_screen

; Maybe put the think flag in the state, so we already have the value?
                            getword {x},>entities_root+playfield_entity~personality
                            bit #personality~think_flag
                            bne skip_think
                            eor #personality~think_flag
                            putword {x},>entities_root++playfield_entity~personality
on_screen                   clc
                            rtl

skip_think                  eor #personality~think_flag
                            putword {x},>entities_root++playfield_entity~personality
                            sec
                            rtl

                            end

; -----------------------------------------------------------------------------
; Default leaving the sector function, just markes the entity for removal
; Parameters:
; y-reg     - short pointer to the entity
gameplay_entity_default_leave_sector start seg_gameplay

                            tyx
                            jsl playfield_entity_mark_for_removal

                            rtl

                            end
