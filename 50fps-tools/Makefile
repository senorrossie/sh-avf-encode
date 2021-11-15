CC = gcc
CFLAGS = -lm

# PREFIX is environment variable, set default if not set
ifeq ($(PREFIX),)
    PREFIX := /usr/local
endif

all: encaudio60.o encvideo50n.o encvideo60n.o mux50n.o mux60n.o

encaudio60.o: encaudio60.cpp

encvideo50n.o: encvideo50n.cpp

encvideo60n.o: encvideo60n.cpp

mux50n.o: mux50n.cpp

mux60n.o: mux60n.cpp

install:
	install -d $(PREFIX)/bin
	install -m 755 encaudio60.o		$(PREFIX)/bin/encaudio60
	install -m 755 encvideo50n.o	$(PREFIX)/bin/encvideo50n
	install -m 755 encvideo60n.o	$(PREFIX)/bin/encvideo60n
	install -m 755 mux50n.o			$(PREFIX)/bin/mux50n
	install -m 755 mux60n.o			$(PREFIX)/bin/mux60n

clean:
	-rm -f *.o
