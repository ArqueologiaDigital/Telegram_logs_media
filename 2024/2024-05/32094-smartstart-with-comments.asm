EQU VAR_08 08h
EQU VAR_09 09h
EQU VAR_0A 0Ah
EQU VAR_0B 0Bh
EQU VAR_0C 0Ch
EQU VAR_0D 0Dh
EQU VAR_11 11h
EQU VAR_1E 1Eh
EQU VAR_1F 1Fh
EQU VAR_30 30h
EQU VAR_31 31h
EQU VAR_32 32h
EQU VAR_33 33h
EQU VAR_38 38h
EQU VAR_50 50h
EQU VAR_51 51h
EQU VAR_52 52h
EQU VAR_53 53h
EQU VAR_57 57h
EQU VAR_5A 5Ah
EQU VAR_5E 5Eh
EQU VAR_5F 5Fh
EQU VAR_60 60h
EQU VAR_61 61h
EQU VAR_62 62h
EQU VAR_63 63h
EQU VAR_64 64h
EQU VAR_65 65h
EQU VAR_66 66h
EQU VAR_67 67h

000: DW #000h                ; IRQ0
002: DW #000h                ; IRQ1
004: DW #000h                ; IRQ2
006: DW #000h                ; IRQ3
008: DW TIMER_0_INT_HANDLER  ; IRQ4
00a: DW #000h                ; IRQ5

ENTRY_POINT:
		LD   P2M, #0Eh
		LD   R2, #2Eh
		SRP  #F0h
		LD   R8, #04h   ; P01M = #04h  ; Ports 0 & 1 Mode
		                ;                P0 & P1: OUTPUT
		                ;                stack: internal
       
		LD   R15, #80h  ; SPL = #80h   ; Stack pointer (low-byte)
		LD   R11, #90h  ; IMR = #90h   ; Interrupt Mask Reg.
		LD   R9, #03h   ; IPR = #03h   ; Interrupt Priority Reg.
		LD   R10, #10h  ; IRQ = #10h   ; Interrupt Request Reg.
		LD   R5, #0Ch   ; PRE0 = #0Ch  ; Timer 0 Prescaler
		LD   R4, #20h   ; T0 = #20h    ; Timer/Counter 0
		LD   R1, #03h   ; TMR = #03h   ; Timer Mode
		LD   VAR_60, #0Bh
		CALL ROUTINE_67F
		CLR  VAR_5A
		SRP  #00h
		LD   R0, #FFh   ; Port 0 = FFh
		LD   R1, #7Fh   ; Port 1 = 7Fh
		AND  R2, #06h   ; Port 2 &= 06h
		JR   NZ, 007Bh
		LD   R1, #00h
		JP   LABEL_7B1


DEAD_CODE_AT_03b:
		SRP  #10h
		LD   R15, #05h
		CALL ROUTINE_668


LABEL_042:
		LD   R5, #04h
		CALL 04B2h

LABEL_047:
		LD   R1, #FFh
		LD   R14, #81h
		CALL ROUTINE_54E
		CALL 04B0h
		LD   R4, HI(JUMP_TABLE - 2)
		LD   R5, LOW(JUMP_TABLE - 2)
		LD   R6, VAR_0D
		INC  R6
058:
		ADD  R5, #02h
		DJNZ R6, 0058h
		LDC  R12, @RR4
		INC  R5
		LDC  R13, @RR4
		LD   R15, #01h
		CALL ROUTINE_668
		CLR  VAR_51
		LD   R10, #0Ah
		LD   R0, VAR_0D
		LD   R7, #00h
		JP   @RR12

LABEL_071:
		LD   R5, R0
		CALL 04BEh
		LD   VAR_0C, R0
		CALL 052Fh

07b:
		CALL 02EBh
		JR   LABEL_071

LABEL_080:
		CALL 052Fh
		CP   R12, R3
		JR   NZ, 008Fh
087:
		LD   VAR_0A, #03h
		LD   VAR_0B, #06h
		JR   LABEL_080

08f:
		CP   R11, R12
		JR   Z, 0097h
		CP   R11, R3
		JR   NZ, 009Eh
097:
		CP   R11, #02h
		JR   NZ, 009Eh
		JR   0087h

09e:
		CALL 042Ah
		CALL 04C4h
		LD   R14, #04h
0a6:
		LD   R1, #0Ch
		LD   R5, #06h
		CALL 04BEh
		CALL ROUTINE_54E
		LD   R5, VAR_0D
		CALL 04BEh
		CALL PAUSE_20
		CP   R6, VAR_0D
		JR   NZ, 00CCh
		LD   R15, #02h
		CALL ROUTINE_668
0c2:
		LD   R5, R6
		CALL 04BEh
		CALL 03CAh
		JR   LABEL_080

0cc:
		CALL 0359h
		JR   NC, 00A6h
		JR   00C2h

LABEL_0D3:
		CALL 052Fh
		LD   R5, R6
		CALL 04BEh
		CALL 02EBh
		JR   LABEL_0D3

LABEL_0E0:
		LD   VAR_51, #90h
		LD   R10, #1Eh
		CLR  R13
		LD   VAR_38, #01h
		CALL ROUTINE_384
		LD   VAR_30, R4
		LD   VAR_32, R6

0f1:
		CLR  VAR_31
		CP   VAR_32, #06h
		JR   NZ, 0123h
		LD   VAR_38, #01h
		LD   R13, #95h
		LD   R4, #1Fh
		SUB  R4, R10
101:
		INC  VAR_31
		LD   R5, R4
		SUB  R4, #06h
		JR   Z, 010Ch
		JR   NC, 0101h
10c:
		ADD  R13, #05h
		DA   R13
		DJNZ R5, 010Ch
		LD   R4, VAR_0B
		AND  R4, #07h
		CP   R4, #04h
		JR   C, 011Fh
		LD   R4, #04h
11f:
		ADD  R13, R4
		JR   0126h
123:
		LD   VAR_31, VAR_32
126:
		LD   R11, VAR_31
		ADD  R13, #01h
12b:
		DA   R13
		JR   NC, 0132h
		LD   VAR_60, #01h
132:
		CP   R11, VAR_38
		JR   Z, 013Eh
		INC  VAR_38
		ADD  R13, #30h
		JR   012Bh

13e:
		LD   R4, R13
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		JR   NZ, 0147h
		LD   R5, #0Ch
147:
		LD   VAR_63, R5
		ADD  VAR_63, #14h
		CP   R4, #00h
		JR   NZ, 0156h
		CP   VAR_60, #01h
		JR   NZ, 0158h
156:
		LD   VAR_61, R4
158:
		LD   R5, VAR_31
		LD   R4, #15h
		LD   R2, #00h
15e:
		CP   R5, #01h
		JR   Z, 016Eh
		ADD  R4, #30h
		DA   R4
		JR   NC, 016Ch
		LD   R2, #01h
16c:
		DJNZ R5, 015Eh
16e:
		CP   R13, R4
		JR   ULE, 017Dh
		CP   R2, #01h
		JR   NZ, 017Ch
		CP   VAR_60, R2
		JR   NZ, 017Dh
17c:
		INC  R11
17d:
		LD   R12, R13
		ADD  R12, VAR_30
		DA   R12
		ADD  R11, R11
		SUB  R11, #01h
		CALL 04EAh
18c:
		CP   R3, #15h
		JR   ULE, 0198h
		SUB  R3, #16h
		DA   R3
		JR   018Ch

198:
		LD   R4, #07h
		LD   R5, #A7h
		ADD  R5, R3
		LDC  R3, @RR4
		LD   R8, #03h
		LD   R9, #00h
1a4:
		LD   VAR_62, #05h
		LD   R14, #04h
		LD   R1, #64h
1ab:
		LD   @R1, #18h
		INC  R1
		DJNZ R14, 01ABh
		LD   R1, #F0h
		LD   R14, #08h
		CALL ROUTINE_54E
		LD   R2, VAR_0D
		CALL 047Ch
		CALL PAUSE_20
		CP   R3, R2
		JR   NZ, 01C9h
		CALL 0352h
		JR   01D4h

1c9:
		CALL 0359h
		JR   NC, 01A4h
		CALL 047Ah
		CALL PAUSE_60
1d4:
		CALL 03D4h
		JP   00F1h

LABEL_1DA:
		CLR  R1
		LD   R10, #10h
		LD   R14, #82h
		LD   R9, #30h
1e2:
		DJNZ R10, 01ECh
		LD   R15, #09h
		CALL ROUTINE_668
		JP   LABEL_042

1ec:
		SWAP VAR_0A
		OR   VAR_0A, #0Fh
		LD   @R9, VAR_0A
1f4:
		LD   R7, #10h
		SUB  R7, R10
		LD   R9, #2Fh
		CALL PAUSE_20
1fd:
		LD   R5, #10h
		CALL PAUSE
		INC  R9
		LD   VAR_08, @R9
		CALL 0613h
		EI   
		DJNZ R7, 01FDh
		LD   R9, #30h
		LD   R13, #10h
210:
		DEC  R13
		CALL ROUTINE_54E
		SWAP VAR_0D
		OR   VAR_0D, #0Fh
		CALL 0610h
		EI
		CP   VAR_0D, @R9
		JR   NZ, 022Ah
		INC  R9
		CP   R13, R10
		JR   NZ, 0210h
		JR   01E2h

22a:
		CALL ROUTINE_666
		LD   VAR_67, #0Bh
		JR   01F4h

LABEL_232:
		CLR  R10
		LD   R2, #01h
		CLR  R3
		LD   R14, #92h
23a:
		LD   VAR_67, #0Ah
		LD   R1, #80h
23f:
		CALL ROUTINE_54E
		JR   C, 0264h
		LD   R3, #01h
		CP   R2, R3
		JR   NZ, 024Eh
		CLR  R10
		LD   R9, #30h
24e:
		CLR  R2
		SWAP VAR_0D
		OR   VAR_0D, #0Fh
		CALL 0610h
		CP   R10, #1Fh
		JR   Z, 023Fh
		LD   @R9, VAR_0D
		INC  R9
		INC  R10
		JR   023Fh


264:
		LD   R2, #01h
		CP   R3, R2
		JR   NZ, LABEL_232
		LD   R9, #30h
		LD   R8, R10
26e:
		LD   VAR_08, @R9
		CALL SUBROUTINE_61F
		INC  R9
		DJNZ R8, 026Eh
		JR   023Ah


279:
		LD   0Bh, #50h
LABEL_27C:
		LD   R9, #00h
		LD   R8, #03h
		LD   R4, 0Bh
		LD   R3, R4
		ADD  R3, VAR_0A
		DA   R3
		JR   C, 0279h
		LD   R6, R3
		ADD  R6, VAR_0A
		DA   R6
		JR   C, 0279h
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		LD   R11, R4
		LD   R12, R5
		LD   R4, R6
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		LD   R13, R4
		LD   R2, R5
		LD   VAR_62, #1Ah
2a7:
		CALL 045Eh
		CALL 0305h
		JR   NC, 02A7h
		LD   VAR_62, #1Ah
		CALL 0458h
		CALL 03CAh
		JR   LABEL_27C


LABEL_2BA:
		LD   R3, 0Bh
		LD   R11, #00h
		LD   R12, #00h
		LD   R13, #09h
		LD   R2, #09h
2c4:
		CALL 045Eh
		LD   R9, #00h
		CALL 0305h
		JR   NC, 02D0h
		LD   R10, #01h
2d0:
		LD   R4, R5
		CP   R5, R3
		JR   C, 02E2h
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		LD   R13, R4
		LD   R2, R5
2dd:
		CALL 03D4h
		JR   02C4h
2e2:
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		LD   R11, R4
		LD   R12, R5
		JR   02DDh

2eb:
		LD   VAR_65, #0Ch
		LD   VAR_66, #0Ch
		LD   VAR_67, #0Ah
		CALL 042Ah
		LD   R1, #80h
		CALL 0305h
		JR   NC, 02EBh
		CALL 04C4h
		CALL 03CAh
		RET


305:
		LD   R14, #12h
		LD   R4, #00h
		LD   R5, #00h
		LD   R6, #00h
30d:
		CALL ROUTINE_54E
		JR   C, 0341h
		LD   R4, R5
		LD   R5, R6
		LD   R6, VAR_0D
		TCM  R7, #01h
		JR   Z, 032Bh
		LD   VAR_32, R4
		LD   VAR_33, R5
		SWAP VAR_33
		OR   VAR_33, R6
		CALL 04C8h
		JR   030Dh

32b:
		LD   VAR_62, #1Ah
		CP   R5, #00h
		JR   Z, 033Ah
		LD   VAR_63, R5
		ADD  VAR_63, #14h
		JR   033Dh

33a:
		LD   VAR_63, #02h
33d:
		LD   VAR_64, R6
		JR   030Dh

341:
		SWAP R5
		OR   R5, R6
		CP   R5, R3
		JR   NZ, 0359h
		TCM  R7, #01h
		JR   Z, 0352h
		CP   R4, R2
		JR   NZ, 0359h
352:
		LD   R15, #02h
		CALL ROUTINE_668
		SCF  
		RET

359:
		OR   R7, #04h
		CP   R0, #0Ah
		JR   NZ, 0368h
		LD   R9, #0Ah
363:
		CALL ROUTINE_666
		RCF  
		RET  

368:
		CP   R0, #06h
		JR   NZ, 0374h
		ADD  R9, #01h
		DJNZ R8, 0363h
		JR   037Bh

374:
		ADD  R9, #04h
		DJNZ R8, 0363h
		LD   R9, #0Ah
37b:
		LD   R15, #04h
		CALL ROUTINE_668
		LD   R1, #FFh
		SCF  
		RET  


ROUTINE_384:
		CALL 04B0h
		LD   R1, #81h
		LD   R14, #12h
		LD   VAR_67, #0Ah
		LD   R5, #0Ch
		LD   R6, #0Ch
392:
		CALL ROUTINE_54E
		JR   C, 03B0h
		LD   R4, R5
		LD   R5, R6
		LD   R6, VAR_0D
		LD   VAR_66, R5
		LD   VAR_67, R6
		LD   VAR_65, R4
		CP   R4, #00h
		JR   NZ, 03ABh
		LD   VAR_65, #0Dh
3ab:
		ADD  VAR_65, #0Dh
		JR   0392h

3b0:
		LD   R11, #07h
3b2:
		DJNZ R11, 03B9h
3b4:
		CALL ROUTINE_666
		JR   ROUTINE_384

3b9:
		CP   R11, R6
		JR   NZ, 03B2h
		CP   R4, #0Ch
		JR   Z, 03B4h
		SWAP R4
		OR   R4, R5
		JR   Z, 03B4h
		JR   0352h

3ca:
		CP   R15, #02h
		JR   NZ, 03D1h
		JR   03D4h

3d1:
		CALL PAUSE_60
3d4:
		CALL PAUSE_20
		SUB  VAR_51, R9
		DA   VAR_51
		DJNZ R10, 0429h
		LD   R6, #0Bh
		LD   R2, #00h
		TCM  R7, #04h
		JR   Z, 03EDh
		CLR  VAR_51
		LD   R2, #01h
		LD   R6, #0Eh
3ed:
		CALL 04B0h
		CP   R0, #0Ah
		JR   NZ, 03FEh
		CP   R15, #02h
		JR   Z, 03FEh
		DI   
		CALL 0448h
3fe:
		LD   R15, #06h
		CP   R6, #0Eh
		JR   Z, 0416h
		CP   VAR_51, #75h
		JR   NC, 0416h
		CP   VAR_51, #50h
		JR   NC, 0417h
		CP   VAR_51, #25h
		JR   NC, 0418h
		JR   0419h

416:
		INC  R15
417:
		INC  R15
418:
		INC  R15
419:
		CALL ROUTINE_668
		LD   R3, VAR_51
		CALL 04C4h
		LD   VAR_65, R6
		LD   SPL, #80h
		JP   0047h

429:
		RET


42a:
		LD   R4, R12
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		LD   VAR_61, R5
		CP   R4, #00h
		JR   NZ, 0438h
		LD   R4, #0Bh
438:
		LD   VAR_60, R4
		LD   VAR_64, R11
		RET  


43d:
		LD   R4, R3
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		ADD  R4, #14h
		LD   VAR_63, R4
		RET  


448:
		CALL 043Dh
		CP   R5, #00h
		JR   NZ, 0452h
		LD   R5, #0Ch
452:
		ADD  R5, #0Dh
		LD   VAR_64, R5
		RET  


458:
		CALL 043Dh
		LD   VAR_64, R5
		RET  


45e:
		LD   VAR_64, #0Bh
		LD   R5, #04h
		CALL 04BEh
		LD   R1, #0Ch
		LD   VAR_60, R11
		ADD  VAR_60, #0Dh
		LD   VAR_61, R12
		LD   VAR_65, R13
		ADD  VAR_65, #0Dh
		LD   VAR_66, R2
		OR   R7, #01h
		RET


47a:
		LD   R2, R3
47c:
		LD   R4, #64h
		LD   R5, #04h
480:
		LD   @R4, #0Bh
		INC  R4
		DJNZ R5, 0480h
		LD   R4, #08h
		LD   R5, #FFh
		LD   R6, #63h
48c:
		RL   R4
		INC  R5
		INC  R6
		CP   R5, R2
		JR   NZ, 048Ch
		LD   @R6, #18h
		RET  


PAUSE_60:
		; 0x6000 = 6 * 4096 = 24576 clock cycles
		; At 12.5 MHz =>  (24.576 * 10^3) / (12.5 * 10^6) ~= 1.96608 * 10-3 s ~= 2ms 
		LD   R5, #60h
PAUSE:
		LD   R4, #FFh
49c:
		DJNZ R4, 049Ch
		DJNZ R5, PAUSE
		RET  


PAUSE_20:
		LD   R5, #20h
		JR   PAUSE


SPLIT_R4_INTO_R4_R5_NIBBLES:
		LD   R5, R4
		SWAP R4
		AND  R4, #0Fh
		AND  R5, #0Fh
		RET  


4b0:
		LD   R5, #05h
4b2:
		LD   R4, #60h
		DI   
4b5:
		LD   @R4, #0Bh
		INC  R4
		CP   R4, #68h
		JR   NZ, 04B5h
4be:
		LD   VAR_62, R5
		LD   VAR_63, R5
		EI   
		RET


4c4:
		LD   VAR_32, R2
		LD   VAR_33, R3
4c8:
		SRP  #30h
		LD   R4, R3
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		LD   VAR_67, R5
		CP   R2, #00h
		JR   Z, 04DDh
		LD   VAR_65, R2
4d8:
		LD   VAR_66, R4
4da:
		SRP  #10h
		RET  

4dd:
		LD   VAR_65, #0Ch
		CP   R4, #00h
		JR   NZ, 04D8h
		LD   VAR_66, #0Bh
		JR   04DAh

4ea:
		CLR  R2
		CLR  R3
		LD   R5, R11
4f0:
		CALL 04FAh
		DJNZ R5, 04F0h
		RET

4f6:
		CLR  R2
		LD   R3, R11
4fa:
		ADD  R3, R12
		DA   R3
		JR   NC, 0503h
		ADD  R2, #01h
503:
		RET

504:
		CALL 04F6h
		LD   R4, R12
		LD   R12, R3
		LD   R3, R4
		CP   R2, #00h
		JR   NZ, 0504h
		RET

513:
		CALL 04EAh
		CP   R2, #00h
		JR   Z, 0528h
		ADD  R12, R2
		DA   R12
		AND  R12, #0Fh
		JR   NZ, 0513h
		LD   R12, #09h
		JR   0513h

528:
		LD   R4, R12
		LD   R12, R3
		LD   R3, R4
		RET

52f:
		LD   R8, #03h
		LD   R9, #00h
		LD   R12, VAR_0B
		LD   R11, VAR_0A
		LD   R6, VAR_0C
		CP   R6, #00h
		JR   Z, 04F6h
		CP   R6, #01h
		JR   Z, 0504h
		CP   R6, #02h
		JR   Z, 04EAh
		JR   0513h

LABEL_54a:
		LD   R2, #FFh
		JR   LABEL_54a

ROUTINE_54E:
		CALL ROUTINE_688
		PUSH RP
		SRP  #00h
		LD   VAR_5E, #C0h
558:
		INCW VAR_5E
		JR   Z, LABEL_54a
		CLR  R7
		LD   R8, #88h
560:
		RL   R8
		LD   R10, #7Fh
		LD   R11, #09h
566:
		RL   R10
		LD   R1, R10
		DEC  R11
		JR   Z, 0560h
		INC  R7
		CP   R7, #21h
		JR   NZ, 0578h
		CLR  R9
576:
		JR   0558h

578:
		TCM  R8, #01h
		JR   Z, 0581h
		LD   R4, R2
		JR   0585h

581:
		LD   R4, R3
		RR   R4
585:
		LD   R5, R8
		AND  R5, #0Fh
		TCM  R4, R5
		JR   Z, 0566h
		LD   R4, HI(LABEL_73D)
		LD   R5, LOW(LABEL_73D)
		LD   R12, #01h
594:
		LDC  R6, @RR4
		CP   R6, R7
		JR   Z, 059Eh
		INC  R5
		INC  R12
		JR   0594h

59e:
		CP   R12, R9
		JR   Z, 0558h
		LD   R9, R12
		LD   VAR_5E, #C0h
		CP   R9, #01h
		JR   Z, LABEL_54a
		TCM  VAR_1E, #10h
		JR   NZ, 05B8h
		CP   R9, #02h
		JR   NZ, 05B8h
		JR   05E3h

5b8:
		LD   R6, VAR_1E
		LD   R4, HI(LABEL_75A)
		LD   R5, LOW(LABEL_75A)
5be:
		INC  R5
		INC  R5
		RR   R6
		JR   NC, 05BEh
		LDC  R6, @RR4
		INC  R5
		LDC  R11, @RR4
		LD   R13, #00h
5cb:
		CP   R6, R9
		JR   Z, 05DBh
		INC  R13
		INC  R6
		DJNZ R11, 05CBh
		LD   R8, #AFh
		CALL SUBROUTINE_61F
		EI   
		JR   0576h

5db:
		TCM  VAR_1E, #80h
		JR   Z, 05E3h
		LD   VAR_5A, #01h
5e3:
		LD   R5, #80h
5e5:
		ADC  R11, @R5
		DJNZ R5, 05E5h
		ADD  R11, R5
		DA   R11
		JR   NZ, 05F1h
		LD   R11, #07h
5f1:
		ADC  R10, VAR_5F
		ADD  R10, R5
		DA   R10
		AND  R10, #0Fh
		JR   NZ, 05FFh
		LD   R10, #05h
5ff:
		ADC  R12, R11
		AND  R12, #03h
		RCF  
		CP   VAR_09, #02h
		JR   NZ, 060Bh
		SCF  
60b:
		POP  RP
		CLR  VAR_11
		RET  


610:
		LD   VAR_08, VAR_0D
613:
		CALL SUBROUTINE_61F
		SWAP VAR_08
		AND  VAR_08, #0Fh
		LD   VAR_67, VAR_08
		RET  


SUBROUTINE_61F:
		DI   
		LD   P3M, #01h
		PUSH RP
		SRP  #20h
		LD   R4, VAR_08
		CALL SPLIT_R4_INTO_R4_R5_NIBBLES
		LD   R11, R4
		LD   R12, R5
LABEL_630:
		LD   R4, HI(LABEL_764)
		LD   R5, LOW(LABEL_764)
		CP   R11, #0Fh
		JR   NZ, LABEL_63C
		POP  RP
		RET  

LABEL_63c:
		CP   R11, #00h
		JR   NZ, LABEL_648
		LD   R5, #70h
643: d6 04 9a  CALL PAUSE
646: 8b 18     JR   0660h

LABEL_648:
		LDC  R14, @RR4
		INC  R5
		LDC  R15, @RR4
		INC  R5
		DJNZ R11, LABEL_648
650:
		LD   P2, #2Eh
		LD   R5, R14
655:
		DJNZ R5, 0655h
		LD   P2, #0Eh
		LD   R5, R14
65c:
		DJNZ R5, 065Ch
		DJNZ R15, 0650h
660:
		LD   R11, R12
		LD   R12, #0Fh
		JR   LABEL_630

ROUTINE_666:
		LD   R15, #03h

ROUTINE_668:
		SRP  #00h
		LD   R7, VAR_1F ; VAR_07
		LD   R4, #07h   ; VAR_04
		LD   R5, #78h   ; VAR_05

LABEL_670:
		DJNZ R7, 068Dh
LABEL_672:
		LDC  R8, @RR4
		CALL SUBROUTINE_61F
		INC  R5
		TCM  R8, #0Fh
		JR   NZ, LABEL_672
		SRP  #10h

ROUTINE_67f:
		LD   VAR_52, #FEh
		LD   VAR_53, #60h
		LD   VAR_57, #01h

ROUTINE_688:
		LD   VAR_50, #48h
		EI   
		RET  


68d:
		LDC  R10, @RR4
		INC  R5
		TCM  R8, #0Fh
		JR   NZ, 068Dh
		JR   LABEL_670


TIMER_0_INT_HANDLER:
		PUSH RP
		SRP  #50h
		LD   P3M, #01h
		XOR  R10, #00h
		JR   NZ, LABEL_6A9
		LD   R12, #18h
		CLR  R11
		JR   06BCh
LABEL_6A9:
		CP   R11, R10
		JR   Z, LABEL_6B3
		LD   P2, #0Eh
		INC  R11
		JR   LABEL_6B8
LABEL_6B3:
		LD   P2, #2Eh
		CLR  R11
LABEL_6B8:
		DJNZ R12, 06BCh
		CLR  R10
6bc:
		PUSH P1
		LD   P1, #FFh
		LD   R4, R2
		XOR  R4, #3Fh
		AND  R4, #3Fh
		JR   Z, 06CFh
		LD   P0, R2
		JR   06DCh

6cf:
		CP   R2, #BFh
		JR   NZ, 06D9h
		LD   P3, #D0h
		JR   06DCh

6d9:
		LD   P3, #B0h
6dc:
		CP   R7, #03h
		JR   NZ, 06E5h
		LD   R5, #BDh
		JR   06F9h

6e5:
		CP   R7, #04h
		JR   NZ, 06EEh
		LD   R5, #C4h
		JR   06F9h

6ee:
		TM   R7, #01h
		JR   NZ, 06F7h
		LD   R5, #E5h
		JR   06F9h

6f7:
		LD   R5, #CBh
6f9:
		LD   R4, #07h
		ADD  R5, @R3
		LDC  R6, @RR4
		LD   R4, R2
		COM  R4
		AND  R4, VAR_11
		JR   Z, 070Fh
		CP   R0, #70h
		JR   C, 070Fh
		LD   R6, #FFh
70f:
		LD   P1, R6
		LD   R5, #01h
		CALL PAUSE
		LD   R4, #FFh
		LD   P1, R4
		LD   P0, R4
		LD   P3, R4
		CP   R3, #67h
		JR   NZ, 0731h
		INC  R0
		CP   R0, #80h
		JR   NZ, 072Bh
		LD   R0, #48h
72b:
		LD   R3, #5Fh
		LD   R2, #7Fh
		LD   R7, #00h
731:
		INC  R3
		RL   R2
		INC  R7
		POP  P1
		LD   TMR, #03h
		POP  RP
		IRET 


LABEL_73d:
		DB #10h, #0eh, #13h, #12h, #01h, #02h, #03h, #04h
		DB #0fh, #05h, #06h, #07h, #08h, #14h, #11h, #19h
		DB #1ah, #1bh, #1ch, #1dh, #1eh, #1fh, #20h, #15h
		DB #16h, #17h, #18h, #09h, #0ah

LABEL_75A:
		DB #0bh, #0ch, #03h, #0bh, #0eh

75f:           DB #0ah, #18h, #04h, #1ch, #04h

LABEL_764:
		DB #efh, #4fh, #d3h, #4fh, #bch, #55h, #b0h, #5fh
		DB #9dh, #6ah, #8bh, #75h, #7ah, #80h, #74h, #8ah
		DB #66h, #90h, #5ah, #30h
               
778:           DB #85h, #8fh, #58h, #8fh, #31h, #0fh, #35h, #31h
               DB #0fh, #35h, #65h, #3fh, #13h, #32h, #1fh, #13h
               DB #55h, #3fh, #34h, #55h, #8fh, #55h, #53h, #88h
               DB #8fh

JUMP_TABLE:
               DW LABEL_071
               DW LABEL_071
               DW LABEL_071
               DW LABEL_071
               DW LABEL_0D3
               DW LABEL_080
               DW LABEL_0E0
               DW LABEL_1DA
               DW LABEL_232
               DW LABEL_27C
               DW LABEL_2BA
               
7a7:           DB #02h, #03h, #03h, #01h, #00h, #00h
               DB #03h, #02h, #01h, #03

LABEL_7B1:
		LD   R3, #00h
		LD   R0, #00h
		JR   LABEL_7B1


7b7:           DB #00h, #00h, #03h, #02h, #01h, #01h, #ebh, #ffh
               DB #d4h, #bfh, #c0h, #ffh, #80h, #efh, #efh, #ffh
               DB #6fh, #efh, #ffh, #6fh

; font for 7seg display
; (active low)
;
;      ---a---
;     |       |
;     f       b
;     |       |
;      ---g---
;     |       |
;     e       c
;     |       |
;      ---d---
;                             -abgcdef
7cb:           DB #10h  ; 0 - 00010000
               DB #57h  ; 1 - 01010111
               DB #09h  ; 2 - 00001001
               DB #03h  ; 3 - 00000011
               DB #46h  ; 4 - 01000110
               DB #22h  ; 5 - 00100010
               DB #20h  ; 6 - 00100000
               DB #17h  ; 7 - 00010111
               DB #00h  ; 8 - 00000000
               DB #02h  ; 9 - 00000010

               ;             -abgcdef
7d5:           DB #6fh ; '-' 01101111
               DB #ffh ; ' ' 11111111
               DB #7fh ; ' ' 01111111
               DB #ffh ; ' ' 11111111
               DB #d7h ; '1' 11010111
               DB #89h ; '2' 10001001
               DB #83h ; '3' 10000011
               DB #c6h ; '4' 11000110
               DB #a2h ; '5' 10100010
               DB #a0h ; '6' 10100000
               DB #97h ; '7' 10010111
               DB #80h ' '8' 10000000
               DB #82h ' '9' 10000010
               
               ;             -abgcdef
               DB #efh ; '-' 11101111
               DB #fbh ; '_' 11111011
               DB #90h ; '0' 10010000
               DB #04h ; 'A' 00000100
               DB #75h ; ' ' 01110101
               DB #48h ; ' ' 01001000
               DB #60h ; ' ' 01100000
               DB #31h ; ' ' 00110001
               DB #22h
               DB #02h
               DB #74h
               DB #00h, #20h, #7bh, #ffh, #7fh, #ffh, #f5h, #c8h
               DB #e0h, #b1h, #a2h, #82h, #f4h, #80h, #a0h, #fbh
               DB #efh, #ffh, #84h
