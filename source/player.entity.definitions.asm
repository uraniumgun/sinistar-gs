 AIF C:sizeof~playfield_entity,.past
  ERR 'Must include playfield.entity.definitions.asm before this file'
.past

; Definitions for a Player Entity
; Player entity is a 1:1 with the playfield_entity
player_entity               gequ 0
sizeof~player_entity        gequ sizeof~playfield_entity
