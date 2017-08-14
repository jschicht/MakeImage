Tool that will transform a file into a bmp/bitmap. It was made to fascilitate visual comparison of binary files. It is hardcoded to use ARGB 32 bit per pixel. The image width can be configured at the input box presented. If you want to display an image representing one sector per line, you need to use width of 128 (since 128 * 4 = 512), for sectors of 512 bytes. This may result in a rather high image for larger binary files though.

MakeImage is a modification of the sources found here; https://www.autoitscript.com/forum/topic/148636-alternative-data-compression/

Comparison of 2 such bitmaps (with same size), can most easily be done by using ImageMagick. Download at https://www.imagemagick.org/download/binaries/ImageMagick-7.0.6-7-portable-Q16-x64.zip and use compare tool like this;

compare.exe input1.bmp input2.bmp diff.bmp

All different pixels are red.