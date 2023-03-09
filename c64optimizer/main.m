//
//  main.m
//  c64optimizer
//
//  Created by Jonatan Yde on 07/03/2023.
//
#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#define CLAMP(x, low, high)  (((x) > (high)) ? (high) : (((x) < (low)) ? (low) : (x)))


NSDictionary* getUsedColors(NSBitmapImageRep* image, CGRect block);
NSArray* getReducedPalette(NSDictionary *palette, int maxColors,  NSColor* _Nullable requiredColor);
NSColor* getDominantColor(NSDictionary* palette);
float GetDistanceBetweenColours(NSColor* a, NSColor* b);
NSColor* MatchColor(NSColor* input, NSArray* palette);
void ditherBlock(NSBitmapImageRep *image, CGRect block, NSArray* palette);
void reduceBlock(NSBitmapImageRep *image, CGRect block, NSArray* palette);
NSBitmapImageRep* resizeImage(NSBitmapImageRep* sourceImage, NSSize newSize);
NSBitmapImageRep* cropImage(NSBitmapImageRep* sourceImage, NSRect cropArea);
NSArray<NSColor*>* getC64Palette(void);
NSArray<NSColor*>* getSimplePalette(void);
enum Gravity parseGravity(NSString *input);
void printHelp(void);

enum Gravity
{
    North,
    South,
    Center
};

enum Gravity parseGravity(NSString *input)
{
    if(!input)
        return Center;
    
    if([input.lowercaseString isEqualToString:@"south"])
        return South;
    else if([input.lowercaseString isEqualToString:@"north"])
        return North;
    else if([input.lowercaseString isEqualToString:@"center"])
        return Center;
    else
        printf("'%s' not recognized. Please specify either North, South or Center. Default to center\n", [input cStringUsingEncoding:NSASCIIStringEncoding]);
    
    //Default
    return Center;
}



int main(int argc, char * argv[]) {
    @autoreleasepool {
        
        NSString *inputFile;
        NSString *outputFile;
        int verbose = 0;
        BOOL dither = NO;
        BOOL resizeOutput = NO;
        BOOL cropOutput = NO;
        int maxColors = 4;
        enum Gravity gravity = Center;

            

        int opt;
        opterr = 0;
        while ((opt = getopt (argc, argv, "i:o:v:hdrfc:a:")) != -1)
            switch (opt)
        {
            case 'i':
                inputFile = [NSString stringWithFormat:@"%s", optarg];
                break;
            case 'o':
                outputFile = [NSString stringWithFormat:@"%s", optarg];
                if( outputFile.pathExtension.length !=0 )
                    outputFile = [[outputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
                else if(outputFile.pathExtension.length == 0 && ![outputFile isEqualToString:@"-"] )
                    outputFile = [outputFile stringByAppendingPathExtension:@"png"];
                break;
            case 'c':
                maxColors = [[NSString stringWithFormat:@"%s", optarg] intValue];
                break;
            case 'a':
                cropOutput = YES;
                gravity = parseGravity([NSString stringWithFormat:@"%s", optarg]);
                break;
            case 'f':
                cropOutput = YES;
                resizeOutput = YES;
                break;
            case 'h':
                printHelp();
                return 0;
            case 'r':
                resizeOutput = YES;
                break;
            case 'v':
                verbose = atoi(optarg);
                break;
            case 'd':
                dither = YES;
                break;
            case '?':
                if (optopt == 'i' )
                    fprintf (stderr, "Option -%c requires an argument.\n", optopt);
                else if (isprint (optopt))
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                else
                    fprintf (stderr,
                             "Unknown option character `\\x%x'.\n",
                             optopt);
                return 1;
            default:
                abort ();
        }
        
        if(!inputFile)
        {
            printf("Error: no inpout file!\n");
            printf("Usage: c64optimizer -i <file> <options>\n");
            printf("use -h to see all options.\n");
            return 1;
        }
        if(![[NSFileManager defaultManager] fileExistsAtPath:inputFile])
        {
            printf("Error: Input file not found.\n");
            return 1;
        }
        
        NSData *inputData;

        if([inputFile isEqualToString:@"-"])
        {
            NSFileHandle *inputHandle = [NSFileHandle fileHandleWithStandardInput];
            NSMutableData *tmpInputData = [[NSMutableData alloc] init];
            NSData *dataBuffer = inputHandle.availableData;
            while(dataBuffer.length > 0)
            {
                [tmpInputData appendData:dataBuffer];
                if(verbose > 0) printf("Data received: %lu\n", (unsigned long)tmpInputData.length);
                dataBuffer = inputHandle.availableData;
            }
            inputData = [NSData dataWithData:tmpInputData];
        }
        else
            inputData = [NSData dataWithContentsOfFile:inputFile];
        
        
        NSImage *inputImage = [[NSImage alloc] initWithData:inputData];
        NSBitmapImageRep *inputRep =  [NSBitmapImageRep imageRepWithData:[inputImage TIFFRepresentation]];
        int width = (int)inputRep.pixelsWide;
        int height = (int)inputRep.pixelsHigh;
        CGSize blockSize = CGSizeMake(8, 8);
        
        
        if(resizeOutput)
        {
            float ratio = width/height;
            int newWidth = 320;
            int newHeight = newWidth / ratio;
            NSSize desiredSize = NSMakeSize(newWidth, newHeight);
            
            inputRep = resizeImage(inputRep, desiredSize);
            width = (int)inputRep.pixelsWide;
            height = (int)inputRep.pixelsHigh;
            if(verbose > 0) printf("Image resized to %dx%d.\n", width, height);
        }
        
        if(cropOutput)
        {
            NSSize cropSize = NSMakeSize(320, 200); //hardcoded c64 dimensions
            NSRect cropArea;
            if(gravity == South)
            {
                cropArea = NSMakeRect(0, 0, cropSize.width, cropSize.height);
                if(verbose > 0) printf("Adjusting using gravity: south\n.");
            }
            else if(gravity == North)
            {
                cropArea = NSMakeRect(0, height-cropSize.height, cropSize.width, cropSize.height);
                if(verbose > 0) printf("Adjusting using gravity: north\n.");
            }
            else
            {
                cropArea = NSMakeRect((width - cropSize.width)/2, (height - cropSize.height)/2, cropSize.width, cropSize.height);
                if(verbose > 0) printf("Adjusting using gravity: center.\n");
            }
            
            inputRep = cropImage(inputRep, cropArea);
            
            width = (int)inputRep.pixelsWide;
            height = (int)inputRep.pixelsHigh;
            if(verbose > 0) printf("Image adjusted to %dx%d.\n", width, height);
        }
        
        if(verbose > 0) printf("Matching C64 color palette.\n");
        if(dither)
        {
            if(verbose > 0) printf("Using dithering to reduce colors.\n");
            ditherBlock(inputRep, CGRectMake(0, 0, width, height), getC64Palette());
        }
        else
        {
            if(verbose > 0) printf("Using closest match to reduce colors.\n");
            reduceBlock(inputRep, CGRectMake(0, 0, width, height), getC64Palette());
            
        }
        
        
        NSDictionary *allColors = getUsedColors(inputRep, CGRectMake(0, 0, width, height));
        if(verbose > 0) printf("Colors used: %lu\n", (unsigned long)allColors.count);
        NSColor *dominantColor = getDominantColor(allColors);
        
        
        for(int y = 0; y < height; y+=blockSize.height)
        {
            for(int x = 0; x < width; x+=blockSize.width)
            {
                CGRect block = CGRectMake(x, y, blockSize.width, blockSize.height);
                
                NSDictionary* activeColors = getUsedColors(inputRep, block);
                if(activeColors.count >= maxColors)
                {
                    if(verbose > 1) printf("Block %d,%d contains equal or more than %d colors (%lu)\n", x, y, maxColors, (unsigned long)activeColors.count);
                                                        
                    NSArray *colors = getReducedPalette(activeColors, maxColors, dominantColor);
                    reduceBlock(inputRep, block, colors);
                    //ditherBlock(inputRep, block, colors);
                    if(verbose > 1) printf("Block reduced to %lu colors. \n", colors.count);
                }
                else
                {
                    if(verbose > 1) printf("Block %d,%d contains less than %d colors (%lu).\n", x, y, maxColors, (unsigned long)activeColors.count);
                }
            }
        }
        
        //Check the output path
        if(!outputFile)
            //outputFile = [[[inputFile stringByDeletingPathExtension] stringByAppendingString:@"_optimized"] stringByAppendingPathExtension:@"png"];
            outputFile = [[[[inputFile lastPathComponent] stringByDeletingPathExtension] stringByAppendingString:@"_optimized"] stringByAppendingPathExtension:@"png"];
        
        if(verbose > 0) printf("Writing output to %s.\n", [outputFile cStringUsingEncoding:NSASCIIStringEncoding]);
        //Write resulting image to disk
        NSData *image = [inputRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSError* err;
        [image writeToFile:outputFile options:NSDataWritingAtomic error:&err];
        
        if(err)
            printf("An error occurend: %s", [err.description cStringUsingEncoding:NSASCIIStringEncoding]);
        else
            printf("All done\n");
    }
    
    
    return 0;
}


NSDictionary* getUsedColors(NSBitmapImageRep* image, CGRect block)
{
    NSMutableDictionary* activeColors = [[NSMutableDictionary alloc] init];
    
    for(int y = block.origin.y; y < block.origin.y+block.size.height; y++)
    {
        for(int x = block.origin.x; x < block.origin.x + block.size.width; x++)
        {
            NSColor *color = [image colorAtX:x y:y];
            if(!color) continue;
            
            NSNumber *currentCount = [activeColors objectForKey:color];
            currentCount = [NSNumber numberWithInt:[currentCount intValue] + 1];
            
            [activeColors setObject:currentCount forKey:color];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary: activeColors];
}


NSArray* getReducedPalette(NSDictionary *palette, int maxColors,  NSColor* _Nullable requiredColor)
{
    NSMutableArray* reducedPalette = [[NSMutableArray alloc] init];
    
    NSArray *keys = [palette keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber * obj2) {
        return obj1.intValue < obj2.intValue;
    }];
    
    
    
    int counter = 0;
    for(NSColor* color in keys)
    {
        [reducedPalette addObject:color];
        counter++;
        if(counter >= maxColors)
            break;
    }

    if(requiredColor)
    {
        if(![reducedPalette doesContain:requiredColor])
        {
            [reducedPalette removeLastObject];
            [reducedPalette addObject:requiredColor];
        }
    }
    return reducedPalette;
}

NSColor* getDominantColor(NSDictionary* palette)
{
    NSArray *keys = [palette keysSortedByValueUsingComparator:^NSComparisonResult(NSNumber *obj1, NSNumber * obj2) {
        return obj1.intValue < obj2.intValue;
    }];
    
    return [keys firstObject];
}


void reduceBlock(NSBitmapImageRep *image, CGRect block, NSArray* palette)
{
    for(int y = block.origin.y; y < block.origin.y+block.size.height; y++)
    {
        for(int x = block.origin.x; x < block.origin.x + block.size.width; x++)
        {
            NSColor *color = [image colorAtX:x y:y];
            NSColor *matchedColor = MatchColor(color, palette);
            [image setColor:matchedColor atX:x y:y];
            
        }
    }
}




NSColor* MatchColor(NSColor* input, NSArray* palette)
{
    NSColor *output = [NSColor whiteColor];
    float delta = 255*255 + 255*255 + 255*255; //441.7 (sqrt);
    
    for (NSColor *color in palette) {
        
        float dist = GetDistanceBetweenColours(color, input);
        if (dist < delta)
        {
            delta = dist;
            output = color;
        }
    }
   return output;
}

float GetDistanceBetweenColours(NSColor* a, NSColor* b)
{
    
    float dR = fabs( a.redComponent * 255 - b.redComponent * 255 );
    float dG = fabs( a.greenComponent * 255 - b.greenComponent * 255);
    float dB = fabs( a.blueComponent * 255 - b.blueComponent * 255);

    return  dR * dR + dG * dG + dB * dB; // 0 - 195.075 (sqr = 441,6729559300637)

}


NSBitmapImageRep* resizeImage(NSBitmapImageRep* sourceImage, NSSize newSize)
{
    NSImage *tmp = [[NSImage alloc] init];
    [tmp addRepresentation:sourceImage];
    if (! tmp.isValid) return nil;

    NSBitmapImageRep *outputRep = [[NSBitmapImageRep alloc]
              initWithBitmapDataPlanes:NULL
                            pixelsWide:newSize.width
                            pixelsHigh:newSize.height
                         bitsPerSample:8
                       samplesPerPixel:4
                              hasAlpha:YES
                              isPlanar:NO
                        colorSpaceName:NSCalibratedRGBColorSpace
                           bytesPerRow:0
                          bitsPerPixel:0];
    outputRep.size = newSize;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:outputRep]];
    
    
    [tmp drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
    
    
    [NSGraphicsContext restoreGraphicsState];

    return outputRep;
}

NSBitmapImageRep* cropImage(NSBitmapImageRep* sourceImage, NSRect cropArea)
{
    NSImage *tmp = [[NSImage alloc] init];
    [tmp addRepresentation:sourceImage];
    
    if (! tmp.isValid) return nil;

    NSBitmapImageRep *outputRep = [[NSBitmapImageRep alloc]
              initWithBitmapDataPlanes:NULL
                            pixelsWide:cropArea.size.width
                            pixelsHigh:cropArea.size.height
                         bitsPerSample:8
                       samplesPerPixel:4
                              hasAlpha:YES
                              isPlanar:NO
                        colorSpaceName:NSCalibratedRGBColorSpace
                           bytesPerRow:0
                          bitsPerPixel:0];
    outputRep.size = cropArea.size;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:outputRep]];
    
    [tmp drawAtPoint:NSZeroPoint   fromRect:cropArea operation:NSCompositingOperationSourceOver fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];

    tmp = nil;

    return outputRep;
}


void ditherBlock(NSBitmapImageRep *sourceImage, CGRect block, NSArray* palette)
{
    
    
    for (int y = block.origin.y; y < block.origin.y+block.size.height; y++)
    {
        for (int x = block.origin.x; x < block.origin.x+block.size.width; x++)
        {
            NSColor *actualColor = [sourceImage colorAtX:x y:y];
            NSColor *matchedColor = MatchColor(actualColor, palette);
            
            float rError = (actualColor.redComponent - matchedColor.redComponent) / 16;
            float gError = (actualColor.greenComponent - matchedColor.greenComponent) / 16;
            float bError = (actualColor.blueComponent - matchedColor.blueComponent) / 16;
            
            [sourceImage setColor:matchedColor atX:x y:y];
            
            /*
             multiplication coeficients for surrounding pixels
               x 7
             3 5 1
             */
            
            NSColor *nextColor;
            int coefficient;
            //field to the immidiate right
            nextColor = [sourceImage colorAtX:x+1 y:y];
            coefficient = 7;
            NSColor *adjustedColor = [NSColor colorWithCalibratedRed:CLAMP( nextColor.redComponent + rError * coefficient, 0, 1) green:CLAMP( nextColor.greenComponent + gError * coefficient, 0, 1) blue:CLAMP( nextColor.blueComponent + bError * coefficient, 0, 1) alpha:1.0 ];
            [sourceImage setColor:adjustedColor atX:x+1 y:y];
            
            //field to the left & down
            nextColor =  [sourceImage colorAtX:x-1 y:y+1];
            coefficient = 3;
            adjustedColor = [NSColor colorWithCalibratedRed:CLAMP( nextColor.redComponent + rError * coefficient, 0, 1) green:CLAMP( nextColor.greenComponent + gError * coefficient, 0, 1) blue:CLAMP( nextColor.blueComponent + bError * coefficient, 0, 1) alpha:1.0 ];
            [sourceImage setColor:adjustedColor atX:x-1 y:y+1];
            
            //field to the imidiate down
            nextColor = [sourceImage colorAtX:x y:y+1];
            coefficient = 5;
            adjustedColor = [NSColor colorWithCalibratedRed:CLAMP( nextColor.redComponent + rError * coefficient, 0, 1) green:CLAMP( nextColor.greenComponent + gError * coefficient, 0, 1) blue:CLAMP( nextColor.blueComponent + bError * coefficient, 0, 1) alpha:1.0 ];
            [sourceImage setColor:adjustedColor atX:x y:y+1];
            
            //field to the right & down
            nextColor = [sourceImage colorAtX:x+1 y:y+1];
            coefficient = 1;
            adjustedColor = [NSColor colorWithCalibratedRed:CLAMP( nextColor.redComponent + rError * coefficient, 0, 1) green:CLAMP( nextColor.greenComponent + gError * coefficient, 0, 1) blue:CLAMP( nextColor.blueComponent + bError * coefficient, 0, 1) alpha:1.0 ];
                
            [sourceImage setColor:adjustedColor atX:x+1 y:y+1];
        }
    }
    
    //return sourceImage;
}


NSArray<NSColor*>* getC64Palette(void)
{
    return @[
    [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1],                          //0: black
    [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1],                          //1: white
    [NSColor colorWithCalibratedRed:136./255. green:0 blue:0 alpha:1],                  //2: red
    [NSColor colorWithCalibratedRed:170./255. green:1 blue:238./255. alpha:1],          //3: Cyan
    [NSColor colorWithCalibratedRed:204./255. green:68./255. blue:204./255. alpha:1],   //4: Purple
    [NSColor colorWithCalibratedRed:0 green:204./255. blue:85./255. alpha:1],           //5: Green
    [NSColor colorWithCalibratedRed:0 green:0 blue:170./255. alpha:1],                  //6: Blue
    [NSColor colorWithCalibratedRed:238./255. green:238./255. blue:119./255. alpha:1],  //7: Yellow
    [NSColor colorWithCalibratedRed:221./255. green:136./255. blue:85./255. alpha:1],   //8: Orange
    [NSColor colorWithCalibratedRed:102./255. green:68./255. blue:0 alpha:1],           //9: Brown
    [NSColor colorWithCalibratedRed:255./255. green:119./255. blue:119./255. alpha:1],  //10: Light red
    [NSColor colorWithCalibratedRed:51./255. green:51./255. blue:51./255. alpha:1],     //11: Dark grey / Grey 1./255
    [NSColor colorWithCalibratedRed:119./255. green:119./255. blue:119./255. alpha:1],  //12: Grey 2
    [NSColor colorWithCalibratedRed:170./255. green:1 blue:102./255. alpha:1],          //13: Light green
    [NSColor colorWithCalibratedRed:0 green:136./255. blue:1 alpha:1],                  //14: Light blue
    [NSColor colorWithCalibratedRed:187./255. green:187./255. blue:187./255. alpha:1]    //15: Light grey / Grey 3
    
    
];
}

NSArray<NSColor*>* getSimplePalette(void)
{
    return @[
    [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1],                          //0: black
    [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1],                          //1: white
    [NSColor colorWithCalibratedRed:136./255. green:0 blue:0 alpha:1],                  //2: red
    [NSColor colorWithCalibratedRed:0 green:0 blue:170./255. alpha:1],                  //6: Blue
    [NSColor colorWithCalibratedRed:170./255. green:1 blue:102./255. alpha:1],          //13: Light green
];
}

void printHelp(void)
{
    printf("Usage: c64optimizer -i <file> [-ovhdrfca].\n");
    printf("E.g: c64optimizer -i input.png -r -a North\n");
    
    printf("\t-i\tInput file. Must be a bitmap image.\n");
    printf("\t-o\tOutput name.\n");
    printf("\t-r\tResize image to fit C64 width (320px).\n");
    printf("\t\tPlease note that aspect ratio might result in a hight larger than 200px\n");
    printf("\t\tUse in concunjtion with -a switch to crop.\n");
    printf("\t-a\tAdjust image fit 320x200 by cropping it\n");
    printf("\t\tGravity can be 'north', 'center' or 'south'.\n");
    printf("\t-f\tShorthand for '-r -a Center' \n");
    printf("\t-c\tMax amount of colors per char (2-4).\n");
    printf("\t-d\tDither output.\n");
    printf("\t-v\tBe verbose about the process (0-2).\n");
    printf("\t-h\tDisplay this help.\n");
}

