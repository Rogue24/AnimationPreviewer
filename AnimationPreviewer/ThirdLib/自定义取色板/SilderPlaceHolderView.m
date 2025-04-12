//
//  SilderPlaceHolderView.m
//  Infinitee2.0-Design
//
//  Created by Jill on 16/9/26.
//  Copyright © 2016年 陈珏洁. All rights reserved.
//

#import "SilderPlaceHolderView.h"

@implementation SilderPlaceHolderView

- (instancetype)initWithFrame:(CGRect)frame baseColor:(UIColor *)baseColor {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = frame.size.height * 0.5;
//        self.layer.borderWidth = 0.5;
//        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
        self.baseColor = baseColor;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    if (!self.baseColor || !self.sliderColor) return;
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    NSArray *colors = @[(id)self.baseColor.CGColor,
                        (id)self.sliderColor.CGColor];
    
    CGGradientRef myGradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, NULL);
    
    CGContextDrawLinearGradient(ctx, myGradient, CGPointZero, CGPointMake(rect.size.width, 0), 0);
    CGGradientRelease(myGradient);
    CGColorSpaceRelease(space);
}

- (void)setSliderColor:(UIColor *)sliderColor {
    _sliderColor = sliderColor;
    [self setNeedsDisplay];
}

@end
