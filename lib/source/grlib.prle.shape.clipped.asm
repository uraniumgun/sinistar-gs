; -----------------------------------------------------------------------------
; The PRLE (pseudo run length encoding) Shape Drawing function
; This version supports horizontal clipping.
;
; See the parent version's file for more information.
;
; Clipping will happen on a byte, not pixel boundary.
; This can be called, even if there is no horizontal clipping occurring, but
; the inner loop will be slower because it is still testing for it.
;
; It is best to call _prle_shape_draw, and it will jump into entry points in this
; function, if it detects that horizontal clipping is required.
; ------------------------------------------------------------------------------
                copy lib/source/debug.definitions.asm
                copy lib/source/shape.definitions.asm
                mcopy generated/grlib.prle.shape.clipped.macros

                longa on
                longi on

; -----------------------------------------------------------------------------
; Note that <shape_ptr is modified by this function.
; Also note that this is not usually called directly.
; The _prle_shape_draw will call the sub-functions of this, as it determines if
; clipping is needed at all
_prle_shape_draw_clipped start seg_grlib
                using grlib_global_equates
                using YLookupData
                using grlib_global_data

; If we are doing a profile, we have to do this little hack, because of the way we normally jump out
                AIF C:debug~profile=0,.skip
                profile_point_begin prle_shape_draw_clipped
                jsr profile_entry
                profile_point_end
                rts
profile_entry   anop
.skip

                phd
                lda >grlib~dp
                tcd

;               keyed_break 0,'_prle_clipped'

                phb                     ; save the data bank, we will set it to where the sprite data lives.
                shortm
                lda <shape_ptr+2        ; Get the bank address.
                pha
                plb                     ; Set to the sprite data, we can use short addressing to get the source data.
                longm

; Remember from here to the end, only DP variables and the stack, as the data bank is set to where the sprite lives.

                ldy #shapedef~width
                lda (<shape_ptr),y
                sta <area_width
; Test if the horizontal drawing is completely off the clip
                lda <draw_x
                cmp <clipx_right
                jsge line_bottom_done
                clc
                adc <area_width
                cmp <clipx_left
                jslt line_bottom_done

                ldy #shapedef~height
                lda (<shape_ptr),y
                sta <area_height

; We now know that horizontally, at least part of the shape is in the clipping area

; Check for left clipping
                stz <shape_byte_clip_left

                lda <draw_x
                cmp <clipx_left
                bsge shape_no_left_clip

_prle_shape_draw_clipped_has_left_clip entry
                and #$fffe                                  ; We want this to be even, so the byte_clip_left is correct
                negate a
                clc
                adc <clipx_left
; The result of this will be positive, as we would have completely clipped otherwise
                lsr a
                sta <shape_byte_clip_left
; However, the left edge destination offset can be negative
                lda <draw_x
                cmp #$7fff                                  ; Get the n flag into the c flag
                ror a                                       ; rotate, so we preserve the negative flag
                sta <dest_left_edge_byte_offset             ; left edge byte offset on the destination to write to.  This is from the left edge of the shape!
                lda <draw_x
                lsr a
                bcc is_even_x
                bra is_odd_x
shape_no_left_clip anop
                lsr a
                sta <dest_left_edge_byte_offset             ; left edge byte offset on the destination to write to.  This is from the left edge of the shape!
                bcc is_even_x
; The x pixel value is odd, we are drawing on byte boundaries, so see if we have 'odd' data, if so, use that.
is_odd_x        ldy #shapedef~odd_data_offset
                lda (<shape_ptr),y
                beq is_even_x                               ; if 0, then we don't have that.
                clc
                adc <shape_ptr
                sta <shape_ptr
                inc <area_width                             ; The odd data, is one pixel wider
                bra have_odd_data                           ; The offset to the odd data, already has the header included.

is_even_x       lda <shape_ptr
                clc
                adc #shapedef~line_offsets
                sta <shape_ptr
have_odd_data   anop

; We know that clipx_right is greater than draw_x at this point.
; This can set shape_byte_clip_right greater than area_width/2, but that is ok
                sec
                lda <clipx_right
                sbc <draw_x

_prle_shape_draw_clipped_has_right_clip entry
                lsr a
                adc #0
                sta <shape_byte_clip_right

                stz <shape_y_offset                 ; Y offset into the shape data.
                lda <draw_y
                cmp <clipy_bottom                   ; Off the bottom of the clip?
                jsge line_bottom_done
                cmp <clipy_top                      ; Off the top of the clip?
                bsge line_top_ok

; Adjust our Y offset into the shape data
                lda <clipy_top
                sec
                sbc <draw_y
                cmp <area_height
                jsge line_bottom_done               ; completely off the top of the clip, we can just exit
                sta <shape_y_offset
                lda <draw_y

line_top_ok     anop
                stz <scratch_word
                clc
                adc <area_height
                cmp <clipy_bottom                   ; Off the bottom of the clip?
                bslt line_bottom_ok
                sec
                sbc <clipy_bottom
                sta <scratch_word
line_bottom_ok  anop
                lda <area_height
                sec
                sbc <shape_y_offset
                sbc <scratch_word
                sta <area_height_countdown          ; <area_height_countdown now has the number of lines we will draw
; Fix <draw_y with any clipping
                lda <draw_y
                clc
                adc <shape_y_offset

; Get the top screen line the lower address
                asl a                               ; x2, we are getting a word
                tax
                lda >gYLookup,x
;               clc                                 ; Don't need this, the asl should have popped out a 0
                adc <dest_left_edge_byte_offset     ; Add the destination left edge offset
                sta <dest_left_edge_byte_offset     ; Lower 16 bits of the start of the destination line, plus the indent on the current line

                dec <shape_y_offset                 ; back up one, we will advance in the loop

                debug_stats_inc >grlib~prle_clipped_draw_count
;
; This is the start of the outer drawing loop.  All the is above is only run once per shape draw.
;
line_loop       anop
; Get the the shape address
                lda <shape_y_offset                 ; 4 Y offset into the shape data.
                inc a                               ; 2
                sta <shape_y_offset                 ; 4
                asl a                               ; 2
                tay                                 ; 2
                lda (<shape_ptr),y                  ; 7 get the offset
                jeq no_groups                       ; 2-3
;               clc                                 ; Don't need this, the asl should have popped out a 0
                adc <shape_ptr                      ; 4
                sta <group_data_load_ptr            ; 4 <group_data_load_ptr now points to the top line we want to draw with, in the shape data
;                                                     31 for above
; Get the screen line the lower address
                lda <dest_left_edge_byte_offset
                sta <dest_left_edge_byte_ptr        ; Lower 16 bits of the start of the destination line, plus the indent on the current line
                adc #160                            ; Advance for next line
                sta <dest_left_edge_byte_offset

; Inner loop for the N number of groups on the line
group_loop      anop
                profile_point_begin2 group_loop_top
                lda (<group_data_load_ptr)          ; length of group
                sta <group_data_byte_size           ; store it, as we may have to adjust it
                stz <group_data_offset_adjust       ; 4 Assume no adjustment from clipping
                ldy #shape_datagroup~indent         ; 3
                lda (<group_data_load_ptr),y        ; 7
                sta <group_info                     ; 4 Save off info
                and #shape_datagroup_indent~byte_count_mask
                sta <group_dest_indent              ; store it, as we may have to adjust it
                cmp <shape_byte_clip_right          ; compare the indent to the local right clip
                bge line_next                       ; if greater or equal to, the group and all other groups, are clipped.
                cmp <shape_byte_clip_left           ; compare the indent to the local left clip
                bge group_no_left_clip              ; if greater or equal to, then no clipping on the left
; We know there is some clipping on the left
;               clc                                 ; carry is already clear
                negate a
                adc <shape_byte_clip_left           ; get the amount of clip on the left
                cmp <group_data_byte_size           ; more that the size of the group?
                bge next_group                      ; if so, next please.
                sta <group_data_offset_adjust       ; save, so we can adjust the source pointer
;               clc
                adc <group_dest_indent              ; 4 adust the indent
                sta <group_dest_indent              ; 4
; Clear any left edge mask
                lda #shape_datagroup_indent~left_edge_mask ; 3
                trb <group_info                     ; 7
                lda <group_data_byte_size           ; 4
                sec                                 ; 2
                sbc <group_data_offset_adjust       ; 4
                sta <group_data_byte_size           ; 4 store new size
                lda <group_dest_indent              ; 4

; Fall through and check for clipping on the right
group_no_left_clip anop
                clc
                adc <group_data_byte_size           ; get the local right edge of the run
                cmp <shape_byte_clip_right          ; compare to the local right clip
                blt group_no_clip                   ; if less, we are ok
                beq group_no_clip
; We have some right clipping
;               sec                                 ; carry is set at this time
                sbc <shape_byte_clip_right
                cmp <group_data_byte_size           ; bigger than our remaining size?
                bge next_group                      ; if so, next group.
                negate a                            ; negate
;               clc                                 ; carry is clear at this time
                adc <group_data_byte_size
                sta <group_data_byte_size
; The clip has made sure there is no right edge, so just test for a left-edge or not
                 lda <group_info                    ; 4
                 and #shape_datagroup_indent~left_edge_mask ; 3
                 beq plotline_whole_bytes
                 clc                                ; 2 has_left_edge is assuming the carry is clear and we know it is not at this time.
                 bra  has_left_edge

group_no_clip   lda <group_info                    ; get the info back
                and #shape_datagroup_indent~left_right_edge_mask      ; 3 Edge flags
; Do some compares to get where we want to go.  Seems ugly.  I can't use a jmp (runfuncs,x), because I have switched the data bank.
; Overall, to fall all the way through to left_and_right_edges, is 9 cycles, then there is still the jmp to do.
; The worst is actually has_left_edge, which is because it needs a successful branch, and that is an extra cycle, so 10, then the jump.
; Instead of using the jmp (runfuncs,x), I could use the rts trick, but that is 20 cycles to setup and do, so slower than the slowest path through now. :/
                beq plotline_whole_bytes            ; 2-3 We are in range to branch directly to this group draw, the rest need jumps, because the code is too large (unrolled loops)
                cmp #shape_datagroup_indent~right_edge_mask ; 3
                beq has_right_edge                  ; 2-3
                blt has_left_edge                   ; 2-3

; Have left and right edges
left_and_right_edges anop
; KWG: OOR       profile_point_end2
; KWG: OOR       profile_point_begin2 plotline_has_left_and_right_edge
                jmp plotline_has_left_and_right_edge ; 3

next_group      anop
                bit <group_info                         ; 4 more on line? Flag is in high bit of info
                bpl line_next                           ; 2-3

                lda <group_data_load_ptr                ; 4
                clc                                     ; 2
                adc (<group_data_load_ptr)              ; 6, can't use group_data_byte_size, it may have been adjusted
                adc #sizeof~shape_datagroup             ; 3
                sta <group_data_load_ptr                ; 4
                bra group_loop                          ; 3

line_next       anop
                dec <area_height_countdown              ; 7
                jne line_loop                           ; 2-3

line_bottom_done anop
                plb
                pld
                rts

has_right_edge  anop
                profile_point_end2
                profile_point_begin2 plotline_has_right_edge
                jmp plotline_has_right_edge         ; 3

has_left_edge   anop
                profile_point_end2
                profile_point_begin2 plotline_has_left_edge
                jmp plotline_has_left_edge          ; 3

no_groups       anop
; Need to advance the line, we will have skipped this
; Carry will be clear on entry
                lda <dest_left_edge_byte_offset
                sta <dest_left_edge_byte_ptr        ; Lower 16 bits of the start of the destination line, plus the indent on the current line
                adc #160                            ; Advance for next line
                sta <dest_left_edge_byte_offset
                bra line_next
; -----------------------------------------------------------------------------
; Whole bytes are in the group, i.e. no edge bytes needing merging with the background.
;
; Vertical line clipping has already been done, however horizontal has not.
; Carry will indeterminant.
plotline_whole_bytes anop
                profile_point_end2
                profile_point_begin2 plotline_whole_bytes
; Get Y to have the full lower 16-bits to where we want to read in the shape data
                clc                                 ; We don't know the state coming in, so clear it
                lda <group_data_load_ptr            ; Get the group address
                adc #sizeof~shape_datagroup         ; Skip the header
                adc <group_data_offset_adjust       ; adjust for any clipping
                tay
; Unrolled loop, with the data writing going backward
; Maximum possible width is 320
                lda <group_data_byte_size           ; Length of group, can be adjusted
                bit #1
                beq plotline_wb_address_calc_not_odd
; Odd number of bytes
; First, calc our jump address into the words unrolled loop
                dec a                               ; 2 cycles
                tax                                 ; 2 cycles
                lda >gMulBy7Inverted,x              ; 6 cycles
                adc #plotline_wb_write_words_end-1
                pha                                 ; 4 cycles, store our jump address
; Get X to have the full lower 16-bits to where we want to store the shape data
                clc
                lda <group_dest_indent              ; get the indent, can be adjusted
                adc <dest_left_edge_byte_ptr        ; Add left edge
                tax                                 ; X now has the full 16-bit address of where we want to write to. (from start of destination buffer)
; Do the odd byte first, this saves from having to test again at the end.
                shortm
                lda |$0000,y
plotline_wb_odd_store_patch anop
                sta >$012000,x
                longm
; Then increment our addresses in X and Y by one, the remaining will be full words
                iny
                inx
                rts                                 ; jump into the unrolled loop
;
plotline_wb_address_calc_not_odd anop
; Jump to the desired place in the unrolled loop
; Each entry is 7 bytes

; When we get here, we have the even number of bytes, which is words * 2, so we don't have to asl
; Multiply by 7 and also negate the value
                tax                             ; 2 cycles
                lda >gMulBy7Inverted,x          ; 6 cycles
; Add to the *end* of the unrolled loop.  This will wrap, and give us the address in the unrolled loop.
; Need to use -1, because RTS will add one
; No need to do a clc, it is clear by the time we get here
                adc #plotline_wb_write_words_end-1
; So now I need to branch to the desired location in the unrolled loop, but I have a problem.
; The data bank is set to wherever the shape data is, so I can't write to a local program bank location and update an indirect jump location
; I could temporarily set the data bank. It is odd that there is no direct page jump, no?
;               phb                             ; 3 cycles
;               phk                             ; 3 cycles
;               plb                             ; 4 cycles
;               sta |loop_jmp_location          ; 4 cycles
;               plb                             ; 4 cycles
;               jmp (loop_jump_location)        ; 5 cycles
; or, get clever and push the short (address - 1) on the stack, and rts!  This would not work if I have futzed with the stack/dp location at this time.
; If DP/Stack is in bank 1, I'd have to do a code patch, which would still mean setting the data bank to the code bank.
; Note, already made the address - 1 in the last adc that added the top of the unrolled loop address
                pha                             ; 4 cycles
; Get X to have the full lower 16-bits to where we want to store the shape data
                clc
                lda <group_dest_indent
                adc <dest_left_edge_byte_ptr    ; Add left edge
                tax                             ; X now has the full 16-bit address of where we want to write to. (from start of destination buffer)
                rts                             ; 6 cycles

; using X and Y as full address registers, so that we don't have to patch code.
;               lda |318,y
;               sta >$012000+318,x
; ... unrolled, decrementing the addresses, to cover the entire screen
;
; A more useful way of looking at it is
;               lda offset(y)
;               sta loffset(x)
plotline_wb_write_words_patch anop
                UnrolledWriteShapeToScreenLoop  ; A macro to generate the unrolled read/write.  Each read/write pair is 7 bytes of opcodes.
plotline_wb_write_words_end anop
                profile_point_end2
                jmp next_group                  ; jump back, faster than an rts

; -----------------------------------------------------------------------------
; Group has a left edge, where the left most pixel in a byte should remain the background color.
; In SHR, this means that the shape data will be in the lower 4 bits, and we need to read the screen
; and #$F0 and OR with the shape data, then write the pixel back.
;
; Vertical line clipping has already been done, however horizontal has not.
; Carry will be clear
plotline_has_left_edge anop
; Get Y to have the full lower 16-bits to where we want to read in the shape data
                lda <group_data_load_ptr            ; Get the group address
                adc #sizeof~shape_datagroup         ; Skip the header
                adc <group_data_offset_adjust       ; adjust for any clipping
                tay

                lda <group_data_byte_size           ; Length of group data, can be adjusted
                bit #1
                bne plotline_hle_address_calc_odd
; Even number of bytes, but we are going to draw one word first
                sbc #1                              ; 3, subtract 1, but with the carry clear, it will subtract 2. Carry will be *set* afterward
                tax                                 ; 2
                lda >gMulBy7Inverted,x              ; 6
                adc #plotline_hle_write_words_end-2  ; 3, note -2, because the carry is *clear*
                pha                                 ; 4, store our jump address
; Get X to have the full lower 16-bits to where we want to store the shape data
                clc
                lda <group_dest_indent
                adc <dest_left_edge_byte_ptr        ; Add left edge
                tax                                 ; X now has the full 16-bit address of where we want to write to. (from start of destination buffer)
; We have an odd byte, but, we also have the left edge, so really, we have a word, do them both together
plotline_hle_edge_load1_patch anop
                lda >$012000,x
                and #$00F0                        ; Lower nybble is the right pixel in the pair, erase that and keep the high nybble, the left pixel
                ora |$0000,y
plotline_hle_edge_store1_patch anop
                sta >$012000,x
; We did a whole word, move up by 2
                iny
                iny
                inx
                inx
                rts                                 ; jump to do the rest of the whole words (could be 0)

plotline_hle_address_calc_odd anop
; Odd bytes, do the first one by itself
                dec a                               ; 2
                tax                                 ; 2
                lda >gMulBy7Inverted,x              ; 6
                adc #plotline_hle_write_words_end-1 ; 3
                pha                                 ; 4, store our jump address
; Get X to have the full lower 16-bits to where we want to store the shape data
                clc
                lda <group_dest_indent
                adc <dest_left_edge_byte_ptr        ; Add left edge
                tax                                 ; X now has the full 16-bit address of where we want to write to. (from start of destination buffer)
; Do just the edge byte, the rest are words
                shortm
plotline_hle_edge_load2_patch anop
                lda >$012000,x
                and #$F0
                ora |$0000,y
plotline_hle_edge_store2_patch anop
                sta >$012000,x
                longm
; Move the addresses up one, to skip the edge byte
                inx
                iny
                rts                             ; 6, jump to do the remaining whole words

plotline_hle_write_words_patch anop
                UnrolledWriteShapeToScreenLoop  ; A macro to generate the unrolled read/write.  Each read/write pair is 7 bytes of opcodes.
plotline_hle_write_words_end anop
                profile_point_end2
                jmp next_group                  ; jump back, faster than an rts

; -----------------------------------------------------------------------------
; Group has a right edge, where the right most pixel in a byte should remain the background color.
; In SHR, this means that the shape data will be in the upper 4 bits, and we need to read the screen
; and #$0F and OR with the shape data, then write the pixel back.
;
; Vertical line clipping has already been done, however horizontal has not.
; Carry will be set
plotline_has_right_edge anop
* Get Y to have the full lower 16-bits to where we want to read in the shape data
                lda <group_data_load_ptr            ; Get the group address
                adc #sizeof~shape_datagroup-1       ; Skip the header (-1 because we know the carry is set)
                adc <group_data_offset_adjust       ; adjust for any clipping
                tay
;
                lda <group_data_byte_size           ; Length of group data, can be adjusted
                dec a                               ; subtracting 1, for the 'edge' byte
                bit #1
                beq plotline_hre_address_calc_even
;
; --- Odd number of bytes before the right edge
;
                dec a                               ; 2, dec one for the odd byte
                tax                                 ; 2
                lda >gMulBy7Inverted,x              ; 6
                adc #plotline_hre_write_words_odd_end-1  ; 3
                pha                                 ; 4, store our jump address
; Get the storage address in X
                clc
                lda <group_dest_indent
                adc <dest_left_edge_byte_ptr        ; Add left edge
                tax                                 ; X now has the full 16-bit address of where we want to write to. (from start of destination buffer)
; Do the odd byte first.
                shortm
                lda |$0000,y
plotline_hre_odd_store_patch anop
                sta >$012000,x
                longm
; odd number of bytes, increment our addresses in X and Y by one, we will do the odd byte at the end
                iny
                inx
                rts                                 ; 6, jump to the words
;
; --- Even number of bytes before the right edge
;
plotline_hre_address_calc_even anop
                tax                                 ; 2
                lda >gMulBy7Inverted,x              ; 6
                adc #plotline_hre_write_words_even_end-1 ; 3
                pha                                 ; 4, store our jump address
; Get the storage address in X
                clc
                lda <group_dest_indent
                adc <dest_left_edge_byte_ptr        ; Add left edge (can be negative!)
                tax                                 ; 2, X now has the full 16-bit address of where we want to write to. (from start of destination buffer)
                rts                                 ; 6 Jump into the unrolled word loop
;
; --- Unrolled loop.  This is 'jumped' into with an rts.
;     This is called by the 'even' path through this run.
;
plotline_hre_write_words_even_patch anop
            UnrolledWriteShapeToScreenLoop  ; A macro to generate the unrolled read/write.  Each read/write pair is 7 bytes of opcodes.
plotline_hre_write_words_even_end anop
; Do the edge byte
; This is more complicated, because it is at the far end, so we have to get our x and y addresses to the correct location
; However, we do know that Y is already pointing to the first byte in the group after the header
                clc                             ; Carry might be set, clear it
                tya                             ; 2 cycles
                adc <group_data_byte_size       ; 4 cycles
                dec a                           ; 2 cycles, go back one
                tay                             ; 2 cycles
; Similar with X, it already pointing to the first byte to draw to.
                txa                             ; 2 cycles
                adc <group_data_byte_size       ; 4 cycles
                dec a                           ; 2 cycles, go back one
                tax
                shortm                          ; 2 cycles
plotline_hre_edge_load1_even_patch anop
                lda >$012000,x
                and #$0F                        ; High nybble is the left pixel in the pair, erase that and keep the low nybble, the right pixel
                ora |$0000,y
plotline_hre_edge_store1_even_patch anop
                sta >$012000,x
                longm

                profile_point_end2
                jmp next_group                   ; jump back, faster than an rts

;
; --- Unrolled loop.  This is 'jumped' into with an rts.
;     This is called by the 'odd' path through this run.
;
plotline_hre_write_words_odd_patch anop
                UnrolledWriteShapeToScreenLoop  ; A macro to generate the unrolled read/write.  Each read/write pair is 7 bytes of opcodes.
plotline_hre_write_words_odd_end anop
; Do the edge byte
; This is more complicated, because it is at the far end, so we have to get our x and y addresses to the correct location
; Y already has the the <group_data_load_ptr + the header in it, but also + 1, because this is the odd path
;               clc                             ; This should still be clear
                tya                             ; 2 cycles
                adc <group_data_byte_size       ; 4 cycles
                sbc #1                          ; 3 cycles.  Need to go back 2.  Carry is *clear*, so subtract 1, and it will do 2.  Carry will be *set* afterward.  This is faster than two decs!
                tay                             ; 2 cycles
; X already pointing to the first byte to draw to.
                txa                             ; 2 cycles
                adc <group_data_byte_size       ; 4 cycles  Note, the carry is now *set* from above, so it will add 1 more than we want, and clear the carry
                sbc #2                          ; 3 cycles.  Need to go back 2.  Carry is *clear*, but we also added 1 more than we needed above, so so subtract 2, and it will subtract 3
                tax
                shortm                          ; 2 cycles
plotline_hre_edge_load1_odd_patch anop
                lda >$012000,x
                and #$0F                        ; High nybble is the left pixel in the pair, erase that and keep the low nybble, the right pixel
                ora |$0000,y
plotline_hre_edge_store1_odd_patch anop
                sta >$012000,x
                longm

                profile_point_end2
                jmp next_group                   ; jump back, faster than an rts

; -----------------------------------------------------------------------------
; Group has a left and right edge
;
; Vertical line clipping has already been done, however horizontal has not.
; Carry will be set
plotline_has_left_and_right_edge anop
; Get Y to have the full lower 16-bits to where we want to read in the shape data
                lda <group_data_load_ptr            ; Get the group address
                adc #sizeof~shape_datagroup-1       ; Skip the header (-1 because we know the carry is set)
                adc <group_data_offset_adjust       ; adjust for any clipping
                tay

                lda <group_data_byte_size           ; Length of group data, can be adjusted
                bit #1
                beq plotline_hlre_address_calc_even      ; Note, we technically want to test if <group_data_byte_size-2 is even/odd, but subtracting 2 does not change that, so just test as-is
; We are odd, and have at least 3 bytes, we are going to do the two 'left' ones here, then the remaining whole words, then the final byte afterward
; Dec 2 for the two bytes we will do now, and 1 for the right edge.  This can result in 0, but that is ok
                sbc #2                              ; 3, faster then 3 decs.  We know the carry is *clear* at the start and will be *set* at the end.
                tax                                 ; 2
                lda >gMulBy7Inverted,x              ; 6
                adc #plotline_hlre_write_words_odd_end-2  ; 3, note -2, because the carry is *set*
                pha                                 ; 4, store our jump address
; Get X to have the full lower 16-bits to where we want to store the shape data
                clc
                lda <group_dest_indent
                adc <dest_left_edge_byte_ptr        ; Add left edge
                tax                                 ; X now has the full 16-bit address of where we want to write to. (from start of destination buffer)
; We have an odd byte, but, we also have the left edge, so really, we have a word, do them both together
plotline_hlre_edge_load1_patch anop
                lda >$012000,x
                and #$00F0                        ; Lower nybble is the right pixel in the pair, erase that and keep the high nybble, the left pixel
                ora |$0000,y
plotline_hlre_edge_store1_patch anop
                sta >$012000,x
; Skip the two bytes we did
                iny
                iny
                inx
                inx
                rts                                 ; 6, jump to do the whole words

plotline_hlre_address_calc_even anop
; We have an even number of bytes, but with a left and right edge
; sbc #1 would be faster, knowing that the carry is clear.  The carry would be *set* afterward!
                sbc #1                              ; 3, faster that 2 decs.  Carry is *clear* on entry and *set* afterward
                tax                                 ; 2
                lda >gMulBy7Inverted,x              ; 6
                adc #plotline_hlre_write_words_even_end-2  ; 3, Note, -2 because we know the carry is *set*
                pha                                 ; 4, store our jump address
; Get the storage pointer into X
                lda <group_dest_indent
                clc
                adc <dest_left_edge_byte_ptr        ; Add left edge (can be negative!)
                tax                                 ; X now has the full 16-bit address of where we want to write to. (from start of destination buffer)
; Do the left edge byte
                shortm
plotline_hlre_edge_load3_patch anop
                lda >$012000,x
                and #$F0
                ora |$0000,y
plotline_hlre_edge_store3_patch anop
                sta >$012000,x
                longm
; Move the addresses up one, to skip the left edge byte
                inx
                iny
                rts                                 ; 6, jump to the desired place in the unrolled loop

; --- Unrolled loop.  This is 'jumped' into with an rts.
;     This is called by the 'even' path through this run.
;
plotline_hlre_write_words_even_patch anop
                UnrolledWriteShapeToScreenLoop  ; A macro to generate the unrolled read/write.  Each read/write pair is 7 bytes of opcodes.
plotline_hlre_write_words_even_end anop
; And the right edge
; This is more complicated, because it is at the far end, so we have to get our x and y addresses to the correct location.
; Y already has the the <group_data_load_ptr + the header in it, but also + 1, because of the left-edge
                clc                             ; Carry might be set, clear it
                tya                             ; 2 cycles
                adc <group_data_byte_size       ; 4 cycles
                sbc #1                          ; 3 cycles.  Need to go back 2.  Carry is *clear*, so subtract 1, and it will do 2.  Carry will be *set* afterward.  This is faster than two decs!
                tay                             ; 2 cycles
; X already pointing to the first byte to draw to.
                txa                             ; 2 cycles
                adc <group_data_byte_size       ; 4 cycles  Note, the carry is now *set* from above, so it will add 1 more than we want, and clear the carry
                sbc #2                          ; 3 cycles.  Need to go back 2.  Carry is *clear*, but was also added 1 more than we needed above, so so subtract 2, and it will subtract 3
                tax                             ; 2 cycles
                shortm
plotline_hlre_edge_load2_even_patch anop
                lda >$012000,x
                and #$0F
                ora |$0000,y
plotline_hlre_edge_store2_even_patch anop
                sta >$012000,x
                longm

                profile_point_end2
                jmp next_group                   ; jump back, quicker than an rts

; --- Unrolled loop.  This is 'jumped' into with an rts.
;     This is called by the 'odd' path through this run.
;
plotline_hlre_write_words_odd_patch anop
                UnrolledWriteShapeToScreenLoop  ; A macro to generate the unrolled read/write.  Each read/write pair is 7 bytes of opcodes.
plotline_hlre_write_words_odd_end anop
; And the right edge
; This is more complicated, because it is at the far end, so we have to get our x and y addresses to the correct location.
; Y already has the the <group_data_load_ptr + the header in it, but also + 2, because of the left-edge, that we did as a whole word
;               clc                             ; We know the carry is clear already
                tya                             ; 2 cycles
                adc <group_data_byte_size       ; 4 cycles
                sbc #2                          ; 3 cycles.  Need to go back 3.  Carry is *clear*, so subtract 2, and it will do 3.  Carry will be *set* afterward.  This is faster than two decs!
                tay                             ; 2 cycles
; X already pointing to the first byte to draw to.
                txa                             ; 2 cycles
                adc <group_data_byte_size       ; 4 cycles  Note, the carry is now *set* from above, so it will add 1 more than we want, and clear the carry
                sbc #3                          ; 3 cycles.  Need to go back 3.  Carry is *clear*, but we also added more than we needed above, so so subtract 3, and it will subtract 4
                tax                             ; 2 cycles
                shortm
plotline_hlre_edge_load2_odd_patch anop
                lda >$012000,x
                and #$0F
                ora |$0000,y
plotline_hlre_edge_store2_odd_patch anop
                sta >$012000,x
                longm

                profile_point_end2
                jmp next_group                   ; jump back, quicker than an rts

                profile_add_symbol2 plotline_has_left_and_right_edge
                profile_add_symbol2 plotline_has_right_edge
                profile_add_symbol2 plotline_has_left_edge
                profile_add_symbol2 plotline_whole_bytes
                profile_add_symbol2 group_loop_top
                profile_add_symbol2 group_loop_bottom
                profile_add_symbol prle_shape_draw_clipped

; -----------------------------------------------------------------------------
;
; Allow for the alternate screen to be not at the shadowed memory SHR location
;
_patch_pack_plot_clipped_destination entry

                phd                 ;save users direct address
                lda   >grlib~dp
                tcd

; The wb (whole byte only) group
                lda #plotline_wb_write_words_patch
                ldy #^plotline_wb_write_words_patch
                jsr patch_unrolled_word_move

; Patch the wb 'odd' byte store
                lda #plotline_wb_odd_store_patch
                ldy #^plotline_wb_odd_store_patch
                jsr patch_long_load_store

; --------------------------------------------------
; The hle (has left edge) group
                lda #plotline_hle_write_words_patch
                ldy #^plotline_hle_write_words_patch
                jsr patch_unrolled_word_move

; No hle 'odd' byte store, we combine with the left edge write

; Patch the hle edge load and store instructions
                lda #plotline_hle_edge_load1_patch
                ldy #^plotline_hle_edge_load1_patch
                jsr patch_long_load_store
                lda #plotline_hle_edge_store1_patch
                ldy #^plotline_hle_edge_store1_patch
                jsr patch_long_load_store
                lda #plotline_hle_edge_load2_patch
                ldy #^plotline_hle_edge_load2_patch
                jsr patch_long_load_store
                lda #plotline_hle_edge_store2_patch
                ldy #^plotline_hle_edge_store2_patch
                jsr patch_long_load_store

; --------------------------------------------------
; The hre (has right edge) group
; This has two unrolled loops, one for the 'even' path
; and one for the 'odd'.  This allows for making some
; assumptions when doing the final right-edge byte
                lda #plotline_hre_write_words_even_patch
                ldy #^plotline_hre_write_words_even_patch
                jsr patch_unrolled_word_move

                lda #plotline_hre_write_words_odd_patch
                ldy #^plotline_hre_write_words_odd_patch
                jsr patch_unrolled_word_move

; Patch the hre 'odd' byte store
                lda #plotline_hre_odd_store_patch
                ldy #^plotline_hre_odd_store_patch
                jsr patch_long_load_store

; Patch the hre edge load and store instructions
                lda #plotline_hre_edge_load1_even_patch
                ldy #^plotline_hre_edge_load1_even_patch
                jsr patch_long_load_store
                lda #plotline_hre_edge_store1_even_patch
                ldy #^plotline_hre_edge_store1_even_patch
                jsr patch_long_load_store
;
                lda #plotline_hre_edge_load1_odd_patch
                ldy #^plotline_hre_edge_load1_odd_patch
                jsr patch_long_load_store
                lda #plotline_hre_edge_store1_odd_patch
                ldy #^plotline_hre_edge_store1_odd_patch
                jsr patch_long_load_store

; --------------------------------------------------
; The hlre (has left and right edge) group
; This has two unrolled loops, one for the 'even' path
; and one for the 'odd'.  This allows for making some
; assumptions when doing the final right-edge byte
                lda #plotline_hlre_write_words_even_patch
                ldy #^plotline_hlre_write_words_even_patch
                jsr patch_unrolled_word_move
                lda #plotline_hlre_write_words_odd_patch
                ldy #^plotline_hlre_write_words_odd_patch
                jsr patch_unrolled_word_move

; No hlre 'odd' byte store, we combine with the left edge

; Patch the hlre edge load and store instructions
                lda #plotline_hlre_edge_load1_patch
                ldy #^plotline_hlre_edge_load1_patch
                jsr patch_long_load_store
                lda #plotline_hlre_edge_store1_patch
                ldy #^plotline_hlre_edge_store1_patch
                jsr patch_long_load_store
; even
                lda #plotline_hlre_edge_load2_even_patch
                ldy #^plotline_hlre_edge_load2_even_patch
                jsr patch_long_load_store
                lda #plotline_hlre_edge_store2_even_patch
                ldy #^plotline_hlre_edge_store2_even_patch
                jsr patch_long_load_store
; odd
                lda #plotline_hlre_edge_load2_odd_patch
                ldy #^plotline_hlre_edge_load2_odd_patch
                jsr patch_long_load_store
                lda #plotline_hlre_edge_store2_odd_patch
                ldy #^plotline_hlre_edge_store2_odd_patch
                jsr patch_long_load_store

                lda #plotline_hlre_edge_load3_patch
                ldy #^plotline_hlre_edge_load3_patch
                jsr patch_long_load_store
                lda #plotline_hlre_edge_store3_patch
                ldy #^plotline_hlre_edge_store3_patch
                jsr patch_long_load_store

                pld                         ; Restore the direct page
                rts

; Takes the address in <altscr_ptr and patches the unrolled word move code pointed
; to by A/Y.  i.e. patches the sta $000000,x instruction in a run of
; lda |$0000,y
; sta >$000000,x
patch_unrolled_word_move anop
                sta <patch_ptr
                sty <patch_ptr+2
                lda <altscr_ptr
                clc
                adc #(320/2)-2                  ; max bytes on a screen line - 2
; Patch the lower 16 bits first
                ldx #((320/2)/2)                ; Each entry is writing a word
                ldy #4                          ; From the start of the unrolled loop, we are patching 4 bytes in, where the lower 16-bits of the sta >$000000, x is.
                sec
patch_loop1     anop
                sta [<patch_ptr],y
                sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                iny                             ; Unrolled loop, 7 bytes for the load/store opcodes
                iny
                iny
                iny
                iny
                iny
                iny
                dex
                bne patch_loop1

; Patch the high byte (bank)
                ldx #((320/2)/2)                ; Each entry is writing a word
                ldy #6                          ; Offset to the high byte
                shortm
                lda <altscr_ptr+2
patch_loop2     anop
                sta [<patch_ptr],y              ; Bank is always the same
                iny                             ; Unrolled loop, 7 bytes for the load/store opcodes
                iny
                iny
                iny
                iny
                iny
                iny
                dex
                bne patch_loop2
                longm
                rts

; Takes the address in <altscr_ptr and patches the odd byte store instruction pointed
; to by A/Y.  i.e. updates the address of a single sta >$000000,x instruction
patch_long_load_store anop
                sta <patch_ptr
                sty <patch_ptr+2
                lda <altscr_ptr
                ldy #1                      ; patch_ptr has the address of the sta, so just skip the opcode.
                sta [<patch_ptr],y
                iny
                iny
                shortm
                lda <altscr_ptr+2
                sta [<patch_ptr],y
                longm
                rts

                end
