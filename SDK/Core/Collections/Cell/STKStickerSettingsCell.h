//
//  STKStickerSettingsCell.h
//  StickerPipe
//
//  Created by Vadim Degterev on 05.08.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

@import UIKit;

@class STKStickerPack;

@interface STKStickerSettingsCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel* packTitleLabel;
@property (nonatomic, weak) IBOutlet UILabel* packDescriptionLabel;
@property (nonatomic, weak) IBOutlet UIImageView* packIconImageView;

- (void)configureWithStickerPack: (STKStickerPack*)stickerPack;

@end
