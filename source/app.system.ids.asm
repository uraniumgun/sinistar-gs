; App System IDs
; This file is meant to include (copy)
; All app systems are $8000 or higher

system_id_playfield_entity_manager  gequ $8000
system_id_rock_entity_manager       gequ $8100
system_id_worker_entity_manager     gequ $8200
system_id_warrior_entity_manager    gequ $8300
system_id_shot_entity_manager       gequ $8400
system_id_explosion_entity_manager  gequ $8500
system_id_crystal_entity_manager    gequ $8600
system_id_sinistar_entity_manager   gequ $8700
system_id_bomb_entity_manager       gequ $8800
system_id_player_entity_manager     gequ $8900

; Errors.  These are meant to be in the lower byte
; These are 'common' errors, that can be added to the system_id to make a complete error code
app_error_null_pointer              gequ $0001
app_error_allocation_failed         gequ $0002
app_error_invalid_parameter         gequ $0003


