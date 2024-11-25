//
//  SVGARePlayer.h
//  SVGAPlayer_OptimizedDemo
//
//  Created by aa on 2023/11/6.
//

#import <UIKit/UIKit.h>
#import "SVGAVideoEntity+Extension.h"

NS_ASSUME_NONNULL_BEGIN

@class SVGARePlayer;

typedef void(^SVGARePlayerDrawingBlock)(CALayer *contentLayer, NSInteger frameIndex);

typedef NS_ENUM(NSUInteger, SVGARePlayerPlayError) {
    /// 没有SVGA资源
    SVGARePlayerPlayError_NullEntity = 1,
    /// 没有父视图
    SVGARePlayerPlayError_NullSuperview = 2,
    /// 只有一帧可播放帧（无法形成动画）
    SVGARePlayerPlayError_OnlyOnePlayableFrame = 3,
};

typedef NS_ENUM(NSUInteger, SVGARePlayerStoppedScene) {
    /// 停止后清空图层
    SVGARePlayerStoppedScene_ClearLayers = 0,
    /// 停止后留在最后
    SVGARePlayerStoppedScene_StepToTrailing = 1,
    /// 停止后回到开头
    SVGARePlayerStoppedScene_StepToLeading = 2,
};

@protocol SVGARePlayerDelegate <NSObject>
@optional
/// 正在播放的回调
- (void)svgaRePlayer:(SVGARePlayer *)player animationPlaying:(NSInteger)currentFrame;
/// 完成一次播放的回调
- (void)svgaRePlayer:(SVGARePlayer *)player animationDidFinishedOnce:(NSInteger)loopCount;
/// 完成所有播放的回调（前提条件：`loops > 0`）
- (void)svgaRePlayer:(SVGARePlayer *)player animationDidFinishedAll:(NSInteger)loopCount;
/// 播放失败的回调
- (void)svgaRePlayer:(SVGARePlayer *)player animationPlayFailed:(SVGARePlayerPlayError)error;
@end

@interface SVGARePlayer: UIView
/// 代理
@property (nonatomic, weak) id<SVGARePlayerDelegate> delegate;

/// 播放所在RunLoop模式（默认为CommonMode）
@property (nonatomic, copy) NSRunLoopMode mainRunLoopMode;

/// 主动调用`stopAnimation`后的情景
@property (nonatomic, assign) SVGARePlayerStoppedScene userStoppedScene;
/// 完成所有播放后（需要设置`loops > 0`）的情景
@property (nonatomic, assign) SVGARePlayerStoppedScene finishedAllScene;

/// 播放次数（大于0才会触发回调`svgaPlayerDidFinishedAllAnimation`）
@property (nonatomic, assign) NSInteger loops;
/// 当前播放次数
@property (nonatomic, assign, readonly) NSInteger loopCount;

/// 是否静音
@property (nonatomic, assign) BOOL isMute;

/// 是否反转播放
@property (nonatomic, assign) BOOL isReversing;

/// SVGA资源
@property (nonatomic, strong, nullable) SVGAVideoEntity *videoItem;
/// 起始帧数
@property (nonatomic, assign, readonly) NSInteger startFrame;
/// 结束帧数
@property (nonatomic, assign, readonly) NSInteger endFrame;
/// 头部帧数
@property (readonly) NSInteger leadingFrame;
/// 尾部帧数
@property (readonly) NSInteger trailingFrame;

/// 当前帧数
@property (nonatomic, assign, readonly) NSInteger currentFrame;

/// 当前进度
@property (readonly) float progress;

/// 是否播放中
@property (readonly) BOOL isAnimating;

/// 是否完成所有播放（前提条件：`loops > 0`）
@property (readonly) BOOL isFinishedAll;

#pragma mark - 更换SVGA资源+设置播放区间
- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
        currentFrame:(NSInteger)currentFrame;

- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
          startFrame:(NSInteger)startFrame
            endFrame:(NSInteger)endFrame;

- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem
          startFrame:(NSInteger)startFrame
            endFrame:(NSInteger)endFrame
        currentFrame:(NSInteger)currentFrame;

#pragma mark - 设置播放区间
/// 重置起始帧数为最小帧数（0），结束帧数为最大帧数（videoItem.frames）
- (void)resetStartFrameAndEndFrame;

/// 设置起始帧数，结束帧数为最大帧数（videoItem.frames）
- (void)setStartFrameUntilTheEnd:(NSInteger)startFrame;

/// 设置结束帧数，起始帧数为最小帧数（0）
- (void)setEndFrameFromBeginning:(NSInteger)endFrame;

- (void)setStartFrame:(NSInteger)startFrame
             endFrame:(NSInteger)endFrame;

- (void)setStartFrame:(NSInteger)startFrame
             endFrame:(NSInteger)endFrame
         currentFrame:(NSInteger)currentFrame;

#pragma mark - 重置loopCount
- (void)resetLoopCount;

#pragma mark - 开始播放（如果已经完成所有播放，则重置loopCount；返回YES代表播放成功）
- (BOOL)startAnimation;

#pragma mark - 跳至指定帧（如果已经完成所有播放，则重置loopCount；返回YES代表播放/跳转成功）
- (BOOL)stepToFrame:(NSInteger)frame;
- (BOOL)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay;

#pragma mark - 暂停播放
- (void)pauseAnimation;

#pragma mark - 停止播放
- (void)stopAnimation; // ==> [self stopAnimation:self.userStoppedScene];
- (void)stopAnimation:(SVGARePlayerStoppedScene)scene;

#pragma mark - Dynamic Object
- (void)setImage:(nullable UIImage *)image forKey:(NSString *)aKey;
- (void)setAttributedText:(nullable NSAttributedString *)attributedText forKey:(NSString *)aKey;
- (void)setDrawingBlock:(nullable SVGARePlayerDrawingBlock)drawingBlock forKey:(NSString *)aKey;
- (void)setHidden:(BOOL)hidden forKey:(NSString *)aKey;
- (void)clearDynamicObjects;

#warning JP修改_我需要用到drawLayer
- (nullable CALayer *)getDrawLayer;
@end

NS_ASSUME_NONNULL_END
