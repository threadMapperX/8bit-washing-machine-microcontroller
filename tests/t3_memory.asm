; Test group 3 : RAM store/load, reserved-address and peripheral isolation
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

            LDI  R1, 0xA5
            LDI  R2, 0x00
            ST   R1, [R2]          ; RAM[0x00] = A5
            LDI  R1, 0x5A
            LDI  R2, 0x7F
            ST   R1, [R2]          ; RAM[0x7F] = 5A
            LDI  R1, 0x33
            LDI  R2, 0x80
            ST   R1, [R2]          ; reserved: ignored (would alias RAM[0x00])
            LDI  R1, 0x44
            LDI  R2, 0xEF
            ST   R1, [R2]          ; reserved: ignored (would alias RAM[0x6F])
            LDI  R1, 0x55
            LDI  R2, 0xFC
            ST   R1, [R2]          ; unimplemented peripheral: ignored
            LDI  R1, 0x66
            LDI  R2, LEVEL
            ST   R1, [R2]          ; read-only WATER_LEVEL: ignored
            LDI  R1, 0x77
            LDI  R2, TCOUNT
            ST   R1, [R2]          ; read-only TIMER_COUNT: ignored
            LDI  R1, 0xC3
            LDI  R2, DISP
            ST   R1, [R2]          ; DISPLAY = C3
            LDI  R2, 0x00
            LD   R3, [R2]          ; A5
            LDI  R2, 0x7F
            LD   R4, [R2]          ; 5A
            LDI  R2, 0x80
            LD   R5, [R2]          ; 00 (reserved reads 0)
            LDI  R2, 0xEF
            LD   R6, [R2]          ; 00
            LDI  R7, 0x50
            ST   R3, [R7]          ; RAM[0x50..] = results
            ADDI R7, 1
            ST   R4, [R7]
            ADDI R7, 1
            ST   R5, [R7]
            ADDI R7, 1
            ST   R6, [R7]
            LDI  R2, 0x6F
            LD   R3, [R2]          ; 00 (EF store did not alias)
            LDI  R2, 0xFC
            LD   R4, [R2]          ; 00 (unimplemented peripheral)
            LDI  R2, LEVEL
            LD   R5, [R2]          ; sensor value (tester: 0x2A)
            LDI  R2, DISP
            LD   R6, [R2]          ; C3 readback
            ADDI R7, 1
            ST   R3, [R7]
            ADDI R7, 1
            ST   R4, [R7]
            ADDI R7, 1
            ST   R5, [R7]
            ADDI R7, 1
            ST   R6, [R7]
            HALT
