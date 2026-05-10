                    copy lib/source/debug.definitions.asm
                    copy lib/source/applib.definitions.asm

                    mcopy generated/math.support.macros

; -----------------------------------------------------------------------------
; Initialize some common math functions.
; This is needed for ones that have calculated tables, that I haven't burned
; into the app
math~initialize             start seg_mathlib
                            using applib_data

; Patch in the DP page in a few places, it helps for functions where we don't want to disturb A on entry.
                            lda >applib~shared_dp

                            sta >patch~math~vec2_angle+1
                            sta >patch~math~vec2_angle_quadrant+1

                            rtl

                            end
; -----------------------------------------------------------------------------
; 16-bit, Signed Integer Multiply.
; This is a modified version from the Orca library, where it allows for a
; 32-bit result.  This also means we will never overflow.
; However it is probably about %30 slower than a ~mul2 from the Orca lib
; so that should be used if you know your math will never overflow.
;
;  Inputs:
;   A - multiplicand
;   X - multiplier
;
;  Outputs:
;   A - result (low)
;   X - result (high)
;
; Note, the y register is used as a temporary, and is not saved
; -----------------------------------------------------------------------------

math~mul2r4                 start seg_mathlib
result_low                  equ 1               ; Low word of the result
op1                         equ 3
op2                         equ 5
sign                        equ 7
;
;  Initialization
;
                            tay                 ; save value
                            phd                 ; set up local space
                            tsc
                            sec
                            sbc #8
                            tcd
                            tcs
                            tya                 ; restore value
                            ldy #0              ; make all arguments positive
                            bit #$8000          ; start with A
                            beq in1
                            eor #$FFFF
                            inc a
                            iny
in1                         sta <op1
                            txa                 ; now do X
                            bpl in2
                            dey
                            eor #$FFFF
                            inc a
in2                         anop
                            cmp <op1
                            bge bigger
; We want op2 to be bigger than op1
                            ldx <op1
                            sta <op1
                            txa
bigger                      dec a               ; do -1 for the op2, so we can skip doing a clc before each add
                            sta <op2
                            sty <sign            ; save sign; non-zero for negative results
;
; Do the multiply
; We shift the bits of one of the operands right, then rol the bits into the top of the result
; <result_low will end up with the lower bits of the result, A will have the high bits.
;
; Each step is
;                           lsr <op1        ; test the LSB
;                           bcc skip        ; br if it is off
;                           adc <op2        ; add in partial product
;skip                       ror a           ; multiply answer by 2
;                           ror <result_low

                            lda #0              ; set up the result
                            stz <result_low

                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
;                           mul16_step <op1,<op2,<result_low
                            lsr <op1        ; test the LSB
                            beq earlyout8
                            bcc lb9        ; br if it is off
                            adc <op2        ; add in partial product
lb9                         ror a           ; multiply answer by 2
                            ror <result_low

                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
;
;  Set sign and exit, 32 bit result
;
sse32                       ldy <sign           ; if result is to be neg, reverse sign
                            beq sse32_2
; We have to do a 32 bit negate.
                            eor #$FFFF          ; invert the high word
                            tax                 ; put in x
                            lda <result_low
                            eor #$FFFF          ; invert the low word
                            inc a
                            tay                 ; put into y
                            bne sse32_3         ; need to increment the high word?
                            inx
                            bra sse32_3

sse32_2                     tax                 ; high word into x
                            ldy <result_low     ; low word into y
; restore stack, DP
sse32_3                     anop
                            tsc
                            clc
                            adc #8
                            tcs
                            pld
                            tya                 ; low word into a
                            clv
                            rtl

; We come here if the remaining bits of the op1 are 0, after 8 shifts
; Do the remaining shifts, knowing that there are no more bits in op1
earlyout8                   anop
                            bcc eo8_skip
                            adc <op2
eo8_skip                    ror a
                            ror <result_low

                            lsr a
                            ror <result_low
                            lsr a
                            ror <result_low
                            lsr a
                            ror <result_low
                            lsr a
                            ror <result_low
                            lsr a
                            ror <result_low
                            lsr a
                            ror <result_low
                            lsr a
                            ror <result_low
                            bra sse32

                            end

; -----------------------------------------------------------------------------
; 16-bit, Signed Integer Multiply
; This is the same code from the Orca lib, just the small optimization
; for skipping a clc, before each add.  This only saves cycles for bits that
; are on in the 'smaller' operand, so not really much of a savings.
; The most you would get is 14 cycles, if all the lower 8 bits were on
; ((8 * 2) - 2)
;
;  Inputs:
;   A - multiplicand
;   X - multiplier
;
;  Outputs:
;   A - result
;   V - set if an overflow occurred
;
; Note, the y register is used as a temporary, and is not saved
; -----------------------------------------------------------------------------

math~mul2r2                 start seg_mathlib
num1                        equ 1
num2                        equ 5
sign                        equ 7
;
;  Initialization
;
                            tay                         ; save value
                            phd                         ; set up local space
                            tsc
                            sec
                            sbc #8
                            tcd
                            tcs
                            tya                         ; restore value
                            ldy #0                      ; make all arguments positive
                            bit #$8000                  ; start with A
                            beq in1
                            eor #$FFFF
                            inc A
                            bmi jen32768                ; special case -32768
                            iny
in1                         sta num1+2
                            txa                         ; now do X
                            bpl in2
                            dey
                            eor #$FFFF
                            inc A
                            bpl in2                     ; special case -32768
                            ldx num1+2
jen32768                    brl en32768
in2                         cmp num1+2                  ; make sure num1+2 is the smaller
                            bge in3                     ; operand
                            ldx num1+2
                            sta num1+2
                            txa
in3                         dec a                       ; - 1, so we can optimize the add (no clc)
                            sta num2
                            sty sign                    ; save sign; non-zero for negative results
;
;  Do the multiply
;
                            lda #0                      ; set up the result
                            stz num1

                            mul16_step <num1+2,<num2,<num1
                            mul16_step <num1+2,<num2,<num1
                            mul16_step <num1+2,<num2,<num1
                            mul16_step <num1+2,<num2,<num1
; Early out at 4 bits
                            lsr num1+2                  ; test the LSB
                            beq abrt4
                            bcc lb5                     ; br if it is off
                            adc num2
lb5                         ror A                       ; multiply answer by 2
                            ror num1

                            mul16_step <num1+2,<num2,<num1
                            mul16_step <num1+2,<num2,<num1
                            mul16_step <num1+2,<num2,<num1
;
;  Because the operands are sorted, we can stop now
;
                            ldy num1+2                  ; if num1+2 isn't 0 yet, we'll overflow
                            bne ovfl
                            bit #$FF80                  ; check for overflow in A
                            bne ovfl
                            ora num1                    ; do remaining shifts
                            xba
;
;  Set sign and exit
;
ss1                         ldy sign                    ; if result is to be neg, reverse sign
                            beq ss2
                            eor #$FFFF
                            inc A
ss2                         tay                         ; restore stack, DP
                            tsc
                            clc
                            adc #8
                            tcs
                            pld
                            tya
                            clv
                            rtl
;
;  Handle an input operand of -32768
;
en32768                     txa                         ; -32768 * 0 = 0
                            beq ss2

                            cmp #1                      ; -32768 * 1 = -32768
                            bne ovfl                    ; any other result is an overflow
                            lda #$8000
                            bra ss2
;
;  Abort with num1+2 = 0 after 4 shifts
;
abrt4                       bcc aa1                     ; add in partial product
                            adc num2
aa1                         bit #$F800                  ; check for overflow
                            beq aa2
                            brl ovfl
aa2                         rol num1                    ; do remaining shifts
                            ora num1
                            rol A
                            rol A
                            rol A
                            rol A
                            bra ss1
;
;  Handle an overflow
;
ovfl                        tsc                         ; restore stack, DP
                            clc
                            adc #8
                            tcs
                            pld
                            sep #%01000000              ; SEV
                            rtl
                            end

; -----------------------------------------------------------------------------
; 16-bit, Unsigned Signed Integer Multiply
; This is the same code from the Orca lib, but stripped of the sign
; adjustment and the the small optimization
; for skipping a clc, before each add.  This only saves cycles for bits that
; are on in the 'smaller' operand, so not really much of a savings.
; The most you would get is 14 cycles, if all the lower 8 bits were on
; ((8 * 2) - 2)
;
;  Inputs:
;   A - multiplicand
;   X - multiplier
;
;  Outputs:
;   A - result
;   V - set if an overflow occurred
;
; Note, the y register is used as a temporary, and is not saved
; With an early out of < 32 for the multiplier, this function is about 207 cycles
; and > 31, about 260 cycles.  The estimation is due to the branches
; based on the bits in the multiplier being set or not
; -----------------------------------------------------------------------------

math~umul2r2                start seg_mathlib
result_low                  equ 1
op1                         equ 3
op2                         equ 5
;
;  Initialization
;
                            tay                         ; save value
                            phd                         ; set up local space
                            tsc
                            sec
                            sbc #6
                            tcd
                            tcs
                            sty <op1                    ; a was moved to y, just store y, in the assumed smaller value location
                            txa                         ; get x into a
                            cmp <op1                    ; make sure op1 is the smaller
                            bge in3                     ; operand
                            sta <op1                    ; put the smaller into op1
                            tya                         ; put y, which is larger, into a
in3                         dec a                       ; - 1, so we can optimize the add (no clc)
                            sta <op2
;
;  Do the multiply, the running sum with have
;
                            lda #0                      ; set up the result
                            stz result_low

                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
; Early out at 4 bits
                            lsr op1                     ; test the LSB
                            beq abrt4
                            bcc lb5                     ; br if it is off
                            adc op2
lb5                         ror A                       ; multiply answer by 2
                            ror result_low

                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
                            mul16_step <op1,<op2,<result_low
;
;  Because the operands are sorted, we can stop now
;
                            ldy op1                     ; if op1 isn't 0 yet, we'll overflow
                            bne ovfl
                            bit #$FF00                  ; check for overflow in A
                            bne ovfl
                            ora result_low              ; do remaining shifts
                            xba

ss2                         tay                         ; restore stack, DP
                            tsc
                            clc
                            adc #6
                            tcs
                            pld
                            tya
                            clv
                            rtl
;
;  Abort with num1+2 = 0 after 4 shifts
;
abrt4                       bcc aa1                     ; add in partial product
                            adc op2
aa1                         bit #$F000                  ; check for overflow
                            beq aa2
                            bra ovfl
aa2                         rol result_low              ; do remaining shifts
                            ora result_low
                            rol A
                            rol A
                            rol A
                            rol A
                            bra ss2
;
;  Handle an overflow
;
ovfl                        tsc                         ; restore stack, DP
                            clc
                            adc #6
                            tcs
                            pld
                            sep #%01000000              ; SEV
                            rtl
                            end

; -----------------------------------------------------------------------------
; 8 bit, unsigned multiply with a 16-bit output.
;
; Uses the technique
;
;  let f(x) = x^2 / 4
;  then
;  a*b = f(a+b) - f(a-b)
;
; f(x) is a lookup table, which makes this have a fairly constant time is is
; much quicker than an iterative multiply.
;
;  Inputs:
;   A - multiplicand
;   X - multipier
;
;  Outputs:
;   A - result
;
; The Y register is not affected
;
; Please note that no checking of A or X is done, so-as to not have redundant checks and if either
; of those values are > $ff, the results can be random, as it will be going off the end of the
; lookup table.
;
; Adapted from www.6502.org/source/integers/fastmult.htm
; See also forum.6502.org/viewtopic.php?f=10(amp)t=2211(amp)p=20864#p20864
;
; Note, since this is pretty small, there is a macro version,
; inline~umul1r2, which can be up to 30% faster.
;
math~umul1r2                start seg_mathlib
                            using math_tables

; Uses the stack for temporary storage

; Cycle time, 32 + 27 + 3 = 62, or 32 + 27 + 7 = 66, if A < B
                            phx                                     ; 4
                            pha                                     ; 4
                            clc                                     ; 2
                            adc 3,s                                 ; 5 add B
                            asl a                                   ; 2
                            tax                                     ; 2
                            pla                                     ; 5 get A back
                            sec                                     ; 2
                            sbc 1,s                                 ; 5 subtract B
                            bcs ok                                  ; 2-3
                            negate a                                ; 5 this is a squared lookup, so always positive.
ok                          asl a                                   ; 2
                            sta 1,s                                 ; 5 save for later
                            lda >math~squared_512_div4,x            ; 6
                            sec                                     ; 2
                            plx                                     ; 5
                            sbc >math~squared_512_div4,x            ; 6
                            rtl                                     ; 6

; Alternate version.  Uses Y as a temporary, but does not use the stack
                            ago .skip
; Cycle time, 69, if A is greater than B, else 73
                            sta >temp_a                             ; 6
                            txa                                     ; 2
                            sta >temp_b                             ; 6
                            clc                                     ; 2
                            adc >temp_a                             ; 6
                            asl a                                   ; 2
                            tax                                     ; 2
                            lda >temp_a                             ; 6
                            sec                                     ; 2
                            sbc >temp_b                             ; 6
                            bcs ok                                  ; 2-3
                            negate a                                ; 5 this is a squared lookup, so always positive.
ok                          asl a                                   ; 2
                            tay                                     ; 2 save for later
                            lda >math~squared_512_div4,x            ; 6
                            sec                                     ; 2
                            tyx                                     ; 2
                            sbc >math~squared_512_div4,x            ; 6
                            rtl
temp_a                      ds 2
temp_b                      ds 2
.skip

                            end

; -----------------------------------------------------------------------------
; 16 bit, Signed Integer Divide
; This is directly from the Orca library, and can be swapped for ~DIV2 calls
;
; Parameters:
;  X - denominator
;  A - numerator
;
; Returns:
; A - result
; X - remainder
; V - set for division by zero
; -----------------------------------------------------------------------------

math~div2r2                 start seg_mathlib

                            begin_locals
sign                        decl word
num2                        decl word
num1                        decl word
                            end_locals

                            ldy #0                      ; make all arguments positive
                            bit #$8000                  ; start with a
                            beq dv1
                            eor #$ffff
                            inc a
                            iny
dv1                         pha                         ; save it
                            txa                         ; now do x
                            beq err
                            bpl dv2
                            dey
                            eor #$ffff
                            inc a
dv2                         pha                         ; save it
                            phy                         ; save sign
                            tsc                         ; set up dp
                            phd
                            tcd

                            lda #0                      ; initialize the remainder
                            ldy #16                     ; 16 bits to go
dv3                         asl <num1                   ; roll up the next number
                            rol a
                            sec                         ; subtract the digit
                            sbc <num2
                            bcs dv4
                            adc <num2                   ; digit is 0
                            dey
                            bne dv3
                            bra dv5
dv4                         inc <num1                    ; digit is 1
                            dey
                            bne dv3

dv5                         tax                         ; save the remainder
                            lda <num1                   ; get the result
                            ldy <sign                   ; set the sign
                            beq dv6
                            eor #$ffff
                            inc a
dv6                         clv                         ; clear the error flag
dv7                         pld                         ; reset dp
                            ply                         ; clean up stack
                            ply
                            ply
                            rtl

err                         pla
                            sep #%01000000              ; sev
                            rtl
                            end

; -----------------------------------------------------------------------------
; 16-bit, Unsigned Integer Divide
; This is directly from the Orca library, with the sign adjustment stripped out
; This also does not check for div by 0, caller should do that!
;
; Parameters:
;  X - denominator
;  A - numerator
;
; Returns:
; A - result
; X - remainder
; Z flag will be set to the state of A
; -----------------------------------------------------------------------------

math~udiv2r2                start seg_mathlib

                            begin_locals
num2                        decl word
num1                        decl word
                            end_locals

                            pha                         ; numerator to the stack
                            phx                         ; denominator to the stack
                            tsc                         ; set up dp
                            phd
                            tcd

                            lda #0                      ; initialize the remainder
                            ldy #16                     ; 16 bits to go
dv3                         asl <num1                   ; roll up the next number
                            rol a
                            sec                         ; subtract the digit
                            sbc <num2
                            bcs dv4
                            adc <num2                   ; digit is 0
                            dey
                            bne dv3
                            bra dv5
dv4                         inc <num1                    ; digit is 1
                            dey
                            bne dv3

dv5                         tax                         ; save the remainder
                            clv                         ; clear the error flag
                            pld                         ; reset dp
                            ply                         ; clean up stack
                            pla                         ; get result (where num1 is)
                            rtl

                            end

; -----------------------------------------------------------------------------
; Get the length of a 2D vector.
; The vector has some strict limits, and the returned value is an approximation
; This is all to keep the tables within a reasonable limit
;
; The input vector values are assumed to be fp16, and the maximum value supported
; is 8.0.
; Internal lookup tables may have less precision, but the result will be in fp16
; However it might not be as precise as one might expect, not that it is, even with fp16.
;
; Note that while this was designed for fp16 numbers, the input can be ints with a 12 bit limit.
;
; Parameters:
; The vector in X and A, with the x coordinate in x, and the Y in A.
; Returns:
; Length in A.
math~vec2_length            start seg_mathlib
                            using math_tables

; The number of bits we will lop off
maxbits                     equ 12
shiftbits                   equ 4
;
;  Initialization
;
                            setlocaldatabank
                            stx value_x
                            tay                         ; just to set the status bits, for what is in A
                            sta value_y
                            beq zero_y
                            bpl positive_y
                            negate a
positive_y                  dec a                       ; -1, because we have eliminated the 0 entry, and also want to support maxbits+1
                            and #(1|maxbits)-1
                            shiftright shiftbits-1      ; shift, but - 1, so that the result is * 2, which we need for the 16-bit lookup table
                            and #$fffe                  ; though, we have to make sure the lower bit is 0. Still quicker than shifting all the way down, then up one.
                            tax
                            lda >math~sqr_fp4bit+2,x
                            sta value_y

zero_y                      lda value_x
                            beq zero_x
                            bpl positive_x
                            negate a
positive_x                  dec a                       ; -1, because we have eliminated the 0 entry, and also want to support maxbits+1
                            and #(1|maxbits)-1
                            shiftright shiftbits-1      ; shift, but - 1, so that the result is * 2, which we need for the 16-bit lookup table
                            and #$fffe                  ; though, we have to make sure the lower bit is 0. Still quicker than shifting all the way down, then up one.
                            tax
                            lda >math~sqr_fp4bit+2,x
zero_x                      clc
                            adc value_y
                            asl a
                            tax
                            lda >math~sqrt_fp4bit,x
                            restoredatabank
                            rtl

value_x                     ds 2
value_y                     ds 2
                            end

; -----------------------------------------------------------------------------
; Get the angle of a 2D vector.
;
; The input vector values can be in any range, as we are using the ratio, rather than
; an absolute.  However, only the most significant 5-bits will be used.
; This is not necessarily the upper most, it will use the max of each component
; to determine the most significant bits.
;
; Small in both starting values. will yield rather course approximations.
;
; Parameters:
; The vector in X and A, with the x coordinate in x, and the Y in A.
; Returns:
; Angle in A, 0 - 255, with 0, going 'up', i.e. 0,-y, and going clock-wise from there.
math~vec2_angle             start seg_mathlib
                            using math_tables
                            using applib_data

; The number of significant bits we will use
maxbits                     equ 5
maskbits                    equ +((1|maxbits)-1)        ; odd, that I can't have a ( as the first character, it will throw an error
testbits                    equ +((maskbits*-1)-1)      ; the lack of a bit-wise invert is annoying

; Using scratch space on the shared_dp
                            begin_struct mathlib~shared_dp~start
sign_x                      decl word
sign_y                      decl word
value_x                     decl word
value_y                     decl word
                            end_struct

                            phd                         ; 4
patch~math~vec2_angle       entry
                            pea $0000                   ; 5
                            pld                         ; 5

; Save the original values, so I can get the origin signs.
                            stx <sign_x
                            sta <sign_y
; Make both positive (put them in quadrant 2, which is what our lookup table is based on)
                            tay                         ; just to set the status bits, for what is in A
                            bpl positive_y
                            negate a
positive_y                  sta <value_y
                            txa
                            bpl positive_x
                            negate a
positive_x                  anop
; Now shift both values, until the X component (in A), does not have bits, outside the max bits range
shift_loop_x                bit #testbits
                            beq no_bits_x
                            lsr <value_y
                            lsr a
                            bne shift_loop_x            ; loop, unless we went to 0.
no_bits_x                   anop
                            sta <value_x
; Now shift both values, until the Y component (in A), does not have bits, outside the max bits range
                            lda <value_y
shift_loop_y                bit #testbits
                            beq no_bits_y
                            lsr <value_x
                            lsr a
                            bne shift_loop_y
no_bits_y                   anop
; Now shift the Y component, which we have in A, up into the high bits
                            shiftleft maxbits
                            ora <value_x                 ; Merge with the X value in the lower bits, to make the lookup value
                            asl a                       ; x 2 for the lookup
                            tax
                            lda >math~slope_to_angle,x
; Now determine how we have to adjust this, to get the the correct quadrant.
                            bit <sign_y
                            bmi neg_y
                            bit <sign_x
                            bmi neg_x
; Postive x, positive y, (2nd quadrant), 180 - angle, (-angle + 180)
                            negate a
                            clc
                            adc #math~angle_180
                            restoredp
                            rtl
; Positive y, negative x, (3th quadrant), add 180
neg_x                       clc
                            adc #math~angle_180
                            restoredp
                            rtl
neg_y                       bit <sign_x
                            bmi neg_y_and_x
; Positive x, negative y, (1st quadrant), do nothing, this matches the table
                            restoredp
                            rtl
; Negative x, negative y, (4th quadrant), 360 - angle, or (-angle + 360)
neg_y_and_x                 negate a
                            clc
                            adc #math~angle_range
                            restoredp
                            rtl
                            end

; -----------------------------------------------------------------------------
; Get the angle of a 2D vector.
;
; The input vector values can be in any range, as we are using the ratio, rather than
; an absolute.  However, only the most significant 5-bits will be used.
; This is not necessarily the upper most, it will use the max of each component
; to determine the most significant bits.
;
; This version returns an angle index, 0-63, and a quadrant index in x
;
; Small in both starting values. will yield rather course approximations.
;
; Parameters:
; The vector in X and A, with the x coordinate in x, and the Y in A.
; Returns:
; Quadrant angle in A, 0 - 63, and quadrant value, x 2, in X
math~vec2_angle_quadrant    start seg_mathlib
                            using math_tables

; The number of significant bits we will use
maxbits                     equ 5
maskbits                    equ +((1|maxbits)-1)        ; odd, that I can't have a ( as the first character, it will throw an error
testbits                    equ +((maskbits*-1)-1)      ; the lack of a bit-wise invert is annoying

; Using scratch space on the shared_dp
                            begin_struct mathlib~shared_dp~start
sign_x                      decl word
sign_y                      decl word
value_x                     decl word
value_y                     decl word
                            end_struct

                            phd
patch~math~vec2_angle_quadrant entry
                            pea $0000
                            pld

; Save the original values, so I can get the origin signs.
                            stx <sign_x
                            sta <sign_y
; Make both positive (put them in quadrant 2, which is what our lookup table is based on)
                            tay                         ; just to set the status bits, for what is in A
                            bpl positive_y
                            negate a
positive_y                  sta <value_y
                            txa
                            bpl positive_x
                            negate a
positive_x                  anop
; Now shift both values, until the X component (in A), does not have bits, outside the max bits range
shift_loop_x                bit #testbits
                            beq no_bits_x
                            lsr <value_y
                            lsr a
                            bne shift_loop_x            ; loop, unless we went to 0.
no_bits_x                   anop
                            sta <value_x
; Now shift both values, until the Y component (in A), does not have bits, outside the max bits range
                            lda <value_y
shift_loop_y                bit #testbits
                            beq no_bits_y
                            lsr <value_x
                            lsr a
                            bne shift_loop_y
no_bits_y                   anop
; Now shift the Y component, which we have in A, up into the high bits
                            shiftleft maxbits
                            ora <value_x                ; Merge with the X value in the lower bits, to make the lookup value
                            asl a                       ; x 2 for the lookup
                            tax
                            lda >math~slope_to_angle,x
; Now determine how we have to adjust this, to get the the correct quadrant.
                            bit <sign_y
                            bmi neg_y
                            bit <sign_x
                            bmi neg_x
; Postive x, positive y, (2nd quadrant), 180 - angle, (-angle + 180)
                            ldx #1*2
                            pld
                            rtl
; Positive y, negative x, (3th quadrant), add 180
neg_x                       ldx #2*2
                            restoredp
                            rtl
neg_y                       bit <sign_x
                            bmi neg_y_and_x
; Positive x, negative y, (1st quadrant), do nothing, this matches the table
                            ldx #0*2
                            restoredp
                            rtl
; Negative x, negative y, (4th quadrant), 360 - angle, or (-angle + 360)
neg_y_and_x                 ldx #3*2
                            restoredp
                            rtl

                            end

;------------------------------------------------------------------------------
; Pseudo Random Number Generator
;
; This is the same as ~ranx from the Orca libraries, except it is unrolled
; so it is a bit quicker, and it does not use the X register anymore.
; Y is also untouched.
;
; The ACC will have the current value of math~rnd_seed in it, on exit,
; except in the extremely rare circumstance, where the upper 14 bytes
; of the 16 byte seed was at $ffffffffffffffffffffffffffffxxxx, in which case, it will contain
; math~rnd_seed - 1.
;
; Minimum cycle time: 107
; Maximum cycle time: 184 (exceptionally rare case though)
;
; The algorithm seems to be a Fibonacci-style adder with an additional
; increment to make sure things don't go to 0.
math~rnd_generate           start seg_mathlib

                            setlocaldatabank                ; 9

                            clc                             ; 2
                            lda math~rnd_seed+14            ; 5
                            adc math~rnd_seed+12            ; 5
                            sta math~rnd_seed+12            ; 5
                            adc math~rnd_seed+10
                            sta math~rnd_seed+10
                            adc math~rnd_seed+8
                            sta math~rnd_seed+8
                            adc math~rnd_seed+6
                            sta math~rnd_seed+6
                            adc math~rnd_seed+4
                            sta math~rnd_seed+4
                            adc math~rnd_seed+2
                            sta math~rnd_seed+2
                            adc math~rnd_seed+0
                            sta math~rnd_seed+0             ; 77 total for the add block

                            inc math~rnd_seed+14            ; 8
                            bne done                        ; 2-3
                            inc math~rnd_seed+12
                            bne done
                            inc math~rnd_seed+10
                            bne done
                            inc math~rnd_seed+8
                            bne done
                            inc math~rnd_seed+6
                            bne done
                            inc math~rnd_seed+4
                            bne done
                            inc math~rnd_seed+2
                            bne done
                            inc math~rnd_seed+0

done                        restoredatabank                 ; 4
                            rtl                             ; 6

math~rnd_seed               entry                       ; using an entry, rather than putting this in a dat segment
                            ds 16

math~rnd_initialize         entry

                            setlocaldatabank
                            sta math~rnd_seed+14
                            sta math~rnd_seed+12
                            sta math~rnd_seed+10
                            sta math~rnd_seed+8
                            sta math~rnd_seed+6
                            sta math~rnd_seed+4
                            sta math~rnd_seed+2
                            sta math~rnd_seed+0
                            restoredatabank

                            rtl

                            end

; From the CC65 library
;
; Random number generator
;
; Written and donated by Sidney Cadot - sidney@ch.twi.tudelft.nl
; 2016-11-07, modified by Brad Smith
; 2019-10-07, modified by Lewis "LRFLEW" Fox
;
; May be distributed with the cc65 runtime using the same license.
;
; int rand (void);
; void srand (unsigned seed);
;
;  Uses 4-byte state.
;  Multiplier must be 1 (mod 4)
;  Added value must be 1 (mod 2)
;  This guarantees max. period (2**32)
;  The quality of entropy in the bits of the seed are poorest in the lowest
;  bits, and best in the highest bits.
;
;  The high 8 bits are used for the low byte A to provide the best entropy in
;  the most commonly used part of the return value.
;
;  Finally XOR with the lower 2 bytes is used on the output, which breaks up
;  some minor deficient sequential patterns. (#951)
;
;  Uses the following LCG values for ax + c (mod m)
;  a = $01010101
;  c = $B3B3B3B3
;  m = $100000000 (32-bit truncation)
;
;  The multiplier was carefully chosen such that it can
;  be computed with 3 adc instructions, and the increment
;  was chosen to have the same value in each byte to allow
;  the addition to be performed in conjunction with the
;  multiplication, adding only 1 additional adc instruction.
;
; The code itself is modified from the cc65 code, just a little for
; formatting and such.
;
; https://github.com/cc65/cc65/blob/master/LICENSE
; Note: This is a 'zlib' license
;
;  LCG functions have less entropy in their lower bits, so the upper bits
;  of the 32-bit seed are returned.  Also, this means that trying to use
;  sub-parts of the resulting 32-bit seed for 'quick' random numbers
;  should be avoided.

math~rnd2_generate          start seg_mathlib

                            setlocaldatabank                ; 9
                            shortm                          ; 3
                            clc                             ; 2
                            lda     math~rnd2_seed+0        ; 4
                            adc     #$B3                    ; 2
                            sta     math~rnd2_seed+0        ; 4
                            adc     math~rnd2_seed+1        ; 4
                            sta     math~rnd2_seed+1        ; 4
                            adc     math~rnd2_seed+2        ; 4
                            sta     math~rnd2_seed+2        ; 4
                            eor     math~rnd2_seed+0        ; 4
                            pha                             ; 3, this will be the high byte of the result
                            lda     math~rnd2_seed+2        ; 4
                            adc     math~rnd2_seed+3        ; 4
                            sta     math~rnd2_seed+3        ; 4
                            eor     math~rnd2_seed+1        ; 4
                            pha                             ; 3
                            longm                           ; 3
                            pla                             ; 5
                            restoredatabank                 ; 4, 78 total
                            rtl                             ; return bit (16-31) in A

math~rnd2_seed              entry
                            ds 4

math~rnd2_initialize        entry
                            sta >math~rnd2_seed
                            sta >math~rnd2_seed+2
                            rtl
                            end

; -----------------------------------------------------------------------------
;  A similar LCG (Linear Congruent Generator) as the CC65 one, but in 16-bits
;  This does have a weaker multiplier.  However, it gives decent results
;  and is quick.
;  LCG functions have less entropy in their lower bits, so the upper bits
;  of the 32-bit seed are returned.  Also, this means that trying to use
;  sub-parts of the resulting 32-bit seed for 'quick' random numbers
;  should be avoided.
;
;  Uses the following LCG values for ax + c (mod m)
;  a = $00010001
;  c = $B3B3B3B3
;  m = $100000000 (32-bit truncation)
math~rnd3_generate          start seg_mathlib

                            clc                             ; 2
                            lda     >math~rnd3_seed+0       ; 6
                            adc     #$B3B3                  ; 3
                            sta     >math~rnd3_seed+0       ; 6
                            adc     >math~rnd3_seed+2       ; 6
                            sta     >math~rnd3_seed+2       ; 6
                            eor     >math~rnd3_seed+0       ; 6, 35 cycles for the main body.

                            rtl                             ; return bit (16-31) in A

math~rnd3_seed              entry
                            ds 4

math~rnd3_initialize        entry
                            sta >math~rnd3_seed
                            sta >math~rnd3_seed+2
                            rtl

                            end

; -----------------------------------------------------------------------------
math_tables                 data seg_mathtables

; Angles from the math lib are an index, from 0 - 255, with 0 being 'up'.
; Up, being 0, -y, and angle values going clock-wise from there.
; This matches the 'direction', that apps use for sprite display.
; The direction range supported by the app, is usually less than the full angle
; range, such as 8, 16 or 32.

math~angle_range            equ 256                     ; inclusive
math~angle_max              equ math~angle_range-1      ; Max value

math~angle_0                equ 0
math~angle_45               equ math~angle_range/8
math~angle_90               equ math~angle_range/4
math~angle_180              equ math~angle_range/2

math~quadrant_1             equ 0
math~quadrant_2             equ 1
math~quadrant_3             equ 2
math~quadrant_4             equ 3

; Index table of 128 steps of 0 - 1, fixed point 16, Linear progression

; Positive values
math~fixed_point_0_to_1_128_steps anop
    dc i'$0000,$0002,$0004,$0006,$0008,$000a,$000c,$000e,$0010,$0012,$0014,$0016,$0018,$001a,$001c,$001e,$0020,$0022,$0024,$0026,$0028,$002a,$002c,$002e,$0030,$0032,$0034,$0036,$0038,$003a,$003c,$003e'
    dc i'$0040,$0042,$0044,$0046,$0048,$004a,$004c,$004e,$0050,$0052,$0054,$0056,$0058,$005a,$005c,$005e,$0060,$0062,$0064,$0066,$0068,$006a,$006c,$006e,$0070,$0072,$0074,$0076,$0078,$007a,$007c,$007e'
    dc i'$0081,$0083,$0085,$0087,$0089,$008b,$008d,$008f,$0091,$0093,$0095,$0097,$0099,$009b,$009d,$009f,$00a1,$00a3,$00a5,$00a7,$00a9,$00ab,$00ad,$00af,$00b1,$00b3,$00b5,$00b7,$00b9,$00bb,$00bd,$00bf'
    dc i'$00c1,$00c3,$00c5,$00c7,$00c9,$00cb,$00cd,$00cf,$00d1,$00d3,$00d5,$00d7,$00d9,$00db,$00dd,$00df,$00e1,$00e3,$00e5,$00e7,$00e9,$00eb,$00ed,$00ef,$00f1,$00f3,$00f5,$00f7,$00f9,$00fb,$00fd,$0100'

; Index table of 128 steps of 0 - 1, fixed point 16, Smoothed Progression
; The progression is slower at each end of the table.  This middle of the table is still half way in the range.

; Positive values
math~fixed_point_0_to_1_128_steps_smoothed anop
    dc i'$0000,$0000,$0000,$0000,$0000,$0001,$0001,$0002,$0002,$0003,$0004,$0005,$0006,$0007,$0008,$0009,$000b,$000c,$000d,$000f,$0011,$0012,$0014,$0016,$0017,$0019,$001b,$001d,$001f,$0021,$0024,$0026'
    dc i'$0028,$002a,$002d,$002f,$0032,$0034,$0037,$0039,$003c,$003e,$0041,$0044,$0046,$0049,$004c,$004f,$0052,$0054,$0057,$005a,$005d,$0060,$0063,$0066,$0069,$006c,$006f,$0072,$0075,$0078,$007b,$007e'
    dc i'$0081,$0084,$0087,$008a,$008d,$0090,$0093,$0096,$0099,$009c,$009f,$00a2,$00a5,$00a8,$00ab,$00ad,$00b0,$00b3,$00b6,$00b9,$00bb,$00be,$00c1,$00c3,$00c6,$00c8,$00cb,$00cd,$00d0,$00d2,$00d5,$00d7'
    dc i'$00d9,$00db,$00de,$00e0,$00e2,$00e4,$00e6,$00e8,$00e9,$00eb,$00ed,$00ee,$00f0,$00f2,$00f3,$00f4,$00f6,$00f7,$00f8,$00f9,$00fa,$00fb,$00fc,$00fd,$00fd,$00fe,$00fe,$00ff,$00ff,$00ff,$00ff,$0100'

; A table of 4 bit values, scaled over 5 bits.
; Each row represents the integer value of, (row index * (column index / 32))
; Ex. Row 9, which is the value of 8, scaled over 32 divisions, so it starts with 0 (8 * (0 / 32)) and ends with 8 (8 * (32 / 32))
; Each row is (32 * sizeof(word)) in length
; Note, these have rounding in them, so small values will reach their max before the last entry.
; Maybe make another table that is rounded down?

; Positive values
math~positive_4bits_scaled_over_5bits anop
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000'
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001'
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002'
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0003,$0003,$0003,$0003,$0003'
    dc i'$0000,$0000,$0000,$0000,$0000,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0004,$0004,$0004,$0004'
    dc i'$0000,$0000,$0000,$0000,$0001,$0001,$0001,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0003,$0003,$0003,$0003,$0003,$0003,$0004,$0004,$0004,$0004,$0004,$0004,$0005,$0005,$0005'
    dc i'$0000,$0000,$0000,$0001,$0001,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0002,$0002,$0003,$0003,$0003,$0003,$0003,$0004,$0004,$0004,$0004,$0004,$0004,$0005,$0005,$0005,$0005,$0005,$0006,$0006'
    dc i'$0000,$0000,$0000,$0001,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0002,$0003,$0003,$0003,$0003,$0004,$0004,$0004,$0004,$0004,$0005,$0005,$0005,$0005,$0005,$0006,$0006,$0006,$0006,$0007,$0007'
    dc i'$0000,$0000,$0000,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0002,$0003,$0003,$0003,$0004,$0004,$0004,$0004,$0004,$0005,$0005,$0005,$0006,$0006,$0006,$0006,$0006,$0007,$0007,$0007,$0008,$0008'
    dc i'$0000,$0000,$0001,$0001,$0001,$0001,$0002,$0002,$0002,$0003,$0003,$0003,$0003,$0004,$0004,$0004,$0004,$0005,$0005,$0005,$0006,$0006,$0006,$0006,$0007,$0007,$0007,$0008,$0008,$0008,$0008,$0009'
    dc i'$0000,$0000,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0003,$0003,$0003,$0004,$0004,$0004,$0005,$0005,$0005,$0006,$0006,$0006,$0007,$0007,$0007,$0008,$0008,$0008,$0008,$0009,$0009,$0009,$000a'
    dc i'$0000,$0000,$0001,$0001,$0001,$0002,$0002,$0002,$0003,$0003,$0003,$0004,$0004,$0004,$0005,$0005,$0006,$0006,$0006,$0007,$0007,$0007,$0008,$0008,$0008,$0009,$0009,$0009,$000a,$000a,$000a,$000b'
    dc i'$0000,$0000,$0001,$0001,$0002,$0002,$0002,$0003,$0003,$0003,$0004,$0004,$0004,$0005,$0005,$0006,$0006,$0006,$0007,$0007,$0008,$0008,$0008,$0009,$0009,$0009,$000a,$000a,$000a,$000b,$000b,$000c'
    dc i'$0000,$0000,$0001,$0001,$0002,$0002,$0002,$0003,$0003,$0004,$0004,$0004,$0005,$0005,$0006,$0006,$0006,$0007,$0007,$0008,$0008,$0009,$0009,$0009,$000a,$000a,$000b,$000b,$000b,$000c,$000c,$000d'
    dc i'$0000,$0000,$0001,$0001,$0002,$0002,$0003,$0003,$0004,$0004,$0004,$0005,$0005,$0006,$0006,$0007,$0007,$0007,$0008,$0008,$0009,$0009,$000a,$000a,$000a,$000b,$000b,$000c,$000c,$000d,$000d,$000e'
    dc i'$0000,$0000,$0001,$0001,$0002,$0002,$0003,$0003,$0004,$0004,$0005,$0005,$0006,$0006,$0007,$0007,$0008,$0008,$0008,$0009,$0009,$000a,$000a,$000b,$000b,$000c,$000c,$000d,$000d,$000e,$000e,$000f'
; Negative values
; Note, keep the negative table, right after the positive table, to allow for offset adjustment from the postive table to get to it, rather than a direct reference
math~negative_4bits_scaled_over_5bits anop
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000'
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff'
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe'
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffd,$fffd'
    dc i'$0000,$0000,$0000,$0000,$0000,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffc'
    dc i'$0000,$0000,$0000,$0000,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffb,$fffb,$fffb'
    dc i'$0000,$0000,$0000,$ffff,$ffff,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffb,$fffb,$fffb,$fffb,$fffb,$fffa,$fffa'
    dc i'$0000,$0000,$0000,$ffff,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffc,$fffc,$fffb,$fffb,$fffb,$fffb,$fffb,$fffa,$fffa,$fffa,$fffa,$fff9,$fff9'
    dc i'$0000,$0000,$0000,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffc,$fffc,$fffb,$fffb,$fffb,$fffa,$fffa,$fffa,$fffa,$fffa,$fff9,$fff9,$fff9,$fff8,$fff8'
    dc i'$0000,$0000,$ffff,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffc,$fffb,$fffb,$fffb,$fffa,$fffa,$fffa,$fffa,$fff9,$fff9,$fff9,$fff8,$fff8,$fff8,$fff8,$fff7'
    dc i'$0000,$0000,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffb,$fffb,$fffb,$fffa,$fffa,$fffa,$fff9,$fff9,$fff9,$fff8,$fff8,$fff8,$fff8,$fff7,$fff7,$fff7,$fff6'
    dc i'$0000,$0000,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffb,$fffb,$fffa,$fffa,$fffa,$fff9,$fff9,$fff9,$fff8,$fff8,$fff8,$fff7,$fff7,$fff7,$fff6,$fff6,$fff6,$fff5'
    dc i'$0000,$0000,$ffff,$ffff,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffb,$fffb,$fffa,$fffa,$fffa,$fff9,$fff9,$fff8,$fff8,$fff8,$fff7,$fff7,$fff7,$fff6,$fff6,$fff6,$fff5,$fff5,$fff4'
    dc i'$0000,$0000,$ffff,$ffff,$fffe,$fffe,$fffe,$fffd,$fffd,$fffc,$fffc,$fffc,$fffb,$fffb,$fffa,$fffa,$fffa,$fff9,$fff9,$fff8,$fff8,$fff7,$fff7,$fff7,$fff6,$fff6,$fff5,$fff5,$fff5,$fff4,$fff4,$fff3'
    dc i'$0000,$0000,$ffff,$ffff,$fffe,$fffe,$fffd,$fffd,$fffc,$fffc,$fffc,$fffb,$fffb,$fffa,$fffa,$fff9,$fff9,$fff9,$fff8,$fff8,$fff7,$fff7,$fff6,$fff6,$fff6,$fff5,$fff5,$fff4,$fff4,$fff3,$fff3,$fff2'
    dc i'$0000,$0000,$ffff,$ffff,$fffe,$fffe,$fffd,$fffd,$fffc,$fffc,$fffb,$fffb,$fffa,$fffa,$fff9,$fff9,$fff8,$fff8,$fff8,$fff7,$fff7,$fff6,$fff6,$fff5,$fff5,$fff4,$fff4,$fff3,$fff3,$fff2,$fff2,$fff1'

; A table of 9 bit values, scaled to 5 bits
    ago .skip
; Positive values
math~positive_9bits_scaled_to_5bits anop
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0002,$0002,$0002,$0002,$0002,$0002,$0002'
    dc i'$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0004,$0004,$0004,$0004,$0004,$0004'
    dc i'$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0006,$0006,$0006,$0006,$0006'
    dc i'$0006,$0006,$0006,$0006,$0006,$0006,$0006,$0006,$0006,$0006,$0006,$0006,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0008,$0008,$0008,$0008'
    dc i'$0008,$0008,$0008,$0008,$0008,$0008,$0008,$0008,$0008,$0008,$0008,$0008,$0008,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$0009,$000a,$000a,$000a'
    dc i'$000a,$000a,$000a,$000a,$000a,$000a,$000a,$000a,$000a,$000a,$000a,$000a,$000a,$000a,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000b,$000c,$000c'
    dc i'$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000c,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000d,$000e'
    dc i'$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000e,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f,$000f'
    dc i'$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0010,$0011,$0011,$0011,$0011,$0011,$0011,$0011,$0011,$0011,$0011,$0011,$0011,$0011,$0011,$0011'
    dc i'$0011,$0011,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0012,$0013,$0013,$0013,$0013,$0013,$0013,$0013,$0013,$0013,$0013,$0013,$0013,$0013,$0013'
    dc i'$0013,$0013,$0013,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0014,$0015,$0015,$0015,$0015,$0015,$0015,$0015,$0015,$0015,$0015,$0015,$0015,$0015'
    dc i'$0015,$0015,$0015,$0015,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0016,$0017,$0017,$0017,$0017,$0017,$0017,$0017,$0017,$0017,$0017,$0017,$0017'
    dc i'$0017,$0017,$0017,$0017,$0017,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0018,$0019,$0019,$0019,$0019,$0019,$0019,$0019,$0019,$0019,$0019,$0019'
    dc i'$0019,$0019,$0019,$0019,$0019,$0019,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001a,$001b,$001b,$001b,$001b,$001b,$001b,$001b,$001b,$001b,$001b'
    dc i'$001b,$001b,$001b,$001b,$001b,$001b,$001b,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001c,$001d,$001d,$001d,$001d,$001d,$001d,$001d,$001d,$001d'
    dc i'$001d,$001d,$001d,$001d,$001d,$001d,$001d,$001d,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001e,$001f,$001f,$001f,$001f,$001f,$001f,$001f,$001f'

; Negative values
math~negative_9bits_scaled_to_5bits anop
    dc i'$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$ffff,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe'
    dc i'$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffe,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffd,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc'
    dc i'$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffc,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffb,$fffa,$fffa,$fffa,$fffa,$fffa'
    dc i'$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fffa,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff9,$fff8,$fff8,$fff8,$fff8'
    dc i'$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff8,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff7,$fff6,$fff6,$fff6'
    dc i'$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff6,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff5,$fff4,$fff4'
    dc i'$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff4,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff3,$fff2'
    dc i'$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff2,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1,$fff1'
    dc i'$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$fff0,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef,$ffef'
    dc i'$ffef,$ffef,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffee,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed,$ffed'
    dc i'$ffed,$ffed,$ffed,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffec,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb,$ffeb'
    dc i'$ffeb,$ffeb,$ffeb,$ffeb,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffea,$ffe9,$ffe9,$ffe9,$ffe9,$ffe9,$ffe9,$ffe9,$ffe9,$ffe9,$ffe9,$ffe9,$ffe9'
    dc i'$ffe9,$ffe9,$ffe9,$ffe9,$ffe9,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe8,$ffe7,$ffe7,$ffe7,$ffe7,$ffe7,$ffe7,$ffe7,$ffe7,$ffe7,$ffe7,$ffe7'
    dc i'$ffe7,$ffe7,$ffe7,$ffe7,$ffe7,$ffe7,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe6,$ffe5,$ffe5,$ffe5,$ffe5,$ffe5,$ffe5,$ffe5,$ffe5,$ffe5,$ffe5'
    dc i'$ffe5,$ffe5,$ffe5,$ffe5,$ffe5,$ffe5,$ffe5,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe4,$ffe3,$ffe3,$ffe3,$ffe3,$ffe3,$ffe3,$ffe3,$ffe3,$ffe3'
    dc i'$ffe3,$ffe3,$ffe3,$ffe3,$ffe3,$ffe3,$ffe3,$ffe3,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe2,$ffe1,$ffe1,$ffe1,$ffe1,$ffe1,$ffe1,$ffe1,$ffe1'
.skip

; A ramp of 5 bit values, each with a scalar of itself
; Each ramp entry is ends at index - 1, meaning it is non-inclusive of the index / index-max

; Positive values
math~positive_5bit_scalar_ramp anop
    dc i'$0000'
    dc i'$0000,$0010'
    dc i'$0000,$000b,$0015'
    dc i'$0000,$0008,$0010,$0018'
    dc i'$0000,$0006,$000d,$0013,$001a'
    dc i'$0000,$0005,$000b,$0010,$0015,$001b'
    dc i'$0000,$0005,$0009,$000e,$0012,$0017,$001b'
    dc i'$0000,$0004,$0008,$000c,$0010,$0014,$0018,$001c'
    dc i'$0000,$0004,$0007,$000b,$000e,$0012,$0015,$0019,$001c'
    dc i'$0000,$0003,$0006,$000a,$000d,$0010,$0013,$0016,$001a,$001d'
    dc i'$0000,$0003,$0006,$0009,$000c,$000f,$0011,$0014,$0017,$001a,$001d'
    dc i'$0000,$0003,$0005,$0008,$000b,$000d,$0010,$0013,$0015,$0018,$001b,$001d'
    dc i'$0000,$0002,$0005,$0007,$000a,$000c,$000f,$0011,$0014,$0016,$0019,$001b,$001e'
    dc i'$0000,$0002,$0005,$0007,$0009,$000b,$000e,$0010,$0012,$0015,$0017,$0019,$001b,$001e'
    dc i'$0000,$0002,$0004,$0006,$0009,$000b,$000d,$000f,$0011,$0013,$0015,$0017,$001a,$001c,$001e'
    dc i'$0000,$0002,$0004,$0006,$0008,$000a,$000c,$000e,$0010,$0012,$0014,$0016,$0018,$001a,$001c,$001e'
    dc i'$0000,$0002,$0004,$0006,$0008,$0009,$000b,$000d,$000f,$0011,$0013,$0015,$0017,$0018,$001a,$001c,$001e'
    dc i'$0000,$0002,$0004,$0005,$0007,$0009,$000b,$000c,$000e,$0010,$0012,$0014,$0015,$0017,$0019,$001b,$001c,$001e'
    dc i'$0000,$0002,$0003,$0005,$0007,$0008,$000a,$000c,$000d,$000f,$0011,$0013,$0014,$0016,$0018,$0019,$001b,$001d,$001e'
    dc i'$0000,$0002,$0003,$0005,$0006,$0008,$000a,$000b,$000d,$000e,$0010,$0012,$0013,$0015,$0016,$0018,$001a,$001b,$001d,$001e'
    dc i'$0000,$0002,$0003,$0005,$0006,$0008,$0009,$000b,$000c,$000e,$000f,$0011,$0012,$0014,$0015,$0017,$0018,$001a,$001b,$001d,$001e'
    dc i'$0000,$0001,$0003,$0004,$0006,$0007,$0009,$000a,$000c,$000d,$000f,$0010,$0011,$0013,$0014,$0016,$0017,$0019,$001a,$001c,$001d,$001f'
    dc i'$0000,$0001,$0003,$0004,$0006,$0007,$0008,$000a,$000b,$000d,$000e,$000f,$0011,$0012,$0013,$0015,$0016,$0018,$0019,$001a,$001c,$001d,$001f'
    dc i'$0000,$0001,$0003,$0004,$0005,$0007,$0008,$0009,$000b,$000c,$000d,$000f,$0010,$0011,$0013,$0014,$0015,$0017,$0018,$0019,$001b,$001c,$001d,$001f'
    dc i'$0000,$0001,$0003,$0004,$0005,$0006,$0008,$0009,$000a,$000c,$000d,$000e,$000f,$0011,$0012,$0013,$0014,$0016,$0017,$0018,$001a,$001b,$001c,$001d,$001f'
    dc i'$0000,$0001,$0002,$0004,$0005,$0006,$0007,$0009,$000a,$000b,$000c,$000e,$000f,$0010,$0011,$0012,$0014,$0015,$0016,$0017,$0019,$001a,$001b,$001c,$001e,$001f'
    dc i'$0000,$0001,$0002,$0004,$0005,$0006,$0007,$0008,$0009,$000b,$000c,$000d,$000e,$000f,$0011,$0012,$0013,$0014,$0015,$0017,$0018,$0019,$001a,$001b,$001c,$001e,$001f'
    dc i'$0000,$0001,$0002,$0003,$0005,$0006,$0007,$0008,$0009,$000a,$000b,$000d,$000e,$000f,$0010,$0011,$0012,$0013,$0015,$0016,$0017,$0018,$0019,$001a,$001b,$001d,$001e,$001f'
    dc i'$0000,$0001,$0002,$0003,$0004,$0006,$0007,$0008,$0009,$000a,$000b,$000c,$000d,$000e,$000f,$0011,$0012,$0013,$0014,$0015,$0016,$0017,$0018,$0019,$001a,$001c,$001d,$001e,$001f'
    dc i'$0000,$0001,$0002,$0003,$0004,$0005,$0006,$0007,$0009,$000a,$000b,$000c,$000d,$000e,$000f,$0010,$0011,$0012,$0013,$0014,$0015,$0016,$0017,$0019,$001a,$001b,$001c,$001d,$001e,$001f'
    dc i'$0000,$0001,$0002,$0003,$0004,$0005,$0006,$0007,$0008,$0009,$000a,$000b,$000c,$000d,$000e,$000f,$0011,$0012,$0013,$0014,$0015,$0016,$0017,$0018,$0019,$001a,$001b,$001c,$001d,$001e,$001f'
; An offset table, into the scalar ramp

math~positive_5bit_scalar_ramp_offsets anop
    dc i'$0000'
    dc i'$0000'
    dc i'$0002'
    dc i'$0006'
    dc i'$000c'
    dc i'$0014'
    dc i'$001e'
    dc i'$002a'
    dc i'$0038'
    dc i'$0048'
    dc i'$005a'
    dc i'$006e'
    dc i'$0084'
    dc i'$009c'
    dc i'$00b6'
    dc i'$00d2'
    dc i'$00f0'
    dc i'$0110'
    dc i'$0132'
    dc i'$0156'
    dc i'$017c'
    dc i'$01a4'
    dc i'$01ce'
    dc i'$01fa'
    dc i'$0228'
    dc i'$0258'
    dc i'$028a'
    dc i'$02be'
    dc i'$02f4'
    dc i'$032c'
    dc i'$0366'
    dc i'$03a2'

; The next few tables are mainly for some pixel routines, to do specific mulitplications.

; Index table where the index is the multiplier and the multiplicand is 7
math~mul7_256 anop
    dc i'$0000,$0007,$000e,$0015,$001c,$0023,$002a,$0031,$0038,$003f,$0046,$004d,$0054,$005b,$0062,$0069,$0070,$0077,$007e,$0085,$008c,$0093,$009a,$00a1,$00a8,$00af,$00b6,$00bd,$00c4,$00cb,$00d2,$00d9'
    dc i'$00e0,$00e7,$00ee,$00f5,$00fc,$0103,$010a,$0111,$0118,$011f,$0126,$012d,$0134,$013b,$0142,$0149,$0150,$0157,$015e,$0165,$016c,$0173,$017a,$0181,$0188,$018f,$0196,$019d,$01a4,$01ab,$01b2,$01b9'
    dc i'$01c0,$01c7,$01ce,$01d5,$01dc,$01e3,$01ea,$01f1,$01f8,$01ff,$0206,$020d,$0214,$021b,$0222,$0229,$0230,$0237,$023e,$0245,$024c,$0253,$025a,$0261,$0268,$026f,$0276,$027d,$0284,$028b,$0292,$0299'
    dc i'$02a0,$02a7,$02ae,$02b5,$02bc,$02c3,$02ca,$02d1,$02d8,$02df,$02e6,$02ed,$02f4,$02fb,$0302,$0309,$0310,$0317,$031e,$0325,$032c,$0333,$033a,$0341,$0348,$034f,$0356,$035d,$0364,$036b,$0372,$0379'
    dc i'$0380,$0387,$038e,$0395,$039c,$03a3,$03aa,$03b1,$03b8,$03bf,$03c6,$03cd,$03d4,$03db,$03e2,$03e9,$03f0,$03f7,$03fe,$0405,$040c,$0413,$041a,$0421,$0428,$042f,$0436,$043d,$0444,$044b,$0452,$0459'
    dc i'$0460,$0467,$046e,$0475,$047c,$0483,$048a,$0491,$0498,$049f,$04a6,$04ad,$04b4,$04bb,$04c2,$04c9,$04d0,$04d7,$04de,$04e5,$04ec,$04f3,$04fa,$0501,$0508,$050f,$0516,$051d,$0524,$052b,$0532,$0539'
    dc i'$0540,$0547,$054e,$0555,$055c,$0563,$056a,$0571,$0578,$057f,$0586,$058d,$0594,$059b,$05a2,$05a9,$05b0,$05b7,$05be,$05c5,$05cc,$05d3,$05da,$05e1,$05e8,$05ef,$05f6,$05fd,$0604,$060b,$0612,$0619'
    dc i'$0620,$0627,$062e,$0635,$063c,$0643,$064a,$0651,$0658,$065f,$0666,$066d,$0674,$067b,$0682,$0689,$0690,$0697,$069e,$06a5,$06ac,$06b3,$06ba,$06c1,$06c8,$06cf,$06d6,$06dd,$06e4,$06eb,$06f2,$06f9'

; Index table where the index is the multiplier and the multiplicand is 7,
; with an additional 4 added to each entry.  This is specific for some grlib functions, and only needs a screen width range (80 words)
math~mul7plus4_80 anop
    dc i'$0004,$000b,$0012,$0019,$0020,$0027,$002e,$0035,$003c,$0043,$004a,$0051,$0058,$005f,$0066,$006d,$0074,$007b,$0082,$0089,$0090,$0097,$009e,$00a5,$00ac,$00b3,$00ba,$00c1,$00c8,$00cf,$00d6,$00dd'
    dc i'$00e4,$00eb,$00f2,$00f9,$0100,$0107,$010e,$0115,$011c,$0123,$012a,$0131,$0138,$013f,$0146,$014d,$0154,$015b,$0162,$0169,$0170,$0177,$017e,$0185,$018c,$0193,$019a,$01a1,$01a8,$01af,$01b6,$01bd'
    dc i'$01c4,$01cb,$01d2,$01d9,$01e0,$01e7,$01ee,$01f5,$01fc,$0203,$020a,$0211,$0218,$021f,$0226,$022d'

; Index table where the index is the multiplier and the multiplicand is 9, multiplier range 0 - 79
math~mul9_80 anop
    dc i'$0000,$0009,$0012,$001b,$0024,$002d,$0036,$003f,$0048,$0051,$005a,$0063,$006c,$0075,$007e,$0087,$0090,$0099,$00a2,$00ab,$00b4,$00bd,$00c6,$00cf,$00d8,$00e1,$00ea,$00f3,$00fc,$0105,$010e,$0117'
    dc i'$0120,$0129,$0132,$013b,$0144,$014d,$0156,$015f,$0168,$0171,$017a,$0183,$018c,$0195,$019e,$01a7,$01b0,$01b9,$01c2,$01cb,$01d4,$01dd,$01e6,$01ef,$01f8,$0201,$020a,$0213,$021c,$0225,$022e,$0237'
    dc i'$0240,$0249,$0252,$025b,$0264,$026d,$0276,$027f,$0288,$0291,$029a,$02a3,$02ac,$02b5,$02be,$02c7'

; Index table where the index is the multiplier and the multiplicand is 7, multiplier range 0 - 79
; This has an additional 4 added to each entry.  This is specific for some grlib functions.
math~mul9plus4_80 anop
    dc i'$0004,$000d,$0016,$001f,$0028,$0031,$003a,$0043,$004c,$0055,$005e,$0067,$0070,$0079,$0082,$008b,$0094,$009d,$00a6,$00af,$00b8,$00c1,$00ca,$00d3,$00dc,$00e5,$00ee,$00f7,$0100,$0109,$0112,$011b'
    dc i'$0124,$012d,$0136,$013f,$0148,$0151,$015a,$0163,$016c,$0175,$017e,$0187,$0190,$0199,$01a2,$01ab,$01b4,$01bd,$01c6,$01cf,$01d8,$01e1,$01ea,$01f3,$01fc,$0205,$020e,$0217,$0220,$0229,$0232,$023b'
    dc i'$0244,$024d,$0256,$025f,$0268,$0271,$027a,$0283,$028c,$0295,$029e,$02a7,$02b0,$02b9,$02c2,$02cb'

; Index table where the index is the multiplier and the multiplicand is 23, multiplier range 0 - 79
math~mul23_80 anop
    dc i'$0000,$0017,$002e,$0045,$005c,$0073,$008a,$00a1,$00b8,$00cf,$00e6,$00fd,$0114,$012b,$0142,$0159,$0170,$0187,$019e,$01b5,$01cc,$01e3,$01fa,$0211,$0228,$023f,$0256,$026d,$0284,$029b,$02b2,$02c9'
    dc i'$02e0,$02f7,$030e,$0325,$033c,$0353,$036a,$0381,$0398,$03af,$03c6,$03dd,$03f4,$040b,$0422,$0439,$0450,$0467,$047e,$0495,$04ac,$04c3,$04da,$04f1,$0508,$051f,$0536,$054d,$0564,$057b,$0592,$05a9'
    dc i'$05c0,$05d7,$05ee,$0605,$061c,$0633,$064a,$0661,$0678,$068f,$06a6,$06bd,$06d4,$06eb,$0702,$0719'

; Index table where the index is the multiplier and the multiplicand is 23, multiplier range 0 - 79
; This has an additional 4 added to each entry.  This is specific for some grlib functions.
math~mul23plus4_80 anop
    dc i'$0004,$001b,$0032,$0049,$0060,$0077,$008e,$00a5,$00bc,$00d3,$00ea,$0101,$0118,$012f,$0146,$015d,$0174,$018b,$01a2,$01b9,$01d0,$01e7,$01fe,$0215,$022c,$0243,$025a,$0271,$0288,$029f,$02b6,$02cd'
    dc i'$02e4,$02fb,$0312,$0329,$0340,$0357,$036e,$0385,$039c,$03b3,$03ca,$03e1,$03f8,$040f,$0426,$043d,$0454,$046b,$0482,$0499,$04b0,$04c7,$04de,$04f5,$050c,$0523,$053a,$0551,$0568,$057f,$0596,$05ad'
    dc i'$05c4,$05db,$05f2,$0609,$0620,$0637,$064e,$0665,$067c,$0693,$06aa,$06c1,$06d8,$06ef,$0706,$071d'

; Index table where the index is the multiplier and the multiplicand is 14, multiplier range 0 - 79
math~mul14_80 anop
    dc i'$0000,$000e,$001c,$002a,$0038,$0046,$0054,$0062,$0070,$007e,$008c,$009a,$00a8,$00b6,$00c4,$00d2,$00e0,$00ee,$00fc,$010a,$0118,$0126,$0134,$0142,$0150,$015e,$016c,$017a,$0188,$0196,$01a4,$01b2'
    dc i'$01c0,$01ce,$01dc,$01ea,$01f8,$0206,$0214,$0222,$0230,$023e,$024c,$025a,$0268,$0276,$0284,$0292,$02a0,$02ae,$02bc,$02ca,$02d8,$02e6,$02f4,$0302,$0310,$031e,$032c,$033a,$0348,$0356,$0364,$0372'
    dc i'$0380,$038e,$039c,$03aa,$03b8,$03c6,$03d4,$03e2,$03f0,$03fe,$040c,$041a,$0428,$0436,$0444,$0452'

; Index table where the index is the multiplier and the multiplicand is 14, multiplier range 0 - 79
; This has an additional 4 added to each entry.  This is specific for some grlib functions.
math~mul14plus4_80 anop
    dc i'$0004,$0012,$0020,$002e,$003c,$004a,$0058,$0066,$0074,$0082,$0090,$009e,$00ac,$00ba,$00c8,$00d6,$00e4,$00f2,$0100,$010e,$011c,$012a,$0138,$0146,$0154,$0162,$0170,$017e,$018c,$019a,$01a8,$01b6'
    dc i'$01c4,$01d2,$01e0,$01ee,$01fc,$020a,$0218,$0226,$0234,$0242,$0250,$025e,$026c,$027a,$0288,$0296,$02a4,$02b2,$02c0,$02ce,$02dc,$02ea,$02f8,$0306,$0314,$0322,$0330,$033e,$034c,$035a,$0368,$0376'
    dc i'$0384,$0392,$03a0,$03ae,$03bc,$03ca,$03d8,$03e6,$03f4,$0402,$0410,$041e,$042c,$043a,$0448,$0456'

; Index table where the index is the multiplier and the multiplicand is 5, multiplier range 0 - 79
math~mul5_80 anop
    dc i'$0000,$0005,$000a,$000f,$0014,$0019,$001e,$0023,$0028,$002d,$0032,$0037,$003c,$0041,$0046,$004b,$0050,$0055,$005a,$005f,$0064,$0069,$006e,$0073,$0078,$007d,$0082,$0087,$008c,$0091,$0096,$009b'
    dc i'$00a0,$00a5,$00aa,$00af,$00b4,$00b9,$00be,$00c3,$00c8,$00cd,$00d2,$00d7,$00dc,$00e1,$00e6,$00eb,$00f0,$00f5,$00fa,$00ff,$0104,$0109,$010e,$0113,$0118,$011d,$0122,$0127,$012c,$0131,$0136,$013b'
    dc i'$0140,$0145,$014a,$014f,$0154,$0159,$015e,$0163,$0168,$016d,$0172,$0177,$017c,$0181,$0186,$018b'

; Index table where the index is the multiplier and the multiplicand is 6, multiplier range 0 - 79
math~mul6_80 anop
    dc i'$0000,$0006,$000c,$0012,$0018,$001e,$0024,$002a,$0030,$0036,$003c,$0042,$0048,$004e,$0054,$005a,$0060,$0066,$006c,$0072,$0078,$007e,$0084,$008a,$0090,$0096,$009c,$00a2,$00a8,$00ae,$00b4,$00ba'
    dc i'$00c0,$00c6,$00cc,$00d2,$00d8,$00de,$00e4,$00ea,$00f0,$00f6,$00fc,$0102,$0108,$010e,$0114,$011a,$0120,$0126,$012c,$0132,$0138,$013e,$0144,$014a,$0150,$0156,$015c,$0162,$0168,$016e,$0174,$017a'
    dc i'$0180,$0186,$018c,$0192,$0198,$019e,$01a4,$01aa,$01b0,$01b6,$01bc,$01c2,$01c8,$01ce,$01d4,$01da'

;
; Tables for a rotated vector of varying magnitudes.  This is useful for movement updates.
; These are essentially cos/sin values, for a circle with an angle of 0-31, then multiplied by a scalar
;
;
; Rotation for magnitude 0.25
math~dir_32_rot_mag_8_step_1_of_32 anop
    dc i'$0000,$ffc0,$000c,$ffc1,$0018,$ffc5,$0024,$ffcb,$002d,$ffd3,$0035,$ffdc,$003b,$ffe8,$003f,$fff4'
    dc i'$0040,$0000,$003f,$000c,$003b,$0018,$0035,$0024,$002d,$002d,$0024,$0035,$0018,$003b,$000c,$003f'
    dc i'$0000,$0040,$fff4,$003f,$ffe8,$003b,$ffdc,$0035,$ffd3,$002d,$ffcb,$0024,$ffc5,$0018,$ffc1,$000c'
    dc i'$ffc0,$0000,$ffc1,$fff4,$ffc5,$ffe8,$ffcb,$ffdc,$ffd3,$ffd3,$ffdc,$ffcb,$ffe8,$ffc5,$fff4,$ffc1'
; Rotation for magnitude 0.5
math~dir_32_rot_mag_8_step_2_of_32 anop
    dc i'$0000,$ff80,$0019,$ff82,$0031,$ff8a,$0047,$ff96,$005b,$ffa5,$006a,$ffb9,$0076,$ffcf,$007e,$ffe7'
    dc i'$0080,$0000,$007e,$0019,$0076,$0031,$006a,$0047,$005b,$005b,$0047,$006a,$0031,$0076,$0019,$007e'
    dc i'$0000,$0080,$ffe7,$007e,$ffcf,$0076,$ffb9,$006a,$ffa5,$005b,$ff96,$0047,$ff8a,$0031,$ff82,$0019'
    dc i'$ff80,$0000,$ff82,$ffe7,$ff8a,$ffcf,$ff96,$ffb9,$ffa5,$ffa5,$ffb9,$ff96,$ffcf,$ff8a,$ffe7,$ff82'
; Rotation for magnitude 0.75
math~dir_32_rot_mag_8_step_3_of_32 anop
    dc i'$0000,$ff40,$0025,$ff44,$0049,$ff4f,$006b,$ff60,$0088,$ff78,$00a0,$ff95,$00b1,$ffb7,$00bc,$ffdb'
    dc i'$00c0,$0000,$00bc,$0025,$00b1,$0049,$00a0,$006b,$0088,$0088,$006b,$00a0,$0049,$00b1,$0025,$00bc'
    dc i'$0000,$00c0,$ffdb,$00bc,$ffb7,$00b1,$ff95,$00a0,$ff78,$0088,$ff60,$006b,$ff4f,$0049,$ff44,$0025'
    dc i'$ff40,$0000,$ff44,$ffdb,$ff4f,$ffb7,$ff60,$ff95,$ff78,$ff78,$ff95,$ff60,$ffb7,$ff4f,$ffdb,$ff44'
; Rotation for magnitude 1
math~dir_32_rot_mag_8_step_4_of_32 anop
    dc i'$0000,$ff00,$0032,$ff05,$0062,$ff13,$008e,$ff2b,$00b5,$ff4b,$00d5,$ff72,$00ed,$ff9e,$00fb,$ffce'
    dc i'$0100,$0000,$00fb,$0032,$00ed,$0062,$00d5,$008e,$00b5,$00b5,$008e,$00d5,$0062,$00ed,$0032,$00fb'
    dc i'$0000,$0100,$ffce,$00fb,$ff9e,$00ed,$ff72,$00d5,$ff4b,$00b5,$ff2b,$008e,$ff13,$0062,$ff05,$0032'
    dc i'$ff00,$0000,$ff05,$ffce,$ff13,$ff9e,$ff2b,$ff72,$ff4b,$ff4b,$ff72,$ff2b,$ff9e,$ff13,$ffce,$ff05'
; Rotation for magnitude 1.25
math~dir_32_rot_mag_8_step_5_of_32 anop
    dc i'$0000,$fec0,$003e,$fec6,$007a,$fed8,$00b2,$fef6,$00e2,$ff1e,$010a,$ff4e,$0128,$ff86,$013a,$ffc2'
    dc i'$0140,$0000,$013a,$003e,$0128,$007a,$010a,$00b2,$00e2,$00e2,$00b2,$010a,$007a,$0128,$003e,$013a'
    dc i'$0000,$0140,$ffc2,$013a,$ff86,$0128,$ff4e,$010a,$ff1e,$00e2,$fef6,$00b2,$fed8,$007a,$fec6,$003e'
    dc i'$fec0,$0000,$fec6,$ffc2,$fed8,$ff86,$fef6,$ff4e,$ff1e,$ff1e,$ff4e,$fef6,$ff86,$fed8,$ffc2,$fec6'
; Rotation for magnitude 1.5
math~dir_32_rot_mag_8_step_6_of_32 anop
    dc i'$0000,$fe80,$004b,$fe87,$0093,$fe9d,$00d5,$fec1,$0110,$fef0,$013f,$ff2b,$0163,$ff6d,$0179,$ffb5'
    dc i'$0180,$0000,$0179,$004b,$0163,$0093,$013f,$00d5,$0110,$0110,$00d5,$013f,$0093,$0163,$004b,$0179'
    dc i'$0000,$0180,$ffb5,$0179,$ff6d,$0163,$ff2b,$013f,$fef0,$0110,$fec1,$00d5,$fe9d,$0093,$fe87,$004b'
    dc i'$fe80,$0000,$fe87,$ffb5,$fe9d,$ff6d,$fec1,$ff2b,$fef0,$fef0,$ff2b,$fec1,$ff6d,$fe9d,$ffb5,$fe87'
; Rotation for magnitude 1.75
math~dir_32_rot_mag_8_step_7_of_32 anop
    dc i'$0000,$fe40,$0057,$fe49,$00ab,$fe62,$00f9,$fe8c,$013d,$fec3,$0174,$ff07,$019e,$ff55,$01b7,$ffa9'
    dc i'$01c0,$0000,$01b7,$0057,$019e,$00ab,$0174,$00f9,$013d,$013d,$00f9,$0174,$00ab,$019e,$0057,$01b7'
    dc i'$0000,$01c0,$ffa9,$01b7,$ff55,$019e,$ff07,$0174,$fec3,$013d,$fe8c,$00f9,$fe62,$00ab,$fe49,$0057'
    dc i'$fe40,$0000,$fe49,$ffa9,$fe62,$ff55,$fe8c,$ff07,$fec3,$fec3,$ff07,$fe8c,$ff55,$fe62,$ffa9,$fe49'
; Rotation for magnitude 2
math~dir_32_rot_mag_8_step_8_of_32 anop
    dc i'$0000,$fe00,$0064,$fe0a,$00c4,$fe27,$011c,$fe56,$016a,$fe96,$01aa,$fee4,$01d9,$ff3c,$01f6,$ff9c'
    dc i'$0200,$0000,$01f6,$0064,$01d9,$00c4,$01aa,$011c,$016a,$016a,$011c,$01aa,$00c4,$01d9,$0064,$01f6'
    dc i'$0000,$0200,$ff9c,$01f6,$ff3c,$01d9,$fee4,$01aa,$fe96,$016a,$fe56,$011c,$fe27,$00c4,$fe0a,$0064'
    dc i'$fe00,$0000,$fe0a,$ff9c,$fe27,$ff3c,$fe56,$fee4,$fe96,$fe96,$fee4,$fe56,$ff3c,$fe27,$ff9c,$fe0a'
; Rotation for magnitude 2.25
math~dir_32_rot_mag_8_step_9_of_32 anop
    dc i'$0000,$fdc0,$0070,$fdcb,$00dc,$fdec,$0140,$fe21,$0197,$fe69,$01df,$fec0,$0214,$ff24,$0235,$ff90'
    dc i'$0240,$0000,$0235,$0070,$0214,$00dc,$01df,$0140,$0197,$0197,$0140,$01df,$00dc,$0214,$0070,$0235'
    dc i'$0000,$0240,$ff90,$0235,$ff24,$0214,$fec0,$01df,$fe69,$0197,$fe21,$0140,$fdec,$00dc,$fdcb,$0070'
    dc i'$fdc0,$0000,$fdcb,$ff90,$fdec,$ff24,$fe21,$fec0,$fe69,$fe69,$fec0,$fe21,$ff24,$fdec,$ff90,$fdcb'
; Rotation for magnitude 2.5
math~dir_32_rot_mag_8_step_10_of_32 anop
    dc i'$0000,$fd80,$007d,$fd8c,$00f5,$fdb1,$0164,$fdec,$01c5,$fe3b,$0214,$fe9c,$024f,$ff0b,$0274,$ff83'
    dc i'$0280,$0000,$0274,$007d,$024f,$00f5,$0214,$0164,$01c5,$01c5,$0164,$0214,$00f5,$024f,$007d,$0274'
    dc i'$0000,$0280,$ff83,$0274,$ff0b,$024f,$fe9c,$0214,$fe3b,$01c5,$fdec,$0164,$fdb1,$00f5,$fd8c,$007d'
    dc i'$fd80,$0000,$fd8c,$ff83,$fdb1,$ff0b,$fdec,$fe9c,$fe3b,$fe3b,$fe9c,$fdec,$ff0b,$fdb1,$ff83,$fd8c'
; Rotation for magnitude 2.75
math~dir_32_rot_mag_8_step_11_of_32 anop
    dc i'$0000,$fd40,$0089,$fd4e,$010d,$fd76,$0187,$fdb7,$01f2,$fe0e,$0249,$fe79,$028a,$fef3,$02b2,$ff77'
    dc i'$02c0,$0000,$02b2,$0089,$028a,$010d,$0249,$0187,$01f2,$01f2,$0187,$0249,$010d,$028a,$0089,$02b2'
    dc i'$0000,$02c0,$ff77,$02b2,$fef3,$028a,$fe79,$0249,$fe0e,$01f2,$fdb7,$0187,$fd76,$010d,$fd4e,$0089'
    dc i'$fd40,$0000,$fd4e,$ff77,$fd76,$fef3,$fdb7,$fe79,$fe0e,$fe0e,$fe79,$fdb7,$fef3,$fd76,$ff77,$fd4e'
; Rotation for magnitude 3
math~dir_32_rot_mag_8_step_12_of_32 anop
    dc i'$0000,$fd00,$0096,$fd0f,$0126,$fd3a,$01ab,$fd81,$021f,$fde1,$027f,$fe55,$02c6,$feda,$02f1,$ff6a'
    dc i'$0300,$0000,$02f1,$0096,$02c6,$0126,$027f,$01ab,$021f,$021f,$01ab,$027f,$0126,$02c6,$0096,$02f1'
    dc i'$0000,$0300,$ff6a,$02f1,$feda,$02c6,$fe55,$027f,$fde1,$021f,$fd81,$01ab,$fd3a,$0126,$fd0f,$0096'
    dc i'$fd00,$0000,$fd0f,$ff6a,$fd3a,$feda,$fd81,$fe55,$fde1,$fde1,$fe55,$fd81,$feda,$fd3a,$ff6a,$fd0f'
; Rotation for magnitude 3.25
math~dir_32_rot_mag_8_step_13_of_32 anop
    dc i'$0000,$fcc0,$00a2,$fcd0,$013e,$fcff,$01ce,$fd4c,$024c,$fdb4,$02b4,$fe32,$0301,$fec2,$0330,$ff5e'
    dc i'$0340,$0000,$0330,$00a2,$0301,$013e,$02b4,$01ce,$024c,$024c,$01ce,$02b4,$013e,$0301,$00a2,$0330'
    dc i'$0000,$0340,$ff5e,$0330,$fec2,$0301,$fe32,$02b4,$fdb4,$024c,$fd4c,$01ce,$fcff,$013e,$fcd0,$00a2'
    dc i'$fcc0,$0000,$fcd0,$ff5e,$fcff,$fec2,$fd4c,$fe32,$fdb4,$fdb4,$fe32,$fd4c,$fec2,$fcff,$ff5e,$fcd0'
; Rotation for magnitude 3.5
math~dir_32_rot_mag_8_step_14_of_32 anop
    dc i'$0000,$fc80,$00af,$fc91,$0157,$fcc4,$01f2,$fd17,$027a,$fd86,$02e9,$fe0e,$033c,$fea9,$036f,$ff51'
    dc i'$0380,$0000,$036f,$00af,$033c,$0157,$02e9,$01f2,$027a,$027a,$01f2,$02e9,$0157,$033c,$00af,$036f'
    dc i'$0000,$0380,$ff51,$036f,$fea9,$033c,$fe0e,$02e9,$fd86,$027a,$fd17,$01f2,$fcc4,$0157,$fc91,$00af'
    dc i'$fc80,$0000,$fc91,$ff51,$fcc4,$fea9,$fd17,$fe0e,$fd86,$fd86,$fe0e,$fd17,$fea9,$fcc4,$ff51,$fc91'
; Rotation for magnitude 3.75
math~dir_32_rot_mag_8_step_15_of_32 anop
    dc i'$0000,$fc40,$00bb,$fc52,$016f,$fc89,$0215,$fce2,$02a7,$fd59,$031e,$fdeb,$0377,$fe91,$03ae,$ff45'
    dc i'$03c0,$0000,$03ae,$00bb,$0377,$016f,$031e,$0215,$02a7,$02a7,$0215,$031e,$016f,$0377,$00bb,$03ae'
    dc i'$0000,$03c0,$ff45,$03ae,$fe91,$0377,$fdeb,$031e,$fd59,$02a7,$fce2,$0215,$fc89,$016f,$fc52,$00bb'
    dc i'$fc40,$0000,$fc52,$ff45,$fc89,$fe91,$fce2,$fdeb,$fd59,$fd59,$fdeb,$fce2,$fe91,$fc89,$ff45,$fc52'
; Rotation for magnitude 4
math~dir_32_rot_mag_8_step_16_of_32 anop
    dc i'$0000,$fc00,$00c8,$fc14,$0188,$fc4e,$0239,$fcad,$02d4,$fd2c,$0353,$fdc7,$03b2,$fe78,$03ec,$ff38'
    dc i'$0400,$0000,$03ec,$00c8,$03b2,$0188,$0353,$0239,$02d4,$02d4,$0239,$0353,$0188,$03b2,$00c8,$03ec'
    dc i'$0000,$0400,$ff38,$03ec,$fe78,$03b2,$fdc7,$0353,$fd2c,$02d4,$fcad,$0239,$fc4e,$0188,$fc14,$00c8'
    dc i'$fc00,$0000,$fc14,$ff38,$fc4e,$fe78,$fcad,$fdc7,$fd2c,$fd2c,$fdc7,$fcad,$fe78,$fc4e,$ff38,$fc14'
; Rotation for magnitude 4.25
math~dir_32_rot_mag_8_step_17_of_32 anop
    dc i'$0000,$fbc0,$00d4,$fbd5,$01a0,$fc13,$025c,$fc77,$0301,$fcff,$0389,$fda4,$03ed,$fe60,$042b,$ff2c'
    dc i'$0440,$0000,$042b,$00d4,$03ed,$01a0,$0389,$025c,$0301,$0301,$025c,$0389,$01a0,$03ed,$00d4,$042b'
    dc i'$0000,$0440,$ff2c,$042b,$fe60,$03ed,$fda4,$0389,$fcff,$0301,$fc77,$025c,$fc13,$01a0,$fbd5,$00d4'
    dc i'$fbc0,$0000,$fbd5,$ff2c,$fc13,$fe60,$fc77,$fda4,$fcff,$fcff,$fda4,$fc77,$fe60,$fc13,$ff2c,$fbd5'
; Rotation for magnitude 4.5
math~dir_32_rot_mag_8_step_18_of_32 anop
    dc i'$0000,$fb80,$00e1,$fb96,$01b9,$fbd8,$0280,$fc42,$032f,$fcd1,$03be,$fd80,$0428,$fe47,$046a,$ff1f'
    dc i'$0480,$0000,$046a,$00e1,$0428,$01b9,$03be,$0280,$032f,$032f,$0280,$03be,$01b9,$0428,$00e1,$046a'
    dc i'$0000,$0480,$ff1f,$046a,$fe47,$0428,$fd80,$03be,$fcd1,$032f,$fc42,$0280,$fbd8,$01b9,$fb96,$00e1'
    dc i'$fb80,$0000,$fb96,$ff1f,$fbd8,$fe47,$fc42,$fd80,$fcd1,$fcd1,$fd80,$fc42,$fe47,$fbd8,$ff1f,$fb96'
; Rotation for magnitude 4.75
math~dir_32_rot_mag_8_step_19_of_32 anop
    dc i'$0000,$fb40,$00ed,$fb57,$01d1,$fb9d,$02a4,$fc0d,$035c,$fca4,$03f3,$fd5c,$0463,$fe2f,$04a9,$ff13'
    dc i'$04c0,$0000,$04a9,$00ed,$0463,$01d1,$03f3,$02a4,$035c,$035c,$02a4,$03f3,$01d1,$0463,$00ed,$04a9'
    dc i'$0000,$04c0,$ff13,$04a9,$fe2f,$0463,$fd5c,$03f3,$fca4,$035c,$fc0d,$02a4,$fb9d,$01d1,$fb57,$00ed'
    dc i'$fb40,$0000,$fb57,$ff13,$fb9d,$fe2f,$fc0d,$fd5c,$fca4,$fca4,$fd5c,$fc0d,$fe2f,$fb9d,$ff13,$fb57'
; Rotation for magnitude 5
math~dir_32_rot_mag_8_step_20_of_32 anop
    dc i'$0000,$fb00,$00fa,$fb19,$01ea,$fb61,$02c7,$fbd8,$0389,$fc77,$0428,$fd39,$049f,$fe16,$04e7,$ff06'
    dc i'$0500,$0000,$04e7,$00fa,$049f,$01ea,$0428,$02c7,$0389,$0389,$02c7,$0428,$01ea,$049f,$00fa,$04e7'
    dc i'$0000,$0500,$ff06,$04e7,$fe16,$049f,$fd39,$0428,$fc77,$0389,$fbd8,$02c7,$fb61,$01ea,$fb19,$00fa'
    dc i'$fb00,$0000,$fb19,$ff06,$fb61,$fe16,$fbd8,$fd39,$fc77,$fc77,$fd39,$fbd8,$fe16,$fb61,$ff06,$fb19'
; Rotation for magnitude 5.25
math~dir_32_rot_mag_8_step_21_of_32 anop
    dc i'$0000,$fac0,$0106,$fada,$0202,$fb26,$02eb,$fba3,$03b6,$fc4a,$045d,$fd15,$04da,$fdfe,$0526,$fefa'
    dc i'$0540,$0000,$0526,$0106,$04da,$0202,$045d,$02eb,$03b6,$03b6,$02eb,$045d,$0202,$04da,$0106,$0526'
    dc i'$0000,$0540,$fefa,$0526,$fdfe,$04da,$fd15,$045d,$fc4a,$03b6,$fba3,$02eb,$fb26,$0202,$fada,$0106'
    dc i'$fac0,$0000,$fada,$fefa,$fb26,$fdfe,$fba3,$fd15,$fc4a,$fc4a,$fd15,$fba3,$fdfe,$fb26,$fefa,$fada'
; Rotation for magnitude 5.5
math~dir_32_rot_mag_8_step_22_of_32 anop
    dc i'$0000,$fa80,$0113,$fa9b,$021b,$faeb,$030e,$fb6d,$03e4,$fc1c,$0493,$fcf2,$0515,$fde5,$0565,$feed'
    dc i'$0580,$0000,$0565,$0113,$0515,$021b,$0493,$030e,$03e4,$03e4,$030e,$0493,$021b,$0515,$0113,$0565'
    dc i'$0000,$0580,$feed,$0565,$fde5,$0515,$fcf2,$0493,$fc1c,$03e4,$fb6d,$030e,$faeb,$021b,$fa9b,$0113'
    dc i'$fa80,$0000,$fa9b,$feed,$faeb,$fde5,$fb6d,$fcf2,$fc1c,$fc1c,$fcf2,$fb6d,$fde5,$faeb,$feed,$fa9b'
; Rotation for magnitude 5.75
math~dir_32_rot_mag_8_step_23_of_32 anop
    dc i'$0000,$fa40,$011f,$fa5c,$0233,$fab0,$0332,$fb38,$0411,$fbef,$04c8,$fcce,$0550,$fdcd,$05a4,$fee1'
    dc i'$05c0,$0000,$05a4,$011f,$0550,$0233,$04c8,$0332,$0411,$0411,$0332,$04c8,$0233,$0550,$011f,$05a4'
    dc i'$0000,$05c0,$fee1,$05a4,$fdcd,$0550,$fcce,$04c8,$fbef,$0411,$fb38,$0332,$fab0,$0233,$fa5c,$011f'
    dc i'$fa40,$0000,$fa5c,$fee1,$fab0,$fdcd,$fb38,$fcce,$fbef,$fbef,$fcce,$fb38,$fdcd,$fab0,$fee1,$fa5c'
; Rotation for magnitude 6
math~dir_32_rot_mag_8_step_24_of_32 anop
    dc i'$0000,$fa00,$012c,$fa1e,$024c,$fa75,$0355,$fb03,$043e,$fbc2,$04fd,$fcab,$058b,$fdb4,$05e2,$fed4'
    dc i'$0600,$0000,$05e2,$012c,$058b,$024c,$04fd,$0355,$043e,$043e,$0355,$04fd,$024c,$058b,$012c,$05e2'
    dc i'$0000,$0600,$fed4,$05e2,$fdb4,$058b,$fcab,$04fd,$fbc2,$043e,$fb03,$0355,$fa75,$024c,$fa1e,$012c'
    dc i'$fa00,$0000,$fa1e,$fed4,$fa75,$fdb4,$fb03,$fcab,$fbc2,$fbc2,$fcab,$fb03,$fdb4,$fa75,$fed4,$fa1e'
; Rotation for magnitude 6.25
math~dir_32_rot_mag_8_step_25_of_32 anop
    dc i'$0000,$f9c0,$0138,$f9df,$0264,$fa3a,$0379,$face,$046b,$fb95,$0532,$fc87,$05c6,$fd9c,$0621,$fec8'
    dc i'$0640,$0000,$0621,$0138,$05c6,$0264,$0532,$0379,$046b,$046b,$0379,$0532,$0264,$05c6,$0138,$0621'
    dc i'$0000,$0640,$fec8,$0621,$fd9c,$05c6,$fc87,$0532,$fb95,$046b,$face,$0379,$fa3a,$0264,$f9df,$0138'
    dc i'$f9c0,$0000,$f9df,$fec8,$fa3a,$fd9c,$face,$fc87,$fb95,$fb95,$fc87,$face,$fd9c,$fa3a,$fec8,$f9df'
; Rotation for magnitude 6.5
math~dir_32_rot_mag_8_step_26_of_32 anop
    dc i'$0000,$f980,$0145,$f9a0,$027d,$f9ff,$039c,$fa98,$0499,$fb67,$0568,$fc64,$0601,$fd83,$0660,$febb'
    dc i'$0680,$0000,$0660,$0145,$0601,$027d,$0568,$039c,$0499,$0499,$039c,$0568,$027d,$0601,$0145,$0660'
    dc i'$0000,$0680,$febb,$0660,$fd83,$0601,$fc64,$0568,$fb67,$0499,$fa98,$039c,$f9ff,$027d,$f9a0,$0145'
    dc i'$f980,$0000,$f9a0,$febb,$f9ff,$fd83,$fa98,$fc64,$fb67,$fb67,$fc64,$fa98,$fd83,$f9ff,$febb,$f9a0'
; Rotation for magnitude 6.75
math~dir_32_rot_mag_8_step_27_of_32 anop
    dc i'$0000,$f940,$0151,$f961,$0295,$f9c4,$03c0,$fa63,$04c6,$fb3a,$059d,$fc40,$063c,$fd6b,$069f,$feaf'
    dc i'$06c0,$0000,$069f,$0151,$063c,$0295,$059d,$03c0,$04c6,$04c6,$03c0,$059d,$0295,$063c,$0151,$069f'
    dc i'$0000,$06c0,$feaf,$069f,$fd6b,$063c,$fc40,$059d,$fb3a,$04c6,$fa63,$03c0,$f9c4,$0295,$f961,$0151'
    dc i'$f940,$0000,$f961,$feaf,$f9c4,$fd6b,$fa63,$fc40,$fb3a,$fb3a,$fc40,$fa63,$fd6b,$f9c4,$feaf,$f961'
; Rotation for magnitude 7
math~dir_32_rot_mag_8_step_28_of_32 anop
    dc i'$0000,$f900,$015e,$f922,$02ae,$f988,$03e4,$fa2e,$04f3,$fb0d,$05d2,$fc1c,$0678,$fd52,$06de,$fea2'
    dc i'$0700,$0000,$06de,$015e,$0678,$02ae,$05d2,$03e4,$04f3,$04f3,$03e4,$05d2,$02ae,$0678,$015e,$06de'
    dc i'$0000,$0700,$fea2,$06de,$fd52,$0678,$fc1c,$05d2,$fb0d,$04f3,$fa2e,$03e4,$f988,$02ae,$f922,$015e'
    dc i'$f900,$0000,$f922,$fea2,$f988,$fd52,$fa2e,$fc1c,$fb0d,$fb0d,$fc1c,$fa2e,$fd52,$f988,$fea2,$f922'
; Rotation for magnitude 7.25
math~dir_32_rot_mag_8_step_29_of_32 anop
    dc i'$0000,$f8c0,$016a,$f8e4,$02c6,$f94d,$0407,$f9f9,$0520,$fae0,$0607,$fbf9,$06b3,$fd3a,$071c,$fe96'
    dc i'$0740,$0000,$071c,$016a,$06b3,$02c6,$0607,$0407,$0520,$0520,$0407,$0607,$02c6,$06b3,$016a,$071c'
    dc i'$0000,$0740,$fe96,$071c,$fd3a,$06b3,$fbf9,$0607,$fae0,$0520,$f9f9,$0407,$f94d,$02c6,$f8e4,$016a'
    dc i'$f8c0,$0000,$f8e4,$fe96,$f94d,$fd3a,$f9f9,$fbf9,$fae0,$fae0,$fbf9,$f9f9,$fd3a,$f94d,$fe96,$f8e4'
; Rotation for magnitude 7.5
math~dir_32_rot_mag_8_step_30_of_32 anop
    dc i'$0000,$f880,$0177,$f8a5,$02df,$f912,$042b,$f9c4,$054e,$fab2,$063c,$fbd5,$06ee,$fd21,$075b,$fe89'
    dc i'$0780,$0000,$075b,$0177,$06ee,$02df,$063c,$042b,$054e,$054e,$042b,$063c,$02df,$06ee,$0177,$075b'
    dc i'$0000,$0780,$fe89,$075b,$fd21,$06ee,$fbd5,$063c,$fab2,$054e,$f9c4,$042b,$f912,$02df,$f8a5,$0177'
    dc i'$f880,$0000,$f8a5,$fe89,$f912,$fd21,$f9c4,$fbd5,$fab2,$fab2,$fbd5,$f9c4,$fd21,$f912,$fe89,$f8a5'
; Rotation for magnitude 7.75
math~dir_32_rot_mag_8_step_31_of_32 anop
    dc i'$0000,$f840,$0183,$f866,$02f7,$f8d7,$044e,$f98e,$057b,$fa85,$0672,$fbb2,$0729,$fd09,$079a,$fe7d'
    dc i'$07c0,$0000,$079a,$0183,$0729,$02f7,$0672,$044e,$057b,$057b,$044e,$0672,$02f7,$0729,$0183,$079a'
    dc i'$0000,$07c0,$fe7d,$079a,$fd09,$0729,$fbb2,$0672,$fa85,$057b,$f98e,$044e,$f8d7,$02f7,$f866,$0183'
    dc i'$f840,$0000,$f866,$fe7d,$f8d7,$fd09,$f98e,$fbb2,$fa85,$fa85,$fbb2,$f98e,$fd09,$f8d7,$fe7d,$f866'
; Rotation for magnitude 8
math~dir_32_rot_mag_8_step_32_of_32 anop
    dc i'$0000,$f800,$0190,$f827,$0310,$f89c,$0472,$f959,$05a8,$fa58,$06a7,$fb8e,$0764,$fcf0,$07d9,$fe70'
    dc i'$0800,$0000,$07d9,$0190,$0764,$0310,$06a7,$0472,$05a8,$05a8,$0472,$06a7,$0310,$0764,$0190,$07d9'
    dc i'$0000,$0800,$fe70,$07d9,$fcf0,$0764,$fb8e,$06a7,$fa58,$05a8,$f959,$0472,$f89c,$0310,$f827,$0190'
    dc i'$f800,$0000,$f827,$fe70,$f89c,$fcf0,$f959,$fb8e,$fa58,$fa58,$fb8e,$f959,$fcf0,$f89c,$fe70,$f827'
; Lookup table for a 32 direction, rotated vector of a magnitude from 0.25 to 8
math~dir_32_rot_to_mag_8_steps_32 anop
    dc a4'math~dir_32_rot_mag_8_step_1_of_32'
    dc a4'math~dir_32_rot_mag_8_step_2_of_32'
    dc a4'math~dir_32_rot_mag_8_step_3_of_32'
    dc a4'math~dir_32_rot_mag_8_step_4_of_32'
    dc a4'math~dir_32_rot_mag_8_step_5_of_32'
    dc a4'math~dir_32_rot_mag_8_step_6_of_32'
    dc a4'math~dir_32_rot_mag_8_step_7_of_32'
    dc a4'math~dir_32_rot_mag_8_step_8_of_32'
    dc a4'math~dir_32_rot_mag_8_step_9_of_32'
    dc a4'math~dir_32_rot_mag_8_step_10_of_32'
    dc a4'math~dir_32_rot_mag_8_step_11_of_32'
    dc a4'math~dir_32_rot_mag_8_step_12_of_32'
    dc a4'math~dir_32_rot_mag_8_step_13_of_32'
    dc a4'math~dir_32_rot_mag_8_step_14_of_32'
    dc a4'math~dir_32_rot_mag_8_step_15_of_32'
    dc a4'math~dir_32_rot_mag_8_step_16_of_32'
    dc a4'math~dir_32_rot_mag_8_step_17_of_32'
    dc a4'math~dir_32_rot_mag_8_step_18_of_32'
    dc a4'math~dir_32_rot_mag_8_step_19_of_32'
    dc a4'math~dir_32_rot_mag_8_step_20_of_32'
    dc a4'math~dir_32_rot_mag_8_step_21_of_32'
    dc a4'math~dir_32_rot_mag_8_step_22_of_32'
    dc a4'math~dir_32_rot_mag_8_step_23_of_32'
    dc a4'math~dir_32_rot_mag_8_step_24_of_32'
    dc a4'math~dir_32_rot_mag_8_step_25_of_32'
    dc a4'math~dir_32_rot_mag_8_step_26_of_32'
    dc a4'math~dir_32_rot_mag_8_step_27_of_32'
    dc a4'math~dir_32_rot_mag_8_step_28_of_32'
    dc a4'math~dir_32_rot_mag_8_step_29_of_32'
    dc a4'math~dir_32_rot_mag_8_step_30_of_32'
    dc a4'math~dir_32_rot_mag_8_step_31_of_32'
    dc a4'math~dir_32_rot_mag_8_step_32_of_32'

; Most of the tables cap out at 8.0 in fp16.  Might want to increase this to 16.0
math~max_pos_speed      equ 8|8
math~max_neg_speed      equ -8|8

; When using the fps adjustment, where doubling happens if the fps falls to 30, we have to cap out at 4.
math~max_fps_adjusted_pos_speed  equ 4|8
math~max_fps_adjusted_neg_speed  equ -4|8

; Convert an indexed speed, to a fp16 magnitude
math~speed_index_to_magnitude anop
    dc i'$0000'     ; 0.0
    dc i'$0040'     ; 0.25
    dc i'$0080'     ; 0.5
    dc i'$00c0'     ; 0.75
    dc i'$0100'     ; 1.0
    dc i'$0140'     ; 1.25
    dc i'$0180'     ; 1.5
    dc i'$01c0'     ; 1.75
    dc i'$0200'     ; 2
    dc i'$0240'     ; 2.25
    dc i'$0280'     ; 2.5
    dc i'$02c0'     ; 2.75
    dc i'$0300'     ; 3
    dc i'$0340'     ; 3.25
    dc i'$0380'     ; 3.5
    dc i'$03c0'     ; 3.75
    dc i'$0400'     ; 4
    dc i'$0440'     ; 4.25
    dc i'$0480'     ; 4.5
    dc i'$04c0'     ; 4.75
    dc i'$0500'     ; 5
    dc i'$0540'     ; 5.25
    dc i'$0580'     ; 5.5
    dc i'$05c0'     ; 5.75
    dc i'$0600'     ; 6
    dc i'$0640'     ; 6.25
    dc i'$0680'     ; 6.5
    dc i'$06c0'     ; 6.75
    dc i'$0700'     ; 7
    dc i'$0740'     ; 7.25
    dc i'$0780'     ; 7.5
    dc i'$07c0'     ; 7.75
    dc i'$0800'     ; 8
    dc i'$0840'     ; 8.25
    dc i'$0880'     ; 8.5
    dc i'$08c0'     ; 8.75

; Index table where the index is an 8 bit value (x2), and the entry is the square of that index.
math~squared anop
    dc i'$0000,$0001,$0004,$0009,$0010,$0019,$0024,$0031,$0040,$0051,$0064,$0079,$0090,$00a9,$00c4,$00e1,$0100,$0121,$0144,$0169,$0190,$01b9,$01e4,$0211,$0240,$0271,$02a4,$02d9,$0310,$0349,$0384,$03c1'
    dc i'$0400,$0441,$0484,$04c9,$0510,$0559,$05a4,$05f1,$0640,$0691,$06e4,$0739,$0790,$07e9,$0844,$08a1,$0900,$0961,$09c4,$0a29,$0a90,$0af9,$0b64,$0bd1,$0c40,$0cb1,$0d24,$0d99,$0e10,$0e89,$0f04,$0f81'
    dc i'$1000,$1081,$1104,$1189,$1210,$1299,$1324,$13b1,$1440,$14d1,$1564,$15f9,$1690,$1729,$17c4,$1861,$1900,$19a1,$1a44,$1ae9,$1b90,$1c39,$1ce4,$1d91,$1e40,$1ef1,$1fa4,$2059,$2110,$21c9,$2284,$2341'
    dc i'$2400,$24c1,$2584,$2649,$2710,$27d9,$28a4,$2971,$2a40,$2b11,$2be4,$2cb9,$2d90,$2e69,$2f44,$3021,$3100,$31e1,$32c4,$33a9,$3490,$3579,$3664,$3751,$3840,$3931,$3a24,$3b19,$3c10,$3d09,$3e04,$3f01'
    dc i'$4000,$4101,$4204,$4309,$4410,$4519,$4624,$4731,$4840,$4951,$4a64,$4b79,$4c90,$4da9,$4ec4,$4fe1,$5100,$5221,$5344,$5469,$5590,$56b9,$57e4,$5911,$5a40,$5b71,$5ca4,$5dd9,$5f10,$6049,$6184,$62c1'
    dc i'$6400,$6541,$6684,$67c9,$6910,$6a59,$6ba4,$6cf1,$6e40,$6f91,$70e4,$7239,$7390,$74e9,$7644,$77a1,$7900,$7a61,$7bc4,$7d29,$7e90,$7ff9,$8164,$82d1,$8440,$85b1,$8724,$8899,$8a10,$8b89,$8d04,$8e81'
    dc i'$9000,$9181,$9304,$9489,$9610,$9799,$9924,$9ab1,$9c40,$9dd1,$9f64,$a0f9,$a290,$a429,$a5c4,$a761,$a900,$aaa1,$ac44,$ade9,$af90,$b139,$b2e4,$b491,$b640,$b7f1,$b9a4,$bb59,$bd10,$bec9,$c084,$c241'
    dc i'$c400,$c5c1,$c784,$c949,$cb10,$ccd9,$cea4,$d071,$d240,$d411,$d5e4,$d7b9,$d990,$db69,$dd44,$df21,$e100,$e2e1,$e4c4,$e6a9,$e890,$ea79,$ec64,$ee51,$f040,$f231,$f424,$f619,$f810,$fa09,$fc04,$fe01'

; Index table where the index is an 9 bit value, and the entry is the square of that index, divided by 4
; This is used for 8 bit fast multiply
math~squared_512_div4 entry
    dc i'$0000,$0000,$0001,$0002,$0004,$0006,$0009,$000c,$0010,$0014,$0019,$001e,$0024,$002a,$0031,$0038,$0040,$0048,$0051,$005a,$0064,$006e,$0079,$0084,$0090,$009c,$00a9,$00b6,$00c4,$00d2,$00e1,$00f0'
    dc i'$0100,$0110,$0121,$0132,$0144,$0156,$0169,$017c,$0190,$01a4,$01b9,$01ce,$01e4,$01fa,$0211,$0228,$0240,$0258,$0271,$028a,$02a4,$02be,$02d9,$02f4,$0310,$032c,$0349,$0366,$0384,$03a2,$03c1,$03e0'
    dc i'$0400,$0420,$0441,$0462,$0484,$04a6,$04c9,$04ec,$0510,$0534,$0559,$057e,$05a4,$05ca,$05f1,$0618,$0640,$0668,$0691,$06ba,$06e4,$070e,$0739,$0764,$0790,$07bc,$07e9,$0816,$0844,$0872,$08a1,$08d0'
    dc i'$0900,$0930,$0961,$0992,$09c4,$09f6,$0a29,$0a5c,$0a90,$0ac4,$0af9,$0b2e,$0b64,$0b9a,$0bd1,$0c08,$0c40,$0c78,$0cb1,$0cea,$0d24,$0d5e,$0d99,$0dd4,$0e10,$0e4c,$0e89,$0ec6,$0f04,$0f42,$0f81,$0fc0'
    dc i'$1000,$1040,$1081,$10c2,$1104,$1146,$1189,$11cc,$1210,$1254,$1299,$12de,$1324,$136a,$13b1,$13f8,$1440,$1488,$14d1,$151a,$1564,$15ae,$15f9,$1644,$1690,$16dc,$1729,$1776,$17c4,$1812,$1861,$18b0'
    dc i'$1900,$1950,$19a1,$19f2,$1a44,$1a96,$1ae9,$1b3c,$1b90,$1be4,$1c39,$1c8e,$1ce4,$1d3a,$1d91,$1de8,$1e40,$1e98,$1ef1,$1f4a,$1fa4,$1ffe,$2059,$20b4,$2110,$216c,$21c9,$2226,$2284,$22e2,$2341,$23a0'
    dc i'$2400,$2460,$24c1,$2522,$2584,$25e6,$2649,$26ac,$2710,$2774,$27d9,$283e,$28a4,$290a,$2971,$29d8,$2a40,$2aa8,$2b11,$2b7a,$2be4,$2c4e,$2cb9,$2d24,$2d90,$2dfc,$2e69,$2ed6,$2f44,$2fb2,$3021,$3090'
    dc i'$3100,$3170,$31e1,$3252,$32c4,$3336,$33a9,$341c,$3490,$3504,$3579,$35ee,$3664,$36da,$3751,$37c8,$3840,$38b8,$3931,$39aa,$3a24,$3a9e,$3b19,$3b94,$3c10,$3c8c,$3d09,$3d86,$3e04,$3e82,$3f01,$3f80'
    dc i'$4000,$4080,$4101,$4182,$4204,$4286,$4309,$438c,$4410,$4494,$4519,$459e,$4624,$46aa,$4731,$47b8,$4840,$48c8,$4951,$49da,$4a64,$4aee,$4b79,$4c04,$4c90,$4d1c,$4da9,$4e36,$4ec4,$4f52,$4fe1,$5070'
    dc i'$5100,$5190,$5221,$52b2,$5344,$53d6,$5469,$54fc,$5590,$5624,$56b9,$574e,$57e4,$587a,$5911,$59a8,$5a40,$5ad8,$5b71,$5c0a,$5ca4,$5d3e,$5dd9,$5e74,$5f10,$5fac,$6049,$60e6,$6184,$6222,$62c1,$6360'
    dc i'$6400,$64a0,$6541,$65e2,$6684,$6726,$67c9,$686c,$6910,$69b4,$6a59,$6afe,$6ba4,$6c4a,$6cf1,$6d98,$6e40,$6ee8,$6f91,$703a,$70e4,$718e,$7239,$72e4,$7390,$743c,$74e9,$7596,$7644,$76f2,$77a1,$7850'
    dc i'$7900,$79b0,$7a61,$7b12,$7bc4,$7c76,$7d29,$7ddc,$7e90,$7f44,$7ff9,$80ae,$8164,$821a,$82d1,$8388,$8440,$84f8,$85b1,$866a,$8724,$87de,$8899,$8954,$8a10,$8acc,$8b89,$8c46,$8d04,$8dc2,$8e81,$8f40'
    dc i'$9000,$90c0,$9181,$9242,$9304,$93c6,$9489,$954c,$9610,$96d4,$9799,$985e,$9924,$99ea,$9ab1,$9b78,$9c40,$9d08,$9dd1,$9e9a,$9f64,$a02e,$a0f9,$a1c4,$a290,$a35c,$a429,$a4f6,$a5c4,$a692,$a761,$a830'
    dc i'$a900,$a9d0,$aaa1,$ab72,$ac44,$ad16,$ade9,$aebc,$af90,$b064,$b139,$b20e,$b2e4,$b3ba,$b491,$b568,$b640,$b718,$b7f1,$b8ca,$b9a4,$ba7e,$bb59,$bc34,$bd10,$bdec,$bec9,$bfa6,$c084,$c162,$c241,$c320'
    dc i'$c400,$c4e0,$c5c1,$c6a2,$c784,$c866,$c949,$ca2c,$cb10,$cbf4,$ccd9,$cdbe,$cea4,$cf8a,$d071,$d158,$d240,$d328,$d411,$d4fa,$d5e4,$d6ce,$d7b9,$d8a4,$d990,$da7c,$db69,$dc56,$dd44,$de32,$df21,$e010'
    dc i'$e100,$e1f0,$e2e1,$e3d2,$e4c4,$e5b6,$e6a9,$e79c,$e890,$e984,$ea79,$eb6e,$ec64,$ed5a,$ee51,$ef48,$f040,$f138,$f231,$f32a,$f424,$f51e,$f619,$f714,$f810,$f90c,$fa09,$fb06,$fc04,$fd02,$fe01,$ff00'

; Index table where the index is a x.4 fixed point value, and the index is the square of that value, in x.4
; The table has a max index of 8.0 source value.
math~sqr_fp4bit anop
    dc i'$0000,$0000,$0000,$0000,$0001,$0001,$0002,$0003,$0004,$0005,$0006,$0007,$0009,$000a,$000c,$000e,$0010,$0012,$0014,$0016,$0019,$001b,$001e,$0021,$0024,$0027,$002a,$002d,$0031,$0034,$0038,$003c'
    dc i'$0040,$0044,$0048,$004c,$0051,$0055,$005a,$005f,$0064,$0069,$006e,$0073,$0079,$007e,$0084,$008a,$0090,$0096,$009c,$00a2,$00a9,$00af,$00b6,$00bd,$00c4,$00cb,$00d2,$00d9,$00e1,$00e8,$00f0,$00f8'
    dc i'$0100,$0108,$0110,$0118,$0121,$0129,$0132,$013b,$0144,$014d,$0156,$015f,$0169,$0172,$017c,$0186,$0190,$019a,$01a4,$01ae,$01b9,$01c3,$01ce,$01d9,$01e4,$01ef,$01fa,$0205,$0211,$021c,$0228,$0234'
    dc i'$0240,$024c,$0258,$0264,$0271,$027d,$028a,$0297,$02a4,$02b1,$02be,$02cb,$02d9,$02e6,$02f4,$0302,$0310,$031e,$032c,$033a,$0349,$0357,$0366,$0375,$0384,$0393,$03a2,$03b1,$03c1,$03d0,$03e0,$03f0'
    dc i'$0400,$0410,$0420,$0430,$0441,$0451,$0462,$0473,$0484,$0495,$04a6,$04b7,$04c9,$04da,$04ec,$04fe'

; Index table where the index is the square of a x.4 fixed point value, and the entry is the square root of that index, in fp16
; The table has a range of 128 * 2, sqr(128) * 2
math~sqrt_fp4bit anop
    dc i'$0000,$0040,$005a,$006e,$0080,$008f,$009c,$00a9,$00b5,$00c0,$00ca,$00d4,$00dd,$00e6,$00ef,$00f7,$0100,$0107,$010f,$0116,$011e,$0125,$012c,$0132,$0139,$0140,$0146,$014c,$0152,$0158,$015e,$0164'
    dc i'$016a,$016f,$0175,$017a,$0180,$0185,$018a,$018f,$0194,$0199,$019e,$01a3,$01a8,$01ad,$01b2,$01b6,$01bb,$01c0,$01c4,$01c9,$01cd,$01d1,$01d6,$01da,$01de,$01e3,$01e7,$01eb,$01ef,$01f3,$01f7,$01fb'
    dc i'$0200,$0203,$0207,$020b,$020f,$0213,$0217,$021b,$021f,$0222,$0226,$022a,$022d,$0231,$0235,$0238,$023c,$0240,$0243,$0247,$024a,$024e,$0251,$0254,$0258,$025b,$025f,$0262,$0265,$0269,$026c,$026f'
    dc i'$0273,$0276,$0279,$027c,$0280,$0283,$0286,$0289,$028c,$028f,$0292,$0296,$0299,$029c,$029f,$02a2,$02a5,$02a8,$02ab,$02ae,$02b1,$02b4,$02b7,$02ba,$02bd,$02c0,$02c2,$02c5,$02c8,$02cb,$02ce,$02d1'
    dc i'$02d4,$02d6,$02d9,$02dc,$02df,$02e2,$02e4,$02e7,$02ea,$02ed,$02ef,$02f2,$02f5,$02f7,$02fa,$02fd,$0300,$0302,$0305,$0307,$030a,$030d,$030f,$0312,$0315,$0317,$031a,$031c,$031f,$0321,$0324,$0327'
    dc i'$0329,$032c,$032e,$0331,$0333,$0336,$0338,$033b,$033d,$0340,$0342,$0344,$0347,$0349,$034c,$034e,$0351,$0353,$0355,$0358,$035a,$035d,$035f,$0361,$0364,$0366,$0368,$036b,$036d,$036f,$0372,$0374'
    dc i'$0376,$0379,$037b,$037d,$0380,$0382,$0384,$0386,$0389,$038b,$038d,$038f,$0392,$0394,$0396,$0398,$039b,$039d,$039f,$03a1,$03a3,$03a6,$03a8,$03aa,$03ac,$03ae,$03b0,$03b3,$03b5,$03b7,$03b9,$03bb'
    dc i'$03bd,$03c0,$03c2,$03c4,$03c6,$03c8,$03ca,$03cc,$03ce,$03d0,$03d3,$03d5,$03d7,$03d9,$03db,$03dd,$03df,$03e1,$03e3,$03e5,$03e7,$03e9,$03eb,$03ed,$03ef,$03f1,$03f3,$03f5,$03f7,$03f9,$03fb,$03fd'
    dc i'$0400,$0401,$0403,$0405,$0407,$0409,$040b,$040d,$040f,$0411,$0413,$0415,$0417,$0419,$041b,$041d,$041f,$0421,$0423,$0425,$0427,$0429,$042b,$042d,$042e,$0430,$0432,$0434,$0436,$0438,$043a,$043c'
    dc i'$043e,$0440,$0441,$0443,$0445,$0447,$0449,$044b,$044d,$044e,$0450,$0452,$0454,$0456,$0458,$045a,$045b,$045d,$045f,$0461,$0463,$0465,$0466,$0468,$046a,$046c,$046e,$046f,$0471,$0473,$0475,$0477'
    dc i'$0478,$047a,$047c,$047e,$0480,$0481,$0483,$0485,$0487,$0488,$048a,$048c,$048e,$048f,$0491,$0493,$0495,$0496,$0498,$049a,$049c,$049d,$049f,$04a1,$04a3,$04a4,$04a6,$04a8,$04a9,$04ab,$04ad,$04af'
    dc i'$04b0,$04b2,$04b4,$04b5,$04b7,$04b9,$04ba,$04bc,$04be,$04c0,$04c1,$04c3,$04c5,$04c6,$04c8,$04ca,$04cb,$04cd,$04cf,$04d0,$04d2,$04d4,$04d5,$04d7,$04d9,$04da,$04dc,$04dd,$04df,$04e1,$04e2,$04e4'
    dc i'$04e6,$04e7,$04e9,$04eb,$04ec,$04ee,$04ef,$04f1,$04f3,$04f4,$04f6,$04f7,$04f9,$04fb,$04fc,$04fe,$0500,$0501,$0503,$0504,$0506,$0507,$0509,$050b,$050c,$050e,$050f,$0511,$0513,$0514,$0516,$0517'
    dc i'$0519,$051a,$051c,$051e,$051f,$0521,$0522,$0524,$0525,$0527,$0528,$052a,$052c,$052d,$052f,$0530,$0532,$0533,$0535,$0536,$0538,$0539,$053b,$053c,$053e,$0540,$0541,$0543,$0544,$0546,$0547,$0549'
    dc i'$054a,$054c,$054d,$054f,$0550,$0552,$0553,$0555,$0556,$0558,$0559,$055b,$055c,$055e,$055f,$0561,$0562,$0564,$0565,$0567,$0568,$056a,$056b,$056c,$056e,$056f,$0571,$0572,$0574,$0575,$0577,$0578'
    dc i'$057a,$057b,$057d,$057e,$0580,$0581,$0582,$0584,$0585,$0587,$0588,$058a,$058b,$058d,$058e,$058f,$0591,$0592,$0594,$0595,$0597,$0598,$0599,$059b,$059c,$059e,$059f,$05a1,$05a2,$05a3,$05a5,$05a6'
    dc i'$05a8,$05a9,$05aa,$05ac,$05ad,$05af,$05b0,$05b2,$05b3,$05b4,$05b6,$05b7,$05b9,$05ba,$05bb,$05bd,$05be,$05c0,$05c1,$05c2,$05c4,$05c5,$05c6,$05c8,$05c9,$05cb,$05cc,$05cd,$05cf,$05d0,$05d1,$05d3'
    dc i'$05d4,$05d6,$05d7,$05d8,$05da,$05db,$05dc,$05de,$05df,$05e1,$05e2,$05e3,$05e5,$05e6,$05e7,$05e9,$05ea,$05eb,$05ed,$05ee,$05ef,$05f1,$05f2,$05f3,$05f5,$05f6,$05f7,$05f9,$05fa,$05fb,$05fd,$05fe'
    dc i'$0600,$0601,$0602,$0603,$0605,$0606,$0607,$0609,$060a,$060b,$060d,$060e,$060f,$0611,$0612,$0613,$0615,$0616,$0617,$0619,$061a,$061b,$061d,$061e,$061f,$0620,$0622,$0623,$0624,$0626,$0627,$0628'
    dc i'$062a,$062b,$062c,$062d,$062f,$0630,$0631,$0633,$0634,$0635,$0637,$0638,$0639,$063a,$063c,$063d,$063e,$0640,$0641,$0642,$0643,$0645,$0646,$0647,$0648,$064a,$064b,$064c,$064e,$064f,$0650,$0651'
    dc i'$0653,$0654,$0655,$0656,$0658,$0659,$065a,$065b,$065d,$065e,$065f,$0660,$0662,$0663,$0664,$0665,$0667,$0668,$0669,$066a,$066c,$066d,$066e,$066f,$0671,$0672,$0673,$0674,$0676,$0677,$0678,$0679'
    dc i'$067b,$067c,$067d,$067e,$0680,$0681,$0682,$0683,$0684,$0686,$0687,$0688,$0689,$068b,$068c,$068d,$068e,$068f,$0691,$0692,$0693,$0694,$0696,$0697,$0698,$0699,$069a,$069c,$069d,$069e,$069f,$06a0'
    dc i'$06a2,$06a3,$06a4,$06a5,$06a6,$06a8,$06a9,$06aa,$06ab,$06ac,$06ae,$06af,$06b0,$06b1,$06b2,$06b4,$06b5,$06b6,$06b7,$06b8,$06ba,$06bb,$06bc,$06bd,$06be,$06c0,$06c1,$06c2,$06c3,$06c4,$06c5,$06c7'
    dc i'$06c8,$06c9,$06ca,$06cb,$06cc,$06ce,$06cf,$06d0,$06d1,$06d2,$06d4,$06d5,$06d6,$06d7,$06d8,$06d9,$06db,$06dc,$06dd,$06de,$06df,$06e0,$06e2,$06e3,$06e4,$06e5,$06e6,$06e7,$06e8,$06ea,$06eb,$06ec'
    dc i'$06ed,$06ee,$06ef,$06f1,$06f2,$06f3,$06f4,$06f5,$06f6,$06f7,$06f9,$06fa,$06fb,$06fc,$06fd,$06fe,$0700,$0701,$0702,$0703,$0704,$0705,$0706,$0707,$0709,$070a,$070b,$070c,$070d,$070e,$070f,$0711'
    dc i'$0712,$0713,$0714,$0715,$0716,$0717,$0718,$071a,$071b,$071c,$071d,$071e,$071f,$0720,$0721,$0723,$0724,$0725,$0726,$0727,$0728,$0729,$072a,$072c,$072d,$072e,$072f,$0730,$0731,$0732,$0733,$0734'
    dc i'$0736,$0737,$0738,$0739,$073a,$073b,$073c,$073d,$073e,$0740,$0741,$0742,$0743,$0744,$0745,$0746,$0747,$0748,$0749,$074b,$074c,$074d,$074e,$074f,$0750,$0751,$0752,$0753,$0754,$0755,$0757,$0758'
    dc i'$0759,$075a,$075b,$075c,$075d,$075e,$075f,$0760,$0761,$0762,$0764,$0765,$0766,$0767,$0768,$0769,$076a,$076b,$076c,$076d,$076e,$076f,$0771,$0772,$0773,$0774,$0775,$0776,$0777,$0778,$0779,$077a'
    dc i'$077b,$077c,$077d,$077e,$0780,$0781,$0782,$0783,$0784,$0785,$0786,$0787,$0788,$0789,$078a,$078b,$078c,$078d,$078e,$078f,$0790,$0792,$0793,$0794,$0795,$0796,$0797,$0798,$0799,$079a,$079b,$079c'
    dc i'$079d,$079e,$079f,$07a0,$07a1,$07a2,$07a3,$07a4,$07a6,$07a7,$07a8,$07a9,$07aa,$07ab,$07ac,$07ad,$07ae,$07af,$07b0,$07b1,$07b2,$07b3,$07b4,$07b5,$07b6,$07b7,$07b8,$07b9,$07ba,$07bb,$07bc,$07bd'
    dc i'$07be,$07c0,$07c1,$07c2,$07c3,$07c4,$07c5,$07c6,$07c7,$07c8,$07c9,$07ca,$07cb,$07cc,$07cd,$07ce,$07cf,$07d0,$07d1,$07d2,$07d3,$07d4,$07d5,$07d6,$07d7,$07d8,$07d9,$07da,$07db,$07dc,$07dd,$07de'
    dc i'$07df,$07e0,$07e1,$07e2,$07e3,$07e4,$07e5,$07e6,$07e7,$07e8,$07e9,$07ea,$07eb,$07ec,$07ed,$07ee,$07ef,$07f0,$07f1,$07f2,$07f3,$07f4,$07f5,$07f6,$07f7,$07f8,$07f9,$07fa,$07fb,$07fc,$07fd,$07fe'
    dc i'$0800,$0800,$0801,$0802,$0803,$0804,$0805,$0806,$0807,$0808,$0809,$080a,$080b,$080c,$080d,$080e,$080f,$0810,$0811,$0812,$0813,$0814,$0815,$0816,$0817,$0818,$0819,$081a,$081b,$081c,$081d,$081e'
    dc i'$081f,$0820,$0821,$0822,$0823,$0824,$0825,$0826,$0827,$0828,$0829,$082a,$082b,$082c,$082d,$082e,$082f,$0830,$0831,$0832,$0833,$0834,$0835,$0836,$0837,$0838,$0839,$083a,$083b,$083c,$083d,$083e'
    dc i'$083f,$0840,$0840,$0841,$0842,$0843,$0844,$0845,$0846,$0847,$0848,$0849,$084a,$084b,$084c,$084d,$084e,$084f,$0850,$0851,$0852,$0853,$0854,$0855,$0856,$0857,$0858,$0859,$085a,$085a,$085b,$085c'
    dc i'$085d,$085e,$085f,$0860,$0861,$0862,$0863,$0864,$0865,$0866,$0867,$0868,$0869,$086a,$086b,$086c,$086d,$086e,$086e,$086f,$0870,$0871,$0872,$0873,$0874,$0875,$0876,$0877,$0878,$0879,$087a,$087b'
    dc i'$087c,$087d,$087e,$087f,$0880,$0880,$0881,$0882,$0883,$0884,$0885,$0886,$0887,$0888,$0889,$088a,$088b,$088c,$088d,$088e,$088f,$088f,$0890,$0891,$0892,$0893,$0894,$0895,$0896,$0897,$0898,$0899'
    dc i'$089a,$089b,$089c,$089c,$089d,$089e,$089f,$08a0,$08a1,$08a2,$08a3,$08a4,$08a5,$08a6,$08a7,$08a8,$08a9,$08a9,$08aa,$08ab,$08ac,$08ad,$08ae,$08af,$08b0,$08b1,$08b2,$08b3,$08b4,$08b5,$08b5,$08b6'
    dc i'$08b7,$08b8,$08b9,$08ba,$08bb,$08bc,$08bd,$08be,$08bf,$08c0,$08c0,$08c1,$08c2,$08c3,$08c4,$08c5,$08c6,$08c7,$08c8,$08c9,$08ca,$08ca,$08cb,$08cc,$08cd,$08ce,$08cf,$08d0,$08d1,$08d2,$08d3,$08d4'
    dc i'$08d4,$08d5,$08d6,$08d7,$08d8,$08d9,$08da,$08db,$08dc,$08dd,$08dd,$08de,$08df,$08e0,$08e1,$08e2,$08e3,$08e4,$08e5,$08e6,$08e6,$08e7,$08e8,$08e9,$08ea,$08eb,$08ec,$08ed,$08ee,$08ef,$08ef,$08f0'
    dc i'$08f1,$08f2,$08f3,$08f4,$08f5,$08f6,$08f7,$08f7,$08f8,$08f9,$08fa,$08fb,$08fc,$08fd,$08fe,$08ff,$0900,$0900,$0901,$0902,$0903,$0904,$0905,$0906,$0907,$0907,$0908,$0909,$090a,$090b,$090c,$090d'
    dc i'$090e,$090f,$090f,$0910,$0911,$0912,$0913,$0914,$0915,$0916,$0916,$0917,$0918,$0919,$091a,$091b,$091c,$091d,$091e,$091e,$091f,$0920,$0921,$0922,$0923,$0924,$0925,$0925,$0926,$0927,$0928,$0929'
    dc i'$092a,$092b,$092c,$092c,$092d,$092e,$092f,$0930,$0931,$0932,$0932,$0933,$0934,$0935,$0936,$0937,$0938,$0939,$0939,$093a,$093b,$093c,$093d,$093e,$093f,$0940,$0940,$0941,$0942,$0943,$0944,$0945'
    dc i'$0946,$0946,$0947,$0948,$0949,$094a,$094b,$094c,$094c,$094d,$094e,$094f,$0950,$0951,$0952,$0952,$0953,$0954,$0955,$0956,$0957,$0958,$0958,$0959,$095a,$095b,$095c,$095d,$095e,$095e,$095f,$0960'
    dc i'$0961,$0962,$0963,$0964,$0964,$0965,$0966,$0967,$0968,$0969,$096a,$096a,$096b,$096c,$096d,$096e,$096f,$096f,$0970,$0971,$0972,$0973,$0974,$0975,$0975,$0976,$0977,$0978,$0979,$097a,$097a,$097b'
    dc i'$097c,$097d,$097e,$097f,$0980,$0980,$0981,$0982,$0983,$0984,$0985,$0985,$0986,$0987,$0988,$0989,$098a,$098a,$098b,$098c,$098d,$098e,$098f,$098f,$0990,$0991,$0992,$0993,$0994,$0994,$0995,$0996'
    dc i'$0997,$0998,$0999,$0999,$099a,$099b,$099c,$099d,$099e,$099e,$099f,$09a0,$09a1,$09a2,$09a3,$09a3,$09a4,$09a5,$09a6,$09a7,$09a8,$09a8,$09a9,$09aa,$09ab,$09ac,$09ad,$09ad,$09ae,$09af,$09b0,$09b1'
    dc i'$09b2,$09b2,$09b3,$09b4,$09b5,$09b6,$09b6,$09b7,$09b8,$09b9,$09ba,$09bb,$09bb,$09bc,$09bd,$09be,$09bf,$09c0,$09c0,$09c1,$09c2,$09c3,$09c4,$09c4,$09c5,$09c6,$09c7,$09c8,$09c9,$09c9,$09ca,$09cb'
    dc i'$09cc,$09cd,$09cd,$09ce,$09cf,$09d0,$09d1,$09d1,$09d2,$09d3,$09d4,$09d5,$09d6,$09d6,$09d7,$09d8,$09d9,$09da,$09da,$09db,$09dc,$09dd,$09de,$09de,$09df,$09e0,$09e1,$09e2,$09e3,$09e3,$09e4,$09e5'
    dc i'$09e6,$09e7,$09e7,$09e8,$09e9,$09ea,$09eb,$09eb,$09ec,$09ed,$09ee,$09ef,$09ef,$09f0,$09f1,$09f2,$09f3,$09f3,$09f4,$09f5,$09f6,$09f7,$09f7,$09f8,$09f9,$09fa,$09fb,$09fb,$09fc,$09fd,$09fe,$09ff'
    dc i'$0a00,$0a00,$0a01,$0a02,$0a03,$0a03,$0a04,$0a05,$0a06,$0a07,$0a07,$0a08,$0a09,$0a0a,$0a0b,$0a0b,$0a0c,$0a0d,$0a0e,$0a0f,$0a0f,$0a10,$0a11,$0a12,$0a13,$0a13,$0a14,$0a15,$0a16,$0a17,$0a17,$0a18'
    dc i'$0a19,$0a1a,$0a1b,$0a1b,$0a1c,$0a1d,$0a1e,$0a1f,$0a1f,$0a20,$0a21,$0a22,$0a22,$0a23,$0a24,$0a25,$0a26,$0a26,$0a27,$0a28,$0a29,$0a2a,$0a2a,$0a2b,$0a2c,$0a2d,$0a2d,$0a2e,$0a2f,$0a30,$0a31,$0a31'
    dc i'$0a32,$0a33,$0a34,$0a35,$0a35,$0a36,$0a37,$0a38,$0a38,$0a39,$0a3a,$0a3b,$0a3c,$0a3c,$0a3d,$0a3e,$0a3f,$0a40,$0a40,$0a41,$0a42,$0a43,$0a43,$0a44,$0a45,$0a46,$0a47,$0a47,$0a48,$0a49,$0a4a,$0a4a'
    dc i'$0a4b,$0a4c,$0a4d,$0a4e,$0a4e,$0a4f,$0a50,$0a51,$0a51,$0a52,$0a53,$0a54,$0a54,$0a55,$0a56,$0a57,$0a58,$0a58,$0a59,$0a5a,$0a5b,$0a5b,$0a5c,$0a5d,$0a5e,$0a5f,$0a5f,$0a60,$0a61,$0a62,$0a62,$0a63'
    dc i'$0a64,$0a65,$0a65,$0a66,$0a67,$0a68,$0a69,$0a69,$0a6a,$0a6b,$0a6c,$0a6c,$0a6d,$0a6e,$0a6f,$0a6f,$0a70,$0a71,$0a72,$0a73,$0a73,$0a74,$0a75,$0a76,$0a76,$0a77,$0a78,$0a79,$0a79,$0a7a,$0a7b,$0a7c'
    dc i'$0a7c,$0a7d,$0a7e,$0a7f,$0a80,$0a80,$0a81,$0a82,$0a83,$0a83,$0a84,$0a85,$0a86,$0a86,$0a87,$0a88,$0a89,$0a89,$0a8a,$0a8b,$0a8c,$0a8c,$0a8d,$0a8e,$0a8f,$0a8f,$0a90,$0a91,$0a92,$0a92,$0a93,$0a94'
    dc i'$0a95,$0a96,$0a96,$0a97,$0a98,$0a99,$0a99,$0a9a,$0a9b,$0a9c,$0a9c,$0a9d,$0a9e,$0a9f,$0a9f,$0aa0,$0aa1,$0aa2,$0aa2,$0aa3,$0aa4,$0aa5,$0aa5,$0aa6,$0aa7,$0aa8,$0aa8,$0aa9,$0aaa,$0aab,$0aab,$0aac'
    dc i'$0aad,$0aae,$0aae,$0aaf,$0ab0,$0ab1,$0ab1,$0ab2,$0ab3,$0ab4,$0ab4,$0ab5,$0ab6,$0ab7,$0ab7,$0ab8,$0ab9,$0aba,$0aba,$0abb,$0abc,$0abd,$0abd,$0abe,$0abf,$0ac0,$0ac0,$0ac1,$0ac2,$0ac2,$0ac3,$0ac4'
    dc i'$0ac5,$0ac5,$0ac6,$0ac7,$0ac8,$0ac8,$0ac9,$0aca,$0acb,$0acb,$0acc,$0acd,$0ace,$0ace,$0acf,$0ad0,$0ad1,$0ad1,$0ad2,$0ad3,$0ad4,$0ad4,$0ad5,$0ad6,$0ad6,$0ad7,$0ad8,$0ad9,$0ad9,$0ada,$0adb,$0adc'
    dc i'$0adc,$0add,$0ade,$0adf,$0adf,$0ae0,$0ae1,$0ae2,$0ae2,$0ae3,$0ae4,$0ae4,$0ae5,$0ae6,$0ae7,$0ae7,$0ae8,$0ae9,$0aea,$0aea,$0aeb,$0aec,$0aed,$0aed,$0aee,$0aef,$0aef,$0af0,$0af1,$0af2,$0af2,$0af3'
    dc i'$0af4,$0af5,$0af5,$0af6,$0af7,$0af7,$0af8,$0af9,$0afa,$0afa,$0afb,$0afc,$0afd,$0afd,$0afe,$0aff,$0b00,$0b00,$0b01,$0b02,$0b02,$0b03,$0b04,$0b05,$0b05,$0b06,$0b07,$0b07,$0b08,$0b09,$0b0a,$0b0a'
    dc i'$0b0b,$0b0c,$0b0d,$0b0d,$0b0e,$0b0f,$0b0f,$0b10,$0b11,$0b12,$0b12,$0b13,$0b14,$0b15,$0b15,$0b16,$0b17,$0b17,$0b18,$0b19,$0b1a,$0b1a,$0b1b,$0b1c,$0b1c,$0b1d,$0b1e,$0b1f,$0b1f,$0b20,$0b21,$0b21'
    dc i'$0b22,$0b23,$0b24,$0b24,$0b25,$0b26,$0b27,$0b27,$0b28,$0b29,$0b29,$0b2a,$0b2b,$0b2c,$0b2c,$0b2d,$0b2e,$0b2e,$0b2f,$0b30,$0b31,$0b31,$0b32,$0b33,$0b33,$0b34,$0b35,$0b36,$0b36,$0b37,$0b38,$0b38'
    dc i'$0b39,$0b3a,$0b3b,$0b3b,$0b3c,$0b3d,$0b3d,$0b3e,$0b3f,$0b40,$0b40,$0b41,$0b42,$0b42,$0b43,$0b44,$0b44,$0b45,$0b46,$0b47,$0b47,$0b48,$0b49,$0b49,$0b4a,$0b4b,$0b4c,$0b4c,$0b4d,$0b4e,$0b4e,$0b4f'
    dc i'$0b50,$0b51,$0b51,$0b52,$0b53,$0b53,$0b54,$0b55,$0b55,$0b56,$0b57,$0b58,$0b58,$0b59,$0b5a,$0b5a'

; Index table where the index is a positive x, y slope. The component values are 5-bits in size, and a concatenated together
; to form a 10-bit value, with the y component in the upper bits
math~slope_to_angle anop
    dc i'$0000,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040'
    dc i'$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040,$0040'
    dc i'$0000,$0020,$002d,$0032,$0036,$0037,$0039,$003a,$003a,$003b,$003b,$003c,$003c,$003c,$003d,$003d'
    dc i'$003d,$003d,$003d,$003d,$003d,$003e,$003e,$003e,$003e,$003e,$003e,$003e,$003e,$003e,$003e,$003e'
    dc i'$0000,$0012,$0020,$0028,$002d,$0030,$0032,$0034,$0036,$0037,$0037,$0038,$0039,$0039,$003a,$003a'
    dc i'$003a,$003b,$003b,$003b,$003b,$003c,$003c,$003c,$003c,$003c,$003c,$003c,$003d,$003d,$003d,$003d'
    dc i'$0000,$000d,$0017,$0020,$0025,$0029,$002d,$002f,$0031,$0032,$0034,$0035,$0036,$0036,$0037,$0037'
    dc i'$0038,$0038,$0039,$0039,$0039,$003a,$003a,$003a,$003a,$003b,$003b,$003b,$003b,$003b,$003b,$003c'
    dc i'$0000,$0009,$0012,$001a,$0020,$0024,$0028,$002a,$002d,$002e,$0030,$0031,$0032,$0033,$0034,$0035'
    dc i'$0036,$0036,$0037,$0037,$0037,$0038,$0038,$0038,$0039,$0039,$0039,$003a,$003a,$003a,$003a,$003a'
    dc i'$0000,$0008,$000f,$0016,$001b,$0020,$0023,$0026,$0029,$002b,$002d,$002e,$002f,$0031,$0032,$0032'
    dc i'$0033,$0034,$0034,$0035,$0036,$0036,$0036,$0037,$0037,$0037,$0038,$0038,$0038,$0039,$0039,$0039'
    dc i'$0000,$0006,$000d,$0012,$0017,$001c,$0020,$0023,$0025,$0028,$0029,$002b,$002d,$002e,$002f,$0030'
    dc i'$0031,$0032,$0032,$0033,$0034,$0034,$0035,$0035,$0036,$0036,$0036,$0037,$0037,$0037,$0037,$0038'
    dc i'$0000,$0005,$000b,$0010,$0015,$0019,$001c,$0020,$0022,$0025,$0027,$0028,$002a,$002b,$002d,$002e'
    dc i'$002f,$0030,$0030,$0031,$0032,$0032,$0033,$0033,$0034,$0034,$0035,$0035,$0036,$0036,$0036,$0036'
    dc i'$0000,$0005,$0009,$000e,$0012,$0016,$001a,$001d,$0020,$0022,$0024,$0026,$0028,$0029,$002a,$002c'
    dc i'$002d,$002e,$002e,$002f,$0030,$0031,$0031,$0032,$0032,$0033,$0033,$0034,$0034,$0035,$0035,$0035'
    dc i'$0000,$0004,$0008,$000d,$0011,$0014,$0017,$001a,$001d,$0020,$0022,$0024,$0025,$0027,$0028,$0029'
    dc i'$002b,$002c,$002d,$002d,$002e,$002f,$0030,$0030,$0031,$0031,$0032,$0032,$0033,$0033,$0034,$0034'
    dc i'$0000,$0004,$0008,$000b,$000f,$0012,$0016,$0018,$001b,$001d,$0020,$0021,$0023,$0025,$0026,$0028'
    dc i'$0029,$002a,$002b,$002c,$002d,$002d,$002e,$002f,$002f,$0030,$0031,$0031,$0032,$0032,$0032,$0033'
    dc i'$0000,$0003,$0007,$000a,$000e,$0011,$0014,$0017,$0019,$001b,$001e,$0020,$0021,$0023,$0024,$0026'
    dc i'$0027,$0028,$0029,$002a,$002b,$002c,$002d,$002d,$002e,$002f,$002f,$0030,$0030,$0031,$0031,$0032'
    dc i'$0000,$0003,$0006,$0009,$000d,$0010,$0012,$0015,$0017,$001a,$001c,$001e,$0020,$0021,$0023,$0024'
    dc i'$0025,$0026,$0028,$0029,$0029,$002a,$002b,$002c,$002d,$002d,$002e,$002e,$002f,$0030,$0030,$0030'
    dc i'$0000,$0003,$0006,$0009,$000c,$000e,$0011,$0014,$0016,$0018,$001a,$001c,$001e,$0020,$0021,$0022'
    dc i'$0024,$0025,$0026,$0027,$0028,$0029,$002a,$002b,$002b,$002c,$002d,$002d,$002e,$002e,$002f,$002f'
    dc i'$0000,$0002,$0005,$0008,$000b,$000d,$0010,$0012,$0015,$0017,$0019,$001b,$001c,$001e,$0020,$0021'
    dc i'$0022,$0023,$0025,$0026,$0027,$0028,$0028,$0029,$002a,$002b,$002b,$002c,$002d,$002d,$002e,$002e'
    dc i'$0000,$0002,$0005,$0008,$000a,$000d,$000f,$0011,$0013,$0016,$0017,$0019,$001b,$001d,$001e,$0020'
    dc i'$0021,$0022,$0023,$0024,$0025,$0026,$0027,$0028,$0029,$0029,$002a,$002b,$002b,$002c,$002d,$002d'
    dc i'$0000,$0002,$0005,$0007,$0009,$000c,$000e,$0010,$0012,$0014,$0016,$0018,$001a,$001b,$001d,$001e'
    dc i'$0020,$0021,$0022,$0023,$0024,$0025,$0026,$0027,$0028,$0028,$0029,$002a,$002a,$002b,$002c,$002c'
    dc i'$0000,$0002,$0004,$0007,$0009,$000b,$000d,$000f,$0011,$0013,$0015,$0017,$0019,$001a,$001c,$001d'
    dc i'$001e,$0020,$0021,$0022,$0023,$0024,$0025,$0026,$0026,$0027,$0028,$0029,$0029,$002a,$002a,$002b'
    dc i'$0000,$0002,$0004,$0006,$0008,$000b,$000d,$000f,$0011,$0012,$0014,$0016,$0017,$0019,$001a,$001c'
    dc i'$001d,$001e,$0020,$0021,$0022,$0023,$0024,$0024,$0025,$0026,$0027,$0028,$0028,$0029,$0029,$002a'
    dc i'$0000,$0002,$0004,$0006,$0008,$000a,$000c,$000e,$0010,$0012,$0013,$0015,$0016,$0018,$0019,$001b'
    dc i'$001c,$001d,$001e,$0020,$0021,$0022,$0022,$0023,$0024,$0025,$0026,$0027,$0027,$0028,$0028,$0029'
    dc i'$0000,$0002,$0004,$0006,$0008,$0009,$000b,$000d,$000f,$0011,$0012,$0014,$0016,$0017,$0018,$001a'
    dc i'$001b,$001c,$001d,$001e,$0020,$0020,$0021,$0022,$0023,$0024,$0025,$0026,$0026,$0027,$0028,$0028'
    dc i'$0000,$0001,$0003,$0005,$0007,$0009,$000b,$000d,$000e,$0010,$0012,$0013,$0015,$0016,$0017,$0019'
    dc i'$001a,$001b,$001c,$001d,$001f,$0020,$0020,$0021,$0022,$0023,$0024,$0025,$0025,$0026,$0027,$0027'
    dc i'$0000,$0001,$0003,$0005,$0007,$0009,$000a,$000c,$000e,$000f,$0011,$0012,$0014,$0015,$0017,$0018'
    dc i'$0019,$001a,$001b,$001d,$001e,$001f,$0020,$0020,$0021,$0022,$0023,$0024,$0024,$0025,$0026,$0026'
    dc i'$0000,$0001,$0003,$0005,$0007,$0008,$000a,$000c,$000d,$000f,$0010,$0012,$0013,$0014,$0016,$0017'
    dc i'$0018,$0019,$001b,$001c,$001d,$001e,$001f,$0020,$0020,$0021,$0022,$0023,$0023,$0024,$0025,$0025'
    dc i'$0000,$0001,$0003,$0005,$0006,$0008,$0009,$000b,$000d,$000e,$0010,$0011,$0012,$0014,$0015,$0016'
    dc i'$0017,$0019,$001a,$001b,$001c,$001d,$001e,$001f,$0020,$0020,$0021,$0022,$0023,$0023,$0024,$0025'
    dc i'$0000,$0001,$0003,$0004,$0006,$0008,$0009,$000b,$000c,$000e,$000f,$0010,$0012,$0013,$0014,$0016'
    dc i'$0017,$0018,$0019,$001a,$001b,$001c,$001d,$001e,$001f,$0020,$0020,$0021,$0022,$0023,$0023,$0024'
    dc i'$0000,$0001,$0003,$0004,$0006,$0007,$0009,$000a,$000c,$000d,$000e,$0010,$0011,$0012,$0014,$0015'
    dc i'$0016,$0017,$0018,$0019,$001a,$001b,$001c,$001d,$001e,$001f,$0020,$0020,$0021,$0022,$0022,$0023'
    dc i'$0000,$0001,$0003,$0004,$0005,$0007,$0008,$000a,$000b,$000d,$000e,$000f,$0011,$0012,$0013,$0014'
    dc i'$0015,$0016,$0017,$0018,$0019,$001a,$001b,$001c,$001d,$001e,$001f,$0020,$0020,$0021,$0022,$0022'
    dc i'$0000,$0001,$0002,$0004,$0005,$0007,$0008,$0009,$000b,$000c,$000d,$000f,$0010,$0011,$0012,$0014'
    dc i'$0015,$0016,$0017,$0018,$0019,$001a,$001b,$001c,$001c,$001d,$001e,$001f,$0020,$0020,$0021,$0022'
    dc i'$0000,$0001,$0002,$0004,$0005,$0006,$0008,$0009,$000a,$000c,$000d,$000e,$000f,$0011,$0012,$0013'
    dc i'$0014,$0015,$0016,$0017,$0018,$0019,$001a,$001b,$001c,$001c,$001d,$001e,$001f,$0020,$0020,$0021'
    dc i'$0000,$0001,$0002,$0004,$0005,$0006,$0008,$0009,$000a,$000b,$000d,$000e,$000f,$0010,$0011,$0012'
    dc i'$0013,$0015,$0016,$0017,$0017,$0018,$0019,$001a,$001b,$001c,$001d,$001d,$001e,$001f,$0020,$0020'
    dc i'$0000,$0001,$0002,$0003,$0005,$0006,$0007,$0009,$000a,$000b,$000c,$000d,$000f,$0010,$0011,$0012'
    dc i'$0013,$0014,$0015,$0016,$0017,$0018,$0019,$001a,$001a,$001b,$001c,$001d,$001d,$001e,$001f,$0020'

; Qudrant to cos / sin, sign multiplier
math~cos_quadrant_sign anop
    dc i'$ff00,$0100,$0100,$ff00'

math~sin_quadrant_sign anop
    dc i'$0100,$0100,$ff00,$ff00'

;
; Lookup tables for a 256 direction, rotation to sin / cos
; 16-bit value, in 8.8 fixed-point
math~sin_256 anop
    dc i'$0000,$0006,$000d,$0013,$0019,$001f,$0026,$002c,$0032,$0038,$003e,$0044,$004a,$0050,$0056,$005c'
    dc i'$0062,$0068,$006d,$0073,$0079,$007e,$0084,$0089,$008e,$0093,$0098,$009d,$00a2,$00a7,$00ac,$00b1'
    dc i'$00b5,$00b9,$00be,$00c2,$00c6,$00ca,$00ce,$00d1,$00d5,$00d8,$00dc,$00df,$00e2,$00e5,$00e7,$00ea'
    dc i'$00ed,$00ef,$00f1,$00f3,$00f5,$00f7,$00f8,$00fa,$00fb,$00fc,$00fd,$00fe,$00ff,$00ff,$0100,$0100'
    dc i'$0100,$0100,$0100,$00ff,$00ff,$00fe,$00fd,$00fc,$00fb,$00fa,$00f8,$00f7,$00f5,$00f3,$00f1,$00ef'
    dc i'$00ed,$00ea,$00e7,$00e5,$00e2,$00df,$00dc,$00d8,$00d5,$00d1,$00ce,$00ca,$00c6,$00c2,$00be,$00b9'
    dc i'$00b5,$00b1,$00ac,$00a7,$00a2,$009d,$0098,$0093,$008e,$0089,$0084,$007e,$0079,$0073,$006d,$0068'
    dc i'$0062,$005c,$0056,$0050,$004a,$0044,$003e,$0038,$0032,$002c,$0026,$001f,$0019,$0013,$000d,$0006'
    dc i'$0000,$fffa,$fff3,$ffed,$ffe7,$ffe1,$ffda,$ffd4,$ffce,$ffc8,$ffc2,$ffbc,$ffb6,$ffb0,$ffaa,$ffa4'
    dc i'$ff9e,$ff98,$ff93,$ff8d,$ff87,$ff82,$ff7c,$ff77,$ff72,$ff6d,$ff68,$ff63,$ff5e,$ff59,$ff54,$ff4f'
    dc i'$ff4b,$ff47,$ff42,$ff3e,$ff3a,$ff36,$ff32,$ff2f,$ff2b,$ff28,$ff24,$ff21,$ff1e,$ff1b,$ff19,$ff16'
    dc i'$ff13,$ff11,$ff0f,$ff0d,$ff0b,$ff09,$ff08,$ff06,$ff05,$ff04,$ff03,$ff02,$ff01,$ff01,$ff00,$ff00'
    dc i'$ff00,$ff00,$ff00,$ff01,$ff01,$ff02,$ff03,$ff04,$ff05,$ff06,$ff08,$ff09,$ff0b,$ff0d,$ff0f,$ff11'
    dc i'$ff13,$ff16,$ff19,$ff1b,$ff1e,$ff21,$ff24,$ff28,$ff2b,$ff2f,$ff32,$ff36,$ff3a,$ff3e,$ff42,$ff47'
    dc i'$ff4b,$ff4f,$ff54,$ff59,$ff5e,$ff63,$ff68,$ff6d,$ff72,$ff77,$ff7c,$ff82,$ff87,$ff8d,$ff93,$ff98'
    dc i'$ff9e,$ffa4,$ffaa,$ffb0,$ffb6,$ffbc,$ffc2,$ffc8,$ffce,$ffd4,$ffda,$ffe1,$ffe7,$ffed,$fff3,$fffa'

math~cos_256 anop
    dc i'$ff00,$ff00,$ff00,$ff01,$ff01,$ff02,$ff03,$ff04,$ff05,$ff06,$ff08,$ff09,$ff0b,$ff0d,$ff0f,$ff11'
    dc i'$ff13,$ff16,$ff19,$ff1b,$ff1e,$ff21,$ff24,$ff28,$ff2b,$ff2f,$ff32,$ff36,$ff3a,$ff3e,$ff42,$ff47'
    dc i'$ff4b,$ff4f,$ff54,$ff59,$ff5e,$ff63,$ff68,$ff6d,$ff72,$ff77,$ff7c,$ff82,$ff87,$ff8d,$ff93,$ff98'
    dc i'$ff9e,$ffa4,$ffaa,$ffb0,$ffb6,$ffbc,$ffc2,$ffc8,$ffce,$ffd4,$ffda,$ffe1,$ffe7,$ffed,$fff3,$fffa'
    dc i'$0000,$0006,$000d,$0013,$0019,$001f,$0026,$002c,$0032,$0038,$003e,$0044,$004a,$0050,$0056,$005c'
    dc i'$0062,$0068,$006d,$0073,$0079,$007e,$0084,$0089,$008e,$0093,$0098,$009d,$00a2,$00a7,$00ac,$00b1'
    dc i'$00b5,$00b9,$00be,$00c2,$00c6,$00ca,$00ce,$00d1,$00d5,$00d8,$00dc,$00df,$00e2,$00e5,$00e7,$00ea'
    dc i'$00ed,$00ef,$00f1,$00f3,$00f5,$00f7,$00f8,$00fa,$00fb,$00fc,$00fd,$00fe,$00ff,$00ff,$0100,$0100'
    dc i'$0100,$0100,$0100,$00ff,$00ff,$00fe,$00fd,$00fc,$00fb,$00fa,$00f8,$00f7,$00f5,$00f3,$00f1,$00ef'
    dc i'$00ed,$00ea,$00e7,$00e5,$00e2,$00df,$00dc,$00d8,$00d5,$00d1,$00ce,$00ca,$00c6,$00c2,$00be,$00b9'
    dc i'$00b5,$00b1,$00ac,$00a7,$00a2,$009d,$0098,$0093,$008e,$0089,$0084,$007e,$0079,$0073,$006d,$0068'
    dc i'$0062,$005c,$0056,$0050,$004a,$0044,$003e,$0038,$0032,$002c,$0026,$001f,$0019,$0013,$000d,$0006'
    dc i'$0000,$fffa,$fff3,$ffed,$ffe7,$ffe1,$ffda,$ffd4,$ffce,$ffc8,$ffc2,$ffbc,$ffb6,$ffb0,$ffaa,$ffa4'
    dc i'$ff9e,$ff98,$ff93,$ff8d,$ff87,$ff82,$ff7c,$ff77,$ff72,$ff6d,$ff68,$ff63,$ff5e,$ff59,$ff54,$ff4f'
    dc i'$ff4b,$ff47,$ff42,$ff3e,$ff3a,$ff36,$ff32,$ff2f,$ff2b,$ff28,$ff24,$ff21,$ff1e,$ff1b,$ff19,$ff16'
    dc i'$ff13,$ff11,$ff0f,$ff0d,$ff0b,$ff09,$ff08,$ff06,$ff05,$ff04,$ff03,$ff02,$ff01,$ff01,$ff00,$ff00'

; Just the positive values.  This also does NOT use 1.0 or -1.0, to keep the value completely
; 8-bit so that unsigned, 8 bit multipliers can be used without checking for $0100
; Tables are +1 on the index, to match the math~slope_to_angle table
math~sin_64 anop
    dc i'$0000,$0006,$000d,$0013,$0019,$001f,$0026,$002c,$0032,$0038,$003e,$0044,$004a,$0050,$0056,$005c'
    dc i'$0062,$0068,$006d,$0073,$0079,$007e,$0084,$0089,$008e,$0093,$0098,$009d,$00a2,$00a7,$00ac,$00b1'
    dc i'$00b5,$00b9,$00be,$00c2,$00c6,$00ca,$00ce,$00d1,$00d5,$00d8,$00dc,$00df,$00e2,$00e5,$00e7,$00ea'
    dc i'$00ed,$00ef,$00f1,$00f3,$00f5,$00f7,$00f8,$00fa,$00fb,$00fc,$00fd,$00fe,$00ff,$00ff,$00ff,$00ff,$00ff'

math~cos_64 anop
    dc i'$00ff,$00ff,$00ff,$00ff,$00ff,$00fe,$00fd,$00fc,$00fb,$00fa,$00f8,$00f7,$00f5,$00f3,$00f1,$00ef'
    dc i'$00ed,$00ea,$00e7,$00e5,$00e2,$00df,$00dc,$00d8,$00d5,$00d1,$00ce,$00ca,$00c6,$00c2,$00be,$00b9'
    dc i'$00b5,$00b1,$00ac,$00a7,$00a2,$009d,$0098,$0093,$008e,$0089,$0084,$007e,$0079,$0073,$006d,$0068'
    dc i'$0062,$005c,$0056,$0050,$004a,$0044,$003e,$0038,$0032,$002c,$0026,$001f,$0019,$0013,$000d,$0006,$0000'

; Index table where the index is the divisor of 256
; Also, can be thought of as (1.0 / n) * 256
math~inverse_256 anop
    dc i'$0100,$0080,$0055,$0040,$0033,$002a,$0024,$0020,$001c,$0019,$0017,$0015,$0013,$0012,$0011,$0010,$000f,$000e,$000d,$000c,$000c,$000b,$000b,$000a,$000a,$0009,$0009,$0009,$0008,$0008,$0008,$0008'
    dc i'$0007,$0007,$0007,$0007,$0006,$0006,$0006,$0006,$0006,$0006,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004,$0004'
    dc i'$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0003,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002'
    dc i'$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002,$0002'
    dc i'$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001'
    dc i'$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001'
    dc i'$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001'
    dc i'$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001,$0001'
                          end
