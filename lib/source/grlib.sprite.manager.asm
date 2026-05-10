                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            mcopy generated/grlib.sprite.manager.macros

                            longa on
                            longi on

; --------------------------------------------------------------------------------------------
sprite_manager_data             data seg_grlib

; Sprite Manager object
sprite_manager~pool             gequ 0
sizeof~sprite_manager           gequ sprite_manager~pool+sizeof~fixed_buffer_pool

global_sprite_manager_is_initialized dc i'0'

; The global sprite manager
global_sprite_manager           ds sizeof~sprite_manager

                                end
; --------------------------------------------------------------------------------------------
sprite_manager_errors           data seg_grlib

sprite_manager_error_none           equ 0
sprite_manager_error_null_pointer   equ system_id_sprite_manager+1
sprite_manager_error_allocation     equ system_id_sprite_manager+2
sprite_manager_error_not_managed    equ system_id_sprite_manager+3
sprite_manager_error_invalid_parameter equ system_id_sprite_manager+4

sprite_manager_msg_pool_capacity_error dw 'sprite_manager: Pool capacity Error'
sprite_manager_msg_pool_index_error dw 'sprite_manager: Pool index error'
sprite_manager_msg_pool_allocation_error dw 'sprite_manager: Allocation error'
sprite_manager_msg_pool_no_pool_available dw 'sprite_manager: No pool available for requested size'
                            end

; --------------------------------------------------------------------------------------------
; Initialize the global sprite manager.
; This will allocate the global_sprite_manager object and make it ready for use.
; It will allocate a pool for managing sprite instances.
; Having the manager allocate sprite instances, rather than just using the sba,
; allows for better tracking, as these will be the most pref-intensive objects of the application.
;
; Note that this manager provides the fixed buffer object for the sprites, however the allocation
; and deallocation is done in the grlib.sprite.asm file, using sprite_new and sprite_delete

sprite_manager_initialize       start seg_grlib
                                using sprite_manager_data

                                debugtag 'initialize'
                                debugtag 'sprite_manager'

                                lda >global_sprite_manager_is_initialized
                                bne is_initialized

                                pushptr #global_sprite_manager
                                pushsword #32                                ; 32 sprites per block.
                                jsl sprite_manager_construct
                                bne error

                                lda #1
                                sta >global_sprite_manager_is_initialized

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global sprite manager.
sprite_manager_uninitialize     start seg_grlib
                                using sprite_manager_data

                                debugtag 'uninitialize'
                                debugtag 'sprite_manager'

                                lda >global_sprite_manager_is_initialized
                                beq exit

                                pushptr #global_sprite_manager
                                jsl sprite_manager_destruct

                                lda #0
                                sta >global_sprite_manager_is_initialized

exit                            anop
                                rtl

                                end
; --------------------------------------------------------------------------------------------
; Make a new sprite_manager.
; This does not allocate any internal pools.  Use sprite_manager_add_pool to add some before using.
;
; Params:
; pThis                 - the sprite manager
; wBlockCapacity        - the number of sprites per block allocation
; Returns:
; 0 on success or an error result.
sprite_manager_construct        start seg_grlib
                                using sprite_manager_data
                                using sprite_manager_errors

                                debugtag 'construct'
                                debugtag 'sprite_manager'

; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                sub (4:pThis,2:wBlockCapacity),work_area_size

                                testptr <pThis
                                beq null_pointer

                                pushptr <pThis,#sprite_manager~pool
                                pushsword #sizeof~sprite
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
null_pointer                    lda #sprite_manager_error_null_pointer
                                bra exit
param_error                     lda #sprite_manager_error_invalid_parameter
                                bra exit
                                end
; --------------------------------------------------------------------------------------------
; Destruct a sprite manager.  All allocated sprites will become invalid!
;
; Params:
; pThis                 - the sprite manager
sprite_manager_destruct         start seg_grlib
                                using sprite_manager_data

                                debugtag 'destruct'
                                debugtag 'sprite_manager'
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq exit

                                pushptr <pThis,#sprite_manager~pool
                                jsl fixed_buffer_pool_destruct

exit                            anop
                                ret
                                end
