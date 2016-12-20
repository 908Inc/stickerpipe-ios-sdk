//
//  STKStickersShopViewController.m
//  StickerPipe
//
//  Created by Olya Lutsyk on 1/28/16.
//  Copyright © 2016 908 Inc. All rights reserved.
//

#import "STKStickersShopViewController.h"
#import "UIWebView+AFNetworking.h"
#import "STKStickersManager.h"
#import "STKInAppProductsManager.h"
#import "STKStickersConstants.h"
#import "STKStickersPurchaseService.h"
#import "STKStickersEntityService.h"
#import "SKProduct+STKStickerSKProduct.h"
#import "STKStickersShopJsInterface.h"
#import "STKWebserviceManager.h"
#import "UIImage+CustomBundle.h"
#import "STKStickerPack+CoreDataProperties.h"
#import "helper.h"


static NSString* const uri = @"http://demo.stickerpipe.com/work/libs/store/js/stickerPipeStore.js";
static NSUInteger const productsCount = 2;

@interface STKStickersShopViewController () <UIWebViewDelegate, STKStickersShopJsInterfaceDelegate, STKStickersPurchaseDelegate>

@property (nonatomic) STKStickersShopJsInterface* jsInterface;
@property (nonatomic) STKStickersEntityService* entityService;

@property (nonatomic, weak) IBOutlet UIView* errorView;
@property (nonatomic, weak) IBOutlet UILabel* errorLabel;

@property (nonatomic) NSMutableArray* prices;

- (IBAction)closeErrorClicked: (id)sender;

@end

@implementation STKStickersShopViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	self.entityService = [STKStickersEntityService new];

	self.prices = [NSMutableArray new];

	[self setUpButtons];

	self.navigationItem.title = NSLocalizedString(@"Store", nil);

	self.jsInterface = [STKStickersShopJsInterface new];
	self.jsInterface.delegate = self;

	[STKStickersPurchaseService sharedInstance].delegate = self;

	//
	// subscribe to internet status and process current
	[[STKWebserviceManager sharedInstance] addObserver: self
											forKeyPath: @"networkReachable"
											   options: NSKeyValueObservingOptionNew
											   context: nil];

	[[STKWebserviceManager sharedInstance] startCheckingNetwork];
	//
}

- (void)viewWillAppear: (BOOL)animated {
	[super viewWillAppear: animated];

	[self processInternetStatus];
	self.stickersShopWebView.scrollView.contentOffset = CGPointMake(0, -64);

	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: @"shop" forKey: @"viewController"];
	[userDefaults synchronize];
}

- (void)viewDidDisappear: (BOOL)animated {
	[super viewDidDisappear: animated];

	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: @"currentVC" forKey: @"viewController"];
	[userDefaults synchronize];
}

- (void)handleError: (NSError*)error {
	[self.activity stopAnimating];
	self.errorView.hidden = NO;
	self.errorLabel.text = (error.code == NSURLErrorNotConnectedToInternet) ? NSLocalizedString(@"No internet connection", nil) : NSLocalizedString(@"Oops... something went wrong", nil);
}

- (void)packDownloaded {
	dispatch_async(dispatch_get_main_queue(), ^ {
		[self.stickersShopWebView stringByEvaluatingJavaScriptFromString: @"window.JsInterface.onPackPurchaseSuccess()"];
	});
}

- (void)loadShopPrices {
	if ([STKInAppProductsManager hasProductIds]) {
		[[STKStickersPurchaseService sharedInstance] requestProductsWithIdentifier: [STKInAppProductsManager productIds] completion: ^ (NSArray* stickerPacks) {
			if (stickerPacks.count == productsCount) {
				for (SKProduct* product in stickerPacks) {
					[self.prices addObject: [product currencyString]];
				}

				[self loadStickersShop];
			} else {
				[self handleError: nil];
			}
		}                                                                  failure: ^ (NSError* error) {
			[self handleError: error];
		}];
	} else {
		if ([STKStickersManager priceBLabel] && [STKStickersManager priceCLabel]) {
			self.prices = [[NSMutableArray alloc] initWithArray: @[[STKStickersManager priceBLabel], [STKStickersManager priceCLabel]]];
		}

		[self loadStickersShop];
	}
}

- (NSString*)shopUrlString {
	NSMutableString* URL = [[[STKWebserviceManager sharedInstance] stickerUrl] mutableCopy];

	if (self.prices.count > 0) {
		[URL appendString: [NSMutableString stringWithFormat:
				@"&priceB=%@&priceC=%@", [self.prices firstObject], [self.prices lastObject]]];
	}

	NSMutableString* escapedPath = [NSMutableString stringWithString: [URL stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLQueryAllowedCharacterSet]]];

	if (self.packName) {
		[escapedPath appendString: [NSString stringWithFormat: @"#/packs/%@", self.packName]];
	} else {
		[escapedPath appendString: @"#/store"];
	}

	return escapedPath;
}

- (NSURLRequest*)shopRequest {
	NSURL* url = [NSURL URLWithString: [self shopUrlString]];
	return [NSURLRequest requestWithURL: url];
}

- (void)loadStickersShop {
	[self setJSContext];
	[self.stickersShopWebView loadRequest: [self shopRequest] progress: nil success: ^ NSString*(NSHTTPURLResponse* response, NSString* HTML) {
		return HTML;
	}                             failure: ^ (NSError* error) {
		[self handleError: error];
	}];
}

- (void)setUpButtons {

	UIBarButtonItem*closeBarButton=nil;
	if (FRAMEWORK) {
		closeBarButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamedInCustomBundle:@"STKBackIcon"] style:UIBarButtonItemStylePlain target:self action:@selector(closeAction:)];
	} else {
		closeBarButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed: @"STKBackIcon"] style: UIBarButtonItemStylePlain target: self action: @selector(closeAction:)];
	}

	self.navigationItem.leftBarButtonItem = closeBarButton;

	UIBarButtonItem*settingsButton=nil;
	if (FRAMEWORK) {
		settingsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamedInCustomBundle:@"STKSettingsIcon"] style:UIBarButtonItemStylePlain target:self action:@selector(showCollections:)];
	} else {
		settingsButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed: @"STKSettingsIcon"] style: UIBarButtonItemStylePlain target: self action: @selector(showCollections:)];
	}

	self.navigationItem.rightBarButtonItem = settingsButton;
}

- (void)setJSContext {
	JSContext* context = [self.stickersShopWebView valueForKeyPath: @"documentView.webView.mainFrame.javaScriptContext"];

	[context setExceptionHandler: ^ (JSContext* jsContext, JSValue* value) {
		NSLog(@"WEB JS: %@", value);
	}];

	context[@"IosJsInterface"] = self.jsInterface;
}

- (void)loadPackWithName: (NSString*)packName andPrice: (NSString*)packPrice {
	[[STKWebserviceManager sharedInstance] loadStickerPackWithName: packName andPricePoint: packPrice success: ^ (id response) {
		[self.entityService downloadNewPack: response[@"data"]];
		[self.delegate packWithName: packName downloadedFromController: self];

		[self.delegate hideSuggestCollectionViewIfNeeded];

		[self dismissViewControllerAnimated: YES completion: ^ {
			[self.delegate showKeyboard];
		}];
	}                                failure: ^ (NSError* error) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self.stickersShopWebView stringByEvaluatingJavaScriptFromString: @"window.JsInterface.onPackPurchaseFail()"];
		});
	}];
}


#pragma mark - Actions

- (IBAction)closeAction: (id)sender {
	NSString* currentURL = [self.stickersShopWebView stringByEvaluatingJavaScriptFromString: @"window.location.href"];

	if ([currentURL isEqualToString: [self shopUrlString]] || [currentURL isEqualToString: @"about:blank"]) {
		[self.delegate hideSuggestCollectionViewIfNeeded];

		[self dismissViewControllerAnimated: YES completion: ^ {
			[[NSNotificationCenter defaultCenter] postNotificationName: STKCloseModalViewNotification object: self];

			NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
			[userDefaults setObject: @"currentVC" forKey: @"viewController"];
			[userDefaults synchronize];

			[self.delegate showKeyboard];
		}];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self.stickersShopWebView stringByEvaluatingJavaScriptFromString: @"window.JsInterface.goBack()"];
		});
	}
}

- (IBAction)showCollections: (id)sender {
	[self showCollections];
}


#pragma mark - UIWebviewDelegate

- (void)webView: (UIWebView*)webView didFailLoadWithError: (NSError*)error {
	[self handleError: error];
}


#pragma mark - STKStickersShopJsInterfaceDelegate

- (void)showCollectionsView {
	[self showCollections];
}

- (void)purchasePack: (NSString*)packTitle withName: (NSString*)packName andPrice: (NSString*)packPrice {
	if ([packPrice isEqualToString: @"A"] || ([packPrice isEqualToString: @"B"] && [STKStickersManager isSubscriber]) || [self.entityService hasPackWithName: packName]) {
		[self loadPackWithName: packName andPrice: packPrice];
	} else {
		if ([STKInAppProductsManager hasProductIds]) {
			[[STKStickersPurchaseService sharedInstance] purchaseProductWithPackName: packName andPackPrice: packPrice];
		} else {
			[self.delegate packPurchasedWithName: packName price: packPrice fromController: self];
		}
	}
}

- (void)setInProgress: (BOOL)show {
	if (show) {
		[self.activity startAnimating];
	} else {
		[self.activity stopAnimating];
	}
}

- (void)removePack: (NSString*)packName {
	[[STKWebserviceManager sharedInstance] deleteStickerPackWithName: packName success: ^ (id response) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			STKStickerPack* stickerPack = [self.entityService getStickerPackWithName: packName];
			[self.entityService togglePackDisabling: stickerPack];
			[self.delegate packRemoved: stickerPack fromController: self];

			[self.stickersShopWebView stringByEvaluatingJavaScriptFromString: @"window.JsInterface.onPackRemoveSuccess()"];
		});
	}                                                        failure: ^ (NSError* error) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self.stickersShopWebView stringByEvaluatingJavaScriptFromString: @"window.JsInterface.onPackRemoveFail()"];
		});
	}];
}

- (void)showPack: (NSString*)packName {
	dispatch_async(dispatch_get_main_queue(), ^ {

		[self.delegate hideSuggestCollectionViewIfNeeded];

		[self dismissViewControllerAnimated: YES completion: ^ {
            [self.delegate showKeyboard];

			[self.delegate showPackWithName: packName fromController: self];
		}];
	});
}


#pragma mark - Purchase service delegate

- (void)purchaseSucceededWithPackName: (NSString*)packName andPackPrice: (NSString*)packPrice {
	[self loadPackWithName: packName andPrice: packPrice];
}

- (void)purchaseFailedWithError: (NSError*)error {
	[self purchaseFailedError: error];
}


#pragma mark - Show views

- (void)showErrorAlertWithMessage: (NSString*)errorMessage
					  andOkAction: (void (^)(void))completion
				  andCancelAction: (void (^)(void))cancel {
	if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8) {
		UIAlertController* alertController = [UIAlertController alertControllerWithTitle: @"" message: errorMessage preferredStyle: UIAlertControllerStyleAlert];

		if (completion) {
			[alertController addAction: [UIAlertAction actionWithTitle: NSLocalizedString(@"OK", nil) style: UIAlertActionStyleDefault handler: ^ (UIAlertAction* _Nonnull action) {
				completion();
			}]];
		}
		[alertController addAction: [UIAlertAction actionWithTitle: NSLocalizedString(@"Cancel", nil) style: UIAlertActionStyleDefault handler: ^ (UIAlertAction* _Nonnull action) {
			if (cancel) {
				cancel();
			} else {
				[alertController dismissViewControllerAnimated: YES completion: nil];
			}
		}]];

		[self presentViewController: alertController animated: YES completion: nil];
	}
}

- (void)showCollections {
	dispatch_async(dispatch_get_main_queue(), ^ {
		[self dismissViewControllerAnimated: YES completion: ^ {
			[self.delegate showStickersCollection];
		}];
	});
}

- (void)closeErrorClicked: (id)sender {
	if ([STKWebserviceManager sharedInstance].networkReachable) {
		self.errorView.hidden = YES;
		[self loadShopPrices];
	} else {
		self.errorView.hidden = NO;
	}
}


#pragma mark - purchses

- (void)purchaseFailedError: (NSError*)error {
	dispatch_async(dispatch_get_main_queue(), ^ {
		if (error) {
			[self showErrorAlertWithMessage: error.localizedDescription andOkAction: nil andCancelAction: nil];
		}
		[self.stickersShopWebView stringByEvaluatingJavaScriptFromString: @"window.JsInterface.onPackPurchaseFail()"];
	});
}

- (void)observeValueForKeyPath: (NSString*)keyPath
					  ofObject: (id)object
						change: (NSDictionary*)change
					   context: (void*)context {
	if (object == [STKWebserviceManager sharedInstance]) {
		[self processInternetStatus];
	}
}

- (void)processInternetStatus {
	if ([STKWebserviceManager sharedInstance].networkReachable) {
		self.errorView.hidden = YES;
		[self loadShopPrices];
	} else {
		[self handleError: [NSError errorWithDomain: NSCocoaErrorDomain code: NSURLErrorNotConnectedToInternet userInfo: nil]];
	}
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[[STKWebserviceManager sharedInstance] removeObserver: self
											   forKeyPath: @"networkReachable"
												  context: nil];
}


@end
