                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/input.constants.asm

                            mcopy generated/startup.splash.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
do_startup_splash           start seg_app
                            using appdata
                            using applib_data
                            using softswitch_definitions
                            using ui_entity_data
                            using gameplay_ui_data

                            debugtag 'startup_splash'

                            begin_locals
wX                          decl word
wY                          decl word
pEntity                     decl ptr
work_area_size              end_locals

                            sub ,work_area_size

ui_image_collection_id      equ '10IU'

                            setlocaldatabank

; Need one object to draw some images
                            pushptr #ui_entity_object
                            jsl object_new
;                           bcs failed
                            putretptr <pEntity

; Draw Sinistar Logo
                            pushretptr
                            pushptr #ui_image_collection_id
                            pushsword #framelib_set_id_walk
                            pushsword #0
                            jsl ui_entity_load
                            bcs load_error

                            pushptr <pEntity
                            pushsword #4                            ; the shape is 311 x 116.  I only exported the 'even' image, so it has to go on an even x
                            pushsword #42
                            jsl grlib_draw_sprite

; We should do this next bit in the vbl
                            jsl grlib_wait_one_frame

                            pushptr <pEntity
                            jsl grlib_entity_get_palette
                            bcs missing_palette

                            pushretptr
                            pushsword #0
                            pushsword #gameplay_ui~palette_id~splash
                            jsl gameplay_ui_apply_palette

                            pushsword #0
                            pushsword #0
                            pushsword #grlib~screen_height
                            jsl grlib_set_scb_palette_range

                            jsl grlib_alt_screen_to_screen

missing_palette             anop
                            pushptr <pEntity
                            jsl ui_entity_unload

load_error                  anop
                            pushptr <pEntity
                            pushptr #ui_entity_object
                            jsl object_delete

exit                        restoredatabank
                            ret


                            end
