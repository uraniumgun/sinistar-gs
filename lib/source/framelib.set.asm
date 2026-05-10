                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm

                            mcopy generated/framelib.set.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Get a frame ID for a set for the supplied parameters
; Parameters:
;  pThis            - the frame set
;  wFrameListIndex  - the index of the frame list to search
;  wFrameIndex      - the index of the frame to return the ID of
;
; Returns:
; If carry clear, the ID is in A
; If carry set, the frame was not found.
framelib_set_get_frame_id   start seg_grlib

                            begin_locals
result                      decl word                                           ; result value inside our local work area
pFrameList                  decl ptr
work_area_size              end_locals

                            debugtag 'get_frame_id'
                            debugtag 'framelib_collection'
                            sub (4:pThis,2:wFrameList,2:wFrameIndex),work_area_size

                            testptr <pThis
                            beq null_pointer

                            lda <wFrameList
                            ldy #framelib_set~count
                            cmp [<pThis],y
                            bge out_of_range

; Get the offset into the pointer table for the lists, and get the pointer to the list we want
                            asl a
                            asl a
                            clc
                            adc #framelib_set~lists
                            tay
                            lda [<pThis],y
                            sta <pFrameList
                            iny
                            iny
                            lda [<pThis],y
                            sta <pFrameList+2

                            lda <wFrameIndex
                            cmpword [<pFrameList],#framelib_list~count
                            bge out_of_range

; Get the offset into the frame array we want
                            static_assert_equal sizeof~framelib_frame,4

                            asl a                                    ; sizeof~framelib_frame is 4
                            asl a
                            clc
                            adc #framelib_list~array
                            tay
                            lda [<pFrameList],y                      ; This is framelib_frame~id
                            sta <result

                            clc
exit                        retkc 2:result

out_of_range                anop
null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Cache all the frames in the set
;
; Parameters:
;  pThis    - the frame set
;  pLibrary - the parent library of the set.
;
; Returns:
; carry set if there was an error, clear if not
framelib_set_cache_frames   start seg_grlib

                            begin_locals
wCount                      decl word
work_area_size              end_locals

                            debugtag 'cache_frames'
                            debugtag 'framelib_set'
                            sub (4:pThis,4:pLibrary),work_area_size

                            getword [<pThis],#framelib_set~count
                            beq no_lists
                            sta <wCount

                            ldy #framelib_set~lists
loop                        lda [<pThis],y
                            tax
                            iny
                            iny
                            lda [<pThis],y
                            phy                                             ; save this

                            pha
                            phx
                            pushptr <pLibrary
                            jsl framelib_list_cache_frames

                            ply
                            iny
                            iny
                            dec <wCount
                            bne loop

no_lists                    anop
                            clc
                            retkc
                            end

; -----------------------------------------------------------------------------
; Uncache all the frames in the set
;
; Parameters:
;  pThis    - the frame set
;  pLibrary - the parent library of the set.
;
; Returns:
; none
framelib_set_uncache_frames start seg_grlib

                            begin_locals
wCount                      decl word
work_area_size              end_locals

                            debugtag 'uncache_frames'
                            debugtag 'framelib_set'
                            sub (4:pThis,4:pLibrary),work_area_size

                            getword [<pThis],#framelib_set~count
                            beq no_lists
                            sta <wCount

                            ldy #framelib_set~lists
loop                        lda [<pThis],y
                            tax
                            iny
                            iny
                            lda [<pThis],y
                            phy                                             ; save this

                            pha
                            phx
                            pushptr <pLibrary
                            jsl framelib_list_uncache_frames

                            ply
                            iny
                            iny
                            dec <wCount
                            bne loop

no_lists                    anop
                            ret
                            end


