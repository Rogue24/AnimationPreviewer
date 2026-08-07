//
//  LottieFrameConverter.swift
//  AnimationPreviewer
//
//  Created by aa on 2026/8/7.
//

import UIKit
import Lottie

struct LottieFrameConverter {
    let framerate: CGFloat
    let startFrame: CGFloat
    let endFrame: CGFloat
    let totalFrame: CGFloat
    let duration: TimeInterval
    
    init(animation: LottieAnimation) {
        framerate = animation.framerate
        startFrame = animation.startFrame
        endFrame = animation.endFrame
        totalFrame = endFrame - startFrame
        duration = animation.duration
    }
    
//    func fixFrame(of currentFrame: Int) -> CGFloat {
//        let totalFrame = Int(self.totalFrame)
//        var fixFrame = CGFloat(currentFrame % totalFrame)
//        if fixFrame == 0 {
//            fixFrame = currentFrame == 0 ? 0 : self.totalFrame
//        }
//        return startFrame + fixFrame
//    }
    
    func frame(at currentTime: TimeInterval) -> CGFloat {
        var fixTime = currentTime
        if currentTime > duration {
            let multiple = Int(currentTime / duration)
            fixTime -= duration * TimeInterval(multiple)
        }
        return startFrame + fixTime * framerate
    }
}
