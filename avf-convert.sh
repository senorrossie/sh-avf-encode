#!/bin/bash

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
        # mencoder arguments:
        #  -nosound
        #  -of Output Format (rawvideo)
        #  -ovc Video encoder (raw)
        #  -vf 
        #    hue
        #    scale
        #    expand
        #    format
        #    harddup (write every frame)
        #    swapuv
        #  -sws software scaler
        #  -ofps Output fps
        echo "Dumping raw video..."
        mencoder -nosound -of rawvideo -ovc raw \
                -vf hue=0:${HUE}${meSCALE}${meEXPAND},format=yv12,swapuv,harddup \
                -sws 6 -ofps ${FPS} "${VIDIN}" -o "${TMPFILE}.raw" > "${TMPFILE}.mencode.log" 2>&1

        echo "Encoding raw video into $FORMAT..."
        if [ "$FORMAT" = "NTSC" ]; then
                encvideo60n < "${TMPFILE}.raw" "${TMPFILE}.mov" 1>/dev/null 2>/dev/null
        else
                encvideo50n < "${TMPFILE}.raw" "${TMPFILE}.mov" 1>/dev/null 2>/dev/null
        fi

}

function encAudio() {
        echo "Dumping audio to WAV..."
        ffmpeg -y -i "${VIDIN}" "${TMPFILE}.wav" 1>/dev/null 2>/dev/null

        # Sox arguments:
        #  -C compression factor
        #  -c channels
        #  -b bits
        #  -r rate (Sample rate)
        #  gain
        #    -l limiter (gain dB)
        echo "Converting WAV to U8..."
        sox "${TMPFILE}.wav" -C 0.5 -c 1 -b 8 -r ${SRATE} ${sxNORM} "${TMPFILE}.u8" gain -l 10

        echo "Encoding audio..."
        encaudio60 < "${TMPFILE}.u8" "${TMPFILE}.aud"
}

function muxAV(){
        echo "Muxing A+V..."
        mux50n "${TMPFILE}.mov" "${TMPFILE}.aud" "${OUTDIR}${OUTFILE}-${FORMAT}.avf"
}

### Main
# Settings
E=0     # Error
R=""    # Result TXT

### Parameter check
# getopt paramchar: == -paramchar +argument
#  example: ./progname -u argh == getopts u:
# getopt paramchar  == -paramchar
#  example: ./progname -h == getopts h
while getopts d:E:F:H:hN:s:S: PARAM; do
	case $PARAM in
		d)
			# Destination file
			OUTFILE=${OPTARG}
			;;
                E)
                        # mencoder Expand
                        meEXPAND=",expand=${OPTARG}"
                        ;;
		F)
			# Format
                        case ${OPTARG:=P} in
                                [pP]*)
                                        # PAL
                                        HUE=${HUE:=1}
                                        FPS="49.86"
                                        SRATE=15558
                                        meEXPAND=${meEXPAND:=",expand=160:192"}
                                        meSCALE=${meSCALE:=",scale=77:192"}
                                        FORMAT=PAL
                                        ;;
                                [nN]*)
                                        # NTSC
                                        HUE=${HUE:=1.5}
                                        FPS="59.9227"
                                        SRATE=15700
                                        meEXPAND=${meEXPAND:=",expand=160:192"}
                                        meSCALE=${meSCALE:=",scale=77:192"}
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
                        ;;
		N)
			# Normalize (dB level)
			sxNORM="--norm=${OPTARG}"
			;;
		s)
			# Source file
			VIDIN=${OPTARG}
			;;
                S)
                        # mencoder Scale
                        meSCALE=",scale=${OPTARG}"
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
OUTDIR="videos/"

TMPFILE=$(basename "${OUTFILE}")
TMPFILE="tmp/${TMPFILE}"

echo "Converting ${VIDIN} to ${OUTDIR}${OUTFILE}-${FORMAT}.avf (work file ${TMPFILE})..."
encVideo
encAudio
muxAV
echo " ! All Done !"
