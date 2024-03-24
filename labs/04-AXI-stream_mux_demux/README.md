# AXI-stream_mux_demux

This lab is an introduction to the SURF's AXI stream MUX/DEMUX (Multiplexer/Demultiplexer).
By the end of this lab, you will be able to understand the following:
- How to use the SURF AXI stream MUX and AXI stream DEMUX
- How to configure the generics in the MUX/DEMUX for different modes
- How to simulate the AXI stream module using cocoTB

The details of the AXI stream protocol will not be discussed in detail in this lab.
Please refer to the AXI stream protocol specification for the complete details:
[AMBA 4 AXI4-Stream Protocol Specification, ARM IHI 0051A (ID030610)](https://documentation-service.arm.com/static/642583d7314e245d086bc8c9?token=)

<!--- ########################################################################################### -->

## Copy the template to the RTL directory

First, copy the AXI stream template from the `ref_files`
directory to the `rtl` and rename it on the way.
```bash
cp ref_files/MyAxiStreamMuxDemux_start.vhd rtl/MyAxiStreamMuxDemux.vhd
```
Please open the `rtl/MyAxiStreamMuxDemux.vhd` file in
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

This MyAxiStreamMuxDemux has the following entity definition:
```vhdl
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
```
* `TPD_G`: Simulation only generic used to add delay after the register stage.
This generic has no impact to synthesis or Place and Route (PnR).
Primary purpose is to help with visually looking at simulation waveforms.
* `MUX_STREAMS_G` is the number of AXI stream buses between the DEMUX and MUX modules
* `MODE_G` is a string that defines how the MUX/DEMUX will use tDest
  - In INDEXED mode, the output TDEST is set based on the selected slave index (default)
  - In ROUTED mode, TDEST is set according to the TDEST_ROUTES_G table
  - In PASSTHROUGH mode, TDEST is passed through from the slave untouched
* `TDEST_ROUTES_G` is a 8-bit std_logic_vector array used when MODE_G="TDEST_ROUTES_G"
  - Each TDEST bit can be set to '0', '1' or '-' for passthrough from slave TDEST.
*`TDEST_LOW_G` is a integer range from 0 to 7
  - In MODE_G="INDEXED", assign slave index to TDEST at this bit offset
* `ILEAVE_EN_G` is a boolean, set to true if interleaving tDEST mode
* `ILEAVE_ON_NOTVALID_G` is a boolean
  - rearbitrate when tValid drops on selected channel, ignored when ILEAVE_EN_G=false
* `ILEAVE_REARB_G` is a natural range from 0 to 4095 (zero inclusive)
  - Max number of transactions between arbitrations, 0 = unlimited, ignored when ILEAVE_EN_G=false
* `REARB_DELAY_G` is a boolean
  - One cycle gap in stream between during re-arbitration
  - Set true for better timing, false for higher throughput
* `FORCED_REARB_HOLD_G` is a boolean
  - Block selected slave transactions arriving on same cycle as rearbitrate or disableSel from going through, creating 1 cycle gap
  - This might be needed logically but decreases throughput
* `PIPE_STAGES_G` is a natural for setting pipelining in the tReady flow control
  - If zero, then using combinatorial output (lower latency but harder to make timing)
  - If greater than zero, sets the registered pipeline of tReady (high latency but better timing)
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

Replace "-- Placeholder for signals" with the following signals:
```vhdl
   signal axisMasters : AxiStreamMasterArray(MUX_STREAMS_G-1 downto 0);
   signal axisSlaves  : AxiStreamSlaveArray(MUX_STREAMS_G-1 downto 0);
```
* `axisMasters`: an array of AXI stream master buses
[`AxiStreamMasterArray`](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L50) record type
* `axisSlaves`: an array of AXI stream slave buses
[`AxiStreamSlaveArray`](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-stream/rtl/AxiStreamPkg.vhd#L63) record type

<!--- ########################################################################################### -->

## Adding modules into the VHDL body

Replace "-- Placeholder for modules" with the following modules and connections:
```vhdl
   U_DeMux : entity surf.AxiStreamDeMux
      generic map (
         TPD_G          => TPD_G,
         NUM_MASTERS_G  => MUX_STREAMS_G,
         MODE_G         => MODE_G,
         TDEST_ROUTES_G => TDEST_ROUTES_G,
         TDEST_LOW_G    => TDEST_LOW_G,
         PIPE_STAGES_G  => PIPE_STAGES_G)
      port map (
         -- Clock and reset
         axisClk      => axisClk,
         axisRst      => axisRst,
         -- Slave
         sAxisMaster  => sAxisMaster,
         sAxisSlave   => sAxisSlave,
         -- Masters
         mAxisMasters => axisMasters,
         mAxisSlaves  => axisSlaves);

   U_Mux : entity surf.AxiStreamMux
      generic map (
         TPD_G                => TPD_G,
         NUM_SLAVES_G         => MUX_STREAMS_G,
         MODE_G               => MODE_G,
         TDEST_ROUTES_G       => TDEST_ROUTES_G,
         TDEST_LOW_G          => TDEST_LOW_G,
         ILEAVE_EN_G          => ILEAVE_EN_G,
         ILEAVE_ON_NOTVALID_G => ILEAVE_ON_NOTVALID_G,
         ILEAVE_REARB_G       => ILEAVE_REARB_G,
         REARB_DELAY_G        => REARB_DELAY_G,
         FORCED_REARB_HOLD_G  => FORCED_REARB_HOLD_G,
         PIPE_STAGES_G        => PIPE_STAGES_G)
      port map (
         -- Clock and reset
         axisClk      => axisClk,
         axisRst      => axisRst,
         -- Slaves
         sAxisMasters => axisMasters,
         sAxisSlaves  => axisSlaves,
         -- Master
         mAxisMaster  => mAxisMaster,
         mAxisSlave   => mAxisSlave);
```

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
that follow on how to deploy and utilize cocoTB to test the MyAxiStreamMuxDemuxWrapper effectively.

<!--- ########################################################################################### -->

### Why the `rtl/MyAxiStreamMuxDemuxWrapper.vhd`?

cocoTB's AXI extension package does NOT support record types for the AXI interface between
the firmware and the cocoTB simulation. This is a same issue as with AMD/Xilinx IP Integrator.
Both tool only accept `std_logic` (`sl`) and `std_logic_vector` (`slv`) port types. The work-around
for both tools is to use a wrapper that translates the AXI record types to `std_logic` (sl) and
`std_logic_vector` (slv).  For this lab we will be using
`surf.SlaveAxiStreamIpIntegrator` and `surf.MasterAxiStreamIpIntegrator` for translation:

```vhdl
entity MyAxiStreamMuxDemuxWrapper is
   generic (
      -- AXI Stream Configuration
      MUX_STREAMS        : positive               := 2;
      ILEAVE_EN          : boolean                := false;
      ILEAVE_ON_NOTVALID : boolean                := false;
      ILEAVE_REARB       : natural                := 0;
      REARB_DELAY        : boolean                := true;
      FORCED_REARB_HOLD  : boolean                := false;
      PIPE_STAGES        : natural                := 0;
      -- IP Integrator AXI Stream Configuration
      TUSER_WIDTH        : natural range 1 to 8   := 2;
      TID_WIDTH          : natural range 1 to 8   := 1;
      TDEST_WIDTH        : natural range 1 to 8   := 1;
      TDATA_NUM_BYTES    : natural range 1 to 128 := 4);
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
end MyAxiStreamMuxDemuxWrapper;

architecture mapping of MyAxiStreamMuxDemuxWrapper is

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
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
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

   U_MyAxiStreamMuxDemux : entity work.MyAxiStreamMuxDemux
      generic map (
         MUX_STREAMS_G        => MUX_STREAMS,
         ILEAVE_EN_G          => ILEAVE_EN,
         ILEAVE_ON_NOTVALID_G => ILEAVE_ON_NOTVALID,
         ILEAVE_REARB_G       => ILEAVE_REARB,
         REARB_DELAY_G        => REARB_DELAY,
         FORCED_REARB_HOLD_G  => FORCED_REARB_HOLD,
         PIPE_STAGES_G        => PIPE_STAGES)
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
         HAS_TLAST       => 1,
         HAS_TKEEP       => 1,
         HAS_TSTRB       => 1,
         HAS_TREADY      => 1,
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
create_bd_cell -type module -reference MyAxiStreamMuxDemuxWrapper MyAxiStreamMuxDemux_0
```
<img src="ref_files/IpIntegrator.png" width="1000">

<!--- ########################################################################################### -->

### How to run the cocoTB testing script

Run "make". This Makefile will finds all the source code paths via ruckus.tcl for cocoTB simulation.
```bash
make
```

The `tests/test_MyAxiStreamMuxDemuxWrapper.py` cocotb test script is provided in this lab.
This cocotb script uses the [cocotbext-axi library](https://pypi.org/project/cocotbext-axi/),
which provides a cocotb API for communicating with the firmware via AXI, AXI-Lite, and AXI-stream interfaces.

In the `test_MyAxiStreamMuxDemuxWrapper.py`, the `run_test()` function will be run with four different combinations of AXI-stream traffic:
- No IDLEs inserted, no backpressure applied
- No IDLEs inserted, backpressure applied
- IDLEs inserted, no backpressure applied
- IDLEs inserted, backpressure applied

For each `run_test()`, the code will compare the payload sent to the firmware DEMUX and confirm that it matches the
payload received by the firmware MUX.
If there is a mismatch between the sent/received payload, the code will raise an exception error and stop the simulation.
```python
async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None):

    dut.log.custom( f'run_test(): idle_inserter={idle_inserter}, backpressure_inserter={backpressure_inserter}' )

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

        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == test_frame.tdest
        assert not rx_frame.tuser

    assert tb.sink.empty()
    dut.log.custom( f'.... passed test' )
```

Now, run the cocoTB python script and grep for the CUSTOM logging prints
```bash
pytest -rP tests/test_MyAxiStreamMuxDemuxWrapper.py  | grep CUSTOM
```

Here's an example of what the output of that `pytest` command would look like:
```bash
$ pytest -rP tests/test_MyAxiStreamMuxDemuxWrapper.py | grep CUSTOM
INFO     cocotb:simulator.py:305      0.00ns CUSTOM   cocotb.myaxistreammuxdemuxwrapper  run_test(): idle_inserter=None, backpressure_inserter=None
INFO     cocotb:simulator.py:305    920.00ns CUSTOM   cocotb.myaxistreammuxdemuxwrapper  .... passed test
INFO     cocotb:simulator.py:305    920.00ns CUSTOM   cocotb.myaxistreammuxdemuxwrapper  run_test(): idle_inserter=None, backpressure_inserter=<function cycle_pause at 0x714ff3376320>
INFO     cocotb:simulator.py:305   3835.00ns CUSTOM   cocotb.myaxistreammuxdemuxwrapper  .... passed test
INFO     cocotb:simulator.py:305   3835.00ns CUSTOM   cocotb.myaxistreammuxdemuxwrapper  run_test(): idle_inserter=<function cycle_pause at 0x714ff3376320>, backpressure_inserter=None
INFO     cocotb:simulator.py:305   6755.00ns CUSTOM   cocotb.myaxistreammuxdemuxwrapper  .... passed test
INFO     cocotb:simulator.py:305   6755.00ns CUSTOM   cocotb.myaxistreammuxdemuxwrapper  run_test(): idle_inserter=<function cycle_pause at 0x714ff3376320>, backpressure_inserter=<function cycle_pause at 0x714ff3376320>
INFO     cocotb:simulator.py:305   9690.00ns CUSTOM   cocotb.myaxistreammuxdemuxwrapper  .... passed test
```

<!--- ########################################################################################### -->

### How to view the digital logic waveforms after the simulation

After running the cocoTB simulation, a `.ghw` file with all the traces will be dumped
into the build output path.  You can use `gtkwave` to display these simulation traces:
```bash
gtkwave build/MyAxiStreamMuxDemuxWrapper/MyAxiStreamMuxDemuxWrapper.ghw
```
<img src="ref_files/gtkwave.png" width="1000">

<!--- ########################################################################################### -->

## Explore Time!

At this point, we have added lab's AXI stream MUX/DEMUX code for the
example cocoTB testbed python provided in the lab.  If you have extra
time in the lab, please play around with modifying the firmware/software
and testing them in the cocoTB software simulator.

<!--- ########################################################################################### -->
