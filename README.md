# Lenna: FPGA-Based Real-Time Image Processing System

A high-performance image processing system implemented on an FPGA. 

---

## Overview
This project captures continuous video frames from an external camera, processes the pixel stream through dedicated hardware modules, and outputs the filtered result to a monitor in real time.

---

## Key Features

- **Real-time Acquisition:** Synchronous, continuous frame capture directly from an OV7670 CMOS camera.

- **Hardware Convolution Engine:** Parallel execution of spatial filters using hardware-based `3×3` sliding pixel windows.

- **Advanced Color Grading & Effects:**
  Dedicated combinatorial logic pipelines for instantaneous color manipulation, including thermal mapping, sepia toning, channel masking, and brightness control without relying on DSP slices.

- **Robust CDC (Clock Domain Crossing):** Reliable asynchronous frame buffering between the 25 MHz camera clock and the VGA display clock using Dual-Port BRAM.

- **High Throughput:** Sustains exactly one processed pixel per clock cycle (~25M pixels/sec) after initial buffering, sufficient for `640×480 @ 60 FPS`.



---

## Hardware Requirements

- **FPGA:** Nexys A7-100T  
- **Camera:** OV7670 CMOS sensor  
- **Display:** VGA Monitor  

---

## Supported Real-Time Filters & Effects

The system includes a dynamic kernel selector and bypass logic that allows switching between filters and effects without external memory reconfiguration:

**Spatial Filters (3x3 Convolution):**
- **Identity:** Pass-through (no modification)
- **Sobel Edge Detection (X & Y):** Computes image gradients and generates a binarized, high-contrast edge map based on a parameterized threshold.
- **Sharpen:** Enhances high-frequency components.
- **Box Blur & Gaussian Blur:** Smooths image using low-pass filtering.

**Color Processing & Effects (Zero Added Latency):**
- **Image Inversion (Negative):** Hardware-level color inversion.
- **Grayscale Conversion:** Converts the 24-bit RGB stream into monochrome using a hardware-efficient luminance approximation weighted for human vision.
- **Thermal / Heatmap Vision:** Translates luminance into a localized pseudo-color map (Blue -> Green -> Red) for thermal-style imaging.
- **Sepia Tone:** Implements a shift-and-add hardware algorithm to achieve a classic sepia tint without using multiplier blocks.
- **Channel Masking:** Independent toggles to disable the Red, Green, or Blue channels.
- **Brightness Control:** Hardware-level brightness increase and decrease (+/- 32 intensity steps) with built-in overflow and underflow protection.

---

## Repository Structure

- `top_wrapper.v`  
  Top-level architecture managing pixel flow, camera interface, CDC, and datapath control.

- `image_process_wrapper.v`  
  Core processing wrapper routing 24-bit RGB data through selected spatial filters and combinatorial color effects (Sepia, Thermal, Brightness, Masking), feeding an AXI-Stream output FIFO.

- `image_control_param.v`  
  Sliding window generator using ping-pong buffering to output a valid `3×3` grid every clock cycle.

- `line_buff_param.v`  
  Horizontal line buffer for spatial filtering with boundary padding.

- `conv_gen.v` / `conv3x3.v`  
  Convolution engine performing parallel multiplications and optimized adder tree reductions.

- `kernel_selector.v`  
  Provides predefined `3×3` kernels and normalization factors.

- `rgb2gray.v`
  Converts a 24-bit RGB pixel into an 8-bit grayscale pixel using a hardware-efficient luminance approximation.

- `gray2rgb.v`
  Handles bit-depth expansion for video interfaces by duplicating the 8-bit grayscale value across the Red, Green, and Blue channels.

- `sobel_edge_stream_rgb.v`
  Processes the raw horizontal and vertical gradients to produce a binarized RGB edge map.

- `Nexys-A7-100T-Master.xdc`  
  FPGA constraint file for pin configuration.

---

**Jesswin George** Electronics Club, IIT Guwahati
