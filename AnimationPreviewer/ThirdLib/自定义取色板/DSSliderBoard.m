//
//  DSSliderBoard.m
//  Infinitee2.0
//
//  Created by 周健平 on 2017/11/13.
//  Copyright © 2017年 Infinitee. All rights reserved.
//

#import "DSSliderBoard.h"

@interface DSSliderBoard ()
@property (nonatomic, assign) BOOL isTouching;
@property (nonatomic, assign) BOOL isAnimate;
@end

@implementation DSSliderBoard
{
    float _totalValue;
}

#pragma mark - build & init

+ (CGFloat)viewHeight {
    return 60.0;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _maxValue = 1.0;
        _minValue = 0.0;
        _totalValue = 1.0;
        
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(25, 0, frame.size.width - 50, frame.size.height)];
        slider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.2];
        slider.minimumTrackTintColor = [UIColor whiteColor];
        slider.thumbTintColor = [UIColor whiteColor];
        [self addSubview:slider];
        self.slider = slider;
        
        [slider addTarget:self action:@selector(sliderBegin) forControlEvents:UIControlEventTouchDown];
        
        [slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
        
        [slider addTarget:self action:@selector(sliderEnd) forControlEvents:UIControlEventTouchCancel];
        [slider addTarget:self action:@selector(sliderEnd) forControlEvents:UIControlEventTouchUpInside];
        [slider addTarget:self action:@selector(sliderEnd) forControlEvents:UIControlEventTouchUpOutside];
    }
    return self;
}

#pragma mark - value text

- (NSString *)valueText {
    if ([self.delegate respondsToSelector:@selector(sliderValueText:)]) {
        return [self.delegate sliderValueText:self.sliderValue];
    }
    return [NSString stringWithFormat:@"%.2f", self.sliderValue];
}

#pragma mark - slider

- (void)sliderBegin {
    self.isAnimate = NO;
    self.isTouching = YES;
    if ([self.delegate respondsToSelector:@selector(sliderValueTouchBegin)]) {
        [self.delegate sliderValueTouchBegin];
    }
}

- (void)sliderChanged {
    if ([self.delegate respondsToSelector:@selector(sliderValueDidChanged:)]) {
        [self.delegate sliderValueDidChanged:self.sliderValue];
    }
}

- (void)sliderEnd {
    self.isAnimate = NO;
    self.isTouching = NO;
    if ([self.delegate respondsToSelector:@selector(sliderValueTouchDone)]) {
        [self.delegate sliderValueTouchDone];
    }
}

#pragma mark - public method

- (void)resetSliderValue:(float)sliderValue isAnimate:(BOOL)isAnimate {
    self.isAnimate = isAnimate;
    
    if (isAnimate) {
        self.userInteractionEnabled = NO;
        [UIView animateWithDuration:0.35 animations:^{
            self.sliderValue = sliderValue;
            [self.slider layoutIfNeeded];
        } completion:^(BOOL finished) {
            self.userInteractionEnabled = YES;
            if (self.isAnimate) {
                self.isAnimate = NO;
            }
        }];
    } else {
        self.sliderValue = sliderValue;
    }
}

- (void)resetSliderValue:(float)sliderValue {
    [self resetSliderValue:sliderValue isAnimate:NO];
}

- (void)setMaxValue:(float)maxValue {
    _maxValue = maxValue;
    _totalValue = maxValue - _minValue;
}

- (void)setMinValue:(float)minValue {
    _minValue = minValue;
    _totalValue = _maxValue - minValue;
}

- (void)setSliderValue:(float)sliderValue {
    self.slider.value = sliderValue / _totalValue;
}

- (float)sliderValue {
    return self.slider.value * _totalValue;
}

@end
