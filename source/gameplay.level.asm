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
                            copy lib/source/grlib.entity.sort.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm

                            copy source/task.definitions.asm
                            copy source/gameplay.constants.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/rock.entity.definitions.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/app.ui.definitions.asm

                            mcopy generated/gameplay.level.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay level related functions.

; ----------------------------------------------------------------------------

gameplay_level_data         data seg_gameplay
                            using gameplay_manager_data

gameplay_level~playfield        ds sizeof~playfield
gameplay_level~playfield_view   ds sizeof~playfield_view
gameplay_level~playfield_palette_ptr dc a4'0'

gameplay_level~difficulty_task_ptr  dc i4'0'
gameplay_level~population_task_ptr  dc i4'0'
gameplay_level~randomize_orbits_task_ptr dc i4'0'
gameplay_level~planetoid_swarm_task_ptr dc i4'0'

;gameplay_level~population_task_call_count dc i'0'
;gameplay_level~swarm_task_call_count dc i'0'

; There are 4 'zones', Void / Worker / Warrior / Planetoid
; However, there is a special starting zone for the initial zone.
gameplay_level~zone_type_count  equ 4

; Initial values for population and the difficulty progression tables.
; fp16 values!

; Note, there are two copies of the tables.
; The first are the 'hard' values from original game.
; The second 'easy' ones have some tweaks.

; -------------------------------------------------------------------------
; Original Tables (Hard)

; Population.  The value is the starting number of entities, in fp16,
; so dc i1'0,6' would be 6.
;
; Note that later levels also 'progress' the difficulty adjustment table
; a fixed number of 'passes' before starting, so the actual starting value
; will be higher on later levels.
;
; Zone 0 (Initial Wave) i.e. Void Zone, but the first time through.
gameplay_level~hard~0_start_pop     anop
                    dc i1'0,6'      ; workers
                    dc i1'0,0'      ; warriors
                    dc i1'0,10'     ; planetiods1
                    dc i1'0,2'      ; planetiods2
                    dc i1'0,2'      ; planetiods3
                    dc i1'0,2'      ; planetiods4
                    dc i1'0,2'      ; planetiods5

; Zone 1 (Void Zone)
gameplay_level~hard~1_start_pop     anop
                    dc i1'0,6'      ; workers
                    dc i1'0,8'      ; warriors
                    dc i1'0,1'      ; planetiods1
                    dc i1'0,1'      ; planetiods2
                    dc i1'0,1'      ; planetiods3
                    dc i1'0,1'      ; planetiods4
                    dc i1'0,3'      ; planetiods5

; Zone 2 (Worker Zone)
gameplay_level~hard~2_start_pop     anop
                    dc i1'0,16'     ; workers
                    dc i1'0,3'      ; warriors
                    dc i1'0,10'     ; planetiods1
                    dc i1'0,2'      ; planetiods2
                    dc i1'0,2'      ; planetiods3
                    dc i1'0,2'      ; planetiods4
                    dc i1'0,2'      ; planetiods5

; Zone 3 (Warrior Zone)
gameplay_level~hard~3_start_pop     anop
                    dc i1'0,4'      ; workers
                    dc i1'0,10'     ; warriors
                    dc i1'0,10'     ; planetiods1
                    dc i1'0,2'      ; planetiods2
                    dc i1'0,2'      ; planetiods3
                    dc i1'0,2'      ; planetiods4
                    dc i1'0,2'      ; planetiods5

; Zone 4 (Planetoid Zone)
gameplay_level~hard~4_start_pop     anop
                    dc i1'0,6'      ; workers
                    dc i1'0,8'      ; warriors
                    dc i1'0,16'     ; planetiods1
                    dc i1'0,2'      ; planetiods2
                    dc i1'0,16'     ; planetiods3
                    dc i1'0,2'      ; planetiods4
                    dc i1'0,5'      ; planetiods5

; Demo Zone
gameplay_level~demo_start_pop       anop
                    dc i1'0,2'      ; workers
                    dc i1'0,0'      ; warriors
                    dc i1'0,4'      ; planetiods1
                    dc i1'0,4'      ; planetiods2
                    dc i1'0,4'      ; planetiods3
                    dc i1'0,4'      ; planetiods4
                    dc i1'0,5'      ; planetiods5

sizeof~population_table equ 7*2

; Short address table to the main level population tables
gameplay_level~hard~pop_sptr_table anop
                    dc a2'gameplay_level~hard~1_start_pop'
                    dc a2'gameplay_level~hard~2_start_pop'
                    dc a2'gameplay_level~hard~3_start_pop'
                    dc a2'gameplay_level~hard~4_start_pop'

; Tables to change values
gameplay_level~hard~0_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'          ; timer increase
                    dc i'6'                                                                     ; this value is added to referenced value on next line
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'-8'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'                                                                     ; terminator

gameplay_level~hard~1_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'6'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'-1'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'-1'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~hard~2_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'10'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'-8'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~hard~3_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'4'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'-8'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~hard~4_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'6'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'10'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~demo_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'6'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'1'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'1'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'1'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~hard~difficulty_adjust_sptr_table anop
                    dc a2'gameplay_level~hard~1_difficulty_update_table'
                    dc a2'gameplay_level~hard~2_difficulty_update_table'
                    dc a2'gameplay_level~hard~3_difficulty_update_table'
                    dc a2'gameplay_level~hard~4_difficulty_update_table'

; -------------------------------------------------------------------------
; 'Easy' Tables
; There are not many changes, but I decided to just copy-pasta the tables
; and make them separate, so that other tweaks can be added, if desired.
; The changed are gleaned from SynaMax's YouTube video
; https://youtu.be/HnfcAudPPS4?si=MCXIBClE_n8S2ITS
; which details a change to the starting population of the Warriors,
; along with and adjustment to the difficulty tables that slow the population
; increase for the Warriors.


; Zone 0 (Initial Wave) i.e. Void Zone, but the first time through.
gameplay_level~easy~0_start_pop     anop
                    dc i1'0,6'      ; workers
                    dc i1'0,0'      ; warriors
                    dc i1'0,10'     ; planetiods1
                    dc i1'0,2'      ; planetiods2
                    dc i1'0,2'      ; planetiods3
                    dc i1'0,2'      ; planetiods4
                    dc i1'0,2'      ; planetiods5

; Zone 1 (Void Zone) This is actually the 5th zone, then starts the repeat every 4th level
gameplay_level~easy~1_start_pop     anop
                    dc i1'0,6'      ; workers
                    dc i1'0,8'      ; warriors     no adjustment
                    dc i1'0,1'      ; planetiods1
                    dc i1'0,1'      ; planetiods2
                    dc i1'0,1'      ; planetiods3
                    dc i1'0,1'      ; planetiods4
                    dc i1'0,3'      ; planetiods5

; Zone 2 (Worker Zone)
gameplay_level~easy~2_start_pop     anop
                    dc i1'0,16'     ; workers
                    dc i1'0,0'      ; warriors     was 3
                    dc i1'0,10'     ; planetiods1
                    dc i1'0,2'      ; planetiods2
                    dc i1'0,2'      ; planetiods3
                    dc i1'0,2'      ; planetiods4
                    dc i1'0,2'      ; planetiods5

; Zone 3 (Warrior Zone)
gameplay_level~easy~3_start_pop     anop
                    dc i1'0,4'      ; workers
                    dc i1'0,3'      ; warriors    was 10
                    dc i1'0,10'     ; planetiods1
                    dc i1'0,2'      ; planetiods2
                    dc i1'0,2'      ; planetiods3
                    dc i1'0,2'      ; planetiods4
                    dc i1'0,2'      ; planetiods5

; Zone 4 (Planetoid Zone)
gameplay_level~easy~4_start_pop     anop
                    dc i1'0,6'      ; workers
                    dc i1'0,5'      ; warriors    was 8
                    dc i1'0,16'     ; planetiods1
                    dc i1'0,2'      ; planetiods2
                    dc i1'0,16'     ; planetiods3
                    dc i1'0,2'      ; planetiods4
                    dc i1'0,5'      ; planetiods5


; Short address table to the main level population tables
gameplay_level~easy~pop_sptr_table anop
                    dc a2'gameplay_level~easy~1_start_pop'
                    dc a2'gameplay_level~easy~2_start_pop'
                    dc a2'gameplay_level~easy~3_start_pop'
                    dc a2'gameplay_level~easy~4_start_pop'

; Tables to change values
; The value is the fractional value, added to the population value, for each timer tick.
gameplay_level~easy~0_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'          ; timer increase
                    dc i'6'                                                                     ; this value is added to referenced value on next line
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'4'                                                                     ; was 16
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'-8'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'                                                                     ; terminator

gameplay_level~easy~1_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'6'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'4'                                                                     ; was 16
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'-1'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'-1'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~easy~2_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'10'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'4'                                                                     ; was 16
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'-8'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~easy~3_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'4'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'4'                                                                     ; was 16
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'-8'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~easy~4_difficulty_update_table anop
                    dc a4'gameplay_manager~active_state+player_state~difficulty_timer'
                    dc i'6'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~workers'
                    dc i'4'                                                                     ; was 10
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~warriors'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids1'
                    dc i'16'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids3'
                    dc i'3'
                    dc a4'gameplay_manager~active_state+player_state~desired_pop~planetoids5'
                    dc i'127'
                    dc a4'gameplay_manager~active_state+player_state~warrior_aggression'
                    dc i'0'

gameplay_level~easy~difficulty_adjust_sptr_table anop
                    dc a2'gameplay_level~easy~1_difficulty_update_table'
                    dc a2'gameplay_level~easy~2_difficulty_update_table'
                    dc a2'gameplay_level~easy~3_difficulty_update_table'
                    dc a2'gameplay_level~easy~4_difficulty_update_table'

; ----------------------------------------------------------------------------
; Table to the sub-tables

gameplay_level~first_level_pop_tables anop
                            dc a'gameplay_level~easy~0_start_pop'
                            dc a'gameplay_level~hard~0_start_pop'

gameplay_level~first_level_difficulty_tables anop
                            dc a'gameplay_level~easy~0_difficulty_update_table'
                            dc a'gameplay_level~hard~0_difficulty_update_table'

gameplay_level~pop_tables   anop
                            dc a'gameplay_level~easy~pop_sptr_table'
                            dc a'gameplay_level~hard~pop_sptr_table'


gameplay_level~difficulty_adjust_tables anop
                            dc a'gameplay_level~easy~difficulty_adjust_sptr_table'
                            dc a'gameplay_level~hard~difficulty_adjust_sptr_table'

                            end

; ----------------------------------------------------------------------------
gameplay_level_initialize   start seg_gameplay

                            debugtag 'level_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_level_uninitialize start seg_gameplay
                            using appdata
                            using gameplay_level_data

                            debugtag 'level_uninitialize'

                            begin_locals
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            pushptr gameplay_level~difficulty_task_ptr
                            jsl task_manager_free_task
                            clearptr gameplay_level~difficulty_task_ptr

                            pushptr gameplay_level~population_task_ptr
                            jsl task_manager_free_task
                            clearptr gameplay_level~population_task_ptr

                            pushptr gameplay_level~randomize_orbits_task_ptr
                            jsl task_manager_free_task
                            clearptr gameplay_level~randomize_orbits_task_ptr

                            pushptr gameplay_level~planetoid_swarm_task_ptr
                            jsl task_manager_free_task
                            clearptr gameplay_level~planetoid_swarm_task_ptr

                            restoredatabank

                            ret
                            end

; ----------------------------------------------------------------------------
gameplay_level_turn_deactivate start seg_gameplay

                            debugtag 'level_turn_deactivate'

                            jsl gameplay_sinistar_uninitialize
                            jsl gameplay_level_uninitialize                     ; uninitialize any tasks

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_level_turn_activate start seg_gameplay
                            using appdata
                            using gameplay_level_data
                            using gameplay_manager_data
                            using task_manager_data

                            debugtag 'level_turn_activate'

                            begin_locals
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            jsl gameplay_level_uninitialize                     ; uninitialize any tasks

; Are we starting a new level?
                            lda gameplay_manager~active_state+player_state~new_level
                            beq same_level
; Yes, apply the difficulty.
                            jsl gameplay_level_apply_difficulty                 ; Apply the difficulty for the current player, which includes setting up desired populations

same_level                  anop
                            pushdword #0                                        ; fake task data pointer, I know the function doesn't use it.
                            jsl gameplay_task_update_population                 ; force a population rebuild
; Set the tasks

                            pushsword #task_list_256_offset
                            pushptr #_task_update_difficulty
                            pushsword #0
                            jsl task_manager_create_task
                            putretptr gameplay_level~difficulty_task_ptr

                            pushsword #task_list_0_offset
                            pushptr #gameplay_task_update_population
                            pushsword #0
                            jsl task_manager_create_task
                            putretptr gameplay_level~population_task_ptr

;                           stz gameplay_level~population_task_call_count       ; debug
;                           stz gameplay_level~swarm_task_call_count            ; debug

                            pushsword #task_list_256_offset
                            pushptr #_task_randomize_orbits
                            pushsword #sizeof~task_control
                            jsl task_manager_create_task
                            putretptr gameplay_level~randomize_orbits_task_ptr

; Add the planetoid swarm task (HanSolo, from the original)

                            lda gameplay_manager~active_state+player_state~sinistars_killed
                            beq add_planetoid_swarms                             ; Always on the first level
                            and #$0003
                            beq no_planetoid_swarms                              ; Or every level except the Void Zone

add_planetoid_swarms         anop
                            pushsword #task_list_256_offset
                            pushptr #_task_planetoid_swarm
                            pushsword #sizeof~task_timer_header
                            jsl task_manager_create_task
                            putretptr gameplay_level~planetoid_swarm_task_ptr

no_planetoid_swarms          anop

; Clear this
                            stz gameplay_manager~active_state+player_state~new_level

                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Apply the difficulty, based on the current player's state
gameplay_level_apply_difficulty  start seg_gameplay
                            using gameplay_level_data
                            using gameplay_manager_data
                            using appdata

                            debugtag 'apply_difficulty'

                            begin_locals
wDifficulty                 decl word
wCount                      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Reset the difficulty timer and warrior aggression
                            stz gameplay_manager~active_state+player_state~difficulty_timer
                            stz gameplay_manager~active_state+player_state~warrior_aggression
; Demo?
                            lda gameplay_manager~demo_active
                            beq not_demo

; Set the difficulty table
                            lda #gameplay_level~demo_difficulty_update_table
                            sta gameplay_manager~active_state+player_state~difficulty_table_ptr
                            lda #^gameplay_level~demo_difficulty_update_table
                            sta gameplay_manager~active_state+player_state~difficulty_table_ptr+2

                            ldx #gameplay_level~demo_start_pop
                            bra copy_table

not_demo                    anop
; Check to see if Sinistar has been killed at least once. This is essentially a counter of what 'level' the player is on, since they kill Sinistar, once per level
                            lda gameplay_manager~active_state+player_state~sinistars_killed
                            bne has_killed_sinistar

; First time through the Void Zone, we go easy on the player

                            ldy gameplay_manager~active_starting_pop_table_adjust                        ; contains the easy/hard level for the pop/difficulty tables
                            lda gameplay_level~first_level_difficulty_tables,y
                            sta gameplay_manager~active_state+player_state~difficulty_table_ptr
                            lda #^gameplay_level~easy~0_difficulty_update_table  ; all in the same bank
                            sta gameplay_manager~active_state+player_state~difficulty_table_ptr+2

                            lda gameplay_level~first_level_pop_tables,y
                            tax                 ; a contains the short address of the pop table
                            bra copy_table

has_killed_sinistar         anop
                            and #3
                            shiftleft 1
                            tax

                            ldy gameplay_manager~active_starting_pop_table_adjust                       ; contains the easy/hard level for the pop/difficulty tables
                            lda gameplay_level~difficulty_adjust_tables,y
                            sta patch_difficulty_lookup+1                                               ; patch, so I can do short addressing with x
                            lda gameplay_level~pop_tables,y
                            sta patch_pop_lookup+1

patch_difficulty_lookup     lda gameplay_level~easy~difficulty_adjust_sptr_table,x                      ; patched to easy/hard table
                            sta gameplay_manager~active_state+player_state~difficulty_table_ptr
; Take the high address level 0 table, they are all in the same bank
                            lda #^gameplay_level~easy~0_difficulty_update_table
                            sta gameplay_manager~active_state+player_state~difficulty_table_ptr+2

patch_pop_lookup            lda gameplay_level~easy~pop_sptr_table,x                                    ; patched to easy/hard table
                            tax

; Expects X to have the short pointer to the source population table
copy_table                  ldy #0
loop                        getword {x},#0
                            sta gameplay_manager~active_state+player_state~desired_pop,y
                            inx
                            inx
                            iny
                            iny
                            cpy #sizeof~population_table
                            bne loop

                            lda gameplay_manager~active_state+player_state~sinistars_killed
                            beq no_kills

; The player has killed Sinistar at least once, so adjust the starting difficulty
; by (Sinistar Kills) mod (number of zones) * (difficulty_adjust*6)
                            lda #6                                      ; unsure why this magic number is what it is.
                            ldx gameplay_manager~active_difficulty_adjust ; this defaults to 5
                            jsl math~umul1r2
                            sta <wDifficulty                            ; This is how much to apply per-pass

                            lda #0
difficulty_adjust_loop      sta <wCount

                            pushdword gameplay_manager~active_state+player_state~difficulty_table_ptr
                            pushsword <wDifficulty
                            jsl gameplay_apply_list_change

                            lda <wCount
                            clc
                            adc #gameplay_level~zone_type_count         ; Advance by a full set of 'zones'
                            cmp gameplay_manager~active_state+player_state~sinistars_killed
                            blt difficulty_adjust_loop

no_kills                    anop
; Adjust the starting difficulty one more click
                            pushdword gameplay_manager~active_state+player_state~difficulty_table_ptr
                            pushsword gameplay_manager~active_difficulty_adjust
                            jsl gameplay_apply_list_change

; Set the 'zone color', which is the color that some of the UI bits are drawn in.
; Not really a difficulty thing, but this is where it was in the original.
; Maybe move it somewhere else?
                            lda gameplay_manager~active_state+player_state~sinistars_killed
                            bne not_first

                            lda #appdata~ui_color~blue~bits       ; first zone is blue
                            bra set_zone_color

not_first                   and #$0003
                            asl a
                            tax
                            lda gameplay_manager~zone_color_table,x
set_zone_color              sta gameplay_manager~active_state+player_state~zone_color

                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Updates the difficulty timer
_task_update_difficulty     private seg_gameplay
                            using gameplay_manager_data
                            using task_manager_data

                            debugtag 'update_difficulty'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            pushdword >gameplay_manager~active_state+player_state~difficulty_table_ptr
                            pushsword #1
                            jsl gameplay_apply_list_change

                            ret
                            end

; ----------------------------------------------------------------------------
; Checks the population of all the objects that could get destroyed and keeps
; them at pre-defined levels.
gameplay_task_update_population start seg_gameplay
                            using gameplay_level_data
                            using task_manager_data
                            using appdata

                            debugtag 'update_population'

                            begin_locals
wMaxCreate                  decl word
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

                            lda <pTaskData+2
                            beq initial_build                   ; If the task data is null, then this is a request to build the entire sector

total_entity_add_limit      equ 32
per_entity_add_limit        equ 16

                            lda #total_entity_add_limit
                            sta <wMaxCreate                     ; total amount to create

; Show the populate task 'heartbeat'
;gameplay_level~show_pop_task_pixels equ $e12000+160+150
;                            lda >gameplay_level~population_task_call_count      ; debug
;                            inc a
;                            sta >gameplay_level~population_task_call_count

;                            ldy #appdata~ui_color~yellow~bits
;                            bit #$0001
;                            beq even
;                            ldy #appdata~ui_color~red~bits
;even                        tya
;                            sta >gameplay_level~show_pop_task_pixels


                            pushsword #per_entity_add_limit     ; limit this entity create to this
                            pushsword #1                        ; at edge
                            jsl gameplay_workers_check_population
                            negate a
                            clc
                            adc <wMaxCreate                     ; see how many are remaining
                            beq exit
                            bmi exit
                            sta <wMaxCreate
                            cmp #per_entity_add_limit+1
                            blt ok1
                            lda #per_entity_add_limit
ok1                         pha
                            pushsword #1                        ; at edge
                            jsl gameplay_warriors_check_population
                            negate a
                            clc
                            adc <wMaxCreate                     ; see how many are remaining
                            beq exit
                            bmi exit
                            sta <wMaxCreate
                            cmp #per_entity_add_limit+1
                            blt ok2
                            lda #per_entity_add_limit
ok2                         pha
                            pushsword #1                        ; at edge
                            jsl gameplay_rocks_check_population

                            bra exit

initial_build               anop
                            pushsword #$7fff                    ; Max
                            pushsword #0                        ; Any location
                            jsl gameplay_workers_check_population
                            pushsword #$7fff                    ; Max
                            pushsword #0                        ; Any location
                            jsl gameplay_warriors_check_population
                            pushsword #$7fff                    ; Max
                            pushsword #0                        ; Any location
                            jsl gameplay_rocks_check_population

exit                        ret
                            end

; ----------------------------------------------------------------------------
; Randomizes the orbit points for the worker / warrior
; Really, the various missions like the worker 'tail' mission
; don't actually do a real orbit, they just pick a location tangent to the target
; to go to.  This flips if the tangent is to the 'right' or 'left'.
_task_randomize_orbits      private seg_gameplay
                            using gameplay_level_data
                            using task_manager_data
                            using gameplay_worker_logic_data
                            using gameplay_warrior_logic_data

                            debugtag '_task_randomize'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

; We have sleep points in this task, jump to our resume point
                            task_resume

begin                       jsl math~rnd_generate
                            and #1
                            bne one
                            dec a                   ; make -1
one                         anop
                            sta >gameplay_worker_orbit_multiplier
                            negate a
                            sta >gameplay_warrior_orbit_multiplier

                            task_sleep here,exit                    ; We are on the task256, so 256, 1/60 of a second, so 4.2 seconds for each sleep
                            task_sleep here,exit
                            task_sleep reset                        ; resume back at the top

exit                        ret
                            end

; ----------------------------------------------------------------------------
; This attempts to mimic Sinistar's Difficulty update function.
;
; The input is a list of pointers to a 16-bit value to adjust, with coefficient
; multipliers in between.  The input starts with a value to add to the
; first value pointed to in the list, which is considered the 'master'
; value.  The subsequent values in the list have their values updated by
; the change in value of the previous value, scaled by the coefficient.
; The 16-bit values are treated as fp16 style values, where the upper, integer part
; is the part that is evetually used by the external system.
;
; The master / slave construct in the update, is that slave items in the list
; have their coefficient multiplied with the delta change to the previous (master)
; item.  This also means that if the previous item did not change, the subsequent items
; will not change.
;
; The top-level, master value is always the 'difficulty timer', which usually starts at 0,
; and is incremented by 1.0.  Note that because the values are clamped to $7f when
; advancing forward (positive coefficient), when the difficulty timer's value reaches
; $7f, the list essentially stops updating.  At the normal difficulty update rate (256 task list)
; this means the list runs for about 9 minutes before it stops, assuming it starts at 0,
; though the list is usually primed with a value like 30, to seed the difficulty value.
;
; This has been coded so as to faithfully reproduce what the original was doing,
; however, it seems a little overly complicated, with its recursion and master/slave feedback.
; It isn't 100% clear what the 'goal' was, but maybe something simpler could be done.
; It certainly feels like it might be difficult to tune individual values.
;
; Parameters:
; pList     the list definition
; wChange   the change to add to the master of the list.  Only the lower byte is used.
;
gameplay_apply_list_change  start seg_gameplay
                            using gameplay_level_data

                            debugtag 'apply_list_change'

; The usage of A and B is to follow the 6809 A and B registers.  Note that A is the 'upper' byte and B is the 'lower'
                            begin_locals
wB                          decl byte
wA                          decl byte
wPad1                       decl byte                   ; pad, so I can store 16-bits to wA
pValue                      decl ptr
work_area_size              end_locals

                            sub (4:pList,2:wChange),work_area_size

                            stz <wB
                            stz <wPad1

; The raise and lower function, assume that the input is pointing at the 'previous' entries coefficient
; but since the first one, doesn't have one, just go backward by 2.
                            dec <pList
                            dec <pList

                            lda <wChange
                            bpl do_raise
                            and #$00ff                  ; only using the lower 8-bits
                            sta <wA
                            jsr lower
                            ret

do_raise                    anop
                            and #$00ff                  ; only using the lower 8-bits
                            sta <wA
                            jsr raise
                            ret

; The input is positive, raise the value, clamping at $7f
raise                       anop
                            longm
                            pushdword <pList
                            inc <pList
                            inc <pList
                            getptr [<pList],#0,<pValue              ; get the address of the 'value'
                            shortm
raise_restart               anop
; Note, we are in 8-bit accumulator mode in this section!
                            lda <wB
                            clc
                            adc [<pValue]                           ; add B to the lower-byte of the value
                            sta [<pValue]                           ; store it back
                            sta <wB                                 ; might not need to store this
                            lda <wA                                 ; get A
                            adc #0                                  ; add in any carry from the fractional part
                            sta <wA                                 ; save, in case we exit
                            beq raise_done                          ; anything to add?
                            pea $0000                               ; save the change in the 'high' byte for later
                            sta 1,s                                 ; I want it to be a 16-bit value, so pea $0000, then fill in the low-byte
                            clc
                            ldy #1
                            adc [<pValue],y                         ; add to the 'high' byte of the value
; The original code, did a signed compare with the existing value, but I think it is really just wanting to know if the value wrapped
; so we will do that.  The problem is, we can't really effectively do signed compares when wrapping.  It just doesn't work because
; the cmp doesn't set the overflow flag, and we'd have to do a test on N and V to be completely correct.
; The signed-compare-branch macros I have are really cheating and expecting the values to be within a certain signed delta.
;                            cmp [<pValue],y
;                            bsge raise_no_clip
                            bvc raise_no_clip
; We wrapped around, make A and B what it will take to go to the maximum amount.
;
; The original, put $ff in B, but that can end up causing a carry, that will cause A to overflow again
; It will eventually clear itself, as B goes down to 0.
;                            lda #$ff
;                            sta <wB
                            stz <wB                                 ; set to 0, so we don't overflow B.  Could also set B to $ff - [<pValue]
                            lda #$7f
                            sec
                            sbc [<pValue],y
                            sta <wA
                            pla                                     ; pop off the saved change value
                            pla
                            bra raise_restart
raise_no_clip               anop
                            sta [<pValue],y                         ; store the new 'high' byte
                            longm
; Skip the value address, and point to the coefficient for the next value
                            lda <pList
                            clc
                            adc #4
                            sta <pList

raise_coefficient_loop      anop
; coefficient x the last 'high' byte change
                            lda 1,s                                 ; the last change value, always positive
                            tax
                            lda [<pList]
                            beq raise_coeff_zero                    ; end of list?
                            bpl raise_slave_positive
; Negative
                            and #$00ff                              ; have to make sure the upper bits are not set.
                            jsl math~umul1r2
                            sta <wB
                            xba                                     ; put the upper into the lower
                            shortm
                            sec
                            sbc 1,s                                 ; the last change value
                            sta <wA
                            longm
                            asl <wB                                 ; multiply the whole thing by 2

                            jsr lower

                            lda <pList                              ; advance the the next entry's coefficient
                            clc
                            adc #6
                            sta <pList
                            bra raise_coefficient_loop

raise_slave_positive        anop
                            jsl math~umul1r2
                            asl a                                   ; multuiply by 2
                            sta <wB                                 ; Sets wA and wB

                            jsr raise

                            lda <pList
                            clc
                            adc #6
                            sta <pList
                            bra raise_coefficient_loop

raise_done                  anop
                            longm                  ; make sure this is on
; Restore the saved list pointer
                            pla
                            sta <pList
                            pla
                            sta <pList+2
                            rts

raise_coeff_zero            anop
; Coming here, we have hit the end of the list.
                            longm
                            pla                             ; remove the saved delta value
; Restore the saved list pointer
                            pla
                            sta <pList
                            pla
                            sta <pList+2
                            rts

; The input is negative, lower the value toward $80
lower                       anop
                            longm
                            pushdword <pList
                            inc <pList
                            inc <pList
                            getptr [<pList],#0,<pValue
                            shortm
lower_restart               anop
                            lda <wB
                            clc
                            adc [<pValue]
                            sta [<pValue]
                            sta <wB
                            lda <wA
                            adc #0
                            sta <wA                                 ; save, in case we exit
                            beq lower_done
                            pea $0000                               ; save the change in the 'high' byte for later
                            sta 1,s                                 ; I want it to be a 16-bit value, so pea $0000, then fill in the low-byte
                            clc
                            ldy #1
                            adc [<pValue],y
;                           cmp [<pValue],y
;                           bsle lower_no_clip
                            bvc lower_no_clip
                            stz <wB
                            lda #$80
                            sec
                            sbc [<pValue],y
                            sta <wA
                            bra lower_restart
lower_no_clip               anop
                            sta [<pValue],y
                            longm
; Skip the value address, and point to the coefficient for the next value
                            lda <pList
                            clc
                            adc #4
                            sta <pList
lower_coefficient_loop      anop
                            lda 1,s                         ; the last change value, always negative
                            tax
                            lda [<pList]
                            beq lower_coeff_zero
                            bpl lower_slave_positive
; Negative
                            and #$00ff                      ; have to make sure the upper bits are not set.
                            jsl math~umul1r2
                            sta <wB
                            xba                             ; move the upper into the lower
                            shortm
                            sec
                            sbc 1,x                         ; the last change value
                            sec
                            sbc [<pList]
                            sta <wA
                            longm
                            asl <wB

                            jsr raise

                            lda <pList
                            clc
                            adc #6
                            sta <pList
                            bra lower_coefficient_loop

lower_slave_positive        anop
                            jsl math~umul1r2
                            sta <wB
                            xba
                            shortm
                            sec
                            sbc [<pList]
                            sta <wA
                            longm
                            asl <wB

                            jsr lower

                            lda <pList
                            clc
                            adc #6
                            sta <pList
                            bra lower_coefficient_loop

lower_done                  anop
                            longm                   ; make sure this is on
; Restore the saved list pointer
                            pla
                            sta <pList
                            pla
                            sta <pList+2
                            rts

lower_coeff_zero            anop
; Coming here, we have hit the end of the list.
                            longm
                            pla                     ; remove the last change value
; Restore the saved list pointer
                            pla
                            sta <pList
                            pla
                            sta <pList+2
                            rts
                            end

; ----------------------------------------------------------------------------
; Generate an 'planetoid swarm' occasionally.
; This was called the 'HanSolo' task in the original
_task_planetoid_swarm       private seg_gameplay
                            using applib_data

                            using gameplay_level_data
                            using task_manager_data
                            using gameplay_manager_data
                            using gameplay_ui_data
                            using gameplay_sound_data

                            debugtag '_planetoid_swarm'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size

; This will adjust the population of the two smaller planetoids (3 and 4)

; Note, this value is from the original, however, looking at the code (HanSolo), the value it checks and reads might be a bug.
; it is doing a cmpa 20, i.e. the memory location $0020, not #20, which I think they meant.  Looking at the code in MAME, there
;  is a $0A at location $0020.
swarm_upper_limit           equ 10|8
swarm_lower_limit           equ 2|8
swarm_probability           equ 16                          ; Task is running about every 4 seconds, then we do a 1-in-16 roll to see if we start one.
swarm_cooldown              equ +(60*30)/256                ; Once we do a swarm, have a cooldown period, before we try again.  Helps with the crappy rnd generator we have.

; Show the populate task 'heartbeat'
;show_task_pixels            equ $e12000+160+150
;                            lda >gameplay_level~swarm_task_call_count      ; debug
;                            inc a
;                            sta >gameplay_level~swarm_task_call_count

;                            ldy #appdata~ui_color~yellow~bits
;                            bit #$0001
;                            beq even
;                            ldy #appdata~ui_color~red~bits
;even                        tya
;                            sta >show_task_pixels
; Check the timer
                            getword [<pTaskData],#task_timer_header~timer
                            beq no_timer
                            dec a
                            putword [<pTaskData],#same
                            bne exit

no_timer                    lda >gameplay_manager~active_state+player_state~desired_pop~planetoids3
                            cmp #swarm_upper_limit
                            blt check_swarm
; We are at the swarm limit, reduce it back down.
                            lda #swarm_lower_limit
                            sta >gameplay_manager~active_state+player_state~desired_pop~planetoids3
                            sta >gameplay_manager~active_state+player_state~desired_pop~planetoids4

; Wait a bit before trying to do another swarm
                            lda #swarm_cooldown
                            putword [<pTaskData],#task_timer_header~timer

                            bra exit

check_swarm                 jsl math~rnd_generate
                            and #$ff
                            cmp #swarm_probability
                            bge exit

                            lda #swarm_upper_limit
                            sta >gameplay_manager~active_state+player_state~desired_pop~planetoids3
                            sta >gameplay_manager~active_state+player_state~desired_pop~planetoids4

; Force an update of the rocks right now.
                            pushsword #swarm_upper_limit
                            pushsword #1
                            jsl gameplay_rocks_check_population

; Play the message tune
                            pushsword #id_sfx~message
                            jsl sndlib_play_sfx

                            lda #gameplay_ui~message_planetoid_swarm
                            jsl gameplay_ui_set_active_player_message

exit                        ret
                            end

