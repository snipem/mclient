//
//  MCLDetailViewController.h
//  mclient
//
//  Created by Christopher Reitz on 19.09.14.
//  Copyright (c) 2014 Christopher Reitz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SplitViewButtonHandler.h"

@class MCLBoard;
@class MCLThread;
@class MCLReadList;

@protocol MCLMessageListDelegate;

@interface MCLMessageListViewController : UIViewController <SplitViewButtonHandler>

@property (weak) id<MCLMessageListDelegate> delegate;
@property (strong, nonatomic) MCLReadList *readList;
@property (strong, nonatomic) MCLBoard *board;
@property (strong, nonatomic) MCLThread *thread;
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, nonatomic) UILabel *titleLabel;

+ (NSString *)messageHtmlSkeletonForHtml:(NSString *)html withTopMargin:(int)topMargin;
- (void)loadThread:(MCLThread *)inThread fromBoard:(MCLBoard *)inBoard;
- (void)updateTitle:(NSString *)title;

@end

@protocol MCLMessageListDelegate <NSObject>

- (void)messageListViewController:(MCLMessageListViewController *)inController didReadMessageOnThread:(MCLThread *)inThread onReadList:(MCLReadList *)inReadList;

@end