//
//  myH264VideoFrameExtractor.m
//  mydlinkCameraModule
//
//  Created by mydlink on 2011/7/18.
//  Copyright 2011 D-Link Corporation. All rights reserved.
//

#import "myH264VideoFrameExtractor.h"

@interface myH264VideoFrameExtractor (private)
-(BOOL)initCodecContext:(UInt8 *)data length:(int)len;
-(void)initScaler;
-(BOOL)decodeFrame;
-(BOOL)currentImage;
-(void)convertFrameToRGB;
-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height;
@end

@implementation myH264VideoFrameExtractor

- (id)initWithDelegate:(id)delegate {
	_myDelegate = delegate;

	return self;
}

-(int)decodeH264Frame:(NSData *)rawFrame length:(int)rawFrame_length firstTime:(BOOL)first {
	int ret = H264_DECODER_STATE_NONE;

	if (streamInfoRetrieved == FALSE || first) {

		// Register all formats and codecs
		if (first) {
			av_register_all();
		}
	
		if ([self initCodecContext:(UInt8 *)[rawFrame bytes] length:rawFrame_length])
			ret = H264_DECODER_STATE_INIT;

	} else if (streamInfoRetrieved == TRUE) {
		pData = (UInt8 *)[rawFrame bytes];
		Data_len = rawFrame_length;
		if ([self decodeFrame])
			ret = H264_DECODER_STATE_WORKING;
	}
	
	return ret;
}

-(void)dealloc {
	// Init the value
	streamInfoRetrieved = FALSE;
	
	// Free the raw data
	if(pData) free(pData);
	
	// Free scaler
	sws_freeContext(img_convert_ctx);	
	
	// Free RGB picture
	avpicture_free(&picture);
	
    // Free the YUV frame
    av_free(pFrame);
	
    // Close the codec
    if (pCodecCtx) avcodec_close(pCodecCtx);
	
    // Close the video stream
	if (pFormatCtx) av_close_input_stream(pFormatCtx);
	
	[super dealloc];
}

#pragma mark -
#pragma mark initialize the codec context
/* 
 * Initialize the codec context by first frame. 
 * Output dimensions are set to source dimensions.
 */
-(BOOL)initCodecContext:(UInt8 *)data length:(int)len {
	AVProbeData     probe_data;
	AVInputFormat   *pAVInputFormat;	
	AVCodec         *pCodec;
	ByteIOContext   *pAVIOCtx;
	
	// Allocate memory to format context pFormatCtx
	if ((pFormatCtx = avformat_alloc_context()) == nil) {
		return FALSE;    // Couldn't alloc memory to AVFormatContext
	}
	
	// Initializes the probe data probe_data
	probe_data.filename = "";
	probe_data.buf_size = len;
	probe_data.buf = (unsigned char*) calloc(1, len+FF_INPUT_BUFFER_PADDING_SIZE);
	probe_data.buf = data;
	
	// Initializes input format and retrieve information from first frame
	pAVInputFormat = av_find_input_format("h264");
	if (pAVInputFormat == nil) {
		return FALSE;    // Couldn't initialize AVInputFormat
	}

	pAVInputFormat->flags |= AVFMT_NOFILE;
	
	// Allocate IO stream structure and read from probe data
	if(!(pAVIOCtx = av_alloc_put_byte(probe_data.buf, probe_data.buf_size, 0, NULL, NULL, NULL, NULL))) {
		return FALSE;    // Couldn't initialize ByteIOContext
	}
	
	// Allocate Format context structure and read an input IO stream
	if (av_open_input_stream(&pFormatCtx, pAVIOCtx, "", pAVInputFormat, NULL) < 0) {
		return FALSE;    // Couldn't allocate and read input stream
	}
	
	// Retrieve stream information
	if (av_find_stream_info(pFormatCtx)<0) {
		return FALSE;    // Couldn't find stream information
	}
	
	// Find the first video stream
	videoStream=-1;
	for (int i=0; i<pFormatCtx->nb_streams; i++)
		if (pFormatCtx->streams[i]->codec->codec_type==CODEC_TYPE_VIDEO) {
			videoStream = i;
			break;
		}
	if (videoStream == -1) {
		return FALSE;    // Didn't find a video stream
	}
	
	// Get a pointer to the codec context for the video stream
	pCodecCtx=pFormatCtx->streams[videoStream]->codec;
	
	// Find the decoder for the video stream
	pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
	if (pCodec == NULL) {
		return FALSE;    // Codec not found
	}		

	// Open codec
	if (avcodec_open(pCodecCtx, pCodec) < 0) {
		return FALSE;    // Could not open codec
	}

	// Allocate video frame
	pFrame = avcodec_alloc_frame();
	
	// Set output dimensions
	outputWidth = pCodecCtx->width;
	outputHeight = pCodecCtx->height;
	
	[self initScaler];
	streamInfoRetrieved = TRUE;
	
	return TRUE;
}

#pragma mark -
#pragma mark setup scaler parameters
-(void)initScaler {
	// Release old picture and scaler
	avpicture_free(&picture);
	
	// Allocate RGB picture
	avpicture_alloc(&picture, PIX_FMT_RGB24, outputWidth, outputHeight);
	
	// Setup scaler
	static int sws_flags =  SWS_FAST_BILINEAR;
	
	// sws_getCachedContext
	img_convert_ctx = sws_getCachedContext(img_convert_ctx,
										   pCodecCtx->width, 
										   pCodecCtx->height,
										   pCodecCtx->pix_fmt,
										   outputWidth, 
										   outputHeight,
										   PIX_FMT_RGB24,
										   sws_flags, NULL, NULL, NULL);
}

#pragma mark -
#pragma mark raw frame decode procedure
-(BOOL)decodeFrame {
    int frameFinished=0;

	packet.data = pData;
	packet.size = Data_len;

	// Decode the video frame of size packet->size from packet->data into picture.
	if (avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet) > 0)
		[self currentImage];
	
	return frameFinished!=0;
}

-(BOOL)currentImage {
	if (!pFrame->data[0]) return FALSE;
	[self convertFrameToRGB];
	if([_myDelegate respondsToSelector:@selector(onH264VideoFrameExtractor:didReceiveImage:)]) {
		[_myDelegate onH264VideoFrameExtractor:self 
							   didReceiveImage:[self imageFromAVPicture:picture 
																  width:outputWidth 
																 height:outputHeight]];
	}

	return TRUE;
}

-(void)convertFrameToRGB {	
	sws_scale (img_convert_ctx, (const UInt8 **)pFrame->data, pFrame->linesize,
			   0, pCodecCtx->height,
			   picture.data, picture.linesize);	
}

-(UIImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height {
	CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
	CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
	CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

	CGImageRef cgImage = CGImageCreate(width, 
									   height, 
									   8, 
									   24, 
									   pict.linesize[0], 
									   colorSpace, 
									   bitmapInfo, 
									   provider, 
									   NULL, 
									   NO, 
									   kCGRenderingIntentDefault);
	CGColorSpaceRelease(colorSpace);
	UIImage *image = [UIImage imageWithCGImage:cgImage];
	CGImageRelease(cgImage);
	CGDataProviderRelease(provider);
	CFRelease(data);
	
	return image;
}

@end
