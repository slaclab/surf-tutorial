-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Reference of what the final result will be this lab
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

      -- Reset the inbound tReady back to zero
      v.sAxisSlave.tReady := '0';

      -- Check if the outbound tReady was active
      if (mAxisSlave.tReady = '1') then

         -- Reset the outbound metadata
         v.mAxisMaster.tValid := '0';

      end if;

      ---------------------
      -- Process the stream
      ---------------------

      -- Check if new inbound data and able to move outbound
      if (sAxisMaster.tValid = '1') and (v.mAxisMaster.tValid = '0') then  -- Using the variable for mAxisMaster.tValid (not registered)

         -- Accept the data
         v.sAxisSlave.tReady := '1';

         -- Move the data
         v.mAxisMaster := sAxisMaster;

         -- Manipulate the tData bus by adding +1 to the value
         v.mAxisMaster.tData(TDATA_BIT_WIDTH_C-1 downto 0) := v.mAxisMaster.tData(TDATA_BIT_WIDTH_C-1 downto 0) + 1;

      end if;

      ----------
      -- Outputs
      ----------
      sAxisSlave  <= v.sAxisSlave;  -- Using variable output because need 0 cycle latency between tValid/tReady handshaking
      mAxisMaster <= r.mAxisMaster;

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
