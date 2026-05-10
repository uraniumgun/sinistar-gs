                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/player.entity.definitions.asm

                            mcopy generated/gameplay.playfield.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains playfield functions for the in-game playfield.
; Generic playfield support is in playfield.asm

; Where the player is, in the view.  Note, the + in front of the equate, is there, just to prevent a compile error.
playfield_view_center_x        gequ +((gameplay_ui_playfield_right-gameplay_ui_playfield_left)/2)
playfield_view_center_y        gequ +((gameplay_ui_playfield_bottom-gameplay_ui_playfield_top)/2)

playfield_screen_center_x      gequ playfield_view_center_x+gameplay_ui_playfield_left
playfield_screen_center_y      gequ playfield_view_center_y+gameplay_ui_playfield_top

; ----------------------------------------------------------------------------
; Initialize the playfield
gameplay_playfield_initialize start seg_gameplay
                            using appdata
                            using gameplay_level_data
                            using playfield_manager_data

                            debugtag 'initialize'
                            debugtag 'gameplay_playfield'

                            setlocaldatabank

                            pushptr #gameplay_level~playfield
                            jsl playfield_construct

; Set the bounds of the playfield.  Since in the end, these are constant, most things should probably use the global equates for this directly
                            pushptr #gameplay_level~playfield
                            pushsword #-(gameplay_playfield_width/2)
                            pushsword #-(gameplay_playfield_height/2)
                            pushsword #+(gameplay_playfield_width/2)
                            pushsword #+(gameplay_playfield_height/2)
                            jsl playfield_set_bounds

                            pushptr #gameplay_level~playfield_view
                            pushptr #gameplay_level~playfield
                            jsl playfield_view_construct

; Reserve a shr palatte
                            lda >playfield_view~palette_shr_slot
                            bpl got_palette

                            pushsword #$ffff
                            jsl gameplay_ui_palette_reserve
                            bcs error
                            sta >playfield_view~palette_shr_slot

got_palette                 anop
error                       anop

                            jsl gameplay_playfield_view_setup_palette

; Set the view into the playfield
                            pushptr #gameplay_level~playfield_view
                            pushsword #gameplay_ui_playfield_left
                            pushsword #gameplay_ui_playfield_top
                            pushsword #gameplay_ui_playfield_right
                            pushsword #gameplay_ui_playfield_bottom
                            jsl playfield_view_set_bounds

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
; Setup the playfield for gameplay turn activation
gameplay_playfield_turn_activate start seg_gameplay
                            using appdata
                            using gameplay_level_data
                            using playfield_manager_data

                            debugtag 'playfield_turn_activate'

                            setlocaldatabank

; Apply the update rect bounds.

; This is in screen space
                            pushsword #gameplay_ui_playfield_left
                            pushsword #gameplay_ui_playfield_top
                            pushsword #gameplay_ui_playfield_right
                            pushsword #gameplay_ui_playfield_bottom
                            jsl grlib_set_max_update_rect

; The update rect system needs to know the world size, to help with coordinate wrapping.
                            pushsword #gameplay_playfield_width
                            pushsword #gameplay_playfield_height
                            jsl grlib_set_update_rect_world_size

; Set the origin. This will move if coordinate wrapping is enabled
                            pushsword #-playfield_view_center_x
                            pushsword #-playfield_view_center_y
                            jsl grlib_set_update_rect_origin

                            stz playfield_manager~view_speed_x
                            stz playfield_manager~view_speed_y
                            stz playfield_manager~unadjusted_view_speed_x
                            stz playfield_manager~unadjusted_view_speed_y

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_playfield_uninitialize start seg_gameplay
                            using gameplay_level_data
                            using playfield_manager_data

                            debugtag 'uninitialize'
                            debugtag 'gameplay_playfield'

; Release any reserved palette
                            pushword >playfield_view~palette_shr_slot
                            jsl grlib_shr_palette_release_reserve

                            pushptr #gameplay_level~playfield_view
                            jsl playfield_view_destruct

                            pushptr #gameplay_level~playfield
                            jsl playfield_destruct

                            rtl
                            end

; ----------------------------------------------------------------------------
gameplay_playfield_view_apply_palette start seg_gameplay
                            using gameplay_level_data
                            using playfield_manager_data
                            using gameplay_ui_data

                            debugtag 'apply_palette'
                            debugtag 'gameplay_playfield_view'

                            setlocaldatabank

                            lda >playfield_view~palette_shr_slot
                            bmi none
                            tax
                            lda gameplay_level~playfield_palette_ptr+2
                            beq none
                            pha
                            lda gameplay_level~playfield_palette_ptr
                            pha
                            phx
                            pushsword #gameplay_ui~palette_id~playfield             ; track what we are switching to
                            jsl gameplay_ui_apply_palette

                            pushword >playfield_view~palette_shr_slot
                            lda gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~top
                            pha
; Negate and add to bottom, to get the height
                            negate a
                            clc
                            adc gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~bottom
                            pha
                            jsl grlib_set_scb_palette_range

                            pushptr gameplay_level~playfield_palette_ptr
                            pushsword >playfield_view~palette_shr_slot
                            jsl playfield_view_set_palette

none                        restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
; Get the playfield's palette from 'somewhere'
gameplay_playfield_view_setup_palette start seg_gameplay
                            using gameplay_level_data
                            using player_entity_data

                            debugtag 'setup_palette'
                            debugtag 'gameplay_playfield_view'

                            begin_locals
pDataEntry                  decl ptr
pTypeEntry                  decl ptr
pLibrary                    decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            testptr gameplay_level~playfield_palette_ptr
                            bne already_set

; Right now, I'm getting it from the player ship
                            pushdword #datalib_type_FRMC
                            pushdword #player_entity_image_collection_id
                            jsl datalib_manager_find_data_entry
                            bcs error
                            putretptr <pDataEntry

                            getptr [<pDataEntry],#datalib_data_entry~type_ptr,<pTypeEntry
                            getptr [<pTypeEntry],#datalib_type_entry~library_ptr,<pLibrary

                            pushptr <pLibrary
                            pushdword #datalib_type_PALT
                            pushdword #0                                    ; Assuming that the palette is index 0 in the library
                            pushsword #datalib_load_options~none            ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            bcs error
                            putretptr gameplay_level~playfield_palette_ptr

already_set                 anop
                            restoredatabank
error                       ret
                            end
