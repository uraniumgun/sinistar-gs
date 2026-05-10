    aif c:grlib_rect,.past
        ERR 'Must include grlib.definitions.asm before this file'
.past

; Max number of entries in a collision list.
collision_max_entries       gequ 128

; Collision entry
collision_entry             gequ 0
collision_entry~prev_sptr   gequ collision_entry                            ; short pointer to the previous entry
collision_entry~next_sptr   gequ collision_entry~prev_sptr+2                ; short pointer to the next entry
collision_entry~entity_sptr gequ collision_entry~next_sptr+2                ; pointer to the entity (short)
collision_entry~collision_type gequ collision_entry~entity_sptr+2           ; type of collision, can be 0
collision_entry~rect        gequ collision_entry~collision_type+2           ; the collision rect
sizeof~collision_entry      gequ collision_entry~rect+sizeof~grlib_rect

; If this bit is set in the type, objects with the same collision type, do not collide with each other.
; This is primarily for Sinistar pieces that are overlapping a bit.
collision_type~option_no_collide gequ $8000

collision_type~none         gequ 0
collision_type~normal       gequ 1

collision_type~normal_no_collide_same gequ collision_type~normal+collision_type~option_no_collide


