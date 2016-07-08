//
//  VoiceConvertHandle.h
//  BleVOIP
//
//  Created by JustinYang on 16/6/14.
//  Copyright © 2016年 JustinYang. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VoiceConvertHandleDelegate <NSObject>

-(void)covertedData:(NSData *)data;

@end

@interface VoiceConvertHandle : NSObject
@property (nonatomic,weak) id<VoiceConvertHandleDelegate> delegate;
@property (nonatomic)   BOOL    startRecord;
+(instancetype)shareInstance;
-(void)playWithData:(NSData *)data;
@end
