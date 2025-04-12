//
//  DSSliderBoard.h
//  Infinitee2.0
//
//  Created by 周健平 on 2017/11/13.
//  Copyright © 2017年 Infinitee. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol DSSliderBoardDelegate <NSObject>

- (void)sliderValueTouchBegin;
- (void)sliderValueTouchDone;
- (void)sliderValueDidChanged:(float)sliderValue;

- (NSString *)sliderValueText:(float)sliderValue;

@end

@interface DSSliderBoard : UIView

+ (CGFloat)viewHeight;

- (void)resetSliderValue:(float)sliderValue isAnimate:(BOOL)isAnimate;
- (void)resetSliderValue:(float)sliderValue;

@property (nonatomic, assign) id<DSSliderBoardDelegate> delegate;

@property (nonatomic, assign) float sliderValue;
@property (nonatomic, assign) float maxValue;
@property (nonatomic, assign) float minValue;

@property (nonatomic, weak) UISlider *slider;

@end
