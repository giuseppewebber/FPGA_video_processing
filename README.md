# <strong> FPGA Video Processing </strong>
Xilinx Zedboard-based system for video acquisition from a USB webcam using Petalinux. PL implementation of video processing with Sobel filter and VGA video output.

<a name="index"></a>
# <strong> Table of Contents </strong>
1. <a href="#requirementslist">Requirements</a></br>
&nbsp;&nbsp;&nbsp;&nbsp; 1.1 <a href="#hwrequirements">Hardware Requirements</a></br>
&nbsp;&nbsp;&nbsp;&nbsp; 1.2 <a href="#swrequirements">Software Requirements</a></br>

2. <a href="#layoutlist">Project Layout</a></br>
 image alto livello funzionalità + spiegazione a blocchi </br>
4. <a href="#startlist">Getting Started - Setup </a></br>
- spiegazione come da i nostri file far funzionare il progetto </br>
6. <a href="#codelist">Project steps</a></br>
&nbsp;&nbsp;&nbsp;&nbsp; 4.1 <a href="#ccsfsm">Petalinux</a></br>
 da pensare </br>
&nbsp;&nbsp;&nbsp;&nbsp; 4.1 <a href="#ccsfsm">PL</a></br>
4.1.1 spiegazione generale </br>
4.1.2 spiegazione receive dma </br>
4.1.3 spiegazione sobel filter </br>
4.1.4 spiegazione frame generator (somme parziali) </br>
&nbsp;&nbsp;&nbsp;&nbsp; 4.2 <a href="#pythonadd">PS</a></br>
- spiegazione capture.c + dmatest.c </br>
- debug </br>
5. <a href="#externalslist">Video</a></br>
6. <a href="#teamlist">Team Members</a></br>
7. <a href="#referencelist">References</a></br>
8. 

<a name="hwrequirements"></a>
## Hardware Requirements

- [FPGA Xilinx Zedboard](https://www.xilinx.com/products/boards-and-kits/1-8dyf-11.html);
- USB Webcam;
- SD card (8 GB minimum);
- Monitor with VGA port and VGA cable;
- USB cable and USB A to micro adapter;
- Ethernet cable;

<a name="swrequirements"></a>
## Software Requirements
- Vivado 2021.2;
- Vitis 2021.2;
- PetaLinux tools 2021.2;
- Ubuntu 16.04;

