Name
c64optimizer - tool to prepare bitmap images for Commodore 64 hardware.


Description 
c64optimizer is a niche tool to prepare bitmap images for displaying on Commodore 64 hardware. The main feature of the tool is to limit the amount of colors used in each char to 4 (for hires) or 2 (other formats), but also offers additional options to resize, crop/expand, optimize color palette and dither.

The resulting image will be saved as a new image that are already to be converted to cid or prg by another tool such as png2prg by Burglar

If no options are supplied c64optimizer will assume that the input image is the correct size (320x200) and is limited to the allowed C64 color palette and just make sure that no char consists of more than 4 colors as required for the koala format.


Synopsis 
c64optimizer -i FILE (-s scale) (-t translate) (-c comment)




Options:
-i 	Name of the input file. This must be a valid bitmap.

-r Resize the output to fixed width (320px) and aspect fitted height. For all other dimensions prepare the image using any other resizing tool and omit the -r switch

-a ('north', 'south', 'center') Adjust image to fit C64 resolution (320x200) by cropping or expanding the canvas using the supplied gravity

-c (2-4) Restrict the amount of colors used per char to the supplied value. Default is 4

-d  Dither output using Floyd-Steinberg algorithm. 

-h  Display help message and exit.

-f  Shorthand for -r -a center

-o (name) Output file. Default is inputfile_optimized.png

-v (0-2) Be verbose about the process. 0=quiet, 2=all details. Default is 0

 

Examples:
Resize and fit an otherwise unprepared full color bitmap using dithering (koala). 

c64optimizer -i rose.png -f -d 

Resize and crop the top part of the input, while showing the process (koala)

c64optimizer -i rose.png -r -a north -v 1

Only restrict the max amount of colors per char to 2 while assuming correct size (hires). Save result to output.png

c64optimizer -I rose.png -c 2 -o output.png