//
//  BNRCommication.h
//  Game
//
//  Created by JustinYang on 15/9/21.
//  Copyright © 2015年 JustinYang. All rights reserved.
//


/**
 *  该头文件，定义通信过程中的宏和一些常变量
 */
typedef NS_ENUM(NSInteger,RoleType) {
    RoleTypeHost,
    RoleTypeClient,
};
#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@protocol BNRCommicationDelegate <NSObject>

@optional

-(void)commication:(id)commicaton didReceiveData:(NSData *)data fromPeerID:(MCPeerID *)peerID;


-(void)commication:(id)commication sendDicFail:(NSError *)error;
@end

@interface BNRCommication : NSObject


extern NSString * const kServerName;

@property(nonatomic, weak) id delegate;
@property(nonatomic, strong)MCSession *session;
@property(nonatomic, strong , readonly)MCPeerID *localPeerID;


-(void)sendData:(NSData *)data;

@end
