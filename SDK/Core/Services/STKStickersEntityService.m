
//
//  STKStickersEntityService.m
//  StickerPipe
//
//  Created by Vadim Degterev on 27.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKStickersEntityService.h"
#import "STKStickersCache.h"
#import "STKUtility.h"
#import "STKStickersConstants.h"
#import "STKWebserviceManager.h"
#import "STKStickerPack+CoreDataProperties.h"

@interface STKStickersEntityService ()
@property (nonatomic) STKStickersCache* cacheEntity;

@property (nonatomic) NSUInteger numberOfUpdateTries;
@end

@implementation STKStickersEntityService

static const NSTimeInterval kUpdatesDelay = 900.0; //15 min

- (instancetype)init {
	if (self = [super init]) {
		self.cacheEntity = [STKStickersCache new];
	}

	return self;
}

- (void)downloadNewPack: (NSDictionary*)packDict {
	NSArray<STKStickerPack*>* stickerPacks = [self.cacheEntity getAllEnabledPacks];

	STKStickerPack* newPack = [STKStickerPack stickerPackWithDict: packDict];

	[stickerPacks enumerateObjectsUsingBlock: ^ (STKStickerPack* pack, NSUInteger idx, BOOL* stop) {
		pack.order = @(idx + 1);
	}];

	newPack.order = @0;
	newPack.disabled = @NO;

	[self saveChangesIfNeeded];


//TODO: -temp
	[[NSNotificationCenter defaultCenter] postNotificationName: kSTKPackDisabledNotification
														object: nil];
}


#pragma mark - Get sticker packs

- (void)fetchStickerPacksFromCacheCompletion: (void (^)(NSArray<STKStickerPack*>*))completion {
	NSArray<STKStickerPack*>* stickerPacks = [self.cacheEntity getAllEnabledPacks];

	[self loadStickersForPacks: stickerPacks completion: completion];
}

- (void)loadStickersForPacks: (NSArray*)packs completion: (void (^)(NSArray<STKStickerPack*>*))completion {
	if (packs.count > 1) {
		dispatch_group_t group = dispatch_group_create();

		[packs enumerateObjectsUsingBlock: ^ (STKStickerPack* pack, NSUInteger idx, BOOL* stop) {
			if (pack.stickers.count == 0 && ![pack.disabled boolValue]) {
				dispatch_group_enter(group);

				[[STKWebserviceManager sharedInstance] loadStickerPackWithName: pack.packName andPricePoint: pack.pricePoint success: ^ (id response) {
					[pack fillWithDict: response[@"data"]];

					dispatch_group_leave(group);
				}                                                      failure: ^ (NSError* error) {
					dispatch_group_leave(group);
				}];
			}
		}];

		dispatch_group_notify(group, dispatch_get_main_queue(), ^ {
			[[NSNotificationCenter defaultCenter] postNotificationName: STKStickersDownloadedNotification
																object: self];
			completion(packs);
		});
	} else {
		completion(packs);
	}
}

- (void)getStickerPacksWithCompletion: (void (^)(NSArray<STKStickerPack*>*))completion {
	NSTimeInterval lastUpdate = [[STKWebserviceManager sharedInstance] lastUpdateDate];
	NSTimeInterval timeSinceLastUpdate = [[NSDate date] timeIntervalSince1970] - lastUpdate;
	if (timeSinceLastUpdate > kUpdatesDelay) {
		[self updateStickerPacksFromServerWithCompletion: ^ (NSError* error) {
			[self fetchStickerPacksFromCacheCompletion: completion];
		}];
	} else {
		[self fetchStickerPacksFromCacheCompletion: completion];
	}
}

- (void)getPackNameForMessage: (NSString*)message completion: (void (^)(NSString*))completion {
	[[STKWebserviceManager sharedInstance] getStickerInfoWithId: [STKUtility stickerIdWithMessage: message] success: ^ (id response) {
		if (completion) {
			completion(response[@"data"][@"pack"]);
		}
	}                                                   failure: nil];
}

- (STKStickerPack*)getStickerPackWithName: (NSString*)packName {
	return [self.cacheEntity getStickerPackWithPackName: packName];
}

- (void)updateStickerPacksFromServerWithCompletion: (void (^)(NSError* error))completion {
	[[STKWebserviceManager sharedInstance] getPacksWithSuccess: ^ (id response, NSTimeInterval lastModifiedDate, BOOL newContent) {
		NSArray* serializedObjects = [STKStickerPack serializeStickerPacks: response[@"data"]];
		[self loadStickersForPacks: serializedObjects completion: ^ (NSArray<STKStickerPack*>* array) {
			NSError* savingError = nil;
			[self.cacheEntity saveStickerPacks: serializedObjects error: &savingError];
			self.hasNewModifiedPacks = newContent;
			if (lastModifiedDate > [STKWebserviceManager sharedInstance].lastModifiedDate) {
				[STKWebserviceManager sharedInstance].lastModifiedDate = lastModifiedDate;
			}
			[STKWebserviceManager sharedInstance].lastUpdateDate = [NSDate date].timeIntervalSince1970;
			if (completion) {
				completion(savingError);
			}
		}];
	}                                                  failure: ^ (NSError* error) {
		if (error.code == -1009) {
			completion(error);
		} else {
			if (++self.numberOfUpdateTries < 5) {
				[self updateStickerPacksFromServerWithCompletion: completion];
			} else {
				completion(error);
			}
		}
	}];
}

- (void)togglePackDisabling: (STKStickerPack*)pack {
	[self.cacheEntity markStickerPack: pack disabled: YES];
}

- (BOOL)hasRecentStickers {
	return [self.cacheEntity hasRecents];
}

- (NSString*)packNameForStickerId: (NSString*)stickerId {
	return [self.cacheEntity packNameForStickerId: stickerId];
}

- (BOOL)isPackDownloaded: (NSString*)packName {
	return [self.cacheEntity isStickerPackDownloaded: packName];
}

- (NSUInteger)indexOfPackWithName: (NSString*)packName {
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"packName == %@", packName];

	NSArray<STKStickerPack*>* packs = [self.cacheEntity getAllEnabledPacks];

	STKStickerPack* stickerPack = [[packs filteredArrayUsingPredicate: predicate] firstObject];

	NSUInteger stickerIndex = [packs indexOfObject: stickerPack];

	return stickerIndex;
}

- (BOOL)hasPackWithName: (NSString*)packName {
	return [self.cacheEntity hasPackWithName: packName];
}

- (NSError*)saveChangesIfNeeded {
	return [self.cacheEntity saveChangesIfNeeded];
}

- (void)movePackFromIndex: (NSUInteger)sourceIdx toIdx: (NSUInteger)destIdx {
	NSMutableArray<STKStickerPack*>* stickerPacks = [[self.cacheEntity getAllEnabledPacks] mutableCopy];

	STKStickerPack* movedPack = stickerPacks[sourceIdx];
	[stickerPacks removeObjectAtIndex: sourceIdx];
	[stickerPacks insertObject: movedPack atIndex: destIdx];

	[stickerPacks enumerateObjectsUsingBlock: ^ (STKStickerPack* obj, NSUInteger idx, BOOL* stop) {
		obj.order = @(idx);
	}];

	[self.cacheEntity saveChangesIfNeeded];
}

- (void)incrementStickerUsedCount: (STKSticker*)sticker {
	[self.cacheEntity incrementStickerUsedCount: sticker];
}

- (NSArray<STKSticker*>*)getRecentStickers {
	return [self.cacheEntity getRecentStickers];
}


@end
