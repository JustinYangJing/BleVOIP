//
//  BNRBLECentral.m
//  BleChatRoom
//
//  Created by JustinYang on 11/29/15.
//  Copyright © 2015 JustinYang. All rights reserved.
//

#import "BNRBLECentral.h"
@interface BNRBLECentral()<CBCentralManagerDelegate, CBPeripheralDelegate>
@property (nonatomic,strong) CBCentralManager *manager;
@property (nonatomic,strong) CBPeripheral *connectedPeripheral;
@property (nonatomic,strong) CBCharacteristic *writeChara;
@property (nonatomic,strong) CBCharacteristic *readChara;

@end

@implementation BNRBLECentral
{
    NSMutableArray *_peripherals;
}
+(instancetype)sharedInstance{
    static BNRBLECentral *bleCentral = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bleCentral = [[BNRBLECentral alloc] init];
        bleCentral->_peripherals = [NSMutableArray array];
        bleCentral.manager = [[CBCentralManager alloc] initWithDelegate:bleCentral queue:nil];
    });
    return bleCentral;
}


-(NSArray *)peripherals{
    return _peripherals;
}


#pragma mark - func
/**
 *  <#Description#>
 *
 *  @param timeOut the 0 value is never time out with scanning
 */
-(void)scanPeripheralWithTimeOut:(NSInteger)timeOut{
    [self.manager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:kSeriversUUID]]
                                         options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
    if (timeOut > 0) {
         [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stopScan) object:nil];
        [self performSelector:@selector(stopScan) withObject:nil afterDelay:timeOut];
    }
}

-(void)stopScan{
    [self.manager stopScan];
}
-(void)connectPeralWithIndex:(NSInteger)index{
    NSDictionary *peripheralDic = _peripherals[index];
    CBPeripheral *peripheral = peripheralDic [@"peripheral"];
    [self.manager connectPeripheral:peripheral options:nil];
}

-(void)writeData:(NSData *)data{
    [self.connectedPeripheral writeValue:data forCharacteristic:self.writeChara type:CBCharacteristicWriteWithoutResponse];
}

-(void)askRead{
    [self.connectedPeripheral readValueForCharacteristic:self.readChara];
}
#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central{
    NSLog(@"The state of core bluetooth changed on central side :%@",@(central.state));
}


-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI{
    NSLog(@"adverisementData:%@",advertisementData);
    for (int i = 0; i < _peripherals.count; i++) {
        NSDictionary *peripheralDic = _peripherals[i];
        CBPeripheral *oldPeripheral = peripheralDic[@"peripheral"];
        if (oldPeripheral.identifier == nil || peripheral.identifier == nil) {
            continue;
        }
        if ([oldPeripheral.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
            NSNumber *previousRssi = peripheralDic[@"rssi"];
            _peripherals[i] = @{@"peripheral":peripheral,@"rssi":RSSI};
            if (previousRssi.integerValue != RSSI.integerValue) {
                if ([self.delegate respondsToSelector:@selector(discoverPeripherals)]) {
                    [self.delegate discoverPeripherals];
                }
            }
            return;
        }
    }
    NSDictionary *dic = @{@"peripheral":peripheral,@"rssi":RSSI};
    [_peripherals addObject:dic];
    if ([self.delegate respondsToSelector:@selector(discoverPeripherals)]) {
        [self.delegate discoverPeripherals];
    }
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    NSLog(@"%@ is already connected \n then ,should go to discovery speci server and charatiser ",peripheral.name);
    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kSeriversUUID]]];
}

#pragma mark - CBPeripheraldelegate
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    if (error) {
        if ([self.delegate respondsToSelector:@selector(occurError:)]) {
            [self.delegate occurError:error];
        }
        return;
    }
    for (CBService *service in peripheral.services) {
        if ([service.UUID.UUIDString isEqualToString:kSeriversUUID]) {
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:kWriteCharUUID],[CBUUID UUIDWithString:kReadCharUUID]] forService:service];
        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    if (error) {
        if ([self.delegate respondsToSelector:@selector(occurError:)]) {
            [self.delegate occurError:error];
        }
        return;
    }
    int count = 0;
    for (CBCharacteristic *charac in service.characteristics) {
        
        if ([charac.UUID.UUIDString isEqualToString:kReadCharUUID]) {
            [peripheral setNotifyValue:YES forCharacteristic:charac];
            self.readChara = charac;
            count++;
        }else if([charac.UUID.UUIDString isEqualToString:kWriteCharUUID]){
            self.writeChara = charac;
            count++;
        }
    }
    if (count == 2) {
        self.connectedPeripheral = peripheral;
        [self stopScan];
        if ([self.delegate respondsToSelector:@selector(didConnectToPeripheral)]) {
            [self.delegate didConnectToPeripheral];
        }
    }else{
        NSError *error = [NSError errorWithDomain:@"未发现相应的读写特征值" code:-1 userInfo:nil];
        if ([self.delegate respondsToSelector:@selector(occurError:)]) {
            [self.delegate occurError:error];
        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    NSLog(@"%@ isNotifying %@",characteristic.UUID.UUIDString,@(characteristic.isNotifying));
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (!error) {
        NSLog(@"write success");
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        if ([self.delegate respondsToSelector:@selector(occurError:)]) {
            [self.delegate occurError:error];
        }
        return;
    }
    if ([self.delegate respondsToSelector:@selector(receivedData:)]) {
        [self.delegate receivedData:characteristic.value];
    }
}
@end
