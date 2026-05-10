                    copy lib/source/debug.definitions.asm
                    copy lib/source/system.ids.asm
                    copy lib/source/object.definitions.asm
                    copy lib/source/string.definitions.asm
                    copy lib/source/container.definitions.asm
                    copy lib/source/file.definitions.asm
                    copy lib/source/datalib.constants.asm
                    copy lib/source/datalib.definitions.asm
                    copy lib/source/value.transform.definitions.asm
                    copy lib/source/input.constants.asm
                    copy lib/source/sndlib.definitions.asm
                    copy lib/source/grlib.definitions.asm

                    mcopy generated/unit.tests.macros

                    longa on
                    longi on

; Comment out, to disable unit tests
;debug~enable_unit_tests gequ 1

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_vector_test     start seg_tstlib
                    using std_objects

; Define our work area data
result              equ 1
pTemp               equ result+2
iTemp               equ pTemp+4
work_area_size      equ iTemp+2-1

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <result

                    pushptr #test_vector
                    pushptr #std_object_int16
                    jsl container_vector_construct

                    pushptr #test_vector
                    pushptr #test_int_data
                    jsl container_vector_copy_back

                    pushptr #test_vector
                    pushptr #test_int_data+2
                    jsl container_vector_copy_back

                    pushptr #test_vector
                    pushsword #0
                    jsl container_vector_data_at
                    jcs index_error
                    putretptr <pTemp

; Compare the source data to the destination data.  Makes the assumption that it is word data
                    ldx #2
                    jsr compare_data
                    jne push_error

; Increase the capacity
                    pushptr #test_vector
; We have a compile time address, so we can just do this, but it might be nice to have a macro, even if only to highlight that it is reading from an object.
;                   load_object_word test_vector,vector_definition~capacity
                    lda test_vector+vector_definition~capacity
                    clc
                    adc #16
                    sta <iTemp
                    pha
                    jsl container_vector_set_capacity
                    jne resize_error
                    lda test_vector+vector_definition~capacity
                    cmp <iTemp
                    jne resize_error
; Push a 3
                    pushptr #test_vector
                    pushptr #test_int_data+4
                    jsl container_vector_copy_back
; Push a 4
                    pushptr #test_vector
                    pushptr #test_int_data+6
                    jsl container_vector_copy_back

; Get the pointer to the vector again, it should have moved.
                    pushptr #test_vector
                    pushsword #0
                    jsl container_vector_data_at
                    jcs index_error
                    putretptr <pTemp
; Compare to the contents
                    ldx #4
                    jsr compare_data
                    jne push_error
; Pop the back
                    pushptr #test_vector
                    jsl container_vector_pop_back

                    pushptr #test_vector
                    pushptr #itr
                    jsl container_vector_back
                    jne index_error
; Get the pointer from the iterator
                    getptr itr+vector_iterator~ptr,<pTemp

                    lda [<pTemp]
                    cmp test_int_data+4             ; Should be equal to our 3rd entry
                    bne pop_error
; Push a 4
                    pushptr #test_vector
                    pushptr #test_int_data+6
                    jsl container_vector_copy_back
; Push a 5
                    pushptr #test_vector
                    pushptr #test_int_data+8
                    jsl container_vector_copy_back
; Get an iterator to the '4'
                    pushptr #test_vector
                    pushptr #itr
                    pushsword #3
                    jsl container_vector_at
; Erase the 4
                    pushptr #test_vector
                    pushptr #itr
                    jsl container_vector_erase
; The iterator should be pointing to the 5
                    getptr itr+vector_iterator~ptr,<pTemp
                    lda [<pTemp]
                    cmp test_int_data+8
                    bne erase_error

; Destruct what we made
                    pushptr #test_vector
                    jsl container_vector_destruct

                    lda #0
exit                anop
                    sta <result
                    lret 2:result

pop_error           anop
                    pushptr #str_pop_error
                    _DebugStr
                    lda #1
                    bra exit
push_error          anop
                    pushptr #str_push_error
                    _DebugStr
                    lda #1
                    bra exit
index_error         anop
                    pushptr #str_index_error
                    _DebugStr
                    lda #1
                    bra exit
resize_error        anop
                    pushptr #str_resize_error
                    _DebugStr
                    lda #1
                    bra exit
erase_error         anop
                    pushptr #str_erase_error
                    _DebugStr
                    lda #1
                    bra exit
; Compare X words with the temp pointer and the int test data.
compare_data        anop
                    ldy #0
compare_loop        lda [<pTemp],y
                    cmp test_int_data,y
                    bne compare_error
                    iny
                    iny
                    dex
                    bne compare_loop
compare_error       anop
                    rts

test_vector         ds sizeof~vector_definition
itr                 ds sizeof~vector_iterator

str_pop_error       dw "Vector Test - pop failed"
str_push_error      dw "Vector Test - push failed"
str_index_error     dw "Vector Test - index failed"
str_resize_error    dw "Vector Test - resize failed"
str_erase_error     dw "Vector Test - erase failed"

test_int_data       dc i'1'
                    dc i'2'
                    dc i'3'
                    dc i'4'
                    dc i'5'
                    end
.skip

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_zero_memory_test start seg_tstlib
                    using std_objects

                    ph4 #buffer
                    ph2 #1
                    jsl zero_memory

                    ph4 #buffer
                    ph2 #2
                    jsl zero_memory

                    ph4 #buffer
                    ph2 #15
                    jsl zero_memory

                    ph4 #buffer
                    ph2 #16
                    jsl zero_memory

                    rts

buffer              ds 16
                    end
.skip
; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_copy_memory_test start seg_tstlib
                    using std_objects

                    ph4 #buffer1
                    ph4 #buffer2
                    ph2 #1
                    jsl copy_memory

                    ph4 #buffer1
                    ph4 #buffer2
                    ph2 #2
                    jsl copy_memory

                    ph4 #buffer1
                    ph4 #buffer2
                    ph2 #15
                    jsl copy_memory

                    ph4 #buffer1
                    ph4 #buffer2
                    ph2 #16
                    jsl copy_memory

                    rts

buffer1             ds 16
buffer2             ds 16
                    end
.skip
; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_string_test     start seg_tstlib
                    using std_objects

; Define our work area data
                    begin_locals
result              decl word
pBuffer             decl ptr
pBlock              decl ptr
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <result

;                    pushptr #string_debug_break
;                    _DebugStr

                    pushptr #string1
;                   debugtag 'string new'
                    jsl string_object_construct

                    pushptr #string1
                    pushsword #16
;                   debugtag 'set capacity'
                    jsl string_object_set_capacity

                    pushptr #string1
                    pushptr #test_string_short_zt           ; This string will fit in the existing capacity
;                   debugtag 'copy zt short'
                    jsl string_object_copy_zt

                    pushptr #string1
                    pushptr #test_string_long_zt            ; This string will cause the capacity to increase
;                   debugtag 'copy zt long'
                    jsl string_object_copy_zt

                    pushptr #string1
                    pushptr #test_string_to_append_zt
;                   debugtag 'append zt'
                    jsl string_object_append_zt

                    pushptr #string2
;                   debugtag 'string new 2'
                    jsl string_object_construct

                    pushptr #string2
                    pushptr #string1
;                   debugtag 'copy 1 to 2'
                    jsl string_object_copy

                    pushptr #string2
                    pushptr #string1
;                   debugtag 'append 1 to 2'
                    jsl string_object_append

                    pushptr #string1
                    pushptr #string2
;                   debugtag 'move 2 to 1'
                    jsl string_object_move

                    pushptr #string1
;                   debugtag 'delete 1'
                    jsl string_object_destruct

                    pushptr #string2
;                   debugtag 'delete 2'
                    jsl string_object_destruct

                    lret 2:result

string1             ds sizeof~string_object
string2             ds sizeof~string_object

test_string_short_zt dc c'Test string zt'
                    dc i1'0'

test_string_long_zt dc c'Much longer test string to make the capacity increase zt'
                    dc i1'0'

test_string_to_append_zt dc c'Test string to append'
                    dc i1'0'

string_debug_break  dw "Unit Test String"
                    end
.skip
; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_sba_test        start seg_tstlib
                    using std_objects

; Define our work area data
                    begin_locals
result              decl word
pBuffer1            decl ptr
pBuffer2            decl ptr
pBuffer3            decl ptr
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <result

;                    pushptr #string_debug_break
;                    _DebugStr

                    debugtag 'alloc 1'
                    pushsword #16
                    jsl sba_alloc
                    bcs allocation_error1
                    sta <pBuffer1
                    stx <pBuffer1+2

                    debugtag 'alloc 2'
                    pushsword #32
                    jsl sba_alloc
                    bcs allocation_error2
                    sta <pBuffer2
                    stx <pBuffer2+2

                    debugtag 'alloc OS 8k'
                    pushsword #1024*8
                    jsl sba_alloc
                    bcs allocation_error3
                    sta <pBuffer3
                    stx <pBuffer3+2

exit3               anop
                    pushptr <pBuffer3
                    jsl sba_free

exit2               anop
                    pushptr <pBuffer2
                    jsl sba_free

exit1               anop
                    pushptr <pBuffer1
                    jsl sba_free

exit                anop
                    lret 2:result
allocation_error1   lda #1
                    sta <result
                    pushptr #str_allocation_failed
                    _DebugStr
                    bra exit
allocation_error2   lda #1
                    sta <result
                    pushptr #str_allocation_failed
                    _DebugStr
                    bra exit1
allocation_error3   lda #1
                    sta <result
                    pushptr #str_allocation_failed
                    _DebugStr
                    bra exit2

string_debug_break  dw "Unit Test SBA"
str_allocation_failed dw 'Allocation test failed'
                    end
.skip
; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_datalib_test    start seg_tstlib
                    using std_objects

; Define our work area data
                    begin_locals
result              decl word
pLibrary            decl ptr
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <result

                    pushptr #string_debug_break
                    _DebugStr

                    pushptr #pathname_string
                    pushptr #test_pathname
                    jsl string_object_construct_zt

                    pushptr #pathname_string
                    pushsword #datalib_preload_options~none
                    jsl datalib_manager_add_library
                    bcs failed_to_open
                    putretptr <pLibrary

                    pushptr <pLibrary
                    pushdword #datalib_type_TILE
                    pushdword #0
                    pushsword #datalib_load_options~reference
                    jsl datalib_library_get_data_ptr

                    pushptr <pLibrary
                    jsl datalib_manager_remove_library

exit                anop
                    pushptr #pathname_string
                    jsl string_object_destruct
                    lret 2:result

failed_to_open      anop
                    pushptr #str_failed_to_open
                    _DebugStr
                    lda #1
                    bra exit

pathname_string     ds sizeof~string_object

str_failed_to_open  dw 'Failed to open library'

string_debug_break  dw "Unit Test Datalib"

test_pathname       dc c':TRANSFER:RATMAN.DAT'
                    dc i1'0'

                    end
.skip
; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_value_transform_test start seg_tstlib
                    using std_objects
                    using value_transform_data

; Define our work area data
                    begin_locals
result              decl word
pNode               decl ptr
dwTick              decl long
wValue              decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <result
; Construct a transform
                    pushptr #test_transform
                    jsl value_transform_construct
; Add a lerp type
                    pushptr #test_transform
                    pushword #value_transform_node_type~lerp
                    jsl value_transform_append_node_type
                    jcs error
                    putretptr <pNode
; Setup the node
                    pushretptr
                    pushsword #0
                    pushsword #(10|8)
                    jsl value_transform_node_set_start_end

                    pushptr <pNode
                    pushsword #120
                    jsl value_transform_node_set_ticks

                    pushptr <pNode
                    jsl value_transform_node_apply_values
; Run through some calculations
                    clearptr <dwTick

                    pushptr #test_transform
                    pushdword <dwTick
                    jsl value_transform_update

                    inc <dwTick

                    pushptr #test_transform
                    pushdword <dwTick
                    jsl value_transform_update

loop                anop
;                    brk $01
;                    pushptr #test_transform
;                    pushlocalptr #wValue
;                    jsl value_transform_get_current_value
;                    lda <wValue

                    lda <dwTick
                    clc
                    adc #4
                    sta <dwTick

                    pushptr #test_transform
                    pushdword <dwTick
                    jsl value_transform_update
                    bit #value_transform_state~transform_end
                    beq loop

                    pushptr #test_transform
                    pushlocalptr #wValue
                    jsl value_transform_get_current_value
                    lda <wValue
                    cmp #(10|8)
                    bne failed

error               anop
                    pushptr #test_transform
                    jsl value_transform_destruct

exit                anop
                    lret 2:result

; Incorrect value
failed              anop
                    pushptr #str_transform_failed
                    _DebugStr
                    bra error

test_transform      ds sizeof~value_transform

str_transform_failed dw 'Value Transform failed'

                    end
.skip
; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_math_test1      start seg_tstlib

                    pushdword #$1234
                    pushdword #$5678
                    jsl ~mul4
                    pla
                    pla
                    rts

                    end
.skip
; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_math_test2      start seg_tstlib

                    lda #$100
                    ldx #$50
                    jsl math~mul2r2

                    rts

                    end
.skip

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_math_test3      start seg_tstlib

                    lda #$1234
                    ldx #$50
                    jsl math~mul2r4                ; returns a 4 byte results in a/x

                    pha

                    phx
                    pushptr #test_result+10
                    pushword #4
                    jsl word_to_hex_str

; low word is already on the stack
                    pushptr #test_result+14
                    pushword #4
                    jsl word_to_hex_str

                    rts

test_result         anop
                    dw 'Result: $xxxxxxxx'
                    end
.skip
; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_math_test4      start seg_tstlib
                    using math_tables

                    ldx #$0800
                    lda #$0800
                    jsl math~vec2_length

                    jsr print_result

                    ldx #$0040
                    lda #$0040
                    jsl math~vec2_length

                    jsr print_result

; Loop over a direction vector table and calculate the angle.
                    lda #0
loop_angle          sta loop_direction
                    asl a
                    asl a
                    tax
; Use the direction to vector table, that returns a vector of magnitude 1.0 for the direction
                    lda >math~dir_32_rot_mag_8_step_4_of_32,x           ; Get x
                    tay
                    lda >math~dir_32_rot_mag_8_step_4_of_32+2,x         ; Get y
                    tyx
                    jsl math~vec2_angle
; The returned value, should be (loop_direction * 4), or pretty close
                    jsr print_result
                    lda loop_direction
                    inc a
                    cmp #32
                    blt loop_angle

                    lda #$100
                    ldx #$02
                    jsl math~umul2r2
                    jsr print_result

                    lda #$02
                    ldx #$100
                    jsl math~umul2r2
                    jsr print_result

                    lda #$FF
                    ldx #$FF
                    jsl math~umul2r2
                    jsr print_result

                    rts

print_result        anop
                    pha
                    pushptr #test_result+10
                    pushword #4
                    jsl word_to_hex_str
                    rts

test_result         anop
                    dw 'Result: $xxxx'
loop_direction      ds 2
                    end
.skip

; -----------------------------------------------------------------------------
; Test that the 'fast' 8 bit multiply 'works', by comparing its output
; to the iterative multiply
                    aif C:debug~enable_unit_tests=0,.skip
run_math_test5      start seg_tstlib
                    using math_tables

; Define our work area data
                    begin_locals
wA                  decl word
wB                  decl word
wResult1            decl word
wResult2            decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <wA

loop1               stz <wB

loop2               lda <wA
                    ldx <wB
                    jsl math~umul1r2
                    sta <wResult1
                    lda <wA
                    ldx <wB
                    jsl math~umul2r2
                    sta <wResult2
                    cmp <wResult1
                    beq ok
                    brk $01
ok                  anop
                    inc <wB
                    lda <wB
                    cmp #256
                    blt loop2

                    inc <wA
                    lda <wA
                    cmp #256
                    blt loop1

                    lret
                    end
.skip

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_rnd_test        start seg_tstlib
                    using math_tables

; Define our work area data
                    begin_locals
wCount              decl word
wRnd1               decl word
wRnd2               decl word
wRnd3               decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

;                   brk $01

                    lda #$0001
                    jsl math~rnd_initialize
                    lda #$0001
                    jsl math~rnd2_initialize
                    lda #$0001
                    jsl math~rnd3_initialize

                    lda #100
                    sta <wCount

loop                jsl math~rnd_generate
                    sta <wRnd1
                    jsl math~rnd2_generate
                    sta <wRnd2
                    jsl math~rnd3_generate
                    sta <wRnd3

                    dec <wCount
                    bpl loop

                    lret
                    end
.skip

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_rnd_test2       start seg_tstlib
                    using math_tables
                    using YLookupData

; Define our work area data
                    begin_locals
wCount              decl word
wType               decl word
wByte               decl word
bColorEven          decl byte
bColorOdd           decl byte
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

; Make sure we have a good palette
                    jsl grlib_palette_apply_default

                    lda #$6743
                    jsl math~rnd_initialize
                    lda #$6743
                    jsl math~rnd2_initialize
                    lda #$6743
                    jsl math~rnd3_initialize
;                   lda #$6743
;                   tax
;                   jsl math~rnd4_initialize

restart_all         lda #0
                    sta <wType
                    lda #0
                    sta <wByte

type_start          ldx <wType
                    lda get_type,x
                    beq done

type_loop           jsr do_it

                    lda <wByte
                    bne next_type
                    lda #2
                    sta <wByte
                    bra type_loop

next_type           lda <wType
                    inc a
                    inc a
                    sta <wType
                    stz <wByte
                    bra type_start

done                anop
wait_key_done       jsl get_key_press
                    beq wait_key_done
                    jsl key_to_upper
                    cmp #key~esc
                    bne restart_all
                    lret

; do a rnd test pass
do_it               anop
                    ldx <wType
                    lda colors,x
                    sta <bColorEven

restart             jsr reset_counters

again               lda #1000
                    sta <wCount

loop                ldx <wType
                    jsr (get_type,x)
                    ldx <wByte
                    jsr (get_byte,x)
                    jsr add_pixel

                    dec <wCount
                    bpl loop

wait_key_exit       jsl get_key_press
                    beq wait_key_exit
                    jsl key_to_upper
                    cmp #'A'
                    beq again
                    cmp #'R'
                    beq restart
                    rts

get_type            dc a2'get_rnd1'
                    dc a2'get_rnd2'
                    dc a2'get_rnd3'
;                   dc a2'get_rnd4'
                    dc a2'0'

colors              dc i1'$F0,$0F'
                    dc i1'$E0,$0E'
                    dc i1'$D0,$0D'
;                   dc i1'$C0,$0C'

get_rnd1            jsl math~rnd_generate
                    rts
get_rnd2            jsl math~rnd2_generate
                    rts
get_rnd3            jsl math~rnd3_generate
                    rts
;get_rnd4           jsl math~rnd4_generate
;                   rts

get_byte            dc a2'get_low_byte'
                    dc a2'get_high_byte'

get_low_byte        and #$00ff
                    rts

get_high_byte       xba
                    and #$00ff
                    rts

;;
reset_counters      anop
                    lda #$0000
                    jsl grlib_fill_alt_screen
                    jsl grlib_alt_screen_to_screen

                    ldx #(256*2)-2
reset_loop          stz counters,x
                    dex
                    dex
                    bpl reset_loop
                    rts

add_pixel           anop
                    pha
                    asl a
                    tax
                    lda counters,x
                    cmp #200
                    bge no_pixel
                    tay
                    inc a
                    sta counters,x
                    tya
                    asl a
                    tax
                    pla
                    lsr a
                    bcs odd_pixel
                    clc
                    adc >gYLookup,x
                    tax
                    shortm
                    lda >$e12000,x
                    and #$0F
                    ora <bColorEven
                    sta >$e12000,x
                    longm
                    rts
odd_pixel           clc
                    adc >gYLookup,x
                    tax
                    shortm
                    lda >$e12000,x
                    and #$F0
                    ora <bColorOdd
                    sta >$e12000,x
                    longm
                    rts
no_pixel            pla
                    rts

counters            ds 256*2
                    end
.skip

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_hsv_test        start seg_tstlib
                    using math_tables

; Define our work area data
                    begin_locals
wTemp               decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

; Results area for hsv_to_rgb
                    pushsword #$1111
                    pushsword #$2222
                    pushsword #$3333

; Results area for rgb_to_hvs
                    pushsword #$4444
                    pushsword #$5555
                    pushsword #$6666

                    pushsword #$00a0            ; r
                    pushsword #$0000            ; g
                    pushsword #$0000            ; b
                    jsl grlib_rgb_to_hvs

hsv~h               equ 5
hsv~s               equ 3
hsv~v               equ 1

                    getword {s},#hsv~h
                    getword {s},#hsv~s
                    getword {s},#hsv~v
                    lsr a                           ; cut it in half
                    putword {s},#hsv~v
                    jsl grlib_hsv_to_rgb

rgb~r               equ 5
rgb~g               equ 3
hsv~b               equ 1

                    pla                             ; b
                    shiftright 4
                    and #$000F
                    sta <wTemp
                    pla                             ; g
                    and #$00F0
                    ora <wTemp
                    sta <wTemp
                    pla                             ; r
                    shiftleft 4
                    and #$0F00
                    ora <wTemp

                    lret
                    end
.skip

; -----------------------------------------------------------------------------
; Test my inplementation of the original's 'chained list update'
; that drives the difficulty progression as the game proceeds.
; Seems like overkill to me and I feel like it is hard to 'tune'.
; Oh well, I want to replicate the gameplay as close as possible.
                    ago .skip
run_chained_list_update_test start seg_tstlib

; Define our work area data
                    begin_locals
wCount              decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    setlocaldatabank

;                   brk $01

                    lda #140                        ; ~10 minutes of gameplay
                    sta <wCount

                    ldy #(6*2)-1
copy_loop           lda level4_start,y
                    sta dtime,y
                    dey
                    dey
                    bpl copy_loop

                    stz warrior_aggression

loop1               anop
                    pushdword #level4_difficulty_update_table
                    pushsword #1
                    jsl gameplay_apply_list_change
                    dec <wCount
                    bne loop1

;                   brk $02

                    lda #1
                    sta <wCount
loop2               pushdword #level4_difficulty_update_table
                    pushsword #1
                    jsl gameplay_apply_list_change
                    dec <wCount
                    bne loop2

;                   brk $02

                    restoredatabank
                    lret

; Values to change
dtime               ds 2
cworkers            ds 2
cwarriors           ds 2
cplanetiods1        ds 2
cplanetiods3        ds 2
cplanetiods5        ds 2
warrior_aggression  ds 2

; Initial values to change

; Level 0
level0_start        anop
                    dc i1'0,0'      ; dtime
                    dc i1'0,6'      ; cworkers
                    dc i1'0,0'      ; cwarriors
                    dc i1'0,10'     ; cplanetiods1
                    dc i1'0,2'      ; cplanetiods3
                    dc i1'0,2'      ; cplanetiods5

; Level 1
level1_start        anop
                    dc i1'0,0'      ; dtime
                    dc i1'0,6'      ; cworkers
                    dc i1'0,8'      ; cwarriors
                    dc i1'0,1'      ; cplanetiods1
                    dc i1'0,1'      ; cplanetiods3
                    dc i1'0,5'      ; cplanetiods5

; Level 2
level2_start        anop
                    dc i1'0,0'      ; dtime
                    dc i1'0,10'     ; cworkers
                    dc i1'0,3'      ; cwarriors
                    dc i1'0,10'     ; cplanetiods1
                    dc i1'0,2'      ; cplanetiods3
                    dc i1'0,2'      ; cplanetiods5

; Level 3
level3_start        anop
                    dc i1'0,0'      ; dtime
                    dc i1'0,4'      ; cworkers
                    dc i1'0,10'     ; cwarriors
                    dc i1'0,10'     ; cplanetiods1
                    dc i1'0,2'      ; cplanetiods3
                    dc i1'0,2'      ; cplanetiods5

; Level 4
level4_start        anop
                    dc i1'0,0'      ; dtime
                    dc i1'0,6'      ; cworkers
                    dc i1'0,8'      ; cwarriors
                    dc i1'0,10'     ; cplanetiods1
                    dc i1'0,10'     ; cplanetiods3
                    dc i1'0,5'      ; cplanetiods5

; Tables to change values
level0_difficulty_update_table anop
                    dc a4'dtime'
                    dc i'6'
                    dc a4'cworkers'
                    dc i'10'
                    dc a4'cwarriors'
                    dc i'-8'
                    dc a4'cplanetiods1'
                    dc i'10'
                    dc a4'cplanetiods3'
                    dc i'3'
                    dc a4'cplanetiods5'
                    dc i'127'
                    dc a4'warrior_aggression'
                    dc i'0'

level1_difficulty_update_table anop
                    dc a4'dtime'
                    dc i'6'
                    dc a4'cworkers'
                    dc i'10'
                    dc a4'cwarriors'
                    dc i'-1'
                    dc a4'cplanetiods1'
                    dc i'-1'
                    dc a4'cplanetiods3'
                    dc i'3'
                    dc a4'cplanetiods5'
                    dc i'127'
                    dc a4'warrior_aggression'
                    dc i'0'

level2_difficulty_update_table anop
                    dc a4'dtime'
                    dc i'10'
                    dc a4'cworkers'
                    dc i'10'
                    dc a4'cwarriors'
                    dc i'-8'
                    dc a4'cplanetiods1'
                    dc i'10'
                    dc a4'cplanetiods3'
                    dc i'3'
                    dc a4'cplanetiods5'
                    dc i'127'
                    dc a4'warrior_aggression'
                    dc i'0'

level3_difficulty_update_table anop
                    dc a4'dtime'
                    dc i'4'
                    dc a4'cworkers'
                    dc i'10'
                    dc a4'cwarriors'
                    dc i'-8'
                    dc a4'cplanetiods1'
                    dc i'10'
                    dc a4'cplanetiods3'
                    dc i'3'
                    dc a4'cplanetiods5'
                    dc i'127'
                    dc a4'warrior_aggression'
                    dc i'0'

level4_difficulty_update_table anop
                    dc a4'dtime'
                    dc i'6'
                    dc a4'cworkers'
                    dc i'10'
                    dc a4'cwarriors'
                    dc i'10'
                    dc a4'cplanetiods1'
                    dc i'10'
                    dc a4'cplanetiods3'
                    dc i'3'
                    dc a4'cplanetiods5'
                    dc i'127'
                    dc a4'warrior_aggression'
                    dc i'0'

demo_difficulty_update_table anop
                    dc a4'dtime'
                    dc i'6'
                    dc a4'cworkers'
                    dc i'1'
                    dc a4'cwarriors'
                    dc i'1'
                    dc a4'cplanetiods1'
                    dc i'1'
                    dc a4'cplanetiods3'
                    dc i'3'
                    dc a4'cplanetiods5'
                    dc i'127'
                    dc a4'warrior_aggression'
                    dc i'0'

                    end
.skip

                    ago .skip
; -----------------------------------------------------------------------------
; Test the 'distance modifier' for the caller distance priority
run_distance_modifier_test start seg_tstlib
                    using math_tables

; Define our work area data
                    begin_locals
wCount              decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    setlocaldatabank

                    lda #$0001
                    ldy #$0002
                    jsr calc_distance_modifier

                    lda #$0002
                    ldy #$0001
                    jsr calc_distance_modifier

                    lda #$0100
                    ldy #$0000
                    jsr calc_distance_modifier

                    lda #$0000
                    ldy #$0100
                    jsr calc_distance_modifier

                    lda #$0200
                    ldy #$0100
                    jsr calc_distance_modifier

                    lda #$0100
                    ldy #$0200
                    jsr calc_distance_modifier

                    lda #$0200
                    ldy #$0200
                    jsr calc_distance_modifier

                    lda #$03FF
                    ldy #$0100
                    jsr calc_distance_modifier

                    lda #$03FF
                    ldy #$03FF
                    jsr calc_distance_modifier

                    restoredatabank
                    lret

; Note, this is a copy of the local function that is in gameplay_caller_logic_tick

; This is an approximation of what the Sinistar code was doing.  We have 16-bit distances, rather than 8-bit
; This inverts the bits of a component of the x/y distance, then takes only the upper bits, and squares the
; result, taking only the upper bits of that.  Does the same for the other component, then adds them together
; Essentially doing a rounded SQR(X) + SQR(Y), which of course, is the squared distance.
; That value is then multiplied by responder_distance_modifier_max, and again, only the upper bits are used.
; Since the responder_distance_modifier_max is 64, we (thankfully) don't have to do a real multiply and
; since the upper bits are used, we can just do one set of shits and clip the value.
calc_distance_modifier      anop
; We're gonna clamp the input, because I don't want any accidentaly oddball values making subtle bugs
; We need to clamp because we are going strip bits and having an input value just over $3ff, would end up looking like it was very close
; The original didn't need this, because it was using the full range of the register.
                            cmp #1024                           ; gameplay_playfield_width
                            blt oK_d1
                            lda #1024-1
oK_d1                       eor #$ffff                          ; invert so closer distances have more bits
; Our max, absolute range is 1024, so shift down, so the MBS are in the lower 8-bits
; However, we are going to immediately shift it back up by 1, so just shift down by 1 and mask the bits
                            shiftright 1
                            and #$01fe
                            tax
                            lda >math~squared,x
                            xba                                 ; only using the upper bits
                            and #$00ff
                            lsr a                               ; shift down.  Sinistar did this because of 8-bit registers
                            pha                                 ; save on the stack

                            tya                                 ; get the x component
                            cmp #1024                           ; gameplay_playfield_width
                            blt oK_d2
                            lda #1024-1
oK_d2                       eor #$ffff                          ; invert so closer distances have more bits
                            shiftright 1
                            and #$01fe
                            tax
                            lda >math~squared,x
                            xba                                 ; only using the upper bits
                            and #$00ff
                            lsr a                               ; shift down.  Sinistar did this because of 8-bit registers

                            clc
                            adc 1,S                             ; add to the modified Y component on the stack

;                           static_assert_equal responder_distance_modifier_max,64
;                           ldx #responder_distance_modifier_max
;                           jsl math~umul1r2

;                           xba                                 ; only using the upper bits
;                           and #$00ff
; Optimization, if the multiplier is 64, then it would be a shift up 6, but we only use the upper bits,
; so then it is a shift down 8.
; We will just shift the original down 2 and chop it
                            shiftright 2
                            and #$00ff

                            ply                                 ; remove our temporary from the stack
                            rts

                            end
.skip

;use_adb_input               gequ 1

                            aif C:use_adb_input=0,.skip
; -----------------------------------------------------------------------------
run_adb_test        start seg_tstlib
                    using inputlib_data
                    using softswitch_definitions
                    using textlib_global_data

; Define our work area data
                    begin_locals
wCount              decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    setlocaldatabank

                    jsl grlib_set_text_mode

                    jsl textbox_clear_options
                    jsl textbox_reset_size

; Must disable the ADB keyboard polling
                    jsl disable_adb_keyboard_polling

                    pushsword #$20
                    jsl textbox_clear

loop                anop

                    pushsword #0
                    pushsword #0
                    jsl textbox_set_cursor

                    pushsword >input~adb_keyboard_data_length
                    jsl textbox_print_hex_word

                    lda >textbox_primary~cursor_x
                    inc a
                    sta >textbox_primary~cursor_x

                    pushsword >input~adb_keyboard_data
                    jsl textbox_print_hex_word

                    lda >textbox_primary~cursor_x
                    inc a
                    sta >textbox_primary~cursor_x

                    lda #0
                    shortm
                    lda >ssw~adb_status
                    longm
                    pha
                    jsl textbox_print_binary_byte

                    lda >textbox_primary~cursor_x
                    inc a
                    sta >textbox_primary~cursor_x

                    lda #0
                    shortm
                    lda >ssw~kbd_data
                    longm
                    pha
                    cmp #$80+$20
                    beq not_space
                    shortm
                    sta >ssw~kbd_strobe
                    longm
not_space           anop
                    jsl textbox_print_binary_byte

                    lda >textbox_primary~cursor_x
                    inc a
                    sta >textbox_primary~cursor_x

                    lda #0
                    shortm
                    lda >ssw~key_modifiers
                    longm
                    pha
                    jsl textbox_print_binary_byte

                    jsl get_adb_key_press
                    brl loop

                    jsl enable_adb_keyboard_polling

                    restoredatabank
                    rts
                    end
.skip

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_snes_max_test   start seg_tstlib
                    using inputlib_data
                    using softswitch_definitions
                    using textlib_global_data

; Define our work area data
                    begin_locals
wCount              decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    setlocaldatabank

                    jsl grlib_set_text_mode

                    jsl textbox_clear_options
                    jsl textbox_reset_size

                    pushsword #$20
                    jsl textbox_clear

                    jsl textbox_set_option_fill

restart             pushsword #0
                    pushsword #0
                    jsl textbox_set_cursor

                    pushdword #slot_str
                    jsl textbox_print_string

                    pushsword >input~gamepad_slot
                    jsl textbox_print_decimal_word

loop                anop

                    jsl get_key_press
                    cmp #key~esc
                    jeq done
                    cmp #'1'
                    blt not_slot
                    cmp #'8'
                    bge not_slot
                    sec
                    sbc #'0'
                    jsl snes_max_patch_slot
                    bra restart

not_slot            anop
                    lda >input~gamepad_slot
                    beq display_controller_state

                    jsl snes_max_read_controller

display_controller_state anop
                    pushsword #0
                    pushsword #1
                    jsl textbox_set_cursor

; Controller 1
                    pushdword #controller1_str
                    jsl textbox_print_string

                    lda >input~gamepad1_connected
                    beq not_connected1
                    pushdword #connected_str
                    bra show_connection1
not_connected1      pushdword #not_connected_str
show_connection1    jsl textbox_print_string

                    jsl textbox_newline

                    lda >input~gamepad1_buttons
                    xba
                    and #$ff
                    pha
                    jsl textbox_print_binary_byte
                    lda >input~gamepad1_buttons
                    and #$ff
                    pha
                    jsl textbox_print_binary_byte

                    jsl textbox_newline

; Controller 2
                    pushdword #controller2_str
                    jsl textbox_print_string

                    lda >input~gamepad2_connected
                    beq not_connected2
                    pushdword #connected_str
                    bra show_connection2
not_connected2      pushdword #not_connected_str
show_connection2    jsl textbox_print_string

                    jsl textbox_newline

                    lda >input~gamepad2_buttons
                    xba
                    and #$ff
                    pha
                    jsl textbox_print_binary_byte
                    lda >input~gamepad2_buttons
                    and #$ff
                    pha
                    jsl textbox_print_binary_byte
                    brl loop

done                restoredatabank
                    lret

slot_str            cstring 'SNES MAX Slot:'
connected_str       cstring 'Connected'
not_connected_str   cstring 'Not Connected'
controller1_str     cstring 'Controller 1:'
controller2_str     cstring 'Controller 2:'

                    end
.skip
; -----------------------------------------------------------------------------
test_data_id        gequ '41UA'
                    aif C:debug~enable_unit_tests=0,.skip
run_sndlib_test     start seg_tstlib

; Define our work area data
                    begin_locals
result              decl word
pLibrary            decl ptr
pData               decl ptr
dwSampleLength      decl long
spSndDOCRAM         decl word
wSndDOCFrequency    decl word
wSndDOCSize         decl word
wSndOscillator      decl word
wSndOscillatorCount decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <result

;                   pushptr #string_debug_break
;                   _DebugStr

                    pushptr #pathname_string
                    pushptr #test_pathname
                    jsl string_object_construct_zt

                    pushptr #pathname_string
                    pushsword #datalib_preload_options~none
                    jsl datalib_manager_add_library
                    jcs failed_to_open
                    putretptr <pLibrary

                    pushptr <pLibrary
                    pushdword #datalib_type_WAVE
                    pushdword #test_data_id
                    pushsword #datalib_load_options~reference
                    jsl datalib_library_get_data_ptr
                    jcs failed_to_read
                    putretptr <pData
; Get the length
                    getword [<pData],#wavetable_definition~size+2
                    putword <dwSampleLength+2
                    cmp #0
                    jne too_big
                    getword [<pData],#wavetable_definition~size
                    putword <dwSampleLength
                    cmp #1+(1024*32)
                    jge too_big

; round up to the next power of 2, if needed
                    jsl sndlib_get_table_size_from_byte_size        ; input A=byte size, output X=table size index
                    stx <wSndDOCSize                                ; store this here, it isn't quite in the register format yet
                    ldy #1
                    jsl sndlib_get_table_address                    ; input X=table size index, Y=table offset index, output A=table address in DOC ram
                    putword <spSndDOCRAM                            ; save the doc ram address

; Put the address of the the data into the struct
                    getword [<pData],#wavetable_definition~offset+2
                    pha
                    getword [<pData],#wavetable_definition~offset   ; this is a pointer at runtime
                    pha
                    pushsword <dwSampleLength
                    pushsword <spSndDOCRAM
                    jsl sndlib_copy_to_doc

                    pushsword [<pData],#wavetable_definition~sample_rate
                    pushsword #doc_default_sample_advance_delta
                    jsl sndlib_khz_to_doc_frequency
                    putword <wSndDOCFrequency

; Make the correct doc size value, by putting the table size in the correct location
; and leaving the table size value in the lower bits, so that the bus-resolution is 9-bits
                    getword <wSndDOCSize
                    shiftleft 3
                    ora <wSndDOCSize
                    sta <wSndDOCSize

                    lda #$02
                    sta <wSndOscillator
                    lda #$02
                    sta <wSndOscillatorCount

                    lda #1
                    jsl grlib_set_text_mode

                    jsl textbox_clear_options
                    jsl textbox_reset_size

                    pushsword #$20
                    jsl textbox_clear

play_again          anop

                    pushsword #0
                    pushsword #0
                    jsl textbox_set_cursor

                    pushsword <wSndDOCFrequency
                    jsl textbox_print_hex_word

                    pushsword <wSndOscillator
                    pushsword <wSndOscillatorCount
                    pushsword <wSndDOCFrequency
                    pushsword <spSndDOCRAM
                    pushsword <wSndDOCSize
                    jsl sndlib_play_one_shot

                    lda #60
                    jsl applib_wait_ticks

wait                jsl get_key_press
                    beq wait
                    cmp #key~esc
                    beq done
                    cmp #key~up_arrow
                    bne not_up
                    lda <wSndDOCFrequency
                    clc
                    adc #2
                    sta <wSndDOCFrequency
                    bra play_again

not_up              cmp #key~down_arrow
                    bne not_down
                    lda <wSndDOCFrequency
                    sec
                    sbc #2
                    bcc wait
                    sta <wSndDOCFrequency
                    bra play_again

not_down            cmp #key~space
                    beq play_again
                    cmp #'1'
                    bne not_1
                    lda #1
                    bra change_oscillator_count

not_1               cmp #'2'
                    bne not_2
                    lda #2
change_oscillator_count anop
                    sta <wSndOscillatorCount
                    bra play_again
not_2               bra wait

done                anop
                    lda #0
                    jsl grlib_set_text_mode

too_big             anop
exit2               anop
                    pushptr <pLibrary
                    jsl datalib_manager_remove_library

exit                anop
                    pushptr #pathname_string
                    jsl string_object_destruct

                    lret 2:result

failed_to_open      anop
                    pushptr #str_failed_to_open
                    _DebugStr
                    lda #1
                    bra exit

failed_to_read      anop
                    pushptr #str_failed_to_read
                    _DebugStr
                    lda #1
                    bra exit2

pathname_string     ds sizeof~string_object

str_failed_to_open  dw 'Failed to open sound library'
str_failed_to_read  dw 'Failed to read sound data'

string_debug_break  dw "Unit Test Sound"

test_pathname       dc c'9:DATA.DAT'
                    dc i1'0'

                    end
.skip

; -----------------------------------------------------------------------------
run_unit_tests      start seg_tstlib

                    aif C:debug~enable_unit_tests=0,.skip
                    setlocaldatabank

                    jsr run_zero_memory_test
                    jsr run_copy_memory_test
                    jsr run_vector_test
                    jsr run_string_test
                    jsr run_sba_test
;                    jsr run_value_transform_test
;                    jsr run_datalib_test
                    jsr run_math_test1
                    jsr run_math_test2
                    jsr run_math_test3
                    jsr run_math_test4
;                    jsr run_math_test5
;                    jsr run_chained_list_update_test
;                    jsr run_adb_test
;                    jsr run_sndlib_test
;                    jsr run_snes_max_test
;                    jsr run_distance_modifier_test
;                    jsr run_rnd_test
;                    jsr run_rnd_test2
;                    jsr run_hsv_test
                    restoredatabank
.skip
                    lda #1                              ; Return 1 to contine, 0 to exit the app
                    rtl

                    end

; -----------------------------------------------------------------------------
; App level unit tests
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_app_sound_test start seg_tstlib
                    using gameplay_sound_data
                    using sndlib_data

; Define our work area data
                    begin_locals
result              decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <result

                    lda #1
                    jsl grlib_set_text_mode

                    jsl textbox_clear_options
                    jsl textbox_reset_size

                    pushsword #$20
                    jsl textbox_clear

                    jsl applib_update_tick_count
                    jsl sndlib_manager_sync_ticks

                    pushsword #0
                    pushsword #0
                    jsl textbox_set_cursor

play_again          anop
                    pushsword #id_sfx~player_shot
                    jsl sndlib_play_sfx
                    bcc wait
                    brk $01

play_again2         anop
                    pushsword #id_sfx~warrior_shot
                    jsl sndlib_play_sfx
                    bcc wait
                    brk $01

play_again3         anop
                    pushsword #id_sfx~worker_collect_crystal
                    jsl sndlib_play_sfx
                    bcc wait
                    brk $01

wait                anop
; Must do a some of the standard update calls to make sure the sound timers work
                    jsl applib_update_tick_count
                    jsl sndlib_manager_update

                    jsl get_key_press
                    beq wait
                    cmp #key~esc
                    beq done
                    cmp #key~space
                    beq play_again
                    cmp #'1'
                    beq play_again
                    cmp #'2'
                    beq play_again2
                    cmp #'3'
                    beq play_again3
                    bra wait

done                anop
                    lda #0
                    jsl grlib_set_text_mode

                    lret 2:result

                    end
.skip

; -----------------------------------------------------------------------------
                    aif C:debug~enable_unit_tests=0,.skip
run_app_sound_test2 start seg_tstlib
                    using gameplay_sound_data
                    using sndlib_data

; Define our work area data
                    begin_locals
result              decl word
work_area_size      end_locals

                    lsub ,work_area_size          ; Parameters, plus the amount of space for our local work area

                    stz <result

                    lda #1
                    jsl grlib_set_text_mode

                    jsl textbox_clear_options
                    jsl textbox_reset_size

                    pushsword #$20
                    jsl textbox_clear

                    jsl applib_update_tick_count
                    jsl sndlib_manager_sync_ticks

play_again          anop

                    pushsword #0
                    pushsword #0
                    jsl textbox_set_cursor

                    pushsword #id_sfx~i_hunger
                    jsl sndlib_play_sfx

wait                anop
; Must do a some of the standard update calls to make sure the sound timers work
                    jsl applib_update_tick_count
                    jsl sndlib_manager_update

                    jsl get_key_press
                    beq wait
                    cmp #key~esc
                    beq done
                    cmp #key~space
                    beq play_again
                    bra wait

done                anop
                    lda #0
                    jsl grlib_set_text_mode

                    lret 2:result

                    end
.skip

                    ago .skip
; -----------------------------------------------------------------------------
run_app_erase_rect_test start seg_grlib
                    using grlib_global_equates
                    using grlib_global_data

                    debugtag 'run_app_erase_rect_test'

; Going to use the grlib DP values
                    phd
                    lda >grlib~dp
                    tcd

                    setlocaldatabank

test_rect_height            equ 32
test_rect_width             equ 32

; Stack re-map and PHA
                    lda #0
                    sta <draw_y
                    lda #test_rect_height
                    sta <area_height

                    lda #0
                    sta <draw_x                             ; byte x

                    lda #test_rect_width/2
                    sta <area_width                         ; byte width

                    lda #0                                  ; fill pattern
                    jsr _altscr_fill_area_push_words

; Test a rect with a 'right-edge'
                    lda #0
                    sta <draw_y
                    lda #test_rect_height
                    sta <area_height

                    lda #1
                    sta <draw_x

                    lda #(test_rect_width-1)/2
                    sta <area_width

                    jsr _altscr_fill_area_re_unrolled

; Left-Edge
                    lda #0
                    sta <draw_y
                    lda #test_rect_height
                    sta <area_height

                    lda #0
                    sta <draw_x

                    lda #(test_rect_width-1)/2
                    sta <area_width

                    jsr _altscr_fill_area_le_unrolled

; Left and Right Edge
                    lda #0
                    sta <draw_y
                    lda #test_rect_height
                    sta <area_height

                    lda #1
                    lsr a
                    sta <draw_x

                    lda #((test_rect_width-2)/2)-1
                    sta <area_width

                    jsr _altscr_fill_area_lre_unrolled

; Even start and width
                    lda #0
                    sta <draw_y
                    lda #test_rect_height
                    sta <area_height

                    lda #0
                    sta <draw_x

                    lda #test_rect_width/2
                    sta <area_width

                    jsr _altscr_fill_area_wb_unrolled


                    restoredatabank
                    pld
                    rtl

                    end
.skip
; -----------------------------------------------------------------------------
; These are unit tests that require the app to be a bit more 'initialized'
; i.e. They can assume that app-specific systems are initialized and
; app specific data is loaded.
run_app_unit_tests  start seg_tstlib

                    aif C:debug~enable_unit_tests=0,.skip
                    setlocaldatabank

;                    jsr run_app_sound_test
;                    jsr run_app_sound_test2

                    restoredatabank
.skip
                    lda #1                              ; Return 1 to contine, 0 to exit the app
                    rtl

                    end
