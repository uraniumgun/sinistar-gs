; General sndlib definitions

; A generic wave data header
; This is for a single wavetable defintion.
; It meant for ease of use when in memory, and is extended when serialized

wavetable_definition            gequ 0
wavetable_definition~sample_rate gequ wavetable_definition+0            ; rate at which the wavetable was sampled at, in samples per second
wavetable_definition~channels   gequ wavetable_definition~sample_rate+2 ; number of channels
sizeof~wavetable_definition     gequ wavetable_definition~channels+2    ; this is the size of the non-variable part of the definition
; Following the non-variable part, there are N number of data size/offset entries for the channel data
wavetable_definition~size       gequ wavetable_definition~channels+2    ; size of the first wavetable channel data
wavetable_definition~offset     gequ wavetable_definition~size+4        ; offset of the first wavetable channel data.  Note, in memory, this is the pointer to the data.
; Further channels follow

wave_header~typeid_wave         gequ 'EVAW'                             ; WAVE

; This header is serialized, before the wavetable_definition.
; It is just the typeid, and we assume that this first typeid (4 bytes) will be enough
; to identify other headers, such as a RIFF header.
wave_header                     gequ 0
wave_header~typeid              gequ wave_header+0                      ; The typeid
sizeof~wave_header              gequ wave_header~typeid+4

; A definition of wave in the DOC RAM
sound_bank_entry                gequ 0
sound_bank_entry~page           gequ sound_bank_entry                   ; The page the sound starts at.  Only the lower byte is used, and what bits are used by the doc is dependent on the wave-table size. 0 = not-in-use
sound_bank_entry~table_size     gequ sound_bank_entry~page+2            ; The wave-table size.  This is in DOC format, with the size in buts 3-5 and the address bus resolution in bits 0-2
sound_bank_entry~default_frequency gequ sound_bank_entry~table_size+2   ; The default frequency to play the sound back at.  This is in DOC format.
sizeof~sound_bank_entry         gequ sound_bank_entry~default_frequency+2

; A definition of an instanced wave
sound_data_entry                gequ 0
sound_data_entry~bank_entry     gequ sound_data_entry                   ; sound bank the sfx is at.  If sound_bank_entry~page is 0, then it is not in a bank
sound_data_entry~wavetable_ptr  gequ sound_data_entry~bank_entry+sizeof~sound_bank_entry ; pointer to the wave data in RAM.  Can be null
sound_data_entry~wavetable_size gequ sound_data_entry~wavetable_ptr+4   ; the wave data length
sound_data_entry~timer_length   gequ sound_data_entry~wavetable_size+4  ; the timer length to use.  This is in ticks (1/60th of a second)  Note this is based on the default frequency.
sizeof~sound_data_entry         gequ sound_data_entry~timer_length+2

id_oscillator_group~resident    gequ 0
id_oscillator_group~streaming   gequ 1

; This is used to describe oscillators that used to play a single sound.
; It has an oscillator index, and a count of how many oscillators are used, in sequence.
; The normal case is to specify a pair of oscillators that will play the same wave, just in different channels.
; Another case is to specify 3 oscillators, with one of them being used as a timer.  This is the case for streamed audio.
oscillator_binding              gequ 0
oscillator_binding~index        gequ oscillator_binding                 ; the first oscillator index in the binding
oscillator_binding~count        gequ oscillator_binding~index+2         ; how many are in the sequence
oscillator_binding~group        gequ oscillator_binding~count+2         ; which group the binding is in
oscillator_binding~timer        gequ oscillator_binding~group+2         ; frame timer countdown, until when the binding will be 'free'.  If 0, the binding is free to use now.
oscillator_binding~used_by      gequ oscillator_binding~timer+2         ; sfx entry that is using the binding
oscillator_binding~callback     gequ oscillator_binding~used_by+2       ; optional callback for when the timer is finished
oscillator_binding~doc_binding  gequ oscillator_binding~callback+4      ; optional DOC page/size binding.  Used for streamed oscillator bindings
sizeof~oscillator_binding       gequ oscillator_binding~doc_binding+2

sound_interrupt_entry           gequ 0
sound_interrupt_entry~streaming_ptr gequ sound_interrupt_entry
sound_interrupt_entry~streaming_end_ptr gequ sound_interrupt_entry~streaming_ptr+4
sound_interrupt_entry~doc_tblsize  gequ sound_interrupt_entry~streaming_end_ptr+4   ; This is just the table size in the lower bits, it is not in DOC format.  This could be derived from what is in doc_end_offset, but at a cost.
sound_interrupt_entry~doc_sptr  gequ sound_interrupt_entry~doc_tblsize+2
sound_interrupt_entry~doc_offset gequ sound_interrupt_entry~doc_sptr+2
sound_interrupt_entry~doc_end_offset gequ sound_interrupt_entry~doc_offset+2
sizeof~sound_interrupt_entry    gequ sound_interrupt_entry~doc_end_offset+2

sfx_entry                       gequ 0
sfx_entry~sound_data            gequ sfx_entry                          ; the index of the sound data in the global array
sfx_entry~priority              gequ sfx_entry~sound_data+2             ; the priority of the sound, within its oscillator_group.
sizeof~sfx_entry                gequ sfx_entry~priority+2

; Options when manually stopping an sfx
sfx_stop_option~default         gequ 0                                  ; default, which is to do any callback
sfx_stop_option~cancel_callback gequ 1                                  ; don't do any callback

; This is the DOC's scan/update frequency, when all the oscillators are enabled, which is the normal state on the IIgs.
doc_scan_frequency              gequ 26320

; The table size indices for the DOC.
doc_table_size_256              gequ 0
doc_table_size_512              gequ 1
doc_table_size_1024             gequ 2
doc_table_size_2048             gequ 3
doc_table_size_4096             gequ 4
doc_table_size_8192             gequ 5
doc_table_size_16384            gequ 6
doc_table_size_32768            gequ 7

; This is the default amount that an oscillator's 24bit accumulator value must 'advance', to move to the next
; sample in the DOC RAM.  This is not really the DOC's default, it is the applications default, and
; is chosen because it is the only 'common' advance delta for all the table sizes.
; i.e. Setting the bus-resolution bits to match the table size bits, always results in the lower 9 bits
; of the accumulator to be chopped off, when forming the final DOC RAM address.
doc_default_sample_advance_delta gequ 512

