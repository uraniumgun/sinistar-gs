; Test for needed globals.
  AIF  C:sizeof~object_definition,.past
  ERR 'Must include object.definitions before this file'
.past

; Structure layout for various container objects
; This file is meant to include (copy)
; Can't use a DATA section, because some of these equates provide a compile time size, and that needs to be a global equate, as DATA based equates are link-time
; Those can't be used by ds operators. Still wish I could do a proper 'struct' definition and have a sizeof style command.
;

container_allocation_fixed              gequ $0001                      ; If set in the flags of a container.  The allocation is fixed. i.e. no growth is allowed beyond the capacity

; A vector (contiguous memory location) iterator.
; This is somewhat like the C++ version, except we keep the delta size in the iterator and, since we almost always need it.
; The iterator also keeps the a full 'end' pointer inside it.
; This does mean a more cumbersome compare to see if we are at the end.  An alternate might be to keep an index in the vector and a length of the vector
; and increment the index when the iterator is incremented, though that might just offset the pointer compare.
; Also, this increment/compare would be easier if we don't allow for iterators to cross bank boundaries.  Hmm.
; Pro-tip: Having the iterator instance as a local (on the DP), make it so you can use the iterator directly for
;          indirection to the data. i.e. lda [<itr], rather than having to use, vector_iterator_data_ptr to get the pointer to a DP address
vector_iterator~ptr                     gequ 0                                      ; Pointer to the iterator data.
vector_iterator~delta_size              gequ vector_iterator~ptr+4                  ; Delta to get the next pointer in the data
vector_iterator~end_ptr                 gequ vector_iterator~delta_size+2           ; Pointer to the end of the data.  Note this is one-past the valid data, do not try and read the location.
sizeof~vector_iterator                  gequ vector_iterator~end_ptr+4

; Vector definition.  Uses 16-bit values for the size/capacity/object size
vector_definition~size                  gequ 0                                     ; Current size of the vector (number of active entries)
vector_definition~capacity              gequ vector_definition~size+2              ; Current capacity of the vector (number of possible entries)
vector_definition~growth_size           gequ vector_definition~capacity+2          ; How many to grow the vector by.  Maybe make this so that negative numbers are a scaling factor?
vector_definition~flags                 gequ vector_definition~growth_size+2       ; Flags
vector_definition~data_ptr              gequ vector_definition~flags+2             ; Pointer to the first element in the vector, can be null!
vector_definition~data_handle           gequ vector_definition~data_ptr+4          ; GS/OS handle to the data elements.  Can be null!
; Note that this stores a copy of the object definition in the vector, not a pointer to the object definition.
; This is because the object definition is simply a size (word) and an optional pointer to a vtable.
; So it is fairly small, and we don't have to do an extra level of indirection to get the size/vtable.
; Might want to re-visit if the object definition gets more complex, though it can be extended easily through the vtable.
vector_definition~object_definition     gequ vector_definition~data_handle+4       ; The object definition.  The size of the definition must be valid, it is ok for the vtable part to not be
sizeof~vector_definition                gequ vector_definition~object_definition+sizeof~object_definition  ; size of the definition.  This must be last

vector_default_growth_size              gequ 2

