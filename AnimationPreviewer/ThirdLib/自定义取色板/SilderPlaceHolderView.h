//
//  SilderPlaceHolderView.h
//  Infinitee2.0-Design
//
//  Created by Jill on 16/9/26.
//  Copyright © 2016年 陈珏洁. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SilderPlaceHolderView : UIView
- (instancetype)initWithFrame:(CGRect)frame baseColor:(UIColor *)baseColor;
@property (nonatomic, strong) UIColor *baseColor;
@property (nonatomic, strong) UIColor *sliderColor;
@end
