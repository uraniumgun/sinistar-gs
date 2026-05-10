; Test for needed globals.
  AIF  C:sizeof~grlib_entity,.past
  ERR 'Must include grlib.entity.definitions.asm before this file'
.past

; UI entity definition, for drawing a grlib_entity based objects to the UI area.
;
; grlib_entity at the root
ui_entity                       gequ 0
ui_entity~grentity              gequ ui_entity
; ID of the entity
ui_entity~id                    gequ ui_entity~grentity+sizeof~grlib_entity
ui_entity~direction             gequ ui_entity~id+2

sizeof~ui_entity                gequ ui_entity~direction+2
