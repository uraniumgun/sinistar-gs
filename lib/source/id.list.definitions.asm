; Definition for a 16 bit, recycled id list

id_list~free_index              gequ 0                                  ; The index of the next ID that is free
id_list~max_index               gequ id_list~free_index+2               ; The max index.  This is the max number of IDs.  If free_index == max_index, there are no more free IDs
id_list~min_id                  gequ id_list~max_index+2                ; The smallest ID in the list
id_list~max_id                  gequ id_list~min_id+2                   ; The largest ID in the list
sizeof~id_list_header           gequ id_list~max_id+2                   ; size of just the header, the id buffer immediately follows
id_list~ids                     gequ sizeof~id_list_header              ; The
