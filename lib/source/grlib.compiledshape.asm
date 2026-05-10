                            copy lib/source/debug.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            mcopy generated/grlib.compiledshape.macros

                            longa on
                            longi on


;------------------------------------------------------------------------------
; Draw a basic compiled shape
; This assumes clipping has been already tested and we don't clip!
; Compiled shapes do not support clipping!
;
; Parameter:
; <shape_ptr        - pointer to the shape data
; <shape_width      - shape's pixel width
; <shape_height     - shape's pixel height
; <draw_x           - draw location x
; <draw_y           - draw location y
_compiled_basic_shape_draw  start seg_grlib_blit
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData

                            debugtag '_compiled_basic_shape_draw'

                            phd
                            lda >grlib~dp
                            tcd

; Should we use shifted data?
                            lda <draw_x
                            bit #1
                            beq no_shifted

; Do we have shifted data?
                            ldy #shapedef~odd_data_offset
                            lda [<shape_ptr],y                          ; can be 0
                            beq no_shifted
                            clc
                            adc <shape_ptr                              ; header skip is in the offset already
                            bra has_shifted

no_shifted                  anop
                            lda <shape_ptr
                            clc
                            adc #sizeof~shapedef_header                 ; Skip the header

has_shifted                 anop
; shape_ptr, now points to the compiled code
                            sta <shape_ptr
                            sta >patch_call+1
                            lda <shape_ptr+1
                            sta >patch_call+2

                            lda <draw_y
                            asl a
                            tax
                            lda <draw_x
                            lsr a
                            clc
                            adc >gYLookup,x
                            adc <altscr_ptr
                            tax

; Set the data bank to the alt screen
                            phb
                            shortm
                            lda <altscr_ptr+2
                            pha
                            longm
                            plb
patch_call                  jsl $bbaaaa
                            plb

                            pld
                            rtl
                            end


