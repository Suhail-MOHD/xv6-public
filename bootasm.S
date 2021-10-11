#include "asm.h"
#include "memlayout.h"
#include "mmu.h"

# Start the first CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.code16                       # Assemble for 16-bit mode
.global start
start:
  cli                         # BIOS enabled interrupts; disable

  # Zero data segment registers DS, ES, and SS.
  xorw    %ax, %ax            # Set %ax to zero
  movw    %ax, %ds            # -> Data Segment
  movw    %ax, %es            # -> Extra Segment
  movw    %ax, %ss            # -> Stack Segment

  # Physical address line A20 is tied to zero so that the first PCs
  # with 2 MB would run software that assumed 1 MB.  Undo that.
  # (Suhail note):
  # In 16 bit mode on 8086, the addressing scheme takes two values
  # segment:offset
  # segment ranges from 0 -> 2^16 = 0 -> 65536
  # offset ranges from 0 -> 65536
  # largest value that can be represented by 16 * segment + offset is:
  #  - 0x10FFEF
  # whem 16 bit mode was used in processors with only 20address lines this address would become: 
  #  - 0x0FFEF (The highest bit is lost)
  #
  # But when we have systems that have more address lines emulating 16 bit mode, 0x10FFEF should continue
  # to be interpreted as Ox0FFEF instead of 0x10FFEF so that programs that use these values continue working
# This needs to be disabled when switching to 32 bit mode 
seta20.1:
  inb     $0x64, %al          # Wait for not busy
  testb   $0x2, %al
  jnz     seta20.1

  movb    $0xd1, %al          # 0xd1 -> port 0x64
  outb    %al, $0x64

seta20.2:
  inb     $0x64, %al          # Wait for not busy
  testb   $0x2, %al
  jnz     seta20.2

  movb    $0xdf, %al          # 0xdf -> port 0x60
  outb    %al, $0x60

  # Switch from real to protected mode. Use a bootstrap GDT that makes
  # virtual addresses map directly to physical addresses so that the
  # effective memory map doesn't change during the transition.
  #
  # (Suhail note):
  # CR0 control register description here (we only care about the first one):
  #   0	PE	Protected Mode Enable	If 1, system is in protected mode, else system is in real mode
  #   1	MP	Monitor co-processor	Controls interaction of WAIT/FWAIT instructions with TS flag in CR0
  #   2	EM	Emulation	If set, no x87 floating-point unit present, if clear, x87 FPU present
  #   3	TS	Task switched	Allows saving x87 task context upon a task switch only after x87 instruction used
  #   4	ET	Extension type	On the 386, it allowed to specify whether the external math coprocessor was an 80287 or 80387
  #   5	NE	Numeric error	Enable internal x87 floating point error reporting when set, else enables PC style x87 error detection
  #   16	WP	Write protect	When set, the CPU can't write to read-only pages when privilege level is 0
  #   18	AM	Alignment mask	Alignment check enabled if AM set, AC flag (in EFLAGS register) set, and privilege level is 3
  #   29	NW	Not-write through	Globally enables/disable write-through caching
  #   30	CD	Cache disable	Globally enables/disable the memory cache
  #   31	PG	Paging	If 1, enable paging and use the § CR3 register, else disable paging.
  #
  #   CR0_PE = 0x00001
  #   The first bit of the control register determines whether it is in protected mode or not
  lgdt    gdtdesc
  movl    %cr0, %eax
  orl     $CR0_PE, %eax
  movl    %eax, %cr0

  # Complete the transition to 32-bit protected mode by using a long jmp
  # to reload %cs and %eip. The segment descriptors are set up with no
  # translation, so that the mapping is still the identity mapping.
  # (Suhail notes):
  # https://stackoverflow.com/questions/48237933/after-load-the-gdt
  # TODO: Also, find docs confirming that the CPU only starts interpreting 32 bit instructions *after* an ljmp
  # TODO: Also, ljmp vs jmp, study more.
  # SEG_KCODE = 0x1, so CS = 0x08
  ljmp    $(SEG_KCODE<<3), $start32

.code32  # Tell assembler to generate 32-bit code now.
start32:
  # Set up the protected-mode data segment registers
  movw    $(SEG_KDATA<<3), %ax    # Our data segment selector
  movw    %ax, %ds                # -> DS: Data Segment
  movw    %ax, %es                # -> ES: Extra Segment
  movw    %ax, %ss                # -> SS: Stack Segment
  movw    $0, %ax                 # Zero segments not ready for use
  movw    %ax, %fs                # -> FS
  movw    %ax, %gs                # -> GS

  # Set up the stack pointer and call into C.
  movl    $start, %esp
  call    bootmain

  # If bootmain returns (it shouldn't), spin.
spin:
  jmp     spin

# Bootstrap GDT
.p2align 2                                # force 4 byte alignment
gdt:
  SEG_NULLASM                             # null seg
  SEG_ASM(STA_X|STA_R, 0x0, 0xffffffff)   # code seg
  SEG_ASM(STA_W, 0x0, 0xffffffff)         # data seg

gdtdesc:
  .word   (gdtdesc - gdt - 1)             # sizeof(gdt) - 1
  .long   gdt                             # address gdt
