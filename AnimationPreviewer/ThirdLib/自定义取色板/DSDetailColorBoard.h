//
//  DSDetailColorBoard.h
//  Infinitee2.0
//
//  Created by 周健平 on 2017/11/13.
//  Copyright © 2017年 Infinitee. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DSDetailColorBoardDelegate <NSObject>

- (void)detailColorBoardDidChooseOriginColor;
- (void)detailColorBoardDidChooseDefaultColor;
- (void)detailColorBoardDidChooseTransparentGridColor;
- (void)detailColorBoardDidChooseCustomColor:(UIColor *)color;

@end

@interface DSDetailColorBoard : UIView

+ (DSDetailColorBoard *)detailColorBoard;

@property (nonatomic, weak) id<DSDetailColorBoardDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
