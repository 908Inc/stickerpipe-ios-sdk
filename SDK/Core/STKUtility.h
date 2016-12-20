//
//  STKUtility.h
//  StickerFactory
//
//  Created by Vadim Degterev on 26.06.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

@import UIKit;

@interface STKUtility : NSObject

+ (NSArray*)trimmedPackNameAndStickerNameWithMessage: (NSString*)message;
+ (NSString*)stickerIdWithMessage: (NSString*)message;

+ (NSString*)scaleString;
+ (NSString*)maxDensity;

//Colors
+ (UIColor*)defaultOrangeColor;
+ (UIColor*)defaultGreyColor;
+ (UIColor*)defaultPlaceholderGrayColor;
+ (UIColor*)defaultBlueColor;

+ (NSBundle*)getResourceBundle;
void STKLog(NSString* format, ...);


@end


@interface NSString(MD5String)
- (NSString *)MD5Digest;
@end


//--------Custom Bundle----------

@interface NSBundle (CustomBundle)
+ (NSBundle*)stkBundle;

+ (NSArray*)loadNibNamed: (NSString*)name owner: (id)owner options: (NSDictionary*)options;
@end

@interface UIViewController (CustomBundle)
+ (instancetype)viewControllerFromNib: (NSString*)nibNameOrNil;
@end
