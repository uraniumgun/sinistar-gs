                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/shape.definitions.asm

                            mcopy generated/framelib.entity.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; Construct an empty entity
framelib_entity_construct   start seg_grlib

                            begin_locals
work_area_size              end_locals

                            debugtag 'construct'
;                            debugtag 'framelib_entity'
                            sub (4:pThis),work_area_size

                            setdatabanktoptr <pThis

                            setregtoptr x,<pThis

                            jsl framelib_entity_construct_implicit

                            restoredatabank

                            ret
                            end

; -----------------------------------------------------------------------------
; Construct an empty entity
; This assumes the bank is set to entity pointer and the short
; pointer is in x
framelib_entity_construct_implicit start seg_grlib

                            debugtag 'construct_implicit'

; Do I have to clear all of these?  It isn't cheap.
                            putzero {x},#framelib_entity~frame
                            putzero {x},#framelib_entity~list
                            putzero {x},#framelib_entity~set
                            putzero {x},#framelib_entity~variation
                            putzero {x},#framelib_entity~collection_id
                            putzero {x},#framelib_entity~collection_id+2
                            putzero {x},#framelib_entity~collection_ptr
                            putzero {x},#framelib_entity~collection_ptr+2
                            putzero {x},#framelib_entity~set_sptr
                            putzero {x},#framelib_entity~list_count
                            putzero {x},#framelib_entity~list_sptr
                            putzero {x},#framelib_entity~frame_count
                            putzero {x},#framelib_entity~primary_frame_data_ptr
                            putzero {x},#framelib_entity~primary_frame_data_ptr+2
                            putzero {x},#framelib_entity~secondary_frame_data_ptr
                            putzero {x},#framelib_entity~secondary_frame_data_ptr+2

                            rtl
                            end

; -----------------------------------------------------------------------------
; Destruct an entity
framelib_entity_destruct    start seg_grlib

                            begin_locals
work_area_size              end_locals

                            debugtag 'destruct'
                            debugtag 'framelib_entity'
                            sub (4:pThis),work_area_size

                            ret
                            end

; -----------------------------------------------------------------------------
; Get a set_id, by index, for the loaded collection.
; Parameters:
;  pThis        - the entity
;  wIndex       - the set index
; Returns:
; If carry clear, the set ID in A / X
; If carry set, an error occurred
framelib_entity_get_set_id_by_index start seg_grlib

                            begin_locals
result                      decl long
pCollection                 decl ptr
pSet                        decl ptr
work_area_size              end_locals

                            debugtag 'get_set_id_by_index'
                            debugtag 'framelib_entity'
                            sub (4:pThis,2:wIndex),work_area_size

                            testptr <pThis
                            beq null_pointer

                            getptr [<pThis],#framelib_entity~collection_ptr,<pCollection
                            ora <pCollection
                            beq null_pointer
                            lda <wIndex
                            cmpword [<pCollection],#framelib_collection~total_count
                            bge range_error
; Get the set pointer offset
                            asl a
                            adcword [<pThis],#framelib_collection~total_set_offset  ; can assume that the asl cleared the carry
                            tay
; Store it locally and in the entity
                            lda [<pCollection],y
                            sta <pSet
                            lda <pThis+2                                    ; sub-objects are in the same bank
                            sta <pSet+2

                            getdword [<pSet],#framelib_set~id,<result
                            clc
exit                        retkc 4:result

range_error                 anop
null_pointer                anop
                            sec
                            clearptr <result
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Get all the set IDs for the loaded collection
; Parameters:
;  pThis        - the entity
;  pVector          - pointer to a container_vector of longs
; Returns:
; Returns:
;  if carry clear, the number of entries found in a
;  if carry set, an error occured
framelib_entity_get_set_ids start seg_grlib

                            begin_locals
result                      decl word
pCollection                 decl ptr
pSet                        decl ptr
pData                       decl ptr
wCount                      decl word
wDataIndex                  decl word
work_area_size              end_locals

                            debugtag 'get_set_id_by_index'
                            debugtag 'framelib_entity'
                            sub (4:pThis,4:pVector),work_area_size

                            testptr <pThis
                            jeq null_pointer

                            getptr [<pThis],#framelib_entity~collection_ptr,<pCollection
                            ora <pCollection
                            beq null_pointer
                            ldy #framelib_collection~total_count
                            lda [<pCollection],y
                            sta <wCount
                            sta <result
                            pushptr <pVector
                            pushsword <wCount
                            jsl container_vector_resize
                            lda <wCount
                            beq done

                            pushptr <pVector
                            jsl container_vector_data
                            putretptr <pData

                            lda #2                                  ; Point at the high word
                            sta <wDataIndex

                            getword [<pCollection],#framelib_collection~total_set_offset
                            tay

loop                        lda [<pCollection],y
                            sta <pSet
                            lda <pCollection+2                      ; sub-objects are in the same bank
                            sta <pSet+2
                            iny
                            iny
                            phy
                            getword [<pSet],#framelib_set~id
                            tax
                            getword [<pSet],#framelib_set~id+2
                            ldy <wDataIndex
                            sta [<pData],y
                            dey
                            dey
                            txa
                            sta [<pData],y
                            lda <wDataIndex
                            clc
                            adc #4
                            sta <wDataIndex
                            ply
                            dec <wCount
                            bne loop

done                        anop
                            clc
exit                        retkc 2:result

null_pointer                anop
                            sec
                            stz <result
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Get the number of sets available for the loaded collection.
; Parameters:
;  pThis        - the entity
; Returns:
; If carry clear, the number of sets
; If carry set, an error occured
framelib_entity_get_set_count start seg_grlib

                            begin_locals
result                      decl word
pCollection                 decl ptr
work_area_size              end_locals

                            debugtag 'get_set_count'
                            debugtag 'framelib_entity'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq null_pointer

                            getptr [<pThis],#framelib_entity~collection_ptr,<pCollection
                            ora <pCollection
                            beq null_pointer
                            getword [<pCollection],#framelib_collection~total_count
                            sta <result

                            clc
exit                        retkc 4:result

null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Is a set_id available for the loaded collection.
; Parameters:
;  pThis        - the entity
;  hSetID       - the set ID (long), though only the lower 16 bits are compared
; Returns:
; If found, carry clear, set pointer is in a/x
; If not found, carry set / a,x are 0
framelib_entity_has_set_id  start seg_grlib

                            begin_locals
pCollection                 decl ptr
pSet                        decl ptr
work_area_size              end_locals

                            debugtag 'has_set_id'
                            debugtag 'framelib_entity'
                            sub (4:pThis,4:hSetID),work_area_size

                            testptr <pThis
                            beq null_pointer

                            getptr [<pThis],#framelib_entity~collection_ptr,<pCollection
                            ora <pCollection
                            beq null_pointer

                            getword [<pCollection],#framelib_collection~unique_count
                            tax

                            ldy #framelib_collection~sets
;
loop                        lda [<pCollection],y
                            cmp <hSetID
                            beq found
; Advance to the next entry
                            tya
                            clc
                            adc #sizeof~framelib_collection_set_entry
                            tay

                            dex
                            bne loop
                            bra range_error

found                       anop
                            static_assert_equal framelib_collection_set_entry~offset,2
                            iny
                            iny
                            lda [<pCollection],y
                            sta <pSet
                            lda <pCollection+2                          ; sub-objects are in the same bank
                            sta <pSet+2

                            clc
exit                        retkc 4:pSet

range_error                 anop
null_pointer                anop
                            sec
                            clearptr <pSet
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Get the number of variations for a set id.
; Note, it is not required that the variation part of the set id be an index
; and this just returns the count of the variations.
; Parameters:
;  pThis        - the entity
;  hSwSetID     - the lower word of the set ID
; Returns:
; If found, carry clear, count in a
; If not found, carry set, a = 0
framelib_entity_get_set_id_variation_count start seg_grlib

                            begin_locals
result                      decl word
pCollection                 decl ptr
pSet                        decl ptr
work_area_size              end_locals

                            debugtag 'set_id_variation_count'
                            debugtag 'framelib_entity'
                            sub (4:pThis,2:wSetID),work_area_size

                            stz <result
                            testptr <pThis
                            beq null_pointer

                            getptr [<pThis],#framelib_entity~collection_ptr,<pCollection
                            ora <pCollection
                            beq null_pointer

                            getword [<pCollection],#framelib_collection~unique_count
                            tax

                            ldy #framelib_collection~sets
;
loop                        lda [<pCollection],y
                            cmp <wSetID
                            beq found
; Advance to the next entry
                            tya
                            clc
                            adc #sizeof~framelib_collection_set_entry
                            tay

                            dex
                            bne loop
                            bra done

found                       anop
                            static_assert_equal framelib_collection_set_entry~variation_count,4
                            iny
                            iny
                            iny
                            iny
                            lda [<pCollection],y
                            sta <result

done                        clc
exit                        retkc 2:result

null_pointer                anop
                            sec
                            bra exit
                            end


; -----------------------------------------------------------------------------
; Update the cached pointers to the entity's set is set to.
; This will attempt to keep the same list index, but will reset it to 0
; if it is not in range in the new set.  It will reset the frame to 0,
; but will not load the frame data.
;
; This should be considered a sub-function and this assumes
; that the databank is already set to the entity, and the input
; is the short pointer to the entity, in the X register
;
; X will not be disturbed on return
framelib_entity_update_set  start seg_grlib

                            begin_locals
pCollection                 decl ptr
pSet                        decl ptr
pList                       decl ptr
hSetID                      decl long
wListCount                  decl word
work_area_size              end_locals

                            debugtag 'update_set'
                            debugtag 'framelib_entity'
                            sub ,work_area_size

                            getptr {x},#framelib_entity~collection_ptr,<pCollection
                            jeq null_pointer
                            sta <pSet+2                                         ; in the same bank as the collection
                            sta <pList+2
                            getword {x},#framelib_entity~set,<hSetID
                            getword {x},#framelib_entity~variation,<hSetID+2
; This loop searched for the set ID.
; Overall, this isn't great, and we should not be searching.
; The set input should be changed to an index, and the caller should do
; a separate lookup to map the set ID to a set index and cache that.

                            phx
                            getword [<pCollection],#framelib_collection~unique_count
                            tax
                            ldy #framelib_collection~sets
; Find the set id
loop                        lda [<pCollection],y
                            cmp <hSetID
                            beq found
; Next entry.  Its faster to add a constant, than increment, when the offset is > 4
                            tya
                            clc
                            adc #sizeof~framelib_collection_set_entry
                            tay

                            dex
                            bne loop
                            plx
                            bra not_found

found                       anop
                            plx
; NOT going to validate the variation range.
                            lda <hSetID+2
                            asl a
                            static_assert_equal framelib_collection_set_entry~offset,2
                            iny
                            iny
                            adc [<pCollection],y
                            tay
                            lda [<pCollection],y                        ; Get the set pointer
                            sta <pSet
                            putptrlow {x},#framelib_entity~set_sptr
; Update the list.  We will try and use the existing list index, but if it is out of range, we will set it to 0.
; Store the list count for easy reference
                            getword [<pSet],#framelib_set~count
                            putword {x},#framelib_entity~list_count
                            sta <wListCount
; Validate the range
                            getword {x},#framelib_entity~list
                            cmp <wListCount
                            blt ok_list
                            lda #0
                            putword {x},#framelib_entity~list
ok_list                     anop
; Get the list ptr
                            asl a
                            asl a
                            clc
                            adc #framelib_set~lists
                            tay
; Store it locally and in the entity
                            lda [<pSet],y
                            putword {x},#framelib_entity~list_sptr

; Set the list pointer, we have already set the bank at the start
                            sta <pList
; We are going to reset the frame
                            putzero {x},#framelib_entity~frame
; And store the frame count
                            getword [<pList],#framelib_list~count
                            putword {x},#framelib_entity~frame_count

                            clc
exit                        retkc

not_found                   anop
null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Update the cached pointers to the entity's list is set to.
; This assumes that the collection/set pointer are valid!

; This should be considered a sub-function and this assumes
; that the databank is already set to the entity, and the input
; is the short pointer to the entity, in the X register
;
; X will not be disturbed on return

framelib_entity_update_list  start seg_grlib

                            begin_locals
pSet                        decl ptr
pList                       decl ptr
work_area_size              end_locals

                            debugtag 'update_list_framelib_entity'
                            sub ,work_area_size

; Get the set
                            getword {x},#framelib_entity~collection_bank            ; get the shared bank value
                            beq null_pointer
                            sta <pSet+2
                            getword {x},#framelib_entity~set_sptr,<pSet
; Validate the range
                            getword {x},#framelib_entity~list
                            cmpword {x},#framelib_entity~list_count
                            blt ok_list
                            lda #0
                            putword {x},#framelib_entity~list
ok_list                     anop
; Get the list ptr
                            asl a
                            asl a
                            clc
                            adc #framelib_set~lists
                            tay
; Store it locally and in the entity
                            lda [<pSet],y
                            putptrlow {x},#framelib_entity~list_sptr

; Need a long pointer to the list
                            sta <pList
                            lda <pSet+2
                            sta <pList+2

; We are going to reset the frame
                            putzero {x},#framelib_entity~frame
; And store the frame count
                            getword [<pList],#framelib_list~count
                            putword {x},#framelib_entity~frame_count

                            clc
exit                        retkc

range_error                 anop
null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Update the cached pointers to the entity's list is set to.
; This assumes that the collection/set pointer are valid!

; This should be considered a sub-function and this assumes
; that the databank is already set to the entity, and the input
; is the short pointer to the entity, in the X register
;
; X will not be disturbed on return

; Returns:
; carry clear if no error
framelib_entity_update_frame start seg_grlib

                            begin_locals
pCollection                 decl ptr
pSet                        decl ptr
pList                       decl ptr
pCached                     decl ptr
wFrameID                    decl word
spThis                      decl word
wCacheOffset                decl word
work_area_size              end_locals

                            debugtag 'update_frame_framelib_entity'
                            sub ,work_area_size

; Get the list
                            getword {x},#framelib_entity~collection_bank            ; get the shared bank value
                            beq null_pointer
                            sta <pList+2
                            getword {x},#framelib_entity~list_sptr,<pList

                            getword [<pList],#framelib_list~data_ptr+2
                            beq not_cached                                  ; Assuming that if the high word is 0, then the whole pointer is null
; We have a cached array of data pointers.  TBH, this is stupid slow without cached pointers, I should just assume this is the case
                            sta <pCached+2
                            getword [<pList],#framelib_list~data_ptr,<pCached
; Validate the range
                            getword {x},#framelib_entity~frame
                            cmpword [<pList],#framelib_list~count
                            blt ok_frame
                            lda #0
                            putword {x},#framelib_entity~frame
ok_frame                    anop
                            shiftleft 3                                     ; pairs of pointers
                            tay
; Get the frame data pointer
                            lda [<pCached],y
                            putptrlow {x},#framelib_entity~primary_frame_data_ptr
                            iny
                            iny
                            lda [<pCached],y
;                           beq not_cached                                  ; pointer is null, re-load
                            putptrhigh {x},#framelib_entity~primary_frame_data_ptr
; Get the secondary pointer, we don't check if it is null, as it is allowed to be
                            iny
                            iny
                            lda [<pCached],y
                            putptrlow {x},#framelib_entity~secondary_frame_data_ptr
                            iny
                            iny
                            lda [<pCached],y
                            putptrhigh {x},#framelib_entity~secondary_frame_data_ptr
                            clc
exit                        retkc

range_error                 anop
null_pointer                anop
                            sec
                            bra exit

; The data is not cached.  This is very slow, frames should be cached!
not_cached                  anop
; Validate the range
                            getword {x},#framelib_entity~frame
                            cmpword [<pList],#framelib_list~count
                            blt ok_frame2
                            lda #0
                            putword {x},#framelib_entity~frame
ok_frame2                   anop
                            shiftleft 2                                         ; offset to desired frameID
                            adc #framelib_list~array
                            tay
;
                            lda [<pList],y                                      ; frame ID
                            sta <wFrameID
; The frame IDs are relative to the library
; This is rather expensive call, seeing as we are searching for the TILE type.  Cache that too?  Overall, the fully cached path above is going to really be the way to go.
                            stx <spThis
                            getptr {x},#framelib_entity~collection_ptr,<pCollection
                            pushptr [<pCollection],#framelib_collection~library_ptr
                            pushdword #datalib_type_TILE
                            pushsword #0                                     ; The ID is an index, so nothing in the high word
                            pushsword <wFrameID                              ; and the index in the low word.
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            bcs load_error
; Store the pointer
                            txy
                            ldx <spThis
                            clc
                            adc #sizeof~datalib_shapedef                    ; advance past the header
                            putptrlow {x},#framelib_entity~primary_frame_data_ptr
                            tya                                             ; no bank crossing, so no need to add possible carry
                            putptrhigh {x},#framelib_entity~primary_frame_data_ptr
; Load the secondary frame
                            getptr {x},#framelib_entity~collection_ptr,<pCollection
                            pushptr [<pCollection],#framelib_collection~library_ptr
                            pushdword #datalib_type_CTIL
                            pushsword #0                                     ; The ID is an index, so nothing in the high word
                            pushsword <wFrameID                              ; and the index in the low word.
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            bcs no_secondary
; Store the pointer
                            txy
                            ldx <spThis
                            clc
                            adc #sizeof~datalib_shapedef                    ; advance past the header
                            putptrlow {x},#framelib_entity~secondary_frame_data_ptr
                            tya                                             ; no bank crossing, so no need to add possible carry
                            putptrhigh {x},#framelib_entity~secondary_frame_data_ptr

                            clc
                            brl exit

no_secondary                anop
; Ok with not having the secondary, small things don't need it.
                            putzero {x},#framelib_entity~secondary_frame_data_ptr
                            putzero {x},#framelib_entity~secondary_frame_data_ptr+2
                            clc
                            brl exit

load_error                  anop
                            pushptr #msg_load_failed
                            _DebugStr
                            ldx <spThis
                            sec
                            brl exit

msg_load_failed             dw 'framelib_collection: frame load failed'
                            end

; -----------------------------------------------------------------------------
; Load the collection ID that the entity references.
; The cached pointers to the parts of the collection will be cleared.
; No other fields are changed.
framelib_entity_load_collection start seg_grlib

                            begin_locals
work_area_size              end_locals

                            debugtag 'load_collection'
                            debugtag 'framelib_entity'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq null_pointer

                            pushdword #datalib_type_FRMC
                            pushptr [<pThis],#framelib_entity~collection_id ; pushdword
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_manager_get_data_ptr
                            bcs exit
; Store in the object
                            putretptr [<pThis],#framelib_entity~collection_ptr
; Clear the other pointers
                            lda #0
                            putword [<pThis],#framelib_entity~set_sptr
                            putword [<pThis],#framelib_entity~list_sptr
                            putptr [<pThis],#framelib_entity~primary_frame_data_ptr
                            putptr [<pThis],#framelib_entity~secondary_frame_data_ptr
                            clc
exit                        retkc

null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Cache all the frame data for the collection
; Note that even though this is accepting an instanced framelib_entity
; what it is 'caching', is in the shared collection_ptr.
; It might be better to just do this in framelib_entity_load_collection, so
; it is done only once.
framelib_entity_cache_collection start seg_grlib

                            begin_locals
work_area_size              end_locals

                            debugtag 'cache_collection'
                            debugtag 'framelib_entity'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq null_pointer

                            pushptr [<pThis],#framelib_entity~collection_ptr
                            jsl framelib_collection_cache_frames

exit                        retkc

null_pointer                anop
                            sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Uncache all the frame data for the collection
; Note that even though this is accepting an instanced framelib_entity
; what it is 'uncaching', is in the shared collection_ptr.
framelib_entity_uncache_collection start seg_grlib

                            begin_locals
work_area_size              end_locals

                            debugtag 'uncache_collection'
                            debugtag 'framelib_entity'
                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq null_pointer

                            pushptr [<pThis],#framelib_entity~collection_ptr
                            jsl framelib_collection_uncache_frames

exit                        retkc

null_pointer                anop
                            sec
                            bra exit
                            end

