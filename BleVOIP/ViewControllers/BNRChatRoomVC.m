//
//  BNRChatRoomVC.m
//  BleVOIP
//
//  Created by JustinYang on 7/4/16.
//  Copyright © 2016 JustinYang. All rights reserved.
//

#import "BNRChatRoomVC.h"
#import "VoiceConvertHandle.h"
#import "BNRClient.h"
#import "BNRServer.h"
#import <MBProgressHUD/MBProgressHUD.h>

@interface BNRChatRoomVC ()<BNRServerDelegate,BNRClientDelegate,VoiceConvertHandleDelegate>

@end

@implementation BNRChatRoomVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [VoiceConvertHandle shareInstance].delegate = self;
    self.manager.delegate = self;
}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)realRecordVoiceHandle:(UIButton *)sender {
    if ([sender.currentTitle isEqualToString:@"开始通话"]) {
        [VoiceConvertHandle shareInstance].startRecord = YES;
        [sender setTitle:@"停止通话" forState:UIControlStateNormal];
    }else{
        [VoiceConvertHandle shareInstance].startRecord = NO;
        [sender setTitle:@"开始通话" forState:UIControlStateNormal];
    }
}


#pragma mark -- BNRClientDelegate
-(void)commication:(id)commicaton didReceiveData:(NSData *)data fromPeerID:(MCPeerID *)peerID{
    [[VoiceConvertHandle shareInstance] playWithData:data];
}

-(void)server:(BNRServer *)server peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state{
    if (self.roleType == RoleTypeClient) {
        if (state == MCSessionStateNotConnected) {
            [(BNRClient *)self.manager reConnect];
        }
    }
}

-(void)client:(BNRClient *)client foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info{

}
//如何客户端监测到断开了，再去重新连接
-(void)client:(BNRClient *)client connectServerStateChange:(MCSessionState)state{
    
}
#pragma mark - voice delegate
-(void)covertedData:(NSData *)data{

    [self.manager sendData:data];
}
@end
