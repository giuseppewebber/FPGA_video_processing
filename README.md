# FPGA_video_processing
Xilinx Zedboard-based system for video acquisition from a USB webcam using Petalinux. PL implementation of video processing with Sobel filter and VGA video output.

## Vivado architecture

## Building petalinux image

## C code for video acquisition with v4l2 and dma transfer

## Setup Vitis for running and debugging code on petalinux

## Setup the hardware

## Setup petalinux on Zedboard and start the program


<a name="index"></a>
# <strong> Table of Contents </strong>
1. <a href="#requirementslist">Requirements</a></br>
&nbsp;&nbsp;&nbsp;&nbsp; 1.1 <a href="#hwrequirements">Hardware Requirements</a></br>
-> fpga xilinx zedboard </br>
-> cavi usb e adattatore usb "A - micro" </br>
-> webcam </br>
-> cavo ethernet e switch ethernet per debug </br>
-> scheda sd </br>
-> schermo con cavo vga </br>
&nbsp;&nbsp;&nbsp;&nbsp; 1.2 <a href="#swrequirements">Software Requirements</a></br>
-> vivado 2021.2 </br>
-> vitis 2021.2 </br>
-> petalinux tools 2021.2 </br>
-> ubuntu 16.04 </br>
2. <a href="#layoutlist">Project Layout</a></br>
 image alto livello funzionalità + spiegazione a blocchi </br>
4. <a href="#startlist">Getting Started - Setup </a></br>
-> spiegazione come da i nostri file far funzionare il progetto </br>
6. <a href="#codelist">Project steps</a></br>
&nbsp;&nbsp;&nbsp;&nbsp; 4.1 <a href="#ccsfsm">PL</a></br>
4.1.1 spiegazione generale </br>
4.1.2 spiegazione receive dma </br>
4.1.3 spiegazione sobel filter </br>
4.1.4 spiegazione frame generator (somme parziali) </br>
&nbsp;&nbsp;&nbsp;&nbsp; 4.2 <a href="#pythonadd">PS</a></br>
-> spiegazione capture.c + dmatest.c </br>
5. <a href="#externalslist">Video</a></br>
6. <a href="#teamlist">Team Members</a></br>
7. <a href="#referencelist">References</a></br>
8. 

