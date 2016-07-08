//
//  BNRServer.m
//  Game
//
//  Created by JustinYang on 15/9/18.
//  Copyright © 2015年 JustinYang. All rights reserved.
//

#import "BNRServer.h"

@interface BNRServer ()<MCNearbyServiceAdvertiserDelegate, MCSessionDelegate>

@property(nonatomic, strong)MCNearbyServiceAdvertiser *advertiser;

@end

@implementation BNRServer
@dynamic delegate;

+(instancetype)sharedInstance{
    static BNRServer *server;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        server = [[BNRServer alloc] init];
        [server setup];
    });
    return server;
}

-(void)setup{
//    _localPeerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
}

-(void)startAdvertiserWithDic:(NSDictionary *)dic{
    NSAssert(dic, @"advertiser info dic cant be nil");
    _advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.localPeerID
                                                    discoveryInfo:dic serviceType:kServerName];
    _advertiser.delegate = self;
    [_advertiser startAdvertisingPeer];
}
-(void)stopAdvertiser{
    [self.advertiser stopAdvertisingPeer];
    self.advertiser.delegate = nil;
    _advertiser = nil;
}




#pragma mark - MCNearbyServiceAdvertiserDelegate
-(void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession * _Nonnull))invitationHandler{
    NSLog(@"hoster receive join request");
    invitationHandler(YES,self.session);
}

#pragma mark - MCSessionDelegate
// Remote peer changed state.
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state{
    NSLog(@"%@ state %ld",peerID.displayName, (long)state);
    if ([self.delegate respondsToSelector:@selector(server:peer:didChangeState:)]) {
        [self.delegate server:self peer:peerID didChangeState:state];
    }
}

// Received data from remote peer.
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID{
    if ([self.delegate respondsToSelector:@selector(commication:didReceiveData:fromPeerID:)]) {
        [self.delegate commication:self didReceiveData:data fromPeerID:peerID];
    }
}

// Received a byte stream from remote peer.
- (void)    session:(MCSession *)session
   didReceiveStream:(NSInputStream *)stream
           withName:(NSString *)streamName
           fromPeer:(MCPeerID *)peerID{}

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
@end
