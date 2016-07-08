//
//  BNRMainVC.m
//  BleVOIP
//
//  Created by JustinYang on 7/4/16.
//  Copyright © 2016 JustinYang. All rights reserved.
//

#import "BNRMainVC.h"
#import "BNRCommication.h"
#import "BNRConnectVC.h"
@interface BNRMainVC ()

@end

@implementation BNRMainVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)pushToConnectVC:(UIButton *)sender {
    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    BNRConnectVC *vc = [sb instantiateViewControllerWithIdentifier:@"connectVC"];
    if ([sender.currentTitle isEqualToString:@"Host"]) {
        vc.roleType = RoleTypeHost;
    }else{
        vc.roleType = RoleTypeClient;
    }
    [self.navigationController pushViewController:vc animated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
