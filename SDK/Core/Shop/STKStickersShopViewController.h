//
//  STKStickersShopViewController.h
//  StickerPipe
//
//  Created by Olya Lutsyk on 1/28/16.
//  Copyright © 2016 908 Inc. All rights reserved.
//

@import UIKit;

@class STKStickersShopViewController;
@class STKStickerPack;

@protocol STKStickersShopViewControllerDelegate <NSObject>
- (void)hideSuggestCollectionViewIfNeeded;

- (void)showKeyboard;

- (void)showStickersCollection;

- (void)packRemoved: (STKStickerPack*)packObject fromController: (STKStickersShopViewController*)shopController;

- (void)showPackWithName: (NSString*)name fromController: (STKStickersShopViewController*)shopController;

- (void)packWithName: (NSString*)packName downloadedFromController: (STKStickersShopViewController*)shopController;

- (void)packPurchasedWithName:(NSString*)packName price:(NSString* )packPrice fromController:(STKStickersShopViewController*)shopController;

@end

@interface STKStickersShopViewController : UIViewController
@property (nonatomic, weak) id <STKStickersShopViewControllerDelegate> delegate;

@property (nonatomic, weak) IBOutlet UIWebView* stickersShopWebView;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView* activity;

@property (nonatomic) NSString* packName;

@end
