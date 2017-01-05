//
//  STKStickersEntityService.h
//  StickerPipe
//
//  Created by Vadim Degterev on 27.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

@import UIKit;

@class STKSticker;
@class STKStickerPack;

@interface STKStickersEntityService : NSObject

@property BOOL hasNewModifiedPacks;

- (STKStickerPack*)getStickerPackWithName: (NSString*)packName;

- (void)updateStickerPacksFromServerWithCompletion: (void (^)(NSError* error))completion;
- (NSString*)packNameForStickerId: (NSString*)stickerId;

- (BOOL)isPackDownloaded: (NSString*)packName;
- (BOOL)hasRecentStickers;
- (BOOL)hasPackWithName: (NSString*)packName;

- (NSUInteger)indexOfPackWithName: (NSString*)packName;

- (void)getStickerPacksWithCompletion: (void (^)(NSArray<STKStickerPack*>*))completion;
- (void)getPackNameForMessage: (NSString*)message completion: (void (^)(NSString* packName))completion;
- (void)downloadNewPack: (NSDictionary*)packDict;
- (void)togglePackDisabling: (STKStickerPack*)pack;
- (void)incrementStickerUsedCount: (STKSticker*)sticker;
- (NSArray<STKSticker*>*)getRecentStickers;
- (NSError*)saveChangesIfNeeded;

- (void)movePackFromIndex:(NSUInteger)sourceIdx toIdx:(NSUInteger)destIdx;

- (void)loadStickersForPacks: (NSArray*)packs completion: (void (^)(NSArray<STKStickerPack*>*))completion;

- (void)fetchStickerPacksFromCacheCompletion: (void (^)(NSArray<STKStickerPack*>*))completion;
@end
