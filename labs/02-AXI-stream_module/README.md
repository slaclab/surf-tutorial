# AXI-stream_module

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

This MyAxiStreamModule has the following entity definition:
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
  - TDEST_BITS_C       : natural range 0 to 8; -- Number of tDest bits (optional side-channel data field)
  - TID_BITS_C         : natural range 0 to 8; -- Number of tId bits (optional side-channel data field)
  - TKEEP_MODE_C       : TkeepModeType; -- Method for tKeep implementation to improve logical resource utilization
  - TUSER_BITS_C       : natural range 0 to 8; -- Number of tUser bits (optional side-channel data field)
  - TUSER_MODE_C       : TUserModeType; -- Method for tUser implementation to improve logical resource utilization
* `axisClk`: AXI stream clock
* `axisRst`: AXI stream reset (active HIGH)
* `sAxisMaster`: AXI stream master input.
[`AxiStreamMasterType`](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L30) record type
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
[`AxiStreamSlaveType`](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L59) record type
contains the following signals (defined in [AxiStreamPkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd)):
  - tReady : sl;
* `mAxisMaster`: AXI stream master output.
[`AxiStreamMasterType`](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L30) record type
* `mAxisSlave`: AXI stream slave input.
[`AxiStreamSlaveType`](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L59) record type

<!--- ########################################################################################### -->

## Signals, Types, and Constants Definition

This MyAxiStreamModule has the following signals, types, constants:
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

All information below is copied from `Section 2.2.1 Handshake process` from the
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

## Adding Custom code to the Combinatorial Process

At this point in the lab, we will replace the "Placeholder" sections of the code
with custom code. This addition is divided into three sections to facilitate learning
how to use the SURF AXI stream framework:
- Flow Control
- Process the stream
- Outputs

<!--- ########################################################################################### -->

### Flow Control

Replace `-- Flow Control: Placeholder for your code will go here` with the following code:
```vhdl
      -- Reset the inbound tReady back to zero
      v.sAxisSlave.tReady := '0';
```
After the rising edge of each clock cycle, we reset the sAxisSlave.tReady variable back to zero.

Next, add the following code to the "Flow Control" section:
```vhdl
      -- Check if the outbound tReady was active
      if (mAxisSlave.tReady = '1') then

         -- Reset the outbound side-channel data
         v.mAxisMaster.tValid := '0';

      end if;
```
This code is used to deassert the mAxisMaster.tValid once the mAxisSlave.tReady is asserted.

<!--- ########################################################################################### -->

### Process the stream

Replace `-- Stream Process: Placeholder for your code will go here` with the following code:
```vhdl
      -- Check if new inbound data and able to move outbound
      if (sAxisMaster.tValid = '1') and (v.mAxisMaster.tValid = '0') then

         -- Accept the data
         v.sAxisSlave.tReady := '1';

         -- Move the data
         v.mAxisMaster := sAxisMaster;

         -- Manipulate the tData bus by adding +1 to the value
         v.mAxisMaster.tData(TDATA_BIT_WIDTH_C-1 downto 0) := v.mAxisMaster.tData(TDATA_BIT_WIDTH_C-1 downto 0) + 1;

      end if;
```
* `if (sAxisMaster.tValid = '1') and (v.mAxisMaster.tValid = '0') then`
  * This code will check for new inbound data from the sAxisMaster.tValid and the outbound data is ready
to move the next word.
  * Please take note how the variable for mAxisMaster.tValid (not registered) is being
used here.  If we use the registered (r.) for mAxisMaster.tValid, then there would always be at least
1 clock cycle gap between the mAxisMaster.tValid, which would result in reduced performance.
By using the variable for mAxisMaster.tValid, we can be capable of accepting sAxisMaster on every clock
cycle with no gaps in tValid.
* `v.sAxisSlave.tReady := '1';`
  * This will acknowledge the sAxisMaster information was acceptable so the upstream source can either
deassert sAxisMaster.tValid or re-assert sAxisMaster.tValid with new information on the next clock cycle.
* `v.mAxisMaster := sAxisMaster;`
  * This will make an exact copy of the sAxisMaster to the variable of mAxisMaster.
* `v.mAxisMaster.tData(TDATA_BIT_WIDTH_C-1 downto 0) := v.mAxisMaster.tData(TDATA_BIT_WIDTH_C-1 downto 0) + 1;`
  * Using the variable of mAxisMaster.tData, this will increment the value of tData by 1 within the valid range of tData.

<!--- ########################################################################################### -->

### Outputs

Replace `-- Outputs: Placeholder for your code will go here` with the following code:
```vhdl
      sAxisSlave  <= v.sAxisSlave;  -- Variable output
      mAxisMaster <= r.mAxisMaster; -- Registered output
```
For the `mAxisMaster` we are using the registered value on the output port.
However, for the `sAxisSlave` we are using the variable value (instead of registered).
The variable output value is required because of the 0 cycle latency requirement between tValid/tReady handshaking.
This is commonly known "critical path" when making timing in Place and Route (PnR). SURF framework
has a module called [AxiStreamPipeline](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPipeline.vhd)
      to help with breaking apart that critical path with register with a slight increase in pipeline delay.

<!--- ########################################################################################### -->

## Running the cocoTB testbed

cocoTB is an open-source, coroutine-based co-simulation testbench environment
for verifying VHDL and Verilog hardware designs. Developed with Python, cocoTB
eases the testing process by allowing developers to write test scenarios in Python,
leveraging its extensive libraries and simplicity to create flexible and powerful tests.
This enables more intuitive interaction with the simulation, making it possible to
quickly develop complex test sequences, automate testing procedures, and analyze outcomes.
By integrating cocoTB into our testing framework, we can simulate the behavior of
AXI stream module, among other components, in a highly efficient and user-friendly manner.
This introduction aims to familiarize you with the basic concepts and advantages of using
cocoTB in the context of our lab exercises, setting the stage for the detailed instructions
that follow on how to deploy and utilize cocoTB to test the MyAxiStreamModuleWrapper effectively.

<!--- ########################################################################################### -->

### Why the `rtl/MyAxiStreamModuleWrapper.vhd`?

cocoTB's AXI extension package does NOT support record types for the AXI interface between
the firmware and the cocoTB simulation. This is a same issue as with AMD/Xilinx IP Integrator.
Both tool only accept `std_logic` (`sl`) and `std_logic_vector` (`slv`) port types. The work-around
for both tools is to use a wrapper that translates the AXI record types to `std_logic` (sl) and
`std_logic_vector` (slv).  For this lab we will be using
`surf.SlaveAxiStreamIpIntegrator` and `surf.MasterAxiStreamIpIntegrator` for translation:

```vhdl
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
```
Here's an example of what the wrapper looks like when added to Vivado IP integator (A.K.A. "Block Design"):
```tcl
create_bd_cell -type module -reference MyAxiStreamModuleWrapper MyAxiStreamModule_0
```
<img src="ref_files/IpIntegrator.png" width="1000">

<!--- ########################################################################################### -->

### How to run the cocoTB testing script

Run "make". This Makefile will finds all the source code paths via ruckus.tcl for cocoTB simulation.
```bash
make
```

The `tests/test_MyAxiStreamModuleWrapper.py` cocotb test script is provided in this lab.
This cocotb script uses the [cocotbext-axi library](https://pypi.org/project/cocotbext-axi/),
which provides a cocotb API for communicating with the firmware via AXI, AXI-Lite, and AXI-stream interfaces.

In the `test_MyAxiStreamModuleWrapper.py`, the `run_test()` function will be run with four different combinations of AXI-stream traffic:
- No IDLEs inserted, no backpressure applied
- No IDLEs inserted, backpressure applied
- IDLEs inserted, no backpressure applied
- IDLEs inserted, backpressure applied

For each `run_test()`, the code will send a payload of 1 byte and increment the payload size by 1 until it reaches the `payload_lengths()`.
The `CalculateExpectedResult()` function will compare the received payload with the software-calculated "expected" payload.
If there is a mismatch between the received and expected payload, the code will raise an exception error and stop the simulation.
```python
async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    # Debug messages in case it fails
    dut.log.custom( f'Test: TDATA_NUM_BYTES={dut.TDATA_NUM_BYTES.value.integer}, idle_inserter={idle_inserter}, backpressure_inserter={backpressure_inserter}' )

    tb = TB(dut)

    id_count = 2**len(tb.source.bus.tid)

    cur_id = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames = []

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id
        await tb.source.send(test_frame)

        test_frames.append(test_frame)

        cur_id = (cur_id + 1) % id_count

    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()

        assert rx_frame.tdata == CalculateExpectedResult(test_frame.tdata, 'little')
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser

    assert tb.sink.empty()
    dut.log.custom( f'.... passed test' )
```

Now, run the cocoTB python script and grep for the CUSTOM logging prints
```bash
pytest --capture=tee-sys --log-cli-level=INFO tests/test_MyAxiStreamModuleWrapper.py | grep CUSTOM
```

Here's an example of what the output of that `pytest` command would look like:
```bash
$ pytest -rP tests/test_MyAxiStreamModuleWrapper.py  | grep CUSTOM
INFO     cocotb:simulator.py:305      0.00ns CUSTOM   cocotb.myaxistreammodulewrapper    Test: TDATA_NUM_BYTES=4, idle_inserter=None, backpressure_inserter=None
INFO     cocotb:simulator.py:305   1510.00ns CUSTOM   cocotb.myaxistreammodulewrapper    .... passed test
INFO     cocotb:simulator.py:305   1510.00ns CUSTOM   cocotb.myaxistreammodulewrapper    Test: TDATA_NUM_BYTES=4, idle_inserter=None, backpressure_inserter=<function cycle_pause at 0x7fca1abde4d0>
INFO     cocotb:simulator.py:305   7340.00ns CUSTOM   cocotb.myaxistreammodulewrapper    .... passed test
INFO     cocotb:simulator.py:305   7340.00ns CUSTOM   cocotb.myaxistreammodulewrapper    Test: TDATA_NUM_BYTES=4, idle_inserter=<function cycle_pause at 0x7fca1abde4d0>, backpressure_inserter=None
INFO     cocotb:simulator.py:305  13170.00ns CUSTOM   cocotb.myaxistreammodulewrapper    .... passed test
INFO     cocotb:simulator.py:305  13170.00ns CUSTOM   cocotb.myaxistreammodulewrapper    Test: TDATA_NUM_BYTES=4, idle_inserter=<function cycle_pause at 0x7fca1abde4d0>, backpressure_inserter=<function cycle_pause at 0x7fca1abde4d0>
INFO     cocotb:simulator.py:305  19000.00ns CUSTOM   cocotb.myaxistreammodulewrapper    .... passed test
```

<!--- ########################################################################################### -->

### How to view the digital logic waveforms after the simulation

After running the cocoTB simulation, a `.ghw` file with all the traces will be dumped
into the build output path.  You can use `gtkwave` to display these simulation traces:
```bash
gtkwave build/MyAxiStreamModuleWrapper/MyAxiStreamModuleWrapper.ghw
```
<img src="ref_files/gtkwave.png" width="1000">

<!--- ########################################################################################### -->

## Explore Time!

At this point, we have added all the custom AXI stream module code for the
example cocoTB testbed python provided in the lab.  If you have extra
time in the lab, please play around with modifying the firmware/software
and testing them in the cocoTB software simulator.

<!--- ########################################################################################### -->
