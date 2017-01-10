//
//  STKAnalyticService.h
//  StickerFactory
//
//  Created by Vadim Degterev on 30.06.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

@import Foundation;

//Categories
extern NSString* const STKAnalyticMessageCategory;
extern NSString* const STKAnalyticStickerCategory;

//Actions
extern NSString* const STKAnalyticActionTabs;
extern NSString* const STKAnalyticActionSend;
extern NSString* const STKAnalyticActionRecent;
extern NSString* const STKAnalyticActionSuggest;

//Labels
extern NSString* const STKMessageTextLabel;
extern NSString* const STKMessageStickerLabel;


@interface STKAnalyticService : NSObject

+ (instancetype)sharedService;

- (void)sendEventWithCategory: (NSString*)category
					   action: (NSString*)action
						label: (NSString*)label
						value: (NSNumber*)value;

@end
