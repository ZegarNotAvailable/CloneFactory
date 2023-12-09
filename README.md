# CloneFactory

I present a computer compatible with the software of the best Polish educational computer of the 1980s and 1990s - CA80. 
It is not an original or a replica, but a completely new design, using all possible features of the original. 
I have kept the numbering of elements and the names of modules to facilitate the use of the original documentation. 
All programs written for CA80 in accordance with Mr. Stanisław Gardynik's recommendations should work.


## Hardware

![Assembled modules](https://github.com/ZegarNotAvailable/CloneFactory/blob/main/HardWare/Pictures/CA80-modules.jpg)
The computer consists of RC80 standard modules. 
It is not a CP/M system, but a self-sufficient computer with a hexadecimal keyboard and a seven-segment display.
In the minimum version, 2kB EPROM and 2kB RAM are enough, but it is optimal to use the full 64kB RAM.
It is possible to build a classic version with EPROM and a CLK generator, but using an additional module with an ATmega32A microcontroller significantly increases the computer's capabilities.

### CA80-CPU module.

Includes processor and memory. The decoder is consistent with the original and divides the address space into four parts. 
By default, all memory is allocated to RAM. We can allocate one or two sixteen-kilobyte areas to EPROM, which we can insert into the U9 socket. 
If we use memory on another module, we can also disconnect it from RAM.

### CA80-SYS-I/O module.

Contains system interfaces: 
- keyboard,
- display,
- and tape recorder.

![CA80 during operation.](https://github.com/ZegarNotAvailable/CloneFactory/blob/main/HardWare/Pictures/CA80-RCbus-Flash.jpg)

## Code for CA80 with Msid

Here I collected programs found on the Internet and added my own. All of them can be freely loaded into RAM using the CA80-bootloader module.
After turning on the computer, programs are loaded according to the `CA80.txt` file, in which we provide up to five *.hex file names.
Filenames must be in 8.3 format and written without extension.
For example `ca88 CA80_N_B CA80_O_E CAFL2 msid6_4` will load the files:
`ca88.hex CA80_N_B.hex CA80_O_E.hex CAFL2.hex msid6_4.hex`
CA80_N_B.hex is mandatory because it contains procedures for operating all components.
Additionally, we have a `user.txt` file in which we can also save up to five file names.
Based on the description (MIK11), I recreated the basic functions of the program working with CA80 - MSID. It was a development tool used to debug programs.
Various versions of this tool were written for Amstrad, CP/M and IBM PC computers.
![Poor MSID version.](https://github.com/ZegarNotAvailable/CloneFactory/blob/main/HardWare/Pictures/MSid-proced-sys.jpg)
