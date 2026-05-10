                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/fixed.buffer.pool.definitions.asm
                                copy lib/source/grlib.definitions.asm
                                copy lib/source/grlib.sprite.definitions.asm
                                copy lib/source/framelib.definitions.asm
                                copy lib/source/grlib.entity.definitions.asm

                                copy source/app.system.ids.asm
                                copy source/playfield.entity.definitions.asm
                                copy source/rock.entity.definitions.asm
                                copy source/gameplay.constants.asm

                                mcopy generated/rock.entity.manager.macros

                                longa on
                                longi on

; Manager for all the 'rock' entities

; --------------------------------------------------------------------------------------------
rock_entity_manager_data        data seg_entity

; Entity Manager object
rock_entity_manager~pool   gequ 0
sizeof~rock_entity_manager gequ rock_entity_manager~pool+sizeof~fixed_buffer_pool

global_rock_entity_manager_is_initialized dc i'0'

; The global entity manager
global_rock_entity_manager ds sizeof~rock_entity_manager

; Count for each variation type
rock_entity_variation_count ds rock_entity~variation_max*2

max_rock_entity_count       equ 32
rock_entity_count           dc i'0'
rock_entity_array           ds max_rock_entity_count*2              ; just storing the lower word

; The rocks that are in the remove queue
rock_entity_next_remove_index   dc i'0'
rock_entity_remove_count        dc i'0'
rock_entity_remove_array        ds max_rock_entity_count*2

; The rocks that are in the recycled queue
max_rock_entity_recycled_count equ 8
rock_entity_recycled_count      dc i'0'
rock_entity_recycled_array      ds max_rock_entity_recycled_count*2
                                end

; --------------------------------------------------------------------------------------------
; Initialize the global rock entity manager.
; This will allocate the global_rock_entity_manager object and make it ready for use.
; It will allocate a pool for managing entity instances.
;
; Note that this manager provides the fixed buffer object for the entities, however the allocation
; and deallocation is done in the playfield.entity.asm file, using rock_entity_new and rock_entity_delete
;
rock_entity_manager_initialize  start seg_entity
                                using rock_entity_manager_data

                                debugtag 'initialize'
                                debugtag 'rock_entity_manager'

                                setlocaldatabank
                                lda global_rock_entity_manager_is_initialized
                                bne is_initialized

                                jsl rock_entity_preload_images

                                stz rock_entity_count
                                stz rock_entity_remove_count
                                stz rock_entity_next_remove_index
                                stz rock_entity_recycled_count

; Clear the variation counts too
                                ldx #rock_entity~variation_max-2
variation_loop                  stz rock_entity_variation_count,x
                                dex
                                dex
                                bpl variation_loop


                                lda #1
                                sta global_rock_entity_manager_is_initialized

is_initialized                  anop
                                restoredatabank
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
rock_entity_manager_uninitialize start seg_entity
                                using rock_entity_manager_data

                                debugtag 'uninitialize'
                                debugtag 'rock_entity_manager'

                                lda >global_rock_entity_manager_is_initialized
                                beq exit

                                jsl rock_entity_manager_remove_all

                                lda #0
                                sta >global_rock_entity_manager_is_initialized

exit                            anop
                                rtl

                                end

; ----------------------------------------------------------------------------
; Add a rock to the playfield
; Parameters:
; wX            - x location
; wY            - y location
; wVariation    - the variation to use.  0 to rock_entity~variation_max-1
rock_entity_manager_add_rock start seg_entity
                            using appdata
                            using rock_entity_data
                            using rock_entity_manager_data
                            using gameplay_level_data
                            using gameplay_manager_data

                            debugtag 'rock_add'

                            begin_locals
spEntity                    decl word
wSlotIndex                  decl word
work_area_size              end_locals

                            sub (2:wX,2:wY,2:wVariation),work_area_size

                            setlocaldatabank
;                            brl too_many                        ; Disable

                            lda rock_entity_count
                            cmp #max_rock_entity_count
                            jge too_many
                            asl a
                            sta <wSlotIndex

                            lda <wVariation
                            cmp #rock_entity~variation_max
                            blt ok_variation
                            assert_brk
                            stz <wVariation

ok_variation                anop
                            lda rock_entity_recycled_count
                            beq add_new
                            dec a
                            sta rock_entity_recycled_count
                            asl a
                            tay
                            lda rock_entity_recycled_array,y
                            pha
                            pushsword <wVariation
                            jsl rock_entity_reuse
                            bra reused
add_new                     pushsword <wVariation
                            jsl rock_entity_new
                            bcs error

reused                      inc rock_entity_count
                            sta <spEntity                           ; only need the lower word

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta rock_entity_array,y

; Track how many of each type we made
                            lda <wVariation
                            asl a
                            tax
                            lda rock_entity_variation_count,x
                            inc a
                            sta rock_entity_variation_count,x

                            ldx <spEntity
                            jsl gameplay_rock_initialize

                            ldx <spEntity
                            lda <wX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

; Set a random direction, and drift
                            generate_rnd16
                            and #playfield_entity~direction_range_mask

                            tay                     ; Save the direction
                            putword {x},>entities_root+playfield_entity~direction
                            putword {x},>entities_root+playfield_entity~desired_direction

                            pushsword <spEntity
                            phy                     ; push the direction

; If profiling, don't set any motion
                            aif C:debug~use_profile_state=0,.skip
                            lda >gameplay_manager~static_profile
                            bpl not_profile
                            pushsword #0
                            bra is_profile
not_profile                 anop
.skip

; Pick a speed from speed~0, to speed~0_75
                            get_quick_rnd16
                            and #$0003
                            pha

is_profile                  jsl playfield_entity_set_speed

too_many                    anop
error                       anop
                            restoredatabank

                            ret
                            end

; ----------------------------------------------------------------------------
rock_entity_manager_remove_all start seg_entity
                            using rock_entity_data
                            using rock_entity_manager_data
                            using gameplay_level_data

                            debugtag 'remove_all'

                            begin_locals
spEntity                    decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Delete all the allocated rocks
                            lda rock_entity_count
                            beq no_active
                            dec a
                            asl a
                            tax

active_loop                 phx

                            lda rock_entity_array,x
                            sta <spEntity
                            tax
; Remove from playfield
                            jsl rock_entity_remove_from_playfield
; Delete
                            ldx <spEntity
                            jsl rock_entity_delete
                            plx
                            beq active_done
                            dex
                            dex
                            bra active_loop

active_done                 anop
no_active                   anop

; Delete all the suspended rocks
                            lda rock_entity_recycled_count
                            beq no_recycled
                            dec a
                            asl a
                            tax

recycled_loop               phx

                            lda rock_entity_recycled_array,x
                            tax
                            jsl rock_entity_delete_suspended            ; must call the special suspended delete.
                            plx
                            beq recycled_done
                            dex
                            dex
                            bra recycled_loop

recycled_done               anop
no_recycled                 anop
                            stz rock_entity_count
                            stz rock_entity_remove_count
                            stz rock_entity_next_remove_index
                            stz rock_entity_recycled_count

; Clear the variations
                            ldx #rock_entity~variation_max-2
variation_loop              stz rock_entity_variation_count,x
                            dex
                            dex
                            bpl variation_loop

                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
gameplay_all_rocks_update_tick start seg_entity
                            using appdata
                            using rock_entity_data
                            using rock_entity_manager_data
                            using gameplay_rock_logic_data
                            using gameplay_level_data
                            using applib_data

                            debugtag 'rock_logic_tick'

                            begin_locals
spEntity                    decl word
wLastEntitySlot             decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Loop over the rocks, backward.
                            lda rock_entity_count
                            jeq done_update
                            dec a
                            asl a
                            tax

loop                        phx

; Don't need the high-word in this loop
                            lda rock_entity_array,x
                            tax

; Is this set to be removed?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi on_removal_list

; On screen or off?
                            bit #playfield_entity~state_on_collision_list
                            beq offscreen
; On screen
; Decrement the bounce counter
                            bit #playfield_entity~state_bounce_bits
                            beq no_bounce_bits                          ; already 0?
                            dec a                                       ; we know they are the lower bits, so we can just dec
                            putword {x},>entities_root+playfield_entity~state_flags
no_bounce_bits              anop

; Not checking the first-update flag for this type.
; The first_update flag is primarily so that we don't miss the first frame of animation for entities,
; especially entities that are created 'on-screen'

                            jsl playfield_entity_update_position                    ; will not change x
                            bra just_draw

offscreen                   jsl playfield_entity_update_position_offscreen          ; will not change x

just_draw                   anop
; Invalidate
; If we need an erase, are to be removed, or is on screen, then do a full invalidate, else
; just do a quick, "are we on screen" check
                            getword {x},>entities_root+sprite~info
                            bmi full_check          ; erase?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list+playfield_entity~state_marked_for_removal ; on-screen or to-be-removed?
                            bne full_check

; Off screen and we don't have anything to add to the update rects, do a quick check
; The coordinates of the object are in world space, compare in view space.
                            getword {x},>entities_root+grlib_entity~x
                            sec
                            sbcword {x},>entities_root+sprite~offset_x
                            cmp #gameplay_ui_playfield_width-gameplay_ui_playfield_center_x
                            bsge clipped

                            clc
                            adcword {x},>entities_root+sprite~width
                            cmp #-gameplay_ui_playfield_center_x
                            bslt clipped

                            getword {x},>entities_root+grlib_entity~y
                            sec
                            sbcword {x},>entities_root+sprite~offset_y
                            cmp #gameplay_ui_playfield_height-gameplay_ui_playfield_center_y
                            bsge clipped

                            clc
                            adcword {x},>entities_root+sprite~height
                            cmp #-gameplay_ui_playfield_center_y
                            bslt clipped

full_check                  anop
; Not clipped, we must be going on-screen
                            jsl playfield_entity_invalidate_sprite

clipped                     anop
on_removal_list             anop

                            plx
                            dex
                            dex
                            bpl loop

done_update                 anop

; Do any removals
                            lda rock_entity_remove_count
                            jeq done_remove
                            dec a
                            asl a
                            tax

loop_remove                 phx

; We will need to know the last slot index
                            lda rock_entity_count
                            dec a
                            asl a
                            sta <wLastEntitySlot

                            lda rock_entity_remove_array,x
                            sta <spEntity
                            tax

                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_removed_from_screen
                            bne already_removed_from_screen

                            jsl playfield_entity_invalidate_sprite
                            ldx <spEntity

already_removed_from_screen anop
; Get the slot we are in
                            getword {x},>entities_root+playfield_entity~manager_slot_index
                            pha                                 ; save it

                            jsl rock_entity_remove_from_playfield
                            ldx <spEntity
                            lda rock_entity_recycled_count
                            cmp #max_rock_entity_recycled_count
                            bge delete_it
; Add the entity to the recycled list
                            asl a
                            tay
                            txa
                            sta rock_entity_recycled_array,y
                            jsl rock_entity_suspend
                            inc rock_entity_recycled_count
                            bra was_recycled
; Delete the entity
delete_it                   jsl rock_entity_delete
was_recycled                ply                                 ; get the slot index back
                            cpy <wLastEntitySlot
                            beq is_last_slot                    ; last slot?
; Move the last, into the vacated slot
                            ldx <wLastEntitySlot
                            lda rock_entity_array,x
                            sta rock_entity_array,y
                            stz rock_entity_array,x
; Update the moved entity's slot index
                            tax
                            tya
                            putword {x},>entities_root+playfield_entity~manager_slot_index
is_last_slot                dec rock_entity_count

                            plx
                            dex
                            dex
                            bpl loop_remove

done_remove                 anop
                            stz rock_entity_remove_count
                            stz rock_entity_next_remove_index

                            restoredatabank

                            ret
                            end

