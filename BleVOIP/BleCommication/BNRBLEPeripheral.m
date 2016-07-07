//
//  BNRBLEPeripheral.m
//  BleChatRoom
//
//  Created by JustinYang on 11/29/15.
//  Copyright © 2015 JustinYang. All rights reserved.
//

#import "BNRBLEPeripheral.h"

@interface BNRBLEPeripheral ()<CBPeripheralManagerDelegate>
@property (nonatomic,strong) CBPeripheralManager *manager;
@property (nonatomic,strong) CBMutableService *myService;
@property (nonatomic,strong) CBMutableCharacteristic *myWriteChara;
@property (nonatomic,strong) CBMutableCharacteristic *myReadChara;
@end
@implementation BNRBLEPeripheral
+(instancetype)sharedInstance{
    static BNRBLEPeripheral *blePeripheral = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blePeripheral = [[BNRBLEPeripheral alloc] init];
        blePeripheral.manager = [[CBPeripheralManager alloc] initWithDelegate:blePeripheral queue:nil];
    });
    return blePeripheral;
}

-(void)startAdveritise{
    self.myReadChara = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kReadCharUUID]
                                                          properties:CBCharacteristicPropertyRead|CBCharacteristicPropertyNotify
                                                               value:nil
                                                         permissions:CBAttributePermissionsReadable];
    self.myWriteChara = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:kWriteCharUUID]
                                                           properties:CBCharacteristicPropertyWriteWithoutResponse
                                                                value:nil
                                                          permissions:CBAttributePermissionsWriteable];
    self.myService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:kSeriversUUID] primary:YES];
    self.myService.characteristics = @[self.myWriteChara,self.myReadChara];
    [self.manager addService:self.myService];
}

-(void)stopAdveritise{
    [self.manager stopAdvertising];
}
-(void)writeData:(NSData *)data{
//    self.myReadChara.value = data;
    [self.manager updateValue:data forCharacteristic:self.myReadChara onSubscribedCentrals:nil];
}
#pragma mark - CBPeripheralManager delegate
-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral{
    NSLog(@"Peripheral stata chage to %@",@(peripheral.state));
}
-(void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error{
    if (error) {
        if ([self.delegate respondsToSelector:@selector(occurError:)]) {
            [self.delegate occurError:error];
        }
        return;
    }
    
    [self.manager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey:@[self.myService.UUID],
                                     CBAdvertisementDataLocalNameKey:@"VOIP"}];
}

-(void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error{
    if (error) {
        if ([self.delegate respondsToSelector:@selector(occurError:)]) {
            [self.delegate occurError:error];
        }
        return;
    }
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic{
    NSLog(@"the %@ notify my charateristic with %@",central.identifier.UUIDString , characteristic.UUID.UUIDString);
    [self stopAdveritise];
    if ([self.delegate respondsToSelector:@selector(didConnectService)]) {
        [self.delegate didConnectService];
    }
    
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request{
    if ([request.characteristic.UUID isEqual:self.myReadChara.UUID]) {
        NSString *str = [NSString stringWithFormat:@"我还在线 rand%d",arc4random()%100];
        request.value = [str dataUsingEncoding:NSUTF8StringEncoding];
        [self.manager respondToRequest:request withResult:CBATTErrorSuccess];
    }
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests{
    for (CBATTRequest *request in requests) {
        if ([request.characteristic.UUID isEqual:self.myWriteChara.UUID]) {
//            self.myReadChara.value = request.value;
            if ([self.delegate respondsToSelector:@selector(receivedData:)]) {
                [self.delegate receivedData:request.value];
            }
            [self.manager respondToRequest:request withResult:CBATTErrorSuccess];
        }
    }
}
@end
