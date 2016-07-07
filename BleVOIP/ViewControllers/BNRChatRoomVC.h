//
//  BNRChatRoomVC.h
//  BleVOIP
//
//  Created by JustinYang on 7/4/16.
//  Copyright © 2016 JustinYang. All rights reserved.
//

#import <UIKit/UIKit.h>
typedef NS_ENUM(NSInteger,ChatRoomType) {
    /**
     *  设备作为CBCentralManager端
     */
    ChatRoomTypeHost,
    /**
     *  设备作为CBPeripheralManager端
     */
    ChatRoomTypeClient
};

@interface BNRChatRoomVC : UIViewController
@property (nonatomic) ChatRoomType chatRoomType;
@end
