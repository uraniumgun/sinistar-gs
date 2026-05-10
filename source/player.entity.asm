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

                            copy source/app.system.ids.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm
                            copy source/collision.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm

                            mcopy generated/player.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
player_entity_data          data seg_entity
                            using gameplay_caller_logic_data

player_entity_image_collection_id equ '1HSP'

player_entity_is_instanced  dc i'0'

; Preloaded images
preloaded~player_framelib   ds sizeof~framelib_entity

; Note the player_entity_instance is in the shared entity global data pool.
                            end

; -----------------------------------------------------------------------------
; Preload images the player entity uses
; Returns:
; carry clear, if successful
player_entity_preload_images start seg_entity
                            using player_entity_data

                            debugtag 'preload_images'
; Pre-load images
                            pushptr #preloaded~player_framelib
                            pushdword #player_entity_image_collection_id
                            jsl playfield_preload_framelib_collection

                            rtl

                            end

; -----------------------------------------------------------------------------
; Parameters:
; x-reg             - the entity short pointer
player_entity_construct     start seg_entity
                            using player_entity_data
                            using gameplay_entity_data

                            debugtag 'construct'
                            debugtag 'player_entity'

                            begin_locals
spThis                      decl word
work_area_size              end_locals

                            sub ,work_area_size

                            stx <spThis
                            txy
                            jsl playfield_entity_construct
                            bcs failed

                            lda #entity_type~player
                            ldx <spThis
                            putword {x},>entities_root+playfield_entity~type

; This is kinda 'gameplay' setup, maybe call into a custom function?  Adds overhead though..  Stupid slow processor.

; Set the characteristic id
                            lda #id_characteristic_player
                            putword {x},>entities_root+playfield_entity~characteristic_id

                            clc
exit                        anop
                            retkc

failed                      lda #system_id_player_entity_manager+app_error_allocation_failed
                            jsl appdebug_set_last_error
                            bra exit

                            end

; -----------------------------------------------------------------------------
player_entity_destruct      private seg_entity

                            debugtag 'destruct'
                            debugtag 'player_entity'

                            begin_locals
work_area_size              end_locals

                            lsub (4:pThis),work_area_size

                            ldy <pThis
                            jsl playfield_entity_destruct

                            lret

                            end

; -----------------------------------------------------------------------------
; Initialize the player entity.  There is only going to be one of these (right?)
player_entity_initialize    start seg_entity
                            using player_entity_data

                            debugtag 'initialize'
                            debugtag 'player_entity'

                            begin_locals
pEntity                     decl ptr
wRandom                     decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank
                            getword player_entity_is_instanced
                            bne failed

; Construct the player entity in a global
                            ldx #player_entity_instance
                            jsl player_entity_construct
                            bcs failed

                            inc player_entity_is_instanced
                            pushsword #player_entity_instance
                            pushptr #preloaded~player_framelib                      ; use the preloaded framelib
                            pushsword #framelib_set_id_walk
                            pushsword #0
                            jsl playfield_entity_set_collection_from_preload

failed                      anop
                            restoredatabank
                            ret

                            end

; -----------------------------------------------------------------------------
; Uninitialize the player entity.
player_entity_uninitialize  start seg_entity
                            using player_entity_data

                            debugtag 'uninitialize'
                            debugtag 'player_entity'

                            setlocaldatabank
                            lda player_entity_is_instanced
                            beq not_instanced

                            ldy #player_entity_instance
;                           jsr player_entity_destruct
                            jsl playfield_entity_destruct

                            stz player_entity_is_instanced

not_instanced               anop
                            restoredatabank
                            rtl
                            end

                            ago .skip
; -----------------------------------------------------------------------------
; Add the player entity to the playfield
; Deprecated, use inline_entity_add_to_playfield
player_entity_add_to_playfield start seg_entity
                            using player_entity_data

                            debugtag 'add_to_playfield'
                            debugtag 'player_entity'

; Set that this is the first update
                            lda  >player_entity_instance+playfield_entity~state_flags
                            ora #playfield_entity~state_first_update
                            sta >player_entity_instance+playfield_entity~state_flags

                            rtl
                            end
.skip

; -----------------------------------------------------------------------------
; Remove the player entity from the playfield
player_entity_remove_from_playfield start seg_entity
                            using player_entity_data

                            debugtag 'remove_from_playfield'
                            debugtag 'player_entity'

                            begin_locals
pEntity                     decl ptr
work_area_size              end_locals

                            sub (4:pPlayfield),work_area_size

                            getptr #player_entity_instance,<pEntity

; Make sure this is on, so we get removed from the collision list
                            getword [<pEntity],#playfield_entity~state_flags
                            ora #playfield_entity~state_marked_for_removal
                            putword [<pEntity],#same

; Invalidate
                            ldx <pEntity
                            jsl playfield_entity_invalidate_sprite

                            ret
                            end

; -----------------------------------------------------------------------------
player_entity_decelerate    start seg_entity
                            using player_entity_data

                            debugtag 'decelerate_player_entity'

                            pha                                 ; create a temporary on the stack

                            ldx #player_entity_instance

; Get the vector length of the speed
;                            getword {x},>entities_root+playfield_entity~speed_x
;                            tax
;                            getword {x},>entities_root+playfield_entity~speed_y
;                            jsl math~vec2_length
; From the deceleration time, get the amount we want to slow down.

                            getword {x},>entities_root+playfield_entity~speed_x
                            beq no_x

                            ldx #231             ; about .902, in fp16
                            jsl math~mul2r4
; Convert back to fp16, this is doing a >> 8 on the 32 bit result
                            xba
                            and #$00ff
                            sta 1,s
                            txa
                            xba
                            and #$ff00
                            ora 1,s
                            ldx #player_entity_instance
                            putword {x},>entities_root+playfield_entity~speed_x

no_x                        anop
                            getword {x},>entities_root+playfield_entity~speed_y
                            beq no_y

                            ldx #231             ; about .902, in fp16
                            jsl math~mul2r4
; Convert back to fp16, this is doing a >> 8 on the 32 bit result
                            xba
                            and #$00ff
                            sta 1,s
                            txa
                            xba
                            and #$ff00
                            ora 1,s
                            ldx #player_entity_instance
                            putword {x},>entities_root+playfield_entity~speed_y

no_y                        anop
                            pla                                     ; remove the temporary
                            rtl

                            end

; -----------------------------------------------------------------------------
; Handler for when a player is 'marked for removal'
player_entity_remove_handler start seg_entity
                            using player_entity_data

                            debugtag 'remove_handler_player_entity'

                            rts
                            end
