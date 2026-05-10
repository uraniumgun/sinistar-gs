  AIF  C:sizeof~grlib_rect,.past
  ERR 'Must include grlib.definitions.asm before this file'
.past
  AIF  C:sizeof~grlib_entity_sort_list,.past
  ERR 'Must include grlib.entity.sort.definitions.asm before this file'
.past
; --------------------------------------------------------------------------------------------
; An instance of a playfield
playfield~bounds            gequ 0                                          ; bounds of the entire playfield
sizeof~playfield            gequ playfield~bounds+sizeof~grlib_rect

; A view into a playfield
playfield_view~bounds       gequ 0                             	            ; view within the a playfield
playfield_view~sort_list    gequ playfield_view~bounds+sizeof~grlib_rect    ; entity sortlist in the view
playfield_view~playfield_ptr gequ playfield_view~sort_list+sizeof~grlib_entity_sort_list    ; The pointer to the playfield the view is for, does not own this pointer.
sizeof~playfield_view       gequ playfield_view~playfield_ptr+4

; Maximum entities.  This is primarily to size the sort-list, buffer.
playfield~max_entities      gequ 512

; palette slot modifier color
palette_modifier~base_color         gequ 0                               ; base color
palette_modifier~count_down         gequ palette_modifier~base_color+2   ; count down, to when the slot color should revert to the base palette color
palette_modifier~alt_color          gequ palette_modifier~count_down+2
palette_modifier~pad                gequ palette_modifier~alt_color+2
sizeof~palette_modifier             gequ palette_modifier~pad+2

; Add this to the frame count, to start a new count down
palette_modifier~new_count_down     gequ $8000
