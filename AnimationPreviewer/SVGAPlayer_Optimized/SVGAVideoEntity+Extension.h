//
//  SVGAVideoEntity+Extension.h
//  SVGAPlayer_Optimized
//
//  Created by aa on 2023/11/20.
//

#import "SVGAVideoEntity.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SVGAVideoEntityError) {
    /// 木有问题
    SVGAVideoEntityError_None = 0,
    /// 画面没有尺寸
    SVGAVideoEntityError_ZeroVideoSize = 1,
    /// FPS为0
    SVGAVideoEntityError_ZeroFPS = 2,
    /// 帧数为0
    SVGAVideoEntityError_ZeroFrames = 3,
};

@interface SVGAVideoEntity (Extension)

/// 最小帧数（0）
@property (readonly) NSInteger minFrame;

/// 最大帧数
@property (readonly) NSInteger maxFrame;

/// 总时长
@property (readonly) NSTimeInterval duration;

/// 资源错误
@property (readonly) SVGAVideoEntityError entityError;

/// 是否带有音频
@property (readonly) BOOL isHasAudio;

@end

NS_ASSUME_NONNULL_END
