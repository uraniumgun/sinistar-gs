                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/shape.definitions.asm

                            mcopy generated/framelib.list.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Get the frame ID for an index in the frame list
; Parameters:
;  pThis        - the frame list
;  wIndex       - the frame index
; Returns:
; If carry clear, the frame ID is A
; If carry set, the index was out of range
framelib_list_get_frame_id  start seg_grlib

                            begin_locals
result                      decl word
work_area_size              end_locals

                            debugtag 'get_frame_id'
                            debugtag 'framelib_list'
                            sub (4:pThis,2:wIndex),work_area_size

                            lda <wIndex
                            cmpword [<pThis],#framelib_list~count
                            bge out_of_range

                            static_assert_equal sizeof~framelib_frame,4

                            asl a                                       ; sizeof~framelib_frame == 4
                            asl a
                            clc
                            adc #framelib_list~array
                            tay                                         ; y now points to the desired framelib_frame~id
                            lda [<pThis],y

; carry is already clear
exit                        retkc 2:result
out_of_range                sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Cache all the shape pointers for the frames in the list
; This supports a primary and secondary set of frame data.
; The secondary data pointer is to support compiled sprites.
;
; The output list will be an array of pointer pairs,
; primary and secondary shapes, the latter can be null.
;
; Parameters:
;  pThis    - the frame list
;  pLibrary - the parent library of the list.
;
; Returns:
; carry set if there was an error, clear if not
framelib_list_cache_frames  start seg_grlib

                            begin_locals
wCount                      decl word
wIndex                      decl word
wOffset                     decl word
wFrameID                    decl word
pCachedArray                decl ptr
work_area_size              end_locals

                            debugtag 'cache_frames'
                            debugtag 'framelib_list'
                            sub (4:pThis,4:pLibrary),work_area_size

                            testptr [<pThis],#framelib_list~data_ptr
                            bne has_cached                              ; Already have a cached pointer?  If so, we are assuming the values are correct.
                            getword [<pThis],#framelib_list~count
                            beq no_frames
                            sta <wCount
                            shiftleft 3                                 ; (wCount * sizeof(ptr)) * 2
                            pha
                            jsl sba_alloc
                            bcs alloc_error
                            putretptr <pCachedArray

                            putptrlow [<pThis],#framelib_list~data_ptr
                            txa
                            putptrhigh [<pThis],#framelib_list~data_ptr

; Iterate over the array of framelib_frame entries (sizeof~framelib_frame == 4)
                            static_assert_equal sizeof~framelib_frame,4

                            lda #0
                            sta <wIndex
loop                        lda <wIndex
                            shiftleft 3
                            sta <wOffset
                            lsr a                                                       ; back down to x 4 to get the frameID offset
                            clc
                            adc #framelib_list~array
                            tay
                            lda [<pThis],y                                              ; first word in a framelib_frame, is the frame id
                            sta <wFrameID

; Get the primary (TILE)
                            pushptr <pLibrary
                            pushsword <wFrameID
                            jsl framelib_manager_get_primary_frame_data_ptr             ; Note, not currently handling any errors, we will just store a null.

                            ldy <wOffset
                            clc
                            adc #sizeof~datalib_shapedef                                ; Cached entry doesn't need the datalib header
                            sta [<pCachedArray],y
                            txa                                                         ; No bank crossing, so skip adding possible carry
                            iny
                            iny
                            sta [<pCachedArray],y

; Get the secondary (CTIL)
                            pushptr <pLibrary
                            pushsword <wFrameID
                            jsl framelib_manager_get_secondary_frame_data_ptr

                            ldy <wOffset
                            iny
                            iny
                            iny
                            iny
                            clc
                            adc #sizeof~datalib_shapedef                                ; Cached entry doesn't need the datalib header
                            sta [<pCachedArray],y
                            txa                                                         ; No bank crossing, so skip adding possible carry
                            iny
                            iny
                            sta [<pCachedArray],y

                            inc <wIndex
                            dec <wCount
                            bne loop

no_frames                   anop
has_cached                  anop
                            clc
alloc_error                 anop
exit                        retkc
                            end

; -----------------------------------------------------------------------------
; Uncache any cached frames
;
; Parameters:
;  pThis    - the frame list
;  pLibrary - the parent library of the list.
;
; Returns:
; none
framelib_list_uncache_frames start seg_grlib

                            begin_locals
wCount                      decl word
wIndex                      decl word
wOffset                     decl word
wFrameID                    decl word
work_area_size              end_locals

                            debugtag 'uncache_frames'
                            debugtag 'framelib_list'
                            sub (4:pThis,4:pLibrary),work_area_size

                            getword [<pThis],#framelib_list~data_ptr+1
                            beq not_cached

                            getword [<pThis],#framelib_list~count
                            beq no_frames

                            jsr unload_frame_data

; Push and clear the pointer
no_frames                   anop
                            getword [<pThis],#framelib_list~data_ptr+2
                            pha
                            lda #0
                            putword [<pThis],#same
                            getword [<pThis],#framelib_list~data_ptr
                            pha
                            lda #0
                            putword [<pThis],#same

                            jsl sba_free

not_cached                  anop
                            ret

;;;
; What we have cached in the array, is the pointers to the data.
; We need to go back through the frame Ids and request an unload
unload_frame_data           anop

                            sta <wCount

; Iterate over the array of framelib_frame entries (sizeof~framelib_frame == 4)
                            static_assert_equal sizeof~framelib_frame,4

                            lda #0
                            sta <wIndex
loop                        lda <wIndex
                            shiftleft 2
                            sta <wOffset
                            clc
                            adc #framelib_list~array
                            tay
                            lda [<pThis],y                                              ; first word in a framelib_frame, is the frame id
                            sta <wFrameID

; Get the primary (TILE)
                            pushptr <pLibrary
                            pushsword <wFrameID
                            jsl framelib_manager_release_primary_frame_data

; Get the secondary (CTIL)
                            pushptr <pLibrary
                            pushsword <wFrameID
                            jsl framelib_manager_release_secondary_frame_data

                            inc <wIndex
                            dec <wCount
                            bne loop
                            rts

                            end
