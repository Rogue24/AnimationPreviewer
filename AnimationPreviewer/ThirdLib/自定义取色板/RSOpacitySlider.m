//
//  RSOpacitySlider.m
//  RSColorPicker
//
//  Created by Jared Allen on 5/16/13.
//  Copyright (c) 2013 Red Cactus LLC. All rights reserved.
//

#import "RSOpacitySlider.h"

#import "RSColorFunctions.h"

@implementation RSOpacitySlider

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self initRoutine];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initRoutine];
    }
    return self;
}

- (void)initRoutine {
    self.minimumValue = 0.0;
    self.maximumValue = 1.0;
    self.continuous = YES;

    self.enabled = YES;
    self.userInteractionEnabled = YES;

    [self addTarget:self action:@selector(myValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    CGSize size = CGSizeMake(self.bounds.size.height - 2, self.bounds.size.height - 2);
    UIImage *thumbImage = [UIImage imageNamed:@"slider-oval"];
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [thumbImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
    thumbImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self setThumbImage:thumbImage forState:UIControlStateNormal];
    [self setMinimumTrackTintColor:[UIColor clearColor]];
    [self setMaximumTrackTintColor:[UIColor clearColor]];
}

-  (void)didMoveToWindow {
    if (!self.window) return;

//    UIImage *backgroundImage = RSOpacityBackgroundImage(16.f, self.window.screen.scale, [UIColor colorWithWhite:0.5 alpha:1.0]);
    
}

- (void)myValueChanged:(id)notif {
    _colorPicker.opacity = self.value;
}

- (void)setColorPicker:(RSColorPickerView *)cp {
    _colorPicker = cp;
    if (!_colorPicker) { return; }
    self.value = [_colorPicker brightness];
}

@end
