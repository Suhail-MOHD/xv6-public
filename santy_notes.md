## Pre - Kernel
    • Bios loads the first sector of the code - 512 Bytes from the disk and loads to 0x7c00;
	• Change to 32 bit protected mode.
		○ Load the GDT table.
		○ Set the segment registers.
		○ Call bootmain
	• In bootmain, Read the later headers from the disk.
	• Get the entry point, move to it.
	• Set the bootstrap page tables.
	• Page table address starts at 1000 and size -> 8192.
	• Set the first and the 256th entry to the first entry of PDPT.
	• Load GDT
	• Load the 0x1000 to cr3
	• Jump to main


## Main:

- Memory freed(made available) from end to 4MB.
- Two pages created in the memory freed. One for PML and One for PDPT.
- PML[256] -> PDPT[0] -> 0. Flat mapping from this node. No more further layers.
- Detect the number of CPUs and populate nCPUs.
- Setup the interrupt vector table.
- Setup the TSS - Processor specific information.
- Start the other processor?
- Free pages in memory from end to the physical memory end.
- Create the first process.
- Set the process members
    § Set the process state to EMBRYO
    § Allocate Kernel stack
    § Setup trapframe in kernel stack
    § Setup trapret
    § Setup forkret
    § Setup context
		○ Setup the page directory with the kernel address mentioned
			§ Kernel address - the first address points to 0
- Create pages for the first process in the page dir and move the contents to the kalloc'ed address

## Homework2


- Objective is to move a string to the text buffer and switch to video mode and put in the cover image that you have appended in the image (After the bootloader)
- Set ah = 0x0e and al carries the text character. 
- To print it out, call the bios interrupt -> int 10h
- For video mode,
- Set it to video mode. set ah = 0x00 and call 10h
- Read the bytes from disk to memory.
    + Use 13h interrupt.
    + ah = 42h function for reading.
    + dl = 80 => first disk
    + ds:si to point to the address where config is mentioned.
    + config
        + No of sectors = 64k/512
        + Address to where it should be written
        + Which sector to start reading from?
    + call 13h to finish reading.
    + This will display the image
- To wait for a key press, use 16h, ah=00h function.


## Homework 3

- Objective: To write to console with different colors and display image with changing colors.
- Brief intro to VGA:
    + VGA configuration is controlled by VGA registers which can be controlled by inb and outb instructions.
    + VGA has 4 planes of memory, which can be selected by VGA register.
    + For text mode, we need to write to the last plane.
    + For video mode, we need to switch to video mode - Which is done through?
    + You can read and also write the palette values through a VGA register.
- For changing color, we use the prettyprint user program.
- How does the user program change the colors?
- They open the console and the README text.
- They use ioctl to control the colour of the text, use printf to print the text to any of the file descriptors(stdout, stderr)
- What does ioctl system call do?
    + ioctl takes file descriptor, parameter, and value as arguments.
    + if the file's inode device major value is CONSOLE, you call consoleioctl/ make it like devsw[ip->major].consoleioctl(param, value)
    + In consoleioctl, we set the global - consputc from cprintf and as well as for sys_write


## Homework 4


- Objective: To make sys_mmap work. mmap has two options: eager and lazy. Eager is when the whole file that you want to map is mapped to memory, Lazy is when you map when the address is being accessed.
- Every process has an additional structure that stores the mmap start region and an integer storing no of mmaps, and an addr value to the mmaptop.
- For eager, what we need to do is, when sys_mmap is called, get the file size, create appropriate number of pages(using pgroundup), add to the page directory using mappages, return the base.
- For lazy, store the request in the mmaps and increase the mmaptop and return the mmapbase. and when the virtual address is called, the trap is triggered and the pagefault handling should check if the address is within the range of to-be-allocated addresses and if present, allocate a page and put the contents from the page starting from the file to the allocated page. the contents are read through readi(readinode) (inode retireved using file's(fd is present in the file structure of proc -mmap) inode) using the offset derived from address - base of mmap.

## Creation of first process

- Before the creation of first process, everything is done in the kernel stack.
- Userinit is called later.
- you get _binary_initcode_start, _binary_initcode_size through linker.
- allocproc is called
    + it takes an unused 



## MPMAIN - Code common for all the CPUs

- Init syscalls
- Init idt
- Run the scheduler
- What does the scheduler do?
    + acquires ptable lock.
    + Loops over the ptable and if there is a RUNNABLE process, switches to it.
    + Picks the P, sets cr3 to process's page table, SP still in main's SP; IP in Scheduler.
    + Calls swtch with arguments as cpu's scheduler - context address, p->context.
    + Calling swtch loads the next intruction address to SP, loads the callee registers to scheduler (the first argument)
    + Switches to the SP(p->context) and stores the callee registers from the p->context and returns, which picks the rip of the stack which was forkret. 
    + forkret releases the lock held by the scheduler.
    + returns to trapret.
    + trapret stores the all the register values from the trapframe, sets the stackpointer to user stack pointer and uses return to getback to the user program


TODO:

1. Do a diagram of memory layout with regions annotated.
2. Take printout of/notedown the 4 level page table 
2. Read more about mpinit
3. Read start others
4. Finish hw2 - from changing palette.
5. Remember/Note down the register indexes. 
6. Get into the detailes of hw3 and hw4.
7. Read about sysinit
8. Read about IDT initialisation
9. Read about the init process
10. Read about sleep and wakeup
11. Bring pencil, sharpner, eraser.
