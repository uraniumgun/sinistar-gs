; Shape drawing support structure for the legacy draw code
; See grlib.legacy.draw.asm
anmdraw_def                     gequ 0
anmdraw_def~shape_ptr           gequ anmdraw_def                        ; Address of the shape table (long)
anmdraw_def~x                   gequ anmdraw_def~shape_ptr+4            ; X coord of draw (word)
anmdraw_def~y                   gequ anmdraw_def~x+2                    ; Y coord of draw (word)
anmdraw_def~erase~x             gequ anmdraw_def~y+2                    ; X coord of erase (word)
anmdraw_def~erase~y             gequ anmdraw_def~erase~x+2              ; Y coord of erase (word)
anmdraw_def~erase~w             gequ anmdraw_def~erase~y+2              ; Erase width in pixels (word)
anmdraw_def~erase~h             gequ anmdraw_def~erase~w+2              ; Erase height (word)
anmdraw_def~secondary_erase     gequ anmdraw_def~erase~h+2              ; Secondary erase values (erase values from previous erase) (4 * word)
anmdraw_def~secondary_erase~x   gequ anmdraw_def~secondary_erase        ; X coord of erase (word)
anmdraw_def~secondary_erase~y   gequ anmdraw_def~secondary_erase~x+2    ; Y coord of erase (word)
anmdraw_def~secondary_erase~w   gequ anmdraw_def~secondary_erase~y+2    ; Erase width in pixels (word)
anmdraw_def~secondary_erase~h   gequ anmdraw_def~secondary_erase~w+2	; Erase height (word)
anmdraw_def~info                gequ anmdraw_def~secondary_erase+8		; Info (word)
; bit 15 signifies that there is something to erase
anmdraw_def~info~needs_erase    gequ $8000
; bit 14 signifies that there was something erased in the last erase_frame call. Secondary erase values
; are now valid and should be included in the update routine.
anmdraw_def~info~has_erased     gequ $4000
; bit 13 signifies there was something drawn in the last draw call.
anmdraw_def~info~has_drawn      gequ $2000
