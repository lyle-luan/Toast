//
//  CSAppViewController.m
//  Toast
//
//  Copyright (c) 2011-2016 Charles Scalesse.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "CSViewController.h"
#import "UIView+Toast.h"

static NSString * ZOToastSwitchCellId   = @"ZOToastSwitchCellId";
static NSString * ZOToastDemoCellId     = @"ZOToastDemoCellId";

@interface CSViewController ()

@property (assign, nonatomic, getter=isShowingActivity) BOOL showingActivity;
@property (strong, nonatomic) UISwitch *tapToDismissSwitch;
@property (strong, nonatomic) UISwitch *queueSwitch;

@end

@implementation CSViewController

#pragma mark - Constructors

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Toast";
        self.showingActivity = NO;
    }
    return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:ZOToastDemoCellId];
    
    
    
    CSToastStyle *style = [[CSToastStyle alloc] initWithDefaultStyle];
    style.backgroundColor = [UIColor blackColor];
    style.titleColor = [UIColor whiteColor];
    style.messageColor = [UIColor whiteColor];
    style.verticalPadding = 30.0f;
    style.cornerRadius = 14.0f;
    style.titleFont = [UIFont systemFontOfSize:17.0];
    style.titleAlignment = NSTextAlignmentCenter;
    style.messageFont = [UIFont systemFontOfSize:13.0];
    style.messageAlignment = NSTextAlignmentCenter;
    style.displayShadow = YES;
    style.shadowColor = [UIColor blackColor];
    style.shadowOpacity = 0.5;
    style.shadowRadius = 4;
    style.shadowOffset = CGSizeMake(2, 2);
    style.imageSize = CGSizeMake(35, 35);
    style.maxWidthPercentage = 0.72;
    style.maxHeightPercentage = 0.21;
    style.showDuration = 1.5;
    style.activityTimeoutDuration = 5;
    style.progressTintColor = [UIColor blackColor];
    style.trackTintColor = [UIColor grayColor];
    
     [CSToastManager setSharedStyle:style];
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - Events

- (void)handleTapToDismissToggled {
    [CSToastManager setTapToDismissEnabled:![CSToastManager isTapToDismissEnabled]];
}

- (void)handleQueueToggled {
    [CSToastManager setQueueEnabled:![CSToastManager isQueueEnabled]];
}

#pragma mark - UITableViewDelegate & Datasource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2;
    } else {
        return 11;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40.0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"SETTINGS";
    } else {
        return @"DEMOS";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 && indexPath.row == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ZOToastSwitchCellId];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ZOToastSwitchCellId];
            self.tapToDismissSwitch = [[UISwitch alloc] init];
            _tapToDismissSwitch.onTintColor = [UIColor colorWithRed:239.0 / 255.0 green:108.0 / 255.0 blue:0.0 / 255.0 alpha:1.0];
            [_tapToDismissSwitch addTarget:self action:@selector(handleTapToDismissToggled) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = _tapToDismissSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont systemFontOfSize:16.0];
        }
        cell.textLabel.text = @"Tap to Dismiss";
        [_tapToDismissSwitch setOn:[CSToastManager isTapToDismissEnabled]];
        return cell;
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ZOToastSwitchCellId];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ZOToastSwitchCellId];
            self.queueSwitch = [[UISwitch alloc] init];
            _queueSwitch.onTintColor = [UIColor colorWithRed:239.0 / 255.0 green:108.0 / 255.0 blue:0.0 / 255.0 alpha:1.0];
            [_queueSwitch addTarget:self action:@selector(handleQueueToggled) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = _queueSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.font = [UIFont systemFontOfSize:16.0];
        }
        cell.textLabel.text = @"Queue Toast";
        [_queueSwitch setOn:[CSToastManager isQueueEnabled]];
        return cell;
    } else {
        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:ZOToastDemoCellId forIndexPath:indexPath];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.font = [UIFont systemFontOfSize:16.0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"成功";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"失败";
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"普通 loading";
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"带文字 loading";
        } else if (indexPath.row == 4) {
            cell.textLabel.text = @"1秒后取消 loading";
        } else if (indexPath.row == 5) {
            cell.textLabel.text = @"OK 按钮";
        } else if (indexPath.row == 6) {
            cell.textLabel.text = @"进度";
        } else if (indexPath.row == 7) {
            cell.textLabel.text = @"Show an image as toast at point\n(110, 110)";
        } else if (indexPath.row == 8) {
            cell.textLabel.text = (self.isShowingActivity) ? @"Hide toast activity" : @"Show toast activity";
        } else if (indexPath.row == 9) {
            cell.textLabel.text = @"Hide toast";
        } else if (indexPath.row == 10) {
            cell.textLabel.text = @"Hide all toasts";
        }
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return;
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 0) {
        
        [self.navigationController.view makeSuccessToast:@"校准成功" withCompletion:^(BOOL didTap) {
            NSLog(@"===>成功");
        }];
        
        
    } else if (indexPath.row == 1) {
        
        [self.navigationController.view makeFailToast:@"校准失败" withCompletion:^(BOOL didTap) {
            NSLog(@"===>失败");
        }];

        
    } else if (indexPath.row == 2) {
        
        [self.navigationController.view makeActivityToastWithTimeoutCompletion:^(BOOL didTap) {
            NSLog(@"===>超时");
        }];

    } else if (indexPath.row == 3) {
        
        [self.navigationController.view makeActivityToast:@"校准中" withMessage:@"请保持设备直立" withTimeoutCompletion:^(BOOL didTap) {
            NSLog(@"===>超时 校准");
        }];
        
    } else if (indexPath.row == 4) {
        
        [self.navigationController.view makeActivityToastWithTimeoutCompletion:^(BOOL didTap) {
            NSLog(@"===>超时");
        }];
        dispatch_after(1, dispatch_get_main_queue(), ^{
            [self.navigationController.view hideActivityToast];
        });
        
    } else if (indexPath.row == 5) {
        [self.navigationController.view makeOkToast:@"校准失败，请重新校准" withImage:[UIImage imageNamed:@"toast_failed"] withBtnTitle:@"好的" withBtnCompletion:^(BOOL didTap) {
            NSLog(@"===>点击 OK 按钮");
        }];
        
    } else if (indexPath.row == 6) {
        NSInteger progress = 10;
        for (NSInteger index=0; index<11; index++) {
            [self makeProgress:progress + index*10 withDelaySecond:index];
        }
    }
#if 0
    else if (indexPath.row == 6) {
        
        // Show a custom view as toast
        UIView *customView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 80, 400)];
        [customView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)]; // autoresizing masks are respected on custom views
        [customView setBackgroundColor:[UIColor orangeColor]];
        
        [self.navigationController.view showToast:customView
                                         duration:2.0
                                         position:CSToastPositionCenter
                                       completion:nil];
        
    } else if (indexPath.row == 7) {
        
        // Show an imageView as toast, on center at point (110,110)
        UIImageView *toastView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"toast.png"]];
        
        [self.navigationController.view showToast:toastView
                                         duration:2.0
                                         position:[NSValue valueWithCGPoint:CGPointMake(110, 110)] // wrap CGPoint in an NSValue object
                                       completion:nil];
        
    } else if (indexPath.row == 8) {
        
        // Make toast activity
        if (!self.isShowingActivity) {
            [self.navigationController.view makeToastActivity:CSToastPositionCenter];
        } else {
            [self.navigationController.view hideToastActivity];
        }
        _showingActivity = !self.isShowingActivity;
        
        [tableView reloadData];
        
    } else if (indexPath.row == 9) {
        
        // Hide toast
        [self.navigationController.view hideToast];
        
    } else if (indexPath.row == 10) {
        
        // Hide all toasts
        [self.navigationController.view hideAllToasts];
        
    }
#endif
}

- (void)makeProgress: (NSInteger)progress withDelaySecond: (NSInteger)second
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(second * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.navigationController.view makeProgressToast:[NSString stringWithFormat:@"更新中(%zd%%)", progress] withProgpressPercent:progress withCompletion:^{
            NSLog(@"更新完成");
        }];
    });
}

@end
