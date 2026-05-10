                        copy lib/source/debug.definitions.asm
                        copy 13/Ainclude/E16.Memory
                        copy lib/source/system.ids.asm
                        copy lib/source/std.definitions.asm
                        mcopy generated/memory.support.macros

                        longa on
                        longi on

; --------------------------------------------------------------------------------------------
memory_manager_data     data seg_memlib
                        aif C:debug~os_memory_tracking=0,.skip
memlib~os_allocation_count  dc i'0'
memlib~os_allocation_size   dc i4'0'
.skip
                        end
; --------------------------------------------------------------------------------------------
; Zero out a block of memory
; Params:
; pMemory   - (4 bytes) pointer to the memory to zero out
; size      - (2 bytes) size of the memory block
zero_memory             start seg_memlib

                        debugtag 'zero_memory'
                        sub (4:pMemory,2:size),0

                        lda <pMemory
                        ora <pMemory+2
                        beq error_exit

                        lda <size
                        beq exit
                        bit #1
                        bne odd
; We know it is even and at least 2, we can do words
                        tay
                        lda #0
word_loop               anop
                        dey
                        dey
                        sta [<pMemory],y
                        bne word_loop
                        bra exit
odd                     anop
; Odd, and at least one
                        tay
                        lda #0
                        dey
                        shortm
                        sta [<pMemory],y            ; Do end byte
                        longm
                        beq exit                    ; y == 0?
; Even, at least 2
word_loop2              anop
                        dey
                        dey
                        sta [<pMemory],y
                        bne word_loop2

exit                    anop
error_exit              anop
                        ret
                        end

; --------------------------------------------------------------------------------------------
; Fill a block of memory with a 2-byte pattern.
; Params:
; pMemory       - (4 bytes) pointer to the memory to zero out
; size          - (2 bytes) size of the memory block. Does not have to be an even number.
; fill_pattern  - (2 bytes) fill byte
fill_memory_2           start seg_memlib
                        debugtag 'fill_memory2'
                        sub (4:pMemory,2:size,2:fill_pattern),0

                        lda <pMemory
                        ora <pMemory+2
                        beq error_exit

                        lda <size
                        beq exit
                        bit #1
                        bne odd
; We know it is even and at least 2, we can do words
                        tay
                        lda <fill_pattern
word_loop               anop
                        dey
                        dey
                        sta [<pMemory],y
                        bne word_loop
                        bra exit
odd                     anop
; Because this is going backward, the fill patten isn't going to quite be what the user is expecting.  Fix this.
; Odd, and at least one
                        tay
                        lda <fill_pattern
                        dey
                        shortm
                        sta [<pMemory],y            ; Do end byte
                        longm
                        beq exit                    ; y == 0?
; Even, at least 2
word_loop2              anop
                        dey
                        dey
                        sta [<pMemory],y
                        bne word_loop2

exit                    anop
error_exit              anop
                        ret
                        end

; --------------------------------------------------------------------------------------------
; Copy a block of memory
; Might be nice to use the mvn/mvp, inlined, but the fact that you have to have the src/dest
; banks at compile time (or self-modifying) seems clunky if you want a generic move to anywhere
; Note, this does not deal with overlapping memory.
; No, this is not the quickest thing in the world, but it checks for null, etc.
; if speed is necessary, use mvn/mvp with self-modifying code, etc.
;
; Params:
; pSrc      - (4 bytes) pointer to the memory to move from
; pDest     - (4 bytes) pointer to the memory to move from
; size      - (2 bytes) size of the memory block
copy_memory             start seg_memlib

                        debugtag 'copy_memory'
                        sub (4:pSrc,4:pDest,2:size),0

                        lda <pSrc
                        ora <pSrc+2
                        beq error_exit

                        lda <pDest
                        ora <pDest+2
                        beq error_exit

                        lda <size
                        beq exit
                        bit #1
                        bne odd
; We know it is even and at least 2, we can do words
                        tay
word_loop               anop
                        dey
                        dey
                        lda [<pSrc],y
                        sta [<pDest],y
                        cpy #0
                        bne word_loop
                        bra exit
odd                     anop
; Odd, and at least one
                        tay
                        shortm
                        lda [<pSrc]
                        sta [<pDest]
                        longm
                        cpy #1
                        beq exit
; Odd, and at least 3
word_loop2              anop
                        dey
                        dey
                        lda [<pSrc],y
                        sta [<pDest],y
                        cpy #1
                        bne word_loop2

exit                    anop
error_exit              anop
                        ret
                        end

; --------------------------------------------------------------------------------------------
; Fill a memory with random bytes (slowly)
; Params:
; pMemory       - (4 bytes) pointer to the memory to zero out
; size          - (2 bytes) size of the memory block. Does not have to be an even number.
scramble_memory         start seg_memlib

                        debugtag 'scramble_memory'
                        sub (4:pMemory,2:size),0

                        lda <pMemory
                        ora <pMemory+2
                        beq error_exit

                        lda <size
                        beq exit
                        bit #1
                        bne odd

; We know it is even and at least 2, we can do words
                        tay
word_loop               jsl math~rnd_generate
                        dey
                        dey
                        sta [<pMemory],y
                        bne word_loop
                        bra exit
odd                     anop
                        tay
                        jsl math~rnd_generate
                        dey
                        shortm
                        sta [<pMemory],y            ; Do end byte
                        longm
                        beq exit                    ; y == 0?
; Even, at least 2
word_loop2              jsl math~rnd_generate
                        dey
                        dey
                        sta [<pMemory],y
                        bne word_loop2

exit                    anop
error_exit              anop
                        ret
                        end

; -------------------------------------------------------------------------------------------
; Allocate a handle from the system
; This is a simpler interface, for the type of handles we use the most.
; Locked, no bank crossing, no special memory and 64k or less (word size)
; Pass in the requested size in the acc and the handle will be returned in
; the A/X (low/high)
allocate_fixed_handle   start seg_memlib
                        using applib_data

                        debugtag 'allocate_fixed_handle'

                        aif C:debug~scramble_allocations=0,.no_scramble

                        begin_locals
result                  decl ptr
wSize                   decl word
work_area_size          end_locals

                        tax                 ; save the size in x, sub doesn't change that.
                        sub ,work_area_size

; Support scrambling the contents of the allocation
                        stx <wSize

                        pushdword #0         ; result
                        pushsword #0         ; high-word of the size
                        phx                  ; low-word of the size.
                        pushsword >applib~MM_ID
                        pushsword #attrLocked+attrNoCross+attrNoSpec       ;locked, no crossing banks, no special
                        pushdword #0         ; no fixed address
                        _NewHandle
                        tay                 ; save toolbox error
                        pla                 ; low-word of the result
                        plx                 ; high-word of the result
                        putretptr <result
                        bcs error
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        jsl track_os_allocation
.no_tracking
                        pushptr [<result],#0    ; push the dereferenced pointer
                        pushsword <wSize
                        jsl scramble_memory
                        clc
exit                    retkc 4:result
error                   lda #memory_error_allocation
                        jsl system_error_handle_toolbox_error
                        bra exit
                        ago .skip

.no_scramble
                        pushdword #0         ; result
                        pushsword #0         ; high-word of the size
                        pha                 ; low-word of the size.  Note, we know that the above pushes generate PEA instructions, so A is still what was passed in.
                        pushsword >applib~MM_ID
                        pushsword #attrLocked+attrNoCross+attrNoSpec       ;locked, no crossing banks, no special
                        pushdword #0         ; no fixed address
                        _NewHandle
                        tay                 ; save toolbox error
                        pla                 ; low-word of the result
                        plx                 ; high-word of the result
                        bcc ok              ; good result?
                        lda #memory_error_allocation
                        jsl system_error_handle_toolbox_error
                        lda #0
                        tax
                        rtl
ok                      anop
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        jsl track_os_allocation
.no_tracking
                        rtl                 ; carry will be preserved from the _NewHandle call
.skip
                        end

; -------------------------------------------------------------------------------------------
; Deallocate a fixed handle.  This will work with any OS handle, but having this
; makes the API consistent.
; This will check for null, so it is safe to call if the handle wasn't allocated
deallocate_fixed_handle  start seg_memlib
                        debugtag 'deallocate_fixed_handle'
; Check for null
                        cmp #0
                        bne dispose
                        cpx #0
                        beq exit

dispose                 anop
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        jsl track_os_deallocation
.no_tracking

                        phx
                        pha
                        _DisposeHandle
                        rtl

exit                    clc
                        rtl
                        end

; -------------------------------------------------------------------------------------------
; Allocate a handle from the system
; This is similar to allocate_fixed_handle, except it takes a 32-bit value, and so, will attempt
; to allocate something larger than 64k, if requested.
; The input can be smaller that 64k, and if it is, the functionality will be the same as
; allocate_fixed_handle, where it will ask for something that does not cross a bank boundary.
; Pass in the requested size in the acc and the handle will be returned in
; the A/X (low/high)
allocate_long_fixed_handle start seg_memlib
                        using applib_data

                        debugtag 'allocate_long_fixed_handle'

                        cpx #0
                        beq less_than_64k

; greater than 64k, allow for bank crossing.
                        pushdword #0         ; result
                        phx                 ; high-word of the size
                        pha                 ; low-word of the size.  Note, we know that the above pushes generate PEA instructions, so A is still what was passed in.
                        pushsword >applib~MM_ID
                        pushsword #attrLocked+attrNoSpec+attrNoPurge       ;locked, no special
                        pushdword #0         ; no fixed address
                        _NewHandle
                        tay                 ; save toolbox error
                        pla                 ; low-word of the result
                        plx                 ; high-word of the result
                        bcc ok
                        lda #memory_error_allocation
                        jsl system_error_handle_toolbox_error
                        lda #0
                        tax
                        rtl
ok                      anop
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        jsl track_os_allocation
.no_tracking
                        rtl                 ; carry will be preserved from the _NewHandle call

less_than_64k           anop
                        pushdword #0         ; result
                        pushsword #0         ; high-word of the size
                        pha                 ; low-word of the size.  Note, we know that the above pushes generate PEA instructions, so A is still what was passed in.
                        pushsword >applib~MM_ID
                        pushsword #attrLocked+attrNoCross+attrNoSpec+attrNoPurge       ;locked, no crossing banks, no special
                        pushdword #0         ; no fixed address
                        _NewHandle
                        tay                 ; save toolbox error
                        pla                 ; low-word of the result
                        plx                 ; high-word of the result
                        bcc ok
                        lda #memory_error_allocation
                        jsl system_error_handle_toolbox_error
                        lda #0
                        tax
                        rtl                 ; carry will be preserved from the _NewHandle call
                        end

; -------------------------------------------------------------------------------------------
; Deallocate a long fixed handle.  This is the same as allocate_long_fixed_handle, and added
; to make the API consistent.
; This will check for null, so it is safe to call if the handle wasn't allocated
deallocate_long_fixed_handle start seg_memlib
                        debugtag 'deallocate_long_fixed_handle'
; Check for null
                        cmp #0
                        bne dispose
                        cpx #0
                        beq exit

dispose                 anop
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        jsl track_os_deallocation
.no_tracking

                        phx
                        pha
                        _DisposeHandle
                        rtl

exit                    clc
                        rtl
                        end

; -------------------------------------------------------------------------------------------
; Deallocate a long fixed handle, by its pointer.
; This will check for null, so it is safe to call if the handle wasn't allocated
deallocate_long_fixed_handle_ptr start seg_memlib
                        debugtag 'deallocate_fixed_handle'

; Check for null
                        cmp #0
                        bne dispose
                        cpx #0
                        beq exit

dispose                 pea $0000                               ; Result
                        pea $0000
                        phx
                        pha
                        _FindHandle
                        bcs error_exit
; Dispose of the handle
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        pla
                        plx
                        jsl track_os_deallocation
                        phx
                        pha
.no_tracking
                        _DisposeHandle

exit                    rtl

error_exit              pla
                        plx
                        rtl
                        end
; -------------------------------------------------------------------------------------------
; Create a new std_allocation
; Returns:
; carry clear if successful, set if failed.
std_allocation_construct_with_size start seg_memlib
                        using applib_data
; Define our work area data
                        begin_locals
pTemp                   decl ptr
work_area_size          end_locals

                        debugtag 'construct_with_size'
                        debugtag 'std_allocation'
                        sub (4:pThis,2:iSize),work_area_size

                        pushdword #0         ; result
                        pushsword #0         ; high-word of the size
                        pushsword <iSize     ; low word
                        pushsword >applib~MM_ID
                        pushsword #attrLocked+attrNoCross+attrNoSpec       ;locked, no crossing banks, no special
                        pushdword #0         ; no fixed address
                        _NewHandle
                        tay                 ; save toolbox error
                        pulllong <pTemp
                        bcs error
                        aif C:debug~os_memory_tracking=0,.no_tracking
                        tax
                        lda <pTemp
                        jsl track_os_allocation
.no_tracking

                        lda <pTemp
                        ldy #std_system_allocation~handle
                        sta [<pThis],y
                        lda <pTemp+2
                        ldy #std_system_allocation~handle+2
                        sta [<pThis],y

                        lda [<pTemp]
                        ldy #std_system_allocation~ptr
                        sta [<pThis],y
                        ldy #2
                        lda [<pTemp],y
                        ldy #std_system_allocation~ptr+2
                        sta [<pThis],y

error_exit              anop
                        retkc

error                   lda #memory_error_allocation
                        jsl system_error_handle_toolbox_error
                        bra error_exit
                        end

; -------------------------------------------------------------------------------------------
; Create a new std_allocation
std_allocation_destruct   start seg_memlib
; Define our work area data
                        begin_locals
work_area_size          end_locals

                        debugtag 'destruct'
                        debugtag 'std_allocation'
                        sub (4:pThis),work_area_size
                        getword [<pThis],#std_system_allocation~handle+2
                        tax
                        getword [<pThis],#std_system_allocation~handle
                        jsl deallocate_fixed_handle
; Do a clear here, for saftey?
                        bcs error
exit                    anop
                        ret
error                   anop
;                       assert_carry_clear
                        bra exit
                        end
; -------------------------------------------------------------------------------------------
; Construct an empty std_allocation object
std_allocation_construct  start seg_memlib
                        debugtag 'construct'
                        debugtag 'std_allocation'
                        sub (4:pThis),0
; Clear things out
                        lda #0
                        ldy #std_system_allocation~handle
                        sta [<pThis],y
                        ldy #std_system_allocation~handle+2
                        sta [<pThis],y
                        ldy #std_system_allocation~ptr
                        sta [<pThis],y
                        ldy #std_system_allocation~ptr+2
                        sta [<pThis],y
                        ret
                        end

; -------------------------------------------------------------------------------------------
std_allocation_copy_constructor  start seg_memlib
                        sub (4:pDest,4:pSrc),0

                        debugtag 'copy_constructor'
                        debugtag 'std_allocation'
                        brk
                        ret
                        end

; -------------------------------------------------------------------------------------------
std_allocation_move_constructor  start seg_memlib

                        debugtag 'move_constructor'
                        debugtag 'std_allocation'
                        sub (4:pDest,4:pSrc),0
; Bitwise-copy, and clear the source
                        ldy #std_system_allocation~handle
                        lda [<pSrc],y
                        sta [<pDest],y
                        lda #0
                        sta [<pSrc],y
                        ldy #std_system_allocation~handle+2
                        lda [<pSrc],y
                        sta [<pDest],y
                        lda #0
                        sta [<pSrc],y
                        ldy #std_system_allocation~ptr
                        lda [<pSrc],y
                        sta [<pDest],y
                        lda #0
                        sta [<pSrc],y
                        ldy #std_system_allocation~ptr+2
                        lda [<pSrc],y
                        sta [<pDest],y
                        lda #0
                        sta [<pSrc],y
                        ret
                        end

; -------------------------------------------------------------------------------------------
; Track an OS allocation
; Parameters:
; a/x reg - allocation handle
track_os_allocation     start seg_memlib
                        using memory_manager_data

                        debugtag 'track_os_allocation'

                        setlocaldatabank

                        php
                        pha
                        phx

                        pha
                        pha                     ; space for result
                        phx                     ; the handle
                        pha
                        _GetHandleSize
                        pla
                        plx
                        bcs error
; ok handle, increment the count and add the size to the total
                        inc memlib~os_allocation_count
                        clc
                        adc memlib~os_allocation_size
                        sta memlib~os_allocation_size
                        txa
                        adc memlib~os_allocation_size+2
                        sta memlib~os_allocation_size+2

error                   plx
                        pla
                        plp
                        restoredatabank
                        rtl
                        end

; -------------------------------------------------------------------------------------------
; Track an OS allocation
; Parameters:
; a/x reg - allocation handle
track_os_deallocation   start seg_memlib
                        using memory_manager_data

                        debugtag 'track_os_deallocation'

                        setlocaldatabank

                        php
                        pha
                        phx

                        pha
                        pha                     ; space for result
                        phx                     ; the handle
                        pha
                        _GetHandleSize
                        pla
                        plx
                        bcs error
; ok handle, decrement the count and add the negative size to the total
                        dec memlib~os_allocation_count
                        sta patch_low+1
                        stx patch_high+1

                        lda memlib~os_allocation_size
                        sec
patch_low               sbc #0
                        sta memlib~os_allocation_size
                        lda memlib~os_allocation_size+2
patch_high              sbc #0
                        sta memlib~os_allocation_size+2

error                   plx
                        pla
                        plp
                        restoredatabank
                        rtl
                        end
