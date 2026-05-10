                            copy lib/source/debug.definitions.asm
; Standard objects
std_objects                 data seg_memlib

; int16 object
std_object_int16            dc i'2'
                            dc a4'0'     ; No vtable
; int32 object
std_object_int32            dc i'4'
                            dc a4'0'     ; No vtable
; generic pointer object
std_object_ptr4             dc i'4'
                            dc a4'0'     ; No vtable

; vtable for the standard allocation object
std_allocation_vtable       anop
                            dc a4'std_allocation_construct'
                            dc a4'std_allocation_copy_constructor'
                            dc a4'std_allocation_move_constructor'
                            dc a4'std_allocation_destruct'

; generic locked handle object
; Since the IIgs memory manager deals with handles, but we mostly like pointers,
; this is a pair, that contains the pointer from a de-referenced handle, and the handle, which is locked.
std_object_system_allocation dc i'8'
                            dc a4'std_allocation_vtable'

                            end

; --------------------------------------------------------------------------------------------
std_errors                  data seg_memlib

std_error_none              equ 0
std_error_null_pointer      equ 1
std_error_allocation        equ 2

                            end

