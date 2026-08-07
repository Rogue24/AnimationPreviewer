//
//  LottieFrameConverter.swift
//  AnimationPreviewer
//
//  Created by aa on 2026/8/7.
//

import UIKit
import Lottie

struct LottieFrameConverter {
    let animFramerate: CGFloat
    let animStartFrame: CGFloat
    let animEndFrame: CGFloat
    let animTotalFrame: CGFloat
    let animDuration: TimeInterval
    
    init(animation: LottieAnimation) {
        animFramerate = animation.framerate
        animStartFrame = animation.startFrame
        animEndFrame = animation.endFrame
        animTotalFrame = animEndFrame - animStartFrame
        animDuration = animation.duration
    }
    
//        func fixFrame(of currentFrame: Int) -> CGFloat {
//            let totalFrame = Int(animTotalFrame)
//            var fixFrame = CGFloat(currentFrame % totalFrame)
//            if fixFrame == 0 {
//                fixFrame = currentFrame == 0 ? 0 : animTotalFrame
//            }
//            return animStartFrame + fixFrame
//        }
    
    func frame(at currentTime: TimeInterval) -> CGFloat {
        var fixTime = currentTime
        if currentTime > animDuration {
            let multiple = Int(currentTime / animDuration)
            fixTime -= animDuration * TimeInterval(multiple)
        }
        return animStartFrame + fixTime * animFramerate
    }
}
