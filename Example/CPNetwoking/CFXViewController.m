//
//  CFXViewController.m
//  CPNetwoking
//
//  Created by xiaochengfei on 10/18/2016.
//  Copyright (c) 2016 xiaochengfei. All rights reserved.
//

#import "CFXViewController.h"
#import <CPNetwoking/CFXNetworking.h>
#import <CPNetwoking/UIViewController+CFXExtension.h>

@interface CFXViewController ()

@end

@implementation CFXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [CFXNetworking requestWithDomain:@"https://itunes.apple.com/"
                             APIName:@"lookup"
                                type:CFXGetRequestType
                              params:^(CFXAPIParams *params) {
                                [params addParamValue:@(507704613) forKey:@"id"];
                              }
                          modelClass:nil
                             success:^(id model, NSDictionary *dic) {
                               NSLog(@"model: %@ ,dic: %@",model,dic);
                             }failed:^(NSError *err) {
                               NSLog(@"%@",err);
                             }takeUntil:[self cfx_httpTakeUntilSignal]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
