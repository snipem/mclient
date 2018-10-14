//
//  MCLBoardListTableViewController.m
//  mclient
//
//  Copyright © 2014 - 2018 Christopher Reitz. Licensed under the MIT license.
//  See LICENSE file in the project root for full license information.
//

#import "MCLBoardListTableViewController.h"

#import "BBBadgeBarButtonItem.h"
#import "UIViewController+Additions.h"
#import "UIView+addConstraints.h"
#import "MCLDependencyBag.h"
#import "MCLFeatures.h"
#import "MCLFavoriteThreadToggleRequest.h"
#import "MCLRouter+mainNavigation.h"
#import "MCLLogin.h"
#import "MCLMessageResponsesRequest.h"
#import "MCLTheme.h"
#import "MCLThemeManager.h"
#import "MCLSplitViewController.h"
#import "MCLThreadListTableViewController.h"
#import "MCLMessageListViewController.h"
#import "MCLBoard.h"
#import "MCLBoardTableViewCell.h"
#import "MCLThread.h"
#import "MCLThreadTableViewCell.h"
#import "MCLLogoLabel.h"
#import "MCLVerifiyLoginView.h"


@interface MCLBoardListTableViewController ()

@property (strong, nonatomic) id <MCLDependencyBag> bag;
@property (strong, nonatomic) NSArray *boards;
@property (strong, nonatomic) NSMutableArray *favorites;
@property (strong, nonatomic) MCLMessageListViewController *detailViewController;
@property (strong, nonatomic) id <MCLTheme> currentTheme;
@property (strong, nonatomic) BBBadgeBarButtonItem *responsesButtonItem;
@property (strong, nonatomic) BBBadgeBarButtonItem *privateMessagesButtonItem;
@property (strong, nonatomic) MCLVerifiyLoginView *verifyLoginView;
@property (assign, nonatomic) BOOL alreadyAppeared;

@end

@implementation MCLBoardListTableViewController

#pragma mark - Initializers

- (instancetype)initWithBag:(id <MCLDependencyBag>)bag
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (!self) return nil;

    self.bag = bag;
    self.currentTheme = self.bag.themeManager.currentTheme;
    self.alreadyAppeared = NO;
    [self configureNotifications];
    [self configureToolbarButtons];

    self.needsRefreshLoginState = NO;

    return self;
}

- (void)configureNotifications
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(loginStateDidChanged:)
                               name:MCLLoginStateDidChangeNotification
                             object:nil];

    [notificationCenter addObserver:self
                           selector:@selector(themeChanged:)
                               name:MCLThemeChangedNotification
                             object:nil];

    [notificationCenter addObserver:self
                           selector:@selector(foundUnreadResponses:)
                               name:MCLUnreadResponsesFoundNotification
                             object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Lazy Properties

- (MCLVerifiyLoginView *)verifyLoginView
{
    if (!_verifyLoginView) {
        MCLVerifiyLoginView *verifyLoginView = [[MCLVerifiyLoginView alloc] initWithThemeManager:self.bag.themeManager];
        _verifyLoginView = verifyLoginView;
    }

    return _verifyLoginView;
}

#pragma mark - UIViewController life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self configureTableView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.alreadyAppeared && self.bag.login.valid) {
        [[[MCLMessageResponsesRequest alloc] initWithBag:self.bag] loadResponsesWithCompletion:nil];
    }

    self.alreadyAppeared = YES;
}

- (void)didReceiveMemoryWarning
{
    
}

#pragma mark - Configuration

- (void)configureToolbarButtons
{
    [self configureResponsesButton];
    [self configurePrivateMessagesButton];
}

- (void)configureResponsesButton
{
    UIImage *responsesImage = [[UIImage imageNamed:@"responsesButton"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIButton *responsesButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 50.0f)];
    [responsesButton setImage:responsesImage forState:UIControlStateNormal];
    [responsesButton addTarget:self action:@selector(responsesButtonPressed) forControlEvents:UIControlEventTouchUpInside];

    self.responsesButtonItem = [[BBBadgeBarButtonItem alloc] initWithCustomUIButton:responsesButton];
    self.responsesButtonItem.badgeOriginX = 0.0f;
    self.responsesButtonItem.badgeOriginY = 8.0f;
    self.responsesButtonItem.shouldHideBadgeAtZero = YES;
    self.responsesButtonItem.badgePadding = 5;
    [self updateResponsesButtonItemBadgeValueFromApplicationIconBadgeNumber];
}

- (void)updateResponsesButtonItemBadgeValueFromApplicationIconBadgeNumber
{
    self.responsesButtonItem.badgeValue = [NSString stringWithFormat:@"%ld", (long)[UIApplication sharedApplication].applicationIconBadgeNumber];
}

- (void)configurePrivateMessagesButton
{
    UIImage *privateMessagesImage = [[UIImage imageNamed:@"privateMessages"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIButton *privateMessagesButton = [[UIButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 50.0f)];
    [privateMessagesButton setImage:privateMessagesImage forState:UIControlStateNormal];
    [privateMessagesButton addTarget:self action:@selector(responsesButtonPressed) forControlEvents:UIControlEventTouchUpInside];

    self.privateMessagesButtonItem = [[BBBadgeBarButtonItem alloc] initWithCustomUIButton:privateMessagesButton];
    self.privateMessagesButtonItem.badgeOriginX = 0.0f;
    self.privateMessagesButtonItem.badgeOriginY = 8.0f;
    self.privateMessagesButtonItem.badgeValue = [NSString stringWithFormat:@"%i", 7];
    self.privateMessagesButtonItem.shouldHideBadgeAtZero = YES;
    self.privateMessagesButtonItem.badgePadding = 5;

    // Hide when FeatureToggle is off
    if (![self.bag.features isFeatureWithNameEnabled:MCLFeaturePrivateMessages]) {
        self.privateMessagesButtonItem.badgeValue = nil;
        [self.privateMessagesButtonItem setEnabled:NO];
        privateMessagesButton.tintColor = [UIColor clearColor];
    }
}

- (void)configureTableView
{
    [self.tableView registerClass:[MCLBoardTableViewCell class] forCellReuseIdentifier:MCLBoardTableViewCellIdentifier];
    UINib *threadCellNib = [UINib nibWithNibName:@"MCLThreadTableViewCell" bundle:nil];
    [self.tableView registerNib:threadCellNib forCellReuseIdentifier:MCLThreadTableViewCellIdentifier];
    [self.tableView setContentInset:UIEdgeInsetsMake(8, 0, 0, 0)];
}

#pragma mark - MCLLoadingViewControllerDelegate

- (NSString *)loadingViewControllerRequestsTitleString:(MCLLoadingViewController *)loadingViewController
{
    return NSLocalizedString(@"Boards", nil);
}

- (UILabel *)loadingViewControllerRequestsTitleLabel:(MCLLoadingViewController *)loadingViewController
{
    return [self noDetailVC] ? [[MCLLogoLabel alloc] initWithThemeManager:self.bag.themeManager] : nil;
}

- (NSArray<__kindof UIBarButtonItem *> *)loadingViewControllerRequestsToolbarItems:(MCLLoadingViewController *)loadingViewController
{
    UIBarButtonItem *flexibleItem1 = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                   target:nil
                                                                                   action:nil];
    UIBarButtonItem *flexibleItem2 = flexibleItem1;
    UIBarButtonItem *verifyLoginViewItem = [[UIBarButtonItem alloc] initWithCustomView:self.verifyLoginView];

    return [NSArray arrayWithObjects:self.responsesButtonItem,
                                     flexibleItem1,
                                     verifyLoginViewItem,
                                     flexibleItem2,
                                     self.privateMessagesButtonItem,
                                     nil];
}

- (void)loadingViewController:(MCLLoadingViewController *)loadingViewController configureNavigationItem:(UINavigationItem *)navigationItem
{
    if ([self.bag.features isFeatureWithNameEnabled:MCLFeatureFullSearch]) {
        navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"searchButton"]
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:self
                                                                           action:@selector(settingsButtonPressed:)];
    } else { // Needed to center the title label when FeatureToggle is off :-|
        navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"placeholderBarItem"]
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:nil
                                                                           action:nil];
    }

    navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settingsButton"]
                                                                         style:UIBarButtonItemStylePlain
                                                                        target:self
                                                                        action:@selector(settingsButtonPressed:)];
}

- (void)loadingViewController:(MCLLoadingViewController *)loadingViewController hasRefreshedWithData:(NSArray *)newData forKey:(NSNumber *)key
{
    switch ([key integerValue]) {
        case MCLBoardListSectionBoards:
            self.boards = [newData copy];
            if (!self.bag.login.valid) {
                self.favorites = nil;
            }
            break;

        case MCLBoardListSectionFavorites:
            self.favorites = [newData mutableCopy];
            break;
    }

    [self.tableView reloadData];
}

#pragma mark - Login

- (void)updateLoginStatus
{
    if (self.bag.login.valid) {
        [self updateVerifyLoginViewWithSuccess:YES];
    } else {
        [self.bag.login testLoginWithCompletionHandler:^(NSError *error, BOOL success) {
            if (error) {
                [self updateVerifyLoginViewWithSuccess:NO];
                return;
            }
        }];
    }
}

#pragma mark - UITableViewDataSource

- (BOOL)noDetailVC
{
    return !self.splitViewController || self.bag.router.splitViewController.isCollapsed;
}

- (BOOL)showFavoritesSection
{
    BOOL hasFavorites = [self.favorites count] > 0;
    BOOL show = [self noDetailVC] && hasFavorites;

    return show;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == MCLBoardListSectionFavorites && [self.favorites count] == 0) {
        return nil;
    }

    UIView *headerView = [[UIView alloc] init];
    headerView.translatesAutoresizingMaskIntoConstraints = YES;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.font = [UIFont systemFontOfSize:13.0f weight:UIFontWeightRegular];
    titleLabel.textColor = [self.currentTheme tableViewHeaderTextColor];
    titleLabel.text = [self tableView:tableView titleForHeaderInSection:section];

    [headerView addSubview:titleLabel];

    NSDictionary *views = NSDictionaryOfVariableBindings(titleLabel);
    [headerView addConstraints:@"V:|[titleLabel]|" views:views];
    [headerView addConstraints:@"H:|-10-[titleLabel]|" views:views];

    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 38.0f;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case MCLBoardListSectionBoards:
            if ([self noDetailVC]) {
                return NSLocalizedString(@"BOARDS", nil);
            }
            break;
        case MCLBoardListSectionFavorites:
            if ([self showFavoritesSection]) {
                return NSLocalizedString(@"FAVORITES", nil);
            }
            break;
    }

    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case MCLBoardListSectionBoards:
            return [[self boards] count];
            break;
        case MCLBoardListSectionFavorites:
            if ([self showFavoritesSection]) {
                return [[self favorites] count];
            }
            break;
    }

    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case MCLBoardListSectionBoards: return [self boardCellForRowIndexPath:indexPath]; break;
        case MCLBoardListSectionFavorites: return [self favoriteCellForRowIndexPath:indexPath]; break;
    }

    return nil;
}

- (UITableViewCell *)boardCellForRowIndexPath:(NSIndexPath *)indexPath
{
    MCLBoardTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MCLBoardTableViewCellIdentifier];
    cell.currentTheme = self.bag.themeManager.currentTheme;
    cell.board = self.boards[indexPath.row];

    return cell;
}

- (UITableViewCell *)favoriteCellForRowIndexPath:(NSIndexPath *)indexPath
{
    MCLThreadTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:MCLThreadTableViewCellIdentifier];
    cell.index = indexPath.row;
    cell.login = self.bag.login;
    cell.currentTheme = self.bag.themeManager.currentTheme;
    cell.thread = self.favorites[indexPath.row];
    cell.threadIsFavoriteImageView.hidden = YES;
    cell.delegate = self;
    cell.leftSwipeSettings.transition = MGSwipeTransitionBorder;
    cell.leftButtons = @[[MGSwipeButton buttonWithTitle:@""
                                                   icon:[UIImage imageNamed:@"favoriteThreadCellSelected"]
                                        backgroundColor:[self.currentTheme tintColor]]];

    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewAutomaticDimension;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case MCLBoardListSectionBoards:
            [self pushToBoardAtIndexPath:indexPath];
            break;
        case MCLBoardListSectionFavorites:
            [self pushToFavoriteAtIndexPath:indexPath];
            break;
    }
}

- (void)pushToBoardAtIndexPath:(NSIndexPath *)indexPath
{
    MCLBoard *selectedBoard = [self.boards objectAtIndex:indexPath.row];
    [self.bag.router pushToThreadListFromBoard:selectedBoard];
}

- (void)pushToFavoriteAtIndexPath:(NSIndexPath *)indexPath
{
    MCLThread *thread = [self.favorites objectAtIndex:indexPath.row];
    thread.board = [MCLBoard boardWithId:thread.boardId];
    [self.bag.router pushToThread:thread];
}

#pragma mark - MGSwipeTableCellDelegate

- (BOOL)swipeTableCell:(nonnull MGSwipeTableCell*)cell tappedButtonAtIndex:(NSInteger)index direction:(MGSwipeDirection)direction fromExpansion:(BOOL)fromExpansion
{
    MCLThreadTableViewCell *favoriteCell = (MCLThreadTableViewCell *)cell;
    MCLThread *thread = self.favorites[favoriteCell.index];

    [favoriteCell hideSwipeAnimated:YES];

    [self.favorites removeObjectAtIndex:favoriteCell.index];
    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:favoriteCell.index inSection:1]]
                          withRowAnimation:UITableViewRowAnimationLeft];
    [self.tableView reloadData];
    MCLFavoriteThreadToggleRequest *favoriteThreadToggleRequest = [[MCLFavoriteThreadToggleRequest alloc] initWithClient:self.bag.httpClient
                                                                                                                  thread:thread];
    favoriteThreadToggleRequest.forceRemove = YES;
    [favoriteThreadToggleRequest loadWithCompletionHandler:^(NSError *error, NSArray *result) {
        // TODO: - error handling
        if (error) {
            return;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:MCLFavoritedChangedNotification
                                                            object:self
                                                          userInfo:nil];
    }];

    return NO;
}

#pragma mark - MCLMessageListDelegate

- (void)messageListViewController:(MCLMessageListViewController *)inController didReadMessageOnThread:(MCLThread *)inThread
{
    NSIndexPath *selectedIndexPath = self.tableView.indexPathForSelectedRow;
    MCLThreadTableViewCell *selectedCell = [self.tableView cellForRowAtIndexPath:selectedIndexPath];
    [selectedCell updateBadgeWithThread:inThread andTheme:self.currentTheme];
}

#pragma mark - Actions

- (void)settingsButtonPressed:(UIBarButtonItem *)sender
{
    [self.bag.router modalToSettings];
}

- (void)responsesButtonPressed
{
    [self.bag.router pushToResponses];
}

#pragma mark - Notifications

- (void)loginStateDidChanged:(NSNotification *)notification
{
    BOOL success = [[notification.userInfo objectForKey:MCLLoginStateKey] boolValue];
    [self updateVerifyLoginViewWithSuccess:success];
}

- (void)themeChanged:(NSNotification *)notification
{
    self.currentTheme = self.bag.themeManager.currentTheme;
    [self.tableView reloadData];
}

- (void)foundUnreadResponses:(NSNotification *)notification
{
    self.responsesButtonItem.badgeValue = [[[notification userInfo] objectForKey:@"numberOfUnreadResponses"] stringValue];
}

#pragma mark - Public

- (void)updateVerifyLoginViewWithSuccess:(BOOL)success
{
    if (success) {
        [self.verifyLoginView loginStatusWithUsername:self.bag.login.username];
        [[[MCLMessageResponsesRequest alloc] initWithBag:self.bag] loadResponsesWithCompletion:nil];
        [self.responsesButtonItem setEnabled:YES];
        [self updateResponsesButtonItemBadgeValueFromApplicationIconBadgeNumber];
    } else {
        [self.verifyLoginView loginStatusNoLogin];
        self.responsesButtonItem.badgeValue = 0;
        [self.responsesButtonItem setEnabled:NO];
    }
}

@end
