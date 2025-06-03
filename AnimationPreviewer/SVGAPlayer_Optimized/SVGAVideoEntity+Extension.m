//
//  SVGAVideoEntity+Extension.m
//  SVGAPlayer_Optimized
//
//  Created by aa on 2023/11/20.
//

#import "SVGAVideoEntity+Extension.h"

@implementation SVGAVideoEntity (Extension)

- (NSInteger)minFrame {
    return 0;
}

- (NSInteger)maxFrame {
    int frames = self.frames;
    return frames > 1 ? (frames - 1) : 0;
}

- (NSTimeInterval)duration {
    int frames = self.frames;
    int fps = self.FPS;
    if (frames > 0 && fps > 0) {
        return (NSTimeInterval)frames / (NSTimeInterval)fps;
    }
    return 0;
}

- (SVGAVideoEntityError)entityError {
    if (self.videoSize.width <= 0 || self.videoSize.height <= 0) {
        return SVGAVideoEntityError_ZeroVideoSize;
    }
    else if (self.FPS == 0) {
        return SVGAVideoEntityError_ZeroFPS;
    }
    else if (self.frames == 0) {
        return SVGAVideoEntityError_ZeroFrames;
    }
    return SVGAVideoEntityError_None;
}

- (BOOL)isHasAudio {
    return self.audiosData.count > 0 && self.audios.count > 0;
}

@end
