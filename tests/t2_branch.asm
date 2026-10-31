; Test group 2 / trace 8.4 : taken branch kills wrong-path actuator store, wrong-path HALT
; ---------------- memory map (see memory_map.pdf) ----------------
.equ IN_STAT, 0xF0      ; R  : [1:0] MODE, [2] START, [3] DOOR_CLOSED, [4] TRIP, [5] MOTOR_ACTUAL
.equ LEVEL,   0xF1      ; R  : WATER_LEVEL[7:0] (unsigned)
.equ TEMP,    0xF2      ; R  : TEMP[7:0]
.equ RPM,     0xF3      ; R  : DRUM_RPM[7:0]
.equ ACT,     0xF4      ; RW : [0] VALVE_IN [1] HEATER [2] MOTOR_EN [3] MOTOR_DIR [4] PUMP_OUT [5] DOOR_LOCK [6] BUZZER
.equ DISP,    0xF5      ; RW : DISPLAY[7:0]
.equ TCOUNT,  0xF6      ; R  : TIMER_COUNT
.equ TLIMIT,  0xF7      ; RW : TIMER_LIMIT (0 = compare disabled)
.equ TCTRL,   0xF8      ; RW : [0] EN (R/W) ; [1] CLR (write-1 pulse, reads 0)
.equ TSTAT,   0xF9      ; R  : [0] MATCH (sticky)
; IN_STAT bits
.equ M_MODE,  0x03
.equ B_START, 0x04
.equ B_DOOR,  0x08
.equ B_TRIP,  0x10
.equ B_MACT,  0x20
; ACT bits
.equ A_VALVE, 0x01
.equ A_HEAT,  0x02
.equ A_MOTOR, 0x04
.equ A_DIR,   0x08
.equ A_PUMP,  0x10
.equ A_LOCK,  0x20
.equ A_BUZZ,  0x40

            LDI  R2, A_VALVE       ; data that would open the valve
            LDI  R5, ACT           ; Rvalve = ACT latch address
            LDI  R3, 0x11
            LDI  R4, 0x22
            LDI  R1, 0x5A
            NOP
            NOP
            NOP
; ---- 8.4
t84:        SUB  R1, R1            ; R1 = 0
            BEQZ R1, target        ; taken, resolved in EX (R1 via EX/MEM)
            ST   R2, [R5]          ; wrong path: must not write ACT
            ADD  R3, R4            ; wrong path: must not write R3
target:     LDI  R6, 0x40
            ST   R3, [R6]          ; RAM[0x40] = 0x11 (proves ADD was killed)
            LDI  R1, 0x07
            BNEZ R1, tgt2          ; taken
            HALT                   ; wrong-path HALT: must be flushed
            ST   R2, [R5]          ; wrong path
tgt2:       JMP  tgt3              ; unconditional
            HALT                   ; wrong-path HALT
            ST   R2, [R5]          ; wrong path
tgt3:       BEQZ R1, bad           ; not taken (R1 = 7)
            LDI  R7, 0x41
            LDI  R6, 0x42
            ST   R6, [R7]          ; older than HALT: must complete
            HALT                   ; valid HALT
            LDI  R6, 0xEE          ; younger than HALT: must be killed
            ST   R6, [R7]
bad:        LDI  R6, 0xBA
            ST   R6, [R7]
            HALT
