#include <stdio.h>
#include <stdlib.h>
#include <memory.h>
#include <fcntl.h>
//#include <io.h>
#include <math.h>
#include <algorithm>

typedef unsigned char uint8;

// The input frame is 128x384.
// The luma plane is downsampled to 64x192.
// The chroma plane is already 64x192.

const int HEIGHT = 192;

unsigned char frame[HEIGHT*(160+80)];
unsigned char aframe[HEIGHT*40*2];
unsigned char rframe[HEIGHT*40*2];

bool readdata(void *dst, size_t len) {
	while(len) {
		int actual = fread(dst, 1, len, stdin);

		fprintf(stderr, "read %d bytes\n", actual);

		if (actual <= 0)
			return false;

		len -= actual;
		dst = (char *)dst + actual;
	}

	return true;
}

float itab[16];
float qtab[16];

int main(int argc, const char **argv) {
	setvbuf(stdin, NULL, _IONBF, 0);
	//_setmode(_fileno(stdin), _O_BINARY);

	if (argc < 2) {
		fprintf(stderr, "Output filename required.\n");
		return 5;
	}

	FILE *fo = fopen(argv[1], "wb");
	if (!fo) {
		fprintf(stderr, "Unable to open for write: %s\n", argv[1]);
		return 10;
	}

	for(int i=0; i<15; ++i) {
		itab[i+1] = 40.0f * cosf(3.1415926535f * ((float)i + 0.5f) / 7.0f);
		qtab[i+1] = 40.0f * sinf(3.1415926535f * ((float)i + 0.5f) / 7.0f);
	}

	int frn = 0;

	const float rot = 0.5f;

	const float sc = cosf(rot);
	const float ss = sinf(rot);

	static float errfq[HEIGHT][80];
	static float errfi[HEIGHT][80];
	static float errfy[HEIGHT][80];

	for(;;) {
		if (!readdata(frame, HEIGHT*(160+80)))
			break;

		unsigned char *dst = aframe;
		const unsigned char *src = frame;
		const unsigned char *usrc = frame + HEIGHT*160;
		const unsigned char *vsrc = usrc + (HEIGHT/2)*80;

		int err1[80+2] = {0}, err2[80+2] = {0};
		int *perr = err1;
		int *nerr = err2;

		float errc1[80+2] = {0}, errc2[80+2] = {0};
		float *pcerr = errc1;
		float *ncerr = errc2;

		float errs1[80+2] = {0}, errs2[80+2] = {0};
		float *pserr = errs1;
		float *nserr = errs2;

		for(int y=0; y<HEIGHT; ++y) {
			if (!(y & 1)) {
				memset(ncerr, 0, 82*sizeof(float));
				memset(nserr, 0, 82*sizeof(float));

				int dir = (y & 2) ? -1 : 1;

				if (dir < 0) {
					usrc += 79;
					vsrc += 79;
					dst += 40;
				}

				uint8 accum = 0;
				for(int x=0; x<80; ++x) {
					int u = (int)*usrc - 128;		// chroma blue
					int v = (int)*vsrc - 128;		// chroma red
					usrc += dir;
					vsrc += dir;

					float fu = (float)u;
					float fv = (float)v;

					float red = 1.596f * fv;
					float grn = -0.391f * fu - 0.813f * fv;
					float blu = 2.017f * fu;

					float fi = (0.595f*red - 0.274f*grn - 0.321f*blu) + (float)pcerr[x + 1] / 25.0f + errfi[y][x];
					float fq = (0.211f*red - 0.522f*grn + 0.311f*blu) + (float)pserr[x + 1] / 25.0f + errfq[y][x];

					float satsq = fi*fi + fq*fq;

					float rawhue = atan2f(fq, fi) * (7.0f / 3.1415926535f) - 0.5f;
					int ihue = (int)floorf(rawhue + 0.5f);

					int color = ((ihue + 14*1000) % 14) + 1;
					int out = 0;

					if (satsq > 40*40) {
						out += color;

						float sc = 40.0f / sqrtf(satsq);
						fi *= sc;
						fq *= sc;
					}

					float ierror = fi - itab[out];
					float qerror = fq - qtab[out];

					errfi[y][x] = ierror * (9.0f / 25.0f);
					errfq[y][x] = qerror * (9.0f / 25.0f);

					pcerr[x + 2] += ierror * 7;
					ncerr[81 - x] += ierror * 3;
					ncerr[80 - x] += ierror * 5;
					ncerr[79 - x] += ierror;

					pserr[x + 2] += qerror * 7;
					nserr[81 - x] += qerror * 3;
					nserr[80 - x] += qerror * 5;
					nserr[79 - x] += qerror;

					if (dir < 0) {
						accum = (accum >> 4) + (out << 4);

						if (x & 1)
							*--dst = accum;
					} else {
						accum = (accum << 4) + out;

						if (x & 1)
							*dst++ = accum;
					}
				}

				if (dir < 0) {
					usrc += 81;
					vsrc += 81;
					dst += 40;
				}

				std::swap(ncerr, pcerr);
				std::swap(nserr, pserr);
			} else {
				memset(nerr, 0, (80+2)*sizeof(int));

				int dir = (y & 2) ? -1 : 1;

				if (dir < 0) {
					src += 160-2;
					dst += 40;
				}

				uint8 accum = 0;
				for(int x=0; x<80; ++x) {
					int a = (((int)src[0] + (int)src[1] + (int)src[160] + (int)src[161] - 64) * 255 + 219*2) / (219*4);
					src += dir*2;

					a += (perr[x + 1] + errfy[y][x]) / 25;

					if (a < 0)
						a = 0;
					else if (a > 255)
						a = 255;

					// [0,42]
					// [42,127]
					// [127,213]
					// [213,255]
					int b = (a + 8) / 17;

					if (b < 0)
						b = 0;
					else if (b > 15)
						b = 15;

					int c = b * 17;
					int e = a - c;

					errfy[y][x] = e * 9;
					perr[x + 2] += e * 7;
					nerr[81 - x] += e * 3;
					nerr[80 - x] += e * 5;
					nerr[79 - x] += e;

					if (dir < 0) {
						accum = (accum >> 4) + (b << 4);

						if (x & 1)
							*--dst = accum;
					} else {
						accum = (accum << 4) + b;

						if (x & 1)
							*dst++ = accum;
					}
				}

				if (dir < 0) {
					src += 320+2;
					dst += 40;
				} else
					src += 160;

				std::swap(nerr, perr);
			}
		}

		++frn;

		fwrite(aframe, HEIGHT*40, 1, fo);
	}

	fclose(fo);

	return 0;
}
