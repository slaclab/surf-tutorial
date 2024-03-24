##############################################################################
## This file is part of 'surf-tutorial'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'surf-tutorial', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.axi import AxiLiteBus, AxiLiteMaster

# test_MyAxiLiteCrossbarWrapper
from cocotb_test.simulator import run
import pytest
import glob
import os
import itertools
import logging
import random

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
        self.axil_master = AxiLiteMaster(
            bus   = AxiLiteBus.from_prefix(dut, 'S_AXI'),
            clock = dut.S_AXI_ACLK,
            reset = dut.S_AXI_ARESETN,
            reset_active_level=False)

    def set_idle_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.aw_channel.set_pause_generator(generator())
            self.axil_master.write_if.w_channel.set_pause_generator(generator())
            self.axil_master.read_if.ar_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.axil_master.write_if.b_channel.set_pause_generator(generator())
            self.axil_master.read_if.r_channel.set_pause_generator(generator())

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

async def run_test_bytes(dut, data_in=None, idle_inserter=None, backpressure_inserter=None):

    dut.log.custom( f'run_test_bytes(): idle_inserter={idle_inserter}, backpressure_inserter={backpressure_inserter}' )

    tb = TB(dut)

    byte_lanes = tb.axil_master.write_if.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes*2):
        for memDev in [0x0000_0000,0x0010_2000,0x0016_0000]:
            for offset in range(byte_lanes):
                addr = offset+memDev
                tb.log.info( f'length={length},addr={hex(addr)}' )
                test_data = bytearray([x % 256 for x in range(length)])
                await tb.axil_master.write(addr, test_data)
                data = await tb.axil_master.read(addr, length)
                assert data.data == test_data

    await RisingEdge(dut.S_AXI_ACLK)
    await RisingEdge(dut.S_AXI_ACLK)
    dut.log.custom( f'.... passed test' )

async def run_test_words(dut):

    dut.log.custom( f'run_test_words()' )

    tb = TB(dut)

    byte_lanes = tb.axil_master.write_if.byte_lanes

    await tb.cycle_reset()

    for length in list(range(1, 4)):
        for memDev in [0x0000_0000,0x0010_2000,0x0016_0000]:
            for offset in list(range(byte_lanes)):
                addr = offset
                tb.log.info( f'length={length},addr={hex(addr)}' )

                test_data = bytearray([x % 256 for x in range(length)])
                event = tb.axil_master.init_write(addr, test_data)
                await event.wait()
                event = tb.axil_master.init_read(addr, length)
                await event.wait()
                assert event.data.data == test_data

                test_data = bytearray([x % 256 for x in range(length)])
                await tb.axil_master.write(addr, test_data)
                assert (await tb.axil_master.read(addr, length)).data == test_data

                test_data = [x * 0x1001 for x in range(length)]
                await tb.axil_master.write_words(addr, test_data)
                assert await tb.axil_master.read_words(addr, length) == test_data

                test_data = [x * 0x10200201 for x in range(length)]
                await tb.axil_master.write_dwords(addr, test_data)
                assert await tb.axil_master.read_dwords(addr, length) == test_data

                test_data = [x * 0x1020304004030201 for x in range(length)]
                await tb.axil_master.write_qwords(addr, test_data)
                assert await tb.axil_master.read_qwords(addr, length) == test_data

                test_data = 0x01*length
                await tb.axil_master.write_byte(addr, test_data)
                assert await tb.axil_master.read_byte(addr) == test_data

                test_data = 0x1001*length
                await tb.axil_master.write_word(addr, test_data)
                assert await tb.axil_master.read_word(addr) == test_data

                test_data = 0x10200201*length
                await tb.axil_master.write_dword(addr, test_data)
                assert await tb.axil_master.read_dword(addr) == test_data

                test_data = 0x1020304004030201*length
                await tb.axil_master.write_qword(addr, test_data)
                assert await tb.axil_master.read_qword(addr) == test_data

    await RisingEdge(dut.S_AXI_ACLK)
    await RisingEdge(dut.S_AXI_ACLK)
    dut.log.custom( f'.... passed test' )

async def run_stress_test(dut, idle_inserter=None, backpressure_inserter=None):

    dut.log.custom( f'run_stress_test(): idle_inserter={idle_inserter}, backpressure_inserter={backpressure_inserter}' )

    tb = TB(dut)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    async def worker(master, offset, aperture, count=16):
        for k in range(count):
            length = random.randint(1, min(32, aperture))
            addr = offset+random.randint(0, aperture-length)
            test_data = bytearray([x % 256 for x in range(length)])

            await Timer(random.randint(1, 100), 'ns')

            await master.write(addr, test_data)

            await Timer(random.randint(1, 100), 'ns')

            data = await master.read(addr, length)
            assert data.data == test_data

    workers = []

    for k in [0x0000_0000,0x0010_2000,0x0016_0000]:
        workers.append(cocotb.start_soon(worker(tb.axil_master, k, 0x1000, count=16)))

    while workers:
        await workers.pop(0).join()

    await RisingEdge(dut.S_AXI_ACLK)
    await RisingEdge(dut.S_AXI_ACLK)
    dut.log.custom( f'.... passed test' )

def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if cocotb.SIM_NAME:

    #################
    # run_test_bytes
    #################
    factory = TestFactory(run_test_bytes)
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()

    #################
    # run_test_words
    #################
    factory = TestFactory(run_test_words)
    factory.generate_tests()

    #################
    # run_stress_test
    #################
    factory = TestFactory(run_stress_test)
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()

tests_dir = os.path.dirname(__file__)
tests_module = 'MyAxiLiteCrossbarWrapper'

##############################################################################

@pytest.mark.parametrize(
    "parameters", [
        None
    ])
def test_MyAxiLiteCrossbarWrapper(parameters):

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
        # When two operators are overloaded, give preference to the explicit declaration (-fexplicit)
        vhdl_compile_args = ['-fsynopsys','-frelaxed-rules', '-fexplicit'],

        ########################################################################
        # Dump waveform to file ($ gtkwave build/MyAxiLiteCrossbarWrapper/MyAxiLiteCrossbarWrapper.ghw)
        ########################################################################
        sim_args =[f'--wave={tests_module}.ghw'],
    )
