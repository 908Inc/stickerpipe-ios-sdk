//
//  STKAnalyticService.m
//  StickerFactory
//
//  Created by Vadim Degterev on 30.06.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKAnalyticService.h"
#import "NSManagedObjectContext+STKAdditions.h"
#import "NSManagedObject+STKAdditions.h"
#import "STKWebserviceManager.h"
#import "STKStatistic+CoreDataProperties.h"

//Categories
NSString* const STKAnalyticMessageCategory = @"message";
NSString* const STKAnalyticStickerCategory = @"sticker";

//Actions
NSString* const STKAnalyticActionTabs = @"tab";
NSString* const STKAnalyticActionSend = @"send";
NSString* const STKAnalyticActionRecent = @"recent";
NSString* const STKAnalyticActionSuggest = @"suggest";

//labels
NSString* const STKMessageTextLabel = @"text";
NSString* const STKMessageStickerLabel = @"sticker";

//Used with weak
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
static const NSInteger kMemoryCacheObjectsCount = 20;
#pragma clang diagnostic pop


@interface STKAnalyticService ()

@property (nonatomic) NSInteger objectCounter;
@property (nonatomic) NSManagedObjectContext* backgroundContext;

@end

@implementation STKAnalyticService

#pragma mark - Init

+ (instancetype)sharedService {
	static STKAnalyticService* service = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^ {
		service = [STKAnalyticService new];
	});
	return service;
}


- (instancetype)init {
	if (self = [super init]) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationWillResignActive:)
													 name: UIApplicationWillResignActiveNotification
												   object: nil];

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(applicationWillTerminateNotification:)
													 name: UIApplicationWillTerminateNotification
												   object: nil];
	}

	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self name: UIApplicationWillResignActiveNotification object: nil];
}


#pragma mark - Events

- (void)sendEventWithCategory: (NSString*)category
					   action: (NSString*)action
						label: (NSString*)label
						value: (NSNumber*)value {
	typeof(self) __weak weakSelf = self;

	[self.backgroundContext performBlock: ^ {
		STKStatistic* statistic = [NSEntityDescription insertNewObjectForEntityForName: NSStringFromClass([STKStatistic class]) inManagedObjectContext: weakSelf.backgroundContext];
		statistic.value = value;
		statistic.category = category;
		statistic.time = @((NSInteger) [NSDate date].timeIntervalSince1970);
		statistic.label = label;
		statistic.action = action;

		NSError* error = nil;
		weakSelf.objectCounter++;
		if (weakSelf.objectCounter == kMemoryCacheObjectsCount) {
			[weakSelf.backgroundContext save: &error];
			weakSelf.objectCounter = 0;
		}
	}];
}


#pragma mark - Notifications

- (void)applicationWillResignActive: (NSNotification*)notification {
	[self sendEventsFromDatabase];
}

- (void)applicationWillTerminateNotification: (NSNotification*)notification {
	[self sendEventsFromDatabase];
}


#pragma mark - Sending

- (void)sendEventsFromDatabase {
	typeof(self) __weak weakSelf = self;

	if (self.backgroundContext.hasChanges) {
		[self.backgroundContext performBlockAndWait: ^ {
			NSError* error = nil;
			[weakSelf.backgroundContext save: &error];
		}];
	}

	NSArray* events = [STKStatistic stk_findAllInContext: self.backgroundContext];

	//API - send statistics
	[[STKWebserviceManager sharedInstance] sendStatistics: events success: ^ (id response) {
		[weakSelf.backgroundContext performBlock: ^ {
			for (id object in events) {
				[weakSelf.backgroundContext deleteObject: object];
			}
			[weakSelf.backgroundContext save: nil];
		}];
	}                                             failure: ^ (NSError* error) {
		NSLog(@"Failed to send events");
	}];
}


#pragma mark - Properties

- (NSManagedObjectContext*)backgroundContext {
	if (!_backgroundContext) {
		_backgroundContext = [NSManagedObjectContext stk_backgroundContext];
	}
	return _backgroundContext;
}


@end
