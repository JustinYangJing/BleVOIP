//
//  VoiceConvertHandle.m
//  BleVOIP
//
//  Created by JustinYang on 16/6/14.
//  Copyright © 2016年 JustinYang. All rights reserved.
//

#define handleError(error)  if(error){ NSLog(@"%@",error); exit(1);}
#define kSmaple     44100

#define kOutoutBus 0
#define kInputBus  1
//存取PCM原始数据的节点
typedef struct PCMNode{
    struct PCMNode *next;
    struct PCMNode *previous;
    void        *data;
    unsigned int dataSize;
} PCMNode;



#import "VoiceConvertHandle.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#include <pthread.h>

#import "BNRAudioData.h"

#define kRecordDataLen  (1024*20)
typedef struct {
    NSInteger   front;
    NSInteger   rear;
    SInt16      recordArr[kRecordDataLen];
} RecordStruct;

static pthread_mutex_t  recordLock;
static pthread_cond_t   recordCond;

static pthread_mutex_t  playLock;
static pthread_cond_t   playCond;

static pthread_mutex_t  buffLock;
static pthread_cond_t   buffcond;

@interface MCAudioQueueBuffer : NSObject
@property (nonatomic,assign) AudioQueueBufferRef buffer;
@end
@implementation MCAudioQueueBuffer
@end

@interface VoiceConvertHandle ()
{
    AURenderCallbackStruct      _inputProc;
    AudioStreamBasicDescription _audioFormat;
    AudioStreamBasicDescription mAudioFormat;
    
 
    AudioConverterRef           _encodeConvertRef;
    
    AudioQueueRef               _playQueue;
    AudioQueueBufferRef         _queueBuf[3];
    
    CFURLRef                    destinationURL;
    AudioFileID                 destinationFileID;
    
    NSMutableArray *_buffers;
    NSMutableArray *_reusableBuffers;
}

@property (nonatomic,weak)   AVAudioSession *session;
@property (nonatomic,assign) AudioComponentInstance toneUnit;

@property (nonatomic,strong) NSMutableArray     *aacArry;

//test
@property (nonatomic,strong) AVAudioPlayer *player;
@end

@implementation VoiceConvertHandle
RecordStruct    recordStruct;

+(instancetype)shareInstance{
    static dispatch_once_t onceToken;
    static VoiceConvertHandle *handle;
    dispatch_once(&onceToken, ^{
        handle = [[VoiceConvertHandle alloc] init];
        [handle dataInit];
        [handle configAudio];
//        [handle anotherConfigInit];
    });
    return handle;
}
-(void)configAudio{
    _inputProc.inputProc = inputRenderTone;
    _inputProc.inputProcRefCon = (__bridge void *)(self);
    
    //对AudioSession的一些设置
    NSError *error;
    self.session = [AVAudioSession sharedInstance];
    [self.session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    handleError(error);
    //route变化监听
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChangeHandle:) name:AVAudioSessionRouteChangeNotification object:self.session];
    
    [self.session setPreferredIOBufferDuration:0.005 error:&error];
    handleError(error);
    [self.session setPreferredSampleRate:kSmaple error:&error];
    handleError(error);
    
    [self.session setActive:YES error:&error];
    handleError(error);
    
    
    //    Obtain a RemoteIO unit instance
    AudioComponentDescription acd;
    acd.componentType = kAudioUnitType_Output;
    acd.componentSubType = kAudioUnitSubType_RemoteIO;
    acd.componentFlags = 0;
    acd.componentFlagsMask = 0;
    acd.componentManufacturer = kAudioUnitManufacturer_Apple;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &acd);
    AudioComponentInstanceNew(inputComponent, &_toneUnit);
    
    
    UInt32 enable = 1;
    AudioUnitSetProperty(_toneUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,
                         kInputBus,
                         &enable,
                         sizeof(enable));
    AudioUnitSetProperty(_toneUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output,
                         kOutoutBus, &enable, sizeof(enable));
    
    mAudioFormat.mSampleRate         = kSmaple;//采样率
    mAudioFormat.mFormatID           = kAudioFormatLinearPCM;//PCM采样
    mAudioFormat.mFormatFlags        = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    mAudioFormat.mFramesPerPacket    = 1;//每个数据包多少帧
    mAudioFormat.mChannelsPerFrame   = 1;//1单声道，2立体声
    mAudioFormat.mBitsPerChannel     = 16;//语音每采样点占用位数
    mAudioFormat.mBytesPerFrame      = mAudioFormat.mBitsPerChannel*mAudioFormat.mChannelsPerFrame/8;//每帧的bytes数
    mAudioFormat.mBytesPerPacket     = mAudioFormat.mBytesPerFrame*mAudioFormat.mFramesPerPacket;//每个数据包的bytes总数，每帧的bytes数＊每个数据包的帧数
    mAudioFormat.mReserved           = 0;
    
    CheckError(AudioUnitSetProperty(_toneUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input, kOutoutBus,
                                    &mAudioFormat, sizeof(mAudioFormat)),
               "couldn't set the remote I/O unit's output client format");
    CheckError(AudioUnitSetProperty(_toneUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output, kInputBus,
                                    &mAudioFormat, sizeof(mAudioFormat)),
               "couldn't set the remote I/O unit's input client format");
    
    CheckError(AudioUnitSetProperty(_toneUnit,
                                    kAudioOutputUnitProperty_SetInputCallback,
                                    kAudioUnitScope_Output,
                                    kInputBus,
                                    &_inputProc, sizeof(_inputProc)),
               "couldnt set remote i/o render callback for input");
    
    
    CheckError(AudioUnitInitialize(_toneUnit),
               "couldn't initialize the remote I/O unit");
    CheckError(AudioOutputUnitStart(_toneUnit), "couldnt start audio unit");
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask,
                                                         YES);
    NSString *descriptionPth = [[NSString alloc] initWithFormat:@"%@/output.caf",paths[0]];
    NSLog(@"%@",descriptionPth);
    destinationURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                   (CFStringRef)descriptionPth,
                                                   kCFURLPOSIXPathStyle, false);
    
   
    
//    [self anotherConfigInit];

    //convertInit for PCM TO AAC
    AudioStreamBasicDescription sourceDes = mAudioFormat;

    AudioStreamBasicDescription targetDes;
    memset(&targetDes, 0, sizeof(targetDes));
    targetDes.mFormatID = kAudioFormatMPEG4AAC;
    targetDes.mSampleRate = kSmaple;
    targetDes.mChannelsPerFrame = sourceDes.mChannelsPerFrame;
    
    UInt32 size = sizeof(targetDes);
    CheckError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                      0, NULL, &size, &targetDes),
               "couldnt create target data format");


    //选择软件编码
    AudioClassDescription audioClassDes;
    CheckError(AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                          sizeof(targetDes.mFormatID),
                                          &targetDes.mFormatID,
                                          &size), "cant get kAudioFormatProperty_Encoders");
    UInt32 numEncoders = size/sizeof(AudioClassDescription);
    AudioClassDescription audioClassArr[numEncoders];
    CheckError(AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                      sizeof(targetDes.mFormatID),
                                      &targetDes.mFormatID,
                                      &size,
                                      audioClassArr),
               "wrirte audioClassArr fail");
    for (int i = 0; i < numEncoders; i++) {
        if (audioClassArr[i].mSubType == kAudioFormatMPEG4AAC
            && audioClassArr[i].mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
            memcpy(&audioClassDes, &audioClassArr[i], sizeof(AudioClassDescription));
            break;
        }
    }
    
    CheckError(AudioConverterNewSpecific(&sourceDes, &targetDes, 1,
                                         &audioClassDes, &_encodeConvertRef),
               "cant new convertRef");
    
    size = sizeof(sourceDes);
    CheckError(AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentInputStreamDescription, &size, &sourceDes), "cant get kAudioConverterCurrentInputStreamDescription");
    
    size = sizeof(targetDes);
    CheckError(AudioConverterGetProperty(_encodeConvertRef, kAudioConverterCurrentOutputStreamDescription, &size, &targetDes), "cant get kAudioConverterCurrentOutputStreamDescription");
    
    UInt32 bitRate = 64000;
    size = sizeof(bitRate);
    CheckError(AudioConverterSetProperty(_encodeConvertRef,
                                         kAudioConverterEncodeBitRate,
                                         size, &bitRate),
               "cant set covert property bit rate");
    
#warning by justin
    CheckError(AudioFileCreateWithURL(destinationURL,
                                      kAudioFileCAFType,
                                      &targetDes,
                                      kAudioFileFlags_EraseFile,
                                      &destinationFileID),
               "cant create audiofile id");
    
    [self performSelectorInBackground:@selector(convertPCMToAAC) withObject:nil];

    
    CheckError(AudioQueueNewOutput(&targetDes,
                                   fillBufCallback,
                                   (__bridge void *)self,
                                   NULL,
                                   NULL,
                                   0,
                                   &(_playQueue)),
               "cant new audio queue");
    CheckError( AudioQueueSetParameter(_playQueue,
                                       kAudioQueueParam_Volume, 1.0),
               "cant set audio queue gain");
    
    for (int i = 0; i < 3; i++) {
        AudioQueueBufferRef buffer;
        CheckError(AudioQueueAllocateBuffer(_playQueue, 1024, &buffer), "cant alloc buff");
        MCAudioQueueBuffer *buffObj = [[MCAudioQueueBuffer alloc] init];
        buffObj.buffer = buffer;
        [_buffers addObject:buffObj];
        [_reusableBuffers addObject:buffObj];
        
    }
    
    [self performSelectorInBackground:@selector(playData) withObject:nil];
}


-(void)dataInit{
    int rc;
    rc = pthread_mutex_init(&recordLock,NULL);
    assert(rc == 0);
    rc = pthread_cond_init(&recordCond, NULL);
    assert(rc == 0);
    
    rc = pthread_mutex_init(&playLock,NULL);
    assert(rc == 0);
    rc = pthread_cond_init(&playCond, NULL);
    assert(rc == 0);
    
    rc = pthread_mutex_init(&buffLock,NULL);
    assert(rc == 0);
    rc = pthread_cond_init(&buffcond, NULL);
    assert(rc == 0);
    
    
    memset(recordStruct.recordArr, 0, kRecordDataLen);
    recordStruct.front = recordStruct.rear = 0;
    
    self.aacArry = [[NSMutableArray alloc] init];
    
    _buffers = [[NSMutableArray alloc] init];
    _reusableBuffers = [[NSMutableArray alloc] init];
    
}

OSStatus inputRenderTone(
                         void *inRefCon,
                         AudioUnitRenderActionFlags 	*ioActionFlags,
                         const AudioTimeStamp 		*inTimeStamp,
                         UInt32 						inBusNumber,
                         UInt32 						inNumberFrames,
                         AudioBufferList 			*ioData)

{
    
    VoiceConvertHandle *THIS=(__bridge VoiceConvertHandle*)inRefCon;
    
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = NULL;
    bufferList.mBuffers[0].mDataByteSize = 0;
    OSStatus status = AudioUnitRender(THIS->_toneUnit,
                                      ioActionFlags,
                                      inTimeStamp,
                                      kInputBus,
                                      inNumberFrames,
                                      &bufferList);
    
    NSInteger lastTimeRear = recordStruct.rear;
    for (int i = 0; i < inNumberFrames; i++) {
        SInt16 data = ((SInt16 *)bufferList.mBuffers[0].mData)[i];
        recordStruct.recordArr[recordStruct.rear] = data;
        recordStruct.rear = (recordStruct.rear+1)%kRecordDataLen;
    }
    if ((lastTimeRear/1024 + 1) == (recordStruct.rear/1024)) {
         pthread_cond_signal(&recordCond);
    }
    return status;
}


-(void)convertPCMToAAC{
    UInt32 maxPacketSize = 0;
    UInt32 size = sizeof(maxPacketSize);
    CheckError(AudioConverterGetProperty(_encodeConvertRef,
                                         kAudioConverterPropertyMaximumOutputPacketSize,
                                         &size,
                                         &maxPacketSize),
               "cant get max size of packet");
    
    AudioBufferList *bufferList = malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mData = malloc(maxPacketSize);
    bufferList->mBuffers[0].mDataByteSize = maxPacketSize;
    
    for (; ; ) {
        
        pthread_mutex_lock(&recordLock);
        while (ABS(recordStruct.rear - recordStruct.front) < 1024 ) {
            pthread_cond_wait(&recordCond, &recordLock);
        }
        pthread_mutex_unlock(&recordLock);
        
        SInt16 *readyData = (SInt16 *)calloc(1024, sizeof(SInt16));
        memcpy(readyData, &recordStruct.recordArr[recordStruct.front], 1024*sizeof(SInt16));
        recordStruct.front = (recordStruct.front+1024)%kRecordDataLen;
        UInt32 packetSize = 1;
        AudioStreamPacketDescription *outputPacketDescriptions = malloc(sizeof(AudioStreamPacketDescription)*packetSize);
        bufferList->mBuffers[0].mDataByteSize = maxPacketSize;
        CheckError(AudioConverterFillComplexBuffer(_encodeConvertRef,
                                                   encodeConverterComplexInputDataProc,
                                                   readyData,
                                                   &packetSize,
                                                   bufferList,
                                                   outputPacketDescriptions),
                   "cant set AudioConverterFillComplexBuffer");

        free(readyData);
        //加上AAC头部，并发送
//        int headLength = 0;
//        char *head = newAdtsDataForPacketLength(bufferList->mBuffers[0].mDataByteSize, kSmaple, 1, &headLength);
//        NSMutableData *fullData = [NSMutableData dataWithBytes:head length:headLength];
//        free(head);
//        [fullData appendBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
        NSMutableData *fullData = [NSMutableData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
        static int outputFilePos = 0;
        UInt32 numBytes = [fullData length];
     //写到文件中
        /*
        if (outputFilePos > 1200) {
            AudioFileClose(destinationFileID);
        }else{
        CheckError(AudioFileWritePackets(destinationFileID,
                                         false,
                                         numBytes,
                                         outputPacketDescriptions,
                                         outputFilePos,
                                         &packetSize,
                                         [fullData bytes]),
                   "cant write");
        outputFilePos += packetSize;
        }*/
        
        
//        if (initQueueBufCount < 3) {
//            AudioQueueAllocateBuffer(_playQueue,
//                                     1024,
//                                     &_queueBuf[initQueueBufCount]);
//            AudioQueueBufferRef buf = _queueBuf[initQueueBufCount];
//            initQueueBufCount++;
//            
//            memcpy(buf->mAudioData, [fullData bytes], [fullData length]);
//            buf->mAudioDataByteSize = [fullData length];
//            AudioStreamPacketDescription packetDescription;
//            packetDescription.mDataByteSize = [fullData length];
//        
//            packetDescription.mStartOffset = lastIndex;
//            AudioQueueEnqueueBuffer(_playQueue,
//                                    buf,
//                                    1, &packetDescription);
//            lastIndex += [fullData length];
//            if (initQueueBufCount == 3) {
//                AudioQueueStart(_playQueue, nil);
//            }
//        }else{
            pthread_mutex_lock(&playLock);
            AudioStreamPacketDescription packetDescription;
            packetDescription.mDataByteSize = [fullData length];
            packetDescription.mStartOffset = lastIndex;
            lastIndex += [fullData length];
            BNRAudioData *audioData = [BNRAudioData parsedAudioDataWithBytes:[fullData bytes] packetDescription:packetDescription];
            [self.aacArry addObject:audioData];
        BOOL  couldSignal = NO;
        if (self.aacArry.count%8 == 0 && self.aacArry.count > 0) {
            lastIndex = 0;
            couldSignal = YES;
        }
            pthread_mutex_unlock(&playLock);
        if (couldSignal) {
            pthread_cond_signal(&playCond);
        }
        
//        }
    }
}
-(void)playData{
    for (; ; ) {
        NSMutableData *data = [[NSMutableData alloc] init];
        pthread_mutex_lock(&playLock);
        if (self.aacArry.count%8 != 0 || self.aacArry.count == 0) {
            pthread_cond_wait(&playCond, &playLock);
        }
        AudioStreamPacketDescription *paks = calloc(sizeof(AudioStreamPacketDescription), 8);
        for (int i = 0; i < 8 ; i++) {
            BNRAudioData *audio = [self.aacArry firstObject];
            [data appendData:audio.data];
            paks[i].mStartOffset = audio.packetDescription.mStartOffset;
            paks[i].mDataByteSize = audio.packetDescription.mDataByteSize;
            [self.aacArry removeObjectAtIndex:0];
        }
        pthread_mutex_unlock(&playLock);
        
        pthread_mutex_lock(&buffLock);
        if (_reusableBuffers.count == 0) {
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                AudioQueueStart(_playQueue, nil);
            });
            pthread_cond_wait(&buffcond, &buffLock);
           
        }
        MCAudioQueueBuffer *bufferObj = [_reusableBuffers firstObject];
        [_reusableBuffers removeObject:bufferObj];
        pthread_mutex_unlock(&buffLock);
        
        memcpy(bufferObj.buffer->mAudioData,[data bytes] , [data length]);
        bufferObj.buffer->mAudioDataByteSize = (UInt32)[data length];
        CheckError(AudioQueueEnqueueBuffer(_playQueue, bufferObj.buffer, 8, paks), "cant enqueue");
    

        
    }
}
OSStatus encodeConverterComplexInputDataProc(AudioConverterRef inAudioConverter,
                                             UInt32 *ioNumberDataPackets,
                                             AudioBufferList *ioData,
                                             AudioStreamPacketDescription **outDataPacketDescription,
                                             void *inUserData)
{
    ioData->mBuffers[0].mData = inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mDataByteSize = 1024*2;
    *ioNumberDataPackets = 1024;
    return 0;
}
static void CheckError(OSStatus error,const char *operaton){
    if (error==noErr) {
        return;
    }
    char errorString[20]={};
    *(UInt32 *)(errorString+1)=CFSwapInt32HostToBig(error);
    if (isprint(errorString[1])&&isprint(errorString[2])&&isprint(errorString[3])&&isprint(errorString[4])) {
        errorString[0]=errorString[5]='\'';
        errorString[6]='\0';
    }else{
        sprintf(errorString, "%d",(int)error);
    }
    fprintf(stderr, "Error:%s (%s)\n",operaton,errorString);
    exit(1);
}

static void fillBufCallback(void *inUserData,
                           AudioQueueRef inAQ,
                           AudioQueueBufferRef buffer){
    VoiceConvertHandle *THIS=(__bridge VoiceConvertHandle*)inUserData;
    
    for (int i = 0; i < THIS->_buffers.count; ++i) {
        if (buffer == [THIS->_buffers[i] buffer]) {
            pthread_mutex_lock(&buffLock);
            [THIS->_reusableBuffers addObject:THIS->_buffers[i]];
            pthread_mutex_unlock(&buffLock);
            pthread_cond_signal(&buffcond);
            break;
        }
    }
    
//    pthread_mutex_lock(&playLock);
//    pthread_cond_wait(&playCond, &playLock);
//    BNRAudioData *audioData = [THIS->_aacArry firstObject];
//    memcpy((unsigned char *)buffer->mAudioData, [audioData.data bytes], [audioData.data length]);
//    buffer->mAudioDataByteSize = [audioData.data length];
//    [THIS->_aacArry removeObjectAtIndex:0];
//    pthread_mutex_unlock(&playLock);
//    AudioStreamPacketDescription pak = audioData.packetDescription;
//    CheckError(AudioQueueEnqueueBuffer(inAQ, buffer, 1, &pak),
//               "cant enqueue buf");
}

char* newAdtsDataForPacketLength(int packetLength, int samplerate, int channelCount, int* ioHeaderLen) {
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = freqIdxForAdtsHeader(samplerate);
    int chanCfg = channelIdxForAdtsHeader(channelCount);  //MPEG-4 Audio Channel Configuration.
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF;
    // 11111111  = syncword
    packet[1] = (char)0xF9;
    // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    //    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    //    return data;
    *ioHeaderLen = adtsLength;
    return packet;
}
int freqIdxForAdtsHeader(int samplerate)
{
    /**
     0: 96000 Hz
     1: 88200 Hz
     2: 64000 Hz
     3: 48000 Hz
     4: 44100 Hz
     5: 32000 Hz
     6: 24000 Hz
     7: 22050 Hz
     8: 16000 Hz
     9: 12000 Hz
     10: 11025 Hz
     11: 8000 Hz
     12: 7350 Hz
     13: Reserved
     14: Reserved
     15: frequency is written explictly
     */
    int idx = 4;
    if (samplerate >= 7350 && samplerate < 8000) {
        idx = 12;
    }
    else if (samplerate >= 8000 && samplerate < 11025) {
        idx = 11;
    }
    else if (samplerate >= 11025 && samplerate < 12000) {
        idx = 10;
    }
    else if (samplerate >= 12000 && samplerate < 16000) {
        idx = 9;
    }
    else if (samplerate >= 16000 && samplerate < 22050) {
        idx = 8;
    }
    else if (samplerate >= 22050 && samplerate < 24000) {
        idx = 7;
    }
    else if (samplerate >= 24000 && samplerate < 32000) {
        idx = 6;
    }
    else if (samplerate >= 32000 && samplerate < 44100) {
        idx = 5;
    }
    else if (samplerate >= 44100 && samplerate < 48000) {
        idx = 4;
    }
    else if (samplerate >= 48000 && samplerate < 64000) {
        idx = 3;
    }
    else if (samplerate >= 64000 && samplerate < 88200) {
        idx = 2;
    }
    else if (samplerate >= 88200 && samplerate < 96000) {
        idx = 1;
    }
    else if (samplerate >= 96000) {
        idx = 0;
    }
    
    return idx;
}


int channelIdxForAdtsHeader(int channelCount)
{
    /**
     0: Defined in AOT Specifc Config
     1: 1 channel: front-center
     2: 2 channels: front-left, front-right
     3: 3 channels: front-center, front-left, front-right
     4: 4 channels: front-center, front-left, front-right, back-center
     5: 5 channels: front-center, front-left, front-right, back-left, back-right
     6: 6 channels: front-center, front-left, front-right, back-left, back-right, LFE-channel
     7: 8 channels: front-center, front-left, front-right, side-left, side-right, back-left, back-right, LFE-channel
     8-15: Reserved
     */
    int ret = 2;
    if (channelCount == 1) {
        ret = 1;
    }
    else if (channelCount == 2) {
        ret = 2;
    }
    
    return ret;
}

#pragma mark - mutex
- (void)_mutexInit
{
    pthread_mutex_init(&buffLock, NULL);
    pthread_cond_init(&buffcond, NULL);
}

- (void)_mutexDestory
{
    pthread_mutex_destroy(&buffLock);
    pthread_cond_destroy(&buffcond);
}

- (void)_mutexWait
{
    pthread_mutex_lock(&buffLock);
    pthread_cond_wait(&buffcond, &buffLock);
    pthread_mutex_unlock(&buffLock);
}

- (void)_mutexSignal
{
    pthread_mutex_lock(&buffLock);
    pthread_mutex_unlock(&buffLock);
    pthread_cond_signal(&buffcond);
}

@end
