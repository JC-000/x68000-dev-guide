# Disk I/O and File System

### How DOS Calls Work: The F-Line Mechanism

Human68k DOS calls do **not** use `TRAP #15` directly (despite some documentation conflating the two). Instead, DOS calls use **F-line emulation exceptions**. On the MC68000, any opcode whose most significant nibble is `$F` (binary `1111`) is undefined and triggers the **Line-F exception** (vector 11, address `$002C`). Human68k hooks this exception vector. When the CPU encounters an inline `DC.W $FFxx` word during execution, it fires the F-line exception. The handler reads the exception word from the instruction stream, extracts the low byte as the DOS function number, and dispatches to the appropriate handler.

IOCS calls, by contrast, use `TRAP #15` with the function number pre-loaded in register `D0.W`. The `iocscall.mac` `IOCS` macro simply expands to `TRAP #15`.

**Calling convention for DOS calls**:
1. Push arguments onto the stack (right to left, as shown in each call's documentation)
2. The inline `DC.W $FFxx` word acts as both the call instruction and the function selector
3. After the call, **you** must clean up the stack (add back the bytes you pushed)
4. Return value is in `D0.L` (positive = success or data, negative = error)

**Important**: For calls with 10 or more bytes of arguments, you cannot use `ADDQ.L` (which only takes immediate values 1-8). Use `LEA offset(SP),SP` instead, as shown in the official documentation.

---

### File Handle Conventions

Human68k pre-opens five standard device handles at program startup. These do not need to be opened explicitly:

| Handle | Name | Default Device | Notes |
|--------|------|----------------|-------|
| 0 | Standard Input | CON | Redirectable |
| 1 | Standard Output | CON | Redirectable |
| 2 | Standard Error | CON | Not redirectable |
| 3 | Standard Auxiliary | AUX | RS-232C serial |
| 4 | Standard Printer | PRN | Printer port |

When creating or opening files, the OS assigns the lowest available unused handle number. Handle values range from 0 to the value set by the `FILES=` directive in `CONFIG.SYS` (maximum 93). Since 5 handles are reserved for standard devices, the actual maximum number of simultaneously open user files is `FILES - 5`.

---

### Drive and Path Conventions

Human68k follows MS-DOS conventions:

- **Drive letters**: `A:` and `B:` are floppy drives (internal 5.25" drives). `C:` onward are hard disk partitions (SASI/SCSI)
- **Path separator**: Backslash `\` (identical to MS-DOS)
- **Current drive**: Changed via `_CHGDRV` ($FF0E), queried via `_CURDRV` ($FF19)
- **Current directory**: Changed via `_CHDIR` ($FF3B), queried via `_CURDIR` ($FF47)
- **Filenames**: 18.3 format (18 characters for the name, 3 for extension) -- more generous than MS-DOS 8.3. Case-insensitive.
- **Path example**: `A:\GAMES\PROG.X`
- **Wildcard support**: `*` and `?` are supported in `_FILES`/`_NFILES` calls (but NOT in `_DELETE`)

The `_ASSIGN` ($FF5F) DOS call provides virtual drive/directory mapping, allowing one path to be redirected to another.

---

### DOS File I/O Calls: Complete Reference

#### _CREATE ($FF3C) -- Create a New File

Creates a new file, or **truncates an existing file to zero length** if it already exists.

```asm
; Prototype: _CREATE(name_ptr.l, attr.w)
; Returns:   D0.L = file handle (>= 0) or negative error code

    move.w  #ATR,-(sp)          ; file attribute word
    pea     filename(pc)        ; pointer to NUL-terminated path string
    dc.w    $FF3C               ; _CREATE
    addq.l  #6,sp               ; clean up 6 bytes (4 for pointer + 2 for word)
    tst.l   d0
    bmi     error               ; negative = error
    move.w  d0,file_handle      ; save handle for later use
    ...
filename: dc.b 'A:\DATA\OUTPUT.DAT',0
    .even
```

**File attribute bits** (for the `ATR` parameter):

| Bit | Name | Meaning |
|-----|------|---------|
| 0 | R | Read-only |
| 1 | H | Hidden file |
| 2 | S | System file |
| 3 | V | Volume label |
| 4 | D | Directory |
| 5 | A | Archive |
| 6-15 | -- | Ignored |

For a normal file, use attribute `$20` (archive bit set) or `$00`.

**WARNING**: `_CREATE` silently destroys the contents of an existing file. To create a file only if it does not already exist, use `_NEWFILE` ($FF5B) instead, which returns error code `-80` if the file exists.

---

#### _OPEN ($FF3D) -- Open an Existing File

```asm
; Prototype: _OPEN(name_ptr.l, mode.w)
; Returns:   D0.L = file handle (>= 0) or negative error code

    move.w  #MODE,-(sp)         ; access mode
    pea     filename(pc)        ; pointer to NUL-terminated path string
    dc.w    $FF3D               ; _OPEN
    addq.l  #6,sp               ; clean up 6 bytes
    tst.l   d0
    bmi     error
    move.w  d0,file_handle
```

**Access modes**:

| MODE | Meaning |
|------|---------|
| 0 | Read-only |
| 1 | Write-only |
| 2 | Read/Write |

(Modes `$100`-`$102` are dictionary modes reserved for system use.)

---

#### _CLOSE ($FF3E) -- Close a File Handle

```asm
; Prototype: _CLOSE(handle.w)
; Returns:   D0.L = 0 on success, negative error code on failure

    move.w  file_handle,-(sp)   ; file handle to close
    dc.w    $FF3E               ; _CLOSE
    addq.l  #2,sp               ; clean up 2 bytes
```

Always close file handles when done. Unclosed handles are freed when the program terminates (via `_EXIT`), but it is good practice to close them explicitly.

---

#### _READ ($FF3F) -- Read from a File

```asm
; Prototype: _READ(handle.w, buffer_ptr.l, size.l)
; Returns:   D0.L = number of bytes actually read, or negative error code

    move.l  #SIZE,-(sp)         ; number of bytes to read
    pea     buffer(pc)          ; pointer to read buffer
    move.w  file_handle,-(sp)   ; file handle
    dc.w    $FF3F               ; _READ
    lea     10(sp),sp           ; clean up 10 bytes (2+4+4) -- cannot use ADDQ
    tst.l   d0
    bmi     error
    ; D0.L = number of bytes actually read (may be < SIZE at EOF)
```

**Important notes**:
- The stack frame is 10 bytes (word + long + long). Since `ADDQ.L` only supports immediates 1-8, you must use `LEA 10(SP),SP` to clean up.
- Reading starts at the current file pointer position. After the read, the file pointer advances by the number of bytes read.
- A return value of 0 indicates end-of-file.
- A return value less than `SIZE` indicates a partial read (EOF reached during the read).

---

#### _WRITE ($FF40) -- Write to a File

```asm
; Prototype: _WRITE(handle.w, buffer_ptr.l, size.l)
; Returns:   D0.L = number of bytes actually written, or negative error code

    move.l  #SIZE,-(sp)         ; number of bytes to write
    pea     buffer(pc)          ; pointer to data buffer
    move.w  file_handle,-(sp)   ; file handle
    dc.w    $FF40               ; _WRITE
    lea     10(sp),sp           ; clean up 10 bytes
    tst.l   d0
    bmi     error
    ; D0.L = number of bytes written
```

Same stack layout as `_READ`. Writing starts at the current file pointer position. If the file pointer is at the end, the file grows. A return value less than `SIZE` typically indicates the disk is full.

**Writing to standard output**: You can write to handle 1 (stdout) to display text:
```asm
    move.l  #msg_len,-(sp)
    pea     message(pc)
    move.w  #1,-(sp)            ; stdout handle
    dc.w    $FF40               ; _WRITE
    lea     10(sp),sp
```

---

#### _DELETE ($FF41) -- Delete a File

```asm
; Prototype: _DELETE(name_ptr.l)
; Returns:   D0.L = 0 on success, negative error code on failure

    pea     filename(pc)
    dc.w    $FF41               ; _DELETE
    addq.l  #4,sp
```

Wildcards and directories are **not** supported. To delete a directory, use `_RMDIR` ($FF3A).

---

#### _SEEK ($FF42) -- Move the File Pointer

```asm
; Prototype: _SEEK(handle.w, offset.l, mode.w)
; Returns:   D0.L = new absolute file position, or negative error code

    move.w  #MODE,-(sp)         ; seek origin
    move.l  #OFFSET,-(sp)       ; byte offset (signed)
    move.w  file_handle,-(sp)   ; file handle
    dc.w    $FF42               ; _SEEK
    addq.l  #8,sp               ; clean up 8 bytes (2+4+2)
```

**Seek modes**:

| MODE | Origin | Description |
|------|--------|-------------|
| 0 | Beginning of file | OFFSET from start (set absolute position) |
| 1 | Current position | OFFSET relative to current position |
| 2 | End of file | OFFSET relative to end (use negative to go back) |

**Common pattern -- get file size**:
```asm
    ; Seek to end to get file size
    move.w  #2,-(sp)            ; mode 2 = from end
    move.l  #0,-(sp)            ; offset 0
    move.w  file_handle,-(sp)
    dc.w    $FF42               ; _SEEK
    addq.l  #8,sp
    move.l  d0,file_size        ; D0 = position = file size

    ; Seek back to beginning
    move.w  #0,-(sp)            ; mode 0 = from beginning
    move.l  #0,-(sp)            ; offset 0
    move.w  file_handle,-(sp)
    dc.w    $FF42               ; _SEEK
    addq.l  #8,sp
```

The file pointer can be moved beyond the current end of file (creating a "hole"), but attempting to seek before the beginning of the file returns an error.

---

#### _FILES ($FF4E) -- Find First File (Directory Search)

```asm
; Prototype: _FILES(filbuf_ptr.l, name_ptr.l, attr.w)
; Returns:   D0.L = 0 on success, negative error code if no match found

    move.w  #ATR,-(sp)          ; search attribute mask
    pea     pattern(pc)         ; pointer to search pattern (wildcards OK)
    pea     filbuf(pc)          ; pointer to 53-byte result buffer
    dc.w    $FF4E               ; _FILES
    lea     10(sp),sp           ; clean up 10 bytes
    tst.l   d0
    bmi     no_files_found
```

The search pattern supports wildcards: `*.*`, `*.DOC`, `GAME??.X`, etc.

The attribute mask controls which types of files are included in the search. Setting bit 1 (hidden) and bit 2 (system) will include hidden/system files in results. Setting bit 4 (directory) includes directory entries. Normal files (attribute = 0 or archive-only) are always included.

**FILBUF structure** (53 bytes total) -- filled in by `_FILES` and `_NFILES`:

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| $00 | 1 byte | Search ATR | Search attribute (used internally) |
| $01 | 1 byte | Drive number | Drive (0=A, 1=B, etc.) |
| $02 | 2 bytes | Directory cluster | Sector number of directory being searched |
| $04 | 2 bytes | Directory FAT | Remaining sector count for directory |
| $06 | 2 bytes | Directory sector | (internal) |
| $08 | 2 bytes | Directory position | Offset within sector (internal) |
| $0A | 8 bytes | Filename | Filename (space-padded, no dot) |
| $12 | 3 bytes | Extension | Extension (space-padded) |
| $15 | 1 byte | File ATR | File attribute byte |
| $16 | 2 bytes | Time | File time (packed: HHHHHMMMMMMSSSSS) |
| $18 | 2 bytes | Date | File date (packed: YYYYYYYMMMMDDDDD) |
| $1A | 4 bytes | File size | File length in bytes |
| $1E | 23 bytes | Packed name | Full filename as NUL-terminated string (name.ext format) |

**WARNING**: Do not modify the internal fields (offsets $00-$09) between `_FILES` and `_NFILES` calls. Doing so will break the directory enumeration.

---

#### _NFILES ($FF4F) -- Find Next File

```asm
; Prototype: _NFILES(filbuf_ptr.l)
; Returns:   D0.L = 0 on success, negative error code when no more files

    pea     filbuf(pc)          ; same buffer used in previous _FILES call
    dc.w    $FF4F               ; _NFILES
    addq.l  #4,sp
    tst.l   d0
    bmi     done                ; negative = no more files
```

Call `_NFILES` repeatedly after a successful `_FILES` to enumerate all matching files. Each call updates the FILBUF with the next matching file's information. A negative return value indicates no more matching files.

---

#### _NEWFILE ($FF5B) -- Create File (Fail if Exists)

```asm
; Prototype: _NEWFILE(name_ptr.l, attr.w)
; Returns:   D0.L = file handle or negative error code
;            D0.L = -80 if the file already exists

    move.w  #ATR,-(sp)
    pea     filename(pc)
    dc.w    $FF5B               ; _NEWFILE
    addq.l  #6,sp
```

Same calling convention as `_CREATE`, but returns error `-80` (`DOSE_EXISTFILE`) if the file already exists rather than silently truncating it. Use this when you need safe file creation without risking data loss.

---

### DOS Error Codes

When a DOS call fails, `D0.L` contains a negative value. The error codes are defined as follows (sourced from the `run68x` Human68k emulator header `human68k.h`):

| Code | Name | Meaning |
|------|------|---------|
| 0 | `DOSE_SUCCESS` | No error |
| -1 | `DOSE_ILGFNC` | Invalid function number |
| -2 | `DOSE_NOENT` | File not found |
| -3 | `DOSE_NODIR` | Directory not found |
| -4 | `DOSE_MFILE` | Too many open files |
| -5 | `DOSE_ISDIR` | Cannot open a directory as a file |
| -6 | `DOSE_BADF` | Invalid file handle |
| -8 | `DOSE_NOMEM` | Not enough memory |
| -9 | `DOSE_ILGMPTR` | Invalid memory block address |
| -11 | `DOSE_ILGFMT` | Invalid executable format |
| -12 | `DOSE_ILGARG` | Invalid argument |
| -13 | `DOSE_ILGFNAME` | Invalid filename |
| -14 | `DOSE_ILGPARM` | Invalid parameter |
| -15 | `DOSE_ILGDRV` | Invalid drive number |
| -19 | `DOSE_RDONLY` | File/disk is read-only |
| -20 | `DOSE_EXISTDIR` | Directory already exists |
| -21 | `DOSE_NOTEMPTY` | Directory is not empty |
| -23 | `DOSE_DISKFULL` | Disk full (cannot write/create) |
| -25 | `DOSE_CANTSEEK` | Seek to invalid position |
| -33 | `DOSE_LCKERR` | File lock error |
| -80 | `DOSE_EXISTFILE` | File already exists (returned by `_NEWFILE`) |

For memory allocation errors (`_MALLOC`, `_SETBLOCK`):
- `$81xxxxxx`: Insufficient memory, but `xxxxxx` bytes are available
- `$82000000`: Completely out of memory

**Error checking pattern**:
```asm
    tst.l   d0
    bmi.s   .error          ; any negative value = error
    ; success path...
.error:
    ; D0.L contains the negative error code
    ; To extract the error number: neg.l d0 gives the positive code
```

---

### Complete File I/O Assembly Examples

#### Example 5: Write a String to a New File

This example creates a file called `HELLO.TXT` on the current drive, writes the text "Hello X68000!" to it, and closes the file.

```asm
;=============================================================
; write_file.s -- Create a file and write text to it
; Assemble with HAS.X:  HAS.X write_file.s
; Link with HLK.X:      HLK.X write_file.o -o write_file.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o write_file.x write_file.s
;=============================================================

    .text

start:
    ; --- Create the file ---
    move.w  #$20,-(sp)         ; attribute: Archive bit set
    pea     fname(pc)          ; pointer to filename string
    dc.w    $FF3C              ; _CREATE
    addq.l  #6,sp
    tst.l   d0
    bmi     create_err         ; branch if error
    move.w  d0,fhandle         ; save file handle

    ; --- Write data to the file ---
    move.l  #msg_end-msg,-(sp) ; number of bytes to write
    pea     msg(pc)            ; pointer to data
    move.w  fhandle(pc),-(sp)  ; file handle
    dc.w    $FF40              ; _WRITE
    lea     10(sp),sp
    tst.l   d0
    bmi     write_err          ; branch if error

    ; --- Close the file ---
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp

    ; --- Print success message and exit ---
    pea     ok_msg(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp
    dc.w    $FF00              ; _EXIT

create_err:
    pea     err1_msg(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2 with error code 1

write_err:
    ; Close the file even on write error
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp
    pea     err2_msg(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2

    .data

fname:    dc.b  'HELLO.TXT',0
msg:      dc.b  'Hello X68000!',$0D,$0A    ; CR+LF line ending
msg_end:
ok_msg:   dc.b  'File written successfully.',$0D,$0A,0
err1_msg: dc.b  'Error: could not create file.',$0D,$0A,0
err2_msg: dc.b  'Error: could not write to file.',$0D,$0A,0

    .even

    .bss

fhandle:  ds.w  1              ; storage for file handle

    .end    start
```

**Notes on this example**:
- The `.text`, `.data`, `.bss`, and `.end` directives are standard HAS.X/vasm sections.
- `$0D,$0A` (CR+LF) is the standard Human68k line ending, same as MS-DOS.
- Error handling closes the file if the write fails, preventing a handle leak.
- `_PRINT` ($FF09) expects a NUL-terminated string; `_WRITE` uses an explicit byte count.

---

#### Example 6: Read a File and Print Its Contents

This example opens an existing file, reads its entire contents into a buffer, prints the contents to standard output, and closes the file.

```asm
;=============================================================
; read_file.s -- Read a file and display its contents
; Assemble/link as above.
;=============================================================

BUF_SIZE equ 4096              ; read buffer size

    .text

start:
    ; --- Open the file for reading ---
    move.w  #0,-(sp)           ; mode 0 = read-only
    pea     fname(pc)
    dc.w    $FF3D              ; _OPEN
    addq.l  #6,sp
    tst.l   d0
    bmi     open_err
    move.w  d0,fhandle

.read_loop:
    ; --- Read a chunk ---
    move.l  #BUF_SIZE,-(sp)    ; max bytes to read
    pea     buffer             ; pointer to buffer (in BSS)
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3F              ; _READ
    lea     10(sp),sp
    tst.l   d0
    bmi     read_err           ; negative = error
    beq.s   .done              ; zero = end of file

    ; --- Write the chunk to stdout ---
    move.l  d0,-(sp)           ; number of bytes actually read
    pea     buffer
    move.w  #1,-(sp)           ; handle 1 = stdout
    dc.w    $FF40              ; _WRITE
    lea     10(sp),sp
    bra.s   .read_loop         ; loop until EOF

.done:
    ; --- Close the file ---
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp
    dc.w    $FF00              ; _EXIT

open_err:
    pea     err1_msg(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2

read_err:
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp
    pea     err2_msg(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C

    .data

fname:     dc.b 'HELLO.TXT',0
err1_msg:  dc.b 'Error: could not open file.',$0D,$0A,0
err2_msg:  dc.b 'Error: could not read file.',$0D,$0A,0

    .even

    .bss

fhandle:   ds.w 1
buffer:    ds.b BUF_SIZE

    .end    start
```

**Notes**:
- The read loop handles large files by reading in chunks of `BUF_SIZE` bytes.
- A return value of 0 from `_READ` means end-of-file; the loop terminates cleanly.
- The read data is written to stdout (handle 1) using `_WRITE`, which can output binary data (unlike `_PRINT` which stops at NUL bytes).

---

#### Example 7: Directory Listing Using _FILES/_NFILES

This example enumerates all files in the current directory and prints each filename and size.

```asm
;=============================================================
; dir_list.s -- List files in current directory
; Assemble/link as above.
;=============================================================

    .text

start:
    ; --- Print header ---
    pea     header(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    ; --- Find first file ---
    move.w  #$37,-(sp)         ; ATR: include all types (R+H+S+D+A)
    pea     pattern(pc)        ; search pattern
    pea     filbuf             ; 53-byte result buffer
    dc.w    $FF4E              ; _FILES
    lea     10(sp),sp
    tst.l   d0
    bmi     no_files

.print_loop:
    ; --- Print the filename from FILBUF offset $1E (packed name) ---
    pea     filbuf+$1E         ; NUL-terminated name.ext string
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    ; --- Print a tab ---
    move.w  #$09,-(sp)         ; TAB character
    dc.w    $FF02              ; _PUTCHAR
    addq.l  #2,sp

    ; --- Check if this is a directory ---
    move.b  filbuf+$15,d1      ; file attribute byte
    btst    #4,d1              ; test directory bit
    beq.s   .print_size
    pea     dir_str(pc)        ; print "<DIR>" for directories
    dc.w    $FF09
    addq.l  #4,sp
    bra.s   .next

.print_size:
    ; --- Convert file size to decimal and print ---
    ; (For simplicity, print file size in hex using _PUTCHAR)
    move.l  filbuf+$1A,d2      ; file size (longword)
    bsr     print_hex_long

.next:
    ; --- Print newline ---
    move.w  #$0D,-(sp)
    dc.w    $FF02              ; _PUTCHAR (CR)
    addq.l  #2,sp
    move.w  #$0A,-(sp)
    dc.w    $FF02              ; _PUTCHAR (LF)
    addq.l  #2,sp

    ; --- Find next file ---
    pea     filbuf
    dc.w    $FF4F              ; _NFILES
    addq.l  #4,sp
    tst.l   d0
    bpl.s   .print_loop        ; non-negative = found another file

no_files:
    dc.w    $FF00              ; _EXIT

; ----- Subroutine: print D2.L as 8-digit hex -----
print_hex_long:
    moveq   #7,d3              ; 8 hex digits
.hex_loop:
    rol.l   #4,d2              ; rotate top nibble into low nibble
    move.l  d2,d4
    andi.w  #$0F,d4
    cmpi.w  #10,d4
    blt.s   .digit
    addi.w  #'A'-10,d4
    bra.s   .put
.digit:
    addi.w  #'0',d4
.put:
    move.w  d4,-(sp)
    dc.w    $FF02              ; _PUTCHAR
    addq.l  #2,sp
    dbra    d3,.hex_loop
    rts

    .data

header:   dc.b 'Directory listing:',$0D,$0A,0
pattern:  dc.b '*.*',0
dir_str:  dc.b '<DIR>',0

    .even

    .bss

filbuf:   ds.b 53              ; FILBUF structure

    .end    start
```

**Notes**:
- The search pattern `*.*` matches all files. Use a more specific pattern like `*.X` to filter.
- Attribute `$37` includes read-only, hidden, system, directory, and archive files.
- The packed filename at FILBUF offset `$1E` is a NUL-terminated `name.ext` string suitable for printing.
- File size at offset `$1A` is a 32-bit unsigned long.
- For production code, you would want decimal output rather than hex; the hex routine here is simpler for illustration.

---

### Floppy Disk Format

The X68000 uses a Japanese-standard 5.25-inch 2HD floppy disk format:

| Parameter | Value |
|-----------|-------|
| Disk type | 2HD (double-sided, high-density) |
| Tracks | 77 |
| Heads (sides) | 2 |
| Sectors per track | 8 |
| Bytes per sector | 1024 |
| Total capacity | 77 x 2 x 8 x 1024 = **1,261,568 bytes (1232 KiB)** |
| Rotation speed | 360 RPM |
| Data rate | 500 kbps (MFM encoding) |

This is distinct from the IBM PC 1.44 MB format (80 tracks, 2 heads, 18 sectors, 512 bytes/sector). X68000 disks are **not directly readable** on a standard PC floppy drive due to the different sector size (1024 vs 512) and track count (77 vs 80).

**Filesystem**: Human68k uses a FAT12 or FAT16 filesystem on floppy disks, compatible in structure with MS-DOS FAT but using the different physical geometry. The BPB (BIOS Parameter Block) in the boot sector describes the disk layout.

**Disk image formats**:
- **XDF**: Raw sector dump, exactly 1,261,568 bytes (77 x 2 x 8 x 1024). The most common format.
- **DIM**: Raw dump with a 256-byte header containing geometry information.
- **D88**: Multi-format archive used by various Japanese computer emulators.
- **FDI, HDM, 2HD**: Various alternative formats used by different emulators.

```bash
# Create a blank XDF disk image
dd if=/dev/zero of=blank.xdf bs=1024 count=1232
```

---

### Hard Disk Support

#### SASI (Shugart Associates System Interface) -- Early Models

The original X68000 (1987), ACE, PRO, and EXPERT models use SASI, an early predecessor of SCSI. SASI drives are typically 10 MB, 20 MB, or 40 MB in capacity and can be partitioned.

#### SCSI (MB89352) -- Later Models

Starting with the X68000 SUPER (1990), Sharp switched to a proper SCSI-1 interface using the Fujitsu **MB89352** SCSI Protocol Controller (SPC). This is memory-mapped at `$E96000-$E97FFF`.

Models with native SCSI support (no driver needed):
- X68000 SUPER
- X68000 XVI
- X68000 XVI Compact
- X68000 Compact
- X68030
- X68030 Compact

For SASI models, the community-developed **SxSI** driver provides SCSI device support through the SASI interface with appropriate hardware adapters.

Modern replacements include SCSI2SD, BlueSCSI, and RaSCSI (Raspberry Pi-based SCSI emulator), all of which allow SD cards or network storage to appear as SCSI hard drives.

---

### IOCS Disk Calls (Sector-Level I/O)

The IOCS provides low-level disk access calls that bypass the Human68k filesystem. These use `TRAP #15` with the call number in `D0.W`. Parameters are passed in other registers.

**WARNING**: These calls operate below the filesystem level. Using them on a mounted filesystem can cause data corruption if the OS has cached data in memory. Use DOS calls for normal file I/O.

| D0 (call #) | Name | Description |
|-------------|------|-------------|
| `$40` | `_B_SEEK` | Seek to track |
| `$41` | `_B_VERIFY` | Verify sectors |
| `$42` | `_B_READDI` | Read diagnostic |
| `$43` | `_B_DSKINI` | Initialize (format) a disk |
| `$44` | `_B_DRVSNS` | Get drive status |
| `$45` | `_B_WRITE` | Write sectors |
| `$46` | `_B_READ` | Read sectors |
| `$47` | `_B_RECALI` | Recalibrate (seek to track 0) |
| `$48` | `_B_ASSIGN` | Assign alternate track |
| `$4D` | `_B_FORMAT` | Format a track |

#### _B_READ ($46) -- Read Sectors

```asm
; Read sectors from disk
; D1.HB = PDA (physical device address: bits 7-4 = unit, bits 3-0 = reserved)
; D1.B  = mode (device-specific)
; D2.L  = read position (absolute byte offset from start of disk)
; D3.L  = number of bytes to read
; A1.L  = destination buffer address
;
; Returns: D0.L = status (negative = error)
; Note: D2, D3, A1 may be modified by this call

    moveq   #$46,d0             ; _B_READ
    move.l  #$90,d1             ; PDA: unit 0, floppy (example; varies)
    move.l  #0,d2               ; read position: byte 0 (first sector)
    move.l  #1024,d3            ; read 1024 bytes (one sector)
    lea     sector_buf,a1       ; destination buffer
    trap    #15
    tst.l   d0
    bmi     disk_error
```

#### _B_WRITE ($45) -- Write Sectors

```asm
; Write sectors to disk (same register convention as _B_READ)
    moveq   #$45,d0             ; _B_WRITE
    move.l  #$90,d1             ; PDA
    move.l  #1024,d2            ; write position: second sector
    move.l  #1024,d3            ; write 1024 bytes
    lea     sector_buf,a1       ; source data
    trap    #15
```

#### _B_RECALI ($47) -- Recalibrate Drive

```asm
; Seek to track 0 (recalibrate)
    moveq   #$47,d0             ; _B_RECALI
    move.l  #$90,d1             ; PDA
    trap    #15
```

---

### FDC Hardware Registers (uPD72065)

The X68000's floppy disk controller is an NEC **uPD72065** (compatible with the Intel 8272A / NEC uPD765), memory-mapped starting at `$E94000`. The FDC registers are at **odd byte addresses** (the 68000 sees them on the low byte of word reads):

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| `$E94001` | Status Register A | Read | Drive status |
| `$E94003` | Status Register B | Read | Additional status |
| `$E94005` | DOR (Digital Output Register) | Write | Drive select, motor control, DMA/reset |
| `$E94007` | Main Status Register / Data Register | R/W | Status (read) / Command/data (write) |

The FDC uses DMA (via the HD63450 DMAC at `$E84000`) for data transfer. Direct FDC programming is complex and rarely needed -- the IOCS `_B_READ`/`_B_WRITE` calls handle the FDC interaction for you.

**Note on verification**: The register addresses above are confirmed by the MAME emulator source (`src/mame/sharp/x68k.cpp`), which maps FDC read/write handlers at `$E94004-$E94007` (with the odd-byte convention making the effective register addresses `$E94005` and `$E94007`). The X68000 I/O map at Data Crystal and the memory map documentation at mijet.eludevisibility.org corroborate the `$E94000` base address for the FDC region.

**UNCERTAINTY FLAG**: The exact sub-register layout within the `$E94000-$E94007` range has been reconstructed from emulator source code (MAME, MiSTer FPGA core) rather than from original Sharp documentation. The registers follow standard uPD765-family conventions, but the specific address decoding may have minor variations from what is shown here. Consult the X68000 Technical Data Book ("Inside X68000") for definitive register assignments.

---

### Additional DOS File Operations

| Code | Name | Description |
|------|------|-------------|
| `$FF0E` | `_CHGDRV` | Change current drive: `MOVE.W #drive,-(SP)` (0=A, 1=B, ...) |
| `$FF19` | `_CURDRV` | Get current drive number (returns in D0.L) |
| `$FF39` | `_MKDIR` | Create directory: `PEA path` |
| `$FF3A` | `_RMDIR` | Remove directory: `PEA path` |
| `$FF3B` | `_CHDIR` | Change current directory: `PEA path` |
| `$FF43` | `_CHMOD` | Get/set file attributes: `MOVE.W #atr,-(SP); PEA path` (atr=-1 to read) |
| `$FF44` | `_IOCTRL` | Direct device driver I/O control (multiple sub-modes) |
| `$FF45` | `_DUP` | Duplicate file handle: `MOVE.W #handle,-(SP)` |
| `$FF46` | `_DUP2` | Force duplicate handle: `MOVE.W #new,-(SP); MOVE.W #old,-(SP)` |
| `$FF47` | `_CURDIR` | Get current directory: `PEA buf; MOVE.W #drive,-(SP)` |
| `$FF56` | `_RENAME` | Rename/move file |
| `$FF57` | `_FILEDATE` | Get/set file date and time |
| `$FF5C` | `_LOCK` | Lock/unlock file region (file locking) |

---

### Verified Sources and Confidence Notes for Disk I/O

The DOS call documentation in this section is sourced primarily from:

1. **DOS_en.txt** (mijet.eludevisibility.org) -- English translation of the official Human68k DOS call manual for version 3.02. This is the primary source for all DOS call prototypes, parameters, return values, and file handle conventions. **HIGH CONFIDENCE**.

2. **run68x source code** (github.com/kg68k/run68x, `human68k.h`) -- Error code definitions (`DOSE_*` constants) are taken directly from this Human68k CUI emulator by TcbnErik. These match the official documentation. **HIGH CONFIDENCE**.

3. **MAME emulator source** (`src/mame/sharp/x68k.cpp`) -- FDC register address mapping. **MEDIUM-HIGH CONFIDENCE** (emulator source, not original documentation).

4. **Multiple community sources** (Data Crystal wiki, GameSX wiki, ChibiAkumas tutorials) -- Cross-referenced for IOCS disk call numbers and floppy format parameters. **MEDIUM-HIGH CONFIDENCE**.

5. **Floppy format** (77/2/8/1024) -- Confirmed across Wikipedia, GameSX, Target-Earth, and multiple disk image tool repositories. **HIGH CONFIDENCE**.

Items flagged with **UNCERTAINTY FLAG** have been reconstructed from secondary sources and should be verified against the X68000 Technical Data Book for production use.
