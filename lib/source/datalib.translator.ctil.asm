                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/shape.definitions.asm

                            mcopy generated/datalib.translator.ctil.macros

                            longa on
                            longi on

; The translator for the CTIL entries.
; The are exactly the same as the TILE entries, but contain compiled shape dat
; Overall, this is a bit of a hack, and I may get rid of this.
; It is needed simply because I need the pixel shapes and the compiled shapes
; to be in memory at the same time, and use the same ID, because the
; frame collection FRMC references, just use an ID and don't know about
; pixel vs. compiled shapes.  That swap is done at a low level.
; An alternate method would be to have the frame ID be translated to
; an ID that could identify the different types of TILE entries so
; that all the shapes can just be loaded by the TILE loader.

; -----------------------------------------------------------------------------
datalib_translator_ctil_data data seg_flib

datalib_translator_ctil  	dc a4'datalib_translator_ctil_load'
                            dc a4'datalib_translator_ctil_unload'
                            dc a4'0'                                ; add reference
                            dc a4'0'                                ; remove reference
                            dc a4'0'                                ; unload unused
                            end

; -----------------------------------------------------------------------------
; Initialize the CTIL Translator
datalib_translator_ctil_initialize start seg_flib
                            using datalib_translator_ctil_data

                            debugtag 'ctil_initialize'
                            debugtag 'datalib_translator'

                            pushptr #datalib_type_CTIL
                            pushptr #datalib_translator_ctil
                            jsl datalib_manager_set_default_translator_for_type

                            clc
                            lda #0
                            rtl
                            end

; -----------------------------------------------------------------------------
; Uninitialize the CTIL Translator
datalib_translator_ctil_uninitialize start seg_flib
                            using datalib_translator_ctil_data

                            debugtag 'ctil_uninitialize'
                            debugtag 'datalib_translator'

                            pushptr #datalib_type_CTIL
                            pushptr #0
                            jsl datalib_manager_set_default_translator_for_type

                            clc
                            lda #0
                            rtl
                            end

; -----------------------------------------------------------------------------
; Using the same TILE loader / unloader, I'm just having a separate entry point
; so I can set breakpoints
datalib_translator_ctil_load start seg_flib
                            jmp datalib_translator_tile_load
                            end

; -----------------------------------------------------------------------------
datalib_translator_ctil_unload start seg_flib
                            jmp datalib_translator_tile_unload
                            end
