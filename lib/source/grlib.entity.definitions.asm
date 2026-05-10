; Test for needed globals.
  AIF  C:sizeof~framelib_entity,.past
  ERR 'Must include framelib.definitions before this file'
.past
  AIF  C:sizeof~sprite,.past
  ERR 'Must include grlib.sprite.definitions before this file'
.past

; An entity that contains a framelib_entity and a sprite
; This represents a higher level draw object.  One that has a reference to frame data, that can be animated
; as well as position and erase/draw/update support
; I'm currently having those parts as members, rather than pointers.  It will make for some awkward
; looking offsetting, but will allow for fewer DP values needed to get at members.
grlib_entity                gequ 0
; The sprite sub-object
grlib_entity~sprite         gequ grlib_entity
; The frame information, used to determine the shape pointer to set for the sprite
grlib_entity~frame          gequ grlib_entity+sizeof~sprite
grlib_entity~changed        gequ grlib_entity~frame+sizeof~framelib_entity
; The entity coordinates.  This is in view space.
; Note that if the entity is a child, these coordinates are relative to the parent.
grlib_entity~x              gequ grlib_entity~changed+2         ; X coord
grlib_entity~y              gequ grlib_entity~x+2               ; Y coord
; Sub-entities
grlib_entity~parent_entity_ptr  gequ grlib_entity~y+2
grlib_entity~child_entity_ptr   gequ grlib_entity~parent_entity_ptr+4
grlib_entity~sibling_entity_ptr gequ grlib_entity~child_entity_ptr+4

sizeof~grlib_entity         gequ grlib_entity~sibling_entity_ptr+4

grlib_entity~changed_frame_collection gequ $8000
grlib_entity~changed_frame_set        gequ $4000
grlib_entity~changed_frame_list       gequ $2000
grlib_entity~changed_frame_index      gequ $1000

