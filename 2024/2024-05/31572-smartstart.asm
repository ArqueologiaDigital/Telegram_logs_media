000: 00 00     IRQ0 Vector 0000h
002: 00 00     IRQ1 Vector 0000h
004: 00 00     IRQ2 Vector 0000h
006: 00 00     IRQ3 Vector 0000h
008: 06 97     IRQ4 Vector 0697h
00a: 00 02     IRQ5 Vector 0002h
00c: e6 f6 0e  LD   P2M, #0Eh
00f: 2c 2e     LD   R2, #2Eh
011: 31 f0     SRP  #F0h
013: 8c 04     LD   R8, #04h
015: fc 80     LD   R15, #80h
017: bc 90     LD   R11, #90h
019: 9c 03     LD   R9, #03h
01b: ac 10     LD   R10, #10h
01d: 5c 0c     LD   R5, #0Ch
01f: 4c 60     LD   R4, #60h
021: 1c 03     LD   R1, #03h
023: e6 60 0b  LD   60h, #0Bh
026: d6 06 7f  CALL 067Fh
029: f0 5a     SWAP 5Ah
02b: 31 00     SRP  #00h
02d: 0c ff     LD   R0, #FFh
02f: 1c 7f     LD   R1, #7Fh
031: 56 e2 06  AND  R2, #06h
034: eb 15     JR   NZ, 004Bh
036: 1c 00     LD   R1, #00h
038: 8d 07 b1  JP   07B1h
03b: 31 10     SRP  #10h
03d: fc 05     LD   R15, #05h
03f: d6 06 68  CALL 0668h
042: 5c 04     LD   R5, #04h
044: d6 04 b2  CALL 04B2h
047: 1c ff     LD   R1, #FFh
049: ec 81     LD   R14, #81h
04b: d6 05 4e  CALL 054Eh
04e: d6 04 b0  CALL 04B0h
051: 4c 07     LD   R4, #07h
053: 5c 8f     LD   R5, #8Fh
055: 68 0d     LD   R6, 0Dh
057: 6e        INC  R6
058: 06 e5 02  ADD  R5, #02h
05b: 6a fb     DJNZ R6, 0058h
05d: c2 c4     LDC  R12, @RR4
05f: 5f        Illegal
060: c2 d4     LDC  R13, @RR4
062: fc 01     LD   R15, #01h
064: d6 06 68  CALL 0668h
067: b2 51     XOR  R5, R1
069: ac 0a     LD   R10, #0Ah
06b: 08 0d     LD   R0, 0Dh
06d: 7c 00     LD   R7, #00h
06f: 30 ec     JP   @RR12
071: 58 e0     LD   R5, R0
073: d6 04 be  CALL 04BEh
076: 09 0c     LD   0Ch, R0
078: d6 05 2f  CALL 052Fh
07b: d6 8a eb  CALL 8AEBh
07e: 8b f1     JR   0071h
080: d6 05 2f  CALL 052Fh
083: a2 c3     CP   R12, R3
085: eb 08     JR   NZ, 008Fh
087: e6 0a 03  LD   0Ah, #03h
08a: e6 0b 06  LD   0Bh, #06h
08d: 8b f1     JR   0080h
08f: a2 bc     CP   R11, R12
091: 6b 04     JR   Z, 0097h
093: a2 b3     CP   R11, R3
095: eb 07     JR   NZ, 009Eh
097: a7 eb 03  CP   @R11, #03h
09a: eb 02     JR   NZ, 009Eh
09c: 8b e9     JR   0087h
09e: d6 04 2a  CALL 042Ah
0a1: d6 06 c4  CALL 06C4h
0a4: ec 04     LD   R14, #04h
0a6: 1c 0c     LD   R1, #0Ch
0a8: 5c 06     LD   R5, #06h
0aa: d6 04 be  CALL 04BEh
0ad: d6 05 4e  CALL 054Eh
0b0: 58 0d     LD   R5, 0Dh
0b2: d6 04 be  CALL 04BEh
0b5: d6 04 a1  CALL 04A1h
0b8: a4 0d e6  CP   R6, 0Dh
0bb: eb 0f     JR   NZ, 00CCh
0bd: fc 02     LD   R15, #02h
0bf: d6 06 68  CALL 0668h
0c2: 58 e6     LD   R5, R6
0c4: d6 04 be  CALL 04BEh
0c7: d6 03 ca  CALL 03CAh
0ca: 8b b4     JR   0080h
0cc: d6 03 59  CALL 0359h
0cf: fb d5     JR   NC, 00A6h
0d1: 8b ff     JR   00D2h
0d3: d6 05 2f  CALL 052Fh
0d6: d8 e6     LD   R13, R6
0d8: d6 04 be  CALL 04BEh
0db: d6 02 eb  CALL 02EBh
0de: 8b f3     JR   00D3h
0e0: e7 51 90  LD   @51h, #90h
0e3: ac 1e     LD   R10, #1Eh
0e5: b0 ed     CLR  R13
0e7: e6 38 01  LD   38h, #01h
0ea: d6 03 84  CALL 0384h
0ed: 49 30     LD   30h, R4
0ef: 69 32     LD   32h, R6
0f1: b0 31     CLR  31h
0f3: a6 32 06  CP   32h, #06h
0f6: eb 2b     JR   NZ, 0123h
0f8: e6 38 01  LD   38h, #01h
0fb: dc 95     LD   R13, #95h
0fd: 4c 1f     LD   R4, #1Fh
0ff: 22 4a     SUB  R4, R10
101: 20 31     INC  31h
103: 58 e4     LD   R5, R4
105: 26 e4 06  SUB  R4, #06h
108: 6b 02     JR   Z, 010Ch
10a: fb f5     JR   NC, 0101h
10c: 06 ef 05  ADD  R15, #05h
10f: 40 ed     DA   R13
111: 5a f9     DJNZ R5, 010Ch
113: 48 0b     LD   R4, 0Bh
115: 56 e4 07  AND  R4, #07h
118: a6 e6 04  CP   R6, #04h
11b: 7b 02     JR   C, 011Fh
11d: 4c 04     LD   R4, #04h
11f: 02 d4     ADD  R13, R4
121: 8b 03     JR   0126h
123: e4 32 31  LD   31h, 32h
126: b8 31     LD   R11, 31h
128: 06 ed 01  ADD  R13, #01h
12b: 40 ed     DA   R13
12d: fb 03     JR   NC, 0132h
12f: e6 60 01  LD   60h, #01h
132: a4 38 eb  CP   R11, 38h
135: 6b 07     JR   Z, 013Eh
137: 20 38     INC  38h
139: 06 ed 30  ADD  R13, #30h
13c: 8b ef     JR   012Dh
13e: 48 fd     LD   R4, RP
140: d6 04 a5  CALL 04A5h
143: eb 02     JR   NZ, 0147h
145: 5c 0c     LD   R5, #0Ch
147: 59 63     LD   63h, R5
149: 06 63 14  ADD  63h, #14h
14c: a6 e4 00  CP   R4, #00h
14f: eb 45     JR   NZ, 0196h
151: a6 60 01  CP   60h, #01h
154: eb 02     JR   NZ, 0158h
156: 49 61     LD   61h, R4
158: 58 31     LD   R5, 31h
15a: 4c 15     LD   R4, #15h
15c: 2c 00     LD   R2, #00h
15e: a6 e5 01  CP   R5, #01h
161: 6b 0b     JR   Z, 016Eh
163: 06 e4 30  ADD  R4, #30h
166: 40 e4     DA   R4
168: fb 02     JR   NC, 016Ch
16a: 2c 01     LD   R2, #01h
16c: 5a f0     DJNZ R5, 015Eh
16e: a2 d4     CP   R13, R4
170: 3b 0b     JR   ULE, 017Dh
172: a6 e2 01  CP   R2, #01h
175: eb 05     JR   NZ, 017Ch
177: a4 e2 60  CP   60h, R2
17a: eb 01     JR   NZ, 017Dh
17c: be        INC  R11
17d: e8 ed     LD   R14, R13
17f: 06 30 ec  ADD  30h, #ECh
182: 40 ec     DA   R12
184: 02 bb     ADD  R11, R11
186: 26 eb 01  SUB  R11, #01h
189: d6 04 ea  CALL 04EAh
18c: a6 e3 15  CP   R3, #15h
18f: 3b 07     JR   ULE, 0198h
191: 26 e3 16  SUB  R3, #16h
194: 40 e3     DA   R3
196: 8b f4     JR   018Ch
198: 4c 07     LD   R4, #07h
19a: 5c a7     LD   R5, #A7h
19c: 02 5b     ADD  R5, R11
19e: c2 34     LDC  R3, @RR4
1a0: 8c 03     LD   R8, #03h
1a2: 9c 40     LD   R9, #40h
1a4: e6 e2 05  LD   R2, #05h
1a7: ec 04     LD   R14, #04h
1a9: 1c 64     LD   R1, #64h
1ab: e7 e1 18  LD   @R1, #18h
1ae: 1e        INC  R1
1af: ea fa     DJNZ R14, 01ABh
1b1: 1c f0     LD   R1, #F0h
1b3: ec 08     LD   R14, #08h
1b5: d6 05 4e  CALL 054Eh
1b8: 28 0d     LD   R2, 0Dh
1ba: d6 04 7c  CALL 047Ch
1bd: d6 04 a1  CALL 04A1h
1c0: a2 32     CP   R3, R2
1c2: eb 05     JR   NZ, 01C9h
1c4: d6 03 52  CALL 0352h
1c7: 8b 0b     JR   01D4h
1c9: d6 03 59  CALL 0359h
1cc: fb d6     JR   NC, 01A4h
1ce: d6 04 7a  CALL 047Ah
1d1: d6 14 98  CALL 1498h
1d4: d6 03 d4  CALL 03D4h
1d7: 8d 00 f1  JP   00F1h
1da: b0 e1     CLR  R1
1dc: ac 10     LD   R10, #10h
1de: ec 82     LD   R14, #82h
1e0: 9c 30     LD   R9, #30h
1e2: aa 08     DJNZ R10, 01ECh
1e4: fc 09     LD   R15, #09h
1e6: d6 06 68  CALL 0668h
1e9: 8d 00 42  JP   0042h
1ec: f0 0a     SWAP 0Ah
1ee: 56 0a 0f  AND  0Ah, #0Fh
1f1: f5 0a e9  LD   @R9, 0Ah
1f4: 7c 10     LD   R7, #10h
1f6: 22 7a     SUB  R7, R10
1f8: 9c 2f     LD   R9, #2Fh
1fa: d6 04 a1  CALL 04A1h
1fd: 5c 10     LD   R5, #10h
1ff: d6 04 9a  CALL 049Ah
202: 9e        INC  R9
203: e5 e9 08  LD   08h, @R9
206: d6 06 13  CALL 0613h
209: 9f        EI   
20a: 7a f1     DJNZ R7, 01FDh
20c: 9c 30     LD   R9, #30h
20e: dc 10     LD   R13, #10h
210: 00 fd     DEC  RP
212: d6 05 4e  CALL 054Eh
215: f4        Illegal
216: 0d 46 0d  JP   F, 460Dh
219: 0f        Illegal
21a: d6 06 10  CALL 0610h
21d: 9f        EI   
21e: a5 e9 0d  CP   0Dh, @R9
221: eb 07     JR   NZ, 022Ah
223: 9e        INC  R9
224: a2 da     CP   R13, R10
226: fb e8     JR   NC, 0210h
228: 8b b8     JR   01E2h
22a: d6 06 66  CALL 0666h
22d: e6 67 0b  LD   67h, #0Bh
230: 8b c2     JR   01F4h
232: b0 ea     CLR  R10
234: 2c 01     LD   R2, #01h
236: b0 e3     CLR  R3
238: ec 92     LD   R14, #92h
23a: e6 67 0a  LD   67h, #0Ah
23d: 1e        INC  R1
23e: 80 d6     DECW D6h
240: 05 4e 7b  ADD  7Bh, @4Eh
243: 20 3c     INC  3Ch
245: 01 a2     DEC  @A2h
247: 23 eb     SUB  R14, @R11
249: 04 b0 ea  ADD  R10, B0h
24c: 9c 30     LD   R9, #30h
24e: b0 e2     CLR  R2
250: f0 0d     SWAP 0Dh
252: 46 0d 0f  OR   0Dh, #0Fh
255: d6 06 10  CALL 0610h
258: a6 ea 1f  CP   R10, #1Fh
25b: 6b e2     JR   Z, 023Fh
25d: f5 0d e9  LD   @R9, 0Dh
260: 9e        INC  R9
261: ae        INC  R10
262: 8b db     JR   023Fh
264: 2c 01     LD   R2, #01h
266: a2 32     CP   R3, R2
268: eb c8     JR   NZ, 0232h
26a: 9c 30     LD   R9, #30h
26c: 88 ea     LD   R8, R10
26e: e5 e9 08  LD   08h, @R9
271: d6 06 1f  CALL 061Fh
274: 9e        INC  R9
275: 8b f7     JR   026Eh
277: 8b c1     JR   023Ah
279: e6 0b 50  LD   0Bh, #50h
27c: 9c 00     LD   R9, #00h
27e: 8c 03     LD   R8, #03h
280: 48 0b     LD   R4, 0Bh
282: 38 e4     LD   R3, R4
284: 04 0a e3  ADD  R3, 0Ah
287: 40 e3     DA   R3
289: 7b ee     JR   C, 0279h
28b: 6a e3     DJNZ R6, 0270h
28d: 04 0a e6  ADD  R6, 0Ah
290: 40 e6     DA   R6
292: 7b e5     JR   C, 0279h
294: d6 04 a5  CALL 04A5h
297: b8 e4     LD   R11, R4
299: c8 e5     LD   R12, R5
29b: 48 e6     LD   R4, R6
29d: d6 04 a5  CALL 04A5h
2a0: d8 e4     LD   R13, R4
2a2: 28 e5     LD   R2, R5
2a4: e6 62 1a  LD   62h, #1Ah
2a7: d6 04 5e  CALL 045Eh
2aa: d6 03 05  CALL 0305h
2ad: fb f8     JR   NC, 02A7h
2af: e6 62 1a  LD   62h, #1Ah
2b2: d6 04 58  CALL 0458h
2b5: d6 03 ca  CALL 03CAh
2b8: 8b c2     JR   027Ch
2ba: 38 0b     LD   R3, 0Bh
2bc: bc 00     LD   R11, #00h
2be: cc 00     LD   R12, #00h
2c0: dc 09     LD   R13, #09h
2c2: 2c 09     LD   R2, #09h
2c4: d6 04 5e  CALL 045Eh
2c7: 9c 00     LD   R9, #00h
2c9: d6 03 05  CALL 0305h
2cc: fb 02     JR   NC, 02D0h
2ce: ac 01     LD   R10, #01h
2d0: 48 e5     LD   R4, R5
2d2: a2 53     CP   R5, R3
2d4: 7b 0c     JR   C, 02E2h
2d6: d6 04 a5  CALL 04A5h
2d9: d8 e4     LD   R13, R4
2db: 28 e5     LD   R2, R5
2dd: d6 03 d4  CALL 03D4h
2e0: 8b e2     JR   02C4h
2e2: d6 04 a5  CALL 04A5h
2e5: b8 e4     LD   R11, R4
2e7: c8 e5     LD   R12, R5
2e9: 8b f2     JR   02DDh
2eb: e6 65 0c  LD   65h, #0Ch
2ee: e6 66 4c  LD   66h, #4Ch
2f1: e6 67 0a  LD   67h, #0Ah
2f4: d6 04 2a  CALL 042Ah
2f7: 1c 80     LD   R1, #80h
2f9: d6 03 05  CALL 0305h
2fc: fb ed     JR   NC, 02EBh
2fe: d6 04 c4  CALL 04C4h
301: d6 03 ca  CALL 03CAh
304: af        RET  
305: ec 12     LD   R14, #12h
307: 4c 00     LD   R4, #00h
309: 5c 00     LD   R5, #00h
30b: 6c 00     LD   R6, #00h
30d: d6 05 4e  CALL 054Eh
310: 7b 2f     JR   C, 0341h
312: 48 e5     LD   R4, R5
314: 58 e6     LD   R5, R6
316: 68 0d     LD   R6, 0Dh
318: 66 e7 01  TCM  R7, #01h
31b: 6b 0e     JR   Z, 032Bh
31d: 4d 32 59  JP   OV, 3259h
320: 33 f0     SBC  R15, @R0
322: 33 44     SBC  R4, @R4
324: e6 33 d6  LD   33h, #D6h
327: 04 c8 8b  ADD  8Bh, C8h
32a: e2        Illegal
32b: e6 62 1a  LD   62h, #1Ah
32e: a6 e5 00  CP   R5, #00h
331: 6b 07     JR   Z, 033Ah
333: 59 63     LD   63h, R5
335: 06 63 14  ADD  63h, #14h
338: 8b 03     JR   033Dh
33a: e6 63 02  LD   63h, #02h
33d: 69 64     LD   64h, R6
33f: 8b cc     JR   030Dh
341: f0 e5     SWAP R5
343: 42 56     OR   R5, R6
345: a2 53     CP   R5, R3
347: eb 10     JR   NZ, 0359h
349: 66 e7 01  TCM  R7, #01h
34c: 6b 04     JR   Z, 0352h
34e: a2 42     CP   R4, R2
350: eb 07     JR   NZ, 0359h
352: fc 02     LD   R15, #02h
354: d6 06 68  CALL 0668h
357: df        SCF  
358: af        RET  
359: 46 e7 04  OR   R7, #04h
35c: e6 e0 0a  LD   R0, #0Ah
35f: eb 07     JR   NZ, 0368h
361: 9c 0a     LD   R9, #0Ah
363: d6 06 66  CALL 0666h
366: cf        RCF  
367: af        RET  
368: a6 e0 0e  CP   R0, #0Eh
36b: fb 07     JR   NC, 0374h
36d: 06 e9 01  ADD  R9, #01h
370: 8a f1     DJNZ R8, 0363h
372: 8b 07     JR   037Bh
374: 06 e9 04  ADD  R9, #04h
377: 8a ea     DJNZ R8, 0363h
379: 9c 0a     LD   R9, #0Ah
37b: fc 04     LD   R15, #04h
37d: d6 06 68  CALL 0668h
380: 1c ff     LD   R1, #FFh
382: df        SCF  
383: af        RET  
384: d6 04 b0  CALL 04B0h
387: 1c 80     LD   R1, #80h
389: ec 12     LD   R14, #12h
38b: e6 67 0a  LD   67h, #0Ah
38e: 5c 0d     LD   R5, #0Dh
390: 6c 0c     LD   R6, #0Ch
392: d6 05 4e  CALL 054Eh
395: 7b 19     JR   C, 03B0h
397: 48 e5     LD   R4, R5
399: 58 e6     LD   R5, R6
39b: 68 0d     LD   R6, 0Dh
39d: 59 66     LD   66h, R5
39f: 69 67     LD   67h, R6
3a1: 49 65     LD   65h, R4
3a3: a6 e4 00  CP   R4, #00h
3a6: eb 03     JR   NZ, 03ABh
3a8: e6 65 0d  LD   65h, #0Dh
3ab: 06 65 0d  ADD  65h, #0Dh
3ae: 8b e2     JR   0392h
3b0: bc 07     LD   R11, #07h
3b2: ba 05     DJNZ R11, 03B9h
3b4: d6 06 66  CALL 0666h
3b7: 8b cb     JR   0384h
3b9: a2 b6     CP   R11, R6
3bb: eb f5     JR   NZ, 03B2h
3bd: a6 e4 0c  CP   R4, #0Ch
3c0: 6b f2     JR   Z, 03B4h
3c2: f0 e4     SWAP R4
3c4: 42 45     OR   R4, R5
3c6: 6b ec     JR   Z, 03B4h
3c8: 8b 88     JR   0352h
3ca: a6 ef 02  CP   R15, #02h
3cd: eb 02     JR   NZ, 03D1h
3cf: 8b 03     JR   03D4h
3d1: d6 04 98  CALL 0498h
3d4: d6 04 a1  CALL 04A1h
3d7: 24 e9 51  SUB  51h, R9
3da: 40 51     DA   51h
3dc: aa 4b     DJNZ R10, 0429h
3de: 6c 0b     LD   R6, #0Bh
3e0: 2c 00     LD   R2, #00h
3e2: 66 e7 04  TCM  R7, #04h
3e5: 6b 06     JR   Z, 03EDh
3e7: b0 51     CLR  51h
3e9: 2c 01     LD   R2, #01h
3eb: 6c 0e     LD   R6, #0Eh
3ed: d6 04 b0  CALL 04B0h
3f0: a6 e0 0a  CP   R0, #0Ah
3f3: eb 09     JR   NZ, 03FEh
3f5: a6 ef 02  CP   R15, #02h
3f8: 6b 04     JR   Z, 03FEh
3fa: 8f        DI   
3fb: d6 04 48  CALL 0448h
3fe: fc 06     LD   R15, #06h
400: a6 e6 0e  CP   R6, #0Eh
403: 6b 11     JR   Z, 0416h
405: a6 51 75  CP   51h, #75h
408: fb 0c     JR   NC, 0416h
40a: a6 59 50  CP   59h, #50h
40d: fb 08     JR   NC, 0417h
40f: a6 51 25  CP   51h, #25h
412: fb 04     JR   NC, 0418h
414: 8b 03     JR   0419h
416: ff        NOP  
417: fe        INC  R15
418: fe        INC  R15
419: d6 06 68  CALL 0668h
41c: 38 51     LD   R3, 51h
41e: d6 04 c4  CALL 04C4h
421: 69 65     LD   65h, R6
423: e6 ff 80  LD   SPL, #80h
426: 8d 00 47  JP   0047h
429: af        RET  
42a: 48 ec     LD   R4, R12
42c: d6 04 a5  CALL 04A5h
42f: 59 61     LD   61h, R5
431: a6 e4 00  CP   R4, #00h
434: eb 02     JR   NZ, 0438h
436: 4c 0b     LD   R4, #0Bh
438: 49 60     LD   60h, R4
43a: b9 64     LD   64h, R11
43c: af        RET  
43d: 48 e3     LD   R4, R3
43f: d6 04 a5  CALL 04A5h
442: 06 e4 14  ADD  R4, #14h
445: 49 63     LD   63h, R4
447: af        RET  
448: d6 04 3d  CALL 043Dh
44b: a6 e5 00  CP   R5, #00h
44e: eb 02     JR   NZ, 0452h
450: 5c 0c     LD   R5, #0Ch
452: 06 e5 0d  ADD  R5, #0Dh
455: 59 64     LD   64h, R5
457: af        RET  
458: d6 04 3d  CALL 043Dh
45b: 79 64     LD   64h, R7
45d: af        RET  
45e: e6 64 0b  LD   64h, #0Bh
461: 5c 04     LD   R5, #04h
463: d6 04 be  CALL 04BEh
466: 1c 0c     LD   R1, #0Ch
468: b9 60     LD   60h, R11
46a: 06 68 0d  ADD  68h, #0Dh
46d: c9 61     LD   61h, R12
46f: d9 65     LD   65h, R13
471: 06 65 0d  ADD  65h, #0Dh
474: 29 66     LD   66h, R2
476: 46 ef 01  OR   R15, #01h
479: af        RET  
47a: 28 e3     LD   R2, R3
47c: 4c 64     LD   R4, #64h
47e: 5c 04     LD   R5, #04h
480: e7 e4 0b  LD   @R4, #0Bh
483: 4e        INC  R4
484: 5a fa     DJNZ R5, 0480h
486: 4c 08     LD   R4, #08h
488: 5c ff     LD   R5, #FFh
48a: 6c 63     LD   R6, #63h
48c: 90 e4     RL   R4
48e: 5e        INC  R5
48f: 6e        INC  R6
490: a2 52     CP   R5, R2
492: eb f8     JR   NZ, 048Ch
494: e7 e6 18  LD   @R6, #18h
497: af        RET  
498: 5c 60     LD   R5, #60h
49a: 4c ff     LD   R4, #FFh
49c: 4a fe     DJNZ R4, 049Ch
49e: 5a fa     DJNZ R5, 049Ah
4a0: af        RET  
4a1: 5c 20     LD   R5, #20h
4a3: 8b f5     JR   049Ah
4a5: 58 e4     LD   R5, R4
4a7: f0 e4     SWAP R4
4a9: 56 e4 0f  AND  R4, #0Fh
4ac: 56 e5 0f  AND  R5, #0Fh
4af: af        RET  
4b0: 5c 05     LD   R5, #05h
4b2: 4c 60     LD   R4, #60h
4b4: 8f        DI   
4b5: e7 e4 0b  LD   @R4, #0Bh
4b8: 4e        INC  R4
4b9: a6 e4 78  CP   R4, #78h
4bc: eb f7     JR   NZ, 04B5h
4be: 59 62     LD   62h, R5
4c0: 59 63     LD   63h, R5
4c2: 9f        EI   
4c3: af        RET  
4c4: 29 32     LD   32h, R2
4c6: 39 33     LD   33h, R3
4c8: 31 30     SRP  #30h
4ca: 48 e3     LD   R4, R3
4cc: d6 04 a5  CALL 04A5h
4cf: 59 77     LD   77h, R5
4d1: a6 e2 00  CP   R2, #00h
4d4: 6b 07     JR   Z, 04DDh
4d6: 29 65     LD   65h, R2
4d8: 49 66     LD   66h, R4
4da: 31 10     SRP  #10h
4dc: af        RET  
4dd: e6 65 0c  LD   65h, #0Ch
4e0: a6 e4 00  CP   R4, #00h
4e3: eb f3     JR   NZ, 04D8h
4e5: e6 66 0b  LD   66h, #0Bh
4e8: 8b f0     JR   04DAh
4ea: b0 e2     CLR  R2
4ec: b0 e3     CLR  R3
4ee: 58 eb     LD   R5, R11
4f0: d6 04 fa  CALL 04FAh
4f3: 5a fb     DJNZ R5, 04F0h
4f5: af        RET  
4f6: b0 e2     CLR  R2
4f8: 38 eb     LD   R3, R11
4fa: 02 3c     ADD  R3, R12
4fc: 40 e3     DA   R3
4fe: fb 03     JR   NC, 0503h
500: 06 e2 01  ADD  R2, #01h
503: af        RET  
504: d6 24 f6  CALL 24F6h
507: 48 ec     LD   R4, R12
509: c8 e3     LD   R12, R3
50b: 38 e4     LD   R3, R4
50d: a6 e2 00  CP   R2, #00h
510: eb f2     JR   NZ, 0504h
512: af        RET  
513: d6 04 ea  CALL 04EAh
516: e6 e2 00  LD   R2, #00h
519: 6b 0d     JR   Z, 0528h
51b: 02 c2     ADD  R12, R2
51d: 40 ec     DA   R12
51f: 56 ec 0f  AND  R12, #0Fh
522: eb ef     JR   NZ, 0513h
524: cc 09     LD   R12, #09h
526: 8b eb     JR   0513h
528: 48 ec     LD   R4, R12
52a: c8 e3     LD   R12, R3
52c: 38 e4     LD   R3, R4
52e: af        RET  
52f: 8c 03     LD   R8, #03h
531: 9c 00     LD   R9, #00h
533: c8 0b     LD   R12, 0Bh
535: b8 0a     LD   R11, 0Ah
537: 68 0c     LD   R6, 0Ch
539: a6 e6 00  CP   R6, #00h
53c: 6b b8     JR   Z, 04F6h
53e: a6 e6 01  CP   R6, #01h
541: 6b c1     JR   Z, 0504h
543: a6 e6 02  CP   R6, #02h
546: 6b a2     JR   Z, 04EAh
548: 8b c9     JR   0513h
54a: 2c ff     LD   R2, #FFh
54c: 9b fc     JR   GE, 054Ah
54e: d6 06 88  CALL 0688h
551: 70 fd     PUSH RP
553: 31 00     SRP  #00h
555: e6 5e c0  LD   5Eh, #C0h
558: a0 5e     INCW 5Eh
55a: 6b ee     JR   Z, 054Ah
55c: b0 e7     CLR  R7
55e: 8c 88     LD   R8, #88h
560: 90 e8     RL   R8
562: ac 7f     LD   R10, #7Fh
564: fc 09     LD   R15, #09h
566: 90 ea     RL   R10
568: 18 ea     LD   R1, R10
56a: 00 eb     DEC  R11
56c: 6b f2     JR   Z, 0560h
56e: 7e        INC  R7
56f: a6 e7 61  CP   R7, #61h
572: eb 04     JR   NZ, 0578h
574: b0 e9     CLR  R9
576: 8b e0     JR   0558h
578: 67 e8 01  TCM  @R8, #01h
57b: 6b 04     JR   Z, 0581h
57d: 48 e2     LD   R4, R2
57f: 8b 04     JR   0585h
581: 48 e3     LD   R4, R3
583: e0 e4     RR   R4
585: 58 e8     LD   R5, R8
587: 56 e5 0f  AND  R5, #0Fh
58a: 62 45     TCM  R4, R5
58c: 6b d8     JR   Z, 0566h
58e: 4c 07     LD   R4, #07h
590: 5c 3d     LD   R5, #3Dh
592: cc 01     LD   R12, #01h
594: c2 64     LDC  R6, @RR4
596: a2 67     CP   R6, R7
598: 6b 04     JR   Z, 059Eh
59a: 5e        INC  R5
59b: ce        INC  R12
59c: 8b f6     JR   0594h
59e: a2 c9     CP   R12, R9
5a0: 6b b6     JR   Z, 0558h
5a2: 98 ec     LD   R9, R12
5a4: e6 5e c0  LD   5Eh, #C0h
5a7: a6 e9 01  CP   R9, #01h
5aa: 6b 9e     JR   Z, 054Ah
5ac: 66 1e 10  TCM  1Eh, #10h
5af: eb 07     JR   NZ, 05B8h
5b1: a6 e9 02  CP   R9, #02h
5b4: eb 02     JR   NZ, 05B8h
5b6: 8b 3b     JR   05F3h
5b8: 68 1e     LD   R6, 1Eh
5ba: 4c 07     LD   R4, #07h
5bc: 5c 5a     LD   R5, #5Ah
5be: 5e        INC  R5
5bf: 5e        INC  R5
5c0: e0 e6     RR   R6
5c2: fb fa     JR   NC, 05BEh
5c4: c2 64     LDC  R6, @RR4
5c6: 5e        INC  R5
5c7: c2 b4     LDC  R11, @RR4
5c9: dc 00     LD   R13, #00h
5cb: a2 69     CP   R6, R9
5cd: 6b 0c     JR   Z, 05DBh
5cf: de        INC  R13
5d0: 6e        INC  R6
5d1: ba f8     DJNZ R11, 05CBh
5d3: 8c af     LD   R8, #AFh
5d5: d6 06 1f  CALL 061Fh
5d8: 9f        EI   
5d9: 8b 9b     JR   0576h
5db: 66 1e 80  TCM  1Eh, #80h
5de: 6b 03     JR   Z, 05E3h
5e0: e6 5a 01  LD   5Ah, #01h
5e3: 5c 80     LD   R5, #80h
5e5: 33 b5     SBC  R11, @R5
5e7: 5a fc     DJNZ R5, 05E5h
5e9: 22 b5     SUB  R11, R5
5eb: 40 eb     DA   R11
5ed: eb 02     JR   NZ, 05F1h
5ef: bc 07     LD   R11, #07h
5f1: 14 5f ea  ADC  R10, 5Fh
5f4: 02 a5     ADD  R10, R5
5f6: 40 ea     DA   R10
5f8: 56 ea 0f  AND  R10, #0Fh
5fb: eb 02     JR   NZ, 05FFh
5fd: ac 05     LD   R10, #05h
5ff: 12 cb     ADC  R12, R11
601: 56 ec 03  AND  R12, #03h
604: cf        RCF  
605: a6 09 02  CP   09h, #02h
608: eb 01     JR   NZ, 060Bh
60a: df        SCF  
60b: 50 fd     POP  RP
60d: b0 11     CLR  11h
60f: af        RET  
610: e4 0d 08  LD   08h, 0Dh
613: d6 06 1f  CALL 061Fh
616: f0 08     SWAP 08h
618: 56 08 0f  AND  08h, #0Fh
61b: e4 28 67  LD   67h, 28h
61e: af        RET  
61f: 8f        DI   
620: e6 f7 01  LD   P3M, #01h
623: 70 fd     PUSH RP
625: 73 20     TM   R2, @R0
627: 48 08     LD   R4, 08h
629: d6 04 a5  CALL 04A5h
62c: b8 e4     LD   R11, R4
62e: c8 e5     LD   R12, R5
630: 4c 07     LD   R4, #07h
632: 5c 64     LD   R5, #64h
634: a6 eb 0f  CP   R11, #0Fh
637: eb 03     JR   NZ, 063Ch
639: 50 fd     POP  RP
63b: af        RET  
63c: a6 eb 00  CP   R11, #00h
63f: eb 07     JR   NZ, 0648h
641: 5c 70     LD   R5, #70h
643: d6 04 9a  CALL 049Ah
646: 8b 1a     JR   0662h
648: c2 e4     LDC  R14, @RR4
64a: 5e        INC  R5
64b: c2 f4     LDC  R15, @RR4
64d: 5e        INC  R5
64e: ba f8     DJNZ R11, 0648h
650: e6 02 2e  LD   P2, #2Eh
653: 58 ee     LD   R5, R14
655: 5a fe     DJNZ R5, 0655h
657: e6 02 0e  LD   P2, #0Eh
65a: 58 ee     LD   R5, R14
65c: 5a fe     DJNZ R5, 065Ch
65e: fa f0     DJNZ R15, 0650h
660: b8 ec     LD   R11, R12
662: cc 0f     LD   R12, #0Fh
664: 8b ca     JR   0630h
666: fc 03     LD   R15, #03h
668: 31 00     SRP  #00h
66a: 78 1f     LD   R7, 1Fh
66c: 4e        INC  R4
66d: 07 5c 78  ADD  @5Ch, #78h
670: 7a 1b     DJNZ R7, 068Dh
672: c2 85     LDC  R8, @RR5
674: d6 06 1f  CALL 061Fh
677: 5e        INC  R5
678: 66 e8 0f  TCM  R8, #0Fh
67b: eb f7     JR   NZ, 0674h
67d: 31 10     SRP  #10h
67f: e6 52 fe  LD   52h, #FEh
682: e6 53 60  LD   53h, #60h
685: e6 57 01  LD   57h, #01h
688: e6 50 48  LD   50h, #48h
68b: 9f        EI   
68c: af        RET  
68d: c2 84     LDC  R8, @RR4
68f: 5e        INC  R5
690: 66 e8 0f  TCM  R8, #0Fh
693: eb f8     JR   NZ, 068Dh
695: 8b d9     JR   0670h
697: 70 fd     PUSH RP
699: 31 50     SRP  #50h
69b: e6 f7 01  LD   P3M, #01h
69e: b6 ea 00  XOR  R10, #00h
6a1: eb 06     JR   NZ, 06A9h
6a3: cc 18     LD   R12, #18h
6a5: b0 eb     CLR  R11
6a7: 8b 13     JR   06BCh
6a9: a2 ba     CP   R11, R10
6ab: 6b 06     JR   Z, 06B3h
6ad: e6 02 0e  LD   P2, #0Eh
6b0: be        INC  R11
6b1: 8b 05     JR   06B8h
6b3: e6 06 2e  LD   06h, #2Eh
6b6: b0 eb     CLR  R11
6b8: ca 02     DJNZ R12, 06BCh
6ba: b0 ea     CLR  R10
6bc: 71 41     PUSH @41h
6be: e6 01 ff  LD   P1, #FFh
6c1: 49 e2     LD   R2, R4
6c3: b6 e4 3f  XOR  R4, #3Fh
6c6: 56 e4 3f  AND  R4, #3Fh
6c9: 6b 04     JR   Z, 06CFh
6cb: 29 03     LD   P3, R2
6cd: 8b 0d     JR   06DCh
6cf: a6 e2 bf  CP   R2, #BFh
6d2: eb 05     JR   NZ, 06D9h
6d4: e6 03 d0  LD   P3, #D0h
6d7: 8b 03     JR   06DCh
6d9: e6 03 b0  LD   P3, #B0h
6dc: a6 e7 03  CP   R7, #03h
6df: eb 04     JR   NZ, 06E5h
6e1: 5c bd     LD   R5, #BDh
6e3: 8b 16     JR   06FBh
6e5: a6 e7 04  CP   R7, #04h
6e8: eb 04     JR   NZ, 06EEh
6ea: 5c c4     LD   R5, #C4h
6ec: 8b 0b     JR   06F9h
6ee: 76 e7 01  TM   R7, #01h
6f1: eb 04     JR   NZ, 06F7h
6f3: 5c e5     LD   R5, #E5h
6f5: 8b 02     JR   06F9h
6f7: 5c cb     LD   R5, #CBh
6f9: 4c 07     LD   R4, #07h
6fb: 03 53     ADD  R5, @R3
6fd: c2 64     LDC  R6, @RR4
6ff: 48 e2     LD   R4, R2
701: 60 e4     COM  R4
703: 54 11 e4  AND  R4, 11h
706: 6b 07     JR   Z, 070Fh
708: a6 e0 70  CP   R0, #70h
70b: 7b 02     JR   C, 070Fh
70d: 6c ff     LD   R6, #FFh
70f: 69 01     LD   P1, R6
711: 5c 01     LD   R5, #01h
713: d6 04 9a  CALL 049Ah
716: 4c ff     LD   R4, #FFh
718: 49 01     LD   P1, R4
71a: 49 00     LD   P0, R4
71c: 49 03     LD   P3, R4
71e: a6 e3 67  CP   R3, #67h
721: eb 0e     JR   NZ, 0731h
723: 0e        INC  R0
724: a6 e0 80  CP   R0, #80h
727: eb 02     JR   NZ, 072Bh
729: 0c 48     LD   R0, #48h
72b: 3c 5f     LD   R3, #5Fh
72d: 2c 7f     LD   R2, #7Fh
72f: 7c 00     LD   R7, #00h
731: 3e        INC  R3
732: 90 e2     RL   R2
734: 7e        INC  R7
735: 50 01     POP  P1
737: e6 f1 03  LD   TMR, #03h
73a: 51 fd     POP  @FDh
73c: bf        IRET 
73d: 10 0e     RLC  0Eh
73f: 13 12     ADC  R1, @R2
741: 01 02     DEC  @02h
743: 03 04     ADD  R0, @R4
745: 0f        Illegal
746: 05 06 07  ADD  07h, @06h
749: 08 14     LD   R0, 14h
74b: 11 19     RLC  @19h
74d: 1a 1b     DJNZ R1, 076Ah
74f: 1c 5d     LD   R1, #5Dh
751: 1e        INC  R1
752: 1f        Illegal
753: 20 15     INC  15h
755: 16 17 18  ADC  17h, #18h
758: 09 0a     LD   0Ah, R0
75a: 0b 0c     JR   F, 0768h
75c: 03 0b     ADD  R0, @R11
75e: 0e        INC  R0
75f: 0a 18     DJNZ R0, 0779h
761: 04 1c 04  ADD  04h, 1Ch
764: ef        CCF  
765: 4f        Illegal
766: d3 4f     LDCI @RR15, @R4
768: bc 55     LD   R11, #55h
76a: b0 5f     CLR  5Fh
76c: 9d 6a 8b  JP   GE, 6A8Bh
76f: 75 7a 80  TM   80h, @7Ah
772: 74 8a 66  TM   66h, 8Ah
775: 90 5a     RL   5Ah
777: 38 85     LD   R3, 85h
779: 8f        DI   
77a: 58 8f     LD   R5, 8Fh
77c: 31 0f     SRP  #0Fh
77e: 35 31 0f  SBC  0Fh, @31h
781: 35 65 3f  SBC  3Fh, @65h
784: 13 32     ADC  R3, @R2
786: 1f        Illegal
787: 13 55     ADC  R5, @R5
789: 3f        Illegal
78a: 34 55 8f  SBC  8Fh, 55h
78d: 55 53 88  AND  88h, @53h
790: 8f        DI   
791: 00 71     DEC  71h
793: 00 71     DEC  71h
795: 00 71     DEC  71h
797: 00 71     DEC  71h
799: 00 d3     DEC  D3h
79b: 00 80     DEC  80h
79d: 00 e0     DEC  R0
79f: 01 da     DEC  @DAh
7a1: 02 32     ADD  R3, R2
7a3: 02 7c     ADD  R7, R12
7a5: 02 ba     ADD  R11, R10
7a7: 02 03     ADD  R0, R3
7a9: 03 01     ADD  R0, @R1
7ab: 00 00     DEC  P0
7ad: 03 02     ADD  R0, @R2
7af: 01 03     DEC  @03h
7b1: 3c 00     LD   R3, #00h
7b3: 0c 00     LD   R0, #00h
7b5: 8b fa     JR   07B1h
7b7: 00 00     DEC  P0
7b9: 03 02     ADD  R0, @R2
7bb: 01 01     DEC  @01h
7bd: eb ff     JR   NZ, 07BEh
7bf: d4 bf     CALL @BFh
7c1: c0 ff     RRC  SPL
7c3: 80 ef     DECW RR15
7c5: ef        CCF  
7c6: ff        NOP  
7c7: 6f        Illegal
7c8: ef        CCF  
7c9: ff        NOP  
7ca: 6f        Illegal
7cb: 10 57     RLC  57h
7cd: 09 03     LD   P3, R0
7cf: 46 22 20  OR   22h, #20h
7d2: 17 00 02  ADC  @00h, #02h
7d5: 6f        Illegal
7d6: ff        NOP  
7d7: 7f        Illegal
7d8: ff        NOP  
7d9: d7 89 82  LD   R9, 82h(R8)
7dc: c6        Illegal
7dd: a2 a0     CP   R10, R0
7df: 97        Illegal
7e0: 80 82     DECW 82h
7e2: ef        CCF  
7e3: fb 90     JR   NC, 0775h
7e5: 04 75 48  ADD  48h, 75h
7e8: 60 31     COM  31h
7ea: 22 02     SUB  R0, R2
7ec: 74 00 20  TM   20h, P0
7ef: 7b ff     JR   C, 07F0h
7f1: 7f        Illegal
7f2: ff        NOP  
7f3: f5 c8 e0  LD   @R0, C8h
7f6: b1 a2     CLR  @A2h
7f8: 82 f5     LDE  R15, @RR5
7fa: 80 a0     DECW A0h
7fc: fb ef     JR   NC, 07EDh
7fe: ff        NOP  
7ff: 84        Illegal
