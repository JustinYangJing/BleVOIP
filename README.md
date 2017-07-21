
# iOS音频编程之实时语音通信
### 需求：手机通过Mic采集PCM编码的原始音频数据，将PCM转换为AAC编码格式，通过MultipeerConnectivity框架连接手机并发送AAC数据，在接收端使用Audio Queue播放收到的AAC音频


## 音频设置
>对音频以44.1KHZ的采样率来采样,以64000的比特率对PCM进行AAC转码

1）对AVAudioSession的设置

    NSError *error;
    self.session = [AVAudioSession sharedInstance];
    [self.session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    handleError(error);
    //route变化监听
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioSessionRouteChangeHandle:) name:AVAudioSessionRouteChangeNotification object:self.session];
    
    [self.session setPreferredIOBufferDuration:0.005 error:&error];
    handleError(error);
    [self.session setPreferredSampleRate:kSmaple error:&error];
    handleError(error);
    
    //[self.session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
    //handleError(error);
    
    [self.session setActive:YES error:&error];
    handleError(error);
	
	-(void)audioSessionRouteChangeHandle:(NSNotification *)noti{
	//    NSError *error;
	//    [self.session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
	//    handleError(error);
    [self.session setActive:YES error:nil];
    if (self.startRecord) {
        CheckError(AudioOutputUnitStart(_toneUnit), "couldnt start audio unit");
    	}
	}
音频输入输出路径改变会触发`audioSessionRouteChangeHandle`,如果想一直让音频从手机的扬声器输出需要在每次Route改变时，把音频输出重定向到`AVAudioSessionPortOverrideSpeaker`,否则为手机听筒输出音频;其他设置说明请参照[iOS音频编程之变声处理的__*初始化*__部分](http://justinyangjing.github.io/2016/06/09/IOS%E9%9F%B3%E9%A2%91%E5%8F%98%E6%88%90%E4%B9%8B%E5%8F%98%E5%A3%B0%E5%A4%84%E7%90%86/)

2)对Audio Unit的设置

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
具体参数说明请参照[iOS音频编程之变声处理](http://justinyangjing.github.io/2016/06/09/IOS%E9%9F%B3%E9%A2%91%E5%8F%98%E6%88%90%E4%B9%8B%E5%8F%98%E5%A3%B0%E5%A4%84%E7%90%86/)

采集音频数据的输入回调
	
	static OSStatus inputRenderTone(
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
采用循环队列存储原始的音频数据，每1024点的PCM数据，让Converter转换为AAC编码,所以当收集了1024点PCM后，唤醒Converter线程。

3)音频转码
  
  初始化
  
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
    [self performSelectorInBackground:@selector(convertPCMToAAC) withObject:nil];
>主要是设置编码器的输入音频格式(PCM),输出音频格式(AAC),选择软件编码器(默认使用硬件编码器),设置编码器的比特率

AAC编码

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
        @autoreleasepool {
            
        
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
        free(outputPacketDescriptions);
        free(readyData);

        NSMutableData *fullData = [NSMutableData dataWithBytes:bufferList->mBuffers[0].mData length:bufferList->mBuffers[0].mDataByteSize];
        
        if ([self.delegate respondsToSelector:@selector(covertedData:)]) {
            [self.delegate covertedData:[fullData copy]];
        }
    	}
	}
新建的`bufferList`是用来存放每次转码后的AAC音频数据.for循环中等待音频输入回调存满1024个PCM数组并唤醒它。`outputPacketDescriptions`数组是每次转换的AAC编码后各个包的描述,但这里每次只转换一包数据(由传入的packetSize决定)。调用`AudioConverterFillComplexBuffer`触发转码，他的第二个参数是填充原始音频数据的回调。转码完成后，会将转码的数据存放在它的第五个参数中(`bufferList `).转换完成的AAC就可以发送给另外一台手机了。

填充原始数据回调
	
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


4）Audio Queue播放AAC音频数据

Audio Queue基础知识

音频数据以一个个`AudioQueueBuffer`的形式存在与音频队列中，`Audio Queue`使用它提供的音频数据来播放，某一个`AudioQueueBuffer`使用完毕后，会调用`Audio Queue`的回调，要求用户再在这个`AudioQueueBuffer`填入数据，并使它加入`Audio Queue`中，如此循环，达到不间断播放音频数据的效果。

Audio Queue初始化

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
        BNRAudioQueueBuffer *buffObj = [[BNRAudioQueueBuffer alloc] init];
        buffObj.buffer = buffer;
        [_buffers addObject:buffObj];
        [_reusableBuffers addObject:buffObj];
    }
    [self performSelectorInBackground:@selector(playData) withObject:nil];


Audio Queue播放音频数据

	-(void)playData{
    	for (; ; ) {
        @autoreleasepool {
            
        NSMutableData *data = [[NSMutableData alloc] init];
        pthread_mutex_lock(&playLock);
        if (self.aacArry.count%8 != 0 || self.aacArry.count == 0) {
            pthread_cond_wait(&playCond, &playLock);
        }
        AudioStreamPacketDescription *paks = calloc(sizeof(AudioStreamPacketDescription), 8);
        for (int i = 0; i < 8 ; i++) {//8包AAC数据组成放入一个AudioQueueBuffer的数据包
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
        BNRAudioQueueBuffer *bufferObj = [_reusableBuffers firstObject];
        [_reusableBuffers removeObject:bufferObj];
        pthread_mutex_unlock(&buffLock);
        
        memcpy(bufferObj.buffer->mAudioData,[data bytes] , [data length]);
        bufferObj.buffer->mAudioDataByteSize = (UInt32)[data length];
        CheckError(AudioQueueEnqueueBuffer(_playQueue, bufferObj.buffer, 8, paks), "cant enqueue");
        free(paks);

        }
    	}
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
	}

在`playData`中等待收到的`aacArry`数据，**这里要注意:每1024点PCM转换成的一包AAC数据加入到`AudioQueueBuffer`中，不足以使Audio Queue播放音频，所以这里使用8包AAC数据放到一个`AudioQueueBuffer`中**。`fillBufCallback`是Audio Queue播放完一个`AudioQueueBuffer`调用的回调函数，在这里面通知`playData`可以往使用完的`AudioQueueBufferRef`填数据了，填完后，用`AudioQueueEnqueueBuffer`将它加入`Audio Queue`中，这个三个`AudioQueueBufferRef`不断重用。

## 实时语音通信处理

>原来是想用蓝牙来传送数据的，但是自己写的蓝牙传送数据机制的速度跟不上转换的AAC数据。使用`MultipeerConnectivity `框架既可使用蓝牙也可以使用WIFI来通信，底层自动选择。当把两个手机的WIFI都关掉时，他们使用蓝牙来传送数据，在刚刚建立通话时，能听到传送的语音，之后就听不到了，使用wifi传输数据时不会出现这种情况。

1) MultipeerConnectivity基础知识

`MCNearbyServiceAdvertiser`发送广播，并接收`MCNearbyServiceBrowser`端的邀请,`MCSession`发送接收数据、管理连接状态。建立连接和通信的流程是，`MCNearbyServiceAdvertiser `广播服务，`MCNearbyServiceBrowser `搜到这个服务后，要求把这个服务所对用的`MCPeerID`加入到它自己(`MCNearbyServiceBrowser`端)的`MCSession`中，`MCNearbyServiceAdvertiser `收到这个邀请，并同意，同时也将`MCNearbyServiceBrowser `端对应的`MCPeerID`加入到了它自己(`MCNearbyServiceAdvertiser `)的`MCSession`中.
之后双方可以使用各自的`MCSession`发送接收数据。

2）各端发送本身转码的AAC数据，并接收对方发送的AAC数据提供给`Auduio queue`播放

[源码下载地址](https://github.com/JustinYangJing/BleVOIP.git)
