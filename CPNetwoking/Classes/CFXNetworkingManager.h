//
//  CFXNetworkingManager.h
//  Pods
//
//  Created by xiaochengfei on 16/10/18.
//
//

#import <Foundation/Foundation.h>

@interface CFXNetworkingManager : NSObject

@property (nonatomic, strong) NSOperationQueue *cfxMainQueue;
@property (nonatomic, assign) NSInteger maxOperationCount;

+ (CFXNetworkingManager*)sharedInstance;

- (void)addOperation:(NSOperation*)operation;

@end
