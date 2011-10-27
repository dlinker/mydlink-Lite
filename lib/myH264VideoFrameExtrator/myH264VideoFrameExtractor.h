//
//  myH264VideoFrameExtractor.h
//  mydlinkCameraModule
//
//  Created by mydlink on 2011/7/18.
//  Copyright 2011 D-Link Corporation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

enum H264_DECODER_STAGE {
	H264_DECODER_STATE_NONE,
	H264_DECODER_STATE_INIT,
	H264_DECODER_STATE_WORKING
};

@interface myH264VideoFrameExtractor : NSObject {
	AVFormatContext *pFormatCtx;
	AVCodecContext *pCodecCtx;
    AVFrame *pFrame; 
	AVPicture picture;
	AVPacket packet;
	int videoStream;
	struct SwsContext *img_convert_ctx;
	int outputWidth, outputHeight;
	UIImage *currentImage;
	int streamInfoRetrieved;
	id _myDelegate;
	UInt8 *pData;
	int Data_len;
}

-(id)initWithDelegate:(id)delegate;

/* Input the H264 raw frame to decode. Returns H264 decoder stage now. */
-(int)decodeH264Frame:(NSData *)rawFrame length:(int)rawFrame_length firstTime:(BOOL)first;

@end

@interface NSObject (myH264VideoFrameExtractorDelegate)
/**
 * Called when HTTP parser found header or body in HTTP stream.
 **/
- (void)onH264VideoFrameExtractor:(myH264VideoFrameExtractor *)extractor didReceiveImage:(UIImage *)image;
@end
