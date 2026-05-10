; Structure layout for the generic object interface
; This file is meant to include (copy)
; Can't use a DATA section, because some of these equates provide a compile time size, and that needs to be a global equate, as DATA based equates are link-time
; Those can't be used by ds operators. Still wish I could do a proper 'struct' definition and have a sizeof style command.
;
; A simple generic vtable for objects.  This allows for containers to have a generic way to initialize/copy/move elements around
object_vtable_definition    gequ 0
object_constructor          gequ object_vtable_definition   ; default constructor for the object
object_copy_constructor     gequ object_constructor+4       ; copy constructor for the object
object_move_constructor     gequ object_copy_constructor+4  ; move constructor for the object
object_destructor           gequ object_move_constructor+4  ; destructor for the object
object_vtable_definition_object_size gequ object_destructor+4

; A generic object definition for the containers.  The size portion of the definition must be valid for containers, the vtable can be null, in which case default constructor/copy/move operations will be used
object_definition           gequ 0
object_definition~size      gequ object_definition          	; size of the object.  Keeping it 16-bit, since dealing with things larger that 64k is a pain.
object_definition~vtable    gequ object_definition~size+2	    ; vtable for the object
sizeof~object_definition 	gequ object_definition~vtable+4   ; size of the definition.  This must be last.

