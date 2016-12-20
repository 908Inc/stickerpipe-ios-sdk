//
//  UIImageView+Stickers.m
//  StickerFactory
//
//  Created by Vadim Degterev on 24.06.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "UIImageView+Stickers.h"
#import "STKUtility.h"
#import <objc/runtime.h>
#import "UIImage+Tint.h"
#import "STKImageManager.h"
#import "UIImageView+WebCache.h"
#import "UIImage+CustomBundle.h"
#import "helper.h"


@interface UIImageView ()

@property (nonatomic) STKImageManager* imageManager;

@end

@implementation UIImageView (Stickers)

#pragma mark - Builder

- (void)stk_setStickerWithMessage: (NSString*)stickerMessage completion: (STKCompletionBlock)completion {
	[self stk_setStickerWithMessage: stickerMessage placeholder: nil placeholderColor: nil progress: nil completion: completion];
}

- (void)stk_setStickerWithMessage: (NSString*)stickerMessage placeholder: (UIImage*)placeholder {
	[self stk_setStickerWithMessage: stickerMessage placeholder: placeholder placeholderColor: nil progress: nil completion: nil];
}

- (void)stk_setStickerWithMessage: (NSString*)stickerMessage placeholder: (UIImage*)placeholder completion: (STKCompletionBlock)completion {
	[self stk_setStickerWithMessage: stickerMessage placeholder: placeholder placeholderColor: nil progress: nil completion: completion];
}


#pragma mark - Sticker Download

- (void)stk_setStickerWithMessage: (NSString*)stickerMessage
					  placeholder: (UIImage*)placeholder
				 placeholderColor: (UIColor*)placeholderColor
						 progress: (STKDownloadingProgressBlock)progressBlock
					   completion: (STKCompletionBlock)completion {

	UIImage* placeholderImage = nil;
	if (!placeholder) {
		UIImage *defaultPlaceholder = nil;

		if (FRAMEWORK) {
			defaultPlaceholder = [UIImage imageNamedInCustomBundle: @"STKStickerPlaceholder"];
		} else {
			defaultPlaceholder = [UIImage imageNamed: @"STKStickerPlaceholder"];
		}

		if (placeholderColor) {
			defaultPlaceholder = [defaultPlaceholder imageWithImageTintColor: placeholderColor];
		} else {
			defaultPlaceholder = [defaultPlaceholder imageWithImageTintColor: [STKUtility defaultPlaceholderGrayColor]];
		}
		placeholderImage = defaultPlaceholder;
	} else {
		placeholderImage = placeholder;
	}

	self.image = placeholderImage;
	[self setNeedsLayout];

	self.imageManager = [STKImageManager new];

	typeof(self) __weak weakSelf = self;

	[self.imageManager getImageForStickerMessage: stickerMessage
									withProgress: progressBlock
								   andCompletion: ^ (NSError* error, UIImage* stickerImage) {
									   dispatch_async(dispatch_get_main_queue(), ^ {
										   weakSelf.image = stickerImage;
										   [weakSelf setNeedsLayout];
									   });

									   if (error && error.code != -1) {
										   STKLog(@"Failed loading from category: %@", error.localizedDescription);
									   }
								   }];
}


#pragma mark - Properties

- (STKImageManager*)imageManager {
	return objc_getAssociatedObject(self, @selector(imageManager));
}

- (void)setImageManager: (STKImageManager*)imageManager {
	objc_setAssociatedObject(self, @selector(imageManager), imageManager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


#pragma mark - Stop loading

- (void)stk_cancelStickerLoading {
	[self.imageManager cancelLoading];
}

- (void)stk_cancelStickerImageLoading: (UIImageView*)stickerImageView {
	[stickerImageView sd_cancelCurrentAnimationImagesLoad];
}

@end
