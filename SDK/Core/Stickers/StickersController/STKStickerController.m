//
//  STKStickerController.m
//  StickerPipe
//
//  Created by Vadim Degterev on 21.07.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import "STKStickerController.h"
#import "STKStickerDelegateManager.h"
#import "STKStickerHeaderDelegateManager.h"
#import "STKStickerViewCell.h"
#import "STKStickersSeparator.h"
#import "STKStickerHeaderCell.h"
#import "STKUtility.h"
#import "STKStickersEntityService.h"
#import "STKEmptyRecentCell.h"
#import "STKStickersSettingsViewController.h"
#import "STKStickersShopViewController.h"
#import "STKOrientationNavigationController.h"
#import "STKShowStickerButton.h"
#import "STKAnalyticService.h"
#import "STKStickersManager.h"
#import "STKSearchModel.h"
#import "STKSearchDelegateManager.h"
#import "STKWebserviceManager.h"
#import "NSLayoutConstraint+Addictions.h"
#import "STKImageManager.h"
#import "UIImage+CustomBundle.h"
#import "UIView+ActivityIndicator.h"
#import "MBProgressHUD.h"
#import "UIView+CordsAdditions.h"

@interface STKStickerController () <UITextViewDelegate, STKStickersSettingsViewControllerDelegate, STKStickersShopViewControllerDelegate, STKStickerHeaderCollectionViewDelegate>

@property (nonatomic) IBOutlet UIView* internalStickersView;
@property (nonatomic, weak) IBOutlet UICollectionView* stickersHeaderCollectionView;
@property (nonatomic, weak) IBOutlet STKShowStickerButton* stickersShopButton;
@property (nonatomic, weak) IBOutlet UIView* errorView;
@property (nonatomic, weak) IBOutlet UILabel* errorLabel;

@property (nonatomic) STKStickerDelegateManager* stickersDelegateManager;
@property (nonatomic) STKStickerHeaderDelegateManager* stickersHeaderDelegateManager;
@property (nonatomic) BOOL isKeyboardShowed;

@property (nonatomic) STKStickersEntityService* stickersService;

@property (nonatomic) STKStickersShopViewController* shopViewController;
@property (nonatomic) STKStickersSettingsViewController* settingsViewController;

@property (nonatomic) STKSearchDelegateManager* searchDelegateManager;

@property (nonatomic) BOOL recentPresented;

@property (nonatomic, weak) MBProgressHUD* hud;
@end

@implementation STKStickerController

static const CGFloat kStickersSectionPaddingTopBottom = 12.0;
static const CGFloat kKeyboardButtonHeight = 33.0;

void *modifiedPacksContext = &modifiedPacksContext;

- (instancetype)init {
	if (self = [super init]) {
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(willHideKeyboard:)
													 name: UIKeyboardWillHideNotification
												   object: nil];

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(didShowKeyboard:)
													 name: UIKeyboardWillShowNotification
												   object: nil];

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(textFieldDidChange:)
													 name: UITextViewTextDidChangeNotification
												   object: self.textInputView];

		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(storageUpdated:)
													 name: STKStickersCacheDidUpdateStickersNotification
												   object: nil];

		self.stickersService = [STKStickersEntityService new];
		[self.stickersService addObserver: self
							   forKeyPath: @"hasNewModifiedPacks"
								  options: NSKeyValueObservingOptionNew
								  context: modifiedPacksContext];

		self.imageManager = [STKImageManager new];

		self.stickersDelegateManager = [STKStickerDelegateManager new];

		self.stickersHeaderDelegateManager = [STKStickerHeaderDelegateManager new];

		self.stickersShopButton.badgeBorderColor = [STKUtility defaultGreyColor];
		self.stickersShopButton.tintColor = [STKUtility defaultBlueColor];
		self.stickersShopButton.backgroundColor = [STKUtility defaultGreyColor];

		[self initInternalStickerView];
		[self initStickerHeader];
		[self initStickersCollectionView];

		[self loadStickerPacksWithCompletion: ^ {
			[self reloadStickersView];
		}];

		NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults setObject: @"currentVC" forKey: @"viewController"];
		[userDefaults synchronize];

		self.searchDelegateManager = [STKSearchDelegateManager new];
		self.searchDelegateManager.stickerDelegateManager = self.stickersDelegateManager;
	}

	return self;
}

- (void)initInternalStickerView {
	self.internalStickersView = [[NSBundle loadNibNamed: @"STKStickersView" owner: self options: nil] firstObject];

	self.internalStickersView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
	self.internalStickersView.clipsToBounds = YES;

	//iOS 7 FIX
	if (CGRectEqualToRect(self.internalStickersView.frame, CGRectZero) && [UIDevice currentDevice].systemVersion.floatValue < 8.0) {
		self.internalStickersView.frame = CGRectMake(1, 1, 1, 1);
	}
}

- (void)initStickersCollectionView {
	typeof(self) __weak weakSelf = self;

	self.stickersDelegateManager.didChangeDisplayedSection = ^ (NSInteger displayedSection) {
		[weakSelf setPackSelectedAtIndex: displayedSection];
	};

	self.stickersDelegateManager.didSelectSticker = ^ (STKSticker* sticker, BOOL recent) {
		[weakSelf.stickersService incrementStickerUsedCount: sticker];

		[[STKAnalyticService sharedService] sendEventWithCategory: STKAnalyticStickerCategory
														   action: recent ? STKAnalyticActionRecent : STKAnalyticActionTabs
															label: [NSString stringWithFormat: @"%@", sticker.stickerID] value: nil];

		if ([weakSelf.delegate respondsToSelector: @selector(stickerController:didSelectStickerWithMessage:)]) {
			[weakSelf.delegate stickerController: weakSelf didSelectStickerWithMessage: sticker.stickerMessage];
		}
	};

	self.stickersCollectionView.dataSource = self.stickersDelegateManager;
	self.stickersCollectionView.delegate = self.stickersDelegateManager;
	self.stickersDelegateManager.collectionView = self.stickersCollectionView;
	[self.stickersCollectionView registerClass: [STKStickerViewCell class] forCellWithReuseIdentifier: @"STKStickerViewCell"];
	[self.stickersCollectionView registerClass: [STKEmptyRecentCell class] forCellWithReuseIdentifier: @"STKEmptyRecentCell"];
	[self.stickersCollectionView registerClass: [UICollectionReusableView class] forSupplementaryViewOfKind: UICollectionElementKindSectionHeader withReuseIdentifier: @"UICollectionReusableView"];
	[self.stickersCollectionView registerClass: [STKStickersSeparator class] forSupplementaryViewOfKind: UICollectionElementKindSectionFooter withReuseIdentifier: @"STKStickerPanelSeparator"];

	self.stickersDelegateManager.collectionView = self.stickersCollectionView;

	[self.stickersDelegateManager initZoomStickerPreviewView];
}

- (void)initStickerHeader {
	typeof(self) __weak weakSelf = self;

	[self.stickersShopButton setImage: [[UIImage imageNamedInCustomBundle: @"STKShopIcon"] imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate] forState: UIControlStateNormal];
	self.stickersShopButton.tintColor = [UIColor grayColor];

	self.stickersHeaderDelegateManager.delegate = self;

	self.stickersHeaderDelegateManager.didSelectRow = ^ (NSIndexPath* indexPath, STKStickerPack* stickerPack, BOOL animated) {
		NSInteger numberOfItems = [weakSelf.stickersCollectionView numberOfItemsInSection: indexPath.item];

		if (numberOfItems != 0) {
			NSIndexPath* newIndexPath = [NSIndexPath indexPathForItem: 0 inSection: indexPath.item];
			CGRect layoutRect = [weakSelf.stickersCollectionView layoutAttributesForItemAtIndexPath: newIndexPath].frame;
			[weakSelf.stickersCollectionView setContentOffset: CGPointMake(weakSelf.stickersCollectionView.contentOffset.x, layoutRect.origin.y - kStickersSectionPaddingTopBottom) animated: animated];
			weakSelf.stickersDelegateManager.currentDisplayedSection = indexPath.item;
		}
	};

	self.stickersHeaderDelegateManager.collectionView = self.stickersHeaderCollectionView;
	self.stickersHeaderCollectionView.dataSource = self.stickersHeaderDelegateManager;
	self.stickersHeaderCollectionView.delegate = self.stickersHeaderDelegateManager;

	[self.stickersHeaderCollectionView registerClass: [STKStickerHeaderCell class] forCellWithReuseIdentifier: @"STKStickerPanelHeaderCell"];

	self.stickersHeaderCollectionView.backgroundColor = [STKUtility defaultGreyColor];

	self.stickersShopButton.badgeView.hidden = !self.stickersService.hasNewModifiedPacks;
}

- (void)initKeyBoardButton {
	self.keyboardButton = [STKShowStickerButton buttonWithType: UIButtonTypeSystem];
	self.keyboardButton.translatesAutoresizingMaskIntoConstraints = NO;
	self.keyboardButton.tintColor = [UIColor grayColor];
	self.keyboardButton.badgeView.hidden = YES;
	self.keyboardButton.stickerButtonState = STKShowStickerButtonStateStickers;
	[self.keyboardButton addTarget: self action: @selector(keyboardButtonAction:) forControlEvents: UIControlEventTouchUpInside];

	[self.textInputView.superview addSubview: self.keyboardButton];

	[NSLayoutConstraint setConstraintsWidth: kKeyboardButtonHeight
								  andHeight: kKeyboardButtonHeight
									forView: self.keyboardButton];

	NSLayoutConstraint* right = [NSLayoutConstraint constraintWithItem: self.keyboardButton
															 attribute: NSLayoutAttributeRight
															 relatedBy: NSLayoutRelationEqual
																toItem: self.textInputView
															 attribute: NSLayoutAttributeRight
															multiplier: 1
															  constant: 0];

	NSLayoutConstraint* top = [NSLayoutConstraint constraintWithItem: self.keyboardButton
														   attribute: NSLayoutAttributeTop
														   relatedBy: NSLayoutRelationEqual
															  toItem: self.textInputView
														   attribute: NSLayoutAttributeTop
														  multiplier: 1
															constant: 0];

	[self.textInputView.superview addConstraints: @[right, top]];
	[self.textInputView.superview layoutSubviews];

	UIEdgeInsets insets = self.textInputView.textContainerInset;

	self.textInputView.textContainerInset = UIEdgeInsetsMake(insets.top, insets.left, insets.bottom, kKeyboardButtonHeight * 0.75f);
}

- (void)initSuggestCollectionViewWithStickersArray: (NSArray*)stickers {
	UICollectionViewFlowLayout* aFlowLayout = [UICollectionViewFlowLayout new];
	[aFlowLayout setItemSize: CGSizeMake(320, 80)];
	[aFlowLayout setScrollDirection: UICollectionViewScrollDirectionHorizontal];

	CALayer *upperBorder = [CALayer layer];
	upperBorder.backgroundColor = [UIColor colorWithRed: 0.84f green: 0.84f blue: 0.85f alpha: 1].CGColor;
	upperBorder.frame = CGRectMake(0, 0, self.suggestCollectionView.width, 0.5f);
	[self.suggestCollectionView.layer addSublayer:upperBorder];

	[self.suggestCollectionView setCollectionViewLayout: aFlowLayout];
	self.suggestCollectionView.backgroundColor = [UIColor colorWithRed: 0.89f green: 0.89f blue: 0.92f alpha: 0.7];
	[self.suggestCollectionView setShowsHorizontalScrollIndicator: NO];
	[self.suggestCollectionView setShowsVerticalScrollIndicator: NO];

	[self.searchDelegateManager setStickerPacksArray: stickers];

	typeof(self) __weak weakSelf = self;

	self.searchDelegateManager.didSelectSticker = ^ (STKSticker* sticker) {
		[weakSelf hideSuggestCollectionView];

		[weakSelf.stickersService incrementStickerUsedCount: sticker];

		[[STKAnalyticService sharedService] sendEventWithCategory: STKAnalyticStickerCategory action: STKAnalyticActionSuggest label: [NSString stringWithFormat: @"%@", sticker.stickerID] value: nil];

		if ([weakSelf.delegate respondsToSelector: @selector(stickerController:didSelectStickerWithMessage:)]) {
			[weakSelf.delegate stickerController: weakSelf didSelectStickerWithMessage: sticker.stickerMessage];
		}
	};

	self.suggestCollectionView.dataSource = self.searchDelegateManager;
	self.suggestCollectionView.delegate = self.searchDelegateManager;
	self.searchDelegateManager.collectionView = self.suggestCollectionView;

	[self.suggestCollectionView registerClass: [STKStickerViewCell class] forCellWithReuseIdentifier: @"STKStickerViewCell"];
	[self.suggestCollectionView registerClass: [UICollectionReusableView class] forSupplementaryViewOfKind: UICollectionElementKindSectionHeader withReuseIdentifier: @"UICollectionReusableView"];

	self.searchDelegateManager.collectionView = self.suggestCollectionView;
}

- (void)setHeaderBackgroundColor: (UIColor*)headerBackgroundColor {
	_headerBackgroundColor = headerBackgroundColor;

	self.stickersShopButton.backgroundColor = headerBackgroundColor;
	self.stickersHeaderCollectionView.backgroundColor = headerBackgroundColor;
}


#pragma mark - STKStickersSettingsViewControllerDelegate

- (void)stickersReorder: (STKStickersSettingsViewController*)stickersController packs: (NSArray*)packs {
	id <STKStickerControllerDelegate> o = self.delegate;
	if ([o respondsToSelector: @selector(stickersReordered)]) {
		[o stickersReordered];
	}
}

- (void)showStickersView {
	self.keyboardButton.stickerButtonState = STKShowStickerButtonStateKeyboard;

	[self reloadStickersView];

	[self setPackSelectedAtIndex: 0];
	[self.stickersCollectionView setContentOffset: CGPointZero];

	self.textInputView.inputView = self.stickersView;

	[self reloadStickersInputViews];

	// if have not updated yet
	if ([STKWebserviceManager sharedInstance].networkReachable && [STKWebserviceManager sharedInstance].lastModifiedDate == 0) {
		self.internalStickersView.userInteractionEnabled = NO;
		self.hud = [self.internalStickersView showActivityIndicator];
	}
}

- (void)loadStickerPacksWithCompletion: (STSimpleBlock)completion {
	[self.stickersService updateStickerPacksFromServerWithCompletion: ^ (NSError* error) {
		if (error) {
			if (error.code == -1009) {
				[[STKWebserviceManager sharedInstance] addObserver: self
														forKeyPath: @"networkReachable"
														   options: NSKeyValueObservingOptionNew
														   context: nil];

				[[STKWebserviceManager sharedInstance] startCheckingNetwork];
			}
		}

		if (self.hud) {
			[self.hud hideAnimated: YES];
			self.hud = nil;
			self.internalStickersView.userInteractionEnabled = YES;
			[self setPackSelectedAtIndex: 0];
		}

		if (completion) completion();
	}];
}

- (void)showModalViewController: (UIViewController*)viewController {
	STKOrientationNavigationController* navigationController = [[STKOrientationNavigationController alloc] initWithRootViewController: viewController];

	UIViewController* presenter = [self.delegate stickerControllerViewControllerForPresentingModalView];

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSString* vc = [defaults objectForKey: @"viewController"];
	NSString* isNotification = [defaults objectForKey: @"isNotification"];
	[defaults synchronize];

	if ([isNotification isEqualToString: @"yes"]) {
		if ([vc isEqualToString: @"shop"]) {
			[_shopViewController presentViewController: navigationController animated: YES completion: nil];
			[self setUserDefaultsValue];
		} else if ([vc isEqualToString: @"settings"]) {
			[_settingsViewController presentViewController: navigationController animated: YES completion: nil];
			[self setUserDefaultsValue];
		} else {
			[presenter presentViewController: navigationController animated: YES completion: nil];
			[self setUserDefaultsValue];
		}
	} else {
		[presenter presentViewController: navigationController animated: YES completion: nil];
	}
}

- (void)handleError: (NSError*)error {
	self.errorView.hidden = NO;
	self.errorLabel.text = (error.code == NSURLErrorNotConnectedToInternet) ? NSLocalizedString(@"No internet connection", nil) : NSLocalizedString(@"Oops... something went wrong", nil);
	if ([self.delegate respondsToSelector: @selector(stickerControllerErrorHandle:)]) {
		if ([STKWebserviceManager sharedInstance].networkReachable) {
			[self.delegate stickerControllerErrorHandle: error];
		} else {
			NSError* noInternetError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSURLErrorNotConnectedToInternet userInfo: nil];
			[self.delegate stickerControllerErrorHandle: noInternetError];
		}
	}
}


#pragma mark - Actions

- (void)collectionsButtonAction: (UIButton*)collectionsButton {
	if (!_settingsViewController) {
		_settingsViewController = [STKStickersSettingsViewController viewControllerFromNib: @"STKStickersSettingsViewController"];

		_settingsViewController.delegate = self;
	}

	[self showModalViewController: _settingsViewController];

	[self updateRecents];
}

- (void)stickersShopButtonAction: (id)sender {
	if (!_shopViewController) {
		_shopViewController = [STKStickersShopViewController viewControllerFromNib: @"STKStickersShopViewController"];

		_shopViewController.delegate = self;
	}

	self.stickersService.hasNewModifiedPacks = NO;
	self.stickersShopButton.badgeView.hidden = YES;
	[self showModalViewController: _shopViewController];

	[self updateRecents];

	id <STKStickerControllerDelegate> o = self.delegate;
	if ([o respondsToSelector: @selector(shopOpened)]) {
		[o shopOpened];
	}
}

- (void)keyboardButtonAction: (UIButton*)keyboardButton {
	if (self.textInputView.inputView) {
		[self hideStickersView];

		if (self.isSuggestArrayNotEmpty && ![self.textInputView.text isEqualToString: @""]) {
			[self showSuggestCollectionView];
		}
	} else {
		[self showStickersView];

		if (self.isSuggestArrayNotEmpty) {
			[self hideSuggestCollectionView];
		}
	}
}

- (void)closeError: (id)sender {
	if ([STKWebserviceManager sharedInstance].networkReachable) {
		self.errorView.hidden = YES;
		[self loadStickerPacksWithCompletion: ^ {
			if (self.showStickersOnStart) {
				[self showStickersView];
			}
		}];
	} else {
		self.errorView.hidden = NO;
	}
}


#pragma mark - Reload

- (void)updateRecents {
	NSArray<STKSticker*>* recent = [self.stickersService getRecentStickers];
	self.stickersDelegateManager.recentStickers = recent;
	self.recentPresented = recent.count > 0;

	[self.stickersHeaderCollectionView reloadData];
	[self.stickersCollectionView reloadData];
}

- (void)reloadStickersView {
	[self.stickersDelegateManager performFetch];
	[self.stickersHeaderDelegateManager performFetch];

	[self updateRecents];
}


#pragma mark - Selection

- (void)setPackSelectedAtIndex: (NSInteger)index {
	if (self.stickersHeaderCollectionView.numberOfSections > 0 && [self.stickersHeaderCollectionView numberOfItemsInSection: 0] > index) {
		NSIndexPath* indexPath = [NSIndexPath indexPathForItem: index inSection: 0];

		[self.stickersHeaderCollectionView selectItemAtIndexPath: indexPath animated: YES scrollPosition: UICollectionViewScrollPositionCenteredHorizontally];
		[self.stickersHeaderDelegateManager invalidateSelectionForIndexPath: indexPath];
	}
}


#pragma mark - Presenting

- (void)showPackInfoControllerWithStickerMessage: (NSString*)message {
	[self hideStickersView];

	STKStickersShopViewController* vc = [STKStickersShopViewController viewControllerFromNib: @"STKStickersShopViewController"];

	vc.delegate = self;
	[self showStickersView];

	if ([self isStickerPackDownloaded: message]) {
		vc.packName = [self.stickersService packNameForStickerId: [STKUtility stickerIdWithMessage: message]];
		[self showModalViewController: vc];
	} else {
		[self.stickersService getPackNameForMessage: message completion: ^ (NSString* packName) {
			vc.packName = packName;
			dispatch_async(dispatch_get_main_queue(), ^ {
				[self showModalViewController: vc];
			});
		}];
	}
}

- (void)showPackInfoControllerWithName: (NSString*)packName {
	STKStickersShopViewController* vc = [STKStickersShopViewController viewControllerFromNib: @"STKStickersShopViewController"];

	vc.delegate = self;
	vc.packName = packName;
	[self showStickersView];
	[self showModalViewController: vc];
}

- (void)selectPack: (NSUInteger)index {
	[self setPackSelectedAtIndex: index];
	[self.stickersHeaderDelegateManager collectionView: self.stickersHeaderCollectionView didSelectItemAtIndexPath: [NSIndexPath indexPathForRow: index inSection: 0]];
}


#pragma mark - Checks

- (BOOL)isStickerPackDownloaded: (NSString*)packMessage {
	if ([STKStickersManager isOldFormatStickerMessage: packMessage]) {
		NSArray* packNames = [STKUtility trimmedPackNameAndStickerNameWithMessage: packMessage];
		return [self.stickersService isPackDownloaded: packNames.firstObject];
	} else {
		NSString* stickerId = [STKUtility stickerIdWithMessage: packMessage];
		return [self.stickersService isPackDownloaded: [self.stickersService packNameForStickerId: stickerId]];
	}
}


#pragma mark - Colors

- (void)setColorForStickersHeaderPlaceholderColor: (UIColor*)color {
	self.stickersHeaderDelegateManager.placeholderHeaderColor = color;
}

- (void)setColorForStickersPlaceholder: (UIColor*)color {
	self.stickersDelegateManager.placeholderColor = color;
}


#pragma mark - Property

- (BOOL)isStickerViewShowed {
	return self.internalStickersView.superview != nil;
}

- (UIView*)stickersView {
	return _internalStickersView;
}

- (void)setTextInputView: (UITextView*)textInputView {
	_textInputView = textInputView;

	[self initKeyBoardButton];
}

- (void)setSuggestCollectionView: (UICollectionView*)suggestCollectionView {
	_suggestCollectionView = suggestCollectionView;

	self.suggestCollectionView.alpha = 0;
	self.suggestCollectionView.hidden = YES;
}


#pragma mark - Show/hide stickers

- (void)hideStickersView {
	[self updateRecents];

	self.keyboardButton.stickerButtonState = STKShowStickerButtonStateStickers;

	self.textInputView.inputView = nil;

	[self reloadStickersInputViews];
}

- (void)showKeyboard {
	[self.textInputView becomeFirstResponder];
}

- (void)reloadStickersInputViews {
	[self.textInputView reloadInputViews];
	if (!self.isKeyboardShowed) {
		[self.textInputView becomeFirstResponder];
	}
}


#pragma mark - keyboard notifications

- (void)didShowKeyboard: (NSNotification*)notification {
	self.isKeyboardShowed = YES;
}

- (void)willHideKeyboard: (NSNotification*)notification {
	self.isKeyboardShowed = NO;
}

- (void)storageUpdated: (NSNotification*)notification {
	id <STKStickerControllerDelegate> o = self.delegate;
	if ([o respondsToSelector: @selector(didUpdateStickerCache)]) {
		[o didUpdateStickerCache];
	}
}


#pragma mark - user defaults

- (void)setUserDefaultsValue {
	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: @"no" forKey: @"isNotification"];
	[userDefaults synchronize];
}


#pragma mark - statistics

- (void)textMessageSendStatistic {
	[[STKAnalyticService sharedService] sendEventWithCategory: STKAnalyticMessageCategory action: STKAnalyticActionSend label: STKMessageTextLabel value: nil];
}

- (void)stickerMessageSendStatistic {
	[[STKAnalyticService sharedService] sendEventWithCategory: STKAnalyticMessageCategory action: STKAnalyticActionSend label: STKMessageStickerLabel value: nil];
}


#pragma mark - text view notification

- (void)textFieldDidChange: (NSNotification*)notification {
	UITextView* tv = notification.object;

	if (self.showSuggests && self.textInputView == tv) {
		if (tv.text.length != 0) {
			STKSearchModel* model = [STKSearchModel new];

			model.q = [self lastWordFromText: tv.text];
			model.isSuggest = YES;

			if (model.q.length > 0) {
				[[STKWebserviceManager sharedInstance] searchStickersWithSearchModel: model completion: ^ (NSArray* stickers) {
					BOOL stickersReceived = stickers.count != 0;

					if (stickersReceived) {
						[self initSuggestCollectionViewWithStickersArray: stickers];

						[self.suggestCollectionView scrollToItemAtIndexPath: [NSIndexPath indexPathForItem: 0 inSection: 0]
														   atScrollPosition: UICollectionViewScrollPositionLeft
																   animated: NO];

						[self.suggestCollectionView reloadData];

						[self showSuggestCollectionView];
					} else {
						[self hideSuggestCollectionView];
					}

					self.isSuggestArrayNotEmpty = stickersReceived;
				}];
			}
		}
	}
}

- (void)observeValueForKeyPath: (NSString*)keyPath
					  ofObject: (id)object
						change: (NSDictionary*)change
					   context: (void*)context {
	if (context == modifiedPacksContext) {
		self.keyboardButton.badgeView.hidden = !self.stickersService.hasNewModifiedPacks;
		self.stickersShopButton.badgeView.hidden = !self.stickersService.hasNewModifiedPacks;
	} else if (object == [STKWebserviceManager sharedInstance]) {
		if ([change[NSKeyValueChangeNewKey] boolValue]) {
			self.errorView.hidden = YES;
			[self loadStickerPacksWithCompletion: ^ {
				if (self.showStickersOnStart) {
					[self showStickersView];
				}
			}];
		} else {
			[self handleError: [NSError errorWithDomain: NSCocoaErrorDomain code: NSURLErrorNotConnectedToInternet userInfo: nil]];
		}
	}
}


#pragma mark - suggest view

- (void)showSuggestCollectionView {
	self.suggestCollectionView.hidden = NO;

	[UIView animateWithDuration: 0.3 animations: ^ {
		self.suggestCollectionView.alpha = 1.0;
	}];
}

- (void)hideSuggestCollectionView {
	[UIView animateWithDuration: 0.3 animations: ^ {
		self.suggestCollectionView.alpha = 0.0;
	}                completion: ^ (BOOL finished) {
		self.suggestCollectionView.hidden = YES;
	}];
}

- (NSString*)lastWordFromText: (NSString*)text {
	__block NSString* lastWord = nil;

	[text enumerateSubstringsInRange: NSMakeRange(0, [text length]) options: NSStringEnumerationByWords | NSStringEnumerationReverse usingBlock: ^ (NSString* substring, NSRange subrange, NSRange enclosingRange, BOOL* stop) {
		lastWord = substring;
		*stop = YES;
	}];

	return lastWord;
}


#pragma mark - STKStickersShopViewControllerDelegate

- (void)showStickersCollection {
	[self hideStickersView];
	UIViewController* presentViewController = [self.delegate stickerControllerViewControllerForPresentingModalView];
	[presentViewController dismissViewControllerAnimated: YES completion: nil];

	[self collectionsButtonAction: nil];

	id <STKStickerControllerDelegate> o = self.delegate;
	if ([o respondsToSelector: @selector(showStickersCollection)]) {
		[o showStickersCollection];
	}
}

- (void)packRemoved: (STKStickerPack*)packObject fromController: (STKStickersShopViewController*)shopController {
	id <STKStickerControllerDelegate> o = self.delegate;
	if ([o respondsToSelector: @selector(packRemoved:)]) {
		[o packRemoved: packObject];
	}
}

- (void)hideSuggestCollectionViewIfNeeded {
	if (self.isSuggestArrayNotEmpty) {
		[self hideSuggestCollectionView];
	}
}

- (void)showPackWithName: (NSString*)name fromController: (STKStickersShopViewController*)shopController {
	NSUInteger stickerIndex = [self.stickersService indexOfPackWithName: name];
	if (self.recentPresented) {
		++stickerIndex;
	}
	[self setPackSelectedAtIndex: stickerIndex];

	if ([self.stickersHeaderCollectionView numberOfItemsInSection: 0] - 1 >= stickerIndex) {
		NSIndexPath* indexPath = [NSIndexPath indexPathForItem: stickerIndex inSection: 0];
		[self.stickersHeaderDelegateManager scrollToIndexPath: indexPath animated: NO];
	}

	id <STKStickerControllerDelegate> o = self.delegate;
	if ([o respondsToSelector: @selector(newPackShown)]) {
		[o newPackShown];
	}
}

- (void)packWithName: (NSString*)packName downloadedFromController: (STKStickersShopViewController*)shopController {
	[self.stickersService getStickerPacksWithCompletion: ^ (NSArray<STKStickerPack*>* stickerPacks) {
		NSIndexPath* path = [NSIndexPath indexPathForRow: self.recentPresented ? 1 : 0 inSection: 0];

		[self setPackSelectedAtIndex: path.item];

		[self.stickersHeaderCollectionView selectItemAtIndexPath: path
														animated: NO
												  scrollPosition: UICollectionViewScrollPositionCenteredHorizontally];
		[self.stickersHeaderDelegateManager collectionView: self.stickersHeaderCollectionView
								  didSelectItemAtIndexPath: path];
	}];

	id <STKStickerControllerDelegate> o = self.delegate;
	if ([o respondsToSelector: @selector(newPackDownloaded)]) {
		[o newPackDownloaded];
	}
}

- (void)packPurchasedWithName: (NSString*)packName price: (NSString*)packPrice fromController: (STKStickersShopViewController*)shopController {
	id <STKStickerControllerDelegate> o = self.delegate;
	if ([o respondsToSelector: @selector(packPurchasedWithName:price:)]) {
		[o packPurchasedWithName: packName price: packPrice];
	}
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[self.stickersService removeObserver: self
							  forKeyPath: @"hasNewModifiedPacks"
								 context: modifiedPacksContext];

	@try{
		[[STKWebserviceManager sharedInstance] removeObserver: self
												   forKeyPath: @"networkReachable"];
	} @catch (id e){}
}

@end
