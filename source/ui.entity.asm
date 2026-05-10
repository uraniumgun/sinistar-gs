                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/gameplay.player.definitions.asm
                            copy source/ui.entity.definitions.asm
                            copy source/app.ui.definitions.asm

                            mcopy generated/ui.entity.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; UI Entity support.
; UI entities are grlib entities, with just a little extra data.
; Be careful, these are NOT allocated out of the shared playfield entities pool
; so you cannot call functions that expect the entity to be in that
; fixed bank.  All grlib library functions take full pointers, or
; are setup to assume that the databank location is already set before the call is made.
ui_entity_data            	data seg_gameplay

ui_entity_object            dc i'sizeof~ui_entity'
                            dc a4'ui_entity_object~vtable'

ui_entity_object~vtable     anop
                            dc a4'ui_entity_construct'
                            dc a4'0'
                            dc a4'0'
                            dc a4'ui_entity_destruct'

                            end

; -----------------------------------------------------------------------------
ui_entity_construct         start seg_gameplay
                            using ui_entity_data

                            debugtag 'ui_entity_construct'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq null_pointer

                            pushptr <pThis,#ui_entity~grentity
                            jsl grlib_entity_construct
                            lda #0
                            putword [<pThis],#ui_entity~direction

; We are using origin relative positioning
                            lda #sprite~info~origin_relative
                            putword [<pThis],#ui_entity~grentity+grlib_entity~sprite+sprite~info

                            clc
exit                        anop
                            ret
null_pointer                sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
ui_entity_destruct          start seg_gameplay
                            debugtag 'ui_entity_destruct'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit

                            pushptr <pThis,#ui_entity~grentity
                            jsl grlib_entity_destruct

exit                        anop
                            ret
                            end


; -----------------------------------------------------------------------------
; Assign a framelib collection to a UI entity and make sure the
; frames are loaded.
;
; Parameters:
; pEntity               - the UI entity
; hFRMC                 - the framelib collection ID
; wFrameSet             - the framelib set
; wFrameSetVariantion   - the framelib set variation
ui_entity_load              start seg_gameplay
                            using std_objects
                            using ui_entity_data

                            debugtag 'ui_entity_load'

                            begin_locals
work_area_size              end_locals

                            sub (4:pEntity,4:hFRMC,2:wFrameSet,2:wFrameSetVariation),work_area_size          ; Parameters, plus the amount of space for our local work area

                            lda <hFRMC
                            putlonglow [<pEntity],#grlib_entity~frame+framelib_entity~collection_id
                            lda <hFRMC+2
                            putlonghigh [<pEntity],#grlib_entity~frame+framelib_entity~collection_id

                            pushptr <pEntity,#grlib_entity~frame
                            jsl framelib_entity_load_collection
                            bcs exit

                            pushptr <pEntity,#grlib_entity~frame
                            jsl framelib_entity_cache_collection
                            bcs exit

                            lda <wFrameSet
                            putlonglow [<pEntity],#grlib_entity~frame+framelib_entity~set
                            lda <wFrameSetVariation
                            putlonghigh [<pEntity],#grlib_entity~frame+framelib_entity~set

; Set the flag that it changed
                            getword [<pEntity],#grlib_entity~changed
                            ora #grlib_entity~changed_frame_set
                            putword [<pEntity],#same

                            ldx <pEntity
                            setdatabanktoptr <pEntity
                            jsl grlib_entity_update_framelib
                            restoredatabank

                            clc
exit                        retkc

                            end

; -----------------------------------------------------------------------------
; Unload a UI entity.  Currently this just unloads the frame data.
;
; Parameters:
; pEntity               - the UI entity
ui_entity_unload            start seg_gameplay
                            using std_objects
                            using ui_entity_data

                            debugtag 'ui_entity_unload'

                            begin_locals
work_area_size              end_locals

                            sub (4:pEntity),work_area_size          ; Parameters, plus the amount of space for our local work area

                            pushptr <pEntity,#grlib_entity~frame
                            jsl framelib_entity_uncache_collection

                            clc
exit                        retkc

                            end
