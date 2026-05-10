  AIF  C:sizeof~vector_definition,.past
  ERR 'Must include container.definitions.asm before this file'
.past
; A pool of buffers for string_objects
; This uses a simple block allocation strategy, where there is a chain of blocks that hold
; buffers of a specified capacity.
; The string_object allocator will use multiple pools, each holding string buffers of different capacities.
; Using some generic terminology in the descriptions, as this will probably turn into a derivation
; where the block allocator uses generic objects.
; The free-chain is implemented by using a singly linked list of the free slots, using the slot buffer itself.
; This means that the minimum slot size is 4 bytes.
; Thought about using a slot index free chain.  It would be smaller, but then to get the pointer, some
; math would have to be done, which would be slow, since to get an overall pointer from an index, which involves
; getting the block index, then getting the address of the index in the block.
; There are other systems that could be used for free tracking, the pointer chain seems the fastest and with no
; memory overhead, other than a minimum slot size, which is smaller than any realistic minimum for a string
; slot size anyway.  Might be different for a generic system, where the slot is intended for binary data
; i.e. a pool of word values would not work.
fixed_buffer_pool                   gequ 0
fixed_buffer_pool~slots_inuse       gequ fixed_buffer_pool                     ; Slots in use
fixed_buffer_pool~head_free_slot_ptr gequ fixed_buffer_pool~slots_inuse+2       ; The pointer to the first free slot, null if none
fixed_buffer_pool~tail_free_slot_ptr gequ fixed_buffer_pool~head_free_slot_ptr+4 ; The pointer to the last free slot, null if none
fixed_buffer_pool~slot_size         gequ fixed_buffer_pool~tail_free_slot_ptr+4  ; The slot size
fixed_buffer_pool~slots_per_block   gequ fixed_buffer_pool~slot_size+2         ; Slots per block
fixed_buffer_pool~block_size        gequ fixed_buffer_pool~slots_per_block+2   ; Slot size * Slots per block
fixed_buffer_pool~blocks_vector     gequ fixed_buffer_pool~block_size+2        ; The vector of blocks.
sizeof~fixed_buffer_pool            gequ fixed_buffer_pool~blocks_vector+sizeof~vector_definition

fixed_buffer_pool_min_slot_size    gequ 4 ; Because we use the slot memory for the free chain, we need this as the minimum slot size, because we are using pointers for the chain.
