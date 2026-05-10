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
                            copy source/bomb.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm

                            mcopy generated/gameplay.bomb.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the bombs.

; ----------------------------------------------------------------------------
gameplay_bomb_logic_data    data seg_gameplay

gameplay_bomb_task_data     equ sizeof~task_control                         ; Starting with support for sleep commands
gameplay_bomb_task_data~entity_ptr equ gameplay_bomb_task_data        ; Pointer to the entity
gameplay_bomb_task_data~age equ gameplay_bomb_task_data~entity_ptr+4  ; age of the bomb
sizeof~gameplay_bomb_task_data equ gameplay_bomb_task_data~age+2

; The min distance at which the sinistar can be, and have the bomb explode and hurt him
; This is only for off-screen.
; The value from the original was 80
gameplay_bomb~explode_distance  equ 80

; Min distance at which a intercept responder (worker or warrior) can be, bomb will kill them
; This is only for off-screen
gameplay_bomb~responder_kill_distance equ 1+(gameplay_bomb~explode_distance/4)

gameplay_bomb~responder_kill_distance_x equ gameplay_bomb~responder_kill_distance
; Whoa, what is this?  This is mimicking a bug in the original code, where it was always comparing a distance of 0
; I'm doing this, because fixing it, would make the game a bit harder, because the sinibombs would more easily be intercepted.
gameplay_bomb~responder_kill_distance_y equ 4+1

; Values are from the original (stblsbomb)
gameplay_bomb_logic~intercept_speed_table anop
                            dc i'4000,($1fff),acceleration_function~3'
                            dc i'0512,($1100),acceleration_function~4'
                            dc i'0128,($0600),acceleration_function~3'
                            dc i'0064,($0400),acceleration_function~3'
                            dc i'0032,($0200),acceleration_function~3'
                            dc i'0016,($0100),acceleration_function~2'
                            dc i'0008,($00C0),acceleration_function~1'
                            dc i'0000,($0040),acceleration_function~0'
                            end

; ----------------------------------------------------------------------------
; Initialize the bomb values
; Parameters:
; x-reg  - short pointer to entity
gameplay_bomb_initialize    start seg_gameplay
                            using bomb_entity_data
                            using gameplay_bomb_logic_data
                            using gameplay_entity_data
                            using task_manager_data

                            debugtag 'bomb_initialize'

                            begin_locals
spThis                      decl word
pTaskData                   decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            stx <spThis
                            jsl gameplay_caller_initialize

; Make the 'think' flag random, to spread things out a bit
                            generate_rnd16
                            and #personality~think_flag
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~personality

                            pushsword #task_list_8_offset
                            pushptr #gameplay_task_bomb_logic_tick
                            pushsword #sizeof~gameplay_bomb_task_data
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

; Put the caller pointer into the task data
                            lda <spThis
                            tax
                            putptrlow [<pTaskData],#gameplay_bomb_task_data~entity_ptr
                            lda #^entities_root
                            putptrhigh [<pTaskData],#gameplay_bomb_task_data~entity_ptr

; And the task pointer to the entity.  Using the task2 slot
                            lda <pTaskData
                            putptrlow {x},>entities_root+playfield_entity~task2_ptr
                            lda <pTaskData+2
                            putptrhigh {x},>entities_root+playfield_entity~task2_ptr

error                       anop
                            ret
                            end


; -----------------------------------------------------------------------------
gameplay_task_bomb_logic_tick start seg_gameplay
                            using task_manager_data
                            using bomb_entity_data
                            using bomb_entity_manager_data
                            using gameplay_bomb_logic_data
                            using gameplay_manager_data
                            using sinistar_entity_data
                            using gameplay_sinistar_logic_data
                            using gameplay_player_logic_data
                            using gameplay_sound_data
                            using gameplay_ui_data

                            debugtag 'bomb_logic_tick'

                            begin_locals
pEntity                     decl ptr
pResponder                  decl ptr
pTarget                     decl ptr
pTargetParent               decl ptr
wKillBomb                   decl word
wBombOnScreen               decl word
wTargetX                    decl word
wTargetY                    decl word
wDistanceX                  decl word
wDistanceY                  decl word
wTargetSpeedX               decl word
wTargetSpeedY               decl word
; The next 4 entries must be in this order
wVelocityX                  decl word
wAccelerationX              decl word
wVelocityY                  decl word
wAccelerationY              decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            setlocaldatabank

                            stz <wKillBomb

                            getptr [<pTaskData],#gameplay_bomb_task_data~entity_ptr,<pEntity
; Not defining a task_resume, since we don't do any internal task_sleep calls

                            ldx <pEntity
                            jsl gameplay_entity_test_should_think
                            jcs exit
; Is the bomb on screen?
                            getword [<pEntity],#playfield_entity~state_flags
                            and #playfield_entity~state_on_collision_list
                            sta <wBombOnScreen
                            bne on_screen

; off screen, any responders die.
                            getword [<pEntity],#playfield_entity~responder_root_sptr
                            beq no_responders

                            jsr check_responder_kill
; Note, that like the original, even if the bomb hit a responder, we still check against Sinistar

no_responders               anop
on_screen                   anop

                            lda gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_dead
                            jeq exit

                            jsl sinistar_entity_get_piece_to_target
                            jcs exit

                            putretptr <pTarget

; The target could be a child, make sure we get the full location
                            getword [<pTarget],#playfield_entity~grentity+grlib_entity~parent_entity_ptr+2
                            beq no_parent
                            sta <pTargetParent+2
                            getword [<pTarget],#playfield_entity~grentity+grlib_entity~parent_entity_ptr
                            sta <pTargetParent

; We have to get the child absolute position
                            getword [<pTargetParent],#playfield_entity~grentity+grlib_entity~x
                            clc
                            adc [<pTarget],y
                            sta <wTargetX

                            getword [<pTargetParent],#playfield_entity~grentity+grlib_entity~y
                            clc
                            adc [<pTarget],y
                            sta <wTargetY

                            getword [<pTargetParent],#playfield_entity~speed_x
                            sta <wTargetSpeedX
                            getword [<pTargetParent],#playfield_entity~speed_y
                            sta <wTargetSpeedY

                            bra was_child

; Target is the parent
no_parent                   anop
                            getword [<pTarget],#playfield_entity~grentity+grlib_entity~x
                            sta <wTargetX
                            getword [<pTarget],#playfield_entity~grentity+grlib_entity~y
                            sta <wTargetY

                            getword [<pTarget],#playfield_entity~speed_x
                            sta <wTargetSpeedX
                            getword [<pTarget],#playfield_entity~speed_y
                            sta <wTargetSpeedY

was_child                   anop
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~x
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~y
                            pushsword <wTargetX
                            pushsword <wTargetY
                            jsl playfield_get_target_distance
                            sta <wDistanceX
                            stx <wDistanceY

                            pushptr #gameplay_bomb_logic~intercept_speed_table
                            pushsword <wDistanceX
                            pushsword <wDistanceY
                            pushlocalsptr #wVelocityX                                   ; point to the first entry in the output struct
                            jsl playfield_get_to_target_velocity

                            pushsword <pEntity
                            pushsword <wTargetSpeedX
                            pushsword <wTargetSpeedY
                            pushsword <wVelocityX
                            pushsword <wVelocityY
                            pushsword <wAccelerationX
                            pushsword <wAccelerationY
; The velocity in the first entry of the table, is assumed to be vmax.
                            lda gameplay_bomb_logic~intercept_speed_table+target_velocity_entry~velocity
                            pha
                            jsl playfield_entity_update_to_target_velocity

                            lda <wBombOnScreen
                            bne bomb_on_screen                      ; on screen? The collision check will handle the rest.

                            lda gameplay_sinistar_logic~in_sector
                            beq exit                                ; not in sector

                            lda >sinistar_entity~on_screen
                            bne exit                                ; if on screen, exit

; Both off screen, we can check to see if they are in range
                            lda <wDistanceX
                            cmp #gameplay_bomb~explode_distance
                            bsge exit
                            cmp #-gameplay_bomb~explode_distance
                            bslt exit
                            lda <wDistanceY
                            cmp #gameplay_bomb~explode_distance
                            bsge exit
                            cmp #-gameplay_bomb~explode_distance
                            bslt exit

; We hit! Destroy a piece!
                            pushptr <pTarget
                            pushsword #0
                            jsl sinistar_entity_destroy_piece
; Post message
                            lda #gameplay_ui~message_sinibomb_attack
                            jsl gameplay_ui_set_active_player_message

                            bra destroy_bomb

exit                        anop
                            lda <wKillBomb
                            beq bomb_lives

destroy_bomb                ldx <pEntity
                            jsl playfield_entity_mark_for_removal

bomb_on_screen              anop
bomb_lives                  anop
                            restoredatabank
                            ret

;;; Local function
; The bomb is off-screen, see if any responders are off-screen and within range
; if so, kill them
check_responder_kill        anop

                            ldy #^entities_root                         ; fix the need for this!
                            sty <pResponder+2

responder_loop              anop
; Remove the responder from the bomb
                            sta <pResponder

                            getword [<pResponder],#playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list
                            bne next_responder

; See if close enough.  Note, the original code (SINIBOMB.SRC) looks buggy, the way it is doing the compare.

                            getword [<pResponder],#playfield_entity~caller_dist_x
                            cmp #gameplay_bomb~responder_kill_distance_x
                            bge next_responder

                            getword [<pResponder],#playfield_entity~caller_dist_y
                            cmp #gameplay_bomb~responder_kill_distance_y
                            bge next_responder

; Kill the responder.  Note this doesn't do much immediately, so we get still get the next sibling
                            ldx <pResponder
                            jsl playfield_entity_mark_for_removal

                            inc <wKillBomb

next_responder              getword [<pResponder],#playfield_entity~next_sibling_sptr
                            bne responder_loop
done_responders             rts

                            end

; -----------------------------------------------------------------------------
; Bomb is leaving the sector.
; Parameters:
; y-reg     - short pointer to the entity
gameplay_bomb_leave_sector  start seg_gameplay
                            using gameplay_manager_data
                            using gameplay_player_logic_data
                            using gameplay_sinistar_logic_data
                            using gameplay_ui_data
                            using sinistar_entity_data

                            phy
; Sinistar building or alive?
                            lda >gameplay_manager~active_state+player_state~sinistar~state
                            cmp #sinistar_state_dead
                            beq is_dead

; How about, in-sector?
                            lda >gameplay_sinistar_logic~in_sector
                            bne is_in_sector                                ; sinistar is in sector, so just remove the bomb

; Player alive?
                            lda >gameplay_player~is_dead
                            bne is_dead

; Sinistar is out of sector, so we just assume that the bomb 'hit' Sinistar, which is also out of the sector
                            pushptr #0                                      ; pushing null, will cause a piece to be picked
                            pushsword #0
                            jsl sinistar_entity_destroy_piece
; Post message
                            lda #gameplay_ui~message_sinibomb_attack
                            jsl gameplay_ui_set_active_player_message

is_dead                     anop
                            plx                                             ; get the saved entity off the stack
                            jsl playfield_entity_mark_for_removal

                            rtl

; Sinistar is in the sector, so this bomb is lost, post a message.
is_in_sector                anop
                            lda #gameplay_ui~message_sinibomb_intercepted   ; maybe make 'bomb is lost' message?
                            jsl gameplay_ui_set_active_player_message
                            bra is_dead

                            end

; ----------------------------------------------------------------------------
; Initialize the bombs for gameplay, this is pre-state activation
gameplay_bombs_initialize start seg_gameplay
                            using bomb_entity_manager_data

                            debugtag 'bombs_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_bombs_uninitialize start seg_gameplay
                            using gameplay_bomb_logic_data
                            using gameplay_level_data

                            debugtag 'bombs_uninitialize'

                            jsl bomb_entity_manager_remove_all

                            rtl
                            end

; ----------------------------------------------------------------------------
; Turn deactivation
gameplay_bombs_turn_deactivate start seg_gameplay
                            using bomb_entity_manager_data

                            debugtag 'bombs_turn_deactivate'

                            jsl bomb_entity_manager_remove_all

                            rtl
                            end
