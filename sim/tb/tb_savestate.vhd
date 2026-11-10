-- n64top savestate test: load a hand made state with a MIPS test program, save, let it continue, check continuity
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_savestate is
end entity;

architecture sim of tb_savestate is

   -- sparse 64 bit memory, 4096 word pages
   type t_page is array(0 to 4095) of std_logic_vector(63 downto 0);
   type p_page is access t_page;
   type t_dir is array(0 to 8191) of p_page;

   type t_mem is protected
      procedure write(addr : natural; data : std_logic_vector(63 downto 0); be : std_logic_vector(7 downto 0));
      impure function read(addr : natural) return std_logic_vector;
   end protected;
   type t_mem is protected body
      variable dir : t_dir := (others => null);
      procedure write(addr : natural; data : std_logic_vector(63 downto 0); be : std_logic_vector(7 downto 0)) is
         variable p : natural := addr / 4096;
      begin
         if (dir(p) = null) then dir(p) := new t_page'(others => (others => '0')); end if;
         for i in 0 to 7 loop
            if (be(i) = '1') then dir(p)(addr mod 4096)(i*8+7 downto i*8) := data(i*8+7 downto i*8); end if;
         end loop;
      end procedure;
      impure function read(addr : natural) return std_logic_vector is
         variable p : natural := addr / 4096;
      begin
         if (dir(p) = null) then return x"0000000000000000"; end if;
         return dir(p)(addr mod 4096);
      end function;
   end protected body;

   shared variable ddr : t_mem;
   shared variable sdr : t_mem;

   signal clk1x  : std_logic := '1';
   signal clk93  : std_logic := '1';
   signal clk2x  : std_logic := '1';
   signal reset  : std_logic := '1';

   signal save_state : std_logic := '0';
   signal load_state : std_logic := '0';

   signal ddr3_BUSY       : std_logic := '0';
   signal ddr3_DOUT       : std_logic_vector(63 downto 0) := (others => '0');
   signal ddr3_DOUT_READY : std_logic := '0';
   signal ddr3_BURSTCNT   : std_logic_vector(7 downto 0);
   signal ddr3_ADDR       : std_logic_vector(28 downto 0);
   signal ddr3_DIN        : std_logic_vector(63 downto 0);
   signal ddr3_BE         : std_logic_vector(7 downto 0);
   signal ddr3_WE         : std_logic;
   signal ddr3_RD         : std_logic;

   signal sdram_ena          : std_logic;
   signal sdram_rnw          : std_logic;
   signal sdram_Adr          : std_logic_vector(26 downto 0);
   signal sdram_be           : std_logic_vector(3 downto 0);
   signal sdram_dataWrite    : std_logic_vector(31 downto 0);
   signal sdram_reqprocessed : std_logic := '0';
   signal sdram_done         : std_logic := '0';
   signal sdram_dataRead     : std_logic_vector(31 downto 0) := (others => '0');

   constant SLOT : natural := 16#C000000# / 8;

   -- log values written by the program
   signal lastLog    : integer := 0;
   signal logCount   : integer := 0;
   signal lastIrq    : integer := 0;
   signal errors     : integer := 0;
   signal cycle      : integer := 0;
   signal logReset   : std_logic := '0';
   signal irqPreset  : integer := 0;
   signal engineBusy : std_logic := '0';


   function be32(w : std_logic_vector(63 downto 0); lane : natural) return integer is
      variable v : std_logic_vector(31 downto 0);
   begin
      v := w(lane*8+7 downto lane*8) & w(lane*8+15 downto lane*8+8) & w(lane*8+23 downto lane*8+16) & w(lane*8+31 downto lane*8+24);
      return to_integer(signed(v));
   end function;

begin

   clk2x <= not clk2x after 4 ns;
   clk1x <= not clk1x after 8 ns;
   clk93 <= not clk93 after 5333 ps;

   process (clk1x) begin if rising_edge(clk1x) then cycle <= cycle + 1; end if; end process;

   dut : entity work.n64top
   generic map (use2Xclock => '1', is_simu => '1')
   port map
   (
      clk1x => clk1x, clk93 => clk93, clk2x => clk2x, clkvid => clk1x,
      reset => reset, softreset => '0', pause => '0', errorCodesOn => '0', fpscountOn => '0',
      REGION => "00", FIXEDBLANKS => '0', CROPVERTICAL => "00",
      VI_BILINEAROFF => '0', VI_DEBLUR => '0', VI_GAMMAOFF => '0', VI_DEDITHEROFF => '0', VI_DEDITHERFORCE => '0',
      VI_AAOFF => '0', VI_DIVOTOFF => '0', VI_NOISEOFF => '0', VI_7BITPERCOLOR => '0', VI_DIRECTFBMODE => '0',
      CICTYPE => "0000", RAMSIZE8 => '1', FASTRAM => '0', FASTROM => '0',
      INSTRCACHEON => '1', DATACACHEON => '1', DATACACHESLOW => "0000", DATACACHEFORCEWEB => '0', DATACACHETLBON => '1',
      RANDOMMISS => "0000", DISABLE_BOOTCOUNT => '0', DISABLE_DTLBMINI => '0', DDR3SLOW => "0000",
      DISABLEFILTER => '0', DISABLEDITHER => '0', DISABLELOD => '0',
      write9 => '1', read9 => '1', wait9 => '1', writeZ => '1', readZ => '1',
      increaseSSHeaderCount => '1', save_state => save_state, load_state => load_state, savestate_number => 0,
      state_loaded => open,
      pifrom_wraddress => (others => '0'), pifrom_wrdata => (others => '0'), pifrom_wren => '0',
      ddr3_BUSY => ddr3_BUSY, ddr3_DOUT => ddr3_DOUT, ddr3_DOUT_READY => ddr3_DOUT_READY, ddr3_BURSTCNT => ddr3_BURSTCNT,
      ddr3_ADDR => ddr3_ADDR, ddr3_DIN => ddr3_DIN, ddr3_BE => ddr3_BE, ddr3_WE => ddr3_WE, ddr3_RD => ddr3_RD,
      cartAvailable => '1', romcopy_start => '0', romcopy_size => (others => '0'),
      ddDiskAvailable => '0', ddIplAvailable => '0', ddDevMode => '0', hpsRTC => (others => '0'),
      sdram_ena => sdram_ena, sdram_rnw => sdram_rnw, sdram_Adr => sdram_Adr, sdram_be => sdram_be, sdram_dataWrite => sdram_dataWrite,
      sdram_reqprocessed => sdram_reqprocessed, sdram_done => sdram_done, sdram_dataRead => sdram_dataRead,
      PADTYPE0 => "001", PADTYPE1 => "001", PADTYPE2 => "001", PADTYPE3 => "001", MOUSETYPE => "000", PADDPADSWAP => '0',
      rumble => open,
      pad_A => "0000", pad_B => "0000", pad_Z => "0000", pad_START => "0000",
      pad_DPAD_UP => "0000", pad_DPAD_DOWN => "0000", pad_DPAD_LEFT => "0000", pad_DPAD_RIGHT => "0000",
      pad_L => "0000", pad_R => "0000", pad_C_UP => "0000", pad_C_DOWN => "0000", pad_C_LEFT => "0000", pad_C_RIGHT => "0000",
      pad_0_analog_h => x"00", pad_0_analog_v => x"00", pad_1_analog_h => x"00", pad_1_analog_v => x"00",
      pad_2_analog_h => x"00", pad_2_analog_v => x"00", pad_3_analog_h => x"00", pad_3_analog_v => x"00",
      MouseEvent => '0', MouseLeft => '0', MouseRight => '0', MouseMiddle => '0', MouseX => (others => '0'), MouseY => (others => '0'),
      KeyboardPS2Key => (others => '0'), KeyBoardLED => open, PIFCOMPARE => '0',
      snac => open, command_startSNAC => open, command_padindexSNAC => open, command_sendCntSNAC => open, command_receiveCntSNAC => open,
      toPad_enaSNAC => open, toPad_dataSNAC => open, toPad_readySNAC => '0', toPIF_timeoutSNAC => '0', toPIF_enaSNAC => '0', toPIF_dataSNAC => x"00",
      DISABLE_AI => '1', DISABLE_AI_IRQ => '1', sound_out_left => open, sound_out_right => open,
      SAVETYPE => "000", CONTROLLERPAK => '0', TRANSFERPAK => '0', save => '0', load => '0', mounted => '0',
      changePending => open, save_ongoing => open, save_rd => open, save_wr => open, save_lba => open,
      save_ack => '0', save_write => '0', save_addr => x"00", save_dataIn => x"0000", save_dataOut => open,
      video_hsync => open, video_vsync => open, video_hblank => open, video_vblank => open, video_ce => open, video_interlace => open,
      video_r => open, video_g => open, video_b => open, video_FB_en => open, video_FB_base => open, video_FB_sizeX => open, video_FB_sizeY => open
   );

   -- DDR3: never busy, write bursts beat by beat, reads answered after a short latency
   process (clk2x)
      type t_rq is array(0 to 63) of natural;
      variable wrBase, wrIdx, wrRemain : natural := 0;
      variable rdAddr, rdRemain, rdWait : natural := 0;
      variable rqA, rqN : t_rq;
      variable rqHead, rqTail : natural := 0;
      variable a : natural;
      variable w : std_logic_vector(63 downto 0);
   begin
      if rising_edge(clk2x) then
         ddr3_DOUT_READY <= '0';
         if (logReset = '1') then
            lastLog <= 0;
            lastIrq <= irqPreset;
         end if;
         if (ddr3_WE = '1') then
            if (wrRemain = 0) then
               wrBase   := to_integer(unsigned(ddr3_ADDR(24 downto 0)));
               wrRemain := to_integer(unsigned(ddr3_BURSTCNT));
               wrIdx    := 0;
            end if;
            a := wrBase + wrIdx;
            ddr.write(a, ddr3_DIN, ddr3_BE);
            w := ddr.read(a);
            -- program log: phys 0x500 = word 0xA0 lanes 0..3, irq count 0x508, error flag 0x600
            if (engineBusy = '0' and a = 16#A0# and ddr3_BE(3 downto 0) /= "0000") then
               if (lastLog /= 0 and be32(w, 0) /= lastLog + 1) then
                  report "LOG DISCONTINUITY: " & integer'image(lastLog) & " -> " & integer'image(be32(w, 0)) & " at cycle " & integer'image(cycle) severity error;
                  errors <= errors + 1;
               end if;
               lastLog  <= be32(w, 0);
               logCount <= logCount + 1;
            end if;
            if (engineBusy = '0' and a = 16#A1# and ddr3_BE(3 downto 0) /= "0000") then
               if (be32(w, 0) /= lastIrq + 1) then
                  report "IRQ COUNT DISCONTINUITY: " & integer'image(lastIrq) & " -> " & integer'image(be32(w, 0)) severity error;
                  errors <= errors + 1;
               end if;
               lastIrq <= be32(w, 0);
            end if;
            if (engineBusy = '0' and a = 16#C0# and ddr3_BE(3 downto 0) /= "0000") then
               report "PROGRAM DATA CHECK FAILED at loop " & integer'image(be32(w, 0)) & " cycle " & integer'image(cycle) severity error;
               errors <= errors + 1;
            end if;
            wrIdx    := wrIdx + 1;
            wrRemain := wrRemain - 1;
         end if;
         if (ddr3_RD = '1') then
            rqA(rqTail) := to_integer(unsigned(ddr3_ADDR(24 downto 0)));
            rqN(rqTail) := to_integer(unsigned(ddr3_BURSTCNT));
            rqTail := (rqTail + 1) mod 64;
         end if;
         if (rdRemain = 0 and rqHead /= rqTail) then
            rdAddr   := rqA(rqHead);
            rdRemain := rqN(rqHead);
            rqHead   := (rqHead + 1) mod 64;
            rdWait   := 6;
         elsif (rdRemain > 0) then
            if (rdWait > 0) then
               rdWait := rdWait - 1;
            else
               ddr3_DOUT       <= ddr.read(rdAddr);
               ddr3_DOUT_READY <= '1';
               rdAddr          := rdAddr + 1;
               rdRemain        := rdRemain - 1;
            end if;
         end if;
      end if;
   end process;

   -- SDRAM: request accepted next cycle, done three cycles later
   process (clk1x)
      type t_pipe is array(0 to 3) of std_logic;
      variable p_done : t_pipe := (others => '0');
      variable p_addr : natural;
      variable p_rnw  : std_logic;
   begin
      if rising_edge(clk1x) then
         sdram_reqprocessed <= '0';
         sdram_done         <= p_done(3);
         p_done(3) := p_done(2); p_done(2) := p_done(1); p_done(1) := p_done(0); p_done(0) := '0';
         if (sdram_ena = '1') then
            sdram_reqprocessed <= '1';
            p_done(0) := '1';
            p_addr := to_integer(unsigned(sdram_Adr(26 downto 2)));
            p_rnw  := sdram_rnw;
            if (sdram_rnw = '0') then
               sdr.write(p_addr, x"00000000" & sdram_dataWrite, "0000" & sdram_be);
            end if;
            sdram_dataRead <= sdr.read(p_addr)(31 downto 0);
         end if;
      end if;
   end process;

   process
      file f : text;
      variable l : line;
      variable idx : integer;
      variable v : std_logic_vector(63 downto 0);
      variable hdr0 : std_logic_vector(63 downto 0);
      variable logAtSave : integer;
      procedure waitc(n : natural) is begin for i in 1 to n loop wait until rising_edge(clk1x); end loop; end procedure;
      alias ss_pause   is << signal .tb_savestate.dut.savestate_pause : std_logic >>;
      alias ss_hold    is << signal .tb_savestate.dut.ss_holdCPU : std_logic >>;
      alias ss_held    is << signal .tb_savestate.dut.ss_cpuHeld : std_logic >>;
      alias ss_flush   is << signal .tb_savestate.dut.ss_flush : std_logic >>;
      alias ss_flushD  is << signal .tb_savestate.dut.ss_flushDone : std_logic >>;
      alias ss_sysIdle is << signal .tb_savestate.dut.ss_systemIdle : std_logic >>;
      alias ss_busy    is << signal .tb_savestate.dut.savestate_busy : std_logic >>;
   begin
      file_open(f, "image.txt", read_mode);
      while not endfile(f) loop
         readline(f, l); read(l, idx); hread(l, v);
         ddr.write(idx, v, x"FF");
      end loop;
      file_close(f);
      report "image loaded";

      waitc(20); reset <= '0';
      waitc(30000);
      report "load state, busy=" & std_logic'image(ss_busy);
      load_state <= '1'; waitc(4); load_state <= '0';
      waitc(100);
      wait until ss_busy = '0' and rising_edge(clk1x);
      report "state loaded at cycle " & integer'image(cycle);
      waitc(40000);
      report "running: log=" & integer'image(lastLog) & " irq=" & integer'image(lastIrq) & " logwrites=" & integer'image(logCount);
      assert lastLog > 10 report "program not running" severity failure;
      assert lastIrq > 2 report "no interrupts" severity failure;

      -- save
      hdr0 := ddr.read(SLOT);
      save_state <= '1'; waitc(4); save_state <= '0';
      wait until ss_hold = '1';
      report "hold requested at cycle " & integer'image(cycle);
      wait until ss_held = '1';
      report "cpu held at cycle " & integer'image(cycle) & " log=" & integer'image(lastLog);
      logAtSave := lastLog;
      wait until ss_flush = '1';
      report "flush at cycle " & integer'image(cycle);
      wait until ss_pause = '1';
      report "paused at cycle " & integer'image(cycle) & " log=" & integer'image(lastLog);
      assert lastLog = logAtSave report "program ran while held" severity error;
      wait until ss_busy = '0' and rising_edge(clk1x);
      report "save and reload done at cycle " & integer'image(cycle);
      v := ddr.read(SLOT);
      report "header " & to_hstring(v) & " (before " & to_hstring(hdr0) & ")";
      assert v(63 downto 32) = std_logic_vector(to_unsigned(4194302, 32)) report "wrong header size" severity error;
      assert unsigned(v(31 downto 0)) = unsigned(hdr0(31 downto 0)) + 1 report "header count not increased" severity error;
      report "saved PC " & to_hstring(ddr.read(SLOT + 16384)) & " SR " & to_hstring(ddr.read(SLOT + 16384 + 64 + 12)) &
             " s0 " & to_hstring(ddr.read(SLOT + 16384 + 32 + 16)) & " CAUSE " & to_hstring(ddr.read(SLOT + 16384 + 64 + 13));

      waitc(40000);
      report "after save: log=" & integer'image(lastLog) & " irq=" & integer'image(lastIrq);
      assert lastLog > logAtSave + 10 report "program did not continue after save" severity error;

      -- second save
      save_state <= '1'; waitc(4); save_state <= '0';
      waitc(100);
      wait until ss_busy = '0' and rising_edge(clk1x);
      waitc(30000);
      report "after second save: log=" & integer'image(lastLog) & " irq=" & integer'image(lastIrq);

      -- load the saved state again: the program goes back to the saved loop count
      logAtSave := to_integer(unsigned(ddr.read(SLOT + 16384 + 32 + 16)));
      v := ddr.read(SLOT + 1048576 + 16#A1#);
      irqPreset <= be32(v, 0);
      logReset  <= '1'; waitc(2); logReset <= '0';
      report "final load from PC " & to_hstring(ddr.read(SLOT + 16384));
      load_state <= '1'; waitc(4); load_state <= '0';
      wait until ss_busy = '0' and rising_edge(clk1x);
      waitc(30000);
      report "after load: log=" & integer'image(lastLog) & " (saved s0 " & integer'image(logAtSave) & ") irq=" & integer'image(lastIrq);

      assert lastLog > logAtSave report "program did not run after loading the slot" severity error;
      report "DONE errors=" & integer'image(errors);
      assert errors = 0 report "SAVESTATE TEST FAILED" severity failure;
      std.env.stop;
   end process;


   -- engine writes are not program writes
   process (clk1x)
      alias p is << signal .tb_savestate.dut.savestate_pause : std_logic >>;
   begin
      if rising_edge(clk1x) then engineBusy <= p or reset; end if;
   end process;

   -- progress
   process
      alias ss_pause   is << signal .tb_savestate.dut.savestate_pause : std_logic >>;
      alias ss_hold    is << signal .tb_savestate.dut.ss_holdCPU : std_logic >>;
      alias ss_held    is << signal .tb_savestate.dut.ss_cpuHeld : std_logic >>;
      alias ss_flush   is << signal .tb_savestate.dut.ss_flush : std_logic >>;
      alias ss_flushD  is << signal .tb_savestate.dut.ss_flushDone : std_logic >>;
      alias ss_sysIdle is << signal .tb_savestate.dut.ss_systemIdle : std_logic >>;
      alias ss_busy    is << signal .tb_savestate.dut.savestate_busy : std_logic >>;
   begin
      wait for 200 us;
      report "t=" & time'image(now) & " cycle=" & integer'image(cycle) & " log=" & integer'image(lastLog) & " irq=" & integer'image(lastIrq) &
             " pause=" & std_logic'image(ss_pause) & " hold=" & std_logic'image(ss_hold) & " held=" & std_logic'image(ss_held) & " sysidle=" & std_logic'image(ss_sysIdle);
   end process;

end architecture;
