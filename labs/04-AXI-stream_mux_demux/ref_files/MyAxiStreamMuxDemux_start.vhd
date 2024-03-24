-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Template to start from for this lab
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
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

entity MyAxiStreamMuxDemux is
   generic (
      TPD_G                : time                 := 1 ns;  -- Simulated propagation delay
      MUX_STREAMS_G        : positive             := 2;
      MODE_G               : string               := "INDEXED";
      TDEST_ROUTES_G       : Slv8Array            := (0 => "--------");
      TDEST_LOW_G          : integer range 0 to 7 := 0;
      ILEAVE_EN_G          : boolean              := false;
      ILEAVE_ON_NOTVALID_G : boolean              := false;
      ILEAVE_REARB_G       : natural              := 0;
      REARB_DELAY_G        : boolean              := true;
      FORCED_REARB_HOLD_G  : boolean              := false;
      PIPE_STAGES_G        : natural              := 0);
   port (
      -- AXI-Lite Bus
      axisClk     : in  sl;
      axisRst     : in  sl;
      sAxisMaster : in  AxiStreamMasterType;
      sAxisSlave  : out AxiStreamSlaveType;
      mAxisMaster : out AxiStreamMasterType;
      mAxisSlave  : in  AxiStreamSlaveType);
end MyAxiStreamMuxDemux;

architecture mapping of MyAxiStreamMuxDemux is

-- Placeholder for signals

begin

-- Placeholder for modules

end mapping;
