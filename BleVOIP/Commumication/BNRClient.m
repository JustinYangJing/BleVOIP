//
//  BNRClient.m
//  Game
//
//  Created by JustinYang on 15/9/22.
//  Copyright © 2015年 JustinYang. All rights reserved.
//

#import "BNRClient.h"

@interface BNRClient ()<MCNearbyServiceBrowserDelegate, MCSessionDelegate,MCNearbyServiceAdvertiserDelegate>


/**
 *  服务端的PeerId，当断开时，需要再次去连接服务端
 */
@property(nonatomic, strong)MCPeerID *serverPeerID;
@property(nonatomic, strong)MCNearbyServiceBrowser *browser;

//客户端也广播，用于接收其他客户端的连接
@property(nonatomic,strong)MCNearbyServiceAdvertiser *advertiser;
@end

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
