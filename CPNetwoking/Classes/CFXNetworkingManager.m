//
//  CFXNetworkingManager.m
//  Pods
//
//  Created by xiaochengfei on 16/10/18.
//
//

#import "CFXNetworkingManager.h"

@implementation CFXNetworkingManager

static CFXNetworkingManager *SINGLETON = nil;

#pragma mark - Public Method

+ (id)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SINGLETON = [[CFXNetworkingManager alloc] init];
    });
    return SINGLETON;
}

- (id) init {
    self = [super init];
    if (self) {
        self.maxOperationCount = 4;
    }
    return self;
}

- (NSOperationQueue *)cfxMainQueue {
    if (!_cfxMainQueue) {
        _cfxMainQueue = [[NSOperationQueue alloc] init];
        _cfxMainQueue.name = @"CFXRequest.mainQueue";
        [_cfxMainQueue setMaxConcurrentOperationCount:self.maxOperationCount];
    }
    return _cfxMainQueue;
}

- (void)addOperation:(NSOperation*)operation {
    if (!operation) {
        return;
    }
    [self.cfxMainQueue addOperation:operation];
}

@end
