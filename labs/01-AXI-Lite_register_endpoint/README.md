# 01-AXI-Lite_register_endpoint

This lab is intended to be the first of many tutorial labs on SURF.
Unlike the other labs, it will go into more details on the "two-process" coding
and other SURF coding standards.
By the end of this lab, you will be able to understand the following:
- How to use the SURF AXI-Lite helper functions/procedures
- How to add custom read/write, read-only, and write-only registers
- How to simulate the AXI-Lite endpoint using cocoTB

The details of the AXI-Lite protocol will not be discussed in detail in this lab.
Please refer to the AXI-Lite protocol specification for the complete details:
[AMBA AXI and ACE Protocol Specification, ARM ARM IHI 0022E (ID033013)](https://documentation-service.arm.com/static/5f915b62f86e16515cdc3b1c?token=)

<!--- ########################################################################################### -->

## Copy the template to the RTL directory

First, copy the AXI-Lite endpoint template from the `ref_files`
directory to the `rtl` and rename it on the way.
```bash
cp ref_files/MyAxiLiteEndpoint_start.vhd rtl/MyAxiLiteEndpoint.vhd
```
Please open the `rtl/MyAxiLiteEndpoint.vhd` file in
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

This MyAxiLiteEndpoint has the following entity definition:
```vhdl
entity MyAxiLiteEndpoint is
   generic (
      TPD_G          : time := 1 ns;    -- Simulated propagation delay
      FW_VERSION_G   : slv(31 downto 0);
      GIT_HASH_G     : slv(159 downto 0);
      BUILD_STRING_G : Slv32Array(0 to 63));
   port (
      -- AXI-Lite Bus
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType;
      statusA         : in sl;
      statusB         : in slv(3 downto 0));
end MyAxiLiteEndpoint;
```
* `TPD_G`: Simulation only generic used to add delay after the register stage.
This generic has no impact to synthesis or Place and Route (PnR).
Primary purpose is to help with visually looking at simulation waveforms.
* `PRJ_VERSION_G`: same as `PRJ_VERSION` environmental variable in the local Makefile.
* `GIT_HASH_G`: 160-bit value of the git repo's hash at the time of the build. A zero value will be used if the git clone is "dirty".
* `BUILD_STRING_G`: an ASCII string of useful build information at the
time of the build that's packed into 64 by 32-bit std_logic_vectors
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
* `statusA`: A 1-bit status input
* `statusB`: A 4-bit status input

<!--- ########################################################################################### -->

## Signals, Types, and Constants Definition

This MyAxiLiteEndpoint has the following signals, types, constants:
```vhdl
   type RegType is record
      scratchPad     : slv(31 downto 0);
      cnt            : slv(31 downto 0);
      enableCnt      : sl;
      resetCnt       : sl;
      axilReadSlave  : AxiLiteReadSlaveType;
      axilWriteSlave : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
      scratchPad     => x"DEAD_BEEF",
      cnt            => (others => '0'),
      enableCnt      => '0',
      resetCnt       => '0',
      axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
```
* `RegType`: record type definition for the registers in the “two-process” coding style
  - `scratchPad`: 32-bit general purpose read/write register
  - `cnt`: 32-bit counter that's controlled by startCnt/stopCnt
  - `enableCnt`: Enable counter flag
  - `resetCnt': Reset the counter to zero
  - `axilReadSlave`: AXI-Lite read slave bus used to respond to a read transactions
  - `axilWriteSlave`: AXI-Lite write slave bus used to respond to a write transactions
* `REG_INIT_C`: constant defining the registers' initialized values after reset
* `r`: signal from the registers that are feed into the combinational process and initialized to REG_INIT_C
  - Note: Initializing signals in VHDL only valid in FPGA designs and not possible for digital ASICs
* `rin`: signal from the combinational process that is feed back into the register process

<!--- ########################################################################################### -->

## Combinatorial Process

There are two variables defined in the combinatorial process:
```vhdl
      variable v      : RegType;
      variable axilEp : AxiLiteEndpointType;
```

`v` is "RegType", which is the same as the `r` signal.
At the start of the combinatorial process, there is a `v := r;` assignment.
This gives `v` the current output value of each register.

The `v` variable is manipulated through the combinatorial process.
At the very end of the process, there is a `rin <= v;`, which is feed back to the register process.
This means that every register will default to it's previous value each clock cycle, unless
directed otherwise in the combinatoral process logic. This is quite powerful, as it elimanates 
the possiblility of partially assigned registers inferring latches in synthesis. It also often
simplifies the application logic.

Anywhere in the code that starts with a `v.` means it is a "variable" and `r.` means it is a "registers".

The `axilEp` variable is [AxiLiteEndpointType](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L193)
and contains all the information used to detect read/write transaction and returning the transaction response.

<!--- ########################################################################################### -->

### Counter Logic
At the beginning the `resetCnt` variable is set to `'0'`. As we will see later, this has the effect
of stobing the register for just 1 clock cycle when it is written by the AXI-Lite bus.

The counter will check if the `enableCnt` register is active.  If active, then increment the counter.

Next it will check if the `resetCnt` register is `'1'`. If so it will reset the counter to zero.
Note that this overrides any counter increment performed above. By placing this logic "below", 
we have effectivly specified that `resetCnt` takes precedence over `enableCnt`.


```vhdl
      --------------------
      -- Reset strobe
      --------------------
      v.resetCnt := '0';

      ------------------------
      -- Counter logic
      ------------------------

      -- Check if enabling counter
      if (r.enableCnt = '1') then
         -- Increment the counter
         v.cnt := r.cnt + 1;
      end if;

      -- Check if we are resetting the counter
      if (r.resetCnt = '1') then
         -- Set the flag
         v.cnt := (others => '0');
      end if;

```

<!--- ########################################################################################### -->

### AXI-Lite Transaction
The [`axiSlaveWaitTxn()` procedure](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L731)
(defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd))
determines which type of transaction if any exists.

"Placeholder for your code will go here" is where we will put the register mapping later in the lab.

The [`axiSlaveDefault()` procedure](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L1005)
(defined in [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd))
is used to closeout the transaction.  The last argument in this
procedure is what the AXI-Lite response should be to "unmapped" register space.
The [`AXI_RESP_DECERR_C`](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd#L46)
is used for this "unmapped" transaction response.

Note: It is possible in AXI-Lite to have both a read and write transaction to happen
at the same time. These helper function support simultaneous write/read.


```vhdl
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
```

<!--- ########################################################################################### -->

#### Synchronous Reset
At the bottom of the combinatoral process, a synchronous reset of the entire module is
encoded. This will override any other assignment to `v` from above, and effectively return all module 
registers to their initial value on the next clock cycle.

```vhdl
      if (axilRst = '1') then
         v := REG_INIT_C;
      end if;
```

<!--- ########################################################################################### -->

## Register Process

This is the "common" boiler plate register process used in all the SURF code.
It takes the combinatorial process output (`rin`) and registers it to the `r` signal
with a `TPD_G` delay for simulation.

```vhdl
   seq : process (axilClk) is
   begin
      if rising_edge(axilClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;
```

<!--- ########################################################################################### -->

## Adding custom AXI-Lite registers using SURF procedures

Two AXI-Lite procedures will be heavily used in this lab:
* `axiSlaveRegisterR()`: Used for mapping "read-only" registers
* `axiSlaveRegister ()`: Used for mapping "read/write" or "write-only" registers

There are axiSlaveRegisterR() is function overload for `sl`, `slv`, or slv32Array (special case)
in the [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):

```vhdl
   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : in    sl);

   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : in    slv);

   procedure axiSlaveRegisterR (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      regs        : in    slv32Array);
```
where ...
- `ep` is the `axilEp` variable in our combinatorial process
- `addr` is the address offset (in units of bytes)
- `offset` is the bit offset (in units of bits)
- `reg` is the `sl` or `slv` value being read
- `regs` is the array of 32-bit registers being read

There are axiSlaveRegister() is function overload for `sl`, `slv`, or slv32Array (special case)
in the [AxiLitePkg](https://github.com/slaclab/surf/blob/v2.47.1/axi/axi-lite/rtl/AxiLitePkg.vhd)):

```vhdl
   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout sl);

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      offset      : in    integer;
      reg         : inout slv);

   procedure axiSlaveRegister (
      variable ep : inout AxiLiteEndpointType;
      addr        : in    slv;
      regs        : inout slv32Array);
```
where ...
- `ep` is the `axilEp` variable in our combinatorial process
- `addr` is the address offset (in units of bytes)
- `offset` is the bit offset (in units of bits)
- `reg` is the `sl` or `slv` value being written or read
- `regs` is the array of 32-bit registers being written or read

<!--- ########################################################################################### -->

### Add PRJ_VERSION_G (Read-only Register)

Replace `-- Placeholder for your code will go here` line with the following:
```vhdl
      axiSlaveRegisterR(axilEp, x"000", 0, PRJ_VERSION_G);
```
`PRJ_VERSION_G` generic is the same as `PRJ_VERSION` environmental variable in the local Makefile.
The `axiSlaveRegisterR()` VHDL code above will map the 32-bit value
to address offset 0x000 using `axilEp` to hold the transaction response
information. When the read address is `0x----_-000`, then the `fwVersion` will
be returned.  When the write address is `0x----_-000`, then the `AXI_RESP_DECERR_C`
will be the write transaction response.

Note: The axiSlaveRegisterR()/axiSlaveRegister() automatically determines the width
of the address argument and will use the `std_match` function, which is why the `-`
character defined in the address description above. This means the "absolute" address
does not need to be defined at the end point (only the lower address decoding bits).
Using relative address with axiSlaveRegisterR()/axiSlaveRegister() enables the code
to be reusable for different device address offsets.

<!--- ########################################################################################### -->

### Add ScratchPad (Read/Write Register)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegister (axilEp, x"004", 0, v.scratchPad);
```
`scratchPad` is a 32-bit general purpose read/write register.  Notice how we are
using the `v.scratchPad` variable (instead of `r.scratchPad` register) to set
the value via the axiSlaveRegister() procedure.  When the read (or write)
address `0x----_-004` is  detected, a read (or write) transaction on
the `scratchPad` will occur.

Note: The address is in units of bytes.  AXI-Lite is a 32-bit transaction with the
`wstrb` metadata field to do byte level `write` transactions.  We recommend using 32-bit
word strides (4 bytes) for mapping the addresses because it is more human readable
and helps with mapping the registers from firmware to software.

<!--- ########################################################################################### -->

### Add cnt (Read-only Register)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegisterR(axilEp, x"008", 0, r.cnt);
```
`cnt` is 32-bit counter that's controlled by startCnt/stopCnt. Notice how we are
using the `r.cnt` register (instead of `v.cnt` variable) to get
the value into the axiSlaveRegisterR() procedure.
When the read address is `0x----_-008`, then the `cnt` will be returned.
When the write address is `0x----_-008`, then the `AXI_RESP_DECERR_C`
will be the write transaction response.  Every time that we read from this register
we will get the "current" value of the "cnt", which could be changing between AXI-Lite
register transactions.

<!--- ########################################################################################### -->

### Add enableCnt (read/write Register)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegister(axilEp, x"00C", 0, v.enableCnt);
```
`enableCnt` is the enable counter flag. When encoded this way, the register will retain the 
value written to it from the AXI-bus on subsequent clock cycles. 


<!--- ########################################################################################### -->

### Add resetCnt ("write-only" Register)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegister(axilEp, x"010", 0, v.resetCnt);
```
`resetCnt` is used to reset the counter to zero. Recall the `v.resetCnt := '0'` statement from
the counter logic above. When coded this way, writing x"010" to '1' via AXI-Lite will override
the `v.resetCnt := '0'` assignment and cause the `resetCnt` register to pulse high for one 
clock cycle. We call this a "write-only" register because the write has no effect on the readback 
value. Reading x"010 on the AXI-Lite bus will always return 0, because the `resetCnt` register
will have already returned back to 0.

<!--- ########################################################################################### -->

### Add statusA and statusB (read-only Registers)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegisterR(axilEp, x"014", 0, statusA);
      axiSlaveRegisterR(axilEp, x"014", 8, statusB);
```
`statusA` and `statusB` registers are taken directly from the module inputs. (It is assumed that
they are synchronous to `axilClk`.) We are mapping two registers on the same AXI-Lite
address in this example. The 3rd argument is the bitOffset. The bitOffset determines where 
in the 32-bit data that the register is mapped.

Note that the statusB register could be equivalenly encoded as
```vhdl
      axiSlaveRegisterR(axilEp, x"015", 0, statusB);
```
This "non 4-byte algined" address is supported by the `axiSlaveRegister()` procedures. It is
good practice however to keep all addresses aligned with 4-byte strides, with bitOffsets to
determine the 32-bit position, as originally shown.

<!--- ########################################################################################### -->

### Add GIT_HASH_G (read-only Registers)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegisterR(axilEp, x"100", 0, GIT_HASH_G);
```

`GIT_HASH_G` is 160-bit value of the git repo's hash at the time of the build 
and is a zero value will be used if the git clone is "dirty".
axiSlaveRegister()/axiSlaveRegisterR() supports mapping values that are greater
than 32-bit bits, which will require multiple AXI-Lite read (or write)
transactions to get (or set) the value.

<!--- ########################################################################################### -->

### Add BUILD_STRING_G (read-only Registers)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegisterR(axilEp, x"200", BUILD_STRING_G);
```
 `BUILD_STRING_G` is an ASCII string of useful build information at the
time of the build that's packed into 64 by 32-bit std_logic_vectors
axiSlaveRegister()/axiSlaveRegisterR() supports mapping of an array of
32-bit registers, which will require multiple AXI-Lite read (or write)
transactions to get (or set) the value.

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
that follow on how to deploy and utilize cocoTB to test the MyAxiLiteEndpointWrapper effectively.

<!--- ########################################################################################### -->

### Why the `rtl/MyAxiLiteEndpointWrapper.vhd`?

cocoTB's AXI extension package does NOT support record types for the AXI interface between
the firmware and the cocoTB simulation. This is a same issue as with AMD/Xilinx IP Integrator.
Both tool only accept `std_logic` (`sl`) and `std_logic_vector` (`slv`) port types. The work-around 
for both tools is to use a wrapper that translates the AXI record types to `std_logic` (sl) and 
`std_logic_vector` (slv).  For this lab we will be using `surf.SlaveAxiLiteIpIntegrator` for translation:

```vhdl
entity MyAxiLiteEndpointWrapper is
   generic (
      EN_ERROR_RESP : boolean  := false;
      FREQ_HZ       : positive := 100000000);             -- Units of Hz
   port (
      -- AXI-Lite Interface
      S_AXI_ACLK    : in  std_logic;
      S_AXI_ARESETN : in  std_logic;
      S_AXI_AWADDR  : in  std_logic_vector(11 downto 0);  -- Must match ADDR_WIDTH_C
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
      S_AXI_ARADDR  : in  std_logic_vector(11 downto 0);  -- Must match ADDR_WIDTH_C
      S_AXI_ARPROT  : in  std_logic_vector(2 downto 0);
      S_AXI_ARVALID : in  std_logic;
      S_AXI_ARREADY : out std_logic;
      S_AXI_RDATA   : out std_logic_vector(31 downto 0);
      S_AXI_RRESP   : out std_logic_vector(1 downto 0);
      S_AXI_RVALID  : out std_logic;
      S_AXI_RREADY  : in  std_logic);
end MyAxiLiteEndpointWrapper;

architecture mapping of MyAxiLiteEndpointWrapper is

   constant BUILD_INFO_DECODED_C : BuildInfoRetType := toBuildInfo(BUILD_INFO_C);

   constant ADDR_WIDTH_C : positive := 12;  -- Must match the entity's port width

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

   U_MyAxiLiteEndpoint : entity work.MyAxiLiteEndpoint
      generic map (
         PRJ_VERSION_G  => BUILD_INFO_DECODED_C.fwVersion,
         GIT_HASH_G     => BUILD_INFO_DECODED_C.gitHash,
         BUILD_STRING_G => BUILD_INFO_DECODED_C.buildString)
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
create_bd_cell -type module -reference MyAxiLiteEndpointWrapper MyAxiLiteEndpoint_0
```
<img src="ref_files/IpIntegrator.png" width="1000">

<!--- ########################################################################################### -->

### How to run the cocoTB testing script

Use the Makefile + ruckus + GHDL to collect all the source code via ruckus.tcl for cocoTB simulation:
```bash
make
```

Next, run the cocoTB python script and grep for the CUSTOM logging prints
```bash
pytest -rP tests/test_MyAxiLiteEndpointWrapper.py  | grep CUSTOM
```

Here's an example of what the output of that `pytest` command would look like:
```bash
$ pytest -rP tests/test_MyAxiLiteEndpointWrapper.py  | grep CUSTOM
INFO     cocotb:simulator.py:305     90.00ns CUSTOM   cocotb.tb                          FpgaVersion=0x1020304
INFO     cocotb:simulator.py:305    130.00ns CUSTOM   cocotb.tb                          scratchpad(init value)=0xdeadbeef
INFO     cocotb:simulator.py:305    210.00ns CUSTOM   cocotb.tb                          Passed the scratchpad testing
INFO     cocotb:simulator.py:305    250.00ns CUSTOM   cocotb.tb                          cnt(init value)=0x0
INFO     cocotb:simulator.py:305    290.00ns CUSTOM   cocotb.tb                          enableCnt(init value)=0x0
INFO     cocotb:simulator.py:305   1370.00ns CUSTOM   cocotb.tb                          cnt(running)=0x66
INFO     cocotb:simulator.py:305   1410.00ns CUSTOM   cocotb.tb                          enableCnt(running)=0x1
INFO     cocotb:simulator.py:305   1490.00ns CUSTOM   cocotb.tb                          cnt(stopped)=0x70
INFO     cocotb:simulator.py:305   1530.00ns CUSTOM   cocotb.tb                          enableCnt(stopped)=0x0
INFO     cocotb:simulator.py:305   1650.00ns CUSTOM   cocotb.tb                          gitHash=0xb9b6a2350e1715d1c4b980301a291864d674a581
INFO     cocotb:simulator.py:305   2950.00ns CUSTOM   cocotb.tb                          buildString=': GHDL 1.0.0 (Ubuntu 1.0.0+dfsg-6) [Dunoon edition], rdsrv409 (Linux-6.5.0-21-generic-x86_64-with-glibc2.35), Built Wed Mar 13 12:05:38 PM PDT 2024 by ruckman'
```

In the test_MyAxiLiteEndpointWrapper.py, the following code is used to interact with the AXI-Lite endpoint:

```python
    # Get the FpgaVersion register
    rdTxn = await tb.axil.read(address=0x000, length=4)
    assert rdTxn.resp == AxiResp.OKAY
    tb.log.custom( f'FpgaVersion={rdDataToStr(rdTxn.data)}' )

    # Test the scratchpad write/read operations
    rdTxn = await tb.axil.read(address=0x004, length=4)
    tb.log.custom( f'scratchpad(init value)={rdDataToStr(rdTxn.data)}' )
    testWord = int(random.getrandbits(32)).to_bytes(4, "little")
    wrTxn = await tb.axil.write(address=0x004, data=testWord)
    assert wrTxn.resp == AxiResp.OKAY
    rdTxn = await tb.axil.read(address=0x004, length=4)
    assert rdTxn.resp == AxiResp.OKAY
    assert rdTxn.data == testWord
    tb.log.custom( f'Passed the scratchpad testing' )

    # Check the default r.cnt and r.enableCnt values
    rdTxn = await tb.axil.read(address=0x008, length=4)
    tb.log.custom( f'cnt(init value)={rdDataToStr(rdTxn.data)}' )
    rdTxn = await tb.axil.read(address=0x011, length=1)
    tb.log.custom( f'enableCnt(init value)={rdDataToStr(rdTxn.data)}' )

    # Start the counter and wait 100 cycles
    wrTxn = await tb.axil.write(address=0x00C, data=int(0x1).to_bytes(4, "little"))
    assert wrTxn.resp == AxiResp.OKAY
    await tb.add_delay(100)

    # Measure r.cnt and r.enableCnt values
    rdTxn = await tb.axil.read(address=0x008, length=4)
    tb.log.custom( f'cnt(running)={rdDataToStr(rdTxn.data)}' )
    rdTxn = await tb.axil.read(address=0x011, length=1)
    tb.log.custom( f'enableCnt(running)={rdDataToStr(rdTxn.data)}' )

    # Stop the counter and check final count value and that it actually stopped
    wrTxn = await tb.axil.write(address=0x00C, data=int(0x2).to_bytes(4, "little"))
    assert wrTxn.resp == AxiResp.OKAY
    rdTxn = await tb.axil.read(address=0x008, length=4)
    tb.log.custom( f'cnt(stopped)={rdDataToStr(rdTxn.data)}' )
    rdTxn = await tb.axil.read(address=0x011, length=1)
    tb.log.custom( f'enableCnt(stopped)={rdDataToStr(rdTxn.data)}' )

    # Get the Git Hash
    rdTxn = await tb.axil.read(address=0x100, length=20)
    assert rdTxn.resp == AxiResp.OKAY
    tb.log.custom( f'gitHash={rdDataToStr(rdTxn.data)}' )

    # Get the BuildStamp string
    rdTxn = await tb.axil.read(address=0x200, length=256)
    assert rdTxn.resp == AxiResp.OKAY
    buildString = repr(rdTxn.data.decode('utf-8').rstrip('\x00'))
    tb.log.custom( f'buildString={buildString}' )
```

<!--- ########################################################################################### -->

### How to view the digital logic waveforms after the simulation

After running the cocoTB simulation, a `.ghw` file with all the traces will be dumped
into the build output path.  You can use `gtkwave` to display these simulation traces:
```bash
gtkwave build/MyAxiLiteEndpointWrapper/MyAxiLiteEndpointWrapper.ghw
```
<img src="ref_files/gtkwave.png" width="1000">

<!--- ########################################################################################### -->

## Explore Time!

At this point, we have added all the custom AXI-Lite registers for the
example cocoTB testbed python provided in the lab.  If you have extra
time in the lab, please play around with adding/modifying the firmware
registers and testing them in the cocoTB software simulator.

<!--- ########################################################################################### -->
