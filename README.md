Game Boy and Game Boy Color for MEGA65
======================================

Play [Game Boy](https://en.wikipedia.org/wiki/Game_Boy) and
[Game Boy Color](https://en.wikipedia.org/wiki/Game_Boy_Color) games on your
[MEGA65](https://mega65.org/)!

Learn more about where to [download and how to get started](#Installation).

**WARNING: Beta version 0.7 - See constraints below**

![Game Boy and Game Boy Color](doc/gb-and-gbc.jpg)

This core is based on the
[MiSTer](https://github.com/MiSTer-devel/Gameboy_MiSTer) Game Boy core which
itself is based on the
[MiST](https://github.com/mist-devel/gameboy) Game Boy core.

[sy2002](http://www.sy2002.de) ported the core to the MEGA65 in 2021.

Special thanks to [Robert Peip](https://github.com/RobertPeip)
for his invaluable support.

The core uses [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for
loading the Game Boy's BIOS as well as for the on-screen-menu and for
loading game roms.

Features
--------

* Game Boy and Game Boy Color support
* Super Gameboy Support - Borders, Palettes and Multiplayer (Work-in-Progress)
* Convenient game cartridge browser which supports long filenames
* Joystick support including special mappings so that you can for example play
  Super Mario Land via joystick
* Custom Palette Loading (Work-in-Progress)

Installation
------------

1. [Download](https://github.com/sy2002/gbc4mega65/releases/download/V0.6/bitstream-and-core.zip)
   the ZIP file that contains the bitstream and the core file and unpack it.
2. Choose the right subfolder depending on the type of your MEGA65:
   `R2` or `R3`
3. Either use MEGA65's bitstream utility (`m65 -q yourbitstream.bit`) or
   install the core file so that you can use MEGA65's <kbd>No Scroll</kbd>
   boot menu to load the core. Please have a look at the
   [MEGA65 Starter Guide](https://files.mega65.org/news/MEGA65-Starter-Guide.pdf)
   to learn more.
4. The core needs a FAT32 formatted SD card to load game cartridges (ROMs).
5. If you put your ROMs into a folder called `/gbc`, then the core will
   display this folder on startup.
6. The core includes an Open Source Game Boy BIOS. For more authenticity,
   go to https://gbdev.gg8.se/files/roms/bootroms/ and and download
   `dmg_boot.bin` and `cgb_bios.bin` and place both in the `/gbc` folder.

Constraints of the current Beta version 0.7
--------------------------------------------

* MEGA65 R2 machines: Maximum cartridge size: 256kB
* MEGA65 R3 machines: Maximum cartridge size: 1MB
* Only plays cartridges that do not need extra RAM
  in the cartridge ("Cartridge RAM")
* VGA 800x600 @ 60 Hz and audio via 3.5mm audio jack - no HDMI
* No joystick support
* No options menu, yet (no configuration possibilities such as
  "switch to Game Boy classic without color", palette switching, ...)
* In some games, there is a flickering rightmost column and/or bottom scanline
* Only shows ~200 files per folder

Some demo pictures
------------------

| ![gbc01](doc/gbc01.jpg)      | ![gbc02](doc/gbc02.jpg)     | ![gbc03](doc/gbc03.jpg)       | 
|:----------------------------:|:---------------------------:|:-----------------------------:| 
| *MEGA65 Core Selection*      | *Game Boy Core: Start*      | *Game Boy Core: File Browser* |
| ![gbc04](doc/gbc04.jpg)      | ![gbc05](doc/gbc05.jpg)     | ![gbc06](doc/gbc06.jpg)       | 
| *Game Boy Color Boot Screen* | *Super Mario Start Screen*  | *Super Mario Gameplay Screen* |

Clarification: These screenshots are just for illustration purposes.
This repository does not contain any copyrighted ROMs
such as BIOS ROMs or game ROMs.

Joystick usage and mapping
--------------------------

Basic usage: Just plug-in your joystick in port #1 or #2 of the MEGA65. Both
ports are working. By default the fire button of the joystick is mapped to the
Game Boy's A button, which should be fine for many games.

Certain games such as Castlevania and Super Mario Land are using the A button
to jump. When using a joystick, you would expect that moving the joystick up
would mean jumping. For this kind of games, this core supports a feature to
change the joystick's mapping. Press the <kbd>Help</kbd> key while the game
is running and choose `Up=A, Fire=B` as shown on the following example
screenshot.

![gbc07](doc/gbc07.jpg)

The setting `Up=A, Fire=B` works perfectly for Super Mario Land and
Castlevania and all other games that are having this "A to jump, B to fire"
kind of logic: When you move the joystick up, the "A" button is
transmitted. In parallel also the press of the GameBoy joypad's
"up" direction is transmitted in this case, so that in a game like
Castlevania you can jump when you move the joystick upwards as
well as climb upwards. The joystick movements are feeling as natural as
you would expect it.
