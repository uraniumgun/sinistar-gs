
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
                                copy source/sinistar.entity.definitions.asm
                                copy source/gameplay.constants.asm

                                mcopy generated/sinistar.entity.manager.macros

                                longa on
                                longi on

; Manager for all the 'sinistar' entities

; --------------------------------------------------------------------------------------------
sinistar_entity_manager_data    data seg_entity

global_sinistar_entity_manager_is_initialized dc i'0'

; There will only be one sinistar.  Might want to change the code to optimize for that?
; Note, Sinistar is made up of 'child' entities, however, they are not in this list.
; The parent entity manages the lifetime of the child entities.
max_sinistar_entity_count       equ 1
sinistar_entity_count           dc i'0'
sinistar_entity_array           ds max_sinistar_entity_count*2

sinistar_entity_next_remove_index dc i'0'
sinistar_entity_remove_count      dc i'0'
sinistar_entity_remove_array      ds max_sinistar_entity_count*2

                                end

; --------------------------------------------------------------------------------------------
; Initialize the global sinistar entity manager.
; This will allocate the global_sinistar_entity_manager object and make it ready for use.
; It will allocate a pool for managing entity instances.
;
; Note that this manager provides the fixed buffer object for the entities, however the allocation
; and deallocation is done in the playfield.entity.asm file, using sinistar_entity_new and sinistar_entity_delete
;
sinistar_entity_manager_initialize start seg_entity
                                using sinistar_entity_manager_data

                                debugtag 'initialize'
                                debugtag 'sinistar_entity_manager'

                                lda >global_sinistar_entity_manager_is_initialized
                                bne is_initialized

                                jsl sinistar_entity_preload_images

                                lda #1
                                sta >global_sinistar_entity_manager_is_initialized

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
sinistar_entity_manager_uninitialize start seg_entity
                                using sinistar_entity_manager_data

                                debugtag 'uninitialize'
                                debugtag 'sinistar_entity_manager'

                                lda >global_sinistar_entity_manager_is_initialized
                                beq exit

                                jsl sinistar_entity_manager_remove_all

                                lda #0
                                sta >global_sinistar_entity_manager_is_initialized

exit                            anop
                                rtl

                                end

; ----------------------------------------------------------------------------
; Remove all sinistars
sinistar_entity_manager_remove_all start seg_entity
                                using appdata
                                using sinistar_entity_data
                                using sinistar_entity_manager_data
                                using task_manager_data
                                using gameplay_level_data

                                debugtag 'remove_all'

                                begin_locals
spEntity                        decl word
work_area_size                  end_locals

                                sub ,work_area_size

                                setlocaldatabank
; Delete all the allocated sinistars
                                lda sinistar_entity_count
                                beq none
                                dec a
                                asl a
                                tax

loop                            phx

                                lda sinistar_entity_array,x
                                sta <spEntity
                                tax
; Remove from playfield

                                jsl sinistar_entity_remove_from_playfield
; Delete
                                ldx <spEntity
                                jsl sinistar_entity_delete
                                plx
                                dex
                                dex
                                bpl loop

done                            anop
                                stz sinistar_entity_count

none                            anop
                                restoredatabank
                                ret
                                end

; ----------------------------------------------------------------------------
; Add a sinistar to the playfield
; Parameters:
; wX        x location
; wY        y location
sinistar_entity_manager_add_sinistar start seg_entity
                            using appdata
                            using sinistar_entity_data
                            using sinistar_entity_manager_data
                            using gameplay_level_data
                            using task_manager_data

                            debugtag 'sinistar_add'

                            begin_locals
spEntity                    decl word
pTaskData                   decl ptr
wSlotIndex                  decl word
work_area_size              end_locals

                            sub (2:wX,2:wY),work_area_size

                            setlocaldatabank
;                            brl too_many                        ; Disable

                            lda sinistar_entity_count
                            cmp #max_sinistar_entity_count
                            jge too_many
                            asl a
                            sta <wSlotIndex

                            jsl sinistar_entity_new
                            bcs error

                            inc sinistar_entity_count
                            sta <spEntity

; Save the slot-index x2 in the entity
                            tax
                            lda <wSlotIndex
                            putword {x},>entities_root+playfield_entity~manager_slot_index
; Store in the slot
                            tay
                            txa
                            sta sinistar_entity_array,y

                            lda #0
                            sta sinistar_entity~on_screen

                            lda <wX
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                            lda <wY
                            putword {x},>entities_root+playfield_entity~grentity+grlib_entity~y

                            inline_entity_add_to_playfield {>x}

; Set a random direction
                            generate_rnd16
                            and #playfield_entity~direction_range_mask

                            putword {x},>entities_root+playfield_entity~direction
                            putword {x},>entities_root+playfield_entity~desired_direction

                            pushptrhigh #entities_root
                            pushsword <spEntity
                            jsl gameplay_sinistar_initialize_logic

too_many                    anop
error                       anop
                            restoredatabank

                            ret
                            end

; ----------------------------------------------------------------------------
; This updates the animation of all, on screen sinistars.
gameplay_all_sinistars_update_tick start seg_entity
                            using appdata
                            using sinistar_entity_data
                            using sinistar_entity_manager_data
                            using gameplay_sinistar_logic_data
                            using gameplay_level_data
                            using applib_data

                            debugtag 'sinistars_update_tick'

                            begin_locals
spEntity                    decl word
wLastEntitySlot             decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

; Loop over the sinistars, backward.
; Note, there are only primary entities in this list, i.e. no 'child pieces'
                            lda sinistar_entity_count
                            jeq done_update
                            dec a
                            asl a
                            tax

loop                        phx

; Only need the short pointer in this loop
                            lda sinistar_entity_array,x
                            sta <spEntity
                            tax

; Is this set to be removed?
                            getword {x},>entities_root+playfield_entity~state_flags
                            jmi on_removal_list
; On screen or off?
                            ldy sinistar_entity~on_screen                   ; We have to check this flag, because the root piece might not be on screen.
;                           bit #playfield_entity~state_on_collision_list
                            beq offscreen
; On screen
; Decrement the bounce counter
                            bit #playfield_entity~state_bounce_bits
                            beq no_bounce_bits                          ; already 0?
                            dec a                                       ; we know they are the lower bits, so we can just dec
                            putword {x},>entities_root+playfield_entity~state_flags
no_bounce_bits              anop

                            jsl playfield_entity_update_direction       ; will not change x
                            jsl playfield_entity_update_position        ; will not change x
                            bra just_draw

; Offscreen
offscreen                   lda >gameplay_sinistar_logic~in_sector
                            bne in_sector
; Out of sector, use a custom function
                            jsl gameplay_sinistar_update_position_oos   ; will not change x
                            bra just_draw

in_sector                   jsl playfield_entity_update_position_offscreen ; will not change x

just_draw                   anop
; Update the framelib values
                            getword {x},>entities_root+grlib_entity~changed
                            beq no_framelib_update

                            setdatabanktolabel entities_root
                            jsl grlib_entity_update_framelib
                            restoredatabank
; Invalidate
                            ldx <spEntity
no_framelib_update          anop

; If we need an erase, are to be removed, or is on screen, then do a full invalidate, else
; just do a quick, "are we on screen" check
; This is different from the other entities, in that Sinistar is made of of sub-entities, and the root entity
; isn't visible.  We can just use a fixed size of what all the pieces would be to test
                            lda sinistar_entity~on_screen
                            bne full_check
; The root piece is invisible, can't check this
;                            getword {x},>entities_root+sprite~info
;                            bmi full_check          ; erase?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_on_collision_list+playfield_entity~state_marked_for_removal ; on-screen or to-be-removed?
                            bne full_check
; Off screen and we don't have anything to add to the update rects, do a quick check
; The coordinates of the object are in world space, compare in view space.
                            getword {x},>entities_root+grlib_entity~x
                            clc
                            sbc #sinistar_total_x_offset
                            cmp #gameplay_ui_playfield_width-gameplay_ui_playfield_center_x
                            bsge clipped

                            clc
                            adc #sinistar_total_width
                            cmp #-gameplay_ui_playfield_center_x
                            bslt clipped

                            getword {x},>entities_root+grlib_entity~y
                            sec
                            sbc #sinistar_total_y_offset
                            cmp #gameplay_ui_playfield_height-gameplay_ui_playfield_center_y
                            bsge clipped

                            clc
                            adc #sinistar_total_height
                            cmp #-gameplay_ui_playfield_center_y
                            bslt clipped

full_check                  anop
                            jsl playfield_entity_invalidate_hierarchy             ; Use special invalidate, that handles an entity that has multiple parts

; Track a global on/off screen flag, since Sinistar is made up of parts
                            ldx #$ffff
                            bcc on_screen
                            inx
on_screen                   stx sinistar_entity~on_screen
                            bra not_cliped

clipped                     stz sinistar_entity~on_screen

not_cliped                  anop
on_removal_list             anop
                            plx
                            beq done_update
                            dex
                            dex
                            jmp loop

done_update                 anop

; Do any removals
                            lda sinistar_entity_remove_count
                            beq done_remove
                            dec a
                            asl a
                            tax

loop_remove                 phx

; We will need to know the last slot index
                            lda sinistar_entity_count
                            dec a
                            asl a
                            sta <wLastEntitySlot

                            lda sinistar_entity_remove_array,x
                            sta <spEntity
                            tax

                            getword {x},>entities_root+playfield_entity~state_flags
                            bit #playfield_entity~state_removed_from_screen
                            bne already_removed_from_screen

                            jsl playfield_entity_invalidate_hierarchy             ; Use special invalidate, that handles an entity that has multiple parts
                            ldx <spEntity

already_removed_from_screen anop
; Get the slot we are in
                            getword {x},>entities_root+playfield_entity~manager_slot_index
                            pha                                 ; save it

                            jsl sinistar_entity_remove_from_playfield

                            ldx <spEntity
                            jsl sinistar_entity_delete            ; do the delete

                            ply                                 ; get the slot index back
                            cpy <wLastEntitySlot
                            beq is_last_slot                    ; last slot?
; Move the last, into the vacated slot
                            ldx <wLastEntitySlot
                            lda sinistar_entity_array,x
                            sta sinistar_entity_array,y
                            stz sinistar_entity_array,x
; Update the moved entity's slot index
                            tax
                            tya
                            putword {x},>entities_root+playfield_entity~manager_slot_index
is_last_slot                dec sinistar_entity_count

                            plx
                            dex
                            dex
                            bpl loop_remove

done_remove                 anop
                            stz sinistar_entity_remove_count
                            stz sinistar_entity_next_remove_index

                            restoredatabank

                            ret
                            end
