#include <stdio.h>
#include <string.h>

const int HEIGHT = 192;

int main(int argc, char **argv) {
	if (argc != 4)
		return 10;

	const char *fnvid = argv[1];
	const char *fnaud = argv[2];
	const char *fnout = argv[3];

	FILE *fv = fopen(fnvid, "rb");
	FILE *fa = fopen(fnaud, "rb");
	FILE *fo = fopen(fnout, "wb+");

	if (!fv) { fprintf(stderr, "Unable to open video: %s\n", fnvid); return 20; }
	if (!fa) { fprintf(stderr, "Unable to open audio: %s\n", fnaud); return 20; }
	if (!fo) { fprintf(stderr, "Unable to open output: %s\n", fnout); return 20; }

	static unsigned char vbuf[40*HEIGHT];
	static unsigned char abuf[512];

	fseek(fo, 16*512, SEEK_SET);

	for(;;) {
		if (1 != fread(vbuf, sizeof vbuf, 1, fv))
			break;

		if (1 != fread(abuf, 312, 1, fa))
			break;

		// Line pattern:
		// 32*182 bytes video
		// 32 repeats of:
		//	Audio line 214+i
		//	Audio line 32+i*2 (next frame)
		//	Audio line 96+i*2 (next frame)
		//	Audio line 160+i*2 (next frame)
		//	Audio line 33+i*2 (next frame)
		//	Audio line 97+i*2 (next frame)
		//	Audio line 161+i*2 (next frame)
		//	Audio line 246+i
		//	Audio line 16+i (next frame)
		
		for(int y=0; y<192; y+=3) {
			putc(0, fo);
			fwrite(vbuf + 40*y, 40, 1, fo);
			putc(0, fo);
			putc(0, fo);
			putc(0, fo);

			putc(0, fo);
			fwrite(vbuf + 40*y + 40, 40, 1, fo);
			putc(0, fo);
			putc(0, fo);
			putc(0, fo);

			fwrite(vbuf + 40*y + 80, 40, 1, fo);
		}

		for(int y=0; y<32; ++y) {
			putc(abuf[y], fo);
			putc(abuf[y + 0*32 + 120], fo);
			putc(abuf[y + 1*32 + 120], fo);
			putc(abuf[y + 2*32 + 120], fo);
			putc(abuf[y + 3*32 + 120], fo);
			putc(abuf[y + 4*32 + 120], fo);
			putc(abuf[y + 5*32 + 120], fo);
			putc(abuf[y + 0*32 + 52], fo);
			putc(abuf[y + 1*32 + 52], fo);
			putc(0, fo);
		}

		for(int y=0; y<19; ++y) {
			putc(abuf[y+32], fo);
			putc(abuf[y + 2*32 + 52], fo);
			putc(0, fo);
			putc(0, fo);
			putc(0, fo);
			putc(0, fo);
			putc(0, fo);
			putc(0, fo);
			putc(0, fo);
			putc(0, fo);
		}

		putc(abuf[51], fo);
		putc(0, fo);
	}

	fclose(fv);
	fclose(fa);
	fclose(fo);

	return 0;
}
