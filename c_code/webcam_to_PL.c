 /*
 *  V4L2 video capture example
 *
 *  This program can be used and distributed without restrictions.
 *
 *      This program is provided with the V4L2 API
 * see https://linuxtv.org/docs.php for more information
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include <getopt.h>             /* getopt_long() */

#include <fcntl.h>              /* low-level i/o */
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/mman.h>
#include <sys/ioctl.h>

#include <linux/videodev2.h>


#define CLEAR(x) memset(&(x), 0, sizeof(x))

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <termios.h>
#include <sys/mman.h>
#include <stdint.h>

#define MM2S_CONTROL_REGISTER       0x00
#define MM2S_STATUS_REGISTER        0x04
#define MM2S_SRC_ADDRESS_REGISTER   0x18
#define MM2S_TRNSFR_LENGTH_REGISTER 0x28

#define S2MM_CONTROL_REGISTER       0x30
#define S2MM_STATUS_REGISTER        0x34
#define S2MM_DST_ADDRESS_REGISTER   0x48
#define S2MM_BUFF_LENGTH_REGISTER   0x58

#define IOC_IRQ_FLAG                1<<12
#define IDLE_FLAG                   1<<1

#define STATUS_HALTED               0x00000001
#define STATUS_IDLE                 0x00000002
#define STATUS_SG_INCLDED           0x00000008
#define STATUS_DMA_INTERNAL_ERR     0x00000010
#define STATUS_DMA_SLAVE_ERR        0x00000020
#define STATUS_DMA_DECODE_ERR       0x00000040
#define STATUS_SG_INTERNAL_ERR      0x00000100
#define STATUS_SG_SLAVE_ERR         0x00000200
#define STATUS_SG_DECODE_ERR        0x00000400
#define STATUS_IOC_IRQ              0x00001000
#define STATUS_DELAY_IRQ            0x00002000
#define STATUS_ERR_IRQ              0x00004000

#define HALT_DMA                    0x00000000
#define RUN_DMA                     0x00000001
#define RESET_DMA                   0x00000004
#define ENABLE_IOC_IRQ              0x00001000
#define ENABLE_DELAY_IRQ            0x00002000
#define ENABLE_ERR_IRQ              0x00004000
#define ENABLE_ALL_IRQ              0x00007000

#define imageSize 640*480
#define transfer_lenght 15360
#define DMA_SRC_ADDRESS 0x0e000000 // check on vivado address editor


struct buffer {
        volatile void   *start;
        size_t  length;
};

volatile unsigned int *virtual_src_addr = NULL;
unsigned int *dma_virtual_addr;

static char            *dev_name;
static int              fd = -1;
struct buffer          *buffers; //puntatore a variabile tipo buffer
static unsigned int     n_buffers;
static int              frame_count = -1;


unsigned int write_dma(volatile unsigned int *virtual_addr, int offset, unsigned int value)
{
    virtual_addr[offset>>2] = value;

    return 0;
}

unsigned int read_dma(volatile unsigned int *virtual_addr, int offset)
{
    return virtual_addr[offset>>2];
}

int dma_mm2s_sync(volatile unsigned int *virtual_addr)
{
    unsigned int mm2s_status =  read_dma(virtual_addr, MM2S_STATUS_REGISTER);

	// sit in this while loop as long as the status does not read back 0x00001002 (4098)
	// 0x00001002 = IOC interrupt has occured and DMA is idle
	while(!(mm2s_status & IOC_IRQ_FLAG) || !(mm2s_status & IDLE_FLAG))
	{
        mm2s_status =  read_dma(virtual_addr, MM2S_STATUS_REGISTER);
    }

	return 0;
}


void initdma(){
        printf("Running DMA transfer.\n");

//	Opening a character device file of the Zynq's DDR memory with aligned page
        int ddr_memory = open("/dev/mem", O_RDWR | O_SYNC);
        unsigned pagesize = sysconf(_SC_PAGESIZE);

//  Memory map the address of the DMA AXI IP via its AXI lite control interface register block
        dma_virtual_addr = mmap(NULL, pagesize, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, 0x40400000);

//  Memory map the MM2S source address register block
        virtual_src_addr  = mmap(NULL, imageSize*2, PROT_READ | PROT_WRITE, MAP_SHARED, ddr_memory, 0x0e000000);

//  Reset the DMA
        write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, RESET_DMA);

//  Halt the DMA
        write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, HALT_DMA);

//  Enable all interrupts
        write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, ENABLE_ALL_IRQ);
}

void transfer_dma(volatile unsigned int *dma_virtual_addr, unsigned int phisical_address, unsigned int size){
// divide image in N blocks to stream less than maximum bytes number
	int i = 0;
	int N = (int)(size/transfer_lenght);

	for(i=0; i<N; i++){
//	Halt the DMA
		write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, HALT_DMA);

//	Writing source address of the data from MM2S in DDR
		write_dma(dma_virtual_addr, MM2S_SRC_ADDRESS_REGISTER, (phisical_address+(i*transfer_lenght)));

//	Run the MM2S channel
		write_dma(dma_virtual_addr, MM2S_CONTROL_REGISTER, RUN_DMA);

//	Writing MM2S transfer length of transfer_lenght  bytes
		write_dma(dma_virtual_addr, MM2S_TRNSFR_LENGTH_REGISTER, transfer_lenght);

//	Waiting for MM2S synchronization
		dma_mm2s_sync(dma_virtual_addr);

	}
}

static void errno_exit(const char *s) // gestisce gli errori
{
        fprintf(stderr, "%s error %d, %s\\n", s, errno, strerror(errno));
        exit(EXIT_FAILURE);
}

static int xioctl(int fh, int request, void *arg) // serve per tutte le richieste al driver
{
        int r;

        do {
                r = ioctl(fh, request, arg);
        } while (-1 == r && EINTR == errno);

        return r;
}

static void process_image(volatile const void *p, int size){

		int i = 0;
		int j = size/4;

        for (i = 0; i < j; i++){
                virtual_src_addr[i] = *(((volatile unsigned int *)p)+i);
        }

        transfer_dma(dma_virtual_addr, DMA_SRC_ADDRESS, size);

}

static int read_frame(void)
{
        struct v4l2_buffer buf;
        unsigned int i;
        CLEAR(buf);

        buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        buf.memory = V4L2_MEMORY_MMAP;

        if (-1 == xioctl(fd, VIDIOC_DQBUF, &buf)) { //legge i valori e li mette nel buffer, inoltre cambia lo stato del buffer in non utilizzabile per prossime letture
                                                        //NB basta passare un buf generico perchÃ¨ si arrangia lui a gestire gli indirizza a cui deve andare poichÃ¨ si Ã¨ presente uno stream
                switch (errno) {
                case EAGAIN:
                        return 0;

                case EIO:
                        /* Could ignore EIO, see spec. */

                        /* fall through */

                default:
                        errno_exit("VIDIOC_DQBUF");
                }
        }

        assert(buf.index < n_buffers); // verifica che siano stati utilizzati i buffer che abbiamo inizializzato precedentemente

        process_image(buffers[buf.index].start, buf.bytesused); // processa le immagini

        if (-1 == xioctl(fd, VIDIOC_QBUF, &buf)) // cambia lo stato del buffer in modo che si possa utilizzare di nuovo
                errno_exit("VIDIOC_QBUF");

        return 1;
}

static void mainloop(void)
{
    int count;

    count = frame_count; // impostato da -c number nel momento in cui si lancia il programma

    while (count-- > 0 || frame_count == -1) {
        for (;;) {
            fd_set fds;
            struct timeval tv;
            int r;

            FD_ZERO(&fds);
            FD_SET(fd, &fds);

            /* Timeout. */
            tv.tv_sec = 2;
            tv.tv_usec = 0;

            r = select(fd + 1, &fds, NULL, NULL, &tv);

            if (-1 == r) {
                if (EINTR == errno)
                    continue;
                errno_exit("select");
            }

            if (0 == r) {
                fprintf(stderr, "select timeout\\n");
                exit(EXIT_FAILURE);
            }

            if (read_frame())
                break;
            /* EAGAIN - continue select loop. */
        }
    }
}

static void stop_capturing(void){
        enum v4l2_buf_type type;

        type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        if (-1 == xioctl(fd, VIDIOC_STREAMOFF, &type))
                errno_exit("VIDIOC_STREAMOFF");
}

static void start_capturing(void)
{
        unsigned int i;
        enum v4l2_buf_type type;

        for (i = 0; i < n_buffers; ++i) { // inizializza un tmp buffer in modo da poterlo poi passare a xioctl
                struct v4l2_buffer buf;

                CLEAR(buf);
                buf.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
                buf.memory = V4L2_MEMORY_MMAP;
                buf.index = i;

                if (-1 == xioctl(fd, VIDIOC_QBUF, &buf)) // dice tramite xioctl di usare i buffer come buffer per il file fd ("stream che controlla il la webcam")
                        errno_exit("VIDIOC_QBUF");
        }
        type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        if (-1 == xioctl(fd, VIDIOC_STREAMON, &type)) //inizializza lo straem e verifica che si sia aperto correttamente
                errno_exit("VIDIOC_STREAMON");

}

static void uninit_device(void)
{
        unsigned int i;

        for (i = 0; i < n_buffers; ++i)
                if (-1 == munmap(buffers[i].start, buffers[i].length))
                        errno_exit("munmap");

        free(buffers);
}

static void init_mmap(void) // inizializza la mappatura dei buffer sulla memoria virtuale
{       // inizialmente usa il prototipo req che poi passa a xioctl per capire se le richieste sono fattibili
        struct v4l2_requestbuffers req;

        CLEAR(req);

        req.count = 4; // number of buffers
        req.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        req.memory = V4L2_MEMORY_MMAP;
        if (-1 == xioctl(fd, VIDIOC_REQBUFS, &req)) {
                if (EINVAL == errno) {
                        fprintf(stderr, "%s does not support "
                                 "memory mappingn", dev_name);
                        exit(EXIT_FAILURE);
                } else {
                        errno_exit("VIDIOC_REQBUFS");
                }
        }

        if (req.count < 2) {
                fprintf(stderr, "Insufficient buffer memory on %s\\n",
                         dev_name);
                exit(EXIT_FAILURE);
        }

        buffers = calloc(req.count, sizeof(*buffers));

        if (!buffers) {
                fprintf(stderr, "Out of memory\\n");
                exit(EXIT_FAILURE);
        }

        for (n_buffers = 0; n_buffers < req.count; ++n_buffers) {
                struct v4l2_buffer buf;

                CLEAR(buf);

                buf.type        = V4L2_BUF_TYPE_VIDEO_CAPTURE;
                buf.memory      = V4L2_MEMORY_MMAP;
                buf.index       = n_buffers;

                if (-1 == xioctl(fd, VIDIOC_QUERYBUF, &buf))
                        errno_exit("VIDIOC_QUERYBUF");

                buffers[n_buffers].length = buf.length;
                buffers[n_buffers].start =
                        mmap(NULL /* start anywhere */,
                              buf.length,
                              PROT_READ | PROT_WRITE /* required */,
                              MAP_SHARED /* recommended */,
                              fd, buf.m.offset);

                if (MAP_FAILED == buffers[n_buffers].start)
                        errno_exit("mmap");
        }
}

static void init_device(void)
{
        struct v4l2_capability cap;
        struct v4l2_cropcap cropcap;
        struct v4l2_crop crop;
        struct v4l2_format fmt;
        unsigned int min;

        if (-1 == xioctl(fd, VIDIOC_QUERYCAP, &cap)) {
                if (EINVAL == errno) {
                        fprintf(stderr, "%s is no V4L2 device\\n",
                                 dev_name);
                        exit(EXIT_FAILURE);
                } else {
                        errno_exit("VIDIOC_QUERYCAP");
                }
        }

        if (!(cap.capabilities & V4L2_CAP_VIDEO_CAPTURE)) {
                fprintf(stderr, "%s is no video capture device\\n",
                         dev_name);
                exit(EXIT_FAILURE);
        }

        if (!(cap.capabilities & V4L2_CAP_STREAMING)) {
                fprintf(stderr, "%s does not support streaming i/o\\n",
                            dev_name);
                exit(EXIT_FAILURE);
        }



        /* Select video input, video standard and tune here. */


        CLEAR(cropcap);

        cropcap.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;

        if (0 == xioctl(fd, VIDIOC_CROPCAP, &cropcap)) {
                crop.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
                crop.c = cropcap.defrect; /* reset to default */

                if (-1 == xioctl(fd, VIDIOC_S_CROP, &crop)) {
                        switch (errno) {
                        case EINVAL:
                                /* Cropping not supported. */
                                break;
                        default:
                                /* Errors ignored. */
                                break;
                        }
                }
        } else {
                /* Errors ignored. */
        }


        CLEAR(fmt);

        fmt.type = V4L2_BUF_TYPE_VIDEO_CAPTURE;
        fmt.fmt.pix.width       = 640;
        fmt.fmt.pix.height      = 480;
        fmt.fmt.pix.pixelformat = V4L2_PIX_FMT_YUYV;
        fmt.fmt.pix.field       = V4L2_FIELD_INTERLACED;

        if (-1 == xioctl(fd, VIDIOC_S_FMT, &fmt))
                errno_exit("VIDIOC_S_FMT");


        /* Buggy driver paranoia. */
        min = fmt.fmt.pix.width * 2;
        if (fmt.fmt.pix.bytesperline < min)
                fmt.fmt.pix.bytesperline = min;
        min = fmt.fmt.pix.bytesperline * fmt.fmt.pix.height;
        if (fmt.fmt.pix.sizeimage < min)
                fmt.fmt.pix.sizeimage = min;


        init_mmap();

}

static void close_device(void)
{
        if (-1 == close(fd))
                errno_exit("close");

        fd = -1;
}

static void open_device(void) // controlla che esista un device e apre uno stream trimite "file"
{
        struct stat st;

        if (-1 == stat(dev_name, &st)) {
                fprintf(stderr, "Cannot identify '%s': %d, %s\\n",
                         dev_name, errno, strerror(errno));
                exit(EXIT_FAILURE);
        }

        if (!S_ISCHR(st.st_mode)) {
                fprintf(stderr, "%s is no device \\n", dev_name);
                exit(EXIT_FAILURE);
        }

        fd = open(dev_name, O_RDWR /* required */ | O_NONBLOCK, 0);

        if (-1 == fd) {
                fprintf(stderr, "Cannot open '%s': %d, %s\\n",
                         dev_name, errno, strerror(errno));
                exit(EXIT_FAILURE);
        }
}

static void usage(FILE *fp, int argc, char **argv) // help e impostazioni iniziali
{
        fprintf(fp,
                 "Usage: %s [options]\\n\\n"
                 "Version 1.3\\n"
                 "Options:\\n"
                 "-d | --device name   Video device name [%s]n"
                 "-h | --help          Print this messagen"
                 "-c | --count         Number of frames to grab [%i]n"
                 "",
                 argv[0], dev_name, frame_count);
}

static const char short_options[] = "d:hc:";

static const struct option
long_options[] = {
        { "device", required_argument, NULL, 'd' },
        { "help",   no_argument,       NULL, 'h' },
        { "count",  required_argument, NULL, 'c' },
        { 0, 0, 0, 0 }
};

int main(int argc, char **argv)
{
        dev_name = "/dev/video0"; // percorso del device di default

        for (;;) {
                int idx;
                int c;
                 // funzione che va a leggere tutte le impostazioni di lettura
                c = getopt_long(argc, argv,
                                short_options, long_options, &idx);

                if (-1 == c)
                        break;

                switch (c) { // inizilizzazione di tutte le variabili e costanti in modo da modificare il programma in base al lancio del programma
                case 0: /* getopt_long() flag */
                        break;

                case 'd':
                        dev_name = optarg;
                        break;

                case 'h': // comando di help
                        usage(stdout, argc, argv);
                        exit(EXIT_SUCCESS);

                case 'c':
                        errno = 0;
                        frame_count = strtol(optarg, NULL, 0);
                        if (errno)
                                errno_exit(optarg);
                        break;

                default:
                        usage(stderr, argc, argv);
                        exit(EXIT_FAILURE);
                }
        }
        open_device();
        initdma();
        init_device();
        start_capturing();
        mainloop();
        stop_capturing();
        uninit_device();
        close_device();
        return 0;
}
