# CPNetwoking

[![CI Status](http://img.shields.io/travis/xiaochengfei/CPNetwoking.svg?style=flat)](https://travis-ci.org/xiaochengfei/CPNetwoking)
[![Version](https://img.shields.io/cocoapods/v/CPNetwoking.svg?style=flat)](http://cocoapods.org/pods/CPNetwoking)
[![License](https://img.shields.io/cocoapods/l/CPNetwoking.svg?style=flat)](http://cocoapods.org/pods/CPNetwoking)
[![Platform](https://img.shields.io/cocoapods/p/CPNetwoking.svg?style=flat)](http://cocoapods.org/pods/CPNetwoking)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements
iOS8+

## Installation

CPNetwoking is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "CPNetwoking"
```

## Guide

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


check the dependency info below. if the version is defferent in the Podfile of your project, just clone this repo and add floder CPNetwoking to you project.

    s.dependency 'AFNetworking', '~> 3.1.0'
    s.dependency 'ReactiveCocoa', '~> 2.5'
    s.dependency 'JSONModel', '~> 1.7.0'
    
## Author

CrespoXiao <http://weibo.com/crespoxiao>

## License

CPNetwoking is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
