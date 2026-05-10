; A tokenizer definition

tokenizer~offset            gequ 0                                                      ; next location in the buffer to read from.
tokenizer~size              gequ tokenizer~offset+2                                     ; size of the data in the tokenizer buffer
tokenizer~buffer            gequ tokenizer~size+2                                       ; the buffer to read the tokens from.  Does not have to be zero terminated
tokenizer~last_token_offset gequ tokenizer~buffer+4                                     ; the offset of the last token read
tokenizer~last_token_size   gequ tokenizer~last_token_offset+2                          ; the size of the last token read
tokenizer~last_char         gequ tokenizer~last_token_size+2                            ; the value of the last character read
sizeof~tokenizer            gequ tokenizer~last_char+2

