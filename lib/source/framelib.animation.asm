                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm

                            mcopy generated/framelib.animation.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
framelib_animation_get_type start seg_grlib
                            begin_locals
result                      decl word
work_area_size              end_locals

                            debugtag 'get_type'
                            debugtag 'framelib_animation'
                            sub (4:pThis),work_area_size

                            getword [<pThis],#framelib_animation~type,<result

                            ret 2:result
                            end

