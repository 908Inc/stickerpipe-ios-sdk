//
//  STKStickersPurchaseService.m
//  StickerPipe
//
//  Created by Olya Lutsyk on 2/16/16.
//  Copyright © 2016 908 Inc. All rights reserved.
//

#import "STKStickersPurchaseService.h"
#import "STKInAppProductsManager.h"


@interface STKStickersPurchaseService () //<RMStoreObserver>
//@property (nonatomic, strong) RMStoreKeychainPersistence* persistence;
@end

@implementation STKStickersPurchaseService

+ (STKStickersPurchaseService*)sharedInstance {
	static STKStickersPurchaseService* entity = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^ {
		entity = [STKStickersPurchaseService new];
	});

	return entity;
}

- (id)init {
	if (self = [super init]) {
		/*_persistence = [RMStoreKeychainPersistence new];
		[RMStore defaultStore].transactionPersistor = _persistence;
		[[RMStore defaultStore] addStoreObserver: self];
		self.persistence = [RMStore defaultStore].transactionPersistor;*/
	}

	return self;
}

- (void)requestProductsWithIdentifier: (NSArray*)productIds
						   completion: (void (^)(NSArray*))completion
							  failure: (void (^)(NSError*))failre {
	/*NSSet* product = [NSSet setWithArray: productIds];
	[[RMStore defaultStore] requestProducts: product success: ^ (NSArray* products, NSArray* invalidProductIdentifiers) {
		completion(products);
		NSLog(@"Products loaded");
	}                               failure: ^ (NSError* error) {
		NSLog(@"Something went wrong");
		if (failre) {
			failre(error);
		}
	}];*/
}

- (void)purchaseProductWithPackName: (NSString*)packName
					   andPackPrice: (NSString*)packPrice {
	//typeof(self) __weak weakSelf = self;

	/*[[RMStore defaultStore] addPayment: [STKInAppProductsManager productIdWithPackPrice: packPrice] success: ^ (SKPaymentTransaction* transaction) {
		NSLog(@"purchase complete");
		[weakSelf.persistence consumeProductOfIdentifier:
				[STKInAppProductsManager productIdWithPackPrice: packPrice]];

		[weakSelf purchaseSucceedForPack: packName withPrice: packPrice];

	}                          failure: ^ (SKPaymentTransaction* transaction, NSError* error) {
		NSLog(@"purchase failed");
		[weakSelf purchaseFailedError: error];
	}];*/
}

- (void)purchaseInternalPackName: (NSString*)packName
					andPackPrice: (NSString*)packPrice {
	[self purchaseSucceedForPack: packName withPrice: packPrice];
}


#pragma mark - purchases

- (void)purchaseSucceedForPack: (NSString*)packName withPrice: (NSString*)packPrice {
	if ([self.delegate respondsToSelector: @selector(purchaseSucceededWithPackName:andPackPrice:)]) {
		[self.delegate purchaseSucceededWithPackName: packName andPackPrice: packPrice];
	}
}

- (void)purchaseFailedError: (NSError*)error {
	if ([self.delegate respondsToSelector: @selector(purchaseFailedWithError:)]) {
		[self.delegate purchaseFailedWithError: error];
	}
}

@end
