//
//  BNRServer.h
//  Game
//
//  Created by JustinYang on 15/9/18.
//  Copyright © 2015年 JustinYang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BNRCommication.h"
@class BNRServer;
@protocol BNRServerDelegate <BNRCommicationDelegate>

@optional


/**
 *  当来自其他手机的peer连接状态发生变化时，调用此方法，以通知相应的代理
 *
 *  @param server self
 *  @param peerID 连接状态发生变化的peer
 *  @param state  peer的连接状态
 */
-(void)server:(BNRServer *)server peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state;


@end

@interface BNRServer : BNRCommication

@property (nonatomic, weak) id <BNRServerDelegate>delegate;
+(instancetype)sharedInstance;

/**
 *  广播服务
 *
 *  @param dic 字典包含命令号，游戏类型，游戏名称
 */
-(void)startAdvertiserWithDic:(NSDictionary *)dic;

/**
 *  停止广播连接
 */
-(void)stopAdvertiser;


@end
