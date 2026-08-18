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
float GetDistanceBetweenColoursWeighted(NSColor* a, NSColor* b);
NSColor* MatchColor(NSColor* input, NSArray* palette);
void ditherBlock(NSBitmapImageRep *image, CGRect block, NSArray* palette);
void reduceBlock(NSBitmapImageRep *image, CGRect block, NSArray* palette);
NSBitmapImageRep* resizeImage(NSBitmapImageRep* sourceImage, NSSize newSize);
NSBitmapImageRep* cropImage(NSBitmapImageRep* sourceImage, NSRect cropArea);
NSArray<NSColor*>* getC64Palette(void);
NSArray<NSColor*>* getColodorePalette(void);
NSArray<NSColor*>* getPeptoPalette(void);
NSArray<NSColor*>* getDeekayPalette(void);
NSArray<NSColor*>* getPALette(void);
NSArray<NSColor*>* getSimplePalette(void);
enum Gravity parseGravity(NSString *input);
void printHelp(void);
void exportPalette(NSArray<NSColor *>*palette,  NSString* outFile);
NSArray<NSColor*>* parsePaletteFrom(NSString *paletteFile);

void convertImageRepToCIELAB(NSBitmapImageRep* imageRep);
NSDictionary<NSColor*, NSColor*>* RGBPaletteToLab(NSArray<NSColor*>* palette);

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
        BOOL shouldExportPalette = NO;
        int verbose = 0;
        BOOL dither = NO;
        BOOL resizeOutput = NO;
        BOOL cropOutput = NO;
        int maxColors = 4;
        enum Gravity gravity = Center;
        NSSize maxDimensions = {320, 200};
        NSArray<NSColor*>* currentPalette = getColodorePalette();
        


        int opt;
        opterr = 0;
        while ((opt = getopt (argc, argv, "i:o:v:hdrfc:a:ep:P:")) != -1)
            switch (opt)
        {
            case 'i':           //Input
                inputFile = [NSString stringWithFormat:@"%s", optarg];
                break;
            case 'o':           //Output
                outputFile = [NSString stringWithFormat:@"%s", optarg];
                if( outputFile.pathExtension.length !=0 )
                    outputFile = [[outputFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"png"];
                else if(outputFile.pathExtension.length == 0 && ![outputFile isEqualToString:@"-"] )
                    outputFile = [outputFile stringByAppendingPathExtension:@"png"];
                break;
            case 'c':           //Max colors
                maxColors = [[NSString stringWithFormat:@"%s", optarg] intValue];
                break;
            case 'a':           //Crop using gravity
                cropOutput = YES;
                gravity = parseGravity([NSString stringWithFormat:@"%s", optarg]);
                break;
            case 'f':           //Shorthand for 320x200
                cropOutput = YES;
                resizeOutput = YES;
                break;
            case 'h':           //Help
                printHelp();
                return 0;
            case 'r':           //Resize to 320x-2
                resizeOutput = YES;
                break;
            case 'v':           //Verbose level 0-3
                verbose = atoi(optarg);
                break;
            case 'd':           //Dither
                dither = YES;
                break;
            case 'e':
                shouldExportPalette = YES;
                break;
            case 'p':
                currentPalette = parsePaletteFrom( [NSString stringWithFormat:@"%s", optarg] );
                if(currentPalette.count > 16)
                    printf("The loaded palette contains more colors (%lu) than the C64 is capable of (16). However you're the boss.\n", (unsigned long)currentPalette.count);
                break;
            case 'P':
                
                switch( [[NSString stringWithFormat:@"%s", optarg] intValue] )
                {
                    case 0:
                        currentPalette = getC64Palette();
                        break;
                    case 1:
                        currentPalette = getColodorePalette();
                        break;
                    case 2:
                        currentPalette = getPeptoPalette();
                        break;
                    case 3:
                        currentPalette = getDeekayPalette();
                        break;
                    case 4:
                        currentPalette = getPALette();
                        break;
                    case 5:
                        currentPalette = getSimplePalette();
                        break;
                    default:
                        break;
                }
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
            printf("Error: no input file!\n");
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
        
        if(verbose > 0 || shouldExportPalette)
        {
            NSDictionary *colorsUsedUnaltered = getUsedColors(inputRep, CGRectMake(0, 0, width, height));
            if(shouldExportPalette && colorsUsedUnaltered.count < 32)
            {
                NSString *paletteName = [[inputFile stringByDeletingPathExtension] stringByAppendingString:@"_palette.tiff"];
                
                exportPalette(colorsUsedUnaltered.allKeys,  paletteName);
                printf("Exporting palette. Ignoring everything but input parameter.\n");
                printf("Palette saved as %s and %s\n", [paletteName cStringUsingEncoding: NSASCIIStringEncoding], [[paletteName stringByReplacingOccurrencesOfString:@".tiff" withString:@".pal"] cStringUsingEncoding: NSASCIIStringEncoding]  );
                return 0;
            }
            if(shouldExportPalette && colorsUsedUnaltered.count > 32)
            {
                printf("Abort! Colors used in original exeeds 32 ( %lu ). It won't make sense to dump the palette. \n", colorsUsedUnaltered.count);
                return 1;
            }
            printf("Colors in original image: %lu\n", colorsUsedUnaltered.count);
        }
        
        
        if(resizeOutput)
        {
            float ratio = (float)width/(float)height;
            int newWidth = maxDimensions.width;
            int newHeight = newWidth / ratio;
            NSSize desiredSize = NSMakeSize(newWidth, newHeight);
            
            inputRep = resizeImage(inputRep, desiredSize);
            width = (int)inputRep.pixelsWide;
            height = (int)inputRep.pixelsHigh;
            if(verbose > 0) printf("Image resized to %dx%d.\n", width, height);
//            printf("Colors in image now: %lu\n", (unsigned long)getUsedColors(inputRep, CGRectMake(0, 0, width, height)).count);
        }
        
        if(cropOutput)
        {
            NSSize cropSize = maxDimensions; // NSMakeSize(320, 200); //hardcoded c64 dimensions
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
//            printf("Colors in image now: %lu\n", (unsigned long)getUsedColors(inputRep, CGRectMake(0, 0, width, height)).count);
        }
        
        if(verbose > 0) printf("Matching C64 color palette.\n");
        if(dither)
        {
            if(verbose > 0) printf("Using dithering to reduce colors.\n");
            ditherBlock(inputRep, CGRectMake(0, 0, width, height), currentPalette);
        }
        else
        {
            if(verbose > 0) printf("Using closest match to reduce colors.\n");
            
//            convertImageRepToCIELAB(inputRep);
//            currentPalette = RGBPaletteToLab(currentPalette).allKeys;
            
            reduceBlock(inputRep, CGRectMake(0, 0, width, height), currentPalette);
            
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
//                    ditherBlock(inputRep, block, colors);
                    if(verbose > 1) printf("Block reduced to %lu colors. \n", colors.count);
                }
                else
                {
                    if(verbose > 2) printf("Block %d,%d contains less than %d colors (%lu).\n", x, y, maxColors, (unsigned long)activeColors.count);
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

#pragma mark Color reduction

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
            ///NSLog(@"%.0f, %.0f, %.0f", 255*color.redComponent, 255 *color.greenComponent, 255* color.blueComponent);
                
            
            NSColor *matchedColor = MatchColor(color, palette);
            [image setColor:matchedColor atX:x y:y];
        }
    }
}



#pragma mark Color matching
NSColor* MatchColor(NSColor* input, NSArray* palette)
{
    NSColor *output =  nil; // [NSColor whiteColor];
//    NSMutableArray<NSColor *> *candidates = [[NSMutableArray<NSColor*> alloc ] init];
    float delta = 255*255 + 255*255 + 255*255; //furthest distance posible
    
    for (NSColor *color in palette) {
        
        float dist = GetDistanceBetweenColoursWeighted(color, input); // GetDistanceBetweenColours(color, input);
        if (dist <= delta)
        {
            delta = dist;
//            [candidates addObject:color];
            output = color;
        }
    }
   return output;
}

float GetDistanceBetweenColours(NSColor* a, NSColor* b)
{
    
    float dR = ( a.redComponent * 255 - b.redComponent * 255 );
    float dG = ( a.greenComponent * 255 - b.greenComponent * 255);
    float dB = ( a.blueComponent * 255 - b.blueComponent * 255);

    return  dR * dR + dG * dG + dB * dB;

}

float GetDistanceBetweenColoursWeighted(NSColor *a, NSColor *b)
{
    float d =   pow((b.redComponent *255.0 - a.redComponent *255.0), 2)*0.30
                + pow((b.greenComponent *255.0 - a.greenComponent *255.0), 2)*0.59
                + pow((b.blueComponent *255.0 - a.blueComponent *255.0), 2)*0.11;
    
    return d;
    
}

#pragma mark Image manipulation
NSBitmapImageRep* resizeImage(NSBitmapImageRep* sourceImage, NSSize newSize)
{
    NSImage *tmp = [[NSImage alloc] init];
    [tmp addRepresentation:sourceImage];
    if (! tmp.isValid) return nil;

//    printf("Colorspace: %s\n", sourceImage.colorSpaceName.UTF8String);
    
    NSBitmapImageRep *outputRep = [[NSBitmapImageRep alloc]
              initWithBitmapDataPlanes:NULL
                            pixelsWide:newSize.width
                            pixelsHigh:newSize.height
                         bitsPerSample: 8
                       samplesPerPixel:4
                              hasAlpha:YES
                              isPlanar:NO
                        colorSpaceName:sourceImage.colorSpaceName
                           bytesPerRow:0
                          bitsPerPixel:0];
    outputRep.size = newSize;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:outputRep]];
    [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationNone];
    
    
    [tmp drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height) fromRect:NSZeroRect operation: NSCompositingOperationCopy  fraction:1.0];
    
    
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
                        colorSpaceName:sourceImage.colorSpaceName
                           bytesPerRow:0
                          bitsPerPixel:0];
    outputRep.size = cropArea.size;

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:outputRep]];
    [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationNone];
    
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




#pragma mark Palettes
void exportPalette(NSArray<NSColor *>*palette,  NSString* outFile)
{
    NSImage *tmp = [[NSImage alloc] initWithSize:NSMakeSize(200, palette.count*20)];

    NSMutableString *colors = [[NSMutableString alloc] init];
    [tmp lockFocus];
    long i = (palette.count*20) - 20;
    for(NSColor *color in palette)
    {
        [color set];
        [NSBezierPath fillRect:NSMakeRect(0, i, 200, 20)];
        i-=20;
        [colors appendFormat:@"%0.f, %0.f, %0.f\n", color.redComponent*255, color.greenComponent*255, color.blueComponent*255];
        //[colors appendFormat:@"[NSColor colorWithCalibratedRed: %0.2f green:%0.2f blue:%0.2f alpha:1],\n", color.redComponent, color.greenComponent, color.blueComponent];
    }
    [tmp unlockFocus];
    
    NSData *data = [tmp TIFFRepresentation];
    NSError* err;
    [data writeToFile: [[outFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"tiff"]  options:NSDataWritingAtomic error:&err];
    [colors writeToFile:[[outFile stringByDeletingPathExtension] stringByAppendingPathExtension:@"pal"] atomically:YES encoding:NSASCIIStringEncoding error:&err];
    if(err)
        printf("An error occurend: %s", [err.description cStringUsingEncoding:NSASCIIStringEncoding]);
    else
        printf("All done\n");
    
}

NSArray<NSColor*>* parsePaletteFrom(NSString *paletteFile)
{
    NSError *error;
    NSString* fileContents =[NSString stringWithContentsOfFile:paletteFile encoding:NSUTF8StringEncoding error:&error];
    
    if(error)
    {
        printf("Could not load palette. Reverting to default C64 palette.\n");
        return getC64Palette();
    }
    
    NSMutableArray<NSColor*>* palette = [[NSMutableArray<NSColor*> alloc] init];
    
    NSArray* rows = [fileContents componentsSeparatedByString:@"\r"];
    
    
    if(rows.count == 1)
        rows = [fileContents componentsSeparatedByString:@"\n"];
            if(rows.count == 1)
                rows = [fileContents componentsSeparatedByString:@"\r\n"];
    
    for (NSString *row in rows){
        
        //Handle comments #
        NSRange comment = [row rangeOfString:@"#"];
        NSString *line = row;
        if(comment.length > 0)
            line = [line substringToIndex:comment.location];
        
        
        NSArray* columns = [line componentsSeparatedByString:@","];
        if(columns.count != 3)
        {
            continue;;
        }
        
        [palette addObject: [NSColor colorWithCalibratedRed:[columns[0] floatValue] /255.0 green:[columns[1] floatValue] /255.0 blue:[columns[2] floatValue]/255.0 alpha:1.0] ];
        
    }
    
    return palette;
}

NSArray<NSColor*>* getC64Palette(void)
{
    
    return @[
        [NSColor colorWithCalibratedRed: 0.00 green: 0.00 blue: 0.00 alpha:1],               //0: black
        [NSColor colorWithCalibratedRed: 1.00 green: 1.00 blue: 1.00 alpha:1],               //1: white
        [NSColor colorWithCalibratedRed: 0.53 green: 0.00 blue: 0.00 alpha:1],               //2: red
        [NSColor colorWithCalibratedRed: 0.66 green: 1.00 blue: 0.93 alpha:1],               //3: Cyan
        [NSColor colorWithCalibratedRed: 204./255. green:68./255. blue:204./255. alpha:1],   //4: Purple
        [NSColor colorWithCalibratedRed: 0.00 green:204./255. blue:85./255. alpha:1],        //5: Green
        [NSColor colorWithCalibratedRed: 0.00 green:0.00 blue:170./255. alpha:1],            //6: Blue
        [NSColor colorWithCalibratedRed: 238./255. green:238./255. blue:119./255. alpha:1],  //7: Yellow
        [NSColor colorWithCalibratedRed: 221./255. green:136./255. blue:85./255. alpha:1],   //8: Orange
        [NSColor colorWithCalibratedRed: 102./255. green:68./255. blue:0 alpha:1],           //9: Brown
        [NSColor colorWithCalibratedRed: 255./255. green:119./255. blue:119./255. alpha:1],  //10: Light red
        [NSColor colorWithCalibratedRed: 51./255. green:51./255. blue:51./255. alpha:1],     //11: Dark grey / Grey 1./255
        [NSColor colorWithCalibratedRed: 119./255. green:119./255. blue:119./255. alpha:1],  //12: Grey 2
        [NSColor colorWithCalibratedRed: 170./255. green:1 blue:102./255. alpha:1],          //13: Light green
        [NSColor colorWithCalibratedRed: 0.00 green:136./255. blue:1.00 alpha:1],            //14: Light blue
        [NSColor colorWithCalibratedRed: 187./255. green:187./255. blue:187./255. alpha:1]   //15: Light grey / Grey 3
    
    
];
}


NSArray<NSColor*>* getColodorePalette(void)
{
    
    return @[
        [NSColor colorWithCalibratedRed: 0 green: 0 blue:0  alpha: 1.0],                   // black
        [NSColor colorWithCalibratedRed: 1 green: 1 blue:1  alpha: 1.0],                 // white
        [NSColor colorWithCalibratedRed: 0.505882 green: 0.2 blue:0.219608  alpha: 1.0],        // red
        [NSColor colorWithCalibratedRed: 0.458824 green: 0.807843 blue:0.784314  alpha: 1.0],         // cyan
        [NSColor colorWithCalibratedRed: 0.556863 green: 0.235294 blue:0.592157  alpha: 1.0],         // purple
        [NSColor colorWithCalibratedRed: 0.337255 green: 0.67451 blue:0.301961  alpha: 1.0],          // green
        [NSColor colorWithCalibratedRed: 0.180392 green: 0.172549 blue:0.607843  alpha: 1.0],          // blue
        [NSColor colorWithCalibratedRed: 0.929412 green: 0.941176 blue:0.443137  alpha: 1.0],         // yellow
        [NSColor colorWithCalibratedRed: 0.556863 green: 0.313725 blue:0.160784  alpha: 1.0],          // orange
        [NSColor colorWithCalibratedRed: 0.333333 green: 0.219608 blue:0  alpha: 1.0],              // brown
        [NSColor colorWithCalibratedRed: 0.768627 green: 0.423529 blue:0.443137  alpha: 1.0],         // light red
        [NSColor colorWithCalibratedRed: 0.290196 green: 0.290196 blue:0.290196  alpha: 1.0],          // dark
        [NSColor colorWithCalibratedRed: 0.482353 green: 0.482353 blue:0.482353  alpha: 1.0],         // medium gray
        [NSColor colorWithCalibratedRed: 0.662745 green: 1 blue:0.623529  alpha: 1.0],             // light green
        [NSColor colorWithCalibratedRed: 0.439216 green: 0.431373 blue:0.921569  alpha: 1.0],         // light blue
        [NSColor colorWithCalibratedRed: 0.698039 green: 0.698039 blue:0.698039  alpha: 1.0]          //light gray
    ];
}

NSArray<NSColor*>* getPeptoPalette(void)
{
    
    return @[
        [NSColor colorWithCalibratedRed: 0 green: 0 blue:0  alpha: 1.0],                   // black
        [NSColor colorWithCalibratedRed: 1 green: 1 blue:1  alpha: 1.0],                 // white
        [NSColor colorWithCalibratedRed: 0.407843 green: 0.215686 blue:0.168627  alpha: 1.0],          // red
        [NSColor colorWithCalibratedRed: 0.439216 green: 0.643137 blue:0.698039  alpha: 1.0],         // cyan
        [NSColor colorWithCalibratedRed: 0.435294 green: 0.239216 blue:0.52549  alpha: 1.0],         // purple
        [NSColor colorWithCalibratedRed: 0.345098 green: 0.552941 blue:0.262745  alpha: 1.0],          // green
        [NSColor colorWithCalibratedRed: 0.207843 green: 0.156863 blue:0.47451  alpha: 1.0],          // blue
        [NSColor colorWithCalibratedRed: 0.721569 green: 0.780392 blue:0.435294  alpha: 1.0],         // yellow
        [NSColor colorWithCalibratedRed: 0.435294 green: 0.309804 blue:0.145098  alpha: 1.0],          // orange
        [NSColor colorWithCalibratedRed: 0.262745 green: 0.223529 blue:0  alpha: 1.0],              // brown
        [NSColor colorWithCalibratedRed: 0.603922 green: 0.403922 blue:0.34902  alpha: 1.0],         // light red
        [NSColor colorWithCalibratedRed: 0.266667 green: 0.266667 blue:0.266667  alpha: 1.0],          // dark
        [NSColor colorWithCalibratedRed: 0.423529 green: 0.423529 blue:0.423529  alpha: 1.0],         // medium gray
        [NSColor colorWithCalibratedRed: 0.603922 green: 0.823529 blue:0.517647  alpha: 1.0],         // light green
        [NSColor colorWithCalibratedRed: 0.423529 green: 0.368627 blue:0.709804  alpha: 1.0],         // light blue
        [NSColor colorWithCalibratedRed: 0.584314 green: 0.584314 blue:0.584314  alpha: 1.0]         //light gray
    ];
}

NSArray<NSColor*>* getDeekayPalette(void)
{
    
    return @[
        [NSColor colorWithCalibratedRed: 0 green: 0 blue:0  alpha: 1.0],                  // black
        [NSColor colorWithCalibratedRed: 1 green: 1 blue:1  alpha: 1.0],                 // white
        [NSColor colorWithCalibratedRed: 0.533333 green: 0.12549 blue:0  alpha: 1.0],              // red
        [NSColor colorWithCalibratedRed: 0.407843 green: 0.815686 blue:0.658824  alpha: 1.0],         // cyan
        [NSColor colorWithCalibratedRed: 0.658824 green: 0.219608 blue:0.627451  alpha: 1.0],         // purple
        [NSColor colorWithCalibratedRed: 0.313725 green: 0.721569 blue:0.262745  alpha: 1.0],          // green
        [NSColor colorWithCalibratedRed: 0.0941176 green: 0.0627451 blue:0.564706  alpha: 1.0],          // blue
        [NSColor colorWithCalibratedRed: 0.941176 green: 0.909804 blue:0.345098  alpha: 1.0],         // yellow
        [NSColor colorWithCalibratedRed: 0.627451 green: 0.282353 blue:0  alpha: 1.0],              // orange
        [NSColor colorWithCalibratedRed: 0.278431 green: 0.168627 blue:0.105882  alpha: 1.0],          // brown
        [NSColor colorWithCalibratedRed: 0.784314 green: 0.470588 blue:0.439216  alpha: 1.0],         // light red
        [NSColor colorWithCalibratedRed: 0.282353 green: 0.282353 blue:0.282353  alpha: 1.0],          // dark
        [NSColor colorWithCalibratedRed: 0.501961 green: 0.501961 blue:0.501961  alpha: 1.0],         // medium gray
        [NSColor colorWithCalibratedRed: 0.596078 green: 1 blue:0.596078  alpha: 1.0],             // light green
        [NSColor colorWithCalibratedRed: 0.313725 green: 0.564706 blue:0.815686  alpha: 1.0],         // light blue
        [NSColor colorWithCalibratedRed: 0.721569 green: 0.721569 blue:0.721569  alpha: 1.0]         // light gray
    ];
}

NSArray<NSColor*>* getPALette(void)
{
    
    return @[
        [NSColor colorWithCalibratedRed: 0 green: 0 blue:0  alpha: 1.0],                   // black
        [NSColor colorWithCalibratedRed: 1 green: 1 blue:1  alpha: 1.0],                 // white
        [NSColor colorWithCalibratedRed: 0.54902 green: 0.196078 blue:0.239216  alpha: 1.0],          // red
        [NSColor colorWithCalibratedRed: 0.4 green: 0.74902 blue:0.701961  alpha: 1.0],             // cyan
        [NSColor colorWithCalibratedRed: 0.556863 green: 0.211765 blue:0.631373  alpha: 1.0],         // purple
        [NSColor colorWithCalibratedRed: 0.290196 green: 0.65098 blue:0.282353  alpha: 1.0],          // green
        [NSColor colorWithCalibratedRed: 0.196078 green: 0.176471 blue:0.670588  alpha: 1.0],          // blue
        [NSColor colorWithCalibratedRed: 0.803922 green: 0.823529 blue:0.337255  alpha: 1.0],         // yellow
        [NSColor colorWithCalibratedRed: 0.560784 green: 0.313725 blue:0.101961  alpha: 1.0],          // orange
        [NSColor colorWithCalibratedRed: 0.32549 green: 0.239216 blue:0.00392157  alpha: 1.0],          // brown
        [NSColor colorWithCalibratedRed: 0.741176 green: 0.388235 blue:0.431373  alpha: 1.0],         // light red
        [NSColor colorWithCalibratedRed: 0.305882 green: 0.305882 blue:0.305882  alpha: 1.0],          // dark
        [NSColor colorWithCalibratedRed: 0.462745 green: 0.462745 blue:0.462745  alpha: 1.0],         // medium gray
        [NSColor colorWithCalibratedRed: 0.54902 green: 0.913725 blue:0.545098  alpha: 1.0],         // light green
        [NSColor colorWithCalibratedRed: 0.419608 green: 0.4 blue:0.894118  alpha: 1.0],         // light blue
        [NSColor colorWithCalibratedRed: 0.639216 green: 0.639216 blue:0.639216  alpha: 1.0]         // light gray
    ];
}

NSArray<NSColor*>* getSimplePalette(void)
{
    return @[
        [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1],                                  //0: black
        [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1],                                  //1: white
        [NSColor colorWithCalibratedRed: 0.407843 green: 0.215686 blue:0.168627  alpha: 1.0],       //2: red
        [NSColor colorWithCalibratedRed: 0.0941176 green: 0.0627451 blue:0.564706  alpha: 1.0],     //6: Blue
        [NSColor colorWithCalibratedRed: 0.54902 green: 0.913725 blue:0.545098  alpha: 1.0]         //13: Light green
    ];
}


#pragma mark Unused LAB color conversion
NSColor* RGBToLab(NSColor *color) { // CGFloat r, CGFloat g, CGFloat b, CGFloat *L, CGFloat *a, CGFloat *b) {
    
    CGFloat r = color.redComponent;
    CGFloat g = color.greenComponent;
    CGFloat b = color.blueComponent;
    
    CGFloat X, Y, Z;
    CGFloat ref_X =  95.047;
    CGFloat ref_Y = 100.000;
    CGFloat ref_Z = 108.883;

    // Convert sRGB to XYZ
    r = (r > 0.04045) ? pow((r + 0.055) / 1.055, 2.4) : r / 12.92;
    g = (g > 0.04045) ? pow((g + 0.055) / 1.055, 2.4) : g / 12.92;
    b = (b > 0.04045) ? pow((b + 0.055) / 1.055, 2.4) : b / 12.92;

    r *= 100.0;
    g *= 100.0;
    b *= 100.0;

    X = r * 0.4124564 + g * 0.3575761 + b * 0.1804375;
    Y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750;
    Z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041;

    // Normalize for reference white point
    X /= ref_X;
    Y /= ref_Y;
    Z /= ref_Z;

    // Convert XYZ to Lab
    X = (X > 0.008856) ? pow(X, 1.0 / 3.0) : (903.3 * X + 16.0) / 116.0;
    Y = (Y > 0.008856) ? pow(Y, 1.0 / 3.0) : (903.3 * Y + 16.0) / 116.0;
    Z = (Z > 0.008856) ? pow(Z, 1.0 / 3.0) : (903.3 * Z + 16.0) / 116.0;

    CGFloat xL = fmax(0.0, 116.0 * Y - 16.0);
    CGFloat xa = (X - Y) * 500.0;
    CGFloat xb = (Y - Z) * 200.0;
    
    float comps[] = {xL, xa, xb};
    
    return [NSColor colorWithColorSpace: [[NSColorSpace availableColorSpacesWithModel:NSColorSpaceModelLAB] firstObject]  components: comps count:3];
}

void RGBToLab2(CGFloat r, CGFloat g, CGFloat b, CGFloat *lL, CGFloat *la, CGFloat *lb) {
    CGFloat X = 0.4124564 * r + 0.3575761 * g + 0.1804375 * b;
    CGFloat Y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    CGFloat Z = 0.0193339 * r + 0.1191920 * g + 0.9503041 * b;

    // Normalize to the reference white point (D65)
    X /= 95.047;
    Y /= 100.000;
    Z /= 108.883;

    // Apply non-linear transfer function
    X = (X > 0.008856) ? pow(X, 1.0 / 3.0) : (903.3 * X + 16.0) / 116.0;
    Y = (Y > 0.008856) ? pow(Y, 1.0 / 3.0) : (903.3 * Y + 16.0) / 116.0;
    Z = (Z > 0.008856) ? pow(Z, 1.0 / 3.0) : (903.3 * Z + 16.0) / 116.0;

    *lL = fmax(0.0, 116.0 * Y - 16.0);
    *la = (X - Y) * 500.0;
    *lb = (Y - Z) * 200.0;
}

NSDictionary<NSColor*, NSColor*>* RGBPaletteToLab(NSArray<NSColor*>* palette)
{
    NSMutableDictionary<NSColor*, NSColor*> *LabRGBPalette = [[NSMutableDictionary alloc] init];
    
    for(NSColor *rgb in palette)
    {
        [LabRGBPalette setObject:RGBToLab(rgb) forKey:rgb];
    }
    
    return [NSDictionary dictionaryWithDictionary:LabRGBPalette];
    
}


void convertImageRepToCIELAB(NSBitmapImageRep* imageRep)
{

    // Step 2: Convert pixel data to CIELAB
    NSInteger width = [imageRep pixelsWide];
    NSInteger height = [imageRep pixelsHigh];
    NSInteger bytesPerPixel = [imageRep bitsPerPixel] / 8;
    

    for (NSInteger y = 0; y < height; y++) {
        for (NSInteger x = 0; x < width; x++) {
            NSInteger pixelIndex = y * width + x;
            NSUInteger offset = pixelIndex * bytesPerPixel;

            // Extract RGB values from the pixel data
            CGFloat red = imageRep.bitmapData[offset] / 255.0;
            CGFloat green = imageRep.bitmapData[offset + 1] / 255.0;
            CGFloat blue = imageRep.bitmapData[offset + 2] / 255.0;

            // Convert RGB to CIELAB using the CIE 1976 (L*, a*, b*) color space
            CGFloat L, a, b;
            RGBToLab2(red, green, blue, &L, &a, &b);
            /*
            NSColor *lab = RGBToLab( [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0] );
            CGFloat L = lab.redComponent;
            CGFloat a = lab.greenComponent;
            CGFloat b = lab.blueComponent;
            */
            // Store the CIELAB values back into the pixel data
            imageRep.bitmapData[offset] = L * 255.0;
            imageRep.bitmapData[offset + 1] = (a + 128.0) * 255.0;
            imageRep.bitmapData[offset + 2] = (b + 128.0) * 255.0;
        }
    }
}

#pragma mark Help
void printHelp(void)
{
    
    //i:o:v:hdrfc:a:ep:P:
    
    printf("Usage: c64optimizer -i <file> [-ovhdrfcaepP].\n");
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
    printf("\t-e\tExport palette from input image.\n");
    printf("\t-p\tImport palette from palette file (e.g '-p input.pal').\n");
    printf("\t-P\tUse predefined palette (0-4, default is Colorado).\n");
    printf("\t\t\t0 = Direct C64.\n");
    printf("\t\t\t1 = Colorado.\n");
    printf("\t\t\t2 = Pepto.\n");
    printf("\t\t\t3 = Deekay.\n");
    printf("\t\t\t4 = PALette.\n");
    printf("\t-v\tBe verbose about the process (0-2).\n");
    printf("\t-h\tDisplay this help.\n");
}



