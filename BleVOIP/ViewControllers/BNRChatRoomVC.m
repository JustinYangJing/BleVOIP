//
//  BNRChatRoomVC.m
//  BleVOIP
//
//  Created by JustinYang on 7/4/16.
//  Copyright © 2016 JustinYang. All rights reserved.
//

#import "BNRChatRoomVC.h"
#import "BNRBLECentral.h"
#import "BNRBLEPeripheral.h"
#import "VoiceConvertHandle.h"
#import <MBProgressHUD/MBProgressHUD.h>

@interface BNRChatRoomVC ()<BNRBLECentralDelegate,BNRBLEPeripheralDelegate,VoiceConvertHandleDelegate>
@property (nonatomic,weak) id manager;

@property (nonatomic)      BOOL connected;
@end

@implementation BNRChatRoomVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [VoiceConvertHandle shareInstance].delegate = self;
    if (self.chatRoomType == ChatRoomTypeHost) {
        self.manager = [BNRBLECentral sharedInstance];
        ((BNRBLECentral *)self.manager).delegate = self;
        self.connected = YES;
        
    }else if(self.chatRoomType == ChatRoomTypeClient){
        self.manager = [BNRBLEPeripheral sharedInstance];
        ((BNRBLEPeripheral *)self.manager).delegate = self;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [((BNRBLEPeripheral *)self.manager) startAdveritise];
        });
        MBProgressHUD *loadHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        loadHUD.labelText = @"广播中,等待Central连接";
    }

}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    [((BNRBLEPeripheral *)self.manager) stopAdveritise];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark --
-(void)occurError:(NSError *)error{
    [MBProgressHUD hideAllHUDsForView:self.view animated:NO];
    MBProgressHUD *loadHUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    loadHUD.labelText = [NSString stringWithFormat:@"%@",error];
    [loadHUD show:YES];
    [loadHUD hide:YES afterDelay:4];
}

-(void)receivedData:(NSData *)data{
//    [[VoiceConvertHandle shareInstance] playWithData:data];
    static int i = 0;
    i++;
    NSLog(@"接受%@次",@(i));
 
}
-(void)didConnectService{
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
    self.connected = YES;
}

#pragma mark - voice delegate
-(void)covertedData:(NSData *)data{
    if (self.connected) {
        if (self.chatRoomType == ChatRoomTypeClient) {
//            [((BNRBLEPeripheral *)self.manager) writeData:data];
        }else{
            [((BNRBLECentral *)self.manager) writeData:data];
            static int i = 0;
            i++;
            NSLog(@"发送%@次",@(i));
        }
    }
}
@end
