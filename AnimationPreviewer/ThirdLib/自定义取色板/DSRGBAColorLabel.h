//
//  DSRGBAColorLabel.h
//  Infinitee2.0
//
//  Created by 周健平 on 2017/11/15.
//  Copyright © 2017年 Infinitee. All rights reserved.
//

#import <UIKit/UIKit.h>
@class DSRGBAColorLabel;

@protocol DSRGBAColorLabelDelegate <NSObject>

- (void)colorLabelDidClick:(DSRGBAColorLabel *)colorLabel;

@end

@interface DSRGBAColorLabel : UIView
- (instancetype)initWithFrame:(CGRect)frame title:(NSString *)title delegate:(id<DSRGBAColorLabelDelegate>)delegate;

@property (nonatomic, weak) id<DSRGBAColorLabelDelegate> delegate;
@property (nonatomic, assign) int colorValue;

@end
