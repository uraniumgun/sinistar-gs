                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm

                            mcopy generated/framelib.frame.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Get the ID from a frame
; This is not something you would usually call, as it is easy enough to just
; get it directly.
framelib_frame_get_id       start seg_grlib
                            begin_locals
result                      decl word
work_area_size              end_locals

                            debugtag 'get_id'
                            debugtag 'framelib_frame'
                            sub (4:pThis),work_area_size

                            getword [<pThis],#framelib_frame~id,<result

                            ret 2:result
                            end

