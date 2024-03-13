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

First, copy the AXI stream template from the `ref_file`
directory to the `rtl` and rename it on the way.
```bash
cp ref_files/MyAxiStreamModule_start.vhd rtl/MyAxiStreamModule.vhd
```
Please open the `rtl/MyAxiStreamModule.vhd` file in
a text editor (e.g. vim, nano, emacs, etc) at the same time as reading this README.md

<!--- ########################################################################################### -->

