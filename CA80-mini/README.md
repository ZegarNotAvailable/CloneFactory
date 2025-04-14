# CA80-mini

I show a computer compatible with the software of the best Polish educational computer of the 1980s and 1990s - CA80. 
It is not an original or a replica, but a completely new design, using all possible features of the original. 
I have kept the numbering of elements and the names of modules to facilitate the use of the original documentation. 
All programs written for CA80 in accordance with Mr. Stanisław Gardynik's recommendations should work.


## Hardware

![Assembled modules](https://github.com/ZegarNotAvailable/CloneFactory/blob/main/CA80-mini/HW/Pics/KlonCA80-ready.jpg)

It is not a CP/M system, but a self-sufficient computer with a hexadecimal keyboard and a seven-segment display.
In the minimum version, 2kB EPROM and 2kB RAM are enough, but it is optimal to use the full 64kB RAM.
It is possible to build a classic version with EPROM and a CLK generator, but using an additional module with an ATmega32A microcontroller significantly increases the computer's capabilities.

### CA80-mini.

It's MIK90 equivalent. Includes processor and memory. The decoder is consistent with the original and divides the address space into four parts. 
By default, all memory is allocated to RAM. We can allocate one or two sixteen-kilobyte areas to EPROM, which we can insert into the U9 socket. 

Contains system interfaces: 
- keyboard,
- display,
- and tape recorder.

### MIK89 module.

The original only included the i8255 and Z80 CTC. On the edge was a ZS connector containing signals for use outside the motherboard. 
Soldering points scattered throughout the board were connected with wires to a male DB50 called ZU50.
In the new version CA80 (1989 - 1990) these chips were moved to the motherboard and ZU64 was added.

Clone takes this change. I also added a CLK generator and an NMI divider, which did not fit on the CA80-CPU.
They are not needed when we use the CA80-bootloader module.

- CLK was originally 4 MHz. This is important in tape recorder operating procedures. We can use a different frequency with some restrictions.
- NMI is the computer's most important signal. In the original it was 500 Hz and that's what it should always be.
  As the name suggests, this signal reports a non-maskable interrupt, which:
  - displays successive display digits multiplexed.
  - Checks if the "M" key has been pressed.
  - Counts down seconds, minutes, hours... years in RTC.
 
### CA80-multi module.

This is an extended replacement for MIK89. Adapted to the CA80-mini format, it allows you to build a "sandwich" computer.

![CA80-multi](https://github.com/ZegarNotAvailable/CloneFactory/blob/main/CA80-mini/HW/Pics/CA-MULTI-ASEMBLED.jpg)

Includes:
- 8255,
- Z80CTC,
- 4 MHz generator,
- NMI divider,
- ZU64 connector,
- Z80SIO,
- 2.4576 MHz generator,
- Port A and Port B serial connectors,
- LCD display interface (HD44780).

### Software.

File CA80-MLT.HEX (Code-HEX/CA80-MLT.HEX)

In addition to the basic CA80 monitor (MIK290), full "tape recorder" software with functions supporting HEX files, redirected from 2000H. 
You can load it from SD card using CA80-boot module, or program EPROM. It also works without "flash" module.

![CA80 big sandwich.](https://github.com/ZegarNotAvailable/CloneFactory/blob/main/CA80-mini/HW/Pics/Kanapka-big.jpg)

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
