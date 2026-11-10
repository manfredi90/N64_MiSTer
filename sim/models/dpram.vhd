library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY dpram IS
	generic (
		 addr_width : integer := 8;
		 data_width : integer := 8
	); 
	PORT
	(
		clock_a		: IN STD_LOGIC;
		clken_a		: IN STD_LOGIC := '1';
		address_a	: IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
		data_a		: IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
		wren_a		: IN STD_LOGIC := '0';
		q_a			: OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);

		clock_b		: IN STD_LOGIC;
		clken_b		: IN STD_LOGIC := '1';
		address_b	: IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
		wren_b		: IN STD_LOGIC := '0';
		q_b			: OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0)
	);
END dpram;

architecture sim of dpram is
   type t_ram is array(0 to 2**addr_width-1) of std_logic_vector(data_width-1 downto 0);
   shared variable ram : t_ram := (others => (others => '0'));
begin
   process (clock_a) begin
      if rising_edge(clock_a) then
         if (clken_a = '1') then
            if (wren_a = '1') then ram(to_integer(unsigned(address_a))) := data_a; end if;
            q_a <= ram(to_integer(unsigned(address_a)));
         end if;
      end if;
   end process;
   process (clock_b) begin
      if rising_edge(clock_b) then
         if (clken_b = '1') then
            if (wren_b = '1') then ram(to_integer(unsigned(address_b))) := data_b; end if;
            q_b <= ram(to_integer(unsigned(address_b)));
         end if;
      end if;
   end process;
end;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY dpram_1clk IS
	generic (
		 addr_width : integer := 8;
		 data_width : integer := 8
	); 
	PORT
	(
		clock  		: IN STD_LOGIC;

		clken_a		: IN STD_LOGIC := '1';
		address_a	: IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
		data_a		: IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
		wren_a		: IN STD_LOGIC := '0';
		q_a			: OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);

		clken_b		: IN STD_LOGIC := '1';
		address_b	: IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
		data_b		: IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
		wren_b		: IN STD_LOGIC := '0';
		q_b			: OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0)
	);
END dpram_1clk;

architecture sim of dpram_1clk is
   type t_ram is array(0 to 2**addr_width-1) of std_logic_vector(data_width-1 downto 0);
   shared variable ram : t_ram := (others => (others => '0'));
begin
   process (clock) begin
      if rising_edge(clock) then
         if (clken_a = '1') then
            if (wren_a = '1') then ram(to_integer(unsigned(address_a))) := data_a; end if;
            q_a <= ram(to_integer(unsigned(address_a)));
         end if;
         if (clken_b = '1') then
            if (wren_b = '1') then ram(to_integer(unsigned(address_b))) := data_b; end if;
            q_b <= ram(to_integer(unsigned(address_b)));
         end if;
      end if;
   end process;
end;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpram_dif is
	generic (
		addr_width_a  : integer := 8;
		data_width_a  : integer := 8;
		addr_width_b  : integer := 8;
		data_width_b  : integer := 8
	);
	PORT
	(
		clock_a		: in  STD_LOGIC;
		address_a	: in  STD_LOGIC_VECTOR (addr_width_a-1 DOWNTO 0);
		data_a		: in  STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0) := (others => '0');
		clken_a		: in  STD_LOGIC := '1';
		wren_a		: in  STD_LOGIC := '0';
		q_a			: out STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0);
		cs_a        : in  std_logic := '1';

      clock_b		: in  STD_LOGIC;
		address_b	: in  STD_LOGIC_VECTOR (addr_width_b-1 DOWNTO 0) := (others => '0');
		data_b		: in  STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0) := (others => '0');
		clken_b		: in  STD_LOGIC := '1';
		wren_b		: in  STD_LOGIC := '0';
		q_b			: out STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0);
		cs_b        : in  std_logic := '1'
	);
end entity;

architecture sim of dpram_dif is
   constant BITS : integer := (2**addr_width_a) * data_width_a;
   shared variable ram : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin
   process (clock_a)
      variable a : integer;
   begin
      if rising_edge(clock_a) then
         if (clken_a = '1') then
            a := to_integer(unsigned(address_a)) * data_width_a;
            if (wren_a = '1' and cs_a = '1') then ram(a + data_width_a - 1 downto a) := data_a; end if;
            q_a <= ram(a + data_width_a - 1 downto a);
         end if;
      end if;
   end process;
   process (clock_b)
      variable a : integer;
   begin
      if rising_edge(clock_b) then
         if (clken_b = '1') then
            a := to_integer(unsigned(address_b)) * data_width_b;
            if (wren_b = '1' and cs_b = '1') then ram(a + data_width_b - 1 downto a) := data_b; end if;
            q_b <= ram(a + data_width_b - 1 downto a);
         end if;
      end if;
   end process;
end;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dpram_dif_be is
	generic (
		addr_width_a    : integer := 8;
		data_width_a    : integer := 8;
		addr_width_b    : integer := 8;
		data_width_b    : integer := 8;
		width_byteena_a : integer := 1;
		width_byteena_b : integer := 1
	);
	PORT
	(
		clock_a		: in  STD_LOGIC;
		address_a	: in  STD_LOGIC_VECTOR (addr_width_a-1 DOWNTO 0);
		data_a		: in  STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0) := (others => '0');
		clken_a		: in  STD_LOGIC := '1';
		byteena_a   : in  STD_LOGIC_VECTOR(width_byteena_a - 1 downto 0) := (others => '1');
		wren_a		: in  STD_LOGIC := '0';
		q_a			: out STD_LOGIC_VECTOR (data_width_a-1 DOWNTO 0);
		cs_a        : in  std_logic := '1';

      clock_b		: in  STD_LOGIC;
		address_b	: in  STD_LOGIC_VECTOR (addr_width_b-1 DOWNTO 0) := (others => '0');
		data_b		: in  STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0) := (others => '0');
		clken_b		: in  STD_LOGIC := '1';
		byteena_b   : in  STD_LOGIC_VECTOR(width_byteena_b - 1 downto 0) := (others => '1');
		wren_b		: in  STD_LOGIC := '0';
		q_b			: out STD_LOGIC_VECTOR (data_width_b-1 DOWNTO 0);
		cs_b        : in  std_logic := '1'
	);
end entity;

architecture sim of dpram_dif_be is
   constant BITS : integer := (2**addr_width_a) * data_width_a;
   shared variable ram : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin
   process (clock_a)
      variable a : integer;
      constant bw : integer := data_width_a / width_byteena_a;
   begin
      if rising_edge(clock_a) then
         if (clken_a = '1') then
            a := to_integer(unsigned(address_a)) * data_width_a;
            if (wren_a = '1' and cs_a = '1') then
               for i in 0 to width_byteena_a - 1 loop
                  if (byteena_a(i) = '1') then ram(a + i*bw + bw - 1 downto a + i*bw) := data_a(i*bw + bw - 1 downto i*bw); end if;
               end loop;
            end if;
            q_a <= ram(a + data_width_a - 1 downto a);
         end if;
      end if;
   end process;
   process (clock_b)
      variable a : integer;
      constant bw : integer := data_width_b / width_byteena_b;
   begin
      if rising_edge(clock_b) then
         if (clken_b = '1') then
            a := to_integer(unsigned(address_b)) * data_width_b;
            if (wren_b = '1' and cs_b = '1') then
               for i in 0 to width_byteena_b - 1 loop
                  if (byteena_b(i) = '1') then ram(a + i*bw + bw - 1 downto a + i*bw) := data_b(i*bw + bw - 1 downto i*bw); end if;
               end loop;
            end if;
            q_b <= ram(a + data_width_b - 1 downto a);
         end if;
      end if;
   end process;
end;

