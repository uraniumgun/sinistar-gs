                        copy lib/source/debug.definitions.asm
                        copy 13/Ainclude/E16.Memory
                        copy lib/source/system.ids.asm
                        copy lib/source/object.definitions.asm
                        mcopy generated/object.support.macros

                        longa on
                        longi on

; -------------------------------------------------------------------------------------------
object_errors               data seg_memlib
object_error_none           equ 0
object_error_null_pointer   equ system_id_object+1
                            end
; --------------------------------------------------------------------------------------------
; Copy an array of objects from one array to another
; It is assumed that the source and destination arrays are the correct size
; It is assumed the destination is uninitialized memory.  If there were objects
; in the destination array before-hand, they should be destructed in a separate call!
;
; This will use the copy-constructor operation
;
; Params:
;	pObjectDef		- long pointer (4 bytes) to an object_definition
;	pSrc	        - source array start. Can be null, if size is 0
;	pDest	        - destination array start
;   wSize            - number of objects to copy (not bytes!) Can be 0
; Returns: acc - 0 on success, > 0 is error code.
object_copy_array       start seg_memlib
                        using object_errors

                        begin_locals
result                  decl word                                               ; result value inside our local work area
wObjectSize             decl word
pVTable                 decl ptr
pFunc                   decl ptr
work_area_size          end_locals

                        debugtag 'object_copy'
                        debugtag 'array'
                        sub (4:pObjectDef,4:pSrc,4:pDest,2:wSize),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

                        testptr <pObjectDef
                        jeq null_pointer

                        lda <wSize
                        jeq exit            ; zero sized copy just exits

                        testptr <pSrc
                        jeq null_pointer

                        testptr <pDest
                        jeq null_pointer

                        getword [<pObjectDef],#object_definition~size
                        sta <wObjectSize        ; byte size

                        getptr [<pObjectDef],#object_definition~vtable,<pVTable
                        ora <pVTable
                        beq no_vtable

                        getptr [<pVTable],#object_copy_constructor,<pFunc
                        ora <pFunc
                        beq no_vtable

copy_with_constructor_loop anop
; No such thing as jsl [<dp].  So I have two options, one is not so naughty, where I push a return value for here, then push another fake return value, to where I want to go to, then do an rtl here.
; That would be a bit of code, but 'safe'.  The other option is to patch the code.  Notice that I'm patching the code, each time through the loop, this is so that the patching
; is recursively safe.  It's not thread safe, but we aren't going to worry about that.

; Make a macro for this.
;                       patchjsl <pFunc,patch_to_copy
                        lda <pFunc
                        sta >patch_to_copy+1
                        shortm
                        lda <pFunc+2
                        sta >patch_to_copy+3
                        longm

                        pushptr <pDest
                        pushptr <pSrc
patch_to_copy           jsl >$000000
                        lda <wSize
                        dec a
                        sta <wSize
                        beq exit
; Make this a macro
;                       addwordtoptr <pSrc,<wObjectSize
;                       addwordtoptrnobank <pSrc,<wObjectSize        ; does not increment the bank, just does the lower 16 bits.
                        clc
                        lda <pSrc
                        adc <wObjectSize
                        sta <pSrc
                        lda <pSrc+2         ; Hmm, we are not really supposed to be crossing bank boundries.
                        adc #0
                        sta <pSrc+2
                        clc
                        lda <pDest
                        adc <wObjectSize
                        sta <pDest
                        lda <pDest+2         ; Hmm, we are not really supposed to be crossing bank boundries.
                        adc #0
                        sta <pDest+2
                        bra copy_with_constructor_loop

no_vtable               anop
; Do a bitwise copy
                        mul2 <wObjectSize,<wSize
                        pushptr <pSrc
                        pushptr <pDest
                        pushsword <wObjectSize
                        jsl copy_memory

exit                    anop
                        ret 2:result
null_pointer            anop
                        lda #object_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Move an array of objects from one array to another
; It is assumed that the source and destination arrays are the correct size
; It is assumed the destination is uninitialized memory.  If there were objects
; in the destination array before-hand, they should be destructed in a separate call!
;
; This will use the move-constructor operation
;
; Params:
;	pObjectDef		- long pointer (4 bytes) to an object_definition
;	pSrc	        - source array start. Can be null, if size is 0
;	pDest	        - destination array start
;   wSize            - number of objects to copy (not bytes!) Can be 0
; Returns: acc - 0 on success, > 0 is error code.
object_move_array       start seg_memlib
                        using object_errors

                        begin_locals
result                  decl word                                               ; result value inside our local work area
wObjectSize             decl word
pVTable                 decl ptr
pFunc                   decl ptr
work_area_size          end_locals

                        debugtag 'object_move'
                        debugtag 'array'
                        sub (4:pObjectDef,4:pSrc,4:pDest,2:wSize),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

                        lda <wSize
                        jeq exit            ; zero sized copy just exits

                        testptr <pSrc
                        jeq null_pointer

                        testptr <pDest
                        jeq null_pointer

                        testptr <pObjectDef
                        jeq null_pointer

                        getword [<pObjectDef],#object_definition~size
                        sta <wObjectSize        ; byte size

; Get the vtable
                        getptr [<pObjectDef],#object_definition~vtable,<pVtable
                        ora <pVTable
                        beq no_vtable

                        getptr [<pVtable],#object_move_constructor,<pFunc
                        ora <pFunc
                        beq no_vtable                   ; We should test to see if there is a copy constructor, and move with that, then delete the original.

copy_with_move_loop     anop
;                       patchjsl <pCopyFunc,patch_to_move
                        lda <pFunc
                        sta >patch_to_move+1
                        shortm
                        lda <pFunc+2
                        sta >patch_to_move+3
                        longm

                        pushptr <pDest
                        pushptr <pSrc
patch_to_move           jsl >$000000
                        lda <wSize
                        dec a
                        sta <wSize
                        beq exit                                    ; done?
; Make this a macro
;                       addwordtoptr <pSrc,<wObjectSize
;                       addwordtoptrnobank <pSrc,<wObjectSize        ; does not increment the bank, just does the lower 16 bits.
                        clc
                        lda <pSrc
                        adc <wObjectSize
                        sta <pSrc
                        lda <pSrc+2         ; Hmm, we are not really supposed to be crossing bank boundries.
                        adc #0
                        sta <pSrc+2
                        clc
                        lda <pDest
                        adc <wObjectSize
                        sta <pDest
                        lda <pDest+2         ; Hmm, we are not really supposed to be crossing bank boundries.
                        adc #0
                        sta <pDest+2
                        bra copy_with_move_loop

no_vtable               anop
; Do a bitwise copy
                        mul2 <wObjectSize,<wSize
                        pushptr <pSrc
                        pushptr <pDest
                        pushsword <wObjectSize
                        jsl copy_memory

exit                    anop
                        ret 2:result
null_pointer            anop
                        lda #object_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit

                        end

; --------------------------------------------------------------------------------------------
; Destruct an array of objects.  This calls the destructor on each member of the array
; It does NOT delete/free the array memory.
; If the object definition does not have a destructor, this function will do nothing.
;
; Params:
;	pObjectDef       - long pointer (4 bytes) to an object_definition
;	pArray	         - array start. Can be null, if size is 0
;   wSize            - number of objects in the array, can be 0
; Returns: acc - 0 on success, > 0 is error code.
object_destruct_array   start seg_memlib
                        using object_errors

                        begin_locals
result                  decl word                                                 ; result value inside our local work area
wObjectSize             decl word
pVTable                 decl ptr
pDestructorFunc         decl ptr
work_area_size          end_locals

                        debugtag 'object_destruct'
                        debugtag 'array'
                        sub (4:pObjectDef,4:pArray,2:wSize),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

                        testptr <pObjectDef
                        jeq null_pointer

                        lda <wSize
                        jeq exit            ; zero sized copy just exits

                        testptr <pArray
                        jeq null_pointer

                        getword [<pObjectDef],#object_definition~size
                        sta <wObjectSize        ; byte size
                        jeq exit                ; zero sized object just exits

                        getptr [<pObjectDef],#object_definition~vtable,<pVTable
                        ora <pVTable
                        beq no_vtable

                        getptr [<pVTable],#object_destructor,<pDestructorFunc
                        ora <pDestructorFunc
                        beq no_vtable

; No such thing as jsl [<dp].  So I have two options, one is not so naughty, where I push a return value for here, then push another fake return value, to where I want to go to, then do an rtl here.
; That would be a bit of code, but 'safe'.  The other option is to patch the code.  Notice that I'm patching the code, each time through the loop, this is so that the patching
; is recursively safe.  It's not thread safe, but we aren't going to worry about that.

delete_with_destructor_loop anop
; Patch every time through loop to avoid recursion issues!
                        lda <pDestructorFunc
                        sta >patch_to_destructor+1
                        shortm
                        lda <pDestructorFunc+2
                        sta >patch_to_destructor+3
                        longm

                        pushptr <pArray
patch_to_destructor     jsl >$000000
                        lda <wSize
                        dec a
                        sta <wSize
                        beq exit

                        clc
                        lda <pArray
                        adc <wObjectSize
                        sta <pArray
                        lda <pArray+2         ; Hmm, we are not really supposed to be crossing bank boundries.
                        adc #0
                        sta <pArray+2
                        bra delete_with_destructor_loop

no_vtable               anop
exit                    anop
                        ret 2:result
null_pointer            anop
                        lda #object_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Destruct an array of *pointers* to objects.
; This calls the destructor on each member of the array and will then
; call sba_free on the pointer at the array location.
; The pointer in the array can be null and will be skipped.
; The pointer at the array location will be set to null.

; This does NOT delete/free the array memory itself
;
;
; Params:
;	pObjectDef       - long pointer (4 bytes) to an object_definition
;	pArray	         - array start. Can be null, if size is 0
;   wSize            - number of objects in the array, can be 0
; Returns: acc - 0 on success, > 0 is error code.
object_destruct_ptr_array   start seg_memlib
                        using object_errors

                        begin_locals
result                  decl word                                                 ; result value inside our local work area
pVTable                 decl ptr
pDestructorFunc         decl ptr
pObject                 decl ptr
work_area_size          end_locals

                        debugtag 'object_destruct'
                        debugtag 'ptr_array'
                        sub (4:pObjectDef,4:pArray,2:wSize),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

                        testptr <pObjectDef
                        jeq null_pointer

                        lda <wSize
                        jeq exit                ; zero sized array just exits

                        testptr <pArray
                        jeq null_pointer

                        getptr [<pObjectDef],#object_definition~vtable,<pVTable
                        ora <pVTable
                        beq no_vtable

                        getptr [<pVtable],#object_destructor,<pDestructorFunc
                        ora <pDestructorFunc
                        beq no_vtable

; No such thing as jsl [<dp].  So I have two options, one is not so naughty, where I push a return value for here, then push another fake return value, to where I want to go to, then do an rtl here.
; That would be a bit of code, but 'safe'.  The other option is to patch the code.  Notice that I'm patching the code, each time through the loop, this is so that the patching
; is recursively safe.  It's not thread safe, but we aren't going to worry about that.

delete_with_destructor_loop anop
                        getptr [<pArray],#0,<pObject
                        ora <pObject
                        beq next_in_destructor_loop     ; Can be null, we will just skip
; Clear the entry first
                        lda #0
                        sta [<pArray]
                        sta [<pArray],y                 ; Note, assuming y still has a #2 in it from the above

; Patch the call.  Note, we must do this every time in the loop, because we could be recursively called!
                        lda <pDestructorFunc
                        sta >patch_to_destructor+1
                        shortm
                        lda <pDestructorFunc+2
                        sta >patch_to_destructor+3
                        longm
; Call the destructor
                        pushptr <pObject
patch_to_destructor     jsl >$000000
; Free the allocation
                        pushptr <pObject
                        jsl sba_free
next_in_destructor_loop anop
                        lda <wSize
                        dec a
                        sta <wSize
                        beq exit

                        clc
                        lda <pArray
                        adc #4
                        sta <pArray
                        lda <pArray+2         ; Hmm, we are not really supposed to be crossing bank boundries.
                        adc #0
                        sta <pArray+2
                        bra delete_with_destructor_loop

no_vtable               anop
free_loop               anop
                        lda [<pArray]
                        sta <pObject
                        ldy #2
                        lda [<pArray],y
                        sta <pObject+2
                        ora <pObject
                        beq next_in_free_loop     ; Can be null, we will just skip
; Clear the entry first
                        lda #0
                        sta [<pArray]
                        sta [<pArray],y         ; Assuming y still has a 2 in it.
; Call the destructor
                        pushptr <pObject
                        jsl sba_free

next_in_free_loop       anop
                        lda <wSize
                        dec a
                        sta <wSize
                        beq exit

                        clc
                        lda <pArray
                        adc #4
                        sta <pArray
                        lda <pArray+2         ; Hmm, we are not really supposed to be crossing bank boundries.
                        adc #0
                        sta <pArray+2
                        bra free_loop

exit                    anop
                        ret 2:result
null_pointer            anop
                        lda #object_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Fill an array with default constructed objects
; It is assumed that the destination array is the correct size
; It is assumed the destination is uninitialized memory.  If there were objects
; in the destination array before-hand, they should be destructed in a separate call!
;
; Params:
;	pObjectDef		- long pointer (4 bytes) to an object_definition
;	pDest	        - destination array start
;   wSize           - number of objects to create. Can be 0
; Returns: acc - 0 on success, > 0 is error code.
object_fill_array       start seg_memlib
                        using object_errors

                        begin_locals
result                  decl word                                                 ; result value inside our local work area
wObjectSize             decl word
pVTable                 decl ptr
pFunc                   decl ptr
work_area_size          end_locals

                        debugtag 'object_fill'
                        debugtag 'array'
                        sub (4:pObjectDef,4:pDest,2:wSize),work_area_size         ; Parameters, plus the amount of space for our local work area

                        stz <result

                        testptr <pObjectDef
                        jeq null_pointer

                        lda <wSize
                        jeq exit            ; zero sized copy just exits

                        testptr <pDest
                        jeq null_pointer

                        getword [<pObjectDef],#object_definition~size
                        sta <wObjectSize        ; byte size

                        getptr [<pObjectDef],#object_definition~vtable,<pVTable
                        ora <pVTable
                        beq no_vtable

                        getptr [<pVTable],#object_constructor,<pFunc
                        ora <pFunc
                        beq no_vtable

fill_with_constructor_loop anop
; No such thing as jsl [<dp].  So I have two options, one is not so naughty, where I push a return value for here, then push another fake return value, to where I want to go to, then do an rtl here.
; That would be a bit of code, but 'safe'.  The other option is to patch the code.  Notice that I'm patching the code, each time through the loop, this is so that the patching
; is recursively safe.  It's not thread safe, but we aren't going to worry about that.

; Make a macro for this.
;                       patchjsl <pFunc,patch_to_copy
                        lda <pFunc
                        sta >patch_to_construct+1
                        shortm
                        lda <pFunc+2
                        sta >patch_to_construct+3
                        longm

                        pushptr <pDest
patch_to_construct      jsl >$000000
                        lda <wSize
                        dec a
                        sta <wSize
                        beq exit
; Next destination
                        clc
                        lda <pDest
                        adc <wObjectSize
                        sta <pDest
                        lda <pDest+2         ; Hmm, we are not really supposed to be crossing bank boundries.
                        adc #0
                        sta <pDest+2
                        bra fill_with_constructor_loop

no_vtable               anop
; Well, what to do here.  Hmm.  In C/C++, it would do nothing, as there is an assumption that the memory will be almost
; immediately filled in with 'real' values and we shouldn't waste time setting it to 0, etc.
; Filling to 0, also sets a precident of memory being in a 'known' initialized state, and we would not be able to go back.
; I'm going to fill memory here, at least for now and using $CC, to detect using uninitialized memory.
; Maybe only do this in debug?
                        mul2 <wObjectSize,<wSize
                        pushptr <pDest
                        pushsword <wObjectSize
                        pushsword #$CCCC
                        jsl fill_memory_2

exit                    anop
                        ret 2:result
null_pointer            anop
                        lda #object_error_null_pointer
error_exit              anop
                        sta <result
                        bra exit
                        end

; --------------------------------------------------------------------------------------------
; Allocate a new object.
; This will allocate from the sba and call any constructor.
; This does preclude the object from using a custom allocator if allocated in the fashion.
; Might want to extend the vtable to include new and delete function pointers.
;
; Parameters:
; pObjectDef        - the object defintion.
; Returns:
; if carry clear, the pointer to the object, will not be null
; if carry set, null
object_new                  start seg_memlib
                            using object_errors

                            begin_locals
result                      decl ptr                                ; result value inside our local work area
pVTable                     decl ptr
pFunc                       decl ptr
work_area_size              end_locals

                            debugtag 'object_new'

                            sub (4:pObjectDef),work_area_size

                            testptr <pObjectDef
                            beq allocation_error

                            getword [<pObjectDef],#object_definition~size
                            beq allocation_error
                            pha
                            jsl sba_alloc
                            bcs allocation_error
                            putretptr <result

                            getptr [<pObjectDef],#object_definition~vtable,<pVTable
                            ora <pVTable
                            beq no_vtable

                            getptr [<pVTable],#object_constructor,<pFunc
                            ora <pFunc
                            beq no_vtable

                            lda <pFunc
                            sta >patch_to_construct+1
                            shortm
                            lda <pFunc+2
                            sta >patch_to_construct+3
                            longm

                            pushptr <result
patch_to_construct          jsl >$000000

no_vtable                   clc                                     ; no error
exit                        retkc 4:result
allocation_error            anop
                            clearptr <result
                            sec                                     ; error
                            bra exit
                            end

; --------------------------------------------------------------------------------------------
; Deallocate an object.
;
; Parameters:
; pThis             - the object pointer
; pObjectDef        - the object's definition.
; Returns:
; nothing
object_delete               start seg_memlib
                            using object_errors

                            begin_locals
pVTable                     decl ptr
pFunc                       decl ptr
work_area_size              end_locals

                            debugtag 'object_delete'

                            sub (4:pThis,4:pObjectDef),work_area_size

                            testptr <pThis
                            beq null_pointer

                            testptr <pObjectDef
                            beq null_pointer

                            getptr [<pObjectDef],#object_definition~vtable,<pVTable
                            ora <pVTable
                            beq no_vtable

                            getptr [<pVTable],#object_destructor,<pFunc
                            ora <pFunc
                            beq no_vtable

                            lda <pFunc
                            sta >patch_to_destruct+1
                            shortm
                            lda <pFunc+2
                            sta >patch_to_destruct+3
                            longm

                            pushptr <pThis
patch_to_destruct           jsl >$000000

no_vtable                   pushptr <pThis
                            jsl sba_free
null_pointer                clc                                     ; no error
exit                        retkc
error                       anop
                            assert_brk 'object_delete'
                            sec                                     ; error
                            bra exit
                            end
