# <strong> FPGA Video Processing </strong>
Xilinx Zedboard-based system for video acquisition from a USB webcam using Petalinux. PL implementation of video processing with Sobel filter and VGA video output.

<a name="index"></a>
# <strong> Table of Contents </strong>
1. <a href="#requirementslist">Requirements</a></br>
&nbsp;&nbsp;&nbsp;&nbsp; 1.1 <a href="#hwrequirements">Hardware Requirements</a></br>
&nbsp;&nbsp;&nbsp;&nbsp; 1.2 <a href="#swrequirements">Software Requirements</a></br>

2. <a href="#layoutlist">Project Layout</a></br>
 
3. <a href="#startlist">Getting Started</a></br>

4. <a href="#projectsteps">Project steps</a></br>
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

<a name="requirementslist"></a>
# Requirements
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
- [Vivado 2021.2](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/archive.html);
- Vitis 2021.2;
- [PetaLinux tools 2021.2](https://www.xilinx.com/products/design-tools/embedded-software/petalinux-sdk.html);
- Ubuntu 16.04;

<a name="layoutlist"></a>
# Project Layout
The system is composed of three main parts: webcam, Zedboard and monitor. This parts are connected all together to perform video capturing, filtering and show the results on a monitor via VGA. A switch, the first of the FPGA board, is used to choose which image to display, between the original greyscale image and the filtered image. </br>

![Diagram](readm_img/HighLevelDescription.png) </br>

The project layout is pretty straightforward: Webcam data is captured by the processor through the v4l2 kernel running on PetaLinux. Data saved in memory is then transferred to Programmable Logic (PL) through the use of DMA on an AXI-Stream bus. Finally, the FPGA architecture processes the image, managing the format and applying a Sobel filter to then drive the VGA to display the video. </br>

<a name="startlist"></a>
# Getting Started
The following steps are needed to make the system work:
- with a tool like gparted, divide the SD card in three different partitions: a 4MB free space at the beginning, a 500MB FAT32 partition as BOOT and the remaining part in ext4 as rootfs;
- from the petalinux_files/ directory, copy the BOOT.BIN, boot.scr and image.ub files in the BOOT partition and from this [link](https://drive.google.com/drive/folders/1RzFJCgQ1HQrXdmVkEm8N4Z-CmbkjK4yV?usp=sharing) unzip the rootfs.tar.gz in the rootfs partition;
- insert the SD card in the Zedboard, and connect it wih a computer via the COM connection;
- connect the Webcam and the monitor to the Zedboard;
- in the PetaLinux terminal run the commands <code>sh load_hw.sh</code> and <code>sh start.sh</code> and the system should start;
- you might have to use the last switch on the Zedboard to set the right video visualization, depending on the video encoding of our Webcam.

AGGIUNGERE IMMAGINE COLLEGAMENTI SCHEDA

<a name="projectsteps"></a>
# Project steps
The following part explains our steps to develop the system from scratch.
## Vivado Hardware Design


## Petalinux build
The following steps must be carried out on a Linux (we used Ubuntu 16.04) computer. 
- Install PetaLinux Tools;
- inside the project directory run <code>petalinux-create --type project --template zynq --name \<PROJECT NAME\></code> to create the PetaLinux project;
- run <code>petalinux-config --get-hw-description \<PATH TO XSA FILE\></code> with the path to the .xsa file generated by Vivado;
- GUARDARE PETALINUX CONFIG 
 
- generate the PetaLinux image with <code>petalinux-build -c device-tree</code> and <code>petalinux-build</code>;
- use <code>petalinux-package --boot --format BIN --fsbl images/linux/zynq_fsbl.elf --fpga images/linux/BOOT.bit --u-boot</code> to generate the BOOT.BIN file.
 
 for more detailed instructions follow LINK A GUIDA

<a name="externalslist"></a>
# Video

<a name="teamlist"></a>
## Team Members
 Giovanni Solfa
 Giuseppe Webber

<a name="referencelist"></a>
# References
Shraddha Y. Swami ,Jayashree S. Awati , (2017 ) " Implementation of Edge Detection Filter using FPGA " , International Journal of Electrical, Electronics and Data Communication (IJEEDC) , pp. 83-87, Volume-5,Issue-6
