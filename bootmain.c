// Boot loader.
//
// Part of the boot sector, along with bootasm.S, which calls bootmain().
// bootasm.S has put the processor into protected 32-bit mode.
// bootmain() loads a multiboot kernel image from the disk starting at
// sector 1 and then jumps to the kernel entry routine.

#include "types.h"
#include "x86.h"
#include "memlayout.h"

#define SECTSIZE  512

// Don't be fooled
// It says uint64 but it really isn't.
// This file is compiled in 32 bit mode, and uint64 is just a fancy
// way of saying unsigned long which is technically 32 bits :)
// That's why an uint32 pointer in bootmain!!!!!
struct mbheader {
  uint64 magic;
  uint64 flags;
  uint64 checksum;
  uint64 header_addr;
  uint64 load_addr;
  uint64 load_end_addr;
  uint64 bss_end_addr;
  uint64 entry_addr;
};

void readseg(uchar*, uint, uint);

void
bootmain(void)
{
  struct mbheader *hdr;
  void (*entry)(void);
  uint32 *x;
  uint n;

  // (TODO: 32 bit pointer used to read 64 bit values???)
  // SOLVED! See comment above mbheader struct
  x = (uint32*) 0x10000; // scratch space

  // multiboot header must be in the first 8192 bytes
  // (Suhail note):
  // How do I know which disk device to read from???
  // Definitely the same one where the bootloader is 
  // but how am I tell this to readseg????
  readseg((uchar*)x, 8192, 0);

  for (n = 0; n < 8192/4; n++)
    if (x[n] == 0x1BADB002) // See entry.S for structure of magic number and checksum
      if ((x[n] + x[n+1] + x[n+2]) == 0)
        goto found_it;

  // failure
  return;

found_it:
  hdr = (struct mbheader *) (x + n);

  if (!(hdr->flags & 0x10000))
    return; // does not have load_* fields, cannot proceed
  if (hdr->load_addr > hdr->header_addr)
    return; // invalid;
  if (hdr->load_end_addr < hdr->load_addr)
    return; // no idea how much to load

  readseg((uchar*) hdr->load_addr,
    (hdr->load_end_addr - hdr->load_addr),
    (n * 4) - (hdr->header_addr - hdr->load_addr));

  if (hdr->bss_end_addr > hdr->load_end_addr)
    stosb((void*) hdr->load_end_addr, 0,
      hdr->bss_end_addr - hdr->load_end_addr);

  entry = (void(*)(void))(hdr->entry_addr);
  entry();
}

void
waitdisk(void)
{
  while((inb(0x1F7) & 0xC0) != 0x40);
}

// Read a single sector at offset into dst.
void
readsect(void *dst, uint offset)
{
  // Issue command.
  waitdisk();
  outb(0x1F2, 1);   // count = 1
  outb(0x1F3, offset);
  outb(0x1F4, offset >> 8);
  outb(0x1F5, offset >> 16);
  outb(0x1F6, (offset >> 24) | 0xE0);
  outb(0x1F7, 0x20);  // cmd 0x20 - read sectors

  // Read data.
  waitdisk();
  insl(0x1F0, dst, SECTSIZE/4);
}

// Read 'count' bytes at 'offset' from kernel into physical address 'pa'.
// Might copy more than asked.
void
readseg(uchar* pa, uint count, uint offset)
{
  uchar* epa;

  epa = pa + count;

  // Round down to sector boundary.
  pa -= offset % SECTSIZE;

  // Translate from bytes to sectors; kernel starts at sector 1.
  offset = (offset / SECTSIZE) + 1;

  // If this is too slow, we could read lots of sectors at a time.
  // We'd write more to memory than asked, but it doesn't matter --
  // we load in increasing order.
  for(; pa < epa; pa += SECTSIZE, offset++)
    readsect(pa, offset);
}
