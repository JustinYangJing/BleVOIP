//
//  BNRCommication.m
//  Game
//
//  Created by JustinYang on 15/9/21.
//  Copyright © 2015年 JustinYang. All rights reserved.
//

#import "BNRCommication.h"

@interface BNRCommication ()
@property (nonatomic,strong) MCPeerID *localPeerID;
@end

@implementation BNRCommication


NSString * const kServerName         =       @"VOIP";


-(MCPeerID *)localPeerID{
    if (!_localPeerID) {
        _localPeerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];
    }
    return _localPeerID;
}
-(MCSession *)session{
    if (!_session) {
        _session = [[MCSession alloc] initWithPeer:self.localPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
        /**
         *  忽略这个警告，他的子类已经实现了MCSessionDelegate协议
         */
        _session.delegate = self;
    }
    return _session;
}

-(void)sendData:(NSData *)data{
    NSError *err;
    [self.session sendData:data toPeers:self.session.connectedPeers withMode:MCSessionSendDataReliable error:&err];
    if (err) {
        NSLog(@"there is error translate to data ");
        if ([self.delegate respondsToSelector:@selector(commication:sendDicFail:)]) {
            [self.delegate commication:self sendDicFail:err];
        }
    }
}

@end
