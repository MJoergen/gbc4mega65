; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Keyboard controller
;
; The basic idea is: A key first has to be released until it can be counted
; as pressed.
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; typematic delay (DLY) means: how long needs the key to be pressed, until
; the typematic repeat starts?
; typematic speed (SPD) means: how fast will the pressed key be repeated?
TYPEMATIC_DLY  .EQU     0x8000                  ; ~0.5sec in QNICE V1.6
TYPEMATIC_SPD  .EQU     0x1000                  ; ~12 per sec

; call this before working with this library
KEYB_INIT       INCRB
                MOVE    KEYB_PRESSED, R0
                MOVE    0, @R0
                MOVE    KEYB_NEWKEYS, R0
                MOVE    0, @R0
                MOVE    KEYB_CDN_DELAY, R0
                MOVE    0, @R0++
                MOVE    0, @R0++
                MOVE    0, @R0++
                MOVE    0, @R0
                DECRB
                RET

; perform one scan iteration; meant to be called repeatedly
KEYB_SCAN       INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                INCRB

                MOVE    GBC$KEYMATRIX, R0       ; R0: keyboard matrix
                MOVE    @R0, R0
                MOVE    KEYB_PRESSED, R1        ; R1 points to PRESSED
                MOVE    KEYB_NEWKEYS, R2        ; R2 points to NEWKEYS

                ; new keys are keys that have not been pressed since last scan
                NOT     @R1, R3
                AND     R0, R3
                OR      R3, @R2

                ; store currently pressed keys
                MOVE    R0, @R1

                ; typematic repeat for up/down cursor keys
                ; (only inside QNICE as Game Boy does its own thing)
                MOVE    KEY_CUR_DOWN, R8        ; handle cursor down
                MOVE    R1, R9
                MOVE    KEYB_CDN_DELAY, R10
                MOVE    KEYB_CDN_TRIG, R11
                RSUB    _KEYB_TYPEMATIC, 1
                MOVE    KEY_CUR_UP, R8          ; handle cursor up
                MOVE    KEYB_CUP_DELAY, R10
                MOVE    KEYB_CUP_TRIG, R11
                RSUB    _KEYB_TYPEMATIC, 1

                DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                DECRB
                RET

; returns new key in R8
KEYB_GETKEY     INCRB

                MOVE    1, R0                   ; R0: key scanner
                MOVE    KEYB_NEWKEYS, R1        ; R1: list of new keys

_KEYB_GK_LOOP   MOVE    @R1, R2                 ; scan at current R0 pos.
                AND     R0, R2
                RBRA    _KEYBGK_RET_R2, !Z      ; key found? return it
                AND     0xFFFD, SR              ; no: clear X-flag, shift in 0
                SHL     1, R0                   ; move "scanner"
                RBRA    _KEYB_GK_LOOP, !Z       ; loop if not yet done
                RBRA    _KEYBGK_RET_0, 1        ; return 0, if nothing found

_KEYBGK_RET_R2  MOVE    R2, R8                  ; return new key
                NOT     R2, R2
                AND     R2, @R1                 ; unmark this key as new
                RBRA    _KEYBGK_RET, 1

_KEYBGK_RET_0   MOVE    0, R8
_KEYBGK_RET     DECRB
                RET

; internal helper function for typematic repeat
; R8: key code of key that shall be handled
; R9: pointer to PRESSED flag-word
; R10: pointer to speed/delay counter
; R11: pointer to delay-is-over-flag (trigger)
_KEYB_TYPEMATIC INCRB

                MOVE    @R9, R0
                AND     R8, R0                  ; to-be-handled key pressed?
                RBRA    _KEYB_TYPEM_DTD, Z      ; no: delete trg./dly. vars
                CMP     1, @R11                 ; typem, rep. alrdy triggered?
                RBRA    _KEYB_TYPEM_T, Z        ; yes: choose rep. speed
                MOVE    TYPEMATIC_DLY, R6       ; no: choose delay speed
                RBRA    _KEYB_TYPEM_C, 1
_KEYB_TYPEM_T   MOVE    TYPEMATIC_SPD, R6       ; repeat speed     
_KEYB_TYPEM_C   ADD     1, @R10                 ; inc speed/delay counter
                CMP     R6, @R10                ; speed/delay reached?      
                RBRA    _KEYB_TYPEM_RET, !Z     ; no: return

                MOVE    R8, R0                  ; yes: unpress key
                NOT     R0, R0
                AND     R0, @R9
                MOVE    1, @R11                 ; set triggered flag
                RBRA    _KEYB_TYPEM_DTO, 1      ; clear delay and return

_KEYB_TYPEM_DTD MOVE    0, @R11                 ; clear trigger flag
_KEYB_TYPEM_DTO MOVE    0, @R10                 ; clear speed/delay counter

_KEYB_TYPEM_RET DECRB
                RET
