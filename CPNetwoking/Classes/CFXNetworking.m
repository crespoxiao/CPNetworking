//
//  CFXNetworking.m
//  Pods
//
//  Created by xiaochengfei on 16/10/18.
//
//

#import "CFXNetworking.h"
#import "CFXNetworkingManager.h"
#import "NSString+CFXValidateUrl.h"
#import <objc/runtime.h>
#import <AFNetworking/AFNetworking.h>


#define CFXSafeBlockRun(block, ...)         block ? block(__VA_ARGS__) : nil

#ifdef DEBUG
#   define CFXLog(fmt, ...) NSLog((@"[CFXNetworking][%s][Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define CFXLog(...)
#endif



@interface CFXAPIParams ()

@property (nonatomic, strong) NSString     *domain;
@property (nonatomic, strong) NSString     *api_name;
@property (nonatomic, strong) NSMutableDictionary *params;

@end


@implementation CFXAPIParams

- (instancetype)init {
    self = [super init];
    if (self) {
        self.params = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)addParamValue:(id)value forKey:(id)key {
    [self.params setValue:value forKey:key];
}

- (void)addParamsDic:(NSDictionary*)dic {
    [self.params addEntriesFromDictionary:dic];
}

- (void)setParamsDic:(NSDictionary *)dic {
    [self.params setDictionary:dic];
}

@end




typedef void(^CFXSuccessRequestAPIBlock)(NSDictionary *respDic);
typedef void(^CFXFailedRequestAPIBlock)(NSError *err);
typedef NSInteger (^CFXRetryDelayCalcBlock)(NSInteger, NSInteger, NSInteger);

static inline BOOL CFXNetworking_isKindOfClass(Class parent, Class child) {
    for (Class cls = child; cls; cls = class_getSuperclass(cls)) {
        if (cls == parent) {
            return YES;
        }
    }
    return NO;
}

@interface CFXNetworking ()

@property (nonatomic, strong) CFXAPIParams        *apiParams;
@property (nonatomic, assign) CFXRequestType      requestType;
@property (nonatomic, strong) NSString            *modelClassString;
@property (nonatomic, assign) BOOL                isCallBackEnabled;
@property (nonatomic, copy  ) CFXSuccessBlock     succBlock;
@property (nonatomic, copy  ) CFXFailedBlock      failBlock;
//for retry
@property (nonatomic, strong) NSDictionary           *tasksDict;
@property (nonatomic, copy  ) CFXRetryDelayCalcBlock retryDelayCalcBlock;

@end


@implementation CFXNetworking

+ (CFXNetworking *)requestWithDomain:(NSString *)domain
                             APIName:(NSString *)api
                                type:(CFXRequestType)type
                              params:(CFXSetParamsBlock)paramsBlock
                          modelClass:(Class)jsonModelClass
                             success:(CFXSuccessBlock)succBlock
                              failed:(CFXFailedBlock)failBlock
                           takeUntil:(RACSignal *)signal {
    
    CFXNetworking *requestAPI = [[CFXNetworking alloc] init];
    
    CFXAPIParams *tmpParams = [[CFXAPIParams alloc] init];
    tmpParams.domain = domain;
    tmpParams.api_name = api;
    CFXSafeBlockRun(paramsBlock, tmpParams);
    if (!tmpParams.timeOutInterval) {
        tmpParams.timeOutInterval = 10;
    }
    requestAPI.apiParams = tmpParams;
    requestAPI.requestType = type;
    requestAPI.succBlock = succBlock;
    requestAPI.failBlock = failBlock;
    if (jsonModelClass) {
        requestAPI.modelClassString = NSStringFromClass(jsonModelClass);
    }
    if (signal) {
        [[signal takeUntil:[requestAPI rac_willDeallocSignal]] subscribeNext:^(id x) {
            if (x && [x isKindOfClass:[NSNumber class]]) {
                requestAPI.isCallBackEnabled = [x integerValue];
            }
        }];
    }
    if (requestAPI.apiParams.isSerialRequest) {
        for (CFXNetworking * op in [CFXNetworkingManager sharedInstance].cfxMainQueue.operations) {
            if (!op.isFinished && !op.isCancelled && [requestAPI.apiParams.api_name isEqualToString:op.apiParams.api_name]) {
                [requestAPI failedForException];
                return requestAPI;
            }
        }
    }
    [requestAPI startRequest];
    return requestAPI;
}

#pragma mark - life cycle

- (instancetype)init{
    self = [super init];
    if (self) {
        self.isCallBackEnabled = YES;
    }
    return self;
}

- (void)main {
    @autoreleasepool {
        if(self.isCancelled){
            return;
        }
        
        [self requestWithAutoRetry:self.apiParams.retryCount
                     retryInterval:self.apiParams.retryInterval
                           timeOut:self.apiParams.timeOutInterval];
    }
}

- (void)startRequest {
    @weakify(self);
    [[CFXNetworkingManager sharedInstance]addOperation:(NSOperation*)self_weak_];
}

- (void)cancel {
    [super cancel];
}

#pragma mark - getter

- (NSDictionary *)tasksDict {
    if (!_tasksDict) {
        _tasksDict = [NSDictionary dictionary];
    }
    return _tasksDict;
}

- (CFXRetryDelayCalcBlock)retryDelayCalcBlock {
    if (!_retryDelayCalcBlock) {
        _retryDelayCalcBlock = ^NSInteger(NSInteger totalRetries, NSInteger currentRetry, NSInteger delayInSecondsSpecified) {
            return delayInSecondsSpecified;
        };
    }
    return _retryDelayCalcBlock;
}

#pragma mark - retry

- (NSURLSessionDataTask *)requestUrlWithAutoRetry:(NSInteger)retriesRemaining
                                        retryInterval:(NSInteger)intervalInSeconds
                               originalRequestCreator:(NSURLSessionDataTask *(^)
                                                       (void (^)(NSURLSessionDataTask *requestTask, NSError *requestError)))taskCreator
                                      originalFailure:(void(^)(NSURLSessionDataTask *failTask, NSError *failError))failure {
    id taskcreatorCopy = [taskCreator copy];
    void(^retryBlock)(NSURLSessionDataTask *, NSError *) = ^(NSURLSessionDataTask *task, NSError *error) {
        NSMutableDictionary *retryOperationDict = self.tasksDict[[NSString stringWithFormat:@"task_address_%lu",(unsigned long)[task hash]]];
        NSInteger originalRetryCount = [retryOperationDict[@"originalRetryCount"] integerValue];
        NSInteger retriesRemainingCount = [retryOperationDict[@"retriesRemainingCount"] integerValue];
        if (retriesRemainingCount > 0) {
            CFXLog(@"AutoRetry: Request failed: %@, retry %ld out of %ld begining...",
                   error.localizedDescription, (long)(originalRetryCount - retriesRemainingCount + 1), (long)originalRetryCount);
            void (^addRetryOperation)() = ^{
                [self requestUrlWithAutoRetry:retriesRemaining - 1
                                    retryInterval:intervalInSeconds
                           originalRequestCreator:taskCreator
                                  originalFailure:failure];
            };
            CFXRetryDelayCalcBlock delayCalc = self.retryDelayCalcBlock;
            NSInteger intervalToWait = delayCalc(originalRetryCount, retriesRemainingCount, intervalInSeconds);
            if (intervalToWait > 0) {
                CFXLog(@"AutoRetry: Delaying retry for %ld seconds...", (long)intervalToWait);
                dispatch_time_t delay = dispatch_time(0, (int64_t)(intervalToWait * NSEC_PER_SEC));
                dispatch_after(delay, dispatch_get_main_queue(), ^(void){
                    addRetryOperation();
                });
            } else {
                addRetryOperation();
            }
        } else {
            CFXLog(@"AutoRetry: Request failed %ld times: %@", (long)originalRetryCount, error.localizedDescription);
            failure(task, error);
            CFXLog(@"AutoRetry: done.");
        }
    };
    
    NSURLSessionDataTask *task = taskCreator(retryBlock);
    NSMutableDictionary *taskDict = self.tasksDict[taskcreatorCopy];
    if (!taskDict) {
        taskDict = [NSMutableDictionary dictionary];
        taskDict[@"originalRetryCount"] = @(retriesRemaining);
    }
    taskDict[@"retriesRemainingCount"] = @(retriesRemaining);
    NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithDictionary:self.tasksDict];
    newDict[[NSString stringWithFormat:@"task_address_%p",task]] = taskDict;
    self.tasksDict = newDict;
    return task;
}

#pragma mark - Reuqest method

- (void)failedForException {
    if (self.isCallBackEnabled) {
        NSError *error = [self checkErrorWithResDic:nil];//server 4xx/5xx
        if (error) {
            CFXSafeBlockRun(self.failBlock,error);
        }
    }
}

- (NSURLSessionDataTask *)requestWithAutoRetry:(NSInteger)retryCount
                                 retryInterval:(NSInteger)interval
                                       timeOut:(NSUInteger)timeOut {
    if (!self.apiParams.domain || ![self.apiParams.domain length]) {
        [self failedForException];
        return nil;
    }
    if (!self.apiParams.api_name || ![self.apiParams.api_name length]) {
        [self failedForException];
        return nil;
    }
    NSString *apiPath = [self.apiParams.domain stringByAppendingString:self.apiParams.api_name];
    if (![apiPath cfx_validateUrl]) {
        [self failedForException];
        return nil;
    }
    
    return [self requestWithAPIPath:apiPath type:self.requestType params:self.apiParams.params success:^(NSDictionary *respDic) {
        NSError *error = [self checkErrorWithResDic:respDic];
        if (error) {
            if (self.isCallBackEnabled) {
                CFXSafeBlockRun(self.failBlock,error);
            }
        } else {
            id model;
            BOOL isSuccessCallBack = NO;
            if (self.modelClassString) {
                Class jsonModelClass = NSClassFromString(self.modelClassString);
                model = [[jsonModelClass alloc]init];
                if ([model isKindOfClass:[JSONModel class]]) {
                    if (respDic && [respDic isKindOfClass:[NSDictionary class]]) {
                        model = [self transferResDataToModel:respDic];
                        if (model) {
                            isSuccessCallBack = YES;
                        }
                    }
                }
            } else if (respDic && [respDic isKindOfClass:[NSDictionary class]]) {
                isSuccessCallBack = YES;
            }
            if (self.isCallBackEnabled) {
                if (isSuccessCallBack) {
                    CFXSafeBlockRun(self.succBlock,model,respDic);
                } else {
                    [self failedForException];
                }
            }
        }
    } failed:^(NSError *err) {
        if (self.isCallBackEnabled) {
            CFXSafeBlockRun(self.failBlock,err);
        }
    } autoRetry:retryCount retryInterval:interval timeOut:timeOut];
}

#pragma mark - private methods

- (NSURLSessionDataTask *)requestWithAPIPath:(NSString *)apiPath
                                        type:(CFXRequestType)type
                                      params:(NSDictionary *)paramsDic
                                     success:(CFXSuccessRequestAPIBlock)succ
                                      failed:(CFXFailedRequestAPIBlock)fail
                                   autoRetry:(NSUInteger)retryCount
                               retryInterval:(NSUInteger)interval
                                     timeOut:(NSUInteger)timeOut {
    
    
    // upload if contains files
    if (type == CFXPostRequestType) {
        NSInteger uploadFiles = 0;
        for (NSString *key in [paramsDic allKeys]){
            id value = paramsDic[key];
            if ([value isKindOfClass:[NSData class]]){
                uploadFiles += 1;
            }
        }
        if (uploadFiles) {
            //post multipart/form-data
            return [self uploadMultiPartFileWithAPIPath:apiPath params:paramsDic success:^(NSDictionary *respDic) {
                CFXSafeBlockRun(succ,respDic);
            } failed:^(NSError *err) {
                CFXSafeBlockRun(fail,err);
            } autoRetry:retryCount retryInterval:interval timeOut:timeOut];
        }
    }
    
    // normal http request
    AFHTTPSessionManager   *httpClient = [AFHTTPSessionManager manager];
    if (timeOut > 2 && timeOut < 30) {
        httpClient.requestSerializer.timeoutInterval = timeOut;
    } else {
        httpClient.requestSerializer.timeoutInterval = 30.0f;
    }
    if (type == CFXPostRequestType) {
        return [self requestUrlWithAutoRetry:retryCount retryInterval:interval originalRequestCreator:^NSURLSessionDataTask *(void (^retryBlock)(NSURLSessionDataTask *requestTask, NSError *requestError)) {
            return [httpClient POST:apiPath parameters:paramsDic progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
                if ([responseObject isKindOfClass:[NSDictionary class]]){
                    NSString *jsonStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:responseObject options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
                    CFXLog(@"success GET callback\n api request url is %@,\n response data is %@",task.response.URL,jsonStr?:@"");
                }
                NSDictionary *dic = [responseObject isKindOfClass:[NSDictionary class]] ? responseObject : nil;
                CFXSafeBlockRun(succ,dic);
            } failure:retryBlock];
        } originalFailure:^(NSURLSessionDataTask *failTask, NSError *failError) {
            CFXLog(@"api request url is %@,\n response data is %@",failTask.response.URL,failError);
            CFXSafeBlockRun(fail,failError);
        }];
    } else if (type == CFXGetRequestType) {
        return [self requestUrlWithAutoRetry:retryCount retryInterval:interval originalRequestCreator:^NSURLSessionDataTask *(void (^retryBlock)(NSURLSessionDataTask *requestTask, NSError *requestError)) {
            return [httpClient GET:apiPath parameters:paramsDic progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nonnull responseObject) {
                if ([responseObject isKindOfClass:[NSDictionary class]]){
                    NSString *jsonStr = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:responseObject options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
                    CFXLog(@"success GET callback\n api request url is %@,\n response data is %@",task.response.URL,jsonStr?:@"");
                }
                NSDictionary *dic = [responseObject isKindOfClass:[NSDictionary class]] ? responseObject : nil;
                CFXSafeBlockRun(succ,dic);
            } failure:retryBlock];
        } originalFailure:^(NSURLSessionDataTask *failTask, NSError *failError) {
            CFXLog(@"api request url is %@,\n response data is %@",failTask.response.URL,failError);
            CFXSafeBlockRun(fail,failError);
        }];
    } else {
        return nil;
    }
}

#pragma mark - upload files

- (NSURLSessionUploadTask *)uploadMultiPartFileWithAPIPath:(NSString *)apiPath
                                                    params:(NSDictionary *)paramsDic
                                                   success:(CFXSuccessRequestAPIBlock)succ
                                                    failed:(CFXFailedRequestAPIBlock)fail
                                                 autoRetry:(NSUInteger)retryCount
                                             retryInterval:(NSUInteger)interval
                                                   timeOut:(NSUInteger)timeOut {
    
    NSMutableDictionary *dicWithOutUploadKeyValue = [self filterData:paramsDic];
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:apiPath parameters:dicWithOutUploadKeyValue constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        for (NSString *key in [paramsDic allKeys]){
            id value = paramsDic[key];
            if ([value isKindOfClass:[NSData class]]){
                // image/jpeg、text/plain、text/html、application/octet-stream
                [formData appendPartWithFileData:value name:key fileName:[NSString stringWithFormat:@"%@.jpg", key] mimeType:@"image/jpeg"];
            }
        }
    } error:nil];
    
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionUploadTask *uploadtask = [manager
                                          uploadTaskWithStreamedRequest:request
                                          progress:nil
                                          completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                              if (error) {
                                                  CFXLog(@"api request url is %@,\n response data is %@",response.URL,error);
                                                  CFXSafeBlockRun(fail,error);
                                              } else {
                                                  CFXLog(@"api request url is %@,\n response data is %@",response.URL,responseObject);
                                                  CFXSafeBlockRun(succ,responseObject);
                                              }
                                          }];
    [uploadtask resume];
    
    return uploadtask;
}

#pragma mark -

- (id)transferResDataToModel:(NSDictionary *)data {
    JSONModel *model;
    if (self.modelClassString) {
        Class jsonModelClass = NSClassFromString(self.modelClassString);
        if (jsonModelClass) {
            if (CFXNetworking_isKindOfClass([JSONModel class], jsonModelClass)) {
                JSONModelError *err;
                model = [[jsonModelClass alloc] initWithDictionary:data error:&err];
                CFXLog(@"%ld %@",(long)err.code,err.localizedDescription);
            }
        }
    }
    return model;
}

- (NSError *)checkErrorWithResDic:(NSDictionary *)dic {
    if (dic && [dic isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSUInteger errorNo = 10001;
    NSString *errorMsg = @"";
    NSError *error = [NSError errorWithDomain:@"com.cfx.api"
                                         code:errorNo
                                     userInfo:@{ @"errMsg": errorMsg?:@""}];
    return error;
}

- (NSMutableDictionary *)filterData:(NSDictionary *)originalDic {
    if (!originalDic) {
        return nil;
    }
    NSMutableDictionary *tempDic = [NSMutableDictionary dictionaryWithDictionary:originalDic];
    NSMutableArray *tmArray = [NSMutableArray array];
    
    for (NSString *key in [tempDic allKeys]){
        id value = tempDic[key];
        if ([value isKindOfClass:[NSData class]]){
            [tmArray addObject:key];
        }
    }
    if ([tmArray count]) {
        for (NSString* key in tmArray) {
            [tempDic removeObjectForKey:key];
        }
    }
    return tempDic;
}

@end
