//
//  BNRPeripheralTVC.m
//  BleChatRoom
//
//  Created by JustinYang on 11/29/15.
//  Copyright © 2015 JustinYang. All rights reserved.
//

#import "BNRFindPeripheralVC.h"
#import "BNRBLECentral.h"
#import "BNRChatRoomVC.h"
#import <MBProgressHUD/MBProgressHUD.h>
@interface BNRFindPeripheralVC ()<BNRBLECentralDelegate>
@property (nonatomic,weak) BNRBLECentral *manager;
@end

@implementation BNRFindPeripheralVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
     self.clearsSelectionOnViewWillAppear = NO;
    self.manager = [BNRBLECentral sharedInstance];
    self.manager.delegate = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.manager scanPeripheralWithTimeOut:0];
    });
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - BNRBLECentralDelegate
-(void)discoverPeripherals{
    [self.tableView reloadData];
}
-(void)didConnectToPeripheral{
    
    [MBProgressHUD hideAllHUDsForView:self.view.window animated:YES];
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    BNRChatRoomVC *chatRoomVC = [sb instantiateViewControllerWithIdentifier:@"chatroom"];
    chatRoomVC.chatRoomType = ChatRoomTypeHost;
    [self.navigationController pushViewController:chatRoomVC animated:YES];
}

-(void)occurError:(NSError *)error{
    [MBProgressHUD hideAllHUDsForView:self.view.window animated:NO];
    MBProgressHUD *loadHUD = [MBProgressHUD showHUDAddedTo:self.view.window animated:YES];
    loadHUD.labelText = [NSString stringWithFormat:@"%@",error];
    [loadHUD hide:YES afterDelay:3];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.manager.peripherals.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSDictionary *peripheralDic = self.manager.peripherals[indexPath.row];
    CBPeripheral *peripheral = peripheralDic[@"peripheral"];
    NSNumber *rssi = peripheralDic[@"rssi"];
    cell.textLabel.text = peripheral.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@",rssi];
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [MBProgressHUD hideAllHUDsForView:self.view.window animated:NO];
    MBProgressHUD *loadHUD = [MBProgressHUD showHUDAddedTo:self.view.window animated:YES];
    loadHUD.labelText = @"connecting...";
    [self.manager connectPeralWithIndex:indexPath.row];
}


@end
