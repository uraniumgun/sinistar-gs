; RIFF Header (audio format) Constants

master_riff_header~id           gequ 0                                  ; file identifier, must be RIFF
master_riff_header~total_size   gequ master_riff_header~id+4            ; total size of the file - 8
master_riff_header~format_typeid gequ master_riff_header~total_size+4   ; Must be WAVE
sizeof~master_riff_header       gequ master_riff_header~format_typeid+4

riff_header~typeid              gequ 'FFIR'                             ; RIFF
riff_header~typeid_format_wave  gequ 'EVAW'                             ; WAVE
riff_chunk~typeid_fmt           gequ ' tmf'                             ; fmt
riff_chunk~typeid_data          gequ 'atad'                             ; data

; A definition of a riff chunk header
riff_chunk_header               gequ 0
riff_chunk_header~typeid        gequ riff_chunk_header
riff_chunk_header~size          gequ riff_chunk_header~typeid+4         ; size of the chunk data that follows this header
sizeof~riff_chunk_header        gequ riff_chunk_header~size+4

riff_chunk_fmt                  gequ 0
riff_chunk_fmt~type             gequ riff_chunk_fmt                     ; the type of data, we only support riff_chunk_fmt~typeid_pcm
riff_chunk_fmt~channels         gequ riff_chunk_fmt~type+2              ; number of channels
riff_chunk_fmt~samples_per_second gequ riff_chunk_fmt~channels+2        ; samples per second
riff_chunk_fmt~avg_bytes_per_second gequ riff_chunk_fmt~samples_per_second+4 ; Average samples per second. (Sample Rate * BitsPerSample * Channels) / 8.
riff_chunk_fmt~block_align      gequ riff_chunk_fmt~avg_bytes_per_second+4   ; (BitsPerSample * Channels) / 8.1 - 8 bit mono2 - 8 bit stereo/16 bit mono4 - 16 bit stereo
riff_chunk_fmt~bits_per_sample  gequ riff_chunk_fmt~block_align+2       ; bits per sample
sizeof~riff_chunk_fmt           gequ riff_chunk_fmt~bits_per_sample+2

riff_chunk_fmt~typeid_pcm       gequ 1
