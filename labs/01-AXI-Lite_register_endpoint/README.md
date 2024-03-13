# 01-AXI-Lite_register_endpoint

This lab is intended to be the first of many tutorial labs on SURF.
It will go into more details on the "two-process" coding 
and other SURF coding standards that the other labs will.
By the end of this lab, you will be able to understand the following:
- How to use the SURF AXI-Lite helper functions/procedures
- How to add custom read/write, read-only, and write-only registers
- How to simulate the AXI-Lite endpoint using cocoTB

The details of the AXI-Lite protocol will not be discussed in detailed in this lab.
Please refer to the AXI-Lite protocol specification for the complete details:
[AMBA AXI and ACE Protocol Specification, ARM ARM IHI 0022E (ID033013)](https://documentation-service.arm.com/static/5f915b62f86e16515cdc3b1c?token=)

<!--- ########################################################################################### -->

## Copy the template to the RTL directory

First, copy the AXI-Lite endpoint template from the `ref_file`
directory to the `rtl` and rename it on the way.
```bash
cp ref_files/MyAxiLiteEndpoint_blank.vhd rtl/MyAxiLiteEndpoint.vhd
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

library ruckus;
use ruckus.BuildInfoPkg.all;
```
Both the Standard Logic Real Time Logic Package (StdRtlPkg) and AXI-Lite 
Package (AxiLitePkg) are included from SURF.  We also include Build 
Information Package (BuildInfoPkg) from ruckus, which is an auto-generated
VHDL file that contains useful information about the build at the time 
of the build.

<!--- ########################################################################################### -->

### Entity Definition

This MyAxiLiteEndpoint has the following entity definition:
```vhdl
entity MyAxiLiteEndpoint is
   generic (
      TPD_G : time := 1 ns); -- Simulated propagation delay
   port (
      -- AXI-Lite Bus
      axilClk         : in  sl;
      axilRst         : in  sl;
      axilReadMaster  : in  AxiLiteReadMasterType;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType;
      axilWriteSlave  : out AxiLiteWriteSlaveType);
end MyAxiLiteEndpoint;
```
* `TPD_G`: Simulation only generic used to add delay after the register stage.
This generic has no impact to synthesis or Place and Route (PnR). 
Primary purpose is to help with visually looking at simulation waveforms.
* `axilClk`: AXI-Lite clock 
* `axilRst`: AXI-Lite reset (active HIGH)
* `axilReadMaster`: AXI-Lite read master input. 
`AxiLiteReadMasterType` record type contains the following signals (defined in AxiLitePkg):
  - araddr  : slv(31 downto 0);
  - arprot  : slv(2 downto 0);
  - arvalid : sl;
  - rready  : sl;
* `axilReadSlave`: AXI-Lite read slave output. 
`AxiLiteReadSlaveType` record type contains the following signals (defined in AxiLitePkg):
  - arready : sl;
  - rdata   : slv(31 downto 0);
  - rresp   : slv(1 downto 0);
  - rvalid  : sl;
* `axilWriteMaster`: AXI-Lite write master input. 
`AxiLiteWriteMasterType` record type contains the following signals (defined in AxiLitePkg):
  - awaddr  : slv(31 downto 0);
  - awprot  : slv(2 downto 0);
  - awvalid : sl;
  - wdata   : slv(31 downto 0);
  - wstrb   : slv(3 downto 0);
  - wvalid  : sl;
  - bready  : sl;
* `axilWriteSlave`: AXI-Lite write slave output. 
`AxiLiteWriteSlaveType` record type contains the following signals (defined in AxiLitePkg):
  - awready : sl;
  - wready  : sl;
  - bresp   : slv(1 downto 0);
  - bvalid  : sl;

<!--- ########################################################################################### -->

### Signals, Types, and Constants Definition

This MyAxiLiteEndpoint has the following signals, types, constants:
```vhdl
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
```
* `RegType`: record type defination for the registers in the “two-process” coding style
  - `scratchPad`: 32-bit general purpose read/write register
  - `cnt`: 32-bit counter that's controlled by startCnt/stopCnt
  - `enableCnt`: Enable counter flag
  - `startCnt`: Write-only register to start the counter
  - `stopCnt`: Write-only register to stop the counter
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
At the start of the combinatorial process, there is a `v := r;`.  
This creates a variable copy of the registers.  

The `v` variable is manipulated through the combinatorial process.
At the very end of the process, there is a `rin <= v;`, which is feed back to the register process.

Anywhere in the code that starts with a `v.` means it is a "variable" and `r.` means it is a "registers".

The `axilEp` variable contains all the information used to detect read/write transaction and returning the transaction response.

<!--- ########################################################################################### -->

### Counter Logic
At the beginning the `startCnt` and `stopCnt` variables are reset to zero.

The counter will check if the `enableCnt` register is active.  If active, then increment the counter.

Next, check if the `startCnt` register is active.  If active, then enable the `enableCnt` variable.

Finally, check if the `stopCnt` register is active.  If active, then disable the `enableCnt` variable.

If both the `startCnt` and `stopCnt` registers are active at the same time, 
the `enableCnt` variable would be set to zero because `stopCnt` "if statement" happens later in the combinatorial process.
```vhdl
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
```

<!--- ########################################################################################### -->

### AXI-Lite Transaction
The `axiSlaveWaitTxn()` procedure (defined in AxiLitePkg) determines which type of transaction
if any exists.  

"Placeholder for your code will go here" is where we will put the register mapping later in the lab.

The `axiSlaveDefault()` procedure is used to closeout the transaction.  The last argument in this 
procedure is what the AXI-Lite responds should be to "unmap" register space.  
The `AXI_RESP_DECERR_C` is used for this "unmapped" transaction response.

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

## Register Process

This is the "common" boiler plate register process used in all the SURF code.
It takes the combinatorial output (`rin`) and registers it to the `r` signal 
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

There are going to be two AXI-Lite procedures used:
* `axiSlaveRegisterR()`: Used for mapping "read-only" registers
* `axiSlaveRegister ()`: Used for mapping "read/write" or "write-only" registers

<!--- ########################################################################################### -->

### Add BUILD_INFO_DECODED_C.fwVersion (Read-only Register)

Replace `-- Placeholder for your code will go here` line with the following:
```vhdl
      axiSlaveRegisterR(axilEp, x"000", BUILD_INFO_DECODED_C.fwVersion);
```
`BUILD_INFO_DECODED_C.fwVersion` is defined in the BuildInfoPkg package and
will equal the `PRJ_VERSION` environmental variable in the local Makefile.  
The `axiSlaveRegisterR()` VHDL code above will map the 32-bit value 
to address offset 0x000 using `axilEp` to hold the transaction response 
information. When the read address is `0x----_-000`, then the `fwVersion` will
be returned.  When the write address is `0x----_-000`, then the `AXI_RESP_DECERR_C`
will be the write transaction responds.

Note: The axiSlaveRegisterR()/axiSlaveRegister() automatically determines the width 
of the address argument and will use the `std_match` function, which is why the `-`
character defined in the address description above. This means the "absolute" address 
does not need to be defined at the end point (only the lower address decoding bits).

<!--- ########################################################################################### -->

### Add ScratchPad (Read/Write Register)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegister (axilEp, x"004", v.scratchPad);
```
`scratchPad` is a 32-bit general purpose read/write register.  Notice how we are
using the `v.scratchPad` variable (instead of `r.scratchPad` register) to set
the value via the axiSlaveRegister() procedure.  When the read (or write) 
address `0x----_-004` is  detected, a read (or write) transaction on 
the `scratchPad` will occur.

Note: The address is in units of bytes.  AXI-Lite is a 32-bit transaction with the
`wstrb` metadata field to do byte level transactions.  We recommend using 32-bit
word strides (4 bytes) for mapping the addresses because it happens with mapping 
the registers from firmware to software.

<!--- ########################################################################################### -->

### Add cnt (Read-only Register)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegisterR(axilEp, x"008", r.cnt);
```
`cnt` is 32-bit counter that's controlled by startCnt/stopCnt. Notice how we are
using the `r.cnt` register (instead of `v.cnt` variable) to get
the value into the axiSlaveRegisterR() procedure. 
When the read address is `0x----_-008`, then the `cnt` will be returned.  
When the write address is `0x----_-008`, then the `AXI_RESP_DECERR_C`
will be the write transaction responds.  Every time that we read from this register
we will get the "current" value of the "cnt", which could be changing between 
register transactions.

<!--- ########################################################################################### -->

### Add startCnt/stopCnt (write-only Registers)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegister (axilEp, x"00C", 0, v.startCnt);
      axiSlaveRegister (axilEp, x"00C", 1, v.stopCnt);
```
`startCnt` and `stopCnt` are used to start and stop the counter. These are 
"write-only" registers because their values changed externally from the AXI-Lite
interface.  We are mapping two registers on the same AXI-Lite write address. The 
3rd argument (default=0) is the bitoffset.  The bitoffset is being explicitly set
to define where in the 32-bit `wdata` that maps to the registers. 

Note: If a read transaction happens at this write-only register offset, the `AXI_RESP_DECERR_C`
will be the read transaction responds. 

<!--- ########################################################################################### -->

### Add enableCnt (read-only Registers)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegisterR(axilEp, x"011", r.enableCnt);
```
`enableCnt` is the enable counter flag. This time we are mapping to a 
non-4 byte word alignment address offset (0x011).  Non-4 byte word alignment is
supported by axiSlaveRegister()/axiSlaveRegisterR().  This mapping will result in 
the same behavior as if we mapped to 0x010 address offset with a 8 bitoffset. 

<!--- ########################################################################################### -->

### Add BUILD_INFO_DECODED_C.gitHash (read-only Registers)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegisterR(axilEp, x"100", BUILD_INFO_DECODED_C.gitHash);
```
`BUILD_INFO_DECODED_C.gitHash` is a 160-bit value of the git repo's hash at the time of the 
build.  It is auto-generated in the BuildInfoPkg package. 
axiSlaveRegister()/axiSlaveRegisterR() supports mapping values that are greater 
than 32-bit bits, which will require multiple AXI-Lite read (or write) 
transactions to get (or set) the value.

<!--- ########################################################################################### -->

### Add BUILD_INFO_DECODED_C.buildString (read-only Registers)

Next, add the following register to the "Mapping read/write registers" section:
```vhdl
      axiSlaveRegisterR(axilEp, x"200", BUILD_INFO_DECODED_C.buildString);
```
`BUILD_INFO_DECODED_C.buildString` is an ASCII string of useful build information at the 
time of the build that's packed into 64 by 32-bit std_logic_vectors ("Slv32Array(0 to 63)").
`BUILD_INFO_DECODED_C.buildString` is auto-generated in the BuildInfoPkg package.
axiSlaveRegister()/axiSlaveRegisterR() supports mapping of an array of 
32-bit registers, which will require multiple AXI-Lite read (or write) 
transactions to get (or set) the value.

<!--- ########################################################################################### -->

## Running the cocoTB testbed

<!--- ########################################################################################### -->

### Why the `rtl/MyAxiLiteEndpointWrapper.vhd`?

cocoTB's AXI extension package does NOT support record types for the AXI interface between
the firmware and the cocoTB simulation. This is a similar issue with AMD/Xilinx IP Integrator.
Both tool only accept `std_logic` (sl) and `std_logic_vector` (slv) port types. The work 
around for both tools is to use a wrapper that includes a SURF module that translates the 
AXI record types to `std_logic` (sl) and `std_logic_vector` (slv).  For this lab we will 
be using `surf.SlaveAxiLiteIpIntegrator` for translation:

```vhdl
entity MyAxiLiteEndpointWrapper is
   generic (
      EN_ERROR_RESP : boolean  := true;
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

<!--- ########################################################################################### -->

### How to run the cocoTB testing script

Use the Makefile + ruckus + GHDL to collect all the source code via ruckus.tcl for cocoTB:
```bash
make
```

Next, run the cocoTB python script and grep for the CUSTOM logging prints
```bash
pytest -rP tests/test_MyAxiLiteEndpointWrapper.py  | grep CUSTOM
```

<!--- ########################################################################################### -->

### How to view the digital logic waveforms after the simulation

After running the cocoTB simulation, a `.ghw` file with all the traces will be dumped 
into the build output path.  You can use `gtkwave` to display these simulation traces:
```bash
gtkwave build/MyAxiLiteEndpointWrapper/MyAxiLiteEndpointWrapper.ghw
```
<img src="ref_files/gtkwave.png" width="200">

<!--- ########################################################################################### -->

## Explore Time!

At this point, we have added all the custom AXI-Lite registers for the
example cocoTB testbed python provided in the lab.  If you have extra 
time in the lab, please play around with adding/modifying the firmware 
registers and testing them in the cocoTB software simulator. 

<!--- ########################################################################################### -->