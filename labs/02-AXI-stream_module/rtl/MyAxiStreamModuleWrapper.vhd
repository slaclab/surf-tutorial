-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: IP Integrator Wrapper for work.MyAxiStreamModule
-------------------------------------------------------------------------------
-- TCL Command: create_bd_cell -type module -reference MyAxiStreamModuleWrapper MyAxiStreamModule_0
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

entity MyAxiStreamModuleWrapper is
   generic (
      -- IP Integrator AXI Stream Configuration
      HAS_TLAST       : natural range 0 to 1   := 1;
      HAS_TKEEP       : natural range 0 to 1   := 1;
      HAS_TSTRB       : natural range 0 to 1   := 0;
      HAS_TREADY      : natural range 0 to 1   := 1;
      TUSER_WIDTH     : natural range 1 to 8   := 2;
      TID_WIDTH       : natural range 1 to 8   := 1;
      TDEST_WIDTH     : natural range 1 to 8   := 1;
      TDATA_NUM_BYTES : natural range 1 to 128 := 4);
   port (
      -- Clock and Reset
      AXIS_ACLK     : in  std_logic;
      AXIS_ARESETN  : in  std_logic;
      -- IP Integrator Slave AXI Stream Interface
      S_AXIS_TVALID : in  std_logic;
      S_AXIS_TDATA  : in  std_logic_vector((8*TDATA_NUM_BYTES)-1 downto 0);
      S_AXIS_TSTRB  : in  std_logic_vector(TDATA_NUM_BYTES-1 downto 0);
      S_AXIS_TKEEP  : in  std_logic_vector(TDATA_NUM_BYTES-1 downto 0);
      S_AXIS_TLAST  : in  std_logic;
      S_AXIS_TDEST  : in  std_logic_vector(TDEST_WIDTH-1 downto 0);
      S_AXIS_TID    : in  std_logic_vector(TID_WIDTH-1 downto 0);
      S_AXIS_TUSER  : in  std_logic_vector(TUSER_WIDTH-1 downto 0);
      S_AXIS_TREADY : out std_logic;
      -- IP Integrator Master AXI Stream Interface
      M_AXIS_TVALID : out std_logic;
      M_AXIS_TDATA  : out std_logic_vector((8*TDATA_NUM_BYTES)-1 downto 0);
      M_AXIS_TSTRB  : out std_logic_vector(TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TKEEP  : out std_logic_vector(TDATA_NUM_BYTES-1 downto 0);
      M_AXIS_TLAST  : out std_logic;
      M_AXIS_TDEST  : out std_logic_vector(TDEST_WIDTH-1 downto 0);
      M_AXIS_TID    : out std_logic_vector(TID_WIDTH-1 downto 0);
      M_AXIS_TUSER  : out std_logic_vector(TUSER_WIDTH-1 downto 0);
      M_AXIS_TREADY : in  std_logic);
end MyAxiStreamModuleWrapper;

architecture mapping of MyAxiStreamModuleWrapper is

   constant AXIS_CONFIG_C : AxiStreamConfigType := (
      TSTRB_EN_C    => ite(HAS_TSTRB = 1, true, false),
      TDATA_BYTES_C => TDATA_NUM_BYTES,
      TDEST_BITS_C  => TDEST_WIDTH,
      TID_BITS_C    => TID_WIDTH,
      TKEEP_MODE_C  => ite(HAS_TKEEP = 1, TKEEP_NORMAL_C, TKEEP_FIXED_C),
      TUSER_BITS_C  => TUSER_WIDTH,
      TUSER_MODE_C  => TUSER_NORMAL_C);

   signal sAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal sAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal mAxisMaster : AxiStreamMasterType := AXI_STREAM_MASTER_INIT_C;
   signal mAxisSlave  : AxiStreamSlaveType  := AXI_STREAM_SLAVE_FORCE_C;

   signal axisClk : sl := '0';
   signal axisRst : sl := '0';

begin

   U_ShimLayerSlave : entity surf.SlaveAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "S_AXIS",
         HAS_TLAST       => HAS_TLAST,
         HAS_TKEEP       => HAS_TKEEP,
         HAS_TSTRB       => HAS_TSTRB,
         HAS_TREADY      => HAS_TREADY,
         TUSER_WIDTH     => TUSER_WIDTH,
         TID_WIDTH       => TID_WIDTH,
         TDEST_WIDTH     => TDEST_WIDTH,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES)
      port map (
         -- IP Integrator AXI Stream Interface
         S_AXIS_ACLK    => AXIS_ACLK,
         S_AXIS_ARESETN => AXIS_ARESETN,
         S_AXIS_TVALID  => S_AXIS_TVALID,
         S_AXIS_TDATA   => S_AXIS_TDATA,
         S_AXIS_TSTRB   => S_AXIS_TSTRB,
         S_AXIS_TKEEP   => S_AXIS_TKEEP,
         S_AXIS_TLAST   => S_AXIS_TLAST,
         S_AXIS_TDEST   => S_AXIS_TDEST,
         S_AXIS_TID     => S_AXIS_TID,
         S_AXIS_TUSER   => S_AXIS_TUSER,
         S_AXIS_TREADY  => S_AXIS_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => axisClk,
         axisRst        => axisRst,
         axisMaster     => sAxisMaster,
         axisSlave      => sAxisSlave);

   U_MyAxiStreamModule : entity work.MyAxiStreamModule
      generic map (
         AXIS_CONFIG_G => AXIS_CONFIG_C)
      port map (
         -- AXI Stream Interface
         axisClk     => axisClk,
         axisRst     => axisRst,
         sAxisMaster => sAxisMaster,
         sAxisSlave  => sAxisSlave,
         mAxisMaster => mAxisMaster,
         mAxisSlave  => mAxisSlave);

   U_ShimLayerMaster : entity surf.MasterAxiStreamIpIntegrator
      generic map (
         INTERFACENAME   => "M_AXIS",
         HAS_TLAST       => HAS_TLAST,
         HAS_TKEEP       => HAS_TKEEP,
         HAS_TSTRB       => HAS_TSTRB,
         HAS_TREADY      => HAS_TREADY,
         TUSER_WIDTH     => TUSER_WIDTH,
         TID_WIDTH       => TID_WIDTH,
         TDEST_WIDTH     => TDEST_WIDTH,
         TDATA_NUM_BYTES => TDATA_NUM_BYTES)
      port map (
         -- IP Integrator AXI Stream Interface
         M_AXIS_ACLK    => AXIS_ACLK,
         M_AXIS_ARESETN => AXIS_ARESETN,
         M_AXIS_TVALID  => M_AXIS_TVALID,
         M_AXIS_TDATA   => M_AXIS_TDATA,
         M_AXIS_TSTRB   => M_AXIS_TSTRB,
         M_AXIS_TKEEP   => M_AXIS_TKEEP,
         M_AXIS_TLAST   => M_AXIS_TLAST,
         M_AXIS_TDEST   => M_AXIS_TDEST,
         M_AXIS_TID     => M_AXIS_TID,
         M_AXIS_TUSER   => M_AXIS_TUSER,
         M_AXIS_TREADY  => M_AXIS_TREADY,
         -- SURF AXI Stream Interface
         axisClk        => open,        -- same as SlaveAxiStreamIpIntegrator
         axisRst        => open,        -- same as SlaveAxiStreamIpIntegrator
         axisMaster     => mAxisMaster,
         axisSlave      => mAxisSlave);

end mapping;
