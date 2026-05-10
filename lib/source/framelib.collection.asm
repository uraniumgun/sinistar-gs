                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/datalib.constants.asm

                            mcopy generated/framelib.collection.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Destruct the internals of a framelib_collection
; Note that we don't currently support creating one, other than loading one off
; storage and the collection, in that case, has a fully realized hierarchy.
; However, we do support having runtime data inside the collection's hierarchy
; so calling this destruct before releasing the collection's memory is required.
framelib_collection_destruct start seg_grlib

                            begin_locals
work_area_size              end_locals

                            debugtag 'destruct'
                            debugtag 'framelib_collection'
                            sub (4:pThis),work_area_size

                            pushptr <pThis
                            jsl framelib_collection_uncache_frames

                            ret
                            end
; -----------------------------------------------------------------------------
framelib_collection_get_set_by_index start seg_grlib

                            begin_locals
result                      decl ptr                                           ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'get_set_by_index'
                            debugtag 'framelib_collection'
                            sub (4:pThis,2:wIndex),work_area_size

                            clearptr <result
                            testptr <pThis
                            beq null_pointer

                            lda <wIndex
                            cmpword [<pThis],#framelib_collection~total_count
                            bge out_of_range

; Get the offset into the pointer table for the sets, and get the pointer to the set we want
                            asl a
                            adcword [<pThis],#framelib_collection~total_set_offset    ; note, we can assume the asl cleared the carry
                            tay
                            lda [<pThis],y
                            sta <result
                            lda <pThis+2                                    ; sub-objects are in the same bank
                            sta <result+2

                            clc
exit                        retkc 4:result

out_of_range                anop
null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Find a set by ID
;
; Parameters:
;  pThis        - the frame collection
;  hSetID       - the set ID
framelib_collection_find_set start seg_grlib

                            begin_locals
result                      decl ptr                                           ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'find_set'
                            debugtag 'framelib_collection'
                            sub (4:pThis,4:hSetID),work_area_size

                            testptr <pThis
                            beq null_pointer

                            getword [<pThis],#framelib_collection~unique_count
                            beq out_of_range
                            tax
                            ldy #framelib_collection~sets
loop                        lda [<pThis],y
                            cmp <hSetID
                            beq matched_id
; Advance to the next entry
                            tya
                            clc
                            adc #sizeof~framelib_collection_set_entry
                            tay

                            dex
                            bne loop
                            bra out_of_range

matched_id                  anop
; Assumes the variation count is at +4
                            static_assert_equal framelib_collection_set_entry~variation_count,4
                            iny
                            iny
                            iny
                            iny
                            lda <hSetID+2
                            cmp [<pThis],y                  ; the variation count
                            bge out_of_range

; get back to the offset
                            static_assert_equal framelib_collection_set_entry~offset,2
                            dey
                            dey
                            asl a                           ; variation * 2
                            adc [<pThis],y
                            tay
                            lda [<pThis],y                  ; get the set short pointer from the second array
                            sta <result
                            lda <pThis+2                    ; sub-objects are in the same bank
                            sta <result+2

found                       clc
exit                        retkc 4:result

out_of_range                anop
null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Get the frame ID of a collection from the supplied parameters
;
; Parameters:
;  pThis            - the frame collection
;  hSetID           - the set ID to search
;  wFrameListIndex  - the frame list to search
;  wFrameIndex      - the frame index to find
;
; Returns:
; If the carry flag is clear, the frame ID will be in A
; If the carry flag is set, the frame was not found
framelib_collection_get_frame_id start seg_grlib

                            begin_locals
result                      decl word                                           ; result value inside our local work area
pFrameSet                   decl ptr
pFrameList                  decl ptr
work_area_size              end_locals

                            debugtag 'get_frame_id'
                            debugtag 'framelib_collection'
                            sub (4:pThis,4:hSetID,2:wFrameListIndex,2:wFrameIndex),work_area_size

                            testptr <pThis
                            beq null_pointer
                            pushptr <pThis
                            pushptr <hSetID
                            jsl framelib_collection_find_set
                            bcs out_of_range
                            putretptr <pFrameSet

                            lda <wFrameListIndex
                            cmpword [<pFrameSet],#framelib_set~count
                            bge out_of_range

; Get the offset into the pointer table for the lists, and get the pointer to the list we want
                            asl a
                            asl a
                            adc #framelib_set~lists
                            tay
                            lda [<pFrameSet],y
                            sta <pFrameList
                            iny
                            iny
                            lda [<pFrameSet],y
                            sta <pFrameList+2

                            lda <wFrameIndex
                            cmpword [<pFrameList],#framelib_list~count
                            bge out_of_range

; Get the offset into the frame array we want
                            static_assert_equal sizeof~framelib_frame,4

                            asl a                                   ; sizeof~framelib_frame is 4
                            asl a
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
; Get the primary shape pointer for a Frame ID.
; This will return the pointer to the associated TILE (pixel) image
framelib_collection_get_frame_primary_shape_ptr start seg_grlib
                            begin_locals
result                      decl ptr                                        ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'get_frame_primary_shape_ptr'
                            debugtag 'framelib_collection'
                            sub (4:pThis,2:wFrameID),work_area_size

                            testptr <pThis
                            beq null_pointer

; The frame IDs are relative to the library
                            pushptr [<pThis],#framelib_collection~library_ptr
                            pushdword #datalib_type_TILE
                            pushsword #0                                     ; The ID is an index, so nothing in the high word
                            pushsword <wFrameID                              ; and the index in the low word.
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            putretptr <result
exit                        retkc 4:result

null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Get the secondary shape pointer for a Frame ID.
; This will return the pointer to the associated CTIL (compiled) image
framelib_collection_get_frame_secondary_shape_ptr start seg_grlib
                            begin_locals
result                      decl ptr                                        ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'get_frame_secondary_shape_ptr'
                            debugtag 'framelib_collection'
                            sub (4:pThis,2:wFrameID),work_area_size

                            testptr <pThis
                            beq null_pointer

; The frame IDs are relative to the library
                            pushptr [<pThis],#framelib_collection~library_ptr
                            pushdword #datalib_type_CTIL
                            pushsword #0                                     ; The ID is an index, so nothing in the high word
                            pushsword <wFrameID                              ; and the index in the low word.
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            putretptr <result
exit                        retkc 4:result

null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Cache all the frames in the collection
;
; Parameters:
;  pThis    - the frame collection
;
; Returns:
; carry set if there was an error, clear if not
framelib_collection_cache_frames start seg_grlib

                            begin_locals
pLibrary                    decl ptr
wCount                      decl word
work_area_size              end_locals

                            debugtag 'cache_frames'
                            debugtag 'framelib_collection'
                            sub (4:pThis),work_area_size

                            getword [<pThis],#framelib_collection~total_count
                            beq no_sets
                            sta <wCount

                            getptr [<pThis],#framelib_collection~library_ptr,<pLibrary
                            beq no_library

; Doing all the set/variation entries
                            getword [<pThis],#framelib_collection~total_set_offset
                            tay
; Loop over the short pointers
loop                        lda [<pThis],y
                            phy                                         ; save out location

                            pushsword <pThis+2                           ; sub-objects are in the same bank
                            pha
                            pushptr <pLibrary
                            jsl framelib_set_cache_frames

                            ply
                            iny
                            iny
                            dec <wCount
                            bne loop

no_sets                     anop
no_library                  anop
                            clc
                            retkc
                            end

; -----------------------------------------------------------------------------
; Uncache all the frames in the collection
;
; Parameters:
;  pThis    - the frame collection
;
; Returns:
; carry set if there was an error, clear if not
framelib_collection_uncache_frames start seg_grlib

                            begin_locals
wCount                      decl word
pLibrary                    decl ptr
work_area_size              end_locals

                            debugtag 'uncache_frames'
                            debugtag 'framelib_collection'
                            sub (4:pThis),work_area_size

                            getword [<pThis],#framelib_collection~total_count
                            beq no_sets
                            sta <wCount

; The sub-functions will need the library pointer
                            getptr [<pThis],#framelib_collection~library_ptr,<pLibrary

                            getword [<pThis],#framelib_collection~total_set_offset
                            tay
; Loop over the short pointers
loop                        lda [<pThis],y
                            phy                                         ; save out location

                            pushsword <pThis+2                          ; sub-objects are in the same bank
                            pha
                            pushptr <pLibrary
                            jsl framelib_set_uncache_frames

                            ply
                            iny
                            iny
                            dec <wCount
                            bne loop

no_sets                     anop
                            ret
                            end



