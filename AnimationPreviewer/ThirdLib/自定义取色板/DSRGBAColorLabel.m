//
//  DSRGBAColorLabel.m
//  Infinitee2.0
//
//  Created by 周健平 on 2017/11/15.
//  Copyright © 2017年 Infinitee. All rights reserved.
//

#import "DSRGBAColorLabel.h"

@interface DSRGBAColorLabel ()
@property (nonatomic, weak) UILabel *valueLabel;
@end

@implementation DSRGBAColorLabel

- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title delegate:(id<DSRGBAColorLabelDelegate>)delegate {
    if (self = [super initWithFrame:frame]) {
        self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.5].CGColor;
        self.layer.borderWidth = 1;
        self.layer.cornerRadius = 4;
        
        CGFloat scale = 1;
        
        CGFloat fontSize = 15 * scale;
        UILabel *titleLabel = ({
            UILabel *aLabel = [[UILabel alloc] init];
            aLabel.textAlignment = NSTextAlignmentCenter;
            aLabel.font = [UIFont boldSystemFontOfSize:fontSize];
            aLabel.textColor = [UIColor colorWithWhite:1 alpha:0.7];
            aLabel.text = title;
            [aLabel sizeToFit];
            aLabel.frame = CGRectMake(15 * scale, 0, aLabel.frame.size.width, frame.size.height);
            aLabel;
        });
        [self addSubview:titleLabel];
        
        UILabel *valueLabel = ({
            UILabel *aLabel = [[UILabel alloc] init];
            aLabel.textAlignment = NSTextAlignmentLeft;
            aLabel.font = [UIFont systemFontOfSize:fontSize];
            aLabel.textColor = [UIColor whiteColor];
            aLabel.text = @"0";
            CGFloat x = CGRectGetMaxX(titleLabel.frame) + 10 * scale;
            aLabel.frame = CGRectMake(x, 0, frame.size.width - x, frame.size.height);
            aLabel;
        });
        [self addSubview:valueLabel];
        self.valueLabel = valueLabel;
        
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap)]];
        
        self.delegate = delegate;
    }
    return self;
}

- (void)setColorValue:(int)colorValue {
    _colorValue = colorValue;
    self.valueLabel.text = [NSString stringWithFormat:@"%d", colorValue];
}

- (void)tap {
    if ([self.delegate respondsToSelector:@selector(colorLabelDidClick:)]) {
        [self.delegate colorLabelDidClick:self];
    }
}

@end
