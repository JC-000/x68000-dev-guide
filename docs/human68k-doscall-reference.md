# Human68k DOS Call API Reference

Complete, verified reference for the Sharp X68000 Human68k operating system DOS call interface.

## Calling Convention

### DOS Calls: F-line Exception (NOT TRAP)

**DOS calls use the 68000 F-line exception mechanism, NOT TRAP #15.**

The 68000 CPU treats any opcode with bits 15-12 = `1111` (i.e., `$Fxxx`) as an "F-line" instruction, triggering exception vector 11 (address `$002C`). Human68k hooks this vector. When the CPU encounters an inline `DC.W $FFxx` word in the instruction stream:

1. The F-line exception fires
2. Human68k's handler reads the exception PC to find the `$FFxx` opcode
3. The low byte is the DOS function number
4. Parameters are read from the **stack** (pushed before the `DC.W`)
5. The function executes and returns by adjusting PC past the `DC.W` word

The `DOS` macro in `doscall.mac` simply emits `DC.W callname`:
```asm
DOS:    .macro  callname
        dc.w    callname
        .endm
```

### Assembly Pattern

```asm
; Push parameters right-to-left, emit DC.W $FFxx, clean stack after
    pea     message         ; push pointer to string (4 bytes)
    dc.w    $FF09           ; _PRINT -- F-line exception triggers DOS
    addq.l  #4, sp          ; clean up stack (4 bytes were pushed)
```

Parameters use **word alignment** on the stack. After the call returns, the caller cleans up the stack.

### IOCS Calls: TRAP #15 (different mechanism)

For comparison, IOCS calls use `TRAP #15` with the function number in D0:
```asm
    moveq   #$20, d0        ; IOCS _B_PUTC
    move.w  #'A', d1        ; character in D1
    trap    #15             ; invoke IOCS
```

### TRAP Assignment Table

| TRAP | Purpose |
|------|---------|
| #0 - #7 | User-defined |
| #8 | OS internal (abort) |
| #9 | Breakpoints (debugger) |
| #10 | Power off / Reset |
| #11 | BREAK key |
| #12 | COPY key |
| #13 | Ctrl-C |
| #14 | Error processing |
| #15 | **IOCS calls only** |

---

## Complete doscall.mac Equates

From Sharp XC Compiler v1.01, verified against DOS_en.txt:

```asm
_EXIT       equ $FF00       ; Program termination
_GETCHAR    equ $FF01       ; Keyboard input (with echo)
_PUTCHAR    equ $FF02       ; Character display
_COMINP     equ $FF03       ; Serial input (1 byte)
_COMOUT     equ $FF04       ; Serial output (1 byte)
_PRNOUT     equ $FF05       ; Printer output (1 char)
_INPOUT     equ $FF06       ; Keyboard input/output
_INKEY      equ $FF07       ; Key input (no break check)
_GETC       equ $FF08       ; Key input (with break check)
_PRINT      equ $FF09       ; Print string
_GETS       equ $FF0A       ; String input
_KEYSNS     equ $FF0B       ; Key status check
_KFLUSH     equ $FF0C       ; Flush buffer + key input
_FFLUSH     equ $FF0D       ; Disk reset
_CHGDRV     equ $FF0E       ; Change current drive
_DRVCTRL    equ $FF0F       ; Drive status check/set
_CONSNS     equ $FF10       ; Screen output check
_PRNSNS     equ $FF11       ; Printer output check
_CINSNS     equ $FF12       ; Serial input check
_COUTSNS    equ $FF13       ; Serial output check
; $FF14-$FF16 reserved
_FATCHK     equ $FF17       ; File sector check
_HENDSP     equ $FF18       ; Kanji conversion control
_CURDRV     equ $FF19       ; Get current drive
_GETSS      equ $FF1A       ; String input (no break check)
_FGETC      equ $FF1B       ; File handle: read char
_FGETS      equ $FF1C       ; File handle: read string
_FPUTC      equ $FF1D       ; File handle: write char
_FPUTS      equ $FF1E       ; File handle: write string
_ALLCLOSE   equ $FF1F       ; Close all file handles
_SUPER      equ $FF20       ; Supervisor/User mode switch
_FNCKEY     equ $FF21       ; Read/set function keys
_KNJCTRL    equ $FF22       ; Kana-kanji conversion
_CONCTRL    equ $FF23       ; Console control
_KEYCTRL    equ $FF24       ; Console input
_INTVCS     equ $FF25       ; Set interrupt/DOS vector
_PSPSET     equ $FF26       ; Program termination buffer
_GETTIM2    equ $FF27       ; Get time (full seconds)
_SETTIM2    equ $FF28       ; Set time (full seconds)
_NAMESTS    equ $FF29       ; File name info
_GETDATE    equ $FF2A       ; Get current date
_SETDATE    equ $FF2B       ; Set current date
_GETTIME    equ $FF2C       ; Get current time
_SETTIME    equ $FF2D       ; Set current time
_VERIFY     equ $FF2E       ; Set verify flag
_DUP0       equ $FF2F       ; Force duplicate handle (0-4)
_VERNUM     equ $FF30       ; Get OS version
_KEEPPR     equ $FF31       ; Terminate and stay resident
_GETDPB     equ $FF32       ; Get drive parameter block
_BREAKCK    equ $FF33       ; Set break check mode
_DRVXCHG    equ $FF34       ; Swap drives
_INTVCG     equ $FF35       ; Get vector value
_DSKFRE     equ $FF36       ; Get disk free space
_NAMECK     equ $FF37       ; Split filename components
; $FF38 reserved
_MKDIR      equ $FF39       ; Create directory
_RMDIR      equ $FF3A       ; Remove directory
_CHDIR      equ $FF3B       ; Change directory
_CREATE     equ $FF3C       ; Create file (overwrites)
_OPEN       equ $FF3D       ; Open file
_CLOSE      equ $FF3E       ; Close file
_READ       equ $FF3F       ; Read from file
_WRITE      equ $FF40       ; Write to file
_DELETE     equ $FF41       ; Delete file
_SEEK       equ $FF42       ; Move file pointer
_CHMOD      equ $FF43       ; Read/change file attributes
_IOCTRL     equ $FF44       ; Direct device I/O
_DUP        equ $FF45       ; Duplicate file handle
_DUP2       equ $FF46       ; Force duplicate handle
_CURDIR     equ $FF47       ; Get current directory
_MALLOC     equ $FF48       ; Allocate memory
_MFREE      equ $FF49       ; Free memory
_SETBLOCK   equ $FF4A       ; Resize memory block
_EXEC       equ $FF4B       ; Load/execute program
_EXIT2      equ $FF4C       ; Terminate with exit code
_WAIT       equ $FF4D       ; Get child exit code
_FILES      equ $FF4E       ; Find first file
_NFILES     equ $FF4F       ; Find next file
_SETPDB     equ $FF50       ; Switch management process
_GETPDB     equ $FF51       ; Get current process info
_SETENV     equ $FF52       ; Set environment variable
_GETENV     equ $FF53       ; Get environment variable
_VERIFYG    equ $FF54       ; Check verify flag
_COMMON     equ $FF55       ; Manipulate common areas
_RENAME     equ $FF56       ; Rename/move file
_FILEDATE   equ $FF57       ; Read/set file date/time
_MALLOC2    equ $FF58       ; Allocate memory (with mode)
; $FF59 reserved
_MAKETMP    equ $FF5A       ; Create temporary file
_NEWFILE    equ $FF5B       ; Create file (error if exists)
_LOCK       equ $FF5C       ; File locking
; $FF5D-$FF5E reserved
_ASSIGN     equ $FF5F       ; Virtual drive/directory
; $FF60-$FF7C reserved
_S_MALLOC   equ $FF7D       ; Main memory management alloc
_S_MFREE    equ $FF7E       ; Main memory management free
_S_PROCESS  equ $FF7F       ; Set sub memory management
; $FF80-$FFF2 reserved
_DISKRED    equ $FFF3       ; Direct disk read
_DISKWRT    equ $FFF4       ; Direct disk write
_INDOSFLG   equ $FFF5       ; Get OS internal workspace ptr
_SUPER_JSR  equ $FFF6       ; JSR into supervisor area
_BUS_ERR    equ $FFF7       ; Check bus error safety
_OPEN_PR    equ $FFF8       ; Register background task
_KILL_PR    equ $FFF9       ; Delete current process
_GET_PR     equ $FFFA       ; Get thread info
_SUSPEND_PR equ $FFFB       ; Force thread to sleep
_SLEEP_PR   equ $FFFC       ; Enter sleep mode
_SEND_PR    equ $FFFD       ; Send data to thread
_TIME_PR    equ $FFFE       ; Get timer counter
_CHANGE_PR  equ $FFFF       ; Yield to other tasks
```

---

## Console I/O Calls (Detailed)

### $FF00 -- _EXIT

```asm
    dc.w    _EXIT
```
- **Parameters**: None
- **Returns**: Does not return
- Terminates the program. Closes all open file handles including child processes.

### $FF01 -- _GETCHAR

```asm
    dc.w    _GETCHAR
```
- **Returns**: D0.L = keycode
- Waits for key, echoes to stdout. Checks ^C (break), ^P (printer), ^N (cancel ^P).

### $FF02 -- _PUTCHAR

```asm
    move.w  #CODE, -(sp)
    dc.w    _PUTCHAR
    addq.l  #2, sp
```
- **Stack**: CODE.W (character code)
- **Returns**: Nothing
- Displays one character. Checks ^C, ^S, ^P, ^N.

### $FF06 -- _INPOUT

```asm
    move.w  #CODE, -(sp)
    dc.w    _INPOUT
    addq.l  #2, sp
```
- **Stack**: CODE.W
- **Returns**: D0.L = input char (if CODE=$FF/$FE) or 0
- CODE=$FF: key input (non-blocking). CODE=$FE: key sense. Otherwise: output CODE as character. No break check.

### $FF07 -- _INKEY

```asm
    dc.w    _INKEY
```
- **Returns**: D0.L = keycode
- Waits for key. No break check.

### $FF08 -- _GETC

```asm
    dc.w    _GETC
```
- **Returns**: D0.L = keycode
- Waits for key. Checks ^C, ^P, ^N.

### $FF09 -- _PRINT

```asm
    pea     MESPTR
    dc.w    _PRINT
    addq.l  #4, sp
    ...
MESPTR: dc.b    'Hello, World!',$0D,$0A,0
```
- **Stack**: MESPTR.L (pointer to null-terminated string)
- **Returns**: Nothing
- Displays string until null (0). Checks ^C, ^S, ^P, ^N.

### $FF0A -- _GETS

```asm
    pea     INPPTR
    dc.w    _GETS
    addq.l  #4, sp
    ...
INPPTR: dc.b    80      ; max chars
        dc.b    0       ; receives actual count
        ds.b    81      ; buffer (max+1)
```
- **Stack**: INPPTR.L
- **Returns**: D0.L = number of chars input
- Buffer: byte 0=max, byte 1=actual count, byte 2+=string. CR replaced with null.

### $FF0B -- _KEYSNS

```asm
    dc.w    _KEYSNS
```
- **Returns**: D0.L = 0 (input available) or -1 (no input)

### $FF0C -- _KFLUSH

```asm
    pea     INPPTR          ; only for MODE=$0A
    move.w  #MODE, -(sp)
    dc.w    _KFLUSH
    addq.l  #6, sp
```
- **Stack**: MODE.W [, INPPTR.L]
- Flushes keyboard buffer, then reads input. MODE=$01/$06/$07/$08/$0A correspond to DOS calls $FF01/$FF06/$FF07/$FF08/$FF0A.

---

## File I/O Calls (Detailed)

### $FF3C -- _CREATE

```asm
    move.w  #ATR, -(sp)
    pea     NAMEPTR
    dc.w    _CREATE
    addq.l  #6, sp
```
- **Stack**: NAMEPTR.L, ATR.W
- **Returns**: D0.L = file handle (>=0) or negative error
- Creates file. **Overwrites if exists** (use _NEWFILE/$FF5B for safe create).
- ATR bits: 0=ReadOnly, 1=Hidden, 2=System, 3=Volume, 4=Directory, 5=Archive.

### $FF3D -- _OPEN

```asm
    move.w  #MODE, -(sp)
    pea     NAMEPTR
    dc.w    _OPEN
    addq.l  #6, sp
```
- **Stack**: NAMEPTR.L, MODE.W
- **Returns**: D0.L = file handle (>=0) or negative error
- MODE: 0=read-only, 1=write-only, 2=read/write.

### $FF3E -- _CLOSE

```asm
    move.w  #FILENO, -(sp)
    dc.w    _CLOSE
    addq.l  #2, sp
```
- **Stack**: FILENO.W
- **Returns**: D0.L = 0 or negative error

### $FF3F -- _READ

```asm
    move.l  #SIZE, -(sp)
    pea     DATAPTR
    move.w  #FILENO, -(sp)
    dc.w    _READ
    lea     10(sp), sp          ; 2+4+4=10 bytes -- use LEA not ADDQ
```
- **Stack**: FILENO.W, DATAPTR.L, SIZE.L
- **Returns**: D0.L = bytes actually read, or negative error
- Reads from current file pointer position. Stack cleanup is 10 bytes.

### $FF40 -- _WRITE

```asm
    move.l  #SIZE, -(sp)
    pea     DATAPTR
    move.w  #FILENO, -(sp)
    dc.w    _WRITE
    lea     10(sp), sp          ; 10 bytes cleanup
```
- **Stack**: FILENO.W, DATAPTR.L, SIZE.L
- **Returns**: D0.L = bytes actually written, or negative error

### $FF41 -- _DELETE

```asm
    pea     NAMEPTR
    dc.w    _DELETE
    addq.l  #4, sp
```
- **Stack**: NAMEPTR.L
- **Returns**: D0.L = 0 or negative error
- No wildcards, no directories.

### $FF42 -- _SEEK

```asm
    move.w  #MODE, -(sp)
    move.l  #OFFSET, -(sp)
    move.w  #FILENO, -(sp)
    dc.w    _SEEK
    addq.l  #8, sp
```
- **Stack**: FILENO.W, OFFSET.L (signed), MODE.W
- **Returns**: D0.L = new absolute position, or negative error
- MODE: 0=from start, 1=from current, 2=from end.

### $FF43 -- _CHMOD

```asm
    move.w  #ATR, -(sp)
    pea     NAMEPTR
    dc.w    _CHMOD
    addq.l  #6, sp
```
- **Stack**: NAMEPTR.L, ATR.W
- **Returns**: D0.L = file attributes, or negative error
- ATR=-1: read without modifying. Otherwise sets attributes.

### $FF57 -- _FILEDATE

```asm
    move.l  #DATETIME, -(sp)
    move.w  #FILENO, -(sp)
    dc.w    _FILEDATE
    addq.l  #6, sp
```
- **Stack**: FILENO.W, DATETIME.L
- **Returns**: D0.L = file date/time (if DATETIME=0) or error
- DATETIME=0: read. Otherwise: set to DATETIME.
- Format: bits 31-25=year-1980, 24-21=month, 20-16=day, 15-11=hour, 10-6=min, 5-0=sec/2.
- **Note**: If top word of return is $FFFF, it is an error. Other negative values are valid dates.

### $FF1B -- _FGETC (file handle char input)

```asm
    move.w  #FILENO, -(sp)
    dc.w    _FGETC
    addq.l  #2, sp
```
- **Returns**: D0.L = character code

### $FF1D -- _FPUTC (file handle char output)

```asm
    move.w  #FILENO, -(sp)
    move.w  #CODE, -(sp)
    dc.w    _FPUTC
    addq.l  #4, sp
```

### $FF1E -- _FPUTS (file handle string output)

```asm
    move.w  #FILENO, -(sp)
    pea     MESPTR
    dc.w    _FPUTS
    addq.l  #6, sp
```
- Does not output the terminating null.

---

## Memory Management (Detailed)

### $FF48 -- _MALLOC

```asm
    move.l  #LEN, -(sp)
    dc.w    _MALLOC
    addq.l  #4, sp
```
- **Stack**: LEN.L (only lower 24 bits valid)
- **Returns**: D0.L = pointer to allocated memory
  - `$81xxxxxx` = failure (lower 24 bits = max available)
  - `$8200000x` = allocation impossible
- Memory management pointer is at returned_address - $10.
- **IMPORTANT**: At program start, ALL memory is pre-allocated to the program. You MUST call `_SETBLOCK` first to shrink your allocation before `_MALLOC` will work.

### $FF49 -- _MFREE

```asm
    move.l  MEMPTR, -(sp)
    dc.w    _MFREE
    addq.l  #4, sp
```
- **Stack**: MEMPTR.L (pointer from _MALLOC)
- **Returns**: D0.L = 0 or error
- MEMPTR=0: frees ALL memory of caller and children.

### $FF4A -- _SETBLOCK

```asm
    move.l  #NEWLEN, -(sp)
    move.l  MEMPTR, -(sp)
    dc.w    _SETBLOCK
    addq.l  #8, sp
```
- **Stack**: MEMPTR.L, NEWLEN.L (lower 24 bits)
- **Returns**: D0.L = 0 or error
- Can expand or contract.

### $FF58 -- _MALLOC2 (with allocation mode)

```asm
    move.l  #LEN, -(sp)
    move.w  #MD, -(sp)
    dc.w    _MALLOC2
    addq.l  #6, sp
```
- **Stack**: MD.W, LEN.L
- MD=0: search from bottom. MD=1: smallest fit. MD=2: search from top.

---

## Process Control (Detailed)

### $FF4B -- _EXEC

```asm
    ; MD=0: Load and execute
    clr.l   -(sp)               ; P2=0 (inherit environment)
    pea     P1                  ; command line
    pea     FIL                 ; program filename
    move.w  #0, -(sp)           ; MD=0
    dc.w    _EXEC
    lea     14(sp), sp
    ...
P1: dc.b    11,'DOSCALL.DOC',0  ; byte 0 = arg length
FIL: dc.b   'EDIT.X',0
```
- **Stack**: MD.W, FIL.L, P1.L, P2.L
- **Returns**: D0.L = exit code (MD=0), exec address (MD=1), or negative error
- MD=0: load+execute. MD=1: load only. MD=2: PATH lookup. MD=3: load to address. MD=4: execute loaded program.
- D1-D7/A0-A6 destroyed on child execution.
- New program receives: A0=memory mgmt ptr, A1=end of program+1, A2=command line, A3=environment, A4=execution header.

### $FF4C -- _EXIT2

```asm
    move.w  #CODE, -(sp)
    dc.w    _EXIT2
```
- **Stack**: CODE.W (exit code)
- Does not return. Closes all file handles.

### $FF31 -- _KEEPPR

```asm
    move.w  #CODE, -(sp)
    move.l  #PRGLEN, -(sp)
    dc.w    _KEEPPR
```
- **Stack**: PRGLEN.L, CODE.W
- Terminate and stay resident.

### $FF4D -- _WAIT

```asm
    dc.w    _WAIT
```
- **Returns**: D0.L = exit code from last child

---

## Directory and Drive Operations

### $FF39 -- _MKDIR / $FF3A -- _RMDIR / $FF3B -- _CHDIR

```asm
    pea     NAMEPTR
    dc.w    _MKDIR          ; or _RMDIR or _CHDIR
    addq.l  #4, sp
```
- **Returns**: D0.L = 0 or negative error

### $FF47 -- _CURDIR

```asm
    pea     PATHBUF         ; 65 bytes minimum
    move.w  #DRIVE, -(sp)   ; 0=current, 1=A, 2=B...
    dc.w    _CURDIR
    addq.l  #6, sp
```
- Leading/trailing `\` not included. Root returns empty string.

### $FF0E -- _CHGDRV

```asm
    move.w  #DRIVE, -(sp)   ; 0=A, 1=B, 2=C...
    dc.w    _CHGDRV
    addq.l  #2, sp
```
- **Returns**: D0.L = number of available drives (1 to N)

### $FF19 -- _CURDRV

```asm
    dc.w    _CURDRV
```
- **Returns**: D0.L = current drive (0=A, 1=B, 2=C...)

### $FF56 -- _RENAME

```asm
    pea     NEWNAME
    pea     OLDNAME
    dc.w    _RENAME
    addq.l  #8, sp
```
- Can move files between directories (same drive only).

---

## File Search

### $FF4E -- _FILES (find first)

```asm
    move.w  #ATR, -(sp)
    pea     NAMEPTR         ; wildcards OK
    pea     FILBUF          ; 53 bytes
    dc.w    _FILES
    lea     10(sp), sp
```
- FILBUF format (53 bytes): search ATR(1), drive(1), dir cluster(2), FAT(2), sector(2), position(2), filename(8), ext(3), file ATR(1), time(2), date(2), size(4), packed name(22).

### $FF4F -- _NFILES (find next)

```asm
    pea     FILBUF          ; same buffer from _FILES
    dc.w    _NFILES
    addq.l  #4, sp
```

---

## Date/Time

### $FF2A -- _GETDATE

```asm
    dc.w    _GETDATE
```
- **Returns**: D0.L bits: 18-16=weekday(0=Sun..6=Sat), 15-9=year-1980, 8-5=month, 4-0=day

### $FF2C -- _GETTIME

```asm
    dc.w    _GETTIME
```
- **Returns**: D0.W bits: 15-11=hours, 10-5=minutes, 4-0=seconds/2

### $FF27 -- _GETTIM2

```asm
    dc.w    _GETTIM2
```
- **Returns**: D0.L = `$00HHMMSS` (full second precision)

---

## System Calls

### $FF20 -- _SUPER

```asm
    clr.l   -(sp)           ; STACK=0: enter supervisor
    dc.w    _SUPER
    addq.l  #4, sp
    move.l  d0, ssp_save    ; save old SSP
    ; ... supervisor code ...
    move.l  ssp_save, -(sp) ; restore
    dc.w    _SUPER
    addq.l  #4, sp
```
- STACK=0: switch to supervisor, returns old SSP in D0.
- STACK<>0: switch to user, STACK becomes new SSP.

### $FF30 -- _VERNUM

```asm
    dc.w    _VERNUM
```
- **Returns**: D0.L high word = `'68'` ($3638), low word = major*256+minor

### $FF25 -- _INTVCS

```asm
    pea     HANDLER
    move.w  #INTNO, -(sp)
    dc.w    _INTVCS
    addq.l  #6, sp
```
- **Returns**: D0.L = previous vector
- INTNO: $00-$FF = hardware vectors, $100-$1FF = IOCS, $FF00-$FFFF = DOS.
- Handler uses RTE for hardware vectors ($00-$FF), RTS for DOS/IOCS vectors.

### $FF52 -- _SETENV / $FF53 -- _GETENV

```asm
    ; Set
    pea     VALUE
    clr.l   -(sp)           ; 0=current environment
    pea     NAME
    dc.w    _SETENV
    lea     12(sp), sp

    ; Get
    pea     BUFFER          ; 256 bytes
    clr.l   -(sp)
    pea     NAME
    dc.w    _GETENV
    lea     12(sp), sp
```
- SETENV with VALUE=0 deletes the variable. Max 255 bytes per variable.

---

## Error Codes

| Code | Meaning |
|------|---------|
| -1 | Invalid function code |
| -2 | File not found |
| -3 | Directory not found |
| -4 | Too many open files |
| -5 | Cannot access directory/volume label |
| -6 | Handle not open |
| -7 | Memory management area corrupted |
| -8 | Insufficient memory |
| -9 | Invalid memory pointer |
| -10 | Illegal environment |
| -11 | Abnormal executable format |
| -12 | Erroneous access mode |
| -13 | Invalid filename |
| -14 | Invalid parameter |
| -15 | Invalid drive |
| -16 | Cannot delete current directory |
| -17 | Device incapable of IOCTRL |
| -18 | No more files |
| -19 | File not writable |
| -20 | Directory already exists |
| -21 | Cannot delete (file present) |
| -22 | Cannot rename (name collision) |
| -23 | Disk full |
| -24 | Directory full |
| -25 | Cannot seek to position |
| -26 | Already in supervisor mode |
| -27 | Thread name exists |
| -28 | Process comm buffer write prohibited |
| -29 | Cannot start more background processes |
| -32 | Insufficient lock area |
| -33 | Access denied (lock) |
| -34 | Drive handler open |
| -80 | File already exists |

---

## Standard File Handles

Always open at program start:

| Handle | Device | Description |
|--------|--------|-------------|
| 0 | CON | Standard input (redirectable) |
| 1 | CON | Standard output (redirectable) |
| 2 | CON | Standard error |
| 3 | AUX | Auxiliary (RS-232C) |
| 4 | PRN | Printer |

File handles range from 0 to FILES= value in CONFIG.SYS (max 93). Five are reserved for standard devices.

---

## Program Startup State

When Human68k loads a `.X` program:

| Register | Contents |
|----------|----------|
| A0 | Memory management pointer (block header, program at A0+$100) |
| A1 | End of program (DATA+BSS) + 1 |
| A2 | Command line (byte 0=length, then args, null-terminated) |
| A3 | Environment pointer |
| A4 | Program execution header |
| SR | User mode |
| USP | Inherited from parent |
| SSP | System stack |
| D0-D7, A5-A6 | Indeterminate |

**IMPORTANT**: At startup, ALL available memory is allocated to the process. You must call `_SETBLOCK` to shrink your allocation before `_MALLOC` will work. The end of your memory block is at `8(A0)`.

### Command Line Format
```
byte 0:  length of string
byte 1+: argument string (spaces, flags, etc.)
last:    null terminator (0)
```

### Environment Format
```
longword:  total workspace size (including header)
string 1:  'path=A:\',0
string 2:  'COMSPEC=A:\COMMAND.X',0
...
final:     0  (extra null marks end)
```

---

## .X Executable Format

64-byte header, all big-endian:

| Offset | Size | Field |
|--------|------|-------|
| $00 | 2 | Magic: `$4855` ("HU") |
| $02 | 2 | Reserved |
| $04 | 4 | Base address |
| $08 | 4 | Entry point (relative to base) |
| $0C | 4 | Text section size |
| $10 | 4 | Data section size |
| $14 | 4 | BSS/heap size |
| $18 | 4 | Relocation table size |
| $1C | 4 | Symbol table size |
| $20 | 32 | Padding |
| $40+ | | Text, Data, Relocation, Symbols |

---

## Hello World Examples

### HAS.X Native Assembler (Motorola syntax)

```asm
; hello.s -- Assemble: HAS.X hello.s / Link: HLK.X hello.o -o HELLO.X

        .include  doscall.mac

        .text
        .even

main:
        pea     message
        DOS     _PRINT          ; emits dc.w $FF09
        addq.l  #4, sp

        clr.w   -(sp)
        DOS     _EXIT2          ; emits dc.w $FF4C

        .data

message:
        dc.b    'Hello, World!',$0D,$0A,0

        .end    main
```

### GAS Cross-assembler (verified from sokoide/x68k-cross-compile)

```asm
; Assemble: m68k-xelf-as -m68000 --register-prefix-optional hello.s -o hello.o
; Link: m68k-xelf-ld hello.o -o hello.elf -lx68kdos -e main
; Convert: elf2x68k.py -o HELLO.X hello.elf

.equ _print, 0xff09
.equ _exit2, 0xff4c

        .text
        .even
        .globl  main
        .type   main, @function
main:
        pea     message
        dc.w    _print
        addq.l  #4, sp

        clr.w   -(sp)
        dc.w    _exit2

        .section .data
message:
        .string "Hello, World!\r\n"
        .end    main
```

### Raw Motorola syntax (no includes, for vasm)

```asm
; vasmm68k_mot -Ftos -o HELLO.X hello.s

_PRINT  equ     $FF09
_EXIT2  equ     $FF4C

        section text,code
start:
        pea     message(pc)
        dc.w    _PRINT
        addq.l  #4,sp
        clr.w   -(sp)
        dc.w    _EXIT2

        section data,data
message:
        dc.b    'Hello, World!',$0D,$0A,0
        end     start
```

### File I/O Example

```asm
_CREATE equ $FF3C
_WRITE  equ $FF40
_CLOSE  equ $FF3E
_EXIT2  equ $FF4C

        section text,code
start:
        move.w  #$0020,-(sp)        ; ATR=archive
        pea     fname(pc)
        dc.w    _CREATE
        addq.l  #6,sp
        tst.l   d0
        bmi     done
        move.w  d0,fhandle

        move.l  #dend-dstart,-(sp)
        pea     dstart(pc)
        move.w  fhandle,-(sp)
        dc.w    _WRITE
        lea     10(sp),sp

        move.w  fhandle,-(sp)
        dc.w    _CLOSE
        addq.l  #2,sp

done:   clr.w   -(sp)
        dc.w    _EXIT2

        section data,data
fname:  dc.b    'OUTPUT.TXT',0
dstart: dc.b    'Written by X68000!',$0D,$0A
dend:
fhandle: dc.w   0
        end     start
```

---

## Verification Sources

This reference was compiled from:

1. **Primary**: [DOS_en.txt](https://mijet.eludevisibility.org/X68000%20Technical%20Documents/English%20X68k%20Docs/DOS_en.txt) -- English translation of the official Human68k doscall.man (v3.02). Full text fetched and verified. This is the authoritative source for all function numbers, parameter layouts, stack frame formats, and return values.

2. **Cross-reference**: [ghidra-human68k](https://github.com/erique/ghidra-human68k) -- Ghidra extension with "F-line DOS call analyzer" confirming the F-line exception mechanism and $FFxx opcode format.

3. **Cross-reference**: [FedericoTech/X68KTutorials](https://github.com/FedericoTech/X68KTutorials) -- Working assembly examples (`assembler_mariko.s`, `assembler_lydux.S`) showing both the `DOS _PRINT` macro pattern and raw `dc.w _PRINT` / `.short _PRINT` usage.

4. **Cross-reference**: [sokoide/x68k-cross-compile](https://github.com/sokoide/x68k-cross-compile) -- Verified working `asm-hello/main.s` using GAS syntax with `dc.w` for DOS calls.

5. **Cross-reference**: [GOROman's ImHex pattern](https://gist.github.com/GOROman/a704479dceafc67f4552c3256d9b0422) -- .X file header structure.

6. **Cross-reference**: [Data Crystal X68k/DOSCALL](https://datacrystal.tcrf.net/wiki/X68k/DOSCALL), [GameSX doscall](https://gamesx.com/wiki/doku.php?id=x68000:doscall), [GameSX trap_codes](https://gamesx.com/wiki/doku.php?id=x68000:trap_codes).

### Lower Confidence Items

- **IOCS call numbers**: The IOCS table entries are drawn from search result snippets and the Data Crystal X68k/IOCS page, not from a complete fetched source. Verify against `iocscall.mac`.
- **vasm -Ftos**: The TOS output format is for Atari ST. It works for simple X68000 programs because the formats are similar, but complex programs may need `elf2x68k.py` or native toolchain instead.
