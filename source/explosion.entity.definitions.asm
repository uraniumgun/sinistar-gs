; Definitions for a Explosion Entity
; Explosion entity definition.  It is currently 1:1 with a playfield_entity

explosion_entity                gequ 0

explosion_type~none             gequ 0
explosion_type~basic            gequ 1
explosion_type~rock_small       gequ 2
explosion_type~rock_medium      gequ 3
explosion_type~rock_large       gequ 4
explosion_type~warrior          gequ 5
explosion_type~player           gequ 6
explosion_type~sinistar_fragment gequ 7

explosion_image~basic           gequ 0
explosion_image~rock            gequ 1
explosion_image~warrior         gequ 2
explosion_image~player_fragment gequ 3
explosion_image~player_fragment2 gequ 4
explosion_image~sinistar_fragment gequ 5

; Signal that the default variation should be used, which is to pick
; a random one out of however many are available for the type
explosion_variation~default     gequ $ffff
