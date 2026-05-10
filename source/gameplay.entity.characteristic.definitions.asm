; Entity Characteristic Definition
; This is static data for an entity, that is shared with entities of the same type
; This is not necessarily 1:1 with the high-level entities, i.e. worker, warrior, etc.
; There can be multiple characteristics that are assiged for each of those types.
; The original code used this table more extensively, I am just retaining members
; that related to the game logic that I want to preserve.
gameplay_entity_characteristic          gequ 0
gameplay_entity_characteristic~ai_type  gequ gameplay_entity_characteristic
gameplay_entity_characteristic~mass     gequ gameplay_entity_characteristic~ai_type+2
gameplay_entity_characteristic~collision_type gequ gameplay_entity_characteristic~mass+2
gameplay_entity_characteristic~explosion_type gequ gameplay_entity_characteristic~collision_type+2
gameplay_entity_characteristic~leave_sector_func_ptr gequ gameplay_entity_characteristic~explosion_type+2
sizeof~gameplay_entity_characteristic   gequ gameplay_entity_characteristic~leave_sector_func_ptr+4

; The characteristic IDs.  Note, the are not a simple index, they are
; offsets, into the characteristics_table, for easy lookup
id_characteristic_default               gequ 0
id_characteristic_player                gequ sizeof~gameplay_entity_characteristic*1
id_characteristic_worker                gequ sizeof~gameplay_entity_characteristic*2
id_characteristic_warrior               gequ sizeof~gameplay_entity_characteristic*3
id_characteristic_player_shot           gequ sizeof~gameplay_entity_characteristic*4
id_characteristic_warrior_shot          gequ sizeof~gameplay_entity_characteristic*5
id_characteristic_worker_with_crystal   gequ sizeof~gameplay_entity_characteristic*6
id_characteristic_crystal               gequ sizeof~gameplay_entity_characteristic*7
id_characteristic_explosion             gequ sizeof~gameplay_entity_characteristic*8
id_characteristic_planetoid_1           gequ sizeof~gameplay_entity_characteristic*9
id_characteristic_planetoid_2           gequ sizeof~gameplay_entity_characteristic*10
id_characteristic_planetoid_3           gequ sizeof~gameplay_entity_characteristic*11
id_characteristic_planetoid_4           gequ sizeof~gameplay_entity_characteristic*12
id_characteristic_planetoid_5           gequ sizeof~gameplay_entity_characteristic*13
id_characteristic_sinistar              gequ sizeof~gameplay_entity_characteristic*14
id_characteristic_bomb                  gequ sizeof~gameplay_entity_characteristic*15
