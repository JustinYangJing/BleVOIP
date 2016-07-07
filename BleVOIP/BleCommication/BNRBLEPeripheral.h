//
//  BNRBLEPeripheral.h
//  BleChatRoom
//
//  Created by JustinYang on 11/29/15.
//  Copyright © 2015 JustinYang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BNRConstants.h"

@protocol BNRBLEPeripheralDelegate;

@interface BNRBLEPeripheral : NSObject
@property (nonatomic,weak) id <BNRBLEPeripheralDelegate>delegate;
+(instancetype)sharedInstance;
-(void)startAdveritise;
-(void)stopAdveritise;
-(void)writeData:(NSData *)data;
@end

@protocol BNRBLEPeripheralDelegate <NSObject>

@optional


-(void)occurError:(NSError *)error;

-(void)receivedData:(NSData *)data;

-(void)didConnectService;

@end
