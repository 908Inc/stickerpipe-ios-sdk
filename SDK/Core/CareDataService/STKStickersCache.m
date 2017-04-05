//
//  STKStickersDataModel.m
//  StickerFactory
//
//  Created by Vadim Degterev on 08.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKStickersCache.h"
#import "NSManagedObjectContext+STKAdditions.h"
#import "NSManagedObject+STKAdditions.h"
#import "STKStickersConstants.h"
#import "STKStickerPack+CoreDataProperties.h"
#import "STKSticker+CoreDataProperties.h"
#import "STKUtility.h"
#import "STKWebserviceManager.h"

NSString* const kSTKPackDisabledNotification = @"kSTKPackDisabledNotification";


@implementation STKStickersCache

- (instancetype)init {
	if (self = [super init]) {
		[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(didUpdateStorage:) name: NSManagedObjectContextDidSaveNotification object: nil];
		_mainContext = [NSManagedObjectContext stk_defaultContext];
	}

	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void)didUpdateStorage: (NSNotification*)notification {
	dispatch_async(dispatch_get_main_queue(), ^ {
		[[NSNotificationCenter defaultCenter] postNotificationName: STKStickersCacheDidUpdateStickersNotification object: nil];
	});
}


#pragma mark - Saving

- (void)saveStickerPacks: (NSArray*)stickerPacks error: (NSError**)error {
	[self removeAbsentPacksWithCurrentPacks: stickerPacks];

	if (self.mainContext.hasChanges) {
		[self.mainContext save: error];
	}
}

- (void)removeAbsentPacksWithCurrentPacks: (NSArray<STKStickerPack*>*)stickerPacks {
	NSArray* packIDs = [stickerPacks valueForKeyPath: @"@unionOfObjects.packID"];

	NSFetchRequest* requestForDelete = [STKStickerPack fetchRequest];
	requestForDelete.predicate = [NSPredicate predicateWithFormat: @"NOT (packID in %@)", packIDs];

	NSError *error = nil;
	NSArray* objectsForDelete = [self.mainContext executeFetchRequest: requestForDelete error: &error];

	if (error) {
		[[STKWebserviceManager sharedInstance] sendAnErrorWithCategory: @"CoreDataError" p1: error.description p2: [NSString stringWithFormat: @"%i", error.code]];
	}

	for (STKStickerPack* pack in objectsForDelete) {
		[self.mainContext deleteObject: pack];
	}
}

- (NSError*)saveChangesIfNeeded {
	NSError* __block error = nil;

	if (self.mainContext.hasChanges) {
		[self.mainContext save: &error];
	}

	return error;
}


#pragma mark - Getters

- (NSArray<STKStickerPack*>*)getAllEnabledPacks {
	NSFetchRequest<STKStickerPack*>* fetchRequest = [STKStickerPack fetchRequest];
	fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"order" ascending: YES]];
	fetchRequest.predicate = [NSPredicate predicateWithFormat: @"disabled = NO"];

	NSError* error = nil;

	NSArray<STKStickerPack*>* packs = [self.mainContext executeFetchRequest: fetchRequest error: &error];

	if (error) {
		STKLog(@"fetching failed: %@", error.description);
	}

	return packs;
}

- (STKStickerPack*)getStickerPackWithPackName: (NSString*)packName {
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"packName == %@", packName];
	return [[STKStickerPack stk_findWithPredicate: predicate sortDescriptors: nil fetchLimit: 1 context: self.mainContext] firstObject];
}

- (NSString*)packNameForStickerId: (NSString*)stickerId {
	NSPredicate* predicate = [NSPredicate predicateWithFormat: @"stickerID == %@", stickerId];
	STKSticker* sticker = [[STKSticker stk_findWithPredicate: predicate sortDescriptors: nil fetchLimit: 1 context: self.mainContext] firstObject];

	return sticker.packName;
}

#pragma mark - Change

- (void)markStickerPack: (STKStickerPack*)pack disabled: (BOOL)disabled {
	pack.disabled = @(disabled);

	[self saveChangesIfNeeded];

	[[NSNotificationCenter defaultCenter] postNotificationName: kSTKPackDisabledNotification
														object: pack];
}


#pragma mark - Check

- (BOOL)isStickerPackDownloaded: (NSString*)packName {
	return [self packExisted: packName onlyEnabled: YES];
}

- (BOOL)hasPackWithName: (NSString*)packName {
	return [self packExisted: packName onlyEnabled: NO];
}

- (BOOL)packExisted: (NSString*)packName onlyEnabled: (BOOL)onlyEnabled {
	NSFetchRequest* request = [STKStickerPack fetchRequest];
	request.predicate = [NSPredicate predicateWithFormat:
			onlyEnabled ? @"packName == %@ AND disabled == NO" : @"packName == %@", packName];
	request.fetchLimit = 1;
	return [self.mainContext countForFetchRequest: request error: nil] > 0;
}

- (void)incrementStickerUsedCount: (STKSticker*)sticker {
	[self.mainContext performBlock: ^ {
		sticker.usedCount = @([sticker.usedCount integerValue] + 1);
		sticker.usedDate = [NSDate date];

		[self.mainContext save: nil];
	}];
}


#pragma mark - Recents

- (BOOL)hasRecents {
	return [self.mainContext countForFetchRequest: [self recentFetchRequest] error: nil] > 0;
}

- (NSFetchRequest*)recentFetchRequest {
	NSFetchRequest* request = [STKSticker fetchRequest];
	request.predicate = [NSPredicate predicateWithFormat: @"usedCount > 0 && stickerPack.disabled == NO"];
	request.sortDescriptors = @[
			[NSSortDescriptor sortDescriptorWithKey: @"usedDate" ascending: NO],
			[NSSortDescriptor sortDescriptorWithKey: @"usedCount" ascending: NO]
	];
	request.fetchLimit = 12;

	return request;
}

- (NSArray<STKSticker*>*)getRecentStickers {
	NSFetchRequest* request = [self recentFetchRequest];

	NSError* error = nil;

	NSArray* recentStickers = [self.mainContext executeFetchRequest: request error: &error];

	if (error) {
		NSLog(@"fetch recent stickers failed: %@", error.description);
	}

	return recentStickers;
}

@end
