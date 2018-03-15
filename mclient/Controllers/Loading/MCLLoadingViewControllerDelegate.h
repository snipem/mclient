//
//  MCLLoadingViewControllerDelegate.h
//  mclient
//
//  Copyright © 2014 - 2018 Christopher Reitz. Licensed under the MIT license.
//  See LICENSE file in the project root for full license information.
//

@class MCLLoadingViewController;

@protocol MCLLoadingViewControllerDelegate <NSObject>

@optional

@property (weak, nonatomic) MCLLoadingViewController *loadingViewController;
@property (strong, nonatomic) UITableView *tableView;
@property (strong, nonatomic) UIRefreshControl *refreshControl;
@property (strong, nonatomic) UIView *refreshControlBackgroundView;

- (NSString *)loadingViewControllerRequestsTitleString:(MCLLoadingViewController *)loadingViewController;
- (UILabel *)loadingViewControllerRequestsTitleLabel:(MCLLoadingViewController *)loadingViewController;
- (NSArray<__kindof UIBarButtonItem *> *)loadingViewControllerRequestsToolbarItems:(MCLLoadingViewController *)loadingViewController;
- (void)loadingViewController:(MCLLoadingViewController *)loadingViewController configureNavigationItem:(UINavigationItem *)navigationItem;
- (void)loadingViewControllerStartsRefreshing:(MCLLoadingViewController *)loadingViewController;
- (void)loadingViewController:(MCLLoadingViewController *)loadingViewController hasRefreshedWithData:(NSArray *)newData;

@end