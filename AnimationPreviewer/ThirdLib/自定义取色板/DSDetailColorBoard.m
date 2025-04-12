//
//  DSDetailColorBoard.m
//  Infinitee2.0
//
//  Created by 周健平 on 2017/11/13.
//  Copyright © 2017年 Infinitee. All rights reserved.
//

#import "DSDetailColorBoard.h"
#import "RSBrightnessSlider.h"
#import "RSOpacitySlider.h"
#import "SilderPlaceHolderView.h"
#import "DSRGBAColorLabel.h"
#import "DSSliderBoard.h"
#import <Animation_Previewer-Swift.h>

@interface DSDetailColorBoard () <RSColorPickerViewDelegate, DSRGBAColorLabelDelegate, DSSliderBoardDelegate>
@property (weak, nonatomic) SilderPlaceHolderView *opacityPlaceHolderView;
@property (weak, nonatomic) SilderPlaceHolderView *brightnessPlaceHolderView;
@property (weak, nonatomic) RSOpacitySlider *opacitySlider;
@property (weak, nonatomic) RSBrightnessSlider *brightnessSlider;

@property (nonatomic, weak) RSColorPickerView *colorPickerView;
@property (weak, nonatomic) DSRGBAColorLabel *rLabel;
@property (weak, nonatomic) DSRGBAColorLabel *gLabel;
@property (weak, nonatomic) DSRGBAColorLabel *bLabel;
@property (weak, nonatomic) DSRGBAColorLabel *aLabel;
@property (nonatomic, weak) DSRGBAColorLabel *currColorLabel;

@property (nonatomic, weak) UIView *bottomView;
@property (nonatomic, weak) DSSliderBoard *sliderBoard;

@property (nonatomic, assign) BOOL isShowingSlider;
@property (nonatomic, assign) BOOL isTouchingSlider;

@property (nonatomic, strong) NSTimer *timer;
@end

@implementation DSDetailColorBoard

+ (DSDetailColorBoard *)detailColorBoard {
    return [[self alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        
        CGFloat scale = 1;
        CGFloat sliderMargin = 25 * scale;
        CGFloat pickerMargin = 45 * scale;
        CGFloat colorTextMargin = 30 * scale;
        
        CGFloat width = 375;
        
        CGFloat sliderW = width - 2 * sliderMargin;
        CGFloat sliderH = 16;
        
        CGFloat space = 2 * pickerMargin + colorTextMargin;
        CGFloat colorPickerWH = (CGFloat)((NSInteger)(width - space - 76 * scale));
        
        CGFloat colorLabelW = width - space - colorPickerWH;
        CGFloat colorLabelH = (colorPickerWH - 2 * 7 - (4 - 1) * 10) / 4.0;
        
        CGFloat bottomViewH = 44.0;
        
        CGFloat colorWH = 40;
        
        CGFloat height = 20 + colorWH + 15 + 15 + sliderH + 15 + sliderH + 15 + colorPickerWH + 15 + bottomViewH;
        
        self.frame = CGRectMake(0, 0, width, height);
        
        UIControl *control = [[UIControl alloc] initWithFrame:self.bounds];
        [control addTarget:self action:@selector(hideSlider) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:control];
        
        CGFloat x = sliderMargin;
        CGFloat y = 20;
        
        CGFloat colorX = 15;
        CGFloat colorSpace = (sliderW - colorWH * 5.0 - colorX * 2.0) / 4.0;
        UIView *chooseColorList = [[UIView alloc] initWithFrame:CGRectMake(x, y, sliderW, colorWH)];
        [self addSubview:chooseColorList];
        for (NSInteger i = 0; i < 5; i++) {
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            switch (i) {
                case 0:
                    btn.backgroundColor = [UIColor systemBlueColor];
                    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
                    [btn setTitle:@"恢复" forState:UIControlStateNormal];
                    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    break;
                case 1:
                    btn.backgroundColor = [UIColor systemGray4Color];
                    btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
                    [btn setTitle:@"默认" forState:UIControlStateNormal];
                    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                    break;
                case 2:
                    btn.backgroundColor = [UIColor transparentGrid];
                    break;
                case 3:
                    btn.backgroundColor = [UIColor blackColor];
                    break;
                default:
                    btn.backgroundColor = [UIColor whiteColor];
                    break;
            }
            btn.layer.cornerRadius = colorWH * 0.5;
            btn.layer.masksToBounds = YES;
            btn.frame = CGRectMake(colorX, 0, colorWH, colorWH);
            btn.tag = i;
            [chooseColorList addSubview:btn];
            [btn addTarget:self action:@selector(chooseColorBtnDidClick:) forControlEvents:UIControlEventTouchUpInside];
            colorX += colorSpace + colorWH;
        }
        
        y = CGRectGetMaxY(chooseColorList.frame) + 15;
        CALayer *topLine = [CALayer layer];
        topLine.frame = CGRectMake(0, y, width, 0.5);
        topLine.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
        [self.layer addSublayer:topLine];
        
        y += 15;
        SilderPlaceHolderView *opacityPlaceHolderView = [[SilderPlaceHolderView alloc] initWithFrame:CGRectMake(x, y, sliderW, sliderH) baseColor:[UIColor clearColor]];
        UIImage *image = [UIImage imageNamed:@"alpha_img"];
        opacityPlaceHolderView.backgroundColor = [UIColor colorWithPatternImage:image];
        [self addSubview:opacityPlaceHolderView];
        self.opacityPlaceHolderView = opacityPlaceHolderView;
        
        RSOpacitySlider *opacitySlider = [[RSOpacitySlider alloc] initWithFrame:opacityPlaceHolderView.bounds];
        [opacityPlaceHolderView addSubview:opacitySlider];
        self.opacitySlider = opacitySlider;
        
        y = CGRectGetMaxY(opacityPlaceHolderView.frame) + 15;
        SilderPlaceHolderView *brightnessPlaceHolderView = [[SilderPlaceHolderView alloc] initWithFrame:CGRectMake(x, y, sliderW, sliderH) baseColor:[UIColor blackColor]];
        [self addSubview:brightnessPlaceHolderView];
        self.brightnessPlaceHolderView = brightnessPlaceHolderView;
        
        RSBrightnessSlider *brightnessSlider = [[RSBrightnessSlider alloc] initWithFrame:brightnessPlaceHolderView.bounds];
        [brightnessPlaceHolderView addSubview:brightnessSlider];
        self.brightnessSlider = brightnessSlider;
        
        x = pickerMargin;
        y = CGRectGetMaxY(brightnessPlaceHolderView.frame) + 15;
        RSColorPickerView *colorPickerView = [[RSColorPickerView alloc] initWithFrame:CGRectMake(x, y, colorPickerWH, colorPickerWH)];
        colorPickerView.cropToCircle = YES; // 切圆
        [self addSubview:colorPickerView];
        self.colorPickerView = colorPickerView;
        
        x = CGRectGetMaxX(colorPickerView.frame) + colorTextMargin;
        y = colorPickerView.frame.origin.y + 7;
        DSRGBAColorLabel *rLabel = [[DSRGBAColorLabel alloc] initWithFrame:CGRectMake(x, y, colorLabelW, colorLabelH) title:@"R" delegate:self];
        [self addSubview:rLabel];
        self.rLabel = rLabel;
        
        y = CGRectGetMaxY(rLabel.frame) + 10;
        DSRGBAColorLabel *gLabel = [[DSRGBAColorLabel alloc] initWithFrame:CGRectMake(x, y, colorLabelW, colorLabelH) title:@"G" delegate:self];
        [self addSubview:gLabel];
        self.gLabel = gLabel;
        
        y = CGRectGetMaxY(gLabel.frame) + 10;
        DSRGBAColorLabel *bLabel = [[DSRGBAColorLabel alloc] initWithFrame:CGRectMake(x, y, colorLabelW, colorLabelH) title:@"B" delegate:self];
        [self addSubview:bLabel];
        self.bLabel = bLabel;
        
        y = CGRectGetMaxY(bLabel.frame) + 10;
        DSRGBAColorLabel *aLabel = [[DSRGBAColorLabel alloc] initWithFrame:CGRectMake(x, y, colorLabelW, colorLabelH) title:@"A" delegate:self];
        [self addSubview:aLabel];
        self.aLabel = aLabel;
        
        x = 0;
        y = height - bottomViewH;
        UIView *bottomView = [self bottomViewWithFrame:CGRectMake(x, y, width, bottomViewH)];
        [self addSubview:bottomView];
        self.bottomView = bottomView;
        
        DSSliderBoard *sliderBoard = [[DSSliderBoard alloc] initWithFrame:CGRectMake(0, height, width, bottomViewH)];
        sliderBoard.backgroundColor = [UIColor clearColor];
        sliderBoard.alpha = 0;
        sliderBoard.minValue = 0.0;
        sliderBoard.delegate = self;
        [self addSubview:sliderBoard];
        self.sliderBoard = sliderBoard;
        
        CALayer *bottomLine = [CALayer layer];
        bottomLine.frame = CGRectMake(x, y, width, 0.5);
        bottomLine.backgroundColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
        [self.layer addSublayer:bottomLine];
        
//        [colorPickerView setSelectionColor:originColor]; // 初始化颜色
        [opacitySlider setColorPicker:colorPickerView]; // 关联透明度slider
        [brightnessSlider setColorPicker:colorPickerView]; // 关联亮度slider
        
        [colorPickerView setDelegate:self];
    }
    return self;
}

- (void)dealloc {
    [self removeTimer];
}

- (UIView *)bottomViewWithFrame:(CGRect)frame {
    UIView *bottomView = [[UIView alloc] initWithFrame:frame];
    bottomView.backgroundColor = [UIColor clearColor];
    
    UILabel *titleLabel = ({
        UILabel *aLabel = [[UILabel alloc] init];
        aLabel.textAlignment = NSTextAlignmentCenter;
        aLabel.font = [UIFont systemFontOfSize:15];
        aLabel.textColor = [UIColor whiteColor];
        aLabel.text = @"拖动选择自定义颜色";
        aLabel.frame = bottomView.bounds;
        aLabel;
    });
    [bottomView addSubview:titleLabel];
    
    return bottomView;
}

#pragma mark - control did click

- (void)hideSlider {
    if (!self.isShowingSlider) return;
    [self showOrHideSlider:NO];
    self.isTouchingSlider = NO;
}

#pragma mark - timer

- (void)addTimer {
    [self removeTimer];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(hideSlider) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)removeTimer {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

#pragma mark - show or hide slider

- (void)showOrHideSlider:(BOOL)isShow {
    [self removeTimer];
    if (self.isShowingSlider == isShow) {
        if (isShow) {
            [self addTimer];
        }
        return;
    }
    self.isShowingSlider = isShow;
    
    self.userInteractionEnabled = NO;
    
    NSTimeInterval duration = 0.3;
    NSTimeInterval beginTime = 0; // isShow ? 0.15 : 0;
    
    CGFloat height = self.frame.size.height;
    
    CGRect frame = self.sliderBoard.frame;
    frame.origin.y = isShow ? (height - self.sliderBoard.frame.size.height) : height;
    [UIView animateWithDuration:duration delay:beginTime usingSpringWithDamping:0.9 initialSpringVelocity:1 options:kNilOptions animations:^{
        self.sliderBoard.frame = frame;
        self.sliderBoard.alpha = isShow ? 1 : 0;
    } completion:^(BOOL finished) {
        if (self.isShowingSlider) {
            [self addTimer];
        }
        self.userInteractionEnabled = YES;
    }];
    
    beginTime = isShow ? 0 : 0.15;
    frame = self.bottomView.frame;
    frame.origin.y = isShow ? height : (height - self.sliderBoard.frame.size.height);
    [UIView animateWithDuration:duration delay:beginTime usingSpringWithDamping:0.9 initialSpringVelocity:1 options:kNilOptions animations:^{
        self.bottomView.frame = frame;
        self.bottomView.alpha = isShow ? 0 : 1;
    } completion:nil];
}

#pragma mark - choose color button did click

- (void)chooseColorBtnDidClick:(UIButton *)sender {
    if (!self.delegate) return;
    switch (sender.tag) {
        case 0:
            [self.delegate detailColorBoardDidChooseOriginColor];
            break;
        case 1:
            [self.delegate detailColorBoardDidChooseDefaultColor];
            break;
        case 2:
            [self.delegate detailColorBoardDidChooseTransparentGridColor];
            break;
        case 3:
            [self.delegate detailColorBoardDidChooseCustomColor:[UIColor blackColor]];
            break;
        default:
            [self.delegate detailColorBoardDidChooseCustomColor:[UIColor whiteColor]];
            break;
    }
}

#pragma mark - RSColorPickerViewDelegate

- (void)colorPickerDidChangeSelection:(RSColorPickerView *)cp {
    
    // Get color data
    UIColor *color = [cp selectionColor];
    
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    
    // Update important UI
    _brightnessSlider.value = [cp brightness];
    _opacitySlider.value = [cp opacity];
    
    CGFloat or = r / self.brightnessSlider.value;
    CGFloat og = g / self.brightnessSlider.value;
    CGFloat ob = b / self.brightnessSlider.value;
    
    self.opacityPlaceHolderView.sliderColor = [UIColor colorWithRed:or green:og blue:ob alpha:1];
    self.brightnessPlaceHolderView.sliderColor = [UIColor colorWithRed:or green:og blue:ob alpha:1];
    
    if (self.delegate) {
        [self.delegate detailColorBoardDidChooseCustomColor:color];
    }
    
    if (!self.isTouchingSlider) {
        [self showOrHideSlider:NO];
    } else {
        return;
    }
    
    // Debug
    //    NSString *colorDesc = [NSString stringWithFormat:@"rgba: %f, %f, %f, %f", r, g, b, a];
    //    NSLog(@"%@", colorDesc);
    int ir = r * 255 + 0.1;
    int ig = g * 255 + 0.1;
    int ib = b * 255 + 0.1;
    int ia = a * 100 + 0.1;
    //    colorDesc = [NSString stringWithFormat:@"rgba: %d, %d, %d, %d", ir, ig, ib, ia];
    //    NSLog(@"%@", colorDesc);
    //    _rgbLabel.text = colorDesc;
    self.rLabel.colorValue = ir;
    self.gLabel.colorValue = ig;
    self.bLabel.colorValue = ib;
    self.aLabel.colorValue = ia;
}

#pragma mark - DSRGBAColorLabelDelegate

- (void)colorLabelDidClick:(DSRGBAColorLabel *)colorLabel {
    self.currColorLabel = colorLabel;
    float maxValue = 255.0;
    if (colorLabel == self.aLabel) maxValue = 100.0;
    self.sliderBoard.maxValue = maxValue;
    [self.sliderBoard resetSliderValue:(float)colorLabel.colorValue isAnimate:self.isShowingSlider];
    [self showOrHideSlider:YES];
}

#pragma mark - DSSliderBoardDelegate

- (void)sliderValueTouchBegin {
    [self removeTimer];
    self.isTouchingSlider = YES;
}

- (void)sliderValueTouchDone {
    [self addTimer];
    self.isTouchingSlider = NO;
}

- (void)sliderValueDidChanged:(float)sliderValue {
    self.isTouchingSlider = YES;
    self.currColorLabel.colorValue = (int)(sliderValue + 0.1);
    int r = self.rLabel.colorValue;
    int g = self.gLabel.colorValue;
    int b = self.bLabel.colorValue;
    CGFloat a = self.aLabel.colorValue * 0.01;
    [self.colorPickerView setSelectionColor:[UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]];
}

- (NSString *)sliderValueText:(float)sliderValue {
    return [NSString stringWithFormat:@"%d", (int)(sliderValue + 0.1)];
}

@end
