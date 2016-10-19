//
//  CFXNetworking.h
//  Pods
//
//  Created by xiaochengfei on 16/10/18.
//
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <JSONModel/JSONModel.h>

@class CFXAPIParams;

typedef void(^CFXSetParamsBlock)(CFXAPIParams *params);
typedef void(^CFXSuccessBlock)(id model, NSDictionary *dic);
typedef void(^CFXFailedBlock)(NSError *err);

typedef NS_ENUM(NSUInteger, CFXRequestType) {
    CFXGetRequestType,
    CFXPostRequestType
};


@interface CFXNetworking : NSOperation

/**
 *
 *  @param domain           set domain
 *  @param api              set api name
 *  @param type             get/post
 *  @param paramsBlock      set params
 *  @param jsonModelClass   if nil, the obj model in succBlock is nil
 *  @param succBlock        request succeed with result
 *  @param failBlock        request failed
 *  @param signal           when the signal sendNext with @0, succBlock/failBlock would not run
 */
+ (CFXNetworking *)requestWithDomain:(NSString *)domain
                             APIName:(NSString *)api
                                type:(CFXRequestType)type
                              params:(CFXSetParamsBlock)paramsBlock
                          modelClass:(Class)jsonModelClass
                             success:(CFXSuccessBlock)succBlock
                              failed:(CFXFailedBlock)failBlock
                           takeUntil:(RACSignal *)signal;

- (void)cancel;

@end



@interface CFXAPIParams : NSObject

@property (nonatomic, assign  ) NSInteger    timeOutInterval;
@property (nonatomic, assign  ) NSInteger    retryCount;
@property (nonatomic, assign  ) NSInteger    retryInterval;
@property (nonatomic, assign  ) BOOL         isSerialRequest;

- (void)addParamValue:(id)value forKey:(id)key;
- (void)addParamsDic:(NSDictionary*)dic;
- (void)setParamsDic:(NSDictionary*)dic;

@end

