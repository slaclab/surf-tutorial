##############################################################################
## This file is part of 'surf-tutorial'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'surf-tutorial', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# dut_tb
import logging
import random
import cocotb
from cocotb.clock      import Clock
from cocotb.triggers   import RisingEdge
from cocotbext.axi     import AxiLiteBus, AxiLiteMaster, AxiResp
from cocotb.regression import TestFactory

# test_MyAxiLiteEndpointWrapper
from cocotb_test.simulator import run
import pytest
import glob
import os
import sys

# Define a new log level
CUSTOM_LEVEL = 60
logging.addLevelName(CUSTOM_LEVEL, "CUSTOM")

def custom(self, message, *args, **kwargs):
    if self.isEnabledFor(CUSTOM_LEVEL):
        self._log(CUSTOM_LEVEL, message, args, **kwargs)

# Add the custom level to the logging.Logger class
logging.Logger.custom = custom

# Helper function for converting 32-bit values to string
def rdDataToStr(data):
    return hex(int.from_bytes(data, byteorder="little"))

class TB:
    def __init__(self, dut):

        # Pointer to DUT object
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        # Start clock (100 MHz) in a separate thread
        cocotb.start_soon(Clock(dut.S_AXI_ACLK, 10.0, units='ns').start())

        # Create the AXI-Lite Master
        self.axil = AxiLiteMaster(
            bus   = AxiLiteBus.from_prefix(dut, 'S_AXI'),
            clock = dut.S_AXI_ACLK,
            reset = dut.S_AXI_ARESETN,
            reset_active_level=False)

    async def cycle_reset(self):
        self.dut.S_AXI_ARESETN.setimmediatevalue(0)
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 0
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)
        self.dut.S_AXI_ARESETN.value = 1
        await RisingEdge(self.dut.S_AXI_ACLK)
        await RisingEdge(self.dut.S_AXI_ACLK)

    async def add_delay(self,delay):
        for i in range(delay):
            await RisingEdge(self.dut.S_AXI_ACLK)

async def dut_tb(dut):
    # Initialize the DUT
    tb = TB(dut)

    # Reset DUT
    await tb.cycle_reset()

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

if cocotb.SIM_NAME:
    factory = TestFactory(dut_tb)
    factory.generate_tests()

tests_dir = os.path.dirname(__file__)
tests_module = 'MyAxiLiteEndpointWrapper'

@pytest.mark.parametrize(
    "parameters", [
        {'EN_ERROR_RESP': 'true', },  # Enable bus response
    ])
def test_MyAxiLiteEndpointWrapper(parameters):

    # https://github.com/themperek/cocotb-test#arguments-for-simulatorrun
    # https://github.com/themperek/cocotb-test/blob/master/cocotb_test/simulator.py
    run(
        # top level HDL
        toplevel = f'work.{tests_module}'.lower(),

        # name of the file that contains @cocotb.test() -- this file
        # https://docs.cocotb.org/en/stable/building.html?#envvar-MODULE
        module = f'test_{tests_module}',

        # https://docs.cocotb.org/en/stable/building.html?#var-TOPLEVEL_LANG
        toplevel_lang = 'vhdl',

        # VHDL source files to include.
        # Can be specified as a list or as a dict of lists with the library name as key,
        # if the simulator supports named libraries.
        vhdl_sources = {
            'surf'   : glob.glob(f'{tests_dir}/../build/SRC_VHDL/surf/*'),
            'ruckus' : glob.glob(f'{tests_dir}/../build/SRC_VHDL/ruckus/*'),
            'work'   : glob.glob(f'{tests_dir}/../build/SRC_VHDL/work/*'),
        },

        # A dictionary of top-level parameters/generics.
        parameters = parameters,

        # The directory used to compile the tests. (default: sim_build)
        sim_build = f'{tests_dir}/../build/{tests_module}',

        # A dictionary of extra environment variables set in simulator process.
        extra_env=parameters,

        # Select a simulator
        simulator="ghdl",

        # use of synopsys package "std_logic_arith" needs the -fsynopsys option
        # -frelaxed-rules option to allow IP integrator attributes
        # -Welaboration option to allow function called before elaborated of its body
        vhdl_compile_args = ['-fsynopsys','-frelaxed-rules'],

        ########################################################################
        # Dump waveform to file ($ gtkwave sim_build/path/To/{tests_module}.ghw)
        ########################################################################
        sim_args =[f'--wave={tests_module}.ghw'],
    )
