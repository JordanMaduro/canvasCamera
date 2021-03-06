//
//  CanvasCamera.js
//  PhoneGap iOS Cordova Plugin to capture Camera streaming into a HTML5 Canvas or an IMG tag.
//
//  Created by Diego Araos <d@wehack.it> on 12/29/12.
//
//  MIT License

#import "CanvasCamera.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>

typedef enum {
    DestinationTypeDataURL = 0,
    DestinationTypeFileURI = 1
}DestinationType;

typedef enum {
    EncodingTypeJPEG = 0,
    EncodingTypePNG = 1
}EncodingType;

#define DATETIME_FORMAT @"yyyy-MM-dd HH:mm:ss"
#define DATE_FORMAT @"yyyy-MM-dd"

// parameter
#define kQualityKey         @"quality"
#define kCompression        @"compression"
#define kDestinationTypeKey @"destinationType"
#define kEncodingTypeKey    @"encodingType"


#define kSaveToPhotoAlbumKey     @"saveToPhotoAlbum"
#define kCorrectOrientationKey         @"correctOrientation"

#define kWidthKey        @"width"
#define kHeightKey       @"height"

@interface CanvasCamera () {
    dispatch_queue_t queue;
    BOOL bIsStarted;
    
    // parameters
    AVCaptureFlashMode          _flashMode;
    AVCaptureDevicePosition     _devicePosition;
    
    NSDictionary *_advancedOptions;
    
    // options
    int _quality;
    int _compression;
    float _zoomRatio;
    DestinationType _destType;
    //BOOL _allowEdit;
    EncodingType _encodeType;
    BOOL _saveToPhotoAlbum;
    BOOL _correctOrientation;
    
    int _width;
    int _height;
}

@end

@implementation CanvasCamera

#pragma mark - Interfaces

- (void)startCapture:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    // check already started
    if (self.session && bIsStarted)
    {
        // failure callback
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Already started"];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];

        return;
    }
    
    // init parameters - default values
    _quality = 85;
    _compression = 69;
    _zoomRatio = 1;
    _destType = DestinationTypeFileURI;
    _encodeType = EncodingTypeJPEG;
    _width = 640;
    _height = 480;
    _saveToPhotoAlbum = NO;
    _correctOrientation = YES;
    
    NSDictionary * defaultAdvanced = @{
        @"cameraWidth":@704.0,
        @"cameraHeight":@576.0,
        @"preset": @2
    };
    
    
    // parse options
    if ([command.arguments count] > 0)
    {
        NSDictionary *jsonData = [command.arguments objectAtIndex:0];
        [self getOptions:jsonData];
        
        [self getAdvancedOptions:([jsonData objectForKey:@"advanced"] ? jsonData[@"advanced"] : @{}) : defaultAdvanced];
        
    } else {
        [self getAdvancedOptions:@{} :defaultAdvanced];
    
    }
   
    
    
    // add support for options (fps, capture quality, capture format, etc.)
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetPhoto; //AVCaptureSessionPreset352x288; //AVCaptureSessionPresetLow; //AVCaptureSessionPresetPhoto;
   

        switch ([_advancedOptions[@"preset"] intValue]) {
            case 1:
                self.session.sessionPreset = AVCaptureSessionPreset352x288;
                break;
            case 2:
                self.session.sessionPreset = AVCaptureSessionPreset640x480;
                break;
            case 3:
                self.session.sessionPreset = AVCaptureSessionPreset1280x720;
                break;
            case 4:
                self.session.sessionPreset = AVCaptureSessionPreset1920x1080;
                break;
            case 5:
                self.session.sessionPreset = AVCaptureSessionPresetPhoto;
                break;
            case 6:
                self.session.sessionPreset = AVCaptureSessionPresetLow;
                break;
            case 7:
                self.session.sessionPreset = AVCaptureSessionPresetMedium;
                break;
            case 8:
                self.session.sessionPreset = AVCaptureSessionPresetHigh;
                break;
            case 9:
                self.session.sessionPreset = AVCaptureSessionPresetiFrame960x540;
                break;
            case 10:
                self.session.sessionPreset = AVCaptureSessionPresetiFrame1280x720;
                break;
            case 11:
                self.session.sessionPreset = AVCaptureSessionPresetInputPriority;
                break;
            default:
                self.session.sessionPreset = AVCaptureSessionPreset640x480;
                break;
    }
    
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.input = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    

    /*
    for (AVCaptureDeviceFormat *mat in self.device.formats)
    {
        NSLog(@"Format: %@", [mat description]);
        
    }
    NSLog(@"Current Format: %@", [self.device.activeFormat description]);
    
    */
    
 
    self.output = [[AVCaptureVideoDataOutput alloc] init];
    
    self.output.alwaysDiscardsLateVideoFrames = YES;
    

    
    self.output.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG};
    [self.stillImageOutput setOutputSettings:outputSettings];
    
    
    queue = dispatch_queue_create("canvas_camera_queue", NULL);
    
    [self.output setSampleBufferDelegate:(id)self queue:queue];
    
    [self.session addInput:self.input];
    [self.session addOutput:self.output];
    
    // add still image output
    [self.session addOutput:self.stillImageOutput];

    
    [self.session startRunning];
    
    bIsStarted = YES;
    
     if ([self.device lockForConfiguration:nil]){
        //[self.device rampToVideoZoomFactor:2 withRate:0.25];
         //self.device.videoZoomFactor = 2;

        [self.device unlockForConfiguration];
     }
    
    
    // success callback
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
    resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
    [self writeJavascript:resultJS];
}

- (void)stopCapture:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    if (self.session)
    {
        [self.session stopRunning];
        self.session = nil;
        
        bIsStarted = NO;
        
        // success callback
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
        resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
    else
    {
        bIsStarted = NO;
        
        // failure callback
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Already stopped"];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
}


- (void)setZoomRatio:(CDVInvokedUrlCommand *)command
{
    
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    NSString *errMsg = @"";
    BOOL bParsed = NO;
    if (command.arguments.count <= 0)
    {
        bParsed = NO;
        errMsg = @"Please Specify Zoom Ratio!";
    }
    else
    {
        NSString *intZoomRatio = [command.arguments objectAtIndex:0];
        float zoomRatio = [intZoomRatio floatValue];
       // NSLog(@"Requested Zoom %f", zoomRatio);
       // NSLog(@"Max Zoom Factor: %f",self.device.activeFormat.videoMaxZoomFactor);
      //  NSLog(@"Max Zoom Factor Upscale Threshold: %f",self.device.activeFormat.videoZoomFactorUpscaleThreshold);
        if (zoomRatio > self.device.activeFormat.videoZoomFactorUpscaleThreshold)
        {
            //   zoomRatio = self.device.activeFormat.videoZoomFactorUpscaleThreshold;
        }
        
        if (zoomRatio < 1)
        {
            bParsed = NO;
            errMsg = @"Invalid parameter";
        }
        else
        {
            _zoomRatio = zoomRatio;
            bParsed = YES;
        }
    }
    
    
    if (bParsed)
    {
        BOOL bSuccess = NO;
        // check session is started
        if (bIsStarted && self.session)
        {
            if (self.device.activeFormat.videoMaxZoomFactor != 1)
            {
                [self.device lockForConfiguration:nil];
            
                //[self.device rampToVideoZoomFactor:_zoomRatio withRate:4];
                self.device.videoZoomFactor = _zoomRatio;
                
                [self.device unlockForConfiguration];
                
                bSuccess = YES;
            }
            else
            {
                bSuccess = NO;
                errMsg = @"This device cant zoom";
            }
        }
        else
        {
            bSuccess = NO;
            errMsg = @"Session is not started";
        }
        
        if (bSuccess)
        {
            // success callback
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
            //resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
           
          //  resultJS = [self.commandDelegate sendPluginResult:pluginResult callbackId:command.c
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            // [self writeJavascript:resultJS];
          //  [self.commandDelegate evalJs:resultJS];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
            resultJS = [pluginResult toErrorCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
}




- (void)setFlashMode:(CDVInvokedUrlCommand *)command
{
    
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    NSString *errMsg = @"";
    BOOL bParsed = NO;
    if (command.arguments.count <= 0)
    {
        bParsed = NO;
        errMsg = @"Please specify a flash mode";
    }
    else
    {
        NSString *strFlashMode = [command.arguments objectAtIndex:0];
        int flashMode = [strFlashMode integerValue];
        if (flashMode != AVCaptureFlashModeOff
            && flashMode != AVCaptureFlashModeOn
            && flashMode != AVCaptureFlashModeAuto)
        {
            bParsed = NO;
            errMsg = @"Invalid parameter";
        }
        else
        {
            _flashMode = flashMode;
            bParsed = YES;
        }
    }
    
    
    if (bParsed)
    {
        BOOL bSuccess = NO;
        // check session is started
        if (bIsStarted && self.session)
        {
            if ([self.device hasTorch] && [self.device hasFlash])
            {
                [self.device lockForConfiguration:nil];
                if (_flashMode == AVCaptureFlashModeOn)
                {
                    [self.device setTorchMode:AVCaptureTorchModeOn];
                    [self.device setFlashMode:AVCaptureFlashModeOn];
                }
                else if (_flashMode == AVCaptureFlashModeOff)
                {
                    [self.device setTorchMode:AVCaptureTorchModeOff];
                    [self.device setFlashMode:AVCaptureFlashModeOff];
                }
                else if (_flashMode == AVCaptureFlashModeAuto)
                {
                    [self.device setTorchMode:AVCaptureTorchModeAuto];
                    [self.device setFlashMode:AVCaptureFlashModeAuto];
                }
                [self.device unlockForConfiguration];
                
                bSuccess = YES;
            }
            else
            {
                bSuccess = NO;
                errMsg = @"This device has no flash or torch";
            }
        }
        else
        {
            bSuccess = NO;
            errMsg = @"Session is not started";
        }
        
        if (bSuccess)
        {
            // success callback
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
            resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
            resultJS = [pluginResult toErrorCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
}

- (void)setCameraPosition:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult *pluginResult = nil;
    NSString *resultJS = nil;
    
    NSString *errMsg = @"";
    BOOL bParsed = NO;
    if (command.arguments.count <= 0)
    {
        bParsed = NO;
        errMsg = @"Please specify a device position";
    }
    else
    {
        NSString *strDevicePosition = [command.arguments objectAtIndex:0];
        int devicePosition = [strDevicePosition integerValue];
        if (devicePosition != AVCaptureFlashModeOff
            && devicePosition != AVCaptureFlashModeOn
            && devicePosition != AVCaptureFlashModeAuto)
        {
            bParsed = NO;
            errMsg = @"Invalid parameter";
        }
        else
        {
            _devicePosition = devicePosition;
            bParsed = YES;
        }
    }
    
    if (bParsed)
    {
        //Change camera source
        if(self.session)
        {
            //Remove existing input
            AVCaptureInput* currentCameraInput = [self.session.inputs objectAtIndex:0];
            if(((AVCaptureDeviceInput*)currentCameraInput).device.position != _devicePosition)
            {
                //Indicate that some changes will be made to the session
                [self.session beginConfiguration];
                
                //Remove existing input
                AVCaptureInput* currentCameraInput = [self.session.inputs objectAtIndex:0];
                [self.session removeInput:currentCameraInput];
                
                //Get new input
                AVCaptureDevice *newCamera = nil;
                   
                newCamera = [self cameraWithPosition:_devicePosition];
                
                //Add input to session
                AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newCamera error:nil];
                [self.session addInput:newVideoInput];
                
                //Commit all the configuration changes at once
                [self.session commitConfiguration];
                
                // success callback
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
                resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
                [self writeJavascript:resultJS];
            }
            else
            {
                // success callback
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
                resultJS = [pluginResult toSuccessCallbackString:command.callbackId];
                [self writeJavascript:resultJS];
            }
            
            
        }
        else
        {
            errMsg = @"Capture stopped";
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
            resultJS = [pluginResult toErrorCallbackString:command.callbackId];
            [self writeJavascript:resultJS];
        }
        
        
    }
    else
    {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
        resultJS = [pluginResult toErrorCallbackString:command.callbackId];
        [self writeJavascript:resultJS];
    }
}

- (void)captureImage:(CDVInvokedUrlCommand *)command
{
    __block CDVPluginResult *pluginResult = nil;
    __block NSString *resultJS = nil;
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    // Find out the current orientation and tell the still image output.
	AVCaptureConnection *stillImageConnection = videoConnection;//[self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
	UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
	AVCaptureVideoOrientation avcaptureOrientation = [self avOrientationForDeviceOrientation:curDeviceOrientation];
	[stillImageConnection setVideoOrientation:avcaptureOrientation];
    
    // set the appropriate pixel format / image type output setting depending on if we'll need an uncompressed image for
    // the possiblity of drawing the red square over top or if we're just writing a jpeg to the camera roll which is the trival case
    [self.stillImageOutput setOutputSettings:[NSDictionary dictionaryWithObject:AVVideoCodecJPEG
                                                                         forKey:AVVideoCodecKey]];
	
	[self.stillImageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection
       completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
           if (error) {
               //[self displayErrorOnMainQueue:error withMessage:@"Take picture failed"];
           }
           else {
#if 0
               // trivial simple JPEG case
               NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
               CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                           imageDataSampleBuffer,
                                                                           kCMAttachmentMode_ShouldPropagate);
               ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
               [library writeImageDataToSavedPhotosAlbum:jpegData metadata:(__bridge id)attachments completionBlock:^(NSURL *assetURL, NSError *error) {
                   if (error) {
                       [self.commandDelegate runInBackground:^{
                           //[self displayErrorOnMainQueue:error withMessage:@"Save to camera roll failed"];
                           pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Writing data to asset failed :%@", [error localizedDescription]]];
                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                       }];
                   }
                   else
                   {
                       [self.commandDelegate runInBackground:^{
                           // success callback
                           pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@""];
                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                       }];
                   }
               }];
               
               if (attachments)
                   CFRelease(attachments);
               //[library release];
#else
               // when processing an existing frame we want any new frames to be automatically dropped
               // queueing this block to execute on the videoDataOutputQueue serial queue ensures this
               // see the header doc for setSampleBufferDelegate:queue: for more information
               dispatch_sync(queue, ^(void) {
                   
                   NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                   
                   // save image to camera roll
                   if (_saveToPhotoAlbum)
                   {
                       CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault,
                                                                                   imageDataSampleBuffer,
                                                                                   kCMAttachmentMode_ShouldPropagate);
                       [self writeJPGToCameraRoll:jpegData withAttachments:attachments];
                       if (attachments)
                           CFRelease(attachments);
                   }
                   
                   UIImage *srcImg = [UIImage imageWithData:jpegData];
                   UIImage *resizedImg = [CanvasCamera resizeImage:srcImg toSize:CGSizeMake(_width, _height)];
                   
                       
                   BOOL bRet = NO;
                   NSMutableDictionary *dicRet = [[NSMutableDictionary alloc] init];
                   
                   // type
                   NSString *type = (_encodeType == EncodingTypeJPEG)?@"image/jpeg":@"image/png";
                   [dicRet setObject:type forKey:@"type"];
                   
                   // lastModifiedDate
                   NSDate *currDate = [NSDate date];
                   NSString *lastModifiedDate = [CanvasCamera date2str:currDate withFormat:DATETIME_FORMAT];
                   [dicRet setObject:lastModifiedDate forKey:@"lastModifiedDate"];
                   
                   //imageURI
                   NSData *data = nil;
                   if (_encodeType == EncodingTypeJPEG)
                       data = UIImageJPEGRepresentation(resizedImg, (_quality / 100.0));
                   else
                       data = UIImagePNGRepresentation(resizedImg);
                   if (_destType == DestinationTypeFileURI)
                   {
                       // save resized image to app space
                       NSString *path = [CanvasCamera getFilePath:[CanvasCamera GetUUID] ext:(_encodeType == EncodingTypeJPEG)?@"jpg":@"png"];
                       
                       bRet = [self writeData:data toPath:path];
                       
                       [dicRet setObject:path forKey:@"imageURI"];
                   }
                   else
                   {
                       // Convert to Base64 data
                       NSData *base64Data = [data base64EncodedDataWithOptions:0];
                       NSString *strData = [NSString stringWithUTF8String:[base64Data bytes]];
                       
                       [dicRet setObject:strData forKey:@"imageURI"];
                   }
                   
                   // size
                   [dicRet setObject:[NSString stringWithFormat:@"%d", (int)data.length] forKey:@"size"];

                   
                   if (bRet == NO)
                   {
                       [self.commandDelegate runInBackground:^{
                           //[self displayErrorOnMainQueue:error withMessage:@"Save to camera roll failed"];
                           pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Writing data failed"]];
                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                       }];
                   }
                   else
                   {
                       [self.commandDelegate runInBackground:^{
                           // success callback
                           pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dicRet];
                           [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                       }];
                   }
                   
               });
#endif
           }
       }
     ];
}


#pragma mark - capture delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    @autoreleasepool {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer,0);
        uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        
        CGContextRef smallContext = CGBitmapContextCreate(nil, 704, 576, 8, 704*4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        
     
        
        // If image width is too large
        
        //
        
        //CGContextScaleCTM(newContext, (1/(width/704)), (1/(height/576)));
        CGContextScaleCTM(newContext, 0.5, 0.5);
    //    CGContextScaleCTM(smallContext, 0.5, 0.5);
       
        
        
        
     //   NSLog(@"Scale Factors %@,%@",(width/(width/1024)), (height/(height/1024)));
       // CGContextSetInterpolationQuality(newContext, kCGInterpolationHigh);
        //CGContextSetInterpolationQuality(smallContext, kCGInterpolationHigh);
        
    
       // CGImageRef newImage = CGBitmapContextCreateImage(newContext);
        
        
        
        CGImageRef newImage2 = CGBitmapContextCreateImage(newContext);
        
        CGContextDrawImage(smallContext, CGRectMake(0, 0, 704, 576), newImage2);
        CGImageRef newImage = CGBitmapContextCreateImage(smallContext);
        
       // CGContextDrawImage(smallContext, CGRectMake(0, 0, s_width, s_height), newImage2);
        //CGImageRef newImage = CGBitmapContextCreateImage(smallContext);
    
        
       // UIImage *image = [UIImage imageWithCGImage:CGImageCreateWithImageInRect(newImage, CGRectMake(0,0,1024, 768))];
        
        CGContextRelease(newContext);
        CGContextRelease(smallContext);
        CGColorSpaceRelease(colorSpace);
      
        
        UIImage *image = [UIImage imageWithCGImage:newImage];

        
        // resize image
        // resize image
        //image = [CanvasCamera resizeImage:image toSize:CGSizeMake([_advancedOptions[@"cameraWidth"] floatValue], [_advancedOptions[@"cameraHeight"] floatValue])];
       
       // CGRect apple = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(1280, 720), CGRectMake(0,0,1024, 768));
        
        
        
      //  image = [CanvasCamera resizeImage:image toSize:CGSizeMake(width/4, height/4)];
        
        //image = [CanvasCamera resizeImage:image toRect:apple];
        //image = [CanvasCamera scaleImageToSize:image toSize:CGSizeMake(1080, 1080)];
        
       
       
        NSData *imageData = UIImageJPEGRepresentation(image, (_compression / 100.0));
#if 0
        //NSString *encodedString = [imageData base64Encoding];
        NSString *encodedString = [imageData base64EncodedStringWithOptions:0];

        NSString *javascript = @"CanvasCamera.capture('data:image/jpeg;base64,";

        javascript = [NSString stringWithFormat:@"%@%@%@", javascript, encodedString, @"');"];

        [self.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:javascript waitUntilDone:YES];
#else
        dispatch_async(dispatch_get_main_queue(), ^{
            @autoreleasepool {
                
                // Get a file path to save the JPEG
                static int i = 0;
                i++;
                
                NSString *imagePath = [CanvasCamera getFilePath:[NSString stringWithFormat:@"uuid%d", i] ext:@"jpg"];
                
                if (i > 20)
                {
                    NSString *prevPath = [CanvasCamera getFilePath:[NSString stringWithFormat:@"uuid%d", i-10] ext:@"jpg"];
                    NSError *error = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:prevPath error:&error];
                }
                
                // Write the data to the file
                [imageData writeToFile:imagePath atomically:YES];
                
                imagePath = [NSString stringWithFormat:@"file://%@", imagePath];
                
                //[retValues setObject:strUrl forKey:kDataKey];
                //[retValues setObject:imagePath forKey:kDataKey];

                NSString *javascript = [NSString stringWithFormat:@"%@%@%@", @"CanvasCamera.capture('", imagePath, @"');"];
                [self.webView stringByEvaluatingJavaScriptFromString:javascript];
            }
        });
#endif
        
        CGImageRelease(newImage);
       CGImageRelease(newImage2);
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    }
}

#pragma mark - Utilities


// utility routing used during image capture to set up capture orientation
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
	AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
	if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
		result = AVCaptureVideoOrientationLandscapeRight;
	else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
		result = AVCaptureVideoOrientationLandscapeLeft;
	return result;
}


// Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
            return device;
    }
    return nil;
}

// utility routine to create a new image with specified size(_width, _height)
// and return the new composited image which can be saved to the camera roll
- (CGImageRef)createResizedCGImage:(CGImageRef)srcImage withSize:(CGSize)size
{
	CGImageRef returnImage = NULL;
    CGRect newImageRect = CGRectMake(0, 0, size.width, size.height);
	CGContextRef bitmapContext = (CGContextRef)CreateCGBitmapContextForSize(size);
	CGContextClearRect(bitmapContext, newImageRect);
	CGContextDrawImage(bitmapContext, newImageRect, srcImage);
    
	returnImage = CGBitmapContextCreateImage(bitmapContext);
	CGContextRelease (bitmapContext);
	
	return returnImage;
}


+ (NSString *)GetUUID
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    CFRelease(theUUID);
    return (__bridge NSString *)string;
}

+ (NSString *)getFilePath:(NSString *)uuidString ext:(NSString *)ext
{
    NSString *documentsDirectory = [CanvasCamera getAppPath];
    NSString* filename = [NSString stringWithFormat:@"%@.%@", uuidString, ext];
    NSString* imagePath = [documentsDirectory stringByAppendingPathComponent:filename];
    return imagePath;
}

+ (NSString *)getAppPath
{
    // Get a file path to save the JPEG
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    NSString *dataPath = [documentsDirectory stringByAppendingPathComponent:@"/tmp"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:dataPath])
    {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:dataPath withIntermediateDirectories:NO attributes:nil error:&error]; //Create folder
        if (error) {
            NSLog(@"error occurred in create tmp folder : %@", [error localizedDescription]);
        }
    }
    return dataPath;
}


- (void) getAdvancedOptions: (NSDictionary *) jsonData :(NSDictionary *) mapping;
{
    NSLog(@"Does not workd ");
    //if (![jsonData isKindOfClass:[NSDictionary class]] || ![jsonData isKindOfClass:[NSDictionary class]]) {
      //  return;
    //}
    
    NSMutableDictionary *advancedOptions = [[NSMutableDictionary alloc] init];
    
    for (NSString *option in mapping) {
        if (jsonData[option]) {
            [advancedOptions setObject:jsonData[option] forKey:option];
        } else {
            [advancedOptions setObject:mapping[option] forKey:option];
        }
    }
    
    _advancedOptions = [NSDictionary dictionaryWithDictionary:advancedOptions];
}


/**
 * parse options parameter and set it to local variables
 *
 */
- (void)getOptions: (NSDictionary *)jsonData
{
    if (![jsonData isKindOfClass:[NSDictionary class]])
        return;
    
    // get parameters from argument.
    
    
    // quaility
    NSString *obj = [jsonData objectForKey:kQualityKey];
    if (obj != nil)
        _quality = [obj intValue];
    
    _advancedOptions = [NSDictionary dictionaryWithDictionary:[jsonData objectForKey:@"advanced"]];
    
    NSLog(@"Hello Color: %@", _advancedOptions);
    
    
    // compression
    obj = [jsonData objectForKey:kCompression];
    if (obj != nil)
        _compression = [obj intValue];
    
    // destination type
    obj = [jsonData objectForKey:kDestinationTypeKey];
    if (obj != nil)
    {
        int destinationType = [obj intValue];
        NSLog(@"destinationType = %d", destinationType);
        _destType = destinationType;
    }
    
    // encoding type
    obj = [jsonData objectForKey:kEncodingTypeKey];
    if (obj != nil)
    {
        int encodingType = [obj intValue];
        _encodeType = encodingType;
    }
    
    // width
    obj = [jsonData objectForKey:kWidthKey];
    if (obj != nil)
    {
        _width = [obj intValue];
    }
    
    // height
    obj = [jsonData objectForKey:kHeightKey];
    if (obj != nil)
    {
        _height = [obj intValue];
    }
    
    // saveToPhotoAlbum
    obj = [jsonData objectForKey:kSaveToPhotoAlbumKey];
    if (obj != nil)
    {
        _saveToPhotoAlbum = [obj boolValue];
    }
    
    // correctOrientation
    obj = [jsonData objectForKey:kCorrectOrientationKey];
    if (obj != nil)
    {
        _correctOrientation = [obj boolValue];
    }
}


+ (NSString *)date2str:(NSDate *)convertDate withFormat:(NSString *)formatString
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:formatString];
    
    return [dateFormatter stringFromDate:convertDate];
}



+ (UIImage *)scaleImageToSize:(UIImage *)image toSize:(CGSize)newSize;
{
    
    CGRect scaledImageRect = CGRectZero;
    
    CGFloat aspectWidth = newSize.width / image.size.width;
    CGFloat aspectHeight = newSize.height / image.size.height;
    CGFloat aspectRatio = MIN ( aspectWidth, aspectHeight );
    
    scaledImageRect.size.width = image.size.width * aspectRatio;
    scaledImageRect.size.height = image.size.height * aspectRatio;
    scaledImageRect.origin.x = (newSize.width - scaledImageRect.size.width) / 2.0f;
    scaledImageRect.origin.y = (newSize.height - scaledImageRect.size.height) / 2.0f;
    
    UIGraphicsBeginImageContextWithOptions( newSize, YES, 1 );
    //[image drawInRect:scaledImageRect];
    [image drawInRect:CGRectMake( (newSize.width - scaledImageRect.size.width) / 2.0f, (newSize.height - scaledImageRect.size.height) / 2.0f, scaledImageRect.size.width, scaledImageRect.size.height)];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
    
    
}

+ (UIImage *)resizeImage:(UIImage *)image toRect:(CGRect)newSize
{
    UIGraphicsBeginImageContext(newSize.size);
    [image drawInRect:newSize];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

// utility routine used after taking a still image to write the resulting image to the camera roll
- (BOOL)writeCGImageToCameraRoll:(CGImageRef)cgImage withMetadata:(NSDictionary *)metadata withQuality:(CGFloat)quality withEncodingType:(EncodingType)encodingType
{
	CFMutableDataRef destinationData = CFDataCreateMutable(kCFAllocatorDefault, 0);
	CGImageDestinationRef destination = nil;
    if (encodingType == EncodingTypeJPEG)
        destination = CGImageDestinationCreateWithData(destinationData,
																		 kUTTypeJPEG,
																		 1,
																		 NULL);
    else
        destination = CGImageDestinationCreateWithData(destinationData,
                                                       kUTTypePNG,
                                                       1,
                                                       NULL);
	BOOL success = (destination != NULL);
	if (!success)
    {
        if (destinationData)
            CFRelease(destinationData);
        return success;
    }
    
	const float JPEGCompQuality = quality; // JPEGHigherQuality (0 ~ 1)
	CFMutableDictionaryRef optionsDict = NULL;
	CFNumberRef qualityNum = NULL;
	
	qualityNum = CFNumberCreate(0, kCFNumberFloatType, &JPEGCompQuality);
	if ( qualityNum ) {
		optionsDict = CFDictionaryCreateMutable(0, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		if ( optionsDict )
			CFDictionarySetValue(optionsDict, kCGImageDestinationLossyCompressionQuality, qualityNum);
		CFRelease( qualityNum );
	}
	
	CGImageDestinationAddImage( destination, cgImage, optionsDict );
	success = CGImageDestinationFinalize( destination );
    
	if ( optionsDict )
		CFRelease(optionsDict);
	
	if (!success)
    {
        if (destination)
            CFRelease(destination);
        if (destinationData)
            CFRelease(destinationData);
        return success;
    }
	
	CFRetain(destinationData);
	ALAssetsLibrary *library = [ALAssetsLibrary new];
	[library writeImageDataToSavedPhotosAlbum:(__bridge id)destinationData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
		if (destinationData)
			CFRelease(destinationData);
	}];
	//[library release];
    
    if (destination)
        CFRelease(destination);
    if (destinationData)
        CFRelease(destinationData);
    return success;
}

// utility routine used after taking a still image to write the resulting image to the camera roll
- (BOOL)writeCGImageToPath:(CGImageRef)cgImage withMetadata:(NSDictionary *)metadata withQuality:(CGFloat)quality withEncodingType:(EncodingType)encodingType toPath:(NSString *)path
{
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = nil;
    if (encodingType == EncodingTypeJPEG)
        destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    else
        destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    
    const float JPEGCompQuality = quality; // JPEGHigherQuality (0 ~ 1)
	CFMutableDictionaryRef optionsDict = NULL;
	CFNumberRef qualityNum = NULL;
	
	qualityNum = CFNumberCreate(0, kCFNumberFloatType, &JPEGCompQuality);
	if ( qualityNum ) {
		optionsDict = CFDictionaryCreateMutable(0, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		if ( optionsDict )
			CFDictionarySetValue(optionsDict, kCGImageDestinationLossyCompressionQuality, qualityNum);
		CFRelease( qualityNum );
	}
    
    CGImageDestinationAddImage(destination, cgImage, optionsDict);
    
    BOOL success = CGImageDestinationFinalize(destination);
    if (!success) {
        NSLog(@"Failed to write image to %@", path);
    }
    
    
    if ( optionsDict )
		CFRelease(optionsDict);
    
    CFRelease(destination);
    
    return success;
}

- (BOOL)writeData:(NSData *)data toPath:(NSString *)path
{
    BOOL success = [data writeToFile:path atomically:YES];
    return success;
}

- (BOOL)writeJPGToCameraRoll:(NSData *)jpegData withAttachments:(CFDictionaryRef)attachments
{
    if (attachments)
        CFRetain(attachments);
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeImageDataToSavedPhotosAlbum:jpegData metadata:(__bridge id)attachments completionBlock:^(NSURL *assetURL, NSError *error) {
        if (attachments)
            CFRelease(attachments);
        if (error) {
            NSLog(@"Failed to save image to camera roll : %@", [error localizedDescription]);
        }
        else
        {
            //
        }
    }];
    
    return YES;
}

// utility used by newSquareOverlayedImageForFeatures for
static CGContextRef CreateCGBitmapContextForSize(CGSize size);
static CGContextRef CreateCGBitmapContextForSize(CGSize size)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    int             bitmapBytesPerRow;
	
    bitmapBytesPerRow = (size.width * 4);
	
    colorSpace = CGColorSpaceCreateDeviceRGB();
    context = CGBitmapContextCreate (NULL,
									 size.width,
									 size.height,
									 8,      // bits per component
									 bitmapBytesPerRow,
									 colorSpace,
									 kCGImageAlphaPremultipliedLast);
	CGContextSetAllowsAntialiasing(context, NO);
    CGColorSpaceRelease( colorSpace );
    return context;
}


static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size);
static void ReleaseCVPixelBuffer(void *pixel, const void *data, size_t size)
{
	CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)pixel;
	CVPixelBufferUnlockBaseAddress( pixelBuffer, 0 );
	CVPixelBufferRelease( pixelBuffer );
}

// create a CGImage with provided pixel buffer, pixel buffer must be uncompressed kCVPixelFormatType_32ARGB or kCVPixelFormatType_32BGRA
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut);
static OSStatus CreateCGImageFromCVPixelBuffer(CVPixelBufferRef pixelBuffer, CGImageRef *imageOut)
{
	OSStatus err = noErr;
	OSType sourcePixelFormat;
	size_t width, height, sourceRowBytes;
	void *sourceBaseAddr = NULL;
	CGBitmapInfo bitmapInfo;
	CGColorSpaceRef colorspace = NULL;
	CGDataProviderRef provider = NULL;
	CGImageRef image = NULL;
	
	sourcePixelFormat = CVPixelBufferGetPixelFormatType( pixelBuffer );
	if ( kCVPixelFormatType_32ARGB == sourcePixelFormat )
		bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaNoneSkipFirst;
	else if ( kCVPixelFormatType_32BGRA == sourcePixelFormat )
		bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst;
	else
		return -95014; // only uncompressed pixel formats
	
	sourceRowBytes = CVPixelBufferGetBytesPerRow( pixelBuffer );
	width = CVPixelBufferGetWidth( pixelBuffer );
	height = CVPixelBufferGetHeight( pixelBuffer );
	
	CVPixelBufferLockBaseAddress( pixelBuffer, 0 );
	sourceBaseAddr = CVPixelBufferGetBaseAddress( pixelBuffer );
	
	colorspace = CGColorSpaceCreateDeviceRGB();
    
	CVPixelBufferRetain( pixelBuffer );
	provider = CGDataProviderCreateWithData( (void *)pixelBuffer, sourceBaseAddr, sourceRowBytes * height, ReleaseCVPixelBuffer);
	image = CGImageCreate(width, height, 8, 32, sourceRowBytes, colorspace, bitmapInfo, provider, NULL, true, kCGRenderingIntentDefault);
	
bail:
	if ( err && image ) {
		CGImageRelease( image );
		image = NULL;
	}
	if ( provider ) CGDataProviderRelease( provider );
	if ( colorspace ) CGColorSpaceRelease( colorspace );
	*imageOut = image;
	return err;
}

@end
