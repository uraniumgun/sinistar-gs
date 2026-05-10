; Test for needed globals.
  AIF  C:sizeof~fixed_buffer_pool,.past
  ERR 'Must include fixed.buffer.pool.definitions.asm before this file'
.past
; Sort/Draw list support for grlib_entity instances.
grlib_entity_sort_entry         gequ 0
grlib_entity_sort_entry~prev_sptr gequ grlib_entity_sort_entry                       ; prev
grlib_entity_sort_entry~next_sptr gequ grlib_entity_sort_entry~prev_sptr+2           ; and next, are short pointers
grlib_entity_sort_entry~sort_value gequ grlib_entity_sort_entry~next_sptr+2
; Pointer to a grlib_entity.
grlib_entity_sort_entry~entity_ptr  gequ grlib_entity_sort_entry~sort_value+2
sizeof~grlib_entity_sort_entry  gequ grlib_entity_sort_entry~entity_ptr+4

; The head and the tail of the list, are stored in the first entry of the pool
grlib_entity_sort_list_root~head_sptr  gequ 0
grlib_entity_sort_list_root~tail_sptr  gequ grlib_entity_sort_list_root~head_sptr+2

grlib_entity_sort_list~root_ptr gequ 0
grlib_entity_sort_list~pool     gequ grlib_entity_sort_list~root_ptr+4
sizeof~grlib_entity_sort_list   gequ grlib_entity_sort_list~pool+sizeof~fixed_buffer_pool

