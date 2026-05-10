                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm

                            mcopy generated/grlib.entity.macros

                            longa on
                            longi on

; Enable to add some validation on sprite destruction.
;debug~validate_sprite_destruct gequ 1
; Enable to add some validation on the framelib entity destruction.
;debug~validate_framelib_entity_destruct gequ 1

; -----------------------------------------------------------------------------
; Construct a grlib entity
; Parameters:
; pThis             the entity
; Returns:
; Nothing
grlib_entity_construct      start seg_grlib
                            using grlib_entity_manager_errors

                            debugtag 'grlib_entity_construct'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            setdatabanktoptr <pThis

; Both of these, just zero out fields, it would be more efficient to do that inline, in this function
                            setregtoptr x,<pThis,#grlib_entity~frame
                            jsl framelib_entity_construct_implicit

                            setregtoptr x,<pThis,#grlib_entity~sprite
                            jsl sprite_construct_implicit

                            setregtoptr x,<pThis
                            putzero {x},#grlib_entity~changed
                            putzero {x},#grlib_entity~x
                            putzero {x},#grlib_entity~y
                            putzero {x},#grlib_entity~parent_entity_ptr
                            putzero {x},#grlib_entity~parent_entity_ptr+2
                            putzero {x},#grlib_entity~child_entity_ptr
                            putzero {x},#grlib_entity~child_entity_ptr+2
                            putzero {x},#grlib_entity~sibling_entity_ptr
                            putzero {x},#grlib_entity~sibling_entity_ptr+2

                            restoredatabank

                            ret

                            end

; -----------------------------------------------------------------------------
grlib_entity_destruct       start seg_grlib
                            debugtag 'grlib_entity_destruct'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit

                            aif C:debug~validate_framelib_entity_destruct=0,.skip
                            pushptr <pThis,#grlib_entity~frame
                            jsl framelib_entity_destruct
.skip
                            aif C:debug~validate_sprite_destruct=0,.skip
                            pushptr <pThis,#grlib_entity~sprite
                            jsl sprite_destruct
.skip

exit                        anop
                            ret
                            end

; -----------------------------------------------------------------------------
; Reuse a grlib entity
; Parameters:
; pThis             the entity
; Returns:
; Nothing
grlib_entity_reuse          start seg_grlib
                            using grlib_entity_manager_errors

                            debugtag 'grlib_entity_reuse'

                            begin_locals
work_area_size              end_locals

                            sub (4:pThis),work_area_size

                            setdatabanktoptr <pThis

; Both of these, just zero out fields, it would be more efficient to do that inline, in this function
;                           setregtoptr x,<pThis,#grlib_entity~frame
;                           jsl framelib_entity_construct_implicit

;                           setregtoptr x,<pThis,#grlib_entity~sprite
;                           jsl sprite_construct_implicit

                            setregtoptr x,<pThis
                            putzero {x},#grlib_entity~changed
;                           putzero {x},#grlib_entity~x
;                           putzero {x},#grlib_entity~y
                            putzero {x},#grlib_entity~parent_entity_ptr
                            putzero {x},#grlib_entity~parent_entity_ptr+2
                            putzero {x},#grlib_entity~child_entity_ptr
                            putzero {x},#grlib_entity~child_entity_ptr+2
                            putzero {x},#grlib_entity~sibling_entity_ptr
                            putzero {x},#grlib_entity~sibling_entity_ptr+2

                            restoredatabank

                            ret

                            end

; --------------------------------------------------------------------------------------------
; Allocate a new grlib_entity object.
; This allocates from the grlib_entity_manager's fixed pool
;
; Parameters: none
; Returns:
; if carry clear, the pointer to the object, will not be null
; if carry set, null
grlib_entity_new            start seg_grlib
                            using grlib_entity_manager_data
; Define our work area data
                            begin_locals
result                      decl ptr                                ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'grlib_entity_new'

                            sub ,work_area_size

                            pushptr #global_grlib_entity_manager+grlib_entity_manager~pool
                            jsl fixed_buffer_pool_alloc
                            bcs allocation_error
                            putretptr <result
                            pushretptr
                            jsl grlib_entity_construct
                            clc                                     ; no error
exit                        retkc 4:result
allocation_error            anop
                            clearptr <result
                            sec                                     ; error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Deallocate a grlib_entity object.
; Note that this will destruct a grlib_entity that is not owned by the manager correctly.
;
; Parameters:
; pThis             - the grlib_entity pointer.
; Returns:
; nothing
grlib_entity_delete         start seg_grlib
                            using grlib_entity_manager_data

                            begin_locals
work_area_size              end_locals

                            debugtag 'grlib_entity_delete'

                            sub (4:pThis),work_area_size

                            testptr <pThis
                            beq exit

                            pushptr <pThis
                            jsl grlib_entity_destruct

; It is safe to call this with a pointer the buffer does not own
                            pushptr #global_grlib_entity_manager+grlib_entity_manager~pool
                            pushptr <pThis
                            jsl fixed_buffer_pool_free

exit                        ret
                            end

; --------------------------------------------------------------------------------------------
; Add a child entity, to a parent
;
; Parameters:
; pParent               - the parent grlib_entity pointer.
; pChild                - the child grlib_entity pointer.
; Returns:
; nothing
grlib_entity_add_child      start seg_grlib
                            using grlib_entity_manager_data

                            begin_locals
pSibling                    decl ptr
work_area_size              end_locals

                            debugtag 'add_child'
                            debugtag 'grlib_entity'

                            sub (4:pParent,4:pChild),work_area_size

                            getword [<pParent],#grlib_entity~child_entity_ptr+2
                            bne has_children
                            lda <pChild+2
                            putword [<pParent],#same
                            lda <pChild
                            putword [<pParent],#grlib_entity~child_entity_ptr
                            bra added

; Existing children, add to the end of the chain
has_children                anop
                            sta <pSibling+2
                            getword [<pParent],#grlib_entity~child_entity_ptr
                            sta <pSibling

sibling_loop                getword [<pSibling],#grlib_entity~sibling_entity_ptr+2
                            beq last_sibling
                            tax
                            getword [<pSibling],#grlib_entity~sibling_entity_ptr
                            sta <pSibling
                            stx <pSibling+2
                            bra sibling_loop
last_sibling                anop
                            lda <pChild
                            putptrlow [<pSibling],#grlib_entity~sibling_entity_ptr
                            lda <pChild+2
                            putptrhigh [<pSibling],#grlib_entity~sibling_entity_ptr

added                       lda #0
                            putptr [<pChild],#grlib_entity~sibling_entity_ptr
                            lda <pParent
                            putptrlow [<pChild],#grlib_entity~parent_entity_ptr
                            lda <pParent+2
                            putptrhigh [<pChild],#grlib_entity~parent_entity_ptr

exit                        ret
                            end

; --------------------------------------------------------------------------------------------
; Removes the first child from the parent, returning the pointer to the child
;
; Parameters:
; pParent               - the parent grlib_entity pointer.
; Returns:
; child pointer
; carry clear, if a child pointer was returned, set if not
grlib_entity_remove_first_child start seg_grlib

                            begin_locals
pChild                      decl ptr
work_area_size              end_locals

                            debugtag 'remove_first_child'
                            debugtag 'grlib_entity'

                            sub (4:pParent),work_area_size

                            getword [<pParent],#grlib_entity~child_entity_ptr+2
                            beq no_children         ; Assuming if the high word is 0, the pointer is null
                            sta <pChild+2
                            getword [<pParent],#grlib_entity~child_entity_ptr
                            sta <pChild

                            getword [<pChild],#grlib_entity~sibling_entity_ptr
                            putword [<pParent],#grlib_entity~child_entity_ptr
                            getword [<pChild],#grlib_entity~sibling_entity_ptr+2
                            putword [<pParent],#grlib_entity~child_entity_ptr+2
                            clc
                            bra exit

no_children                 sec
exit                        retkc 4:pChild
                            end

; --------------------------------------------------------------------------------------------
; Remove a child entity from a parent.
; This does not delete / deconstruct the child.
;
; Parameters:
; pChild                - the child grlib_entity pointer.
; Returns:
; nothing
grlib_entity_remove_from_parent start seg_grlib
                            using grlib_entity_manager_data

                            begin_locals
pParent                     decl ptr
pSibling                    decl ptr
work_area_size              end_locals

                            debugtag 'remove_from_parent'
                            debugtag 'grlib_entity'

                            sub (4:pChild),work_area_size

                            getptr [<pChild],#grlib_entity~parent_entity_ptr,<pParent
                            getword [<pParent],#grlib_entity~child_entity_ptr
                            tax
                            getword [<pParent],#grlib_entity~child_entity_ptr+2
                            cmp <pChild+2
                            bne search_siblings
                            cpx <pChild
                            bne search_siblings

; It was the first child
                            getword [<pChild],#grlib_entity~sibling_entity_ptr
                            putword [<pParent],#grlib_entity~child_entity_ptr
                            getword [<pChild],#grlib_entity~sibling_entity_ptr+2
                            putword [<pParent],#grlib_entity~child_entity_ptr+2
                            bra exit

search_siblings             anop
                            stx <pSibling
                            sta <pSibling+2

sibling_loop                getword [<pSibling],#grlib_entity~sibling_entity_ptr
                            tax
                            getword [<pSibling],#grlib_entity~sibling_entity_ptr+2
                            cmp <pChild+2
                            bne next_sibling
                            cpx <pChild
                            beq found_sibling

next_sibling                stx <pSibling
                            sta <pSibling+2
                            assert_ptr <pSibling,'sibling_loop'
                            bra sibling_loop

found_sibling               anop
                            getword [<pChild],#grlib_entity~sibling_entity_ptr
                            putword [<pSibling],#same
                            getword [<pChild],#grlib_entity~sibling_entity_ptr+2
                            putword [<pSibling],#same

exit                        ret
                            end

; --------------------------------------------------------------------------------------------
; Process any updates needed to the cached values of the framelib.
;
; Parameters:
; x-reg:    Short pointer to entity in X
; Assumes:
; Databank set to the entity
;
; Returns:
; nothing
grlib_entity_update_framelib start seg_grlib
                            using grlib_entity_manager_data

                            begin_locals
spThis                      decl word
pShape                      decl ptr
work_area_size              end_locals

                            debugtag 'update_framelib_grlib_entity'

                            sub ,work_area_size

                            getword {x},#grlib_entity~changed
                            jeq exit                        ; assuming if 0, then nothing has changed.  Fix this, if the grlib_entity~changed bits are used for other things.

                            stx <spThis                     ; we will need this later

                            bit #(grlib_entity~changed_frame_set+grlib_entity~changed_frame_collection)
                            bne set_changed
                            bit #grlib_entity~changed_frame_list
                            bne list_changed
;                           bit #grlib_entity~changed_frame_index

index_changed               anop
                            and #((grlib_entity~changed_frame_index)*-1)-1
                            putword {x},#grlib_entity~changed
; Get the framelib_entity into X
                            txa
                            clc
                            adc #grlib_entity~frame
                            tax
                            bra update_frame

set_changed                 anop
                            and #((+grlib_entity~changed_frame_collection+grlib_entity~changed_frame_set+grlib_entity~changed_frame_list+grlib_entity~changed_frame_index)*-1)-1
                            putword {x},#grlib_entity~changed
; Get the framelib_entity into X
                            txa
                            clc
                            adc #grlib_entity~frame
                            tax
                            jsl framelib_entity_update_set              ; Assumes bank is set to the entity, and the short pointer is in X
                            bra update_list

list_changed                anop
                            and #((+grlib_entity~changed_frame_collection+grlib_entity~changed_frame_set+grlib_entity~changed_frame_list+grlib_entity~changed_frame_index)*-1)-1
                            putword {x},#grlib_entity~changed
; Get the framelib_entity into X
                            txa
                            clc
                            adc #grlib_entity~frame
                            tax
update_list                 jsl framelib_entity_update_list             ; This does not update the frame too, maybe make that a parameter or a separate call.
update_frame                jsl framelib_entity_update_frame

fixup_shape_ptr             anop
                            ldx <spThis                                 ; get the grlib_entity back
; Cached shapes have the datalib_shapedef header removed.
                            getword {x},#grlib_entity~frame+framelib_entity~primary_frame_data_ptr
                            sta <pShape
                            putptrlow {x},#grlib_entity~sprite+sprite~primary_shape_ptr
                            getword {x},#grlib_entity~frame+framelib_entity~primary_frame_data_ptr+2
                            sta <pShape+2
                            putptrhigh {x},#grlib_entity~sprite+sprite~primary_shape_ptr
; Cache some information in the sprite.  It makes it easier to access
                            getword [<pShape],#shapedef~origin_x
                            putword {x},#grlib_entity~sprite+sprite~offset_x
                            getword [<pShape],#shapedef~origin_y
                            putword {x},#grlib_entity~sprite+sprite~offset_y
                            getword [<pShape],#shapedef~width
                            putword {x},#grlib_entity~sprite+sprite~width
                            getword [<pShape],#shapedef~height
                            putword {x},#grlib_entity~sprite+sprite~height
; Secondary shape pointer.  We are assuming the info we just cached is the same in this shape
                            getword {x},#grlib_entity~frame+framelib_entity~secondary_frame_data_ptr
                            putptrlow {x},#grlib_entity~sprite+sprite~secondary_shape_ptr
                            getword {x},#grlib_entity~frame+framelib_entity~secondary_frame_data_ptr+2
                            putptrhigh {x},#grlib_entity~sprite+sprite~secondary_shape_ptr

exit                        ret
                            end

; -----------------------------------------------------------------------------
; Get the palette from a shape that the entity is using.
; Note this assumes that there is a datalib_shapedef header *before*
; where the shape pointer is pointing to.
grlib_entity_get_palette    start seg_grlib

                            debugtag 'get_palette'
                            debugtag 'grlib_entity'

                            begin_locals
pPalette                    decl ptr
pShape                      decl ptr
pDatalibHeader              decl ptr
pDataEntry                  decl ptr
pTypeEntry                  decl ptr
pLibrary                    decl ptr
work_area_size              end_locals

                            sub (4:pThis),work_area_size          ; Parameters, plus the amount of space for our local work area

                            clearptr <pPalette

; Assumes that the datalib is there, just that the cached frame has moved forward of it
; We will need both. Must get a pointer backward, since we can't index backward
                            getword [<pThis],#grlib_entity~frame+framelib_entity~primary_frame_data_ptr
                            sta <pShape
                            sec
                            sbc #sizeof~datalib_shapedef
                            sta <pDatalibHeader
                            getword [<pThis],#grlib_entity~frame+framelib_entity~primary_frame_data_ptr+2
                            beq null_pointer        ; if the high word is 0, assume it is a null pointer
                            sta <pShape+2
                            sbc #0
                            sta <pDatalibHeader+2

; Lots of dereferencing.  Not done often, but maybe the datalib_shapedef keeps the library pointer cached too?
ok                          getptr [<pDatalibHeader],#datalib_shapedef~data_entry_ptr,<pDataEntry
                            getptr [<pDataEntry],#datalib_data_entry~type_ptr,<pTypeEntry
                            getptr [<pTypeEntry],#datalib_type_entry~library_ptr,<pLibrary
; Get the palette
                            pushptr <pLibrary
                            pushdword #datalib_type_PALT
                            pushptr [<pShape],#shapedef~metadata_id
                            pushsword #datalib_load_options~none             ; Just force a pre-load
                            jsl datalib_library_get_data_ptr
                            bcs exit
                            putretptr <pPalette

                            clc
exit                        retkc 4:pPalette
null_pointer                sec
                            bra exit
                            end

