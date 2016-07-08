//
//  BNRClient.h
//  Game
//
//  Created by JustinYang on 15/9/22.
//  Copyright © 2015年 JustinYang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BNRCommication.h"
@class BNRClient;

@protocol BNRClientDelegate <BNRCommicationDelegate>

@optional
-(void)client:(BNRClient *)client foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info;
-(void)client:(BNRClient *)client lostPeer:(MCPeerID *)peerID;

-(void)client:(BNRClient *)client connectServerStateChange:(MCSessionState)state;

@end


@interface BNRClient : BNRCommication

@property (nonatomic, weak) id <BNRClientDelegate> delegate;
@property (nonatomic) MCSessionState sessionState;
@property (nonatomic, copy) NSString *loadMsg;


+(instancetype)sharedInstance;
-(void)connectAvailableServer:(MCPeerID *)peer;
-(void)reConnect;

-(void)startSearchingServers;
-(void)stopSearchingServers;


@end
