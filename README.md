# Eyeriss-Inspired-FPGA-Accelerator-for-Satellite-Image-Object-Recognition

An FPGA-based CNN accelerator inspired by the Eyeriss v2 architecture, designed for high-resolution 2D convolution (up to 1024×1024) on satellite imagery. The network architecture is based on the LegNet model, targeting object recognition in remote sensing applications.

Key Features

Architecture: Inspired by Eyeriss v2, optimized for spatial data reuse and efficient PE-array utilization
Network: Based on LegNet, an all-convolutional CNN architecture
Input support: High-resolution 2D convolution with input feature maps up to 1024×1024
Memory interface: AXI-based memory exchange for feature maps and weights
Target FPGA: Xilinx Zynq UltraScale+ ZU15EG

Performance

Clock frequency: 83 MHz (12 ns clock period)
Latency: 0.373 seconds per convolutional layer

Tools & Technologies

Verilog, QuestaSim, Vivado, AXI

