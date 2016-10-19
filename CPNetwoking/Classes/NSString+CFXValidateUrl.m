//
//  NSString+CFXValidateUrl.m
//  Pods
//
//  Created by xiaochengfei on 16/10/18.
//
//

#import "NSString+CFXValidateUrl.h"

@implementation NSString (CFXValidateUrl)

- (BOOL)cfx_validateUrl {
    NSUInteger length = [self length];
    if (length) {
        NSError *error = nil;
        NSDataDetector *dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
        if (dataDetector && !error) {
            NSRange range = NSMakeRange(0, length);
            NSRange notFoundRange = (NSRange){NSNotFound, 0};
            NSRange linkRange = [dataDetector rangeOfFirstMatchInString:self options:0 range:range];
            if (!NSEqualRanges(notFoundRange, linkRange) && NSEqualRanges(range, linkRange)) {
                return YES;
            }
        }
    }
    return NO;
}

@end
