//
//  UIView+Toast.m
//  Toast
//
//  Copyright (c) 2011-2017 Charles Scalesse.
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

#import "UIView+Toast.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

// Positions
NSString * CSToastPositionTop                       = @"CSToastPositionTop";
NSString * CSToastPositionCenter                    = @"CSToastPositionCenter";
NSString * CSToastPositionBottom                    = @"CSToastPositionBottom";

// Keys for values associated with toast views
static const NSString * CSToastTimerKey             = @"CSToastTimerKey";
static const NSString * CSToastDurationKey          = @"CSToastDurationKey";
static const NSString * CSToastPositionKey          = @"CSToastPositionKey";
static const NSString * CSToastCompletionKey        = @"CSToastCompletionKey";

// Keys for values associated with self
static const NSString * CSToastActiveKey            = @"CSToastActiveKey";
static const NSString * CSToastActivityViewKey      = @"CSToastActivityViewKey";
static const NSString * CSToastQueueKey             = @"CSToastQueueKey";
static const NSString * CSToastActivityTitleMessageViewKey      = @"CSToastActivityTitleMessageViewKey";

static const NSString * CSToastActivityViewProgressViewKey      = @"CSToastActivityViewProgressViewKey";
static const NSString * CSToastActivityViewProgressTitleViewKey      = @"CSToastActivityViewProgressTitleViewKey";


@interface UIView (ToastPrivate)

/**
 These private methods are being prefixed with "cs_" to reduce the likelihood of non-obvious 
 naming conflicts with other UIView methods.
 
 @discussion Should the public API also use the cs_ prefix? Technically it should, but it
 results in code that is less legible. The current public method names seem unlikely to cause
 conflicts so I think we should favor the cleaner API for now.
 */
- (void)cs_showToast:(UIView *)toast duration:(NSTimeInterval)duration position:(id)position;
- (void)cs_hideToast:(UIView *)toast;
- (void)cs_hideToast:(UIView *)toast fromTap:(BOOL)fromTap;
- (void)cs_toastTimerDidFinish:(NSTimer *)timer;
- (void)cs_hideActivityToast;
- (void)cs_handleToastTapped:(UITapGestureRecognizer *)recognizer;
- (CGPoint)cs_centerPointForPosition:(id)position withToast:(UIView *)toast;
- (NSMutableArray *)cs_toastQueue;

@end

@implementation UIView (Toast)

- (void)makeFailToast: (NSString *)title withCompletion:(void(^)(BOOL didTap))completion
{
    [self makeToast:title withMessage:nil withImage:[UIImage imageNamed:@"toast_failed"] withCompletion:^(BOOL didTap) {
        completion(didTap);
    }];
}

- (void)makeSuccessToast: (NSString *)title withCompletion:(void(^)(BOOL didTap))completion
{
    [self makeToast:title withMessage:nil withImage:[UIImage imageNamed:@"toast_success"] withCompletion:^(BOOL didTap) {
        completion(didTap);
    }];
}

- (void)makeActivityToastWithTimeoutCompletion:(void(^)(BOOL didTap))completion
{
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView != nil) return;
    
    CSToastStyle *style = [CSToastManager sharedStyle];
    
    UIView *activityView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, style.activitySize.width, style.activitySize.height)];
    activityView.center = [self cs_centerPointForPosition:CSToastPositionCenter withToast:activityView];
    activityView.backgroundColor = style.backgroundColor;
    activityView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    activityView.layer.cornerRadius = style.cornerRadius;
    
    if (style.displayShadow) {
        activityView.layer.shadowColor = style.shadowColor.CGColor;
        activityView.layer.shadowOpacity = style.shadowOpacity;
        activityView.layer.shadowRadius = style.shadowRadius;
        activityView.layer.shadowOffset = style.shadowOffset;
    }
    
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityIndicatorView.center = CGPointMake(activityView.bounds.size.width / 2, activityView.bounds.size.height / 2);
    [activityView addSubview:activityIndicatorView];
    [activityIndicatorView startAnimating];
    
    UIView *bgView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    bgView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.08];
    bgView.userInteractionEnabled = YES;
    [bgView addSubview:activityView];
    
    [self addSubview:bgView];
    
    objc_setAssociatedObject (self, &CSToastActivityViewKey, bgView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(bgView, &CSToastCompletionKey, completion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseOut)
                     animations:^{
                         bgView.alpha = 1.0;
                     } completion:^(BOOL finished) {
                         NSTimer *timer = [NSTimer timerWithTimeInterval:[[CSToastManager sharedStyle] activityTimeoutDuration] target:self selector:@selector(cs_hideActivityToast) userInfo:bgView repeats:NO];
                         [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
                         objc_setAssociatedObject(bgView, &CSToastTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                     }];
}

- (void)makeActivityToast: (NSString *)title withMessage: (NSString *)message withTimeoutCompletion:(void(^)(BOOL didTap))completion
{
#if 1
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView != nil) return;
    
    CSToastStyle *style = [CSToastManager sharedStyle];
    
    CGFloat wrapperWidth = 270.0f;
    CGFloat wrapperHeight = 140.0f;
    
    UIView *activityView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, wrapperWidth, wrapperHeight)];
    activityView.center = [self cs_centerPointForPosition:CSToastPositionCenter withToast:activityView];
    activityView.backgroundColor = style.backgroundColor;
    activityView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    activityView.layer.cornerRadius = style.cornerRadius;
    
    if (style.displayShadow) {
        activityView.layer.shadowColor = style.shadowColor.CGColor;
        activityView.layer.shadowOpacity = style.shadowOpacity;
        activityView.layer.shadowRadius = style.shadowRadius;
        activityView.layer.shadowOffset = style.shadowOffset;
    }
    
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityIndicatorView.center = CGPointMake(activityView.bounds.size.width / 2, activityIndicatorView.bounds.size.height / 2 + 30);
    [activityView addSubview:activityIndicatorView];
    [activityIndicatorView startAnimating];
    
    UILabel *messageLabel = nil;
    UILabel *titleLabel = nil;
    
    if (title != nil) {
        titleLabel = [[UILabel alloc] init];
        titleLabel.numberOfLines = style.titleNumberOfLines;
        titleLabel.font = style.titleFont;
        titleLabel.textAlignment = style.titleAlignment;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        titleLabel.textColor = style.titleColor;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.alpha = 1.0;
        titleLabel.text = title;
        
        CGSize maxSizeTitle = CGSizeMake(wrapperWidth, 22);
        titleLabel.frame = CGRectMake(0.0, 0.0, maxSizeTitle.width, maxSizeTitle.height);
    }
    
    if (message != nil) {
        messageLabel = [[UILabel alloc] init];
        messageLabel.numberOfLines = style.messageNumberOfLines;
        messageLabel.font = style.messageFont;
        messageLabel.textAlignment = style.messageAlignment;
        messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        messageLabel.textColor = style.messageColor;
        messageLabel.backgroundColor = [UIColor clearColor];
        messageLabel.alpha = 1.0;
        messageLabel.text = message;
        
        CGSize maxSizeMessage = CGSizeMake(wrapperWidth, 18);
        messageLabel.frame = CGRectMake(0.0, 0.0, maxSizeMessage.width, maxSizeMessage.height);
    }
    
    CGRect titleRect = CGRectZero;
    
    if(titleLabel != nil) {
        titleRect.origin.x = 0;
        titleRect.origin.y = 12+activityIndicatorView.frame.origin.y+activityIndicatorView.frame.size.height;
        titleRect.size.width = titleLabel.bounds.size.width;
        titleRect.size.height = titleLabel.bounds.size.height;
    }
    
    CGRect messageRect = CGRectZero;
    
    if(messageLabel != nil) {
        messageRect.origin.x = titleRect.origin.x;
        messageRect.origin.y = titleRect.origin.y + titleRect.size.height + 8;
        messageRect.size.width = messageLabel.bounds.size.width;
        messageRect.size.height = messageLabel.bounds.size.height;
    }
    
    if(titleLabel != nil) {
        titleLabel.frame = titleRect;
        [activityView addSubview:titleLabel];
    }
    
    if(messageLabel != nil) {
        messageLabel.frame = messageRect;
        [activityView addSubview:messageLabel];
    }
    
    UIView *bgView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    bgView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.08];
    bgView.userInteractionEnabled = YES;
    [bgView addSubview:activityView];
    
    [self addSubview:bgView];
    
    // associate the activity view with self
    objc_setAssociatedObject (self, &CSToastActivityViewKey, bgView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(bgView, &CSToastCompletionKey, completion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
         delay:0.0
       options:(UIViewAnimationOptionCurveEaseOut)
    animations:^{
        bgView.alpha = 1.0;
    } completion:^(BOOL finished) {
        NSTimer *timer = [NSTimer timerWithTimeInterval:[[CSToastManager sharedStyle] activityTimeoutDuration] target:self selector:@selector(cs_hideActivityToast) userInfo:bgView repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        objc_setAssociatedObject(bgView, &CSToastTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
    
#endif
}

- (void)hideActivityToast {
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView != nil) {
        NSTimer *timer = (NSTimer *)objc_getAssociatedObject(existingActivityView, &CSToastTimerKey);
        [timer invalidate];
        [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                         animations:^{
                             existingActivityView.alpha = 0.0;
                         } completion:^(BOOL finished) {
                             [existingActivityView removeFromSuperview];
                             objc_setAssociatedObject (self, &CSToastActivityViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                         }];
    }
}

- (void)makeOkToast: (NSString *)title withImage: (UIImage *)image withBtnTitle: (NSString *)btnTitle withBtnCompletion:(void(^)(BOOL didTap))completion
{
    if (title == nil && image == nil) return;
    
    CSToastStyle *style = [CSToastManager sharedStyle];
    
    UILabel *titleLabel = nil;
    UIImageView *imageView = nil;
    
    CGFloat wrapperWidth = 270.0f;
    CGFloat wrapperHeight = 160.0f;
    
    UIView *wrapperView = [[UIView alloc] init];
    wrapperView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    wrapperView.frame = CGRectMake(0.0, 0.0, wrapperWidth, wrapperHeight);
    wrapperView.layer.cornerRadius = style.cornerRadius;
    if (style.displayShadow) {
        wrapperView.layer.shadowColor = style.shadowColor.CGColor;
        wrapperView.layer.shadowOpacity = style.shadowOpacity;
        wrapperView.layer.shadowRadius = style.shadowRadius;
        wrapperView.layer.shadowOffset = style.shadowOffset;
    }
    wrapperView.backgroundColor = style.backgroundColor;
    
    if(image != nil) {
        imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.frame = CGRectMake((wrapperWidth-style.imageSize.width)/2, 30, style.imageSize.width, style.imageSize.height);
        [wrapperView addSubview:imageView];
    }
    
    if (title != nil) {
        titleLabel = [[UILabel alloc] init];
        titleLabel.numberOfLines = style.titleNumberOfLines;
        titleLabel.font = style.titleFont;
        titleLabel.textAlignment = style.titleAlignment;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        titleLabel.textColor = style.titleColor;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.alpha = 1.0;
        titleLabel.text = title;
        CGSize maxSizeTitle = CGSizeMake(wrapperWidth, 24);
        titleLabel.frame = CGRectMake(0.0, 12+imageView.frame.origin.y+imageView.frame.size.height, maxSizeTitle.width, maxSizeTitle.height);
        [wrapperView addSubview:titleLabel];
    }
    
    UIView *lineView = [[UIView alloc] init];
    lineView.frame =CGRectMake(0, 17+titleLabel.frame.origin.y+titleLabel.frame.size.height, wrapperWidth, 0.3);
    lineView.backgroundColor = [UIColor whiteColor];
    [wrapperView addSubview:lineView];
    
    UIButton *okButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [okButton setTitle:btnTitle forState:UIControlStateNormal];
    okButton.backgroundColor = [UIColor clearColor];
    okButton.titleLabel.textColor = style.titleColor;
    okButton.titleLabel.font = style.titleFont;
    okButton.frame = CGRectMake(0, lineView.frame.origin.y+lineView.frame.size.height, wrapperWidth, 40);
    [okButton addTarget:self action:@selector(tapOkButton:) forControlEvents:UIControlEventTouchUpInside];
    [wrapperView addSubview:okButton];
    
    wrapperView.center = [self cs_centerPointForPosition:CSToastPositionCenter withToast:wrapperView];
    
    UIView *bgView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    bgView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.08];
    bgView.userInteractionEnabled = YES;
    [bgView addSubview:wrapperView];
    
    bgView.alpha = 0.0;
    objc_setAssociatedObject(bgView, &CSToastCompletionKey, completion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [[self cs_activeToasts] addObject:bgView];
    [self addSubview:bgView];
    
    [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         bgView.alpha = 1.0;
                     } completion:^(BOOL finished) {
                     }];
}

- (void)makeProgressToast: (NSString *)title withProgpressPercent: (NSInteger)progressPercent withCompletion:(void(^)(void))completion
{
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView == nil) {
        if (progressPercent >= 100) {
            return;
        }
        CSToastStyle *style = [CSToastManager sharedStyle];
        
        UILabel *titleLabel = nil;
        WFProgressView *progressView = nil;
        
        CGFloat wrapperWidth = 270.0f;
        CGFloat wrapperHeight = 140.0f;
        
        UIView *wrapperView = [[UIView alloc] init];
        wrapperView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
        wrapperView.frame = CGRectMake(0.0, 0.0, wrapperWidth, wrapperHeight);
        wrapperView.layer.cornerRadius = style.cornerRadius;
        if (style.displayShadow) {
            wrapperView.layer.shadowColor = style.shadowColor.CGColor;
            wrapperView.layer.shadowOpacity = style.shadowOpacity;
            wrapperView.layer.shadowRadius = style.shadowRadius;
            wrapperView.layer.shadowOffset = style.shadowOffset;
        }
        wrapperView.backgroundColor = [UIColor whiteColor];
        
        progressView = [[WFProgressView alloc] initWithFrame:CGRectMake(35, 54, wrapperWidth-35*2, 12.0)];
        progressView.progressTintColor = style.progressTintColor;
        progressView.trackTintColor = style.trackTintColor;
//        progressView.frame = CGRectMake(35, 54, wrapperWidth-35*2, 12.0);
//        progressView.transform = CGAffineTransformMakeScale(1.0f, 12.0f / progressView.frame.size.height);
        [progressView setProgress:progressPercent / 100.0 animated:YES];
        for (UIImageView *imageView in progressView.subviews)
        {
            imageView.layer.cornerRadius = progressView.frame.size.height / 2;
            imageView.clipsToBounds = YES;
        }
        [wrapperView addSubview:progressView];
        
        if (title != nil) {
            titleLabel = [[UILabel alloc] init];
            titleLabel.numberOfLines = style.titleNumberOfLines;
            titleLabel.font = style.titleFont;
            titleLabel.textAlignment = style.titleAlignment;
            titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            titleLabel.textColor = style.backgroundColor;
            titleLabel.backgroundColor = [UIColor clearColor];
            titleLabel.alpha = 1.0;
            titleLabel.text = title;
            CGSize maxSizeTitle = CGSizeMake(wrapperWidth, 24);
            titleLabel.frame = CGRectMake(0.0, 12+progressView.frame.origin.y+progressView.frame.size.height, maxSizeTitle.width, maxSizeTitle.height);
            [wrapperView addSubview:titleLabel];
        }
        
        wrapperView.center = [self cs_centerPointForPosition:CSToastPositionCenter withToast:wrapperView];
        
        UIView *bgView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        bgView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.08];
        bgView.userInteractionEnabled = YES;
        [bgView addSubview:wrapperView];
        
        bgView.alpha = 0.0;
//        [[self cs_activeToasts] addObject:bgView];
        [self addSubview:bgView];
        objc_setAssociatedObject(self, &CSToastActivityViewKey, bgView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(bgView, &CSToastActivityViewProgressViewKey, progressView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(bgView, &CSToastActivityViewProgressTitleViewKey, titleLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(bgView, &CSToastCompletionKey, completion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction)
                         animations:^{
                             bgView.alpha = 1.0;
                         } completion:^(BOOL finished) {
                         }];
    }
    else {
        WFProgressView *progressView = (WFProgressView *)objc_getAssociatedObject(existingActivityView, &CSToastActivityViewProgressViewKey);
        UILabel *titleLbel = (UILabel *)objc_getAssociatedObject(existingActivityView, &CSToastActivityViewProgressTitleViewKey);
        if ((progressView != nil) && (titleLbel != nil))
        {
            if (progressPercent > 100) {
                progressPercent = 100;
            }
            [progressView setProgress:progressPercent / 100.0 animated:YES];
            if (title != nil) {
                titleLbel.text = title;
            }
            if (progressPercent == 100)
            {
                [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                                      delay:0.0
                                    options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                                 animations:^{
                                     existingActivityView.alpha = 0.0;
                                 } completion:^(BOOL finished) {
                                     [existingActivityView removeFromSuperview];
                                     objc_setAssociatedObject (self, &CSToastActivityViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

                                     void (^completion)(void) = objc_getAssociatedObject(existingActivityView, &CSToastCompletionKey);
                                     if (completion) {
                                         completion();
                                     }
                                 }];
            }
        }
    }
}

#pragma mark - target

- (void)tapOkButton: (UIButton *)okBtn
{
    UIView *bgView = okBtn.superview.superview;
    [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
                         bgView.alpha = 0.0;
                     } completion:^(BOOL finished) {
                         [bgView removeFromSuperview];
                         [[self cs_activeToasts] removeObject:bgView];
                         void (^completion)(BOOL didTap) = objc_getAssociatedObject(bgView, &CSToastCompletionKey);
                         if (completion) {
                             completion(YES);
                         }
                     }];
}



#pragma mark - Make Toast Methods

- (void)makeToast:(NSString *)message {
    [self makeToast:message duration:[CSToastManager defaultDuration] position:[CSToastManager defaultPosition] style:nil];
}

- (void)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position {
    [self makeToast:message duration:duration position:position style:nil];
}

- (void)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position style:(CSToastStyle *)style {
    UIView *toast = [self toastViewForMessage:message title:nil image:nil style:style];
    [self showToast:toast duration:duration position:position completion:nil];
}

- (void)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position title:(NSString *)title image:(UIImage *)image style:(CSToastStyle *)style completion:(void(^)(BOOL didTap))completion {
    UIView *toast = [self toastViewForMessage:message title:title image:image style:style];
    [self showToast:toast duration:duration position:position completion:completion];
}

- (void)makeToast: (NSString *)title withMessage: (NSString *)message withImage: (UIImage *)image withCompletion:(void(^)(BOOL didTap))completion
{
    CSToastStyle *style = [CSToastManager sharedStyle];
    [self makeToast:nil duration:style.showDuration position:CSToastPositionCenter title:title image:image style:nil completion:^(BOOL didTap) {
        completion(didTap);
    }];
}

#pragma mark - Show Toast Methods

- (void)showToast:(UIView *)toast {
    [self showToast:toast duration:[CSToastManager defaultDuration] position:[CSToastManager defaultPosition] completion:nil];
}

- (void)showToast:(UIView *)toast duration:(NSTimeInterval)duration position:(id)position completion:(void(^)(BOOL didTap))completion {
    // sanity
    if (toast == nil) return;
    
    // store the completion block on the toast view
    
    if ([CSToastManager isQueueEnabled] && [self.cs_activeToasts count] > 0) {
        // we're about to queue this toast view so we need to store the duration and position as well
        objc_setAssociatedObject(toast, &CSToastDurationKey, @(duration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(toast, &CSToastPositionKey, position, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // enqueue
        [self.cs_toastQueue addObject:toast];
    } else {
        // present
        [self cs_showToast:toast duration:duration position:position completion:completion];
    }
}

#pragma mark - Hide Toast Methods

- (void)hideToast {
    [self hideToast:[[self cs_activeToasts] firstObject]];
}

- (void)hideToast:(UIView *)toast {
    // sanity
    if (!toast || ![[self cs_activeToasts] containsObject:toast]) return;
    
    [self cs_hideToast:toast];
}

- (void)hideAllToasts {
    [self hideAllToasts:NO clearQueue:YES];
}

- (void)hideAllToasts:(BOOL)includeActivity clearQueue:(BOOL)clearQueue {
    if (clearQueue) {
        [self clearToastQueue];
    }
    
    for (UIView *toast in [self cs_activeToasts]) {
        [self hideToast:toast];
    }
    
    if (includeActivity) {
        [self hideToastActivity];
    }
}

- (void)clearToastQueue {
    [[self cs_toastQueue] removeAllObjects];
}

#pragma mark - Private Show/Hide Methods

- (void)cs_showToast:(UIView *)toast duration:(NSTimeInterval)duration position:(id)position completion:(void(^)(BOOL didTap))completion {
    toast.center = [self cs_centerPointForPosition:position withToast:toast];
    
    UIView *bgView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    bgView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.08];
    bgView.userInteractionEnabled = YES;
    [bgView addSubview:toast];
    
    bgView.alpha = 0.0;
    
    objc_setAssociatedObject(bgView, &CSToastCompletionKey, completion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if ([CSToastManager isTapToDismissEnabled]) {
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cs_handleToastTapped:)];
        [toast addGestureRecognizer:recognizer];
        toast.userInteractionEnabled = YES;
        toast.exclusiveTouch = YES;
    }
    
    [[self cs_activeToasts] addObject:bgView];
    
    [self addSubview:bgView];
    
    [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         bgView.alpha = 1.0;
                     } completion:^(BOOL finished) {
                         NSTimer *timer = [NSTimer timerWithTimeInterval:duration target:self selector:@selector(cs_toastTimerDidFinish:) userInfo:bgView repeats:NO];
                         [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
                         objc_setAssociatedObject(bgView, &CSToastTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                     }];
}

- (void)cs_hideToast:(UIView *)toast {
    [self cs_hideToast:toast fromTap:NO];
}
    
- (void)cs_hideToast:(UIView *)toast fromTap:(BOOL)fromTap {
    NSTimer *timer = (NSTimer *)objc_getAssociatedObject(toast, &CSToastTimerKey);
    [timer invalidate];
    
    [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
                         toast.alpha = 0.0;
                     } completion:^(BOOL finished) {
                         [toast removeFromSuperview];
                         
                         // remove
                         [[self cs_activeToasts] removeObject:toast];
                         
                         // execute the completion block, if necessary
                         void (^completion)(BOOL didTap) = objc_getAssociatedObject(toast, &CSToastCompletionKey);
                         if (completion) {
                             completion(fromTap);
                         }
                         
                         if ([self.cs_toastQueue count] > 0) {
                             // dequeue
                             UIView *nextToast = [[self cs_toastQueue] firstObject];
                             [[self cs_toastQueue] removeObjectAtIndex:0];
                             
                             // present the next toast
                             NSTimeInterval duration = [objc_getAssociatedObject(nextToast, &CSToastDurationKey) doubleValue];
                             id position = objc_getAssociatedObject(nextToast, &CSToastPositionKey);
                             [self cs_showToast:nextToast duration:duration position:position];
                         }
                     }];
}

- (void)cs_hideActivityToast{
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView != nil) {
        NSTimer *timer = (NSTimer *)objc_getAssociatedObject(existingActivityView, &CSToastTimerKey);
        [timer invalidate];
        [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                         animations:^{
                             existingActivityView.alpha = 0.0;
                         } completion:^(BOOL finished) {
                             [existingActivityView removeFromSuperview];
                             objc_setAssociatedObject (self, &CSToastActivityViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

                             void (^completion)(BOOL didTap) = objc_getAssociatedObject(existingActivityView, &CSToastCompletionKey);
                             if (completion) {
                                 completion(NO);
                             }
                         }];
    }
}

#pragma mark - View Construction

- (UIView *)toastViewForMessage:(NSString *)message title:(NSString *)title image:(UIImage *)image style:(CSToastStyle *)style {
    // sanity
    if (message == nil && title == nil && image == nil) return nil;
    
    // default to the shared style
    if (style == nil) {
        style = [CSToastManager sharedStyle];
    }
    
    // dynamically build a toast view with any combination of message, title, & image
    UILabel *messageLabel = nil;
    UILabel *titleLabel = nil;
    UIImageView *imageView = nil;
    
    CGFloat wrapperWidth = 270.0f;
    CGFloat wrapperHeight = 140.0f;
    
    UIView *wrapperView = [[UIView alloc] init];
    wrapperView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    wrapperView.layer.cornerRadius = style.cornerRadius;
    
    if (style.displayShadow) {
        wrapperView.layer.shadowColor = style.shadowColor.CGColor;
        wrapperView.layer.shadowOpacity = style.shadowOpacity;
        wrapperView.layer.shadowRadius = style.shadowRadius;
        wrapperView.layer.shadowOffset = style.shadowOffset;
    }
    
    wrapperView.backgroundColor = style.backgroundColor;
    
    if(image != nil) {
        imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.frame = CGRectMake((wrapperWidth-style.imageSize.width)/2, 30, style.imageSize.width, style.imageSize.height);
    }
    
    CGRect imageRect = CGRectZero;
    
    if(imageView != nil) {
        imageRect.origin.x = style.horizontalPadding;
        imageRect.origin.y = style.verticalPadding;
        imageRect.size.width = imageView.bounds.size.width;
        imageRect.size.height = imageView.bounds.size.height;
    }
    
    if (title != nil) {
        titleLabel = [[UILabel alloc] init];
        titleLabel.numberOfLines = style.titleNumberOfLines;
        titleLabel.font = style.titleFont;
        titleLabel.textAlignment = style.titleAlignment;
        titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        titleLabel.textColor = style.titleColor;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.alpha = 1.0;
        titleLabel.text = title;
        
        // size the title label according to the length of the text
        CGSize maxSizeTitle = CGSizeMake(wrapperWidth, 24);
//        CGSize expectedSizeTitle = [titleLabel sizeThatFits:maxSizeTitle];
        // UILabel can return a size larger than the max size when the number of lines is 1
//        expectedSizeTitle = CGSizeMake(MIN(maxSizeTitle.width, expectedSizeTitle.width), MIN(maxSizeTitle.height, expectedSizeTitle.height));
        titleLabel.frame = CGRectMake(0.0, 0.0, maxSizeTitle.width, maxSizeTitle.height);
    }
    
    if (message != nil) {
        messageLabel = [[UILabel alloc] init];
        messageLabel.numberOfLines = style.messageNumberOfLines;
        messageLabel.font = style.messageFont;
        messageLabel.textAlignment = style.messageAlignment;
        messageLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        messageLabel.textColor = style.messageColor;
        messageLabel.backgroundColor = [UIColor clearColor];
        messageLabel.alpha = 1.0;
        messageLabel.text = message;
        
        CGSize maxSizeMessage = CGSizeMake(wrapperWidth, 24);;
//        CGSize expectedSizeMessage = [messageLabel sizeThatFits:maxSizeMessage];
        // UILabel can return a size larger than the max size when the number of lines is 1
//        expectedSizeMessage = CGSizeMake(MIN(maxSizeMessage.width, expectedSizeMessage.width), MIN(maxSizeMessage.height, expectedSizeMessage.height));
        messageLabel.frame = CGRectMake(0.0, 0.0, maxSizeMessage.width, maxSizeMessage.height);
    }
    
    CGRect titleRect = CGRectZero;
    
    if(titleLabel != nil) {
        titleRect.origin.x = 0;
        titleRect.origin.y = 12+imageView.frame.origin.y+imageView.frame.size.height;
        titleRect.size.width = titleLabel.bounds.size.width;
        titleRect.size.height = titleLabel.bounds.size.height;
    }
    
    CGRect messageRect = CGRectZero;
    
    if(messageLabel != nil) {
        messageRect.origin.x = titleRect.origin.x;
        messageRect.origin.y = titleRect.origin.y + titleRect.size.height + 8;
        messageRect.size.width = messageLabel.bounds.size.width;
        messageRect.size.height = messageLabel.bounds.size.height;
    }
    
    CGFloat longerWidth = MAX(titleRect.size.width, messageRect.size.width);
    CGFloat longerX = MAX(titleRect.origin.x, messageRect.origin.x);
    
    // Wrapper width uses the longerWidth or the image width, whatever is larger. Same logic applies to the wrapper height.
//    CGFloat wrapperWidth = MAX((imageRect.size.width + (style.horizontalPadding * 2.0)), (longerX + longerWidth + style.horizontalPadding));
//    CGFloat wrapperHeight = MAX((messageRect.origin.y + messageRect.size.height + style.verticalPadding), (imageRect.size.height + (style.verticalPadding * 2.0)));
    
    wrapperWidth = 270.0f;
    wrapperHeight = 140.0f;
    
    wrapperView.frame = CGRectMake(0.0, 0.0, wrapperWidth, wrapperHeight);
    
    if(titleLabel != nil) {
        titleLabel.frame = titleRect;
        [wrapperView addSubview:titleLabel];
    }
    
    if(messageLabel != nil) {
        messageLabel.frame = messageRect;
        [wrapperView addSubview:messageLabel];
    }
    
    if(imageView != nil) {
        [wrapperView addSubview:imageView];
    }
    
    return wrapperView;
}

#pragma mark - Storage

- (NSMutableArray *)cs_activeToasts {
    NSMutableArray *cs_activeToasts = objc_getAssociatedObject(self, &CSToastActiveKey);
    if (cs_activeToasts == nil) {
        cs_activeToasts = [[NSMutableArray alloc] init];
        objc_setAssociatedObject(self, &CSToastActiveKey, cs_activeToasts, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cs_activeToasts;
}

- (NSMutableArray *)cs_toastQueue {
    NSMutableArray *cs_toastQueue = objc_getAssociatedObject(self, &CSToastQueueKey);
    if (cs_toastQueue == nil) {
        cs_toastQueue = [[NSMutableArray alloc] init];
        objc_setAssociatedObject(self, &CSToastQueueKey, cs_toastQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cs_toastQueue;
}

#pragma mark - Events

- (void)cs_toastTimerDidFinish:(NSTimer *)timer {
    [self cs_hideToast:(UIView *)timer.userInfo];
}

- (void)cs_handleToastTapped:(UITapGestureRecognizer *)recognizer {
    UIView *toast = recognizer.view;
    UIView *bgView = toast.superview;
    NSTimer *timer = (NSTimer *)objc_getAssociatedObject(bgView, &CSToastTimerKey);
    [timer invalidate];
    
    [self cs_hideToast:bgView fromTap:YES];
}

#pragma mark - Activity Methods

- (void)makeToastActivity:(id)position {
    // sanity
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView != nil) return;
    
    CSToastStyle *style = [CSToastManager sharedStyle];
    
    CGFloat wrapperWidth = 270.0f;
    CGFloat wrapperHeight = 140.0f;
    
    UIView *activityView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, style.activitySize.width, style.activitySize.height)];
    activityView.center = [self cs_centerPointForPosition:position withToast:activityView];
    activityView.backgroundColor = style.backgroundColor;
    activityView.alpha = 0.0;
    activityView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    activityView.layer.cornerRadius = style.cornerRadius;
    
    if (style.displayShadow) {
        activityView.layer.shadowColor = style.shadowColor.CGColor;
        activityView.layer.shadowOpacity = style.shadowOpacity;
        activityView.layer.shadowRadius = style.shadowRadius;
        activityView.layer.shadowOffset = style.shadowOffset;
    }
    
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    activityIndicatorView.center = CGPointMake(activityView.bounds.size.width / 2, activityView.bounds.size.height / 2);
    [activityView addSubview:activityIndicatorView];
    [activityIndicatorView startAnimating];
    
    // associate the activity view with self
    objc_setAssociatedObject (self, &CSToastActivityViewKey, activityView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self addSubview:activityView];
    
    [UIView animateWithDuration:style.animationDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         activityView.alpha = 1.0;
                     } completion:nil];
}

- (void)hideToastActivity {
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &CSToastActivityViewKey);
    if (existingActivityView != nil) {
        [UIView animateWithDuration:[[CSToastManager sharedStyle] animationDuration]
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                         animations:^{
                             existingActivityView.alpha = 0.0;
                         } completion:^(BOOL finished) {
                             [existingActivityView removeFromSuperview];
                             objc_setAssociatedObject (self, &CSToastActivityViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                         }];
    }
}

#pragma mark - Helpers

- (CGPoint)cs_centerPointForPosition:(id)point withToast:(UIView *)toast {
    CSToastStyle *style = [CSToastManager sharedStyle];
    
    UIEdgeInsets safeInsets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        safeInsets = self.safeAreaInsets;
    }
    
    CGFloat topPadding = style.verticalPadding + safeInsets.top;
    CGFloat bottomPadding = style.verticalPadding + safeInsets.bottom;
    
    if([point isKindOfClass:[NSString class]]) {
        if([point caseInsensitiveCompare:CSToastPositionTop] == NSOrderedSame) {
            return CGPointMake(self.bounds.size.width / 2.0, (toast.frame.size.height / 2.0) + topPadding);
        } else if([point caseInsensitiveCompare:CSToastPositionCenter] == NSOrderedSame) {
            return CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
        }
    } else if ([point isKindOfClass:[NSValue class]]) {
        return [point CGPointValue];
    }
    
    // default to bottom
    return CGPointMake(self.bounds.size.width / 2.0, (self.bounds.size.height - (toast.frame.size.height / 2.0)) - bottomPadding);
}

@end

@implementation CSToastStyle

#pragma mark - Constructors

- (instancetype)initWithDefaultStyle {
    self = [super init];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        self.titleColor = [UIColor whiteColor];
        self.messageColor = [UIColor whiteColor];
        self.maxWidthPercentage = 0.8;
        self.maxHeightPercentage = 0.8;
        self.horizontalPadding = 10.0;
        self.verticalPadding = 10.0;
        self.cornerRadius = 10.0;
        self.titleFont = [UIFont boldSystemFontOfSize:16.0];
        self.messageFont = [UIFont systemFontOfSize:16.0];
        self.titleAlignment = NSTextAlignmentLeft;
        self.messageAlignment = NSTextAlignmentLeft;
        self.titleNumberOfLines = 0;
        self.messageNumberOfLines = 0;
        self.displayShadow = NO;
        self.shadowOpacity = 0.8;
        self.shadowRadius = 6.0;
        self.shadowOffset = CGSizeMake(4.0, 4.0);
        self.imageSize = CGSizeMake(80.0, 80.0);
        self.activitySize = CGSizeMake(100.0, 100.0);
        self.animationDuration = 0.2;
    }
    return self;
}

- (void)setMaxWidthPercentage:(CGFloat)maxWidthPercentage {
    _maxWidthPercentage = MAX(MIN(maxWidthPercentage, 1.0), 0.0);
}

- (void)setMaxHeightPercentage:(CGFloat)maxHeightPercentage {
    _maxHeightPercentage = MAX(MIN(maxHeightPercentage, 1.0), 0.0);
}

- (instancetype)init NS_UNAVAILABLE {
    return nil;
}

@end

@interface CSToastManager ()

@property (strong, nonatomic) CSToastStyle *sharedStyle;
@property (assign, nonatomic, getter=isTapToDismissEnabled) BOOL tapToDismissEnabled;
@property (assign, nonatomic, getter=isQueueEnabled) BOOL queueEnabled;
@property (assign, nonatomic) NSTimeInterval defaultDuration;
@property (strong, nonatomic) id defaultPosition;

@end

@implementation CSToastManager

#pragma mark - Constructors

+ (instancetype)sharedManager {
    static CSToastManager *_sharedManager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedManager = [[self alloc] init];
    });
    
    return _sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sharedStyle = [[CSToastStyle alloc] initWithDefaultStyle];
        self.tapToDismissEnabled = YES;
        self.queueEnabled = NO;
        self.defaultDuration = 3.0;
        self.defaultPosition = CSToastPositionBottom;
    }
    return self;
}

#pragma mark - Singleton Methods

+ (void)setSharedStyle:(CSToastStyle *)sharedStyle {
    [[self sharedManager] setSharedStyle:sharedStyle];
}

+ (CSToastStyle *)sharedStyle {
    return [[self sharedManager] sharedStyle];
}

+ (void)setTapToDismissEnabled:(BOOL)tapToDismissEnabled {
    [[self sharedManager] setTapToDismissEnabled:tapToDismissEnabled];
}

+ (BOOL)isTapToDismissEnabled {
    return [[self sharedManager] isTapToDismissEnabled];
}

+ (void)setQueueEnabled:(BOOL)queueEnabled {
    [[self sharedManager] setQueueEnabled:queueEnabled];
}

+ (BOOL)isQueueEnabled {
    return [[self sharedManager] isQueueEnabled];
}

+ (void)setDefaultDuration:(NSTimeInterval)duration {
    [[self sharedManager] setDefaultDuration:duration];
}

+ (NSTimeInterval)defaultDuration {
    return [[self sharedManager] defaultDuration];
}

+ (void)setDefaultPosition:(id)position {
    if ([position isKindOfClass:[NSString class]] || [position isKindOfClass:[NSValue class]]) {
        [[self sharedManager] setDefaultPosition:position];
    }
}

+ (id)defaultPosition {
    return [[self sharedManager] defaultPosition];
}

@end

@interface WFProgressView ()
@property (nonatomic, readwrite, strong) UIView *progressView;
@property (nonatomic, readwrite, strong) UIView *trackView;
@end

@implementation WFProgressView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.progressTintColor = [UIColor blackColor];
        self.trackTintColor = [UIColor whiteColor];
        
        [self addSubview:self.progressView];
        [self addSubview:self.trackView];
        [self bringSubviewToFront:self.progressView];
    }
    return self;
}

- (void)setProgress:(float)progress animated:(BOOL)animated
{
    [UIView animateWithDuration:0.1 animations:^{
        CGFloat maxWidth = self.bounds.size.width;
        CGFloat width = maxWidth * progress;
        CGRect frame = self.progressView.frame;
        frame.size.width = width;
        self.progressView.frame = frame;
    } completion:^(BOOL finished) {
        ;
    }];
}

- (void)setProgressTintColor:(UIColor *)progressTintColor
{
    _progressTintColor = progressTintColor;
    self.progressView.backgroundColor = progressTintColor;
}

- (void)setTrackTintColor:(UIColor *)trackTintColor
{
    _trackTintColor = trackTintColor;
    self.trackView.backgroundColor = trackTintColor;
}

#pragma mark - UI property

- (UIView *)progressView
{
    if (_progressView == nil){
        _progressView = [[UIView alloc] init];
        CGRect frame = self.bounds;
        frame.size.width = 0;
        _progressView.frame = frame;
        _progressView.backgroundColor = [UIColor blackColor];
        _progressView.layer.cornerRadius = self.bounds.size.height / 2.0f;
        _progressView.layer.masksToBounds = YES;
    }
    return _progressView;
}

- (UIView *)trackView
{
    if (_trackView == nil){
        _trackView = [[UIView alloc] init];
        _trackView.frame = self.bounds;
        _trackView.backgroundColor = [UIColor blackColor];
        _trackView.layer.cornerRadius = self.bounds.size.height / 2.0f;
        _trackView.layer.masksToBounds = YES;
    }
    return _trackView;
}

@end
