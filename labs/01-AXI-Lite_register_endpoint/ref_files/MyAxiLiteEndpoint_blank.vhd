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
use surf.AxiLitePkg.all;

library ruckus;
use ruckus.BuildInfoPkg.all;

entity MyAxiLiteEndpoint is
   generic (
      TPD_G       : time    := 1 ns;    -- Simulated propagation delay
      RST_ASYNC_G : boolean := false);  -- TRUE:
   port (
      -- AXI-Lite Bus
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end MyAxiLiteEndpoint;

architecture behavioral of MyAxiLiteEndpoint is

   constant BUILD_INFO_DECODED_C : BuildInfoRetType := toBuildInfo(BUILD_INFO_C);

   type RegType is record
      scratchPad     : slv(31 downto 0);
      cnt            : slv(31 downto 0);
      enableCnt      : sl;
      startCnt       : sl;
      stopCnt        : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      scratchPad     => x"DEAD_BEEF",
      cnt            => (others => '0'),
      enableCnt      => '0',
      startCnt       => '0',
      stopCnt        => '0',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   ------------------------
   -- combinatorial process
   ------------------------
   comb : process (axilReadMaster, axilRst, axilWriteMaster, r) is
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
   begin
      -- Latch the current value
      v := r;

      --------------------
      -- Reset the strobes
      --------------------
      v.startCnt := '0';
      v.stopCnt  := '0';

      ------------------------
      -- Counter logic
      ------------------------

      -- Check if enabling counter
      if (r.enableCnt = '1') then
         -- Increment the counter
         v.cnt := r.cnt + 1;
      end if;

      -- Check if we are enabling the counter
      if (r.startCnt = '1') then
         -- Set the flag
         v.enableCnt := '1';
      end if;

      -- Check if we are disabling the counter
      if (r.stopCnt = '1') then
         -- Set the flag
         v.enableCnt := '0';
      end if;

      ---------------------------------
      -- Determine the transaction type
      ---------------------------------
      axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

      -------------------------------
      -- Mapping read/write registers
      -------------------------------

      -- Placeholder for your code will go here

      ---------------------------
      -- Closeout the transaction
      ---------------------------
      axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave, AXI_RESP_DECERR_C);

      ----------
      -- Outputs
      ----------
      axilReadSlave  <= r.axilReadSlave;
      axilWriteSlave <= r.axilWriteSlave;

      --------------------
      -- Synchronous Reset
      --------------------
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

   end process comb;

   -------------------
   -- Register process
   -------------------
   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end behavioral;
