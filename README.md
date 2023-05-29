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
![Diagram](readm_img/Block_Diagram.png) </br>
The diagram shows the architecture we have developed where we can identify the main blocks:
- ZYNQ processor (*processing_system7_0*);
- Axi DMA (*axi_dma_0*);
- image processing block composed of receive dma (*recive_dma_0*) and sobel filter (*SobelFilter_0*); 
- image visualization block composed of frame generator (*frame_generator_0*) and vga driver (*vga_0*);
- memory blocks (*blk_mem_gen_0, blk_mem_gen_1, blk_mem_gen_2*).

The data flow starts from the **processor** which via embedded code handles the dma and transfers the image via AXI-Stream to the **receive dma** block.  Here the data is converted from the YUY2 webcam format to 4 bits greyscale. Then the image is saved and passed to the next block that implements the **Sobel filter**, the image processing core that through an algorithm manages to highlight the edges of a figure within the image. Finally, the frame generator block is responsible for creating the frame to be sent to the VGA driver after applying a frame that indicates the recognition of a figure, handling synchronization. </br>

Three memory blocks necessary to save partial results after each processing are provided in the architecture so as to simplify synchronization and management of the image shown on the screen. To avoid concurrency problems between the "SobelFilter" block and "FrameGenerator" block, Memory Block 2 is added, allowing access to the original image at any time. <\br>

### Receive Dma block
This block handles the format of the incoming data from the dma. On input we get a 32 bits data which corresponds to two pixels encoded in YUY2. From this bit array the two bytes related to brightness are extracted where only the most significant 4 bits of each byte are actually transferred. To handle the different order of the input bytes due to variations in the image format, a switch has been added to allow the choice between two different configurations. Data is then passed out in groups of two pixels encoded in greyscale 4 bits (one byte). </br>

### Sobel filter
This is the block designated to implement the Sobel filter. Two 3×3 kernels, that is, two convolution matrices, are applied to the original image to compute approximate values of the horizontal and vertical gradients. From the original image, 2 rows are stored in 2 arrays, and a third array is used to store an additional 3 pixels. In this way, by simply shifting the three arrays by one pixel, one always manages to have in the first three array positions the correct pixels on which to apply the kernel.
Again the image is stored in a BRAM for the next step.

### Frame generator block


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
