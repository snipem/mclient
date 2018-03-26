//
//  MCLBoardListTableViewController.h
//  mclient
//
//  Copyright © 2014 - 2018 Christopher Reitz. Licensed under the MIT license.
//  See LICENSE file in the project root for full license information.
//

#import "MGSwipeTableCell.h"

#import "MCLSectionLoadingViewControllerDelegate.h"
#import "MCLSettingsViewController.h"

// Sections
typedef NS_ENUM(NSInteger, MCLBoardListSection) {
    MCLBoardListSectionBoards = 0,
    MCLBoardListSectionFavorites = 1,
};

@protocol MCLDependencyBag;

@interface MCLBoardListTableViewController : UITableViewController <MGSwipeTableCellDelegate, MCLSectionLoadingViewControllerDelegate, MCLSettingsTableViewControllerDelegate>

- (instancetype)initWithBag:(id <MCLDependencyBag>)bag;

@end
