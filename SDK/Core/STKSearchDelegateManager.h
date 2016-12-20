//
//  STKSearchDelegateManager.h
//  StickerPipe
//
//  Created by Alexander908 on 7/18/16.
//  Copyright © 2016 908 Inc. All rights reserved.
//

@import UIKit;

@class STKStickerDelegateManager;
@class STKSticker;

@interface STKSearchDelegateManager : NSObject <UICollectionViewDataSource, UICollectionViewDelegate, UIScrollViewDelegate>

@property (nonatomic, copy) void (^didSelectSticker)(STKSticker* sticker);

@property (nonatomic, weak) UICollectionView* collectionView;

@property (nonatomic) UIColor* placeholderColor;

- (void)setStickerPacksArray: (NSArray*)searchStickerPacks;

- (void)setStickerPlaceholder: (UIImage*)stickerPlaceholder;

@property (nonatomic) STKStickerDelegateManager* stickerDelegateManager;

@end
