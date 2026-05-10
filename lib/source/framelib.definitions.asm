; Test for needed globals.
  AIF  C:sizeof~grlib_rect,.past
  ERR 'Must include grlib.definitions.asm before this file'
.past

; Frame Library
; This represents a hierarchy of 'frames' (sprite/shape references) that make up things such as a character, building, or any self-contained
; object that needs to be visually represented.

; Based on the PC constructs, though somewhat reduced.  I eliminated the 'frame array' object, which allowed the 'frame list' to have multiple arrays.
; I didn't use that much and most of the time, just used the first array of frames.
; I also don't currently support 'sub-frames', though that could be added back in, if needed.
; I also removed attachments and point arrays

; The base object, which is a frame number reference.  The frame number is most often the sprite/shape ID in the datalib_library that the framelib is also from.
;
; Also note that I am *not* using dynamic storage for arrays of things, i.e. No container_vectors.  This is because I don't intend on adjusting anything on-the-fly
; and so, I can have everything on one big block and just read it in, and fixup the pointers.
; Also note, that I am using 32 bit offsets/pointers, even though 16 would do.  This allows me to not have to set the data bank.
; I may revisit this, though there is no speed issue, a [zp],y and a (zp),y is the same, it just means more moving around of data because the pointer size is bigger.
; However, most of the code assumes 32 bit pointers.
framelib_frame                          gequ 0
framelib_frame~id                       gequ framelib_frame
framelib_frame~info                     gequ framelib_frame~id+2
sizeof~framelib_frame                   gequ framelib_frame~info+2

; A definition of how to animate an array of frames
framelib_animation                      gequ 0
framelib_animation~type                 gequ framelib_animation
framelib_animation~options              gequ framelib_animation~type+2
framelib_animation~base_rate            gequ framelib_animation~options+2
framelib_animation~data1                gequ framelib_animation~base_rate+2
framelib_animation~data2                gequ framelib_animation~data1+2
sizeof~framelib_animation               gequ framelib_animation~data2+2

; A list of frames
framelib_list                           gequ 0
framelib_list~footprint_rect            gequ framelib_list
framelib_list~collision_rect            gequ framelib_list~footprint_rect+sizeof~grlib_rect
framelib_list~attack_rect               gequ framelib_list~collision_rect+sizeof~grlib_rect
; Note, skipping the Point Array and Attachment Array for now
framelib_list~animation                 gequ framelib_list~attack_rect+sizeof~grlib_rect        ; How to animate the frames.
framelib_list~dx                        gequ framelib_list~animation+sizeof~framelib_animation
framelib_list~dy                        gequ framelib_list~dx+2
framelib_list~count                     gequ framelib_list~dy+2
framelib_list~data_ptr                  gequ framelib_list~count+2                              ; Can be null! Cached data for the list.  This points to an array of loaded shapes the correspond to the frame IDs.
sizeof~framelib_list                    gequ framelib_list~data_ptr+4
; the array of frames appears immediately afterward.  Note, this is not part of the 'sizeof'
framelib_list~array                     gequ sizeof~framelib_list

; A set of frame lists.  This usually describes a high level concept like 'walk' or 'attack'
; The set contains one or more lists of frames.  The lists are most often used as the 'direction'
; a character is facing in.
; Note, this used to have a animation reference, but I removed it, in favor of just having all the animation data in the framelib_list.
framelib_set                            gequ 0
framelib_set~id                         gequ framelib_set
framelib_set~variation                  gequ framelib_set~id+2              ; Note, the ID is 4 bytes, this equate is just a helper to access the high word, which is the variation part of the id.
;framelib_set~sub_id                     gequ framelib_set~id+4
;framelib_set~sub_id_link                gequ framelib_set~sub_id+4
framelib_set~info                       gequ framelib_set~id+4
;framelib_set~layering_offset            gequ framelib_set~info+2
framelib_set~count                      gequ framelib_set~info+2
sizeof~framelib_set                     gequ framelib_set~count+2
; the array of list pointer/offsets appears immediately afterward.  Note, this is not part of the 'sizeof'
framelib_set~lists                      gequ sizeof~framelib_set                                ; array of pointers/offsets to the lists

; An entry defining a set entry in the collection
; This repeats a bit of data that is in the set definition itself, but helps
; with searching for sets in the collection.
; Note that with this, the code assumes the variation is always just an index from 0-n
framelib_collection_set_entry           gequ 0
framelib_collection_set_entry~id        gequ framelib_collection_set_entry                      ; the base id of the set, no variation.
framelib_collection_set_entry~offset    gequ framelib_collection_set_entry~id+2                 ; offset, from the start of the framelib_collection, into the table of set pointers, for the first variation
framelib_collection_set_entry~variation_count gequ framelib_collection_set_entry~offset+2       ; number of variations of the set.
sizeof~framelib_collection_set_entry    gequ framelib_collection_set_entry~variation_count+2

; Top-level collection of the frame hierarchy. Contains one or more sets of frames.
; Note that any, non-serialize data is at the top of the collection, everything afterward is assumed to be loaded
; in and offsets will be translated into pointers.
framelib_collection                     gequ 0
framelib_collection~reference_count     gequ framelib_collection
framelib_collection~data_entry_ptr      gequ framelib_collection~reference_count+2              ; the datalib_data_entry the collection is from
framelib_collection~library_ptr         gequ framelib_collection~data_entry_ptr+4               ; the datalib_library the collection is from. We can get this from the data_entry, but we use it a lot, so it is cached.
sizeof~framelib_collection~runtime_header gequ framelib_collection~library_ptr+4                ; This is not a member, it is just a marker as to where the runtime header ends
framelib_collection~id                  gequ sizeof~framelib_collection~runtime_header          ; id
framelib_collection~info                gequ framelib_collection~id+4                           ; info bits
framelib_collection~unique_count        gequ framelib_collection~info+2                         ; unique number of sets.  This does not include the variations.
framelib_collection~total_count         gequ framelib_collection~unique_count+2                 ; total number of set/variations
framelib_collection~total_set_offset    gequ framelib_collection~total_count+2                  ; a helper offset, which is the offset, to the second array of offsets to the set definitions. Saves time calculating it at runtime.
sizeof~framelib_collection              gequ framelib_collection~total_set_offset+2
; Two arrays are immediately afterward.  Note, this is not part of the 'sizeof'
; An array of framelib_collection_set_entry * framelib_collection~unique_count
; An array of word offsets * framelib_collection~total_count, which is the offset from the collection structure start, to each set definition
framelib_collection~sets                gequ sizeof~framelib_collection                         ; array of pointers/offsets to the lists

; Serialization version
framelib_collection_file_header_current_version gequ 1
framelib_collection_file_header         gequ 0
framelib_collection_file_header~version gequ framelib_collection_file_header
sizeof~framelib_collection_file_header  gequ framelib_collection_file_header~version+2

; This is the struct that defines a framelib state, inside a grlib entity.
; (maybe define this in that definition file?)
; It describes the visual state of a grlib entity instance.
; Some values, such as counts, are copied into this struct, from the shared
; to prevent having to dereference a pointer to get the value.
framelib_entity                         gequ 0
framelib_entity~frame                   gequ framelib_entity
framelib_entity~list                    gequ framelib_entity~frame+2
framelib_entity~set                     gequ framelib_entity~list+2
framelib_entity~variation               gequ framelib_entity~set+2
framelib_entity~collection_id           gequ framelib_entity~variation+2
framelib_entity~collection_ptr          gequ framelib_entity~collection_id+4
framelib_entity~collection_bank         gequ framelib_entity~collection_ptr+2       ; alias to the shared bank
framelib_entity~set_sptr                gequ framelib_entity~collection_ptr+4
framelib_entity~list_count              gequ framelib_entity~set_sptr+2
framelib_entity~list_sptr               gequ framelib_entity~list_count+2
framelib_entity~frame_count             gequ framelib_entity~list_sptr+2
framelib_entity~primary_frame_data_ptr  gequ framelib_entity~frame_count+2
framelib_entity~secondary_frame_data_ptr gequ framelib_entity~primary_frame_data_ptr+4
sizeof~framelib_entity                  gequ framelib_entity~secondary_frame_data_ptr+4

; Common Set ID values
framelib_set_id_walk                    gequ 1
framelib_set_id_attack                  gequ 16
framelib_set_id_idle                    gequ 64
framelib_set_id_die                     gequ 96

; Animation types
framelib_animation_type~default         gequ 0
framelib_animation_type~none            gequ 1
framelib_animation_type~frame_advance   gequ 2
framelib_animation_type~list_advance    gequ 3
framelib_animation_type~frame_reverse   gequ 4
framelib_animation_type~list_reverse    gequ 5

; Animation options
framelib_animation_options~looped       gequ $0001




