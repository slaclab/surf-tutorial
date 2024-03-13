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

      -- Example of mapping a constant value to the register mapp
      axiSlaveRegisterR(axilEp, x"000", 0, BUILD_INFO_DECODED_C.fwVersion);  -- BUILD_INFO_DECODED_C.fwVersion is "slv(31 downto 0)" type

      -- Example of mapping a local read/write register
      axiSlaveRegister (axilEp, x"004", 0, v.scratchPad);  -- scratchPad is a general 32-bit register

      -- Example of mapping a local read-only register
      axiSlaveRegisterR(axilEp, x"008", 0, r.cnt);  -- cnt is a 32-bit counter controlled by startCnt/stopCnt

      -- Example of write-only register using the "bit offset" field
      axiSlaveRegister (axilEp, x"00C", 0, v.startCnt);  -- Mapped to BIT0
      axiSlaveRegister (axilEp, x"00C", 1, v.stopCnt);   -- Mapped to BIT1

      -- Example of non-4 byte word alignment
      axiSlaveRegisterR(axilEp, x"011", 0, r.enableCnt);

      -- Example of register map with a value that's larger than 32-bit value
      axiSlaveRegisterR(axilEp, x"100", 0, BUILD_INFO_DECODED_C.gitHash);  -- BUILD_INFO_DECODED_C.gitHash is "slv(159 downto 0)" type

      -- Example of an array of 32-bit registers being mapped
      axiSlaveRegisterR(axilEp, x"200", BUILD_INFO_DECODED_C.buildString);  -- BUILD_INFO_DECODED_C.buildString is "Slv32Array(0 to 63)" type

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
