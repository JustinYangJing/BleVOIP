//
//  BNRBLECentral.h
//  BleChatRoom
//
//  Created by JustinYang on 11/29/15.
//  Copyright © 2015 JustinYang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BNRConstants.h"
@protocol   BNRBLECentralDelegate;
@interface BNRBLECentral : NSObject
/**
 *  数组中存放字典，字典包含单个的peripheral和这个peripheral所对应的信号
 *  key:peripheral,rssi
 */
@property (nonatomic,readonly) NSArray <NSDictionary<NSString *, id> *>*peripherals;
@property (nonatomic, weak)    id<BNRBLECentralDelegate> delegate;

+(instancetype)sharedInstance;

-(void)scanPeripheralWithTimeOut:(NSInteger)timeOut;
-(void)stopScan;
-(void)connectPeralWithIndex:(NSInteger)index;

-(void)writeData:(NSData *)data;
-(void)askRead;
@end

@protocol BNRBLECentralDelegate <NSObject>

@optional
-(void)discoverPeripherals;
-(void)didConnectToPeripheral;

-(void)occurError:(NSError *)error;

-(void)receivedData:(NSData *)data;
@end
