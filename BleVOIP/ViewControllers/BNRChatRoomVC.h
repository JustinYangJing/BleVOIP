//
//  BNRChatRoomVC.h
//  BleVOIP
//
//  Created by JustinYang on 7/4/16.
//  Copyright © 2016 JustinYang. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface BNRChatRoomVC : UIViewController
@property (nonatomic) RoleType roleType;
@property (nonatomic,weak) BNRCommication *manager;
@end
