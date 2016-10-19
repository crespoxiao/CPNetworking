//
//  UIViewController+CFXExtension.m
//  Pods
//
//  Created by xiaochengfei on 16/10/18.
//
//

#import "UIViewController+CFXExtension.h"

@implementation UIViewController (CFXExtension)

- (RACSignal *)cfx_httpTakeUntilSignal {
    
    @weakify(self);
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        @strongify(self);
        RACDisposable *viewWillDisappearSignal = [[self rac_signalForSelector:@selector(viewWillDisappear:)]subscribeNext:^(id x) {
            [subscriber sendNext:@0];
        }];
        RACDisposable *viewWillAppearSignal = [[self rac_signalForSelector:@selector(viewWillAppear:)]subscribeNext:^(id x) {
            [subscriber sendNext:@1];
        }];
        [self.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
            [subscriber sendCompleted];
        }]];
        return [RACDisposable disposableWithBlock:^{
            [viewWillDisappearSignal dispose];
            [viewWillAppearSignal dispose];
        }];
    }];
}

@end
