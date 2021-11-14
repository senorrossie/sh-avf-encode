# sh-avf-encode
Shell encode Atari Video Files (50 fps 15.7KHz audio)

## Origin
In 2013, Atari Age user phaeron (author of virtualdub and altirra) [posted a method to achieve 60pfs video on an Atari 8-bit homecomputer](https://atariage.com/forums/topic/211689-60-fps-video-using-side-2/). In this long thread, [user a8isa posted a shell snippet to convert a video file using linux shell commands](https://atariage.com/forums/topic/211689-60-fps-video-using-side-2/?do=findComment&comment=3841921).

## Usage
Compile the 50fps-tools from phaeron first, and install them to a location in your $PATH:
```
cd 50fps-tools
PREFIX=/usr/local make
sudo make install
```
The above commands will install the binaries to /usr/local/bin

With the binaries in place you can use the script to convert your video to a format compatible with your Atari 8-bit:
```
./avf-convert.sh -F PAL -s myvideo.avi
```
This should generate a PAL encoded `my_video.avf`. `-F NTSC` will convert to NTSC.