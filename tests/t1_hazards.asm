; Test group 1 / traces 8.1-8.3 : forwarding, load-use stall, youngest writer
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

            LDI  R1, 0x10
            LDI  R2, 0x05
            LDI  R3, 0x30
            LDI  R4, 0x20          ; RAM address
            LDI  R5, 0x77
            ST   R5, [R4]          ; RAM[0x20] = 0x77
            NOP
            NOP
            NOP
; ---- 8.1 ALU forwarding, no stall
t81:        ADD  R1, R2            ; R1 = 0x15
            SUB  R3, R1            ; R3 = 0x30 - 0x15 = 0x1B  (R1 from EX/MEM)
            NOP
            NOP
            NOP
            LDI  R2, 0x20
            NOP
            NOP
            NOP
; ---- 8.2 load-use, exactly one bubble
t82:        LD   R1, [R2]          ; R1 = 0x77
            ADD  R3, R1            ; R3 = 0x1B + 0x77 = 0x92  (1 stall, then MEM/WB)
            NOP
            NOP
            NOP
            LDI  R1, 0x01
            LDI  R2, 0x02
            LDI  R3, 0x04
            LDI  R4, 0x21
            NOP
            NOP
            NOP
; ---- 8.3 youngest producer to a store
t83:        ADD  R1, R2            ; R1 = 0x03
            SUB  R1, R3            ; R1 = 0xFF (youngest writer)
            ST   R1, [R4]          ; RAM[0x21] = 0xFF, data from EX/MEM not MEM/WB
            NOP
            NOP
            NOP
; ---- extra: load -> store data, load -> branch, fields not read => no stall
            LDI  R2, 0x20
            LDI  R4, 0x22
            NOP
            NOP
            LD   R1, [R2]          ; R1 = 0x77
            ST   R1, [R4]          ; store data from load: 1 stall, RAM[0x22] = 0x77
            LD   R5, [R2]          ; R5 = 0x77
            LDI  R5, 0x09          ; LDI reads no register: no stall
            LD   R6, [R2]
            MOV  R6, R4            ; MOV reads only Rs (R4): no stall although Rd = R6
            LD   R1, [R2]
            NOP
            ADD  R1, R1            ; distance 2: no stall, MEM/WB forward -> 0xEE
            LD   R7, [R2]
            NOP
            NOP
            MOV  R0, R7            ; distance 3: register-file write-through -> 0x77
            LD   R2, [R4]          ; R2 = 0x77
            BNEZ R2, ok1           ; load -> branch test: 1 stall, taken
            HALT                   ; wrong path
ok1:        LDI  R7, 0x40
            ST   R0, [R7]          ; dump R0..R6 to RAM 0x40..
            ADDI R7, 1
            ST   R1, [R7]
            ADDI R7, 1
            ST   R2, [R7]
            ADDI R7, 1
            ST   R3, [R7]
            ADDI R7, 1
            ST   R4, [R7]
            ADDI R7, 1
            ST   R5, [R7]
            ADDI R7, 1
            ST   R6, [R7]
            HALT
