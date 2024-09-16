# AXI-Lite_crossbar

This lab is an introduction to the SURF's AXI-Lite crossbar.
By the end of this lab, you will be able to understand the following:
- How to configuration the AXI-Lite crossbar
- How to cascade multiple AXI-Lite crossbars together
- How to simulate the AXI-Lite crossbar using cocoTB

The details of the AXI-Lite protocol will not be discussed in detail in this lab.
Please refer to the AXI-Lite protocol specification for the complete details:
[AMBA AXI and ACE Protocol Specification, ARM ARM IHI 0022E (ID033013)](https://documentation-service.arm.com/static/5f915b62f86e16515cdc3b1c?token=)

<!--- ########################################################################################### -->

## Copy the template to the RTL directory

First, copy the AXI-Lite endpoint template from the `ref_files`
directory to the `rtl` and rename it on the way.
```bash
cp ref_files/MyAxiLiteCrossbar_start.vhd rtl/MyAxiLiteCrossbar.vhd
```
Please open the `rtl/MyAxiLiteCrossbar.vhd` file in
a text editor (e.g. vim, nano, emacs, etc) at the same time as reading this README.md

<!--- ########################################################################################### -->

## Libraries and Packages

At the top of the template, the following libraries/packages are included:
```vhdl
library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
```
Both the [Standard Logic Real Time Logic Package (StdRtlPkg)](https://github.com/slaclab/surf/blob/v2.47.1/base/general/rtl/StdRtlPkg.vhd)
and [AXI-Lite Package (AxiLitePkg)](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)
are included from SURF.

<!--- ########################################################################################### -->

## Entity Definition

This MyAxiLiteCrossbar has the following entity definition:
```vhdl
entity MyAxiLiteCrossbar is
   generic (
      TPD_G          : time := 1 ns);    -- Simulated propagation delay
   port (
      -- AXI-Lite Bus
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end MyAxiLiteCrossbar;
```
* `TPD_G`: Simulation only generic used to add delay after the register stage.
This generic has no impact to synthesis or Place and Route (PnR).
Primary purpose is to help with visually looking at simulation waveforms.
* `axilClk`: AXI-Lite clock
* `axilRst`: AXI-Lite reset (active HIGH)
* `axilReadMaster`: AXI-Lite read master input.
[`AxiLiteReadMasterType` record type](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L56)
contains the following signals (defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):
  - araddr  : slv(31 downto 0);
  - arprot  : slv(2 downto 0);
  - arvalid : sl;
  - rready  : sl;
* `axilReadSlave`: AXI-Lite read slave output.
[`AxiLiteReadSlaveType` record type](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L82)
contains the following signals (defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):
  - arready : sl;
  - rdata   : slv(31 downto 0);
  - rresp   : slv(1 downto 0);
  - rvalid  : sl;
* `axilWriteMaster`: AXI-Lite write master input.
[`AxiLiteWriteMasterType` record type](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L117)
contains the following signals (defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):
  - awaddr  : slv(31 downto 0);
  - awprot  : slv(2 downto 0);
  - awvalid : sl;
  - wdata   : slv(31 downto 0);
  - wstrb   : slv(3 downto 0);
  - wvalid  : sl;
  - bready  : sl;
* `axilWriteSlave`: AXI-Lite write slave output.
[`AxiLiteWriteSlaveType` record type](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L150)
contains the following signals (defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):
  - awready : sl;
  - wready  : sl;
  - bresp   : slv(1 downto 0);
  - bvalid  : sl;

<!--- ########################################################################################### -->

## Signals, Types, and Constants Definition

Before talking about the constant, it helps to look at this block diagram showing how the crossbars
are connected to each other and what their respect address ranges for the AXI-Lite buses and AXI-Lite
endpoints are:
<img src="ref_files/block.png" width="1000">

Replace "-- Placeholder for constants" with the following constants:
```vhdl
   constant NUM_AXIL_MASTERS_C : positive := 2;

   constant AXIL_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXIL_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXIL_MASTERS_C, x"0000_0000", 22, 20);

   constant NUM_CASCADE_MASTERS_C : positive := 2;

   constant CASCADE_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_CASCADE_MASTERS_C-1 downto 0) := (
      ----------------------------------------------------------------------
      0               => (             -- SLAVE[0]
         baseAddr     => x"0010_2000", -- [0x0010_2000:0x0010_2FFF]
         addrBits     => 12,           -- lower 12 bits of the address
         connectivity => X"0001"),     -- Only MASTER[0] can connect to SLAVE[0]
      ----------------------------------------------------------------------
      1               => (             -- SLAVE[1]
         baseAddr     => x"0016_0000", -- [0x0016_0000:0x0017_FFFF]
         addrBits     => 17,           -- lower 17 bits of the address
         connectivity => X"0001"));    -- Only MASTER[0] can connect to SLAVE[1]
      ----------------------------------------------------------------------

```
* `NUM_AXIL_MASTERS_C` is the number of AXI-Lite buses that the first AXI-Lite crossbar will have
* `AXIL_XBAR_CONFIG_C` is the AXI-Lite crossbar configuration for first AXI-Lite crossbar
* `NUM_CASCADE_MASTERS_C` is the number of AXI-Lite buses that the second AXI-Lite crossbar will have
* `CASCADE_XBAR_CONFIG_C` is the AXI-Lite crossbar configuration for second AXI-Lite crossbar

[AxiLiteCrossbarMasterConfigArray](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L244)
is an array of AxiLiteCrossbarMasterConfigType.
[AxiLiteCrossbarMasterConfigType](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L238)
is a record type for configuring how AXI-Lite transactions are routed through the crossbar:
```vhdl
type AxiLiteCrossbarMasterConfigType is record
   baseAddr     : slv(31 downto 0);
   addrBits     : natural range 1 to 32;
   connectivity : slv(15 downto 0);
end record;
```
* `baseAddr` is the base address of the routing path
* `addrBits` is the number of lower address bits to use in the routing path
* `connectivity` is an enable bit mask of what crossbar master can communicate with which crossbar slave
  - Up to 16 masters per SURF AXI-lite crossbar

SURF provides two methods for configuring the AxiLiteCrossbarMasterConfigArray: manually and genAxiLiteConfig().
Manually is typically used when there is a non-periodic stride to the address mapping.
[genAxiLiteConfig()](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L1029)
is used when the crossbar slave address mapping is periodic via a "stride".  In this lab,
`genAxiLiteConfig(NUM_AXIL_MASTERS_C, x"0000_0000", 22, 20)` will create the effective address mapping:
```vhdl
   constant CASCADE_XBAR_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_CASCADE_MASTERS_C-1 downto 0) := (
      ----------------------------------------------------------------------
      0               => (             -- SLAVE[0]
         baseAddr     => x"0000_0000", -- [0x0000_0000:0x000F_FFFF]
         addrBits     => 20,           -- 20 bit stride
         connectivity => X"FFFF"),     -- Any master can connect to SLAVE[0]
      ----------------------------------------------------------------------
      1               => (             -- SLAVE[1]
         baseAddr     => x"0010_0000", -- [0x0010_0000:0x001F_FFFF]
         addrBits     => 20,           -- 20 bit stride
         connectivity => X"FFFF"));    -- Any master can connect to SLAVE[1]
      ----------------------------------------------------------------------
```

Replace "-- Placeholder for signals" with the following signals:
```vhdl
   signal axilClk : sl;
   signal axilRst : sl;

   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

   signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXIL_MASTERS_C-1 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXIL_MASTERS_C-1 downto 0);

   signal cascadeReadMasters  : AxiLiteReadMasterArray(NUM_CASCADE_MASTERS_C-1 downto 0);
   signal cascadeReadSlaves   : AxiLiteReadSlaveArray(NUM_CASCADE_MASTERS_C-1 downto 0);
   signal cascadeWriteMasters : AxiLiteWriteMasterArray(NUM_CASCADE_MASTERS_C-1 downto 0);
   signal cascadeWriteSlaves  : AxiLiteWriteSlaveArray(NUM_CASCADE_MASTERS_C-1 downto 0);
```
* `axilClk`: AXI-Lite clock
* `axilRst`: AXI-Lite reset (active HIGH)
* `axilReadMaster`: AXI-Lite read master input.
[`AxiLiteReadMasterType](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L56) record type
contains the following signals (defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):
  - araddr  : slv(31 downto 0);
  - arprot  : slv(2 downto 0);
  - arvalid : sl;
  - rready  : sl;
* `axilReadSlave`: AXI-Lite read slave output.
[`AxiLiteReadSlaveType](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L82) record type
contains the following signals (defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):
  - arready : sl;
  - rdata   : slv(31 downto 0);
  - rresp   : slv(1 downto 0);
  - rvalid  : sl;
* `axilWriteMaster`: AXI-Lite write master input.
[`AxiLiteWriteMasterType](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L117) record type
contains the following signals (defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):
  - awaddr  : slv(31 downto 0);
  - awprot  : slv(2 downto 0);
  - awvalid : sl;
  - wdata   : slv(31 downto 0);
  - wstrb   : slv(3 downto 0);
  - wvalid  : sl;
  - bready  : sl;
* `axilWriteSlave`: AXI-Lite write slave output.
[`AxiLiteWriteSlaveType](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L150) record type
contains the following signals (defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):
  - awready : sl;
  - wready  : sl;
  - bresp   : slv(1 downto 0);
  - bvalid  : sl;
* `axilReadMasters` is an array of AXI-Lite read master buses from first crossbar.
[`AxiLiteReadMasterArray`](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L74) record type
* `axilReadSlaves` is an array of AXI-Lite read slave buses from first crossbar.
[`AxiLiteReadSlaveArray](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L109) record type
* `axilWriteMasters` is an array of AXI-Lite write master buses from first crossbar.
[`AxiLiteWriteMasterArray](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L142) record type
* `axilWriteSlaves` is an array of AXI-Lite write slave buses from first crossbar.
[`AxiLiteWriteSlaveArray](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L179) record type
* `cascadeReadMasters` is an array of AXI-Lite read master buses from second crossbar.
[`AxiLiteReadMasterArray](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L74) record type
* `cascadeReadSlaves` is an array of AXI-Lite read slave buses from second crossbar.
[`AxiLiteReadSlaveArray](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L109) record type
* `cascadeWriteMasters` is an array of AXI-Lite write master buses from second crossbar.
[`AxiLiteWriteMasterArray](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L142) record type
* `cascadeWriteSlaves` is an array of AXI-Lite write slave buses from second crossbar.
[`AxiLiteWriteSlaveArray](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L179) record type

<!--- ########################################################################################### -->

## Adding modules into the VHDL body

Replace "-- Placeholder for modules" with the following modules and connections:
```vhdl
   U_AXIL_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_AXIL_MASTERS_C,
         MASTERS_CONFIG_G   => AXIL_XBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMaster,
         sAxiWriteSlaves(0)  => axilWriteSlave,
         sAxiReadMasters(0)  => axilReadMaster,
         sAxiReadSlaves(0)   => axilReadSlave,
         mAxiWriteMasters    => axilWriteMasters,
         mAxiWriteSlaves     => axilWriteSlaves,
         mAxiReadMasters     => axilReadMasters,
         mAxiReadSlaves      => axilReadSlaves);

   U_MEM : entity surf.AxiDualPortRam
      generic map (
         ADDR_WIDTH_G => 10,
         DATA_WIDTH_G => 32)
      port map (
         -- Axi Port
         axiClk         => axilClk,
         axiRst         => axilRst,
         axiReadMaster  => axilReadMasters(0),
         axiReadSlave   => axilReadSlaves(0),
         axiWriteMaster => axilWriteMasters(0),
         axiWriteSlave  => axilWriteSlaves(0));

   U_CASCADE_XBAR : entity surf.AxiLiteCrossbar
      generic map (
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => NUM_CASCADE_MASTERS_C,
         MASTERS_CONFIG_G   => CASCADE_XBAR_CONFIG_C)
      port map (
         axiClk              => axilClk,
         axiClkRst           => axilRst,
         sAxiWriteMasters(0) => axilWriteMasters(1),
         sAxiWriteSlaves(0)  => axilWriteSlaves(1),
         sAxiReadMasters(0)  => axilReadMasters(1),
         sAxiReadSlaves(0)   => axilReadSlaves(1),
         mAxiWriteMasters    => cascadeWriteMasters,
         mAxiWriteSlaves     => cascadeWriteSlaves,
         mAxiReadMasters     => cascadeReadMasters,
         mAxiReadSlaves      => cascadeReadSlaves);

   GEN_VEC :
   for i in NUM_CASCADE_MASTERS_C-1 downto 0 generate

      U_MEM : entity surf.AxiDualPortRam
         generic map (
            ADDR_WIDTH_G => 10,
            DATA_WIDTH_G => 32)
         port map (
            -- Axi Port
            axiClk         => axilClk,
            axiRst         => axilRst,
            axiReadMaster  => cascadeReadMasters(i),
            axiReadSlave   => cascadeReadSlaves(i),
            axiWriteMaster => cascadeWriteMasters(i),
            axiWriteSlave  => cascadeWriteSlaves(i));

   end generate GEN_VEC;
```

It helps to look at this block diagram showing how the crossbars
are connected to each other and what their respect address ranges for the AXI-Lite buses and AXI-Lite
endpoints are:
<img src="ref_files/block.png" width="1000">

<!--- ########################################################################################### -->

## Running the cocoTB testbed

cocoTB is an open-source, coroutine-based co-simulation testbench environment
for verifying VHDL and Verilog hardware designs. Developed with Python, cocoTB
eases the testing process by allowing developers to write test scenarios in Python,
leveraging its extensive libraries and simplicity to create flexible and powerful tests.
This enables more intuitive interaction with the simulation, making it possible to
quickly develop complex test sequences, automate testing procedures, and analyze outcomes.
By integrating cocoTB into our testing framework, we can simulate the behavior of
AXI-Lite endpoints, among other components, in a highly efficient and user-friendly manner.
This introduction aims to familiarize you with the basic concepts and advantages of using
cocoTB in the context of our lab exercises, setting the stage for the detailed instructions
that follow on how to deploy and utilize cocoTB to test the MyAxiLiteCrossbarWrapper effectively.

<!--- ########################################################################################### -->

### Why the `rtl/MyAxiLiteCrossbarWrapper.vhd`?

cocoTB's AXI extension package does NOT support record types for the AXI interface between
the firmware and the cocoTB simulation. This is a same issue as with AMD/Xilinx IP Integrator.
Both tool only accept `std_logic` (`sl`) and `std_logic_vector` (`slv`) port types. The work-around
for both tools is to use a wrapper that translates the AXI record types to `std_logic` (sl) and
`std_logic_vector` (slv).  For this lab we will be using `surf.SlaveAxiLiteIpIntegrator` for translation:

```vhdl
entity MyAxiLiteCrossbarWrapper is
   generic (
      EN_ERROR_RESP : boolean  := false;
      FREQ_HZ       : positive := 100000000);             -- Units of Hz
   port (
      -- AXI-Lite Interface
      S_AXI_ACLK    : in  std_logic;
      S_AXI_ARESETN : in  std_logic;
      S_AXI_AWADDR  : in  std_logic_vector(31 downto 0);  -- Must match ADDR_WIDTH_C
      S_AXI_AWPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_AWVALID : in  std_logic;
      S_AXI_AWREADY : out std_logic;
      S_AXI_WDATA   : in  std_logic_vector(31 downto 0);
      S_AXI_WSTRB   : in  std_logic_vector(3 downto 0);
      S_AXI_WVALID  : in  std_logic;
      S_AXI_WREADY  : out std_logic;
      S_AXI_BRESP   : out std_logic_vector(1 downto 0);
      S_AXI_BVALID  : out std_logic;
      S_AXI_BREADY  : in  std_logic;
      S_AXI_ARADDR  : in  std_logic_vector(31 downto 0);  -- Must match ADDR_WIDTH_C
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic);
end MyAxiLiteCrossbarWrapper;

architecture mapping of MyAxiLiteCrossbarWrapper is

   constant ADDR_WIDTH_C : positive := 32;  -- Must match the entity's port width

   signal axilClk         : sl;
   signal axilRst         : sl;
   signal axilReadMaster  : AxiLiteReadMasterType;
   signal axilReadSlave   : AxiLiteReadSlaveType;
   signal axilWriteMaster : AxiLiteWriteMasterType;
   signal axilWriteSlave  : AxiLiteWriteSlaveType;

begin

   U_ShimLayer : entity surf.SlaveAxiLiteIpIntegrator
      generic map (
         EN_ERROR_RESP => EN_ERROR_RESP,
         FREQ_HZ       => FREQ_HZ,
         ADDR_WIDTH    => ADDR_WIDTH_C)
      port map (
         -- IP Integrator AXI-Lite Interface
         S_AXI_ACLK      => S_AXI_ACLK,
         S_AXI_ARESETN   => S_AXI_ARESETN,
         S_AXI_AWADDR    => S_AXI_AWADDR,
         S_AXI_AWPROT    => S_AXI_AWPROT,
         S_AXI_AWVALID   => S_AXI_AWVALID,
         S_AXI_AWREADY   => S_AXI_AWREADY,
         S_AXI_WDATA     => S_AXI_WDATA,
         S_AXI_WSTRB     => S_AXI_WSTRB,
         S_AXI_WVALID    => S_AXI_WVALID,
         S_AXI_WREADY    => S_AXI_WREADY,
         S_AXI_BRESP     => S_AXI_BRESP,
         S_AXI_BVALID    => S_AXI_BVALID,
         S_AXI_BREADY    => S_AXI_BREADY,
         S_AXI_ARADDR    => S_AXI_ARADDR,
         S_AXI_ARPROT    => S_AXI_ARPROT,
         S_AXI_ARVALID   => S_AXI_ARVALID,
         S_AXI_ARREADY   => S_AXI_ARREADY,
         S_AXI_RDATA     => S_AXI_RDATA,
         S_AXI_RRESP     => S_AXI_RRESP,
         S_AXI_RVALID    => S_AXI_RVALID,
         S_AXI_RREADY    => S_AXI_RREADY,
         -- SURF AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

   U_MyAxiLiteCrossbar : entity work.MyAxiLiteCrossbar
      port map (
         -- AXI-Lite Interface
         axilClk         => axilClk,
         axilRst         => axilRst,
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave);

end mapping;
```
Here's an example of what the wrapper looks like when added to Vivado IP integator (A.K.A. "Block Design"):
```tcl
create_bd_cell -type module -reference MyAxiLiteCrossbarWrapper MyAxiLiteCrossbar_0
```
<img src="ref_files/IpIntegrator.png" width="1000">

<!--- ########################################################################################### -->

### How to run the cocoTB testing script

Run "make". This Makefile will finds all the source code paths via ruckus.tcl for cocoTB simulation.
```bash
make
```

The `tests/test_MyAxiLiteCrossbarWrapper.py` cocotb test script is provided in this lab.
This cocotb script uses the [cocotbext-axi library](https://pypi.org/project/cocotbext-axi/),
which provides a cocotb API for communicating with the firmware via AXI, AXI-Lite, and AXI-stream interfaces.

In the `test_MyAxiLiteCrossbarWrapper.py`, the `run_test_bytes()` and `run_stress_test()` functions will be run with four different combinations of AXI-stream traffic:
- No IDLEs inserted, no backpressure applied
- No IDLEs inserted, backpressure applied
- IDLEs inserted, no backpressure applied
- IDLEs inserted, backpressure applied

Now, run the cocoTB python script and grep for the CUSTOM logging prints
```bash
pytest --capture=tee-sys --log-cli-level=INFO tests/test_MyAxiLiteCrossbarWrapper.py  | grep CUSTOM
```

Here's an example of what the output of that `pytest` command would look like:
```bash
$ pytest -rP tests/test_MyAxiLiteCrossbarWrapper.py  | grep CUSTOM
INFO     cocotb:simulator.py:305      0.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_test_bytes(): idle_inserter=None, backpressure_inserter=None
INFO     cocotb:simulator.py:305  36050.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
INFO     cocotb:simulator.py:305  36050.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_test_bytes(): idle_inserter=None, backpressure_inserter=<function cycle_pause at 0x7651a30065f0>
INFO     cocotb:simulator.py:305  73380.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
INFO     cocotb:simulator.py:305  73380.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_test_bytes(): idle_inserter=<function cycle_pause at 0x7651a30065f0>, backpressure_inserter=None
INFO     cocotb:simulator.py:305 110700.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
INFO     cocotb:simulator.py:305 110700.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_test_bytes(): idle_inserter=<function cycle_pause at 0x7651a30065f0>, backpressure_inserter=<function cycle_pause at 0x7651a30065f0>
INFO     cocotb:simulator.py:305 154750.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
INFO     cocotb:simulator.py:305 154750.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_test_words()
INFO     cocotb:simulator.py:305 281190.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
INFO     cocotb:simulator.py:305 281190.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_stress_test(): idle_inserter=None, backpressure_inserter=None
INFO     cocotb:simulator.py:305 310800.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
INFO     cocotb:simulator.py:305 310800.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_stress_test(): idle_inserter=None, backpressure_inserter=<function cycle_pause at 0x7651a30065f0>
INFO     cocotb:simulator.py:305 345370.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
INFO     cocotb:simulator.py:305 345370.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_stress_test(): idle_inserter=<function cycle_pause at 0x7651a30065f0>, backpressure_inserter=None
INFO     cocotb:simulator.py:305 380000.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
INFO     cocotb:simulator.py:305 380000.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    run_stress_test(): idle_inserter=<function cycle_pause at 0x7651a30065f0>, backpressure_inserter=<function cycle_pause at 0x7651a30065f0>
INFO     cocotb:simulator.py:305 414650.00ns CUSTOM   cocotb.myaxilitecrossbarwrapper    .... passed test
```

<!--- ########################################################################################### -->

### How to view the digital logic waveforms after the simulation

After running the cocoTB simulation, a `.ghw` file with all the traces will be dumped
into the build output path.  You can use `gtkwave` to display these simulation traces:
```bash
gtkwave build/MyAxiLiteCrossbarWrapper/MyAxiLiteCrossbarWrapper.ghw
```
<img src="ref_files/gtkwave.png" width="1000">

<!--- ########################################################################################### -->

## Explore Time!

At this point, we have added all the custom AXI-Lite crossbar for the
example cocoTB testbed python provided in the lab.  If you have extra
time in the lab, please play around with adding/modifying the crossbar
firmware and testing them in the cocoTB software simulator.

<!--- ########################################################################################### -->
