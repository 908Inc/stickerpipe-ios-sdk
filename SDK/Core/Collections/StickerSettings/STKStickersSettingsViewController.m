//
//  STKStickersSettingsViewController.m
//  StickerPipe
//
//  Created by Vadim Degterev on 05.08.15.
//  Copyright (c) 2015 908 Inc. All rights reserved.
//

#import <MBProgressHUD/MBProgressHUD.h>
#import "STKStickersSettingsViewController.h"
#import "STKStickersEntityService.h"
#import "STKStickerSettingsCell.h"
#import "STKStickersShopViewController.h"
#import "STKStickerController.h"
#import "STKWebserviceManager.h"
#import "UIImage+CustomBundle.h"
#import "UIView+ActivityIndicator.h"
#import "STKStickerPack+CoreDataProperties.h"
#import "NSManagedObjectContext+STKAdditions.h"
#import "STKUtility.h"
#import "STKStickersCache.h"
#import "UIView+CordsAdditions.h"
#import "helper.h"

@interface STKStickersSettingsViewController () <UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate>

@property (nonatomic, weak) IBOutlet UITableView* tableView;
@property (nonatomic) STKStickersEntityService* service;
@property (nonatomic) UIBarButtonItem* editBarButton;

@property (nonatomic) NSFetchedResultsController<STKStickerPack*>* frc;

@end

@implementation STKStickersSettingsViewController

NSString* const kCellIdentifier = @"STKStickerSettingsCell";

- (void)viewDidLoad {
	[super viewDidLoad];

	NSFetchRequest* request = [STKStickerPack fetchRequest];
	request.predicate = [NSPredicate predicateWithFormat: @"disabled = NO"];
	request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey: @"order" ascending: YES]];

	self.frc = [[NSFetchedResultsController alloc] initWithFetchRequest: request
												   managedObjectContext: [NSManagedObjectContext stk_defaultContext]
													 sectionNameKeyPath: nil
															  cacheName: nil];

	self.frc.delegate = self;

	NSError* error = nil;

	if (![self.frc performFetch: &error]) {
		STKLog(@"fetch faulted with error: %@", error.description);
	}

	[self.tableView registerNib: [UINib nibWithNibName: @"STKStickerSettingsCell" bundle: [NSBundle stkBundle]] forCellReuseIdentifier: @"STKStickerSettingsCell"];

	self.service = [STKStickersEntityService new];

	self.navigationItem.title = NSLocalizedString(@"Settings", nil);

	[self setUpButtons];
}

- (void)viewWillAppear: (BOOL)animated {
	[super viewWillAppear: animated];

	[self startEditing: NO];

	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: @"settings" forKey: @"viewController"];
	[userDefaults synchronize];
}

- (void)viewDidDisappear: (BOOL)animated {
	[super viewDidDisappear: animated];

	NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults setObject: @"currentVC" forKey: @"viewController"];
	[userDefaults synchronize];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
	return YES;
}

- (void)setUpButtons {
	UIBarButtonItem* closeBarButton = nil;
	if (FRAMEWORK) {
		closeBarButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamedInCustomBundle: @"STKBackIcon"] style: UIBarButtonItemStylePlain target: self action: @selector(closeAction:)];
	} else {
		closeBarButton = [[UIBarButtonItem alloc] initWithImage: [UIImage imageNamed: @"STKBackIcon"] style: UIBarButtonItemStylePlain target: self action: @selector(closeAction:)];
	}

	self.navigationItem.leftBarButtonItem = closeBarButton;

	self.editBarButton = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"Edit", nil) style: UIBarButtonItemStylePlain target: self action: @selector(editAction:)];

	self.navigationItem.rightBarButtonItem = self.editBarButton;
}


#pragma mark - UITableViewDelegate

- (void)tableView: (UITableView*)tableView didSelectRowAtIndexPath: (NSIndexPath*)indexPath {
	STKStickerPack* stickerPack = [self.frc objectAtIndexPath: indexPath];

	STKStickersShopViewController* shopViewController = [STKStickersShopViewController viewControllerFromNib: @"STKStickersShopViewController"];
	[self saveReorderings];
	shopViewController.delegate = self.delegate;
	[self.delegate showStickersView];
	shopViewController.packName = stickerPack.packName;
	[self.navigationController pushViewController: shopViewController animated: YES];
	[self.tableView deselectRowAtIndexPath: indexPath animated: YES];
}


#pragma mark - Actions

- (IBAction)editAction: (id)sender {
	[self startEditing: !self.tableView.editing];
}

- (void)startEditing: (BOOL)editing {
	[self.tableView setEditing: editing animated: YES];
	self.editBarButton.title = editing ? NSLocalizedString(@"Done", nil) : NSLocalizedString(@"Edit", nil);
}

- (IBAction)closeAction: (id)sender {
	[self dismissViewControllerAnimated: YES completion: ^ {
		[self saveReorderings];

		NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
		[userDefaults setObject: @"currentVC" forKey: @"viewController"];
		[userDefaults synchronize];

		[self.delegate showStickersView];
	}];
}

- (void)saveReorderings {
	[[NSNotificationCenter defaultCenter] postNotificationName: STKCloseModalViewNotification object: self];
}


#pragma mark - UITableViewDataSource

- (NSInteger)tableView: (UITableView*)tableView numberOfRowsInSection: (NSInteger)section {
	return self.frc.sections[(NSUInteger) section].numberOfObjects;
}

- (UITableViewCell*)tableView: (UITableView*)tableView cellForRowAtIndexPath: (NSIndexPath*)indexPath {
	STKStickerSettingsCell* cell = [tableView dequeueReusableCellWithIdentifier: kCellIdentifier
																   forIndexPath: indexPath];
	STKStickerPack* pack = [self.frc objectAtIndexPath: indexPath];

	[cell configureWithStickerPack: pack];

	return cell;
}

- (void)tableView: (UITableView*)tableView moveRowAtIndexPath: (NSIndexPath*)sourceIndexPath toIndexPath: (NSIndexPath*)destinationIndexPath {
	[self.service movePackFromIndex: (NSUInteger) sourceIndexPath.row
							  toIdx: (NSUInteger) destinationIndexPath.row];

//TODO: -temp

	[[NSNotificationCenter defaultCenter] postNotificationName: kSTKPackDisabledNotification
														object: nil];
}

- (BOOL)tableView: (UITableView*)tableView canMoveRowAtIndexPath: (NSIndexPath*)indexPath {
	return YES;
}

- (void)tableView: (UITableView*)tableView commitEditingStyle: (UITableViewCellEditingStyle)editingStyle forRowAtIndexPath: (NSIndexPath*)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		MBProgressHUD* hud = [self.view showActivityIndicator];

		STKStickerPack* pack = [self.frc objectAtIndexPath: indexPath];

		[[STKWebserviceManager sharedInstance] deleteStickerPackWithName: pack.packName success: ^ (id response) {
			dispatch_async(dispatch_get_main_queue(), ^ {
				[self.service togglePackDisabling: pack];

				[hud hideAnimated: YES];
			});
		}                                                        failure: nil];
	}
}


#pragma mark - NSFetchedResultsControllerDelegate

- (void)controller: (NSFetchedResultsController*)controller
   didChangeObject: (id)anObject
	   atIndexPath: (NSIndexPath*)indexPath
	 forChangeType: (NSFetchedResultsChangeType)type
	  newIndexPath: (NSIndexPath*)newIndexPath {
	switch (type) {
		case NSFetchedResultsChangeDelete:
			[self.tableView setEditing: NO animated: NO];
			[self.tableView deleteRowsAtIndexPaths: @[indexPath]
								  withRowAnimation: UITableViewRowAnimationTop];
			[self.tableView setEditing: YES animated: NO];
			break;
		case NSFetchedResultsChangeInsert:
		case NSFetchedResultsChangeMove:
		case NSFetchedResultsChangeUpdate:
			[self.tableView reloadData];
			break;
	}
}


@end
