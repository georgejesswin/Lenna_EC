# Lenna: FPGA-Based Real-Time Image Processing System

A high-performance hardware accelerator designed for real-time image filtering on an FPGA.  
By employing a fully pipelined streaming architecture, this system exploits spatial parallelism to achieve minimal latency and high throughput for complex digital signal processing (DSP) tasks.

---

## Overview
This project captures continuous video frames from an external camera, processes the pixel stream through dedicated hardware modules, and outputs the filtered result to a monitor in real time.

The architecture utilizes a unidirectional streaming pipeline that processes pixels simultaneously across multiple stages, minimizing CPU intervention and maximizing throughput.

---

## Key Features

- **Real-time Acquisition:**  
  Synchronous, continuous frame capture directly from an OV7670 CMOS camera.

- **Hardware Convolution Engine:**  
  Parallel execution of spatial filters using hardware-based `3×3` sliding pixel windows.

- **Robust CDC (Clock Domain Crossing):**  
  Reliable asynchronous frame buffering between the 25 MHz camera clock and the VGA display clock using True Dual-Port BRAM.

- **High Throughput:**  
  Sustains exactly one processed pixel per clock cycle after initial buffering (~25M pixels/sec), sufficient for `640×480 @ 60 FPS`.

- **Flow Control:**  
  Implements AXI-Stream compliant backpressure protocols to prevent pipeline stalls and dropped frames.

---

## Hardware Requirements

- **FPGA:** Nexys A7-100T  
- **Camera:** OV7670 CMOS sensor  
- **Display:** VGA Monitor  

---

## Supported Spatial Filters

The system includes a dynamic kernel selector that allows switching between filters without external memory reconfiguration:

- **Identity:** Pass-through (no modification)
- **Sobel Edge Detection (X & Y):**  
  Computes image gradients and generates a high-contrast edge map
- **Sharpen:** Enhances high-frequency components
- **Box Blur & Gaussian Blur:** Smooths image using low-pass filtering
- **Image Inversion:** Hardware-level color inversion with zero added latency
- **Grayscale Conversion:** Converts the 24-bit RGB stream into monochrome using a hardware-efficient luminance approximation
---

## Repository Structure

- `top_wrapper.v`  
  Top-level architecture managing pixel flow, camera interface, CDC, and datapath control

- `image_process.v`  
  Core processing module routing 24-bit RGB data through selected operations

- `image_control_param.v`  
  Sliding window generator using ping-pong buffering to output a valid `3×3` grid every clock cycle

- `line_buff_param.v`  
  Horizontal line buffer for spatial filtering with boundary padding

- `conv_gen.v`  
  Convolution engine performing parallel multiplications and optimized adder tree reductions

- `kernel.v`  
  Provides predefined `3×3` kernels and normalization factors

- `rgb_to_gray.v`
  Converts a 24-bit RGB pixel into an 8-bit grayscale pixel using a hardware-efficient luminance approximation weighted for human vision

- `gray2rgb.v`
  Handles bit-depth expansion for video interfaces by duplicating the 8-bit grayscale value across the Red, Green, and Blue channels

- `sobel_edge.v`
  Processes the raw horizontal and vertical gradients to produce a binarized, high-contrast RGB edge map based on a parameterized threshold

- `Nexys-A7-100T-Master.xdc`  
  FPGA constraint file for pin configuration

---

## Author

**Jesswin George**  
Electronics Club, IIT Guwahati
