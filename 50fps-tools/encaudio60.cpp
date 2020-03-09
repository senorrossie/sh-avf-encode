#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <io.h>

int main(int argc, const char **argv) {
	setvbuf(stdin, NULL, _IOFBF, 16384);
	_setmode(_fileno(stdin), _O_BINARY);

	if (argc < 2) {
		fprintf(stderr, "Output filename required.\n");
		return 5;
	}

	FILE *fo = fopen(argv[1], "wb");
	if (!fo) {
		fprintf(stderr, "Unable to open for write: %s\n", argv[1]);
		return 10;
	}

	int error = 0;
	int last = 0;

	char secbuf[512];
	int secidx = 0;

	for(;;) {
		int c = getchar();

		if (c == EOF)
			break;

		int c0 = c;

		c -= error;
		int d = c >> 4;

		if (c < 0)
			c = 0;
		else if (c > 255)
			c = 255;

		secbuf[secidx] = (c * 100 / 255);
		if (++secidx >= 512) {
			secidx = 0;
			fwrite(secbuf, 512, 1, fo);
		}
	}

	fclose(fo);

	return 0;
}
