//
//  STKStickerPanelHeaderCell.m
//  StickerFactory
//
//  Created by Vadim Degterev on 08.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import <DFImageManager/DFImageTask.h>
#import <DFImageManager/DFImageRequestOptions.h>
#import <DFImageManager/DFImageRequest.h>
#import <DFImageManager/DFImageManager.h>
#import "STKStickerHeaderCell.h"
#import "STKUtility.h"
#import "UIImage+Tint.h"
#import "STKBadgeView.h"
#import "STKWebserviceManager.h"
#import "UIImage+CustomBundle.h"
#import "STKStickerPack+CoreDataProperties.h"
#import "helper.h"


@interface STKStickerHeaderCell ()

@property (nonatomic) UIImageView* imageView;
@property (nonatomic) STKBadgeView* dotView;
@property (nonatomic) DFImageTask* imageTask;
@property (nonatomic) UIImage* grayImage;
@property (nonatomic) UIImage* originalImage;

@property (nonatomic, copy) NSString* packName;
@end

@implementation STKStickerHeaderCell

- (instancetype)initWithFrame: (CGRect)frame {
    if (self = [super initWithFrame: frame]) {
        self.imageView = [[UIImageView alloc] initWithFrame: CGRectMake(0, 0, 24.0, 24.0)];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.center = CGPointMake(self.contentView.bounds.size.width / 2, self.contentView.bounds.size.height / 2);
        [self.contentView addSubview: self.imageView];
        
        self.dotView = [[STKBadgeView alloc] initWithFrame: CGRectMake(0, 0, 12.0, 12.0) lineWidth: 1.0 dotSize: CGSizeZero andBorderColor: [STKUtility defaultGreyColor]];
        self.dotView.center = CGPointMake(CGRectGetMaxX(self.imageView.frame), CGRectGetMinY(self.imageView.frame));
        
        [self.contentView addSubview: self.dotView];
        
        self.imageView.tintColor = [UIColor grayColor];
    }
    
    return self;
}

- (void)setStickerCellSelected: (BOOL)selected {
    if (selected) {
        self.backgroundColor = self.selectionColor ? self.selectionColor : [UIColor colorWithRed: 250 / 255.0 green: 250 / 255.0 blue: 250 / 255.0 alpha: 1.0];
        self.imageView.image = self.originalImage;
    } else {
        self.backgroundColor = [UIColor clearColor];
        self.imageView.image = self.grayImage ?: self.originalImage;
    }
}

- (void)prepareForReuse {
    [self.imageTask cancel];
    self.imageTask = nil;
    self.imageView.image = nil;
    self.originalImage = nil;
    self.grayImage = nil;
    self.dotView.hidden = NO;
    self.backgroundColor = [UIColor clearColor];
}

- (void)configRecentCell {
	self.originalImage = [[UIImage imageNamedInCustomBundle: @"STKRecentIcon"] imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];
	self.imageView.image = [[UIImage imageNamedInCustomBundle: @"STKRecentIcon"] imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];

	self.dotView.hidden = YES;
}

- (void)configWithStickerPack: (STKStickerPack*)stickerPack placeholder: (UIImage*)placeholder placeholderTintColor: (UIColor*)placeholderTintColor {
	self.packName = stickerPack.packName;
	self.dotView.hidden = YES;

	UIImage* resultPlaceholder = nil;
	if (FRAMEWORK) {
		resultPlaceholder = placeholder ? placeholder : [UIImage imageNamedInCustomBundle: @"STKStikerTabPlaceholder"];
	} else {
		resultPlaceholder = placeholder ? placeholder : [UIImage imageNamed: @"STKStikerTabPlaceholder"];
	}

	UIColor* colorForPlaceholder = placeholderTintColor && !placeholder ? placeholderTintColor : [STKUtility defaultPlaceholderGrayColor];

	UIImage* coloredPlaceholder = [resultPlaceholder imageWithImageTintColor: colorForPlaceholder];


	DFMutableImageRequestOptions* options = [DFMutableImageRequestOptions new];
	options.priority = DFImageRequestPriorityHigh;

	self.originalImage = coloredPlaceholder;
	self.imageView.image = coloredPlaceholder;
	[self setNeedsLayout];

	NSURL* iconUrl = [[STKWebserviceManager sharedInstance] tabImageUrlForPackName: stickerPack.packName];

	DFImageRequest* request = [DFImageRequest requestWithResource: iconUrl targetSize: CGSizeZero contentMode: DFImageContentModeAspectFit options: options.options];

	typeof(self) __weak weakSelf = self;

	self.imageTask = [[DFImageManager sharedManager] imageTaskForRequest: request completion: ^ (UIImage* __nullable image, NSError* __nullable error, DFImageResponse* __nullable response, DFImageTask* __nonnull imageTask) {
		if (image && [weakSelf.packName isEqualToString: stickerPack.packName]) {
			weakSelf.grayImage = [UIImage convertImageToGrayScale: image];
			weakSelf.originalImage = image;
			UIImage* resultImage = weakSelf.selected ? image : [UIImage convertImageToGrayScale: image];
			weakSelf.imageView.image = resultImage;
			[weakSelf setNeedsLayout];
		} else {
			if (error.code != -1) {
				STKLog(@"Failed loading from header cell: %@", error.localizedDescription);
			}
		}
	}];

	[self.imageTask resume];
}

@end
