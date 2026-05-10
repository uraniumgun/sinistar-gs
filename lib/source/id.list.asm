; ------------------------------------------------------------------------------
; Recycled ID list
;
; This is a simple, pre-allocated list of IDs, where each ID can be allocated
; from the pool, then released.
; The system provides for a default way of allocating the IDs that are contained
; though the user can fill in any set of IDs, externally.
;
; The user can also iterate through the IDs that have been allocated, as well
; as ones that have not.  A limitation of the iteration of the allocated IDs
; is that as IDs are released, the ordering of that part of the list is disturbed
; so the use should not rely on iteration ordering.
;
; The default implementation supports only 16-bit IDs.
; A derivation to support 32-bit IDs, or other sizes could be added, if needed
;
; Rules are:
;  Do not assume ordering of the received ID.
;  The most recently released ID is usually the next one to be received
;  User can assume the range of the IDs, from the initial set.
;  Do not rely on consistent iteration order over the allocated or free list.
;
; A common use for this type of ID system, is that the ID can be used
; for quick lookups of the item that is using the ID.  Usually by using
; the ID as a simple index or offset.
;
;
                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/id.list.definitions.asm

                                mcopy generated/id.list.macros

; ------------------------------------------------------------------------------
; Construct an ID list.
; Parameters:
; pThis         - pointer to the id_list structure to be filled in
; wMinID        - the minimum ID
; wIncrement    - the increment between ID values.  This is usually passed in as 1, but can be any value.
;                 If this value is 0, the list will NOT be filled with any initial IDs and it is assumed that
;                 the user will fill it with custom values.
; wCount        - the number of IDs to add.  This should be a valid value, even if the increment is 0.
;
; Note that since the buffer has to already be allocated, this does have the potential to
; overwrite memory, if input values do not match the pre-allocated buffer for the struct.
;
id_list_construct               start seg_clib

                                debugtag 'construct'
                                debugtag 'id_list'

                                begin_locals
wTemp                           decl word
work_area_size                  end_locals

                                sub (4:pThis,2:wMinID,2:wIncrement,2:wCount),work_area_size

                                lda #0
                                putword [<pThis],#id_list~free_index
                                lda <wMinID
                                putword [<pThis],#id_list~min_id

                                lda <wCount
                                putword [<pThis],#id_list~max_index
                                beq no_index
                                tax

                                lda <wIncrement
                                beq no_increment

; Fill the IDs
                                ldy #id_list~ids
                                lda <wMinID
                                bra skip
loop                            clc
                                adc <wIncrement
skip                            sta [<pThis],y
                                iny                             ; 16 bit IDs
                                iny
                                dex
                                bne loop

no_index                        anop
no_increment                    anop
; Save the max id
                                putword [<pThis],#id_list~max_id
                                ret

                                end

; ------------------------------------------------------------------------------
; Allocates an ID from the list
; Returns:
; carry clear, id in acc
; carry set, no more ids available

id_list_allocate_id             start seg_clib

                                debugtag 'allocate_id'
                                debugtag 'id_list'

                                begin_locals
result                          decl word
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                getword [<pThis],#id_list~free_index
                                cmpword [<pThis],#id_list~max_index
                                bge error                   ; any more available?

                                tax                         ; save the index
                                asl a                       ; 16-bit entries
                                clc
                                adc #id_list~ids
                                tay
                                lda [<pThis],y              ; get the ID
                                sta <result

                                txa                         ; get the index back
                                inc a
                                putword [<pThis],#id_list~free_index
                                clc

exit                            retkc 2:result
error                           anop
                                assert_brk 'id_list_allocate_id'
                                stz <result
                                bra exit
                                end

; ------------------------------------------------------------------------------
; Free an ID, and return it to the free section of the list.
; Parameters:
; wID       - the ID to free
;
; This version of the id_list, assumes that the values above the free_index, are all
; the IDs that are allocated and it will search that part of the list, remove the ID from it
; and place it at free_index - 1, swapping places with what was in free_index - 1, then
; adjusting free_index.  This means that freeing an ID is not the quickest operation
; as a search has to happen, but allows for iteration over the the allocated IDs.
;
; If this type of iteration is not needed, use the alternate, id_list_free_id_immediate
; This will just put the ID at free_index - 1 and adjust the free_index.
;
; Please note that intermixing id_list_free_id and id_list_free_id_immediate is bad.

id_list_free_id                 start seg_clib

                                debugtag 'free_id'
                                debugtag 'id_list'

                                begin_locals
wNewFreeIndex                   decl word
work_area_size                  end_locals

                                sub (4:pThis,2:wID),work_area_size

                                getword [<pThis],#id_list~free_index
                                beq error                   ; trying to free, and the list is already completely free
                                tax
                                dec a
                                sta <wNewFreeIndex
                                ldy #id_list~ids
                                lda <wID
loop                            cmp [<pThis],y
                                beq found
                                iny
                                iny
                                dex
                                bne loop
; Uh oh, not found.
error                           sec
                                assert_brk 'id_list_free_id'
                                bra exit

found                           anop
; Swap with the last free allocated
                                phy                         ; save the found offset
                                lda <wNewFreeIndex
                                asl a                       ; 16-bit entries
                                clc
                                adc #id_list~ids
                                tay                         ; offset to the last allocated
                                tax                         ; save for later
                                lda [<pThis],y              ; get last allocated
                                ply                         ; get the found offset
                                sta [<pThis],y              ; swap in
                                txy                         ; get the last allocate offset back
                                lda <wID                    ; put the ID in there
                                sta [<pThis],y
                                lda <wNewFreeIndex
                                putword [<pThis],#id_list~free_index
                                clc

exit                            retkc
                                end


