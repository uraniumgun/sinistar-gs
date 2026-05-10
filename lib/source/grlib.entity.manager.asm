                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/fixed.buffer.pool.definitions.asm
                                copy lib/source/grlib.definitions.asm
                                copy lib/source/grlib.sprite.definitions.asm
                                copy lib/source/framelib.definitions.asm
                                copy lib/source/grlib.entity.definitions.asm
                                mcopy generated/grlib.entity.manager.macros

                                longa on
                                longi on

; --------------------------------------------------------------------------------------------
grlib_entity_manager_data       data seg_grlib

; Entity Manager object
grlib_entity_manager~pool       gequ 0
sizeof~grlib_entity_manager     gequ grlib_entity_manager~pool+sizeof~fixed_buffer_pool

global_grlib_entity_manager_is_initialized dc i'0'

; The global entity manager
global_grlib_entity_manager     ds sizeof~grlib_entity_manager

                                end
; --------------------------------------------------------------------------------------------
grlib_entity_manager_errors     data seg_grlib

grlib_entity_manager_error_none equ 0
grlib_entity_manager_error_null_pointer equ system_id_grlib_entity_manager+1
grlib_entity_manager_error_allocation equ system_id_grlib_entity_manager+2
grlib_entity_manager_error_not_managed equ system_id_grlib_entity_manager+3
grlib_entity_manager_error_invalid_parameter equ system_id_grlib_entity_manager+4

grlib_entity_manager_msg_pool_capacity_error anop
                                dw 'grlib_entity_manager: Pool capacity Error'
grlib_entity_manager_msg_pool_index_error anop
                                dw 'grlib_entity_manager: Pool index error'
grlib_entity_manager_msg_pool_allocation_error anop
                                dw 'grlib_entity_manager: Allocation error'
grlib_entity_manager_msg_pool_no_pool_available anop
                                dw 'grlib_entity_manager: No pool available for requested size'
                                end

; --------------------------------------------------------------------------------------------
; Initialize the global entity manager.
; This will allocate the global_grlib_entity_manager object and make it ready for use.
; It will allocate a pool for managing entity instances.
; Having the manager allocate entity instances, rather than just using the sba,
; allows for better tracking, as these will be the most pref-intensive objects of the application.
;
; Note that this manager provides the fixed buffer object for the entities, however the allocation
; and deallocation is done in the grlib.entity.asm file, using grlib_entity_new and grlib_entity_delete
;
grlib_entity_manager_initialize start seg_grlib
                                using grlib_entity_manager_data

                                debugtag 'initialize'
                                debugtag 'grlib_entity_manager'

                                lda >global_grlib_entity_manager_is_initialized
                                bne is_initialized

                                pushptr #global_grlib_entity_manager
                                pushsword #32                                ; 32 entitys per block.
                                jsl grlib_entity_manager_construct
                                bne error

                                lda #1
                                sta >global_grlib_entity_manager_is_initialized

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
grlib_entity_manager_uninitialize start seg_grlib
                                using grlib_entity_manager_data

                                debugtag 'uninitialize'
                                debugtag 'grlib_entity_manager'

                                lda >global_grlib_entity_manager_is_initialized
                                beq exit

                                pushptr #global_grlib_entity_manager
                                jsl grlib_entity_manager_destruct

                                lda #0
                                sta >global_grlib_entity_manager_is_initialized

exit                            anop
                                rtl

                                end
; --------------------------------------------------------------------------------------------
; Make a new grlib_entity_manager.
; This does not allocate any internal pools.  Use grlib_entity_manager_add_pool to add some before using.
;
; Params:
; pThis                 - the entity manager
; wBlockCapacity        - the number of entities per block allocation
; Returns:
; 0 on success or an error result.
grlib_entity_manager_construct  start seg_grlib
                                using grlib_entity_manager_data
                                using grlib_entity_manager_errors

                                debugtag 'construct'
                                debugtag 'grlib_entity_manager'

; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                sub (4:pThis,2:wBlockCapacity),work_area_size

                                testptr <pThis
                                beq null_pointer

                                pushptr <pThis,#grlib_entity_manager~pool
                                pushsword #sizeof~grlib_entity
                                lda <wBlockCapacity
                                bne ok_capacity
                                lda #32                                             ; Use an input of 0 as a signal to use the default.
ok_capacity                     pha
                                jsl fixed_buffer_pool_construct
                                bne allocation_error

exit                            anop
allocation_error                anop
                                sta <result
                                ret 2:result
null_pointer                    lda #grlib_entity_manager_error_null_pointer
                                bra exit
param_error                     lda #grlib_entity_manager_error_invalid_parameter
                                bra exit
                                end
; --------------------------------------------------------------------------------------------
; Destruct a entity manager.  All allocated entities will become invalid!
;
; Params:
; pThis                 - the entity manager
grlib_entity_manager_destruct   start seg_grlib
                                using grlib_entity_manager_data

                                debugtag 'destruct'
                                debugtag 'grlib_entity_manager'
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq exit

                                pushptr <pThis,#grlib_entity_manager~pool
                                jsl fixed_buffer_pool_destruct

exit                            anop
                                ret
                                end
