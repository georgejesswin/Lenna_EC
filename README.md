# [cite_start]Lenna: FPGA-Based Real-Time Image Processing System [cite: 3, 4]

[cite_start]A high-performance hardware accelerator designed for real-time image filtering on an FPGA[cite: 13]. [cite_start]By employing a fully pipelined streaming architecture, this system exploits spatial parallelism to achieve minimal latency and high throughput for complex digital signal processing (DSP) tasks[cite: 14, 15].

## Overview
[cite_start]This project captures continuous video frames from an external camera, processes the pixel stream through dedicated hardware modules, and outputs the filtered result to a monitor in real time[cite: 16, 22]. [cite_start]The architecture utilizes a unidirectional streaming pipeline that processes pixels simultaneously across multiple stages, minimizing CPU intervention and maximizing throughput[cite: 23, 25, 26].

## Key Features
* [cite_start]**Real-time Acquisition:** Synchronous, continuous frame capture directly from an OV7670 CMOS camera[cite: 18].
* [cite_start]**Hardware Convolution Engine:** Parallel execution of spatial filters using hardware-based $3\times3$ sliding pixel windows[cite: 19, 20].
* [cite_start]**Robust CDC (Clock Domain Crossing):** Reliable asynchronous frame buffering between the 25 MHz camera clock and the VGA display clock using True Dual-Port BRAM[cite: 21, 163, 168].
* [cite_start]**High Throughput:** Sustains exactly one processed pixel per clock cycle after initial buffering, processing 25 million pixels per second to comfortably exceed the requirements for $640\times480$ resolution at 60 FPS[cite: 44, 45, 46, 47].
* [cite_start]**Flow Control:** Implements AXI-Stream compliant backpressure protocols to prevent pipeline stalls and dropped frames[cite: 144].

## Hardware Requirements
* [cite_start]**FPGA:** Nexys A7-100T [cite: 16]
* [cite_start]**Camera:** OV7670 CMOS sensor [cite: 16]
* [cite_start]**Display:** VGA Monitor [cite: 39]

## Supported Spatial Filters
[cite_start]The system includes a dynamic kernel selector that allows switching between filters without external memory reconfiguration[cite: 76, 77]:
* [cite_start]**Identity:** Passes the unmodified pixel window[cite: 79].
* [cite_start]**Sobel Edge Detection (X & Y):** Approximates the image gradient, computed simultaneously using repurposed RGB datapaths to generate a binarized, high-contrast edge map[cite: 82, 83, 108, 134, 135].
* [cite_start]**Sharpen:** Enhances high-frequency spatial components[cite: 86].
* [cite_start]**Box Blur & Gaussian Blur:** Normalized spatial low-pass filters for smoothing[cite: 89, 92].
* [cite_start]**Image Inversion:** Hardware-level color inversion with zero added pipeline latency[cite: 140, 141].

## Repository Structure
* [cite_start]`top_wrapper.v`: The top-level architecture orchestrating pixel flow, camera interfaces, CDC, and datapath expansion/truncation[cite: 149, 151, 157].
* [cite_start]`image_process.v`: The central processing wrapper that dynamically routes streaming 24-bit RGB data through mathematical stages based on the selected operational mode[cite: 118, 119].
* [cite_start]`image_control_param.v`: The 2D sliding window generator that uses a "ping-pong" circular buffering technique to output a valid $3\times3$ grid every clock cycle without stalls[cite: 56, 59, 60].
* [cite_start]`line_buff_param.v`: The 1D horizontal line buffer serving as the memory primitive for spatial filtering, utilizing zero-padding at image boundaries[cite: 51, 52, 55].
* [cite_start]`conv_gen.v`: The mathematical core executing parallel multiplications and utilizing combinational adder trees to drastically reduce critical path delay[cite: 61, 68, 70, 71].
* [cite_start]`kernel.v`: The combinational routing unit supplying predefined $3\times3$ matrices and normalization factors to the convolution engine[cite: 75, 76].
* `Nexys-A7-100T-Master.xdc`: Master constraints file for the Nexys A7 board.

## Author
**Jesswin George**
[cite_start]Electronics Club, IIT Guwahati [cite: 1, 5]
