-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Template to start from for this lab
-------------------------------------------------------------------------------
-- This file is part of 'surf-tutorial'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'surf-tutorial', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;

entity MyAxiStreamModule is
   generic (
      TPD_G         : time := 1 ns;     -- Simulated propagation delay
      AXIS_CONFIG_G : AxiStreamConfigType);
   port (
      -- AXI-Lite Bus
      axisClk     : in  sl;
      axisRst     : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end MyAxiStreamModule;

architecture behavioral of MyAxiStreamModule is

   constant TDATA_BIT_WIDTH_C : positive := 8*AXIS_CONFIG_G.TDATA_BYTES_C;

   type RegType is record
      sAxisSlave  : AxiStreamSlaveType;
      mAxisMaster : AxiStreamMasterType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      sAxisSlave  => AXI_STREAM_SLAVE_INIT_C,
      mAxisMaster => axiStreamMasterInit(AXIS_CONFIG_G));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ------------------------
   -- combinatorial process
   ------------------------
   comb : process (axisRst, mAxisSlave, r, sAxisMaster) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      ---------------
      -- Flow Control
      ---------------

      -- Flow Control: Placeholder for your code will go here

      ---------------------
      -- Process the stream
      ---------------------

      -- Stream Process: Placeholder for your code will go here

      ----------
      -- Outputs
      ----------

      -- Outputs: Placeholder for your code will go here

      --------------------
      -- Synchronous Reset
      --------------------
      if (axisRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   -------------------
   -- Register process
   -------------------
   seq : process (axisClk) is
   begin
      if rising_edge(axisClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end behavioral;
