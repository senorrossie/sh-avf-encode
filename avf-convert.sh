#!/usr/bin/env bash

function do_Exit() {
        if [ -z "${E}" ]; then
                E=1
        fi

        let E=${E}
        if [ ${E} -gt 0 ]; then
                R="[ERROR] ${R}"
        fi
        if [ ! -z "${R}" ]; then
                printf "%s\n" "${R}"
        fi
        exit ${E}
}

function encVideo() {
        echo "Dumping raw video..."
	$FFMPEG -i "${VIDIN}" -c rawvideo -s ${EXPAND} -pix_fmt yuv420p -r ${FPS} "${TMPFILE}.yuv" && mv "${TMPFILE}".yuv "${TMPFILE}.raw"

        echo "Encoding raw video into $FORMAT..."
        if [ "$FORMAT" = "NTSC" ]; then
                $ENCVIDEO60N < "${TMPFILE}.raw" "${TMPFILE}.mov" 1>/dev/null 2>/dev/null
        else
                $ENCVIDEO50N < "${TMPFILE}.raw" "${TMPFILE}.mov" 1>/dev/null 2>/dev/null
        fi

}

function encAudio() {
        echo "Dumping audio to WAV..."
        $FFMPEG -y -i "${VIDIN}" "${TMPFILE}.wav" 1>/dev/null 2>/dev/null

        # Sox arguments:
        #  -C compression factor
        #  -c channels
        #  -b bits
        #  -r rate (Sample rate)
        #  gain
        #    -l limiter (gain dB)
        echo "Converting WAV to U8..."
        $SOX "${TMPFILE}.wav" -C 0.5 -c 1 -b 8 -r ${SRATE} ${sxNORM} "${TMPFILE}.u8" gain -l 10

        echo "Encoding audio..."
        $ENCAUDIO60 < "${TMPFILE}.u8" "${TMPFILE}.aud"
}

function muxAV(){
        echo "Muxing A+V..."
        if [ "$FORMAT" = "NTSC" ]; then
                $MUX60N "${TMPFILE}.mov" "${TMPFILE}.aud" "${OUTDIR}${OUTFILE}-${FORMAT}.avf"
        else
                $MUX50N "${TMPFILE}.mov" "${TMPFILE}.aud" "${OUTDIR}${OUTFILE}-${FORMAT}.avf"
        fi
}

### Main
# Settings
E=0     # Error
R=""    # Result TXT

# Tools used/needed
ENCAUDIO60=$(which encaudio60)
ENCVIDEO50N=$(which encvideo50n)
ENCVIDEO60N=$(which encvideo60n)
FFMPEG=$(which ffmpeg)
MUX50N=$(which mux50n)
MUX60N=$(which mux60n)
SOX=$(which sox)

if [ ${ENCAUDIO60}x == x ] || \
   [ ${ENCVIDEO50N}x == x ] || \
   [ ${ENCVIDEO60N}x == x ] || \
   [ ${FFMPEG}x == x ] || \
   [ ${MUX50N}x == x ] || \
   [ ${SOX}x == x ]; then
        E=1
        R="One or more tools required to run were not found. Check presence of ffmpeg, sox and the 50fps-tools."
        do_Exit
fi

### Parameter check
# getopt paramchar: == -paramchar +argument
#  example: ./progname -u argh == getopts u:
# getopt paramchar  == -paramchar
#  example: ./progname -h == getopts h
while getopts d:E:F:H:hN:s: PARAM; do
	case $PARAM in
		d)
			# Destination file
			OUTFILE=${OPTARG}
			;;
                E)
			# ffmpeg expand
                        EXPAND="${OPTARG}"
                        ;;
		F)
			# Format
                        case ${OPTARG:=P} in
                                [pP]*)
                                        # PAL
                                        HUE=${HUE:=1}
                                        FPS="49.86"
                                        SRATE=15558
                                        EXPAND=${EXPAND:="160:192"}
                                        FORMAT=PAL
                                        ;;
                                [nN]*)
                                        # NTSC
                                        HUE=${HUE:=1.5}
                                        FPS="59.9227"
                                        SRATE=15700
                                        EXPAND=${EXPAND:="160:192"}
                                        FORMAT=NTSC
                                        ;;
                        esac
			;;
		H)
                        # HUE
			HUE=${OPTARG}
			;;
		h)
                        # Help
                        R="No help available.\n"
                        E=1
                        do_Exit
                        ;;
		N)
			# Normalize (dB level)
			sxNORM="--norm=${OPTARG}"
			;;
		s)
			# Source file
			VIDIN=${OPTARG}
			;;
	esac
done
let RESULT=$?

### Sanity checks
if [ ${RESULT} -gt 0 ]; then
	E=1
	R="Incorrect parameter supplied."
	do_Exit
fi
if [ -z "${VIDIN}" ] || [ ! -e "${VIDIN}" 2>/dev/null ]; then
        E=1
        R="Aborted! file $VIDIN was not found!"
        do_Exit
fi

OUTFILE=${OUTFILE:=my_video.avf}
OUTFILE=${OUTFILE%.*}
OUTDIR=""

TMPFILE=$(basename "${OUTFILE}")
TMPFILE="tmp/${TMPFILE}"

echo "Converting ${VIDIN} to ${OUTDIR}${OUTFILE}-${FORMAT}.avf (work file ${TMPFILE})..."
encVideo
encAudio
muxAV
echo " ! All Done !"
