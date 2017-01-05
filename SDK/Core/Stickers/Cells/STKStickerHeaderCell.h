//
//  STKStickerPanelHeaderCell.h
//  StickerFactory
//
//  Created by Vadim Degterev on 08.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//


@class STKStickerPack;

@interface STKStickerHeaderCell : UICollectionViewCell

@property (nonatomic) UIColor* selectionColor;

- (void)setStickerCellSelected: (BOOL)selected;
- (void)configRecentCell;
- (void)configWithStickerPack: (STKStickerPack*)stickerPack
				  placeholder: (UIImage*)placeholder
		 placeholderTintColor: (UIColor*)placeholderTintColor;

@end
