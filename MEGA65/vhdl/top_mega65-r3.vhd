----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- R3-Version: Top Module for synthesizing the whole machine
--
-- Screen resolution:
-- VGA out runs at SVGA mode 800 x 600 @ 60 Hz. This is a compromise between
-- the optimal usage of screen real estate and compatibility to older CRTs 
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.qnice_tools.all;

entity MEGA65_R3 is
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button
   
   -- serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in std_logic;                  -- receive data
   UART_TXD       : out std_logic;                 -- send data   
        
   -- VGA
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;
   
   -- VDAC
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;
   
   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in std_logic;                  -- data input from keyboard   
   
   -- SD Card
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in std_logic;
   
   -- 3.5mm analog audio jack
   pwm_l          : out std_logic;
   pwm_r          : out std_logic;
      
   -- Joysticks
   joy_1_up_n     : in std_logic;
   joy_1_down_n   : in std_logic;
   joy_1_left_n   : in std_logic;
   joy_1_right_n  : in std_logic;
   joy_1_fire_n   : in std_logic
   
--   joy_2_up_n     : in std_logic;
--   joy_2_down_n   : in std_logic;
--   joy_2_left_n   : in std_logic;
--   joy_2_right_n  : in std_logic;
--   joy_2_fire_n   : in std_logic;
               
   -- Built-in HyperRAM
--   hr_d           : inout unsigned(7 downto 0);    -- Data/Address
--   hr_rwds        : inout std_logic;               -- RW Data strobe
--   hr_reset       : out std_logic;                 -- Active low RESET line to HyperRAM
--   hr_clk_p       : out std_logic;
   
   -- Optional additional HyperRAM in trap-door slot
--   hr2_d          : inout unsigned(7 downto 0);    -- Data/Address
--   hr2_rwds       : inout std_logic;               -- RW Data strobe
--   hr2_reset      : out std_logic;                 -- Active low RESET line to HyperRAM
--   hr2_clk_p      : out std_logic;
--   hr_cs0         : out std_logic;
--   hr_cs1         : out std_logic   
); 
end MEGA65_R3;

architecture beh of MEGA65_R3 is

-- Maximum size of cartridge ROM and RAM
-- as long as we are not yet leveraging HyperRAM, these two parameters
-- are the main distinction between the MEGA65 R2 and R3, as R3 has a much larger FPGA
constant CART_ROM_MAX_R2   : integer := 256 * 1024;
constant CART_RAM_MAX_R2   : integer := 32 * 1024;
constant CART_ROM_MAX_R3   : integer := 1024 * 1024;
constant CART_RAM_MAX_R3   : integer := 32 * 1024;

-- modes according to https://gbdev.io/pandocs/#_0148-rom-size and https://gbdev.io/pandocs/#_0149-ram-size
constant SYS_ROM_MAX_R2    : integer := 3;
constant SYS_RAM_MAX_R2    : integer := 3;
constant SYS_ROM_MAX_R3    : integer := 5;
constant SYS_RAM_MAX_R3    : integer := 3; 

-- the current system is running with these parameters
constant CART_ROM_MAX      : integer := CART_ROM_MAX_R3; 
constant CART_RAM_MAX      : integer := CART_RAM_MAX_R3;
constant SYS_ROM_MAX       : integer := SYS_ROM_MAX_R3;
constant SYS_RAM_MAX       : integer := SYS_RAM_MAX_R3;

constant CART_ROM_WIDTH    : integer := f_log2(CART_ROM_MAX);

-- ROM options
constant GBC_ORG_ROM       : string := "../../rom/cgb_bios.rom";        -- Copyrighted original GBC ROM, not checked-in into official repo
constant GBC_OSS_ROM       : string := "../../BootROMs/cgb_boot.rom";   -- Alternative Open Source GBC ROM
constant DMG_ORG_ROM       : string := "../../rom/dmg_boot.rom";        -- Copyrighted original DMG ROM, not checked-in into official repo
constant DMG_OSS_ROM       : string := "../../BootROMs/dmg_boot.rom";   -- Alternative Open Source DMG ROM

constant GBC_ROM           : string := GBC_OSS_ROM;   -- use Open Source ROMs by default
constant DMG_ROM           : string := GBC_OSS_ROM;

-- clock speeds
constant GB_CLK_SPEED      : integer := 33_554_432;
constant QNICE_CLK_SPEED   : integer := 50_000_000;

-- rendering constants
constant GB_DX             : integer := 160;          -- Game Boy's X pixel resolution
constant GB_DY             : integer := 144;          -- ditto Y
constant VGA_DX            : integer := 800;          -- SVGA mode 800 x 600 @ 60 Hz
constant VGA_DY            : integer := 600;          -- ditto
constant GB_TO_VGA_SCALE   : integer := 4;            -- 160 x 144 => 4x => 640 x 576

-- clocks
signal main_clk            : std_logic;               -- Game Boy core main clock @ 33.554432 MHz
signal vga_pixelclk        : std_logic;               -- SVGA mode 800 x 600 @ 60 Hz: 40.00 MHz
signal qnice_clk           : std_logic;               -- QNICE main clock @ 50 MHz

-- VGA signals
signal vga_disp_en         : std_logic;
signal vga_col             : integer range 0 to VGA_DX - 1;
signal vga_row             : integer range 0 to VGA_DY - 1;
signal vga_col_next        : integer range 0 to VGA_DX - 1;
signal vga_row_next        : integer range 0 to VGA_DY - 1;
signal vga_hs_int          : std_logic;
signal vga_vs_int          : std_logic;

-- Audio signals
signal pcm_audio_left      : std_logic_vector(15 downto 0);
signal pcm_audio_right     : std_logic_vector(15 downto 0);

-- debounced signals for the reset button and the joysticks; joystick signals are also inverted
signal dbnce_reset_n       : std_logic;
signal dbnce_joy1_up_n     : std_logic;
signal dbnce_joy1_down_n   : std_logic;
signal dbnce_joy1_left_n   : std_logic;
signal dbnce_joy1_right_n  : std_logic;
signal dbnce_joy1_fire_n   : std_logic;

-- Game Boy
signal is_CGB              : std_logic;
signal gbc_bios_addr       : std_logic_vector(11 downto 0);
signal gbc_bios_data       : std_logic_vector(7 downto 0);

-- LCD interface
signal lcd_clkena          : std_logic;
signal lcd_data            : std_logic_vector(14 downto 0);
signal lcd_mode            : std_logic_vector(1 downto 0);
signal lcd_mode_1          : std_logic_vector(1 downto 0);
signal lcd_on              : std_logic;
signal lcd_vsync           : std_logic;
signal lcd_vsync_1         : std_logic := '0';
signal pixel_out_x         : integer range 0 to GB_DX - 1;
signal pixel_out_y         : integer range 0 to GB_DY - 1;
signal pixel_out_data      : std_logic_vector(14 downto 0);  
signal pixel_out_we        : std_logic := '0';
signal frame_buffer_data   : std_logic_vector(14 downto 0);
 
 -- speed control
signal sc_ce               : std_logic;
signal sc_ce_2x            : std_logic;
signal HDMA_on             : std_logic;
   
-- cartridge signals
signal cart_addr           : std_logic_vector(15 downto 0);
signal cart_rd             : std_logic;
signal cart_wr             : std_logic;
signal cart_do             : std_logic_vector(7 downto 0);
signal cart_di             : std_logic_vector(7 downto 0);

-- cartridge flags
signal cart_cgb_flag       : std_logic_vector(7 downto 0);
signal cart_sgb_flag       : std_logic_vector(7 downto 0);
signal cart_mbc_type       : std_logic_vector(7 downto 0);
signal cart_rom_size       : std_logic_vector(7 downto 0);
signal cart_ram_size       : std_logic_vector(7 downto 0);
signal cart_old_licensee   : std_logic_vector(7 downto 0);

signal isGBC_Game          : boolean;     -- current cartridge is dedicated GBC game
signal isSGB_Game          : boolean;     -- current cartridge is dedicated SBC game

-- MBC signals
signal cartrom_addr        : std_logic_vector(CART_ROM_WIDTH - 1 downto 0); 
signal cartrom_rd          : std_logic;
signal cartrom_data        : std_logic_vector(7 downto 0);

-- joypad: p54 selects matrix entry and data contains either
-- the direction keys or the other buttons
signal joypad_p54          : std_logic_vector(1 downto 0);
signal joypad_data         : std_logic_vector(3 downto 0);

-- QNICE control signals
signal qngbc_reset         : std_logic;
signal qngbc_pause         : std_logic;
signal qngbc_bios_addr     : std_logic_vector(11 downto 0);
signal qngbc_bios_we       : std_logic;
signal qngbc_bios_data_in  : std_logic_vector(7 downto 0);
signal qngbc_bios_data_out : std_logic_vector(7 downto 0);
signal qngbc_cart_addr     : std_logic_vector(22 downto 0);
signal qngbc_cart_we       : std_logic;
signal qngbc_cart_data_in  : std_logic_vector(7 downto 0);
signal qngbc_cart_data_out : std_logic_vector(7 downto 0);
signal qngbc_osm_on        : std_logic;
signal qngbc_osm_rgb       : std_logic_vector(23 downto 0);
signal qngbc_keyb_matrix   : std_logic_vector(15 downto 0);

-- signals neccessary due to Verilog in VHDL embedding
-- otherwise, when wiring constants directly to the entity, then Vivado throws an error
signal i_fast_boot         : std_logic;
signal i_joystick          : std_logic_vector(7 downto 0);
signal i_reset             : std_logic;
signal i_dummy_0           : std_logic;
signal i_dummy_2bit_0      : std_logic_vector(1 downto 0);
signal i_dummy_8bit_0      : std_logic_vector(7 downto 0);
signal i_dummy_64bit_0     : std_logic_vector(63 downto 0);
signal i_dummy_129bit_0    : std_logic_vector(128 downto 0);
 
begin

   -- MMCME2_ADV clock generators:
   --    Core clock:          33.554432 MHz
   --    Pixelclock:          34.96 MHz
   --    QNICE co-processor:  50 MHz   
   clk_gen : entity work.clk_m
      port map
      (
         sys_clk_i         => CLK,
         gbmain_o          => main_clk,         -- Game Boy's 33.554432 MHz main clock
         qnice_o           => qnice_clk         -- QNICE's 50 MHz main clock
      );
   clk_pixel : entity work.clk_p
      port map
      (
         sys_clk_i         => CLK,
         pixelclk_o        => vga_pixelclk      -- 40.00 MHz pixelclock for SVGA mode 800 x 600 @ 60 Hz
      );
         
   -- signals neccessary due to Verilog in VHDL embedding
   i_fast_boot       <= '0';
   i_joystick        <= x"FF";
   i_dummy_0         <= '0';
   i_dummy_2bit_0    <= (others => '0');
   i_dummy_8bit_0    <= (others => '0');
   i_dummy_64bit_0   <= (others => '0');
   i_dummy_129bit_0  <= (others => '0');
   
   -- TODO: Achieve timing closure also when using the debouncer   
   --i_reset           <= not dbnce_reset_n;   
   i_reset           <= not RESET_N; -- TODO/WARNING: might glitch

   is_CGB <= '1';

   -- Cartridge header flags
   -- Infos taken from: https://gbdev.io/pandocs/#the-cartridge-header and from MiSTer's mbc.sv
   isGBC_Game <= true when cart_cgb_flag = x"80" or cart_cgb_flag = x"C0" else false;
   isSGB_Game <= true when cart_sgb_flag = x"03" and cart_old_licensee = x"33" else false;
         
   -- The actual machine (GB/GBC core)
   gameboy : entity work.gb
      port map
      (
         reset                   => qngbc_reset,
                     
         clk_sys                 => main_clk,
         ce                      => sc_ce,
         ce_2x                   => sc_ce_2x,
                  
         fast_boot               => i_fast_boot,
         joystick                => i_joystick,
         isGBC                   => is_CGB,
         isGBC_game              => isGBC_Game,
      
         -- Cartridge interface: Connects with the Memory Bank Controller (MBC) 
         cart_addr               => cart_addr,
         cart_rd                 => cart_rd,
         cart_wr                 => cart_wr, 
         cart_di                 => cart_di,  
         cart_do                 => cart_do,  
         
         -- Game Boy BIOS interface
         gbc_bios_addr           => gbc_bios_addr,
         gbc_bios_do             => gbc_bios_data,
               
         -- audio    
         audio_l                 => pcm_audio_left,
         audio_r                 => pcm_audio_right,
               
         -- lcd interface     
         lcd_clkena              => lcd_clkena,
         lcd_data                => lcd_data,  
         lcd_mode                => lcd_mode,  
         lcd_on                  => lcd_on,    
         lcd_vsync               => lcd_vsync, 
            
         joy_p54                 => joypad_p54,
         joy_din                 => joypad_data,
                  
         speed                   => open,   --GBC
         HDMA_on                 => HDMA_on,
                  
         -- cheating/game code engine: not supported on MEGA65 
         gg_reset                => i_reset,
         gg_en                   => i_dummy_0,
         gg_code                 => i_dummy_129bit_0,
         gg_available            => open,
            
         -- serial port: not supported on MEGA65
         sc_int_clock2           => open,
         serial_clk_in           => i_dummy_0,
         serial_clk_out          => open,
         serial_data_in          => i_dummy_0,
         serial_data_out         => open,
               
         -- MiSTer's save states & rewind feature: not supported on MEGA65
         cart_ram_size           => i_dummy_8bit_0,
         save_state              => i_dummy_0,
         load_state              => i_dummy_0,
         sleep_savestate         => open,
         savestate_number        => i_dummy_2bit_0,               
         SaveStateExt_Din        => open, 
         SaveStateExt_Adr        => open, 
         SaveStateExt_wren       => open,
         SaveStateExt_rst        => open, 
         SaveStateExt_Dout       => i_dummy_64bit_0,
         SaveStateExt_load       => open,         
         Savestate_CRAMAddr      => open,     
         Savestate_CRAMRWrEn     => open,    
         Savestate_CRAMWriteData => open,
         Savestate_CRAMReadData  => i_dummy_8bit_0,                   
         SAVE_out_Din            => open,   
         SAVE_out_Dout           => i_dummy_64bit_0,
         SAVE_out_Adr            => open,   
         SAVE_out_rnw            => open,   
         SAVE_out_ena            => open,   
         SAVE_out_done           => i_dummy_0,               
         rewind_on               => i_dummy_0,
         rewind_active           => i_dummy_0
      );

   -- Speed control is mainly a clock divider and it also manages pause/resume/fast-forward/etc.
   gb_clk_ctrl : entity work.speedcontrol
      port map
      (
         clk_sys                 => main_clk,
         pause                   => qngbc_pause,
         speedup                 => '0',
         cart_act                => cart_rd or cart_wr,
         HDMA_on                 => HDMA_on,
         ce                      => sc_ce,
         ce_2x                   => sc_ce_2x,
         refresh                 => open,
         ff_on                   => open         
      );
      
   -- Memory Bank Controller (MBC)
   gb_mbc : entity work.mbc_wrapper
      generic map
      (
         ROM_WIDTH      => CART_ROM_WIDTH
      )
      port map
      (
         -- Game Boy's clock and reset
         gb_clk                  => main_clk,
         gb_ce_2x                => sc_ce_2x,
         gb_reset                => qngbc_reset,
               
         -- Game Boy's cartridge interface
         cart_addr               => cart_addr,
         cart_rd                 => cart_rd,
         cart_wr                 => cart_wr,
         cart_do                 => cart_do,
         cart_di                 => cart_di,
         
         -- Cartridge ROM interface
         rom_addr                => cartrom_addr,
         rom_rd                  => cartrom_rd,
         rom_data                => cartrom_data,
         
         -- Cartridge flags
         cart_mbc_type           => cart_mbc_type,
         cart_rom_size           => cart_rom_size,
         cart_ram_size           => cart_ram_size                  
      );
      
   -- Convert the Game Boy's PCM output to pulse density modulation
   -- TODO: Is this component configured correctly when it comes to clock speed, constants used within
   -- the component, subtracting 32768 while converting to signed, etc.
   pcm2pdm : entity work.pcm_to_pdm
      port map
      (
         cpuclock       => qnice_clk,
         pcm_left       => signed(signed(pcm_audio_left) - 32768),
         pcm_right      => signed(signed(pcm_audio_right) - 32768),
         pdm_left       => pwm_l,
         pdm_right      => pwm_r,
         audio_mode     => '0'
      ); 
                
   -- BIOS ROM / BOOT ROM
   bios_rom : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH     => 12,
         DATA_WIDTH     => 8,
         ROM_PRELOAD    => true,       -- load default ROM in case no other ROM is on the SD card 
         ROM_FILE       => GBC_ROM,
         FALLING_B      => true        -- QNICE reads/writes on the falling clock edge
      )
      port map
      (
         -- GBC ROM interface
         clock_a        => main_clk,
         address_a      => gbc_bios_addr,
         q_a            => gbc_bios_data, 
         
         -- QNICE RAM interface 
         clock_b        => qnice_clk,
         address_b      => qngbc_bios_addr,
         data_b         => qngbc_bios_data_in,
         wren_b         => qngbc_bios_we,
         q_b            => qngbc_bios_data_out         
      );
     
   -- Cartridge ROM
   game_cart : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH        => CART_ROM_WIDTH,   -- TODO: depends on R2 vs. R3 and TODO adjust address_b
         DATA_WIDTH        => 8,
         ROM_PRELOAD       => false,
         LATCH_ADDR_A      => true,       -- the gbc core expects that the RAM latches the address on cart_rd
         FALLING_B         => true        -- QNICE reads/writes on the falling clock edge
      )
      port map
      (
         -- GBC Game Cartridge Interface
         clock_a           => main_clk,
         address_a         => cartrom_addr,
         do_latch_addr_a   => cartrom_rd,
--         data_a            => cart_di,
--         wren_a            => cart_wr,
         q_a               => cartrom_data,
         
         -- QNICE RAM interface
         clock_b           => qnice_clk,
         address_b         => qngbc_cart_addr(CART_ROM_WIDTH - 1 downto 0),
         data_b            => qngbc_cart_data_in,
         wren_b            => qngbc_cart_we,
         q_b               => qngbc_cart_data_out  
      );

   -- Dual clock & dual port RAM that acts as framebuffer: the LCD display of the gameboy is
   -- written here by the GB core (using its local clock) and the VGA/HDMI display is being fed
   -- using the pixel clock 
   frame_buffer : entity work.dualport_2clk_ram
      generic map
      ( 
         ADDR_WIDTH  => 15,
         DATA_WIDTH  => 15
      )
      port map
      (
         clock_a     => main_clk,
         address_a   => std_logic_vector(to_unsigned(pixel_out_y * GB_DX + pixel_out_x, 15)),
         data_a      => pixel_out_data,
         wren_a      => pixel_out_we,
         q_a         => open,
         
         clock_b     => vga_pixelclk,
         address_b   => std_logic_vector(to_unsigned(vga_row_next * GB_DX + vga_col_next, 15)),
         data_b      => (others => '0'),
         wren_b      => '0',
         q_b         => frame_buffer_data
      );
   
   -- Scaler: 160 x 144 => 4x => 640 x 576
   -- Scaling by 4 is a convenient special case: We just need to use a SHR operation.
   -- We are doing this by taking the bits "9 downto 2" from the current column and row.
   -- This is a hardcoded and very fast operation.
   scaler : process(vga_col, vga_row)
      variable src_x: std_logic_vector(9 downto 0);
      variable src_y: std_logic_vector(9 downto 0);
      variable dst_x: std_logic_vector(7 downto 0);
      variable dst_y: std_logic_vector(7 downto 0);
      variable dst_x_i: integer range 0 to 199;
      variable dst_y_i: integer range 0 to 149;  
   begin    
      src_x    := std_logic_vector(to_unsigned(vga_col, 10));
      src_y    := std_logic_vector(to_unsigned(vga_row, 10));      
      dst_x    := src_x(9 downto 2);
      dst_y    := src_y(9 downto 2);
      dst_x_i  := to_integer(unsigned(dst_x));
      dst_y_i  := to_integer(unsigned(dst_y));
      
      -- The dual port & dual clock RAM needs one clock cycle to provide the data. Therefore we need
      -- to always address one pixel ahead of were we currently stand      
      if dst_x_i < GB_DX - 1 then
         vga_col_next <= dst_x_i + 1;
      else
         vga_col_next <= 0;
      end if;
      
      if dst_y_i < GB_DY - 1 then
         vga_row_next <= dst_y_i + 1;
      else
         vga_row_next <= 0;
      end if;
   end process;               

   -- Generate the signals necessary to store the LCD output into the frame buffer
   lcd_to_pixels : process(main_clk)
   begin
      if rising_edge(main_clk) then
         pixel_out_we <= '0';
         lcd_vsync_1   <= lcd_vsync;
         lcd_mode_1    <= lcd_mode;
         if (lcd_on = '1') then
            if (lcd_vsync = '1' and lcd_vsync_1 = '0') then
               pixel_out_x <= 0;
               pixel_out_y <= 0;
            elsif (lcd_mode_1 /= "11" and lcd_mode = "11") then
               pixel_out_x  <= 0;
               if (pixel_out_y < GB_DY - 1) then
                  pixel_out_y <= pixel_out_y + 1;
               end if;
            elsif (lcd_clkena = '1' and sc_ce = '1') then
               if (pixel_out_x < GB_DX - 1) then
                  pixel_out_x  <= pixel_out_x + 1;
               end if;
               pixel_out_we <= '1';
            end if;
         end if;
         
         if (is_CGB = '0') then
            case (lcd_data(1 downto 0)) is
               when "00"   => pixel_out_data <= "11111" & "11111" & "11111";
               when "01"   => pixel_out_data <= "10000" & "10000" & "10000";
               when "10"   => pixel_out_data <= "01000" & "01000" & "01000";
               when "11"   => pixel_out_data <= "00000" & "00000" & "00000";
               when others => pixel_out_data <= "00000" & "00000" & "11111";
            end case;
         else
            pixel_out_data <= lcd_data(4 downto 0) & lcd_data(9 downto 5) & lcd_data(14 downto 10);
         end if;         
      end if;
   end process; 
                          
   -- MEGA65 keyboard
   kbd : entity work.keyboard
      generic map
      (
         CLOCK_SPEED       => GB_CLK_SPEED
      )
      port map
      (
         clk               => main_clk,
         kio8              => kb_io0,
         kio9              => kb_io1,
         kio10             => kb_io2,
         p54               => joypad_p54,
         joypad            => joypad_data,
         full_matrix       => qngbc_keyb_matrix
      );
   
   -- debouncer for the RESET button as well as for the joysticks:
   -- 40ms for the RESET button
   -- 5ms for any joystick direction
   -- 1ms for the fire button
   do_dbnce_reset_n : entity work.debounce
      generic map(clk_freq => GB_CLK_SPEED, stable_time => 40)
      port map (clk => main_clk, reset_n => '1', button => RESET_N, result => dbnce_reset_n);
   do_dbnce_joysticks : entity work.debouncer
      generic map
      (
         CLK_FREQ             => GB_CLK_SPEED
      )
      port map
      (
         clk                  => main_clk,
         reset_n              => RESET_N,

         joy_1_up_n           => joy_1_up_n,
         joy_1_down_n         => joy_1_down_n, 
         joy_1_left_n         => joy_1_left_n, 
         joy_1_right_n        => joy_1_right_n, 
         joy_1_fire_n         => joy_1_fire_n, 
           
         dbnce_joy1_up_n      => dbnce_joy1_up_n,
         dbnce_joy1_down_n    => dbnce_joy1_down_n,
         dbnce_joy1_left_n    => dbnce_joy1_left_n,
         dbnce_joy1_right_n   => dbnce_joy1_right_n,
         dbnce_joy1_fire_n    => dbnce_joy1_fire_n
      );

   -- SVGA mode 800 x 600 @ 60 Hz  
   -- Component that produces VGA timings and outputs the currently active pixel coordinate (row, column)      
   -- Timings taken from http://tinyvga.com/vga-timing/800x600@60Hz
   vga_pixels_and_timing : entity work.vga_controller
      generic map
      (
         h_pixels    => VGA_DX,           -- horiztonal display width in pixels
         v_pixels    => VGA_DY,           -- vertical display width in rows
         
         h_pulse     => 128,              -- horiztonal sync pulse width in pixels
         h_bp        => 88,               -- horiztonal back porch width in pixels
         h_fp        => 40,               -- horiztonal front porch width in pixels
         h_pol       => '1',              -- horizontal sync pulse polarity (1 = positive, 0 = negative)
         
         v_pulse     => 4,                -- vertical sync pulse width in rows
         v_bp        => 23,               -- vertical back porch width in rows
         v_fp        => 1,                -- vertical front porch width in rows
         v_pol       => '1'               -- vertical sync pulse polarity (1 = positive, 0 = negative)         
      )
      port map
      (
         pixel_clk   =>	vga_pixelclk,     -- pixel clock at frequency of VGA mode being used
         reset_n     => dbnce_reset_n,    -- active low asycnchronous reset
         h_sync      => vga_hs_int,       -- horiztonal sync pulse
         v_sync      => vga_vs_int,       -- vertical sync pulse
         disp_ena    => vga_disp_en,      -- display enable ('1' = display time, '0' = blanking time)
         column      => vga_col,          -- horizontal pixel coordinate
         row         => vga_row,          -- vertical pixel coordinate
         n_blank     => open,             -- direct blacking output to DAC
         n_sync      => open              -- sync-on-green output to DAC      
      );
   
   video_signal_latches : process(vga_pixelclk)
   begin
      if rising_edge(vga_pixelclk) then 
         if vga_disp_en then
            -- Game Boy output
            if vga_col < GB_DX * GB_TO_VGA_SCALE and vga_row < GB_DY * GB_TO_VGA_SCALE then
               VGA_RED   <= frame_buffer_data(14 downto 10) & "000";
               VGA_GREEN <= frame_buffer_data(9 downto 5) & "000";
               VGA_BLUE  <= frame_buffer_data(4 downto 0) & "000";
            end if;       
         
            -- On-Screen-Menu (OSM) output
            if qngbc_osm_on then
               VGA_RED   <= qngbc_osm_rgb(23 downto 16);
               VGA_GREEN <= qngbc_osm_rgb(15 downto 8);
               VGA_BLUE  <= qngbc_osm_rgb(7 downto 0);                  
            end if;

         -- for some reason, the VDAC does not like non-zero values outside the visible window
         -- maybe "vdac_sync_n <= '0';" activates sync-on-green?
         -- TODO: check that
         else
            VGA_RED   <= (others => '0');
            VGA_BLUE  <= (others => '0');
            VGA_GREEN <= (others => '0');
         end if;
                        
         -- VGA horizontal and vertical sync
         VGA_HS      <= vga_hs_int;
         VGA_VS      <= vga_vs_int;         
      end if;
   end process;
        
   -- make the VDAC output the image    
   vdac_sync_n <= '0';
   vdac_blank_n <= '1';   
   vdac_clk <= not vga_pixelclk; -- inverting the clock leads to a sharper signal for some reason
   
   -- QNICE Co-Processor (System-on-a-Chip) for ROM loading and On-Screen-Menu
   QNICE_SOC : entity work.QNICE
      generic map
      (
         VGA_DX            => VGA_DX,
         VGA_DY            => VGA_DY,
         MAX_ROM           => SYS_ROM_MAX,
         MAX_RAM           => SYS_RAM_MAX
      )
      port map
      (
         CLK50             => qnice_clk,        -- 50 MHz clock                                    
         RESET_N           => RESET_N,
         
         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1
         UART_RXD          => UART_RXD,         -- receive data
         UART_TXD          => UART_TXD,         -- send data   
                 
         -- SD Card
         SD_RESET          => SD_RESET,
         SD_CLK            => SD_CLK,
         SD_MOSI           => SD_MOSI,
         SD_MISO           => SD_MISO,
         
         -- keyboard interface
         full_matrix       => qngbc_keyb_matrix,
         
         -- VGA interface
         pixelclock        => vga_pixelclk,
         vga_x             => vga_col,
         vga_y             => vga_row,
         vga_on            => qngbc_osm_on,
         vga_rgb           => qngbc_osm_rgb,
                  
         -- Game Boy control
         gbc_reset         => qngbc_reset,
         gbc_pause         => qngbc_pause,
         
         -- Interfaces to Game Boy's RAMs (MMIO):
         gbc_bios_addr     => qngbc_bios_addr,
         gbc_bios_we       => qngbc_bios_we,
         gbc_bios_data_in  => qngbc_bios_data_in,
         gbc_bios_data_out => qngbc_bios_data_out,
         gbc_cart_addr     => qngbc_cart_addr,
         gbc_cart_we       => qngbc_cart_we,
         gbc_cart_data_in  => qngbc_cart_data_in,
         gbc_cart_data_out => qngbc_cart_data_out,
         
         -- Cartridge flags
         cart_cgb_flag     => cart_cgb_flag,
         cart_sgb_flag     => cart_sgb_flag,
         cart_mbc_type     => cart_mbc_type,
         cart_rom_size     => cart_rom_size,
         cart_ram_size     => cart_ram_size,
         cart_old_licensee => cart_old_licensee                   
      );   
end beh;
