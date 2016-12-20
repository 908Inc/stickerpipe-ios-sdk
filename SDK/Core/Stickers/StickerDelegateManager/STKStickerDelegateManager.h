//
//  STKStickerPanelDelegate.h
//  StickerPipe
//
//  Created by Vadim Degterev on 21.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

@import UIKit;

#import "STKSticker+CoreDataProperties.h"
#import "helper.h"

@class STKStickersEntityService;

@interface STKStickerDelegateManager : NSObject <UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate>

//Callbacks
@property (nonatomic, copy) STIntegerBlock didChangeDisplayedSection;
@property (nonatomic, copy) STKStickerObjectBlock didSelectSticker;

@property (nonatomic, weak) UICollectionView* collectionView;

@property (nonatomic) NSInteger currentDisplayedSection;

@property (nonatomic) UIColor* placeholderColor;

@property (nonatomic) UIImage* stickerPlaceholderImage;

- (void)initZoomStickerPreviewView;

- (void)performFetch;

@property (nonatomic) NSArray<STKSticker*>* recentStickers;
@end
