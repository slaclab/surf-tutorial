# 02-AXI-stream_module

This lab is an introduction to the SURF framework for AXI stream.
By the end of this lab, you will be able to understand the following:
- How to use the SURF AXI stream helper functions/procedures
- How to implement AXI stream tValid/tReady flow control
- How to receive and send AXI streams
- How to simulate the AXI stream module using cocoTB

The details of the AXI stream protocol will not be discussed in detail in this lab.
Please refer to the AXI stream protocol specification for the complete details:
[AMBA 4 AXI4-Stream Protocol Specification, ARM IHI 0051A (ID030610)](https://documentation-service.arm.com/static/642583d7314e245d086bc8c9?token=)

<!--- ########################################################################################### -->

## Copy the template to the RTL directory

First, copy the AXI stream template from the `ref_files`
directory to the `rtl` and rename it on the way.
```bash
cp ref_files/MyAxiStreamModule_start.vhd rtl/MyAxiStreamModule.vhd
```
Please open the `rtl/MyAxiStreamModule.vhd` file in
a text editor (e.g. vim, nano, emacs, etc) at the same time as reading this README.md

<!--- ########################################################################################### -->

## Libraries and Packages

At the top of the template, the following libraries/packages are included:
```vhdl
library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
```
Both the [Standard Logic Real Time Logic Package (StdRtlPkg)](https://github.com/slaclab/surf/blob/v2.47.1/base/general/rtl/StdRtlPkg.vhd)
and [AXI Stream Package (AxiStreamPkg)](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd)
are included from SURF.

<!--- ########################################################################################### -->

## Entity Definition

This MyAxiLiteEndpoint has the following entity definition:
```vhdl
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
```
* `TPD_G`: Simulation only generic used to add delay after the register stage.
This generic has no impact to synthesis or Place and Route (PnR).
Primary purpose is to help with visually looking at simulation waveforms.
* `AXIS_CONFIG_G`: [AxiStreamConfigType](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L82)
Generic that contain the AXI stream configurations
  - TSTRB_EN_C         : boolean; -- Configure if tStrb used or not
  - TDATA_BYTES_C      : natural range 1 to AXI_STREAM_MAX_TKEEP_WIDTH_C; -- tData width (in units of bytes)
  - TDEST_BITS_C       : natural range 0 to 8; -- Number of tDest bits (optional metadata field)
  - TID_BITS_C         : natural range 0 to 8; -- Number of tId bits (optional metadata field)
  - TKEEP_MODE_C       : TkeepModeType; -- Method for tKeep implementation to improve logical resource utilization
  - TUSER_BITS_C       : natural range 0 to 8; -- Number of tUser bits (optional metadata field)
  - TUSER_MODE_C       : TUserModeType; -- Method for tUser implementation to improve logical resource utilization
* `axisClk`: AXI stream clock
* `axisRst`: AXI stream reset (active HIGH)
* `sAxisMaster`: AXI stream master input.
[`AxiStreamMasterType` record type](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L30)
contains the following signals (defined in [AxiStreamPkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd)):
  - tValid : sl;
  - tData  : slv(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 0);
  - tStrb  : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
  - tKeep  : slv(AXI_STREAM_MAX_TKEEP_WIDTH_C-1 downto 0);
  - tLast  : sl;
  - tDest  : slv(7 downto 0);
  - tId    : slv(7 downto 0);
  - tUser  : slv(AXI_STREAM_MAX_TDATA_WIDTH_C-1 downto 0);
* `sAxisSlave`: AXI stream slave output.
[`AxiStreamSlaveType` record type](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L59)
contains the following signals (defined in [AxiStreamPkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd)):
  - tReady : sl;
* `mAxisMaster`: AXI stream master output.
[`AxiStreamMasterType` record type](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L30)
* `mAxisSlave`: AXI stream slave input.
[`AxiStreamSlaveType` record type](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L59)

<!--- ########################################################################################### -->

## Signals, Types, and Constants Definition

This MyAxiLiteEndpoint has the following signals, types, constants:
```vhdl
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
```
* `TDATA_BIT_WIDTH_C`: constant for the calculated number of bits being used in the AXI stream tData bus
* `RegType`: record type definition for the registers in the “two-process” coding style
  - `sAxisSlave`: AXI stream slave bus used for flow control
  - `mAxisMaster`: AXI stream master bus with manipulate the tData information
* `REG_INIT_C`: constant defining the registers' initialized values after reset
  - [AXI_STREAM_SLAVE_INIT_C](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L72) sets the tReady = '0'
  - [axiStreamMasterInit()](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L196) used to initialize the AXI stream master bus with respect to the `AXIS_CONFIG_G` generic
* `r`: signal from the registers that are feed into the combinational process and initialized to REG_INIT_C
  - Note: Initializing signals in VHDL only valid in FPGA designs and not possible for digital ASICs
* `rin`: signal from the combinational process that is feed back into the register process


<!--- ########################################################################################### -->

## Basics of AXI stream Flow Control

All information below are copied from `Section 2.2.1 Handshake process` from the
[AXI stream protocol specification](https://documentation-service.arm.com/static/642583d7314e245d086bc8c9?token=)

The `TVALID` and `TREADY` handshake determines when information is passed across the
interface. A two-way flow control mechanism enables both the master and slave to control the
rate at which the data and control information is transmitted across the interface. For a transfer
to occur both the `TVALID` and `TREADY` signals must be asserted. Either `TVALID` or
`TREADY` can be asserted first or both can be asserted in the same ACLK cycle.

A master is not permitted to wait until `TREADY` is asserted before asserting `TVALID`. Once
`TVALID` is asserted it must remain asserted until the handshake occurs.

A slave is permitted to wait for `TVALID` to be asserted before asserting the corresponding
`TREADY`.

If a slave asserts `TREADY`, it is permitted to deassert `TREADY` before `TVALID` is asserted.
The following sections give examples of the handshake sequence.

<img src="ref_files/axis_fig2-1.png" width="1000">
<img src="ref_files/axis_fig2-2.png" width="1000">
<img src="ref_files/axis_fig2-3.png" width="1000">

<!--- ########################################################################################### -->
