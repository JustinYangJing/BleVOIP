//
//  BNRClient.m
//  Game
//
//  Created by JustinYang on 15/9/22.
//  Copyright © 2015年 JustinYang. All rights reserved.
//

#import "BNRClient.h"
#include <pthread.h>
@interface BNRClient ()<MCNearbyServiceBrowserDelegate, MCSessionDelegate,
                        MCNearbyServiceAdvertiserDelegate,NSStreamDelegate>


/**
 *  服务端的PeerId，当断开时，需要再次去连接服务端
 */
@property(nonatomic, strong)MCPeerID *serverPeerID;
@property(nonatomic, strong)MCNearbyServiceBrowser *browser;

//客户端也广播，用于接收其他客户端的连接
@property(nonatomic,strong)MCNearbyServiceAdvertiser *advertiser;

@property (nonatomic,strong) NSInputStream           *inputStream;

@property (nonatomic,strong) NSMutableArray          *soundDataArr;

@end

pthread_mutex_t lock;
pthread_cond_t  cond;
@implementation BNRClient 
@dynamic delegate;

+(instancetype)sharedInstance{
    static BNRClient *client;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        client = [[BNRClient alloc] init];
        [client setup];
    });
    return client;
}

-(void)setup{
//    _localPeerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    self.soundDataArr = [NSMutableArray array];
    int rc;
    rc = pthread_mutex_init(&lock,NULL);
    assert(rc==0);
    rc = pthread_cond_init(&cond, NULL);
    assert(rc==0);
}

-(void)startSearchingServers{
    _browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID serviceType:kServerName];
    _browser.delegate = self;
    [_browser startBrowsingForPeers];
}

-(void)stopSearchingServers{
    [self.browser stopBrowsingForPeers];
    _browser.delegate = nil;
    _browser = nil;
}


/**
 *  连接发现的peerID
 *
 *  @param peer <#peer description#>
 */
-(void)connectAvailableServer:(MCPeerID *)peer{
    self.serverPeerID = peer;
    [self.browser invitePeer:peer toSession:self.session withContext:nil timeout:30];
}

-(void)reConnect{
    [self.browser invitePeer:self.serverPeerID toSession:self.session withContext:nil timeout:30];
}
-(void)sendData:(NSData *)data{
    if (self.session.connectedPeers.count == 0) {
        return;
    }
    static NSOutputStream *outputStream;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *err;
        outputStream = [self.session startStreamWithName:@"client stream"
                                                  toPeer:self.session.connectedPeers[0]
                                                   error:&err];
        if (err) {
            NSLog(@"%@",err);
            exit(1);
        }
        [outputStream setDelegate:self];
        [outputStream open];
    });
    
    pthread_mutex_lock(&lock);
    [self.soundDataArr addObject:data];
    pthread_mutex_unlock(&lock);
    pthread_cond_signal(&cond);
}
#pragma mark - MCNearbyServiceBrowserDelegate
- (void)        browser:(MCNearbyServiceBrowser *)browser
              foundPeer:(MCPeerID *)peerID
      withDiscoveryInfo:(nullable NSDictionary<NSString *, NSString *> *)info{
    NSLog(@"client find server %@",peerID.displayName);
    if ([self.delegate respondsToSelector:@selector(client:foundPeer:withDiscoveryInfo:)]) {
        [self.delegate client:self foundPeer:peerID withDiscoveryInfo:info];
    }
}


- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID{
    NSLog(@"client lost server %@",peerID.displayName);
    if ([self.delegate respondsToSelector:@selector(client:lostPeer:)]) {
        [self.delegate client:self lostPeer:peerID];
    }
}

#pragma mark - MCSessionDelegate
// Remote peer changed state.
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state{
    NSLog(@"client %@ state %ld",peerID.displayName, (long)state);
    if ([self.serverPeerID.displayName isEqualToString:peerID.displayName]) {
        NSLog(@"client : connect server state change %@",@(state));
        if ([self.delegate respondsToSelector:@selector(client:connectServerStateChange:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.delegate client:self connectServerStateChange:state];
            });
        }
    }
    
}

// Received data from remote peer.
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID{
    if([self.delegate respondsToSelector:@selector(commication:didReceiveData:fromPeerID:)]){
        [self.delegate commication:self didReceiveData:data fromPeerID:peerID];
    }
}

// Received a byte stream from remote peer.
- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID{
    if ([self.serverPeerID.displayName isEqual:peerID.displayName]) {
        self.inputStream = stream;
        [self.inputStream setDelegate:self];
        [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                    forMode:NSRunLoopCommonModes];
        [self.inputStream open];
    }
}

// Start receiving a resource from remote peer.
- (void)                    session:(MCSession *)session
  didStartReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                       withProgress:(NSProgress *)progress{}

// Finished receiving a resource from remote peer and saved the content
// in a temporary location - the app is responsible for moving the file
// to a permanent location within its sandbox.
- (void)                    session:(MCSession *)session
 didFinishReceivingResourceWithName:(NSString *)resourceName
                           fromPeer:(MCPeerID *)peerID
                              atURL:(NSURL *)localURL
                          withError:(nullable NSError *)error{}


#pragma mark - NSStreamDelegate
-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    switch (eventCode) {
        case NSStreamEventHasBytesAvailable:{
            UInt8 buf[1024];
            NSInputStream *inputStream = (NSInputStream *)aStream;
            NSInteger length = [inputStream read:buf maxLength:sizeof(buf)];
            NSData *data = [NSData dataWithBytes:buf length:length];
            if([self.delegate respondsToSelector:@selector(commication:didReceiveData:fromPeerID:)]){
                [self.delegate commication:self didReceiveData:data fromPeerID:nil];
            }
        }
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@"open stream completed");
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"NSStreamEventEndEncountered");
            [aStream close];
            break;
        case NSStreamEventHasSpaceAvailable:{
            NSOutputStream *outputStream = (NSOutputStream *)aStream;
            pthread_mutex_lock(&lock);
            while (self.soundDataArr.count == 0) {
                pthread_cond_wait(&cond, &lock);
            }
            NSData *data = [self.soundDataArr firstObject];
            UInt8 *buf = (UInt8 *)[data bytes];
            [outputStream write:buf maxLength:[data length]];
            [self.soundDataArr removeObjectAtIndex:0];
            pthread_mutex_unlock(&lock);
        }
            break;
        default:
            break;
    }
}
@end
