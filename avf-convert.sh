#!/bin/bash

#NTSC
HUE="1.5"
FPS="59.9227"
BRATE=15700
FORMAT=NTSC

#PAL
HUE="1"
FPS="49.86"
BRATE=15558
FORMAT=PAL

VIDIN=$1
OUTFILE=$(basename "${1%.*}")

function encVideo() {
        mencoder -nosound -of rawvideo -ovc raw -vf hue=0:${HUE},scale=77:192,expand=160:192,format=yv12,harddup,swapuv -sws 6 -ofps ${FPS} "${VIDIN}" -o "${OUTFILE}.raw"
        if [ "$FORMAT" = "NTSC" ]; then
                /usr/local/bin/encvideo60n < "${OUTFILE}.raw" "${OUTFILE}.mov"
        else
                /usr/local/bin/encvideo50n < "${OUTFILE}.raw" "${OUTFILE}.mov"
        fi

}

function encAudio() {
        ffmpeg -i "${VIDIN}" "${OUTFILE}.wav"
        sox "${OUTFILE}.wav" -C 0.5 -c 1 -b 8 -r ${BRATE} "${OUTFILE}.u8" gain -l 10

        /usr/local/bin/encaudio60 < "${OUTFILE}.u8" "${OUTFILE}.aud"
}

function muxAV(){
        /usr/local/bin/mux50n "${OUTFILE}.mov" "${OUTFILE}.aud" "${OUTFILE}-${FORMAT}.avf"
}

if [ -z "${VIDIN}" ] || [ ! -e "${VIDIN}" 2>/dev/null ]; then
        printf "Aborted! file %s was not found!\n\n" "$1"
        exit 1
fi

echo "Converting ${VIDIN} to ${OUTFILE}-${FORMAT}.avf..."
encVideo
encAudio
muxAV
