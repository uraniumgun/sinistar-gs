                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/fixed.buffer.pool.definitions.asm
                                copy lib/source/grlib.sprite.definitions.asm
                                copy lib/source/grlib.entity.sort.definitions.asm

                                mcopy generated/grlib.entity.sort.entry.macros

                                longa on
                                longi on

; -----------------------------------------------------------------------------
grlib_entity_sort_entry_construct start seg_grlib
                                using grlib_global_data
                                using grlib_entity_manager_errors

                                debugtag 'sort_entry_construct'
                                debugtag 'grlib_entity'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size
                                testptr <pThis
                                beq null_pointer

                                setdatabanktoptr <pThis
                                ldx <pThis
                                putzero {x},#grlib_entity_sort_entry~prev_sptr
                                putzero {x},#grlib_entity_sort_entry~next_sptr
                                putzero {x},#grlib_entity_sort_entry~entity_ptr
                                putzero {x},#grlib_entity_sort_entry~entity_ptr+2
                                putzero {x},#grlib_entity_sort_entry~sort_value

                                restoredatabank

exit                            anop
                                retkc
null_pointer                    sec
                                bra exit

                                end

; -----------------------------------------------------------------------------
grlib_entity_sort_entry_destruct start seg_grlib
                                using grlib_global_data

                                debugtag 'sort_list_destruct'
                                debugtag 'grlib_entity'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

; This object doesn't own anything.  Could fill with debug values though.

exit                            ret

                                end

; --------------------------------------------------------------------------------------------
; Allocate a new grlib_entity_sort_entry object.
;
; Parameters:
; The sort list to allocate from
; Returns:
; if carry clear, the pointer to the object, will not be null
; if carry set, null
grlib_entity_sort_entry_new start seg_grlib

; Define our work area data
                            begin_locals
result                      decl ptr                                ; result value inside our local work area
work_area_size              end_locals

                            debugtag 'entry_new'
                            debugtag 'grlib_entity_sort'

                            sub (4:pList),work_area_size

                            pushptr <pList,#grlib_entity_sort_list~pool
                            jsl fixed_buffer_pool_alloc
                            bcs allocation_error
                            putretptr <result
                            pushretptr
                            jsl grlib_entity_sort_entry_construct
                            clc                                     ; no error
exit                        retkc 4:result
allocation_error            anop
                            clearptr <result
                            sec                                     ; error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Deallocate a grlib_entity_sort_entry object.
;
; Parameters:
; pThis             - the grlib_entity_sort_entry pointer.
; Returns:
; nothing
grlib_entity_sort_entry_delete start seg_grlib

                            begin_locals
work_area_size              end_locals

                            debugtag 'entry_delete'
                            debugtag 'grlib_entity_sort'

                            sub (4:pThis,4:pList),work_area_size

                            pushptr <pThis
                            jsl grlib_entity_sort_entry_destruct

                            pushptr <pList,#grlib_entity_sort_list~pool
                            pushptr <pThis
                            jsl fixed_buffer_pool_free

exit                        ret
                            end
