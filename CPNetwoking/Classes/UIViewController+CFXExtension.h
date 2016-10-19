//
//  UIViewController+CFXExtension.h
//  Pods
//
//  Created by xiaochengfei on 16/10/18.
//
//

#import <UIKit/UIKit.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface UIViewController (CFXExtension)

- (RACSignal *)cfx_httpTakeUntilSignal;

@end
