graphicsMatrix = &7e00
businessMatrix = &7d00
petToAsciiLookup = &7c80

{
    MACRO addgkey bbc, ascii, petrow, petcolumn
        ORG graphicsMatrix + &00 + bbc
        EQUB petrow
        ORG graphicsMatrix + &80 + bbc
        EQUB petcolumn
        ORG petToAsciiLookup + bbc
        EQUB ascii
    ENDMACRO

    addgkey &00, 0,   8, %00100001 ; SHIFT
    addgkey &01, 0,   0, %00000000 ; CTRL
    addgkey &02, '?', 7, %00010000 ; ?
    addgkey &10, 'Q', 2, %00000001 ; Q
    addgkey &11, '3', 6, %10000000 ; 3
    addgkey &12, '4', 4, %01000000 ; 4
    addgkey &13, '5', 5, %01000000 ; 5
    addgkey &15, '8', 3, %01000000 ; 8
    addgkey &17, '-', 8, %10000000 ; -
    addgkey &18, '^', 2, %00100000 ; ^
    addgkey &19, 0,   0, %01000000 ; LEFT CURSOR
    addgkey &21, 'W', 3, %00000001 ; W
    addgkey &22, 'E', 2, %00000010 ; E
    addgkey &23, 'T', 2, %00000100 ; T
    addgkey &24, '7', 2, %01000000 ; 7
    addgkey &25, 'I', 3, %00001000 ; I
    addgkey &26, '9', 2, %10000000 ; 9
    addgkey &27, '0', 8, %01000000 ; 0
    addgkey &28, '_', 0, %00100000 ; _
    addgkey &29, 0,   1, %01000000 ; DOWN CURSOR
    addgkey &30, '1', 6, %01000000 ; 1
    addgkey &31, '2', 7, %01000000 ; 2
    addgkey &32, 'D', 4, %00000010 ; D
    addgkey &33, 'R', 3, %00000010 ; R
    addgkey &34, '6', 4, %10000000 ; 6
    addgkey &35, 'U', 2, %00001000 ; U
    addgkey &36, 'O', 2, %00010000 ; O
    addgkey &37, 'P', 3, %00010000 ; P
    addgkey &38, '[', 9, %00000010 ; [
    addgkey &39, 0,   1, %01000000 ; UP CURSOR
    addgkey &40, 0,   0, %00000000 ; CAPS LOCK
    addgkey &41, 'A', 4, %00000001 ; A
    addgkey &42, 'X', 7, %00000001 ; X
    addgkey &43, 'F', 5, %00000010 ; F
    addgkey &44, 'Y', 3, %00000100 ; Y
    addgkey &45, 'J', 4, %00001000 ; J
    addgkey &46, 'K', 5, %00001000 ; K
    addgkey &47, '@', 1, %00010000 ; @
    addgkey &48, ':', 5, %00010000 ; :
    addgkey &49, 13,  6, %00100000 ; RETURN
    addgkey &50, 0,   0, %00000000 ; SHIFT LOCK
    addgkey &51, 'S', 5, %00000001 ; S
    addgkey &52, 'C', 6, %00000010 ; C
    addgkey &53, 'G', 4, %00000100 ; G
    addgkey &54, 'H', 5, %00000100 ; H
    addgkey &55, 'N', 7, %00000100 ; N
    addgkey &56, 'L', 4, %00010000 ; L
;    addgkey &57, ';', 6, %00010000 ; ; --- replaced with .
    addgkey &58, ']', 8, %00000100 ; ]
    addgkey &59, 127, 1, %10000000 ; DELETE
    addgkey &60, 9,   9, %00000001 ; TAB (OFF/RVS)
    addgkey &61, 'Z', 6, %00000001 ; Z
    addgkey &62, ' ', 9, %00000100 ; SPACE
    addgkey &63, 'V', 7, %00000010 ; V
    addgkey &64, 'B', 6, %00000100 ; B
    addgkey &65, 'M', 6, %00001000 ; M
    addgkey &66, ',', 7, %00001000 ; ,
    addgkey &67, '.', 6, %00010000 ; . but mapped to ;
    addgkey &68, '/', 3, %10000000 ; /
    addgkey &69, 0,   0, %00000000 ; COPY
    addgkey &70, 0,   0, %00000000 ; ESCAPE
    addgkey &20, 128, 8, %00000010 ; f0
    addgkey &71, 129, 0, %00000001 ; f1
    addgkey &72, 130, 1, %00000001 ; f2
    addgkey &73, 131, 0, %00000010 ; f3
    addgkey &14, 132, 1, %00000010 ; f4
    addgkey &74, 133, 0, %00000100 ; f5
    addgkey &75, 134, 1, %00000100 ; f6
    addgkey &16, 135, 0, %00001000 ; f7
    addgkey &76, 136, 1, %00001000 ; f8
    addgkey &77, 137, 0, %00010000 ; f9
    addgkey &78, '\', 1, %00000100 ; \
    addgkey &79, 0,   0, %10000000 ; RIGHT CURSOR
}

{
    MACRO addbkey bbc, ascii, petrow, petcolumn
        ORG businessMatrix + &00 + bbc
        EQUB petrow
        ORG businessMatrix + &80 + bbc
        EQUB petcolumn
    ENDMACRO

    ; US business keyboard matrix (left arrow supplies f0; main numbers supply f1-f9; keypad supplies digits).
    addbkey &00, 0,   6, %01000001 ; SHIFT
    addbkey &01, 0,   0, %00000000 ; CTRL
    addbkey &02, '?', 8, %01000000 ; ?
    addbkey &10, 'Q', 5, %00000001 ; Q
    addbkey &11, '3', 6, %10000000 ; 3
    addbkey &12, '4', 5, %10000000 ; 4
    addbkey &13, '5', 2, %10000000 ; 5
    addbkey &15, '8', 0, %00010000 ; 8
    addbkey &17, '-', 0, %00001000 ; -
    addbkey &18, '^', 1, %00100000 ; ^
    addbkey &19, 0,   0, %00100000 ; LEFT CURSOR
    addbkey &21, 'W', 4, %00000010 ; W
    addbkey &22, 'E', 5, %00000010 ; E
    addbkey &23, 'T', 5, %00000100 ; T
    addbkey &24, '7', 1, %00010000 ; 7
    addbkey &25, 'I', 4, %00100000 ; I
    addbkey &26, '9', 1, %10000000 ; 9
    addbkey &28, '_', 9, %00000001 ; _
    addbkey &29, 0,   5, %00010000 ; DOWN CURSOR
    addbkey &30, '1', 8, %10000000 ; 1
    addbkey &31, '2', 7, %10000000 ; 2
    addbkey &32, 'D', 3, %00000010 ; D
    addbkey &33, 'R', 4, %00000100 ; R
    addbkey &34, '6', 3, %10000000 ; 6
    addbkey &35, 'U', 5, %00001000 ; U
    addbkey &36, 'O', 5, %00100000 ; O
    addbkey &37, 'P', 4, %01000000 ; P
    addbkey &38, '[', 3, %01000000 ; [
    addbkey &39, 0,   5, %00010000 ; UP CURSOR
    addbkey &40, 0,   0, %00000000 ; CAPS LOCK
    addbkey &41, 'A', 3, %00000001 ; A
    addbkey &42, 'X', 8, %00000010 ; X
    addbkey &43, 'F', 2, %00000100 ; F
    addbkey &44, 'Y', 4, %00001000 ; Y
    addbkey &45, 'J', 3, %00001000 ; J
    addbkey &46, 'K', 2, %00100000 ; K
    addbkey &47, '@', 1, %00001000 ; @ (mapped to 0)
    addbkey &48, ':', 9, %00100000 ; :
    addbkey &49, 13,  3, %00010000 ; RETURN
    addbkey &50, 0,   0, %00000000 ; SHIFT LOCK
    addbkey &51, 'S', 2, %00000010 ; S
    addbkey &52, 'C', 6, %00000010 ; C
    addbkey &53, 'G', 3, %00000100 ; G
    addbkey &54, 'H', 2, %00001000 ; H
    addbkey &55, 'N', 7, %00000100 ; N
    addbkey &56, 'L', 3, %00100000 ; L
    addbkey &57, ';', 2, %00010000 ; ;
    addbkey &58, ']', 5, %01000000 ; ]
    addbkey &59, 127, 4, %10000000 ; DELETE
    addbkey &60, 9,   4, %00000001 ; TAB (OFF/RVS)
    addbkey &61, 'Z', 7, %00000001 ; Z
    addbkey &62, ' ', 8, %00000100 ; SPACE
    addbkey &63, 'V', 7, %00000010 ; V
    addbkey &64, 'B', 6, %00000100 ; B
    addbkey &65, 'M', 8, %00001000 ; M
    addbkey &66, ',', 7, %00001000 ; ,
    addbkey &67, '.', 6, %00001000 ; .
    addbkey &68, '/', 8, %01000000 ; /
    addbkey &69, 0,   0, %00000000 ; COPY
    addbkey &70, 0,   2, %00000001 ; ESCAPE
    addbkey &20, 128, 9, %00000001 ; f0 (left arrow)
    addbkey &71, 129, 1, %00000001 ; f1
    addbkey &72, 130, 0, %00000001 ; f2
    addbkey &73, 131, 9, %00000010 ; f3
    addbkey &14, 132, 1, %00000010 ; f4
    addbkey &74, 133, 0, %00000010 ; f5
    addbkey &75, 134, 9, %00000100 ; f6
    addbkey &16, 135, 1, %00000100 ; f7
    addbkey &76, 136, 0, %00000100 ; f8
    addbkey &77, 137, 9, %00001000 ; f9
    addbkey &78, '\', 2, %01000000 ; \
    addbkey &79, 0,   0, %00100000 ; RIGHT CURSOR
}
