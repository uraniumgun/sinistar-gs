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
                            copy source/explosion.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/gameplay.player.definitions.asm

                            mcopy generated/gameplay.explosion.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the rocks.

; ----------------------------------------------------------------------------

gameplay_explosion_logic_data    data seg_gameplay

gameplay_explosion_task_data            equ sizeof~task_control                 ; Starting with support for sleep commands
gameplay_explosion_task_data~entity_ptr equ gameplay_explosion_task_data        ; Pointer to the entity
sizeof~gameplay_explosion_task_data     equ gameplay_explosion_task_data~entity_ptr+4

                            end

; ----------------------------------------------------------------------------
; Initialize the rocks for gameplay, this is pre-state activation
gameplay_explosions_initialize  start seg_gameplay

                            debugtag 'explosions_initialize'

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_explosions_uninitialize start seg_gameplay
                            using gameplay_explosion_logic_data
                            using gameplay_level_data

                            debugtag 'explosions_uninitialize'

                            jsl explosion_entity_manager_turn_deactivate

                            rtl
                            end

; ----------------------------------------------------------------------------
; Deactivate the turn
gameplay_explosions_turn_deactivate start seg_gameplay
                            using explosion_entity_manager_data

                            debugtag 'explosions_turn_deactivate'

                            jsl explosion_entity_manager_turn_deactivate

                            rtl
                            end

