CC = gcc
CFLAGS = -lm

# PREFIX is environment variable, set default if not set
ifeq ($(PREFIX),)
    PREFIX := /usr/local
endif

all: encaudio60.o encvideo50n.o mux50n.o

encaudio60.o: encaudio60.cpp

encvideo50n.o: encvideo50n.cpp

mux50n.o: mux50n.cpp

install:
	install -d $(PREFIX)/bin
	install -m 755 encaudio60.o		$(PREFIX)/bin/encaudio60
	install -m 755 encvideo50n.o	$(PREFIX)/bin/encvideo50n
	install -m 755 mux50n.o			$(PREFIX)/bin/mux50n

clean:
	-rm -f *.o
