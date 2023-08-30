//
//  LottieImagePicker.swift
//  Neves
//
//  Created by aa on 2021/10/8.
//

import UIKit

class LottieImagePicker {
    
    let pickQueue = DispatchQueue(label: "LottieImagePicker.SerialQueue")
    
    let animation: LottieAnimation
    
    let provider: AnimationImageProvider
    
    let animLayer: MainThreadAnimationLayer
    
    let animFramerate: CGFloat
    
    let animStartFrame: CGFloat
    
    let animEndFrame: CGFloat
    
    let animTotalFrame: CGFloat
    
    let animDuration: TimeInterval
    
    init(animation: LottieAnimation,
         provider: AnimationImageProvider,
         bgColor: UIColor?,
         animSize: CGSize?,
         renderScale: CGFloat?) {
        
        self.animation = animation
        self.provider = provider
        
        animFramerate = animation.framerate
        animStartFrame = animation.startFrame
        animEndFrame = animation.endFrame
        animTotalFrame = animEndFrame - animStartFrame
        animDuration = animation.duration
        
        let animLayer = MainThreadAnimationLayer(animation: animation,
                                                 imageProvider: provider,
                                                 textProvider: DefaultTextProvider(),
                                                 fontProvider: DefaultFontProvider(),
                                                 logger: LottieLogger.shared)
        animLayer.backgroundColor = bgColor.map { $0.cgColor } ?? UIColor.clear.cgColor
        animLayer.frame = .init(origin: .zero, size: animSize ?? animation.bounds.size)
        
        let scale: CGFloat
        if animation.bounds.size.width < animation.bounds.size.height {
            scale = animLayer.bounds.height / animation.bounds.size.height
        } else {
            scale = animLayer.bounds.width / animation.bounds.size.width
        }
        animLayer.animationLayers.forEach {
            $0.transform = CATransform3DMakeScale(scale, scale, 1)
            // $0.anchorPoint 是 [0, 0]
            $0.position = [HalfDiffValue(animLayer.bounds.width, $0.frame.width),
                           HalfDiffValue(animLayer.bounds.height, $0.frame.height)]
        }
        
        animLayer.renderScale = renderScale ?? 1
        animLayer.reloadImages()
        animLayer.setNeedsDisplay()
        
        self.animLayer = animLayer
    }
    
    func update(_ currentFrame: Int) {
        let totalFrame = Int(animTotalFrame)
        var fixFrame = CGFloat(currentFrame % totalFrame)
        if fixFrame == 0 {
            fixFrame = currentFrame == 0 ? 0 : animTotalFrame
        }
        animLayer.currentFrame = animStartFrame + fixFrame
        animLayer.display()
    }
    
    func update(_ currentTime: TimeInterval) {
        var fixTime = currentTime
        if currentTime > animDuration {
            let multiple = Int(currentTime / animDuration)
            fixTime -= animDuration * TimeInterval(multiple)
        }
        animLayer.currentFrame = animStartFrame + fixTime * animFramerate
        animLayer.display()
    }
}

// MARK: - 截取Lottie动画的其中一帧生成图片
extension LottieImagePicker {
    
    func asyncPickAllImages(framerate: CGFloat? = nil, directoryPath: String, completion: @escaping (Bool) -> ()) {
        
        Asyncs.async {
            let framerateScale = (framerate ?? self.animFramerate) / self.animFramerate
            if framerateScale <= 0 {
                DispatchQueue.main.async { completion(false) }
                return
            }
//            if framerateScale > 1 { framerateScale = 1 }
            
            UIGraphicsBeginImageContextWithOptions(self.animLayer.frame.size, false, self.animLayer.renderScale)
            
            guard let ctx = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            var isSuccess = true
            let lock = DispatchSemaphore(value: 0)
            
            let totalFrame = self.animTotalFrame * framerateScale
            let totalCount = Int(totalFrame)
            
            for i in 0 ... totalCount {
                let progress = CGFloat(i) / totalFrame
                let currentFrame = self.animStartFrame + self.animTotalFrame * progress
                
                DispatchQueue.main.sync {
                    self.animLayer.currentFrame = currentFrame
                    self.animLayer.display()
                    lock.signal()
                }
                lock.wait()
                
                // 画
                ctx.saveGState()
                self.animLayer.render(in: ctx)
                guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                    isSuccess = false
                    break
                }
                ctx.clear(CGRect(origin: .zero, size: self.animLayer.frame.size))
                ctx.restoreGState()
                
                // 写
                var isContainsAlpha: Bool = {
                    guard let cgImage = image.cgImage else {
                        return false
                    }
                    let alphaInfo = cgImage.alphaInfo
                    if alphaInfo == .premultipliedLast ||
                        alphaInfo == .premultipliedFirst ||
                        alphaInfo == .last ||
                        alphaInfo == .first {
                        return true
                    }
                    return false
                }()
                guard let imgData = isContainsAlpha ?
                            image.pngData() :
                            image.jpegData(compressionQuality: 0.9)
                else {
                    isSuccess = false
                    break
                }
                
                var url = URL(fileURLWithPath: directoryPath)
                if isContainsAlpha {
                    url.appendPathComponent("image_\(i).png")
                } else {
                    url.appendPathComponent("image_\(i).jpg")
                }
                
                do {
                    try imgData.write(to: url)
                } catch {
                    JPrint("写入错误 ---", url.path)
                    isSuccess = false
                    break
                }
                
            }
            
            UIGraphicsEndImageContext()
            DispatchQueue.main.async { completion(isSuccess) }
        }
        
    }
    
}

extension LottieImagePicker {
    convenience init?(directoryPath: String, bgColor: UIColor? = nil, animSize: CGSize? = nil, renderScale: CGFloat? = nil) {
        let jsonPath = directoryPath + "/" + "data.json"
        let imageDirPath = directoryPath + "/" + "images"
        
        guard File.manager.fileExists(jsonPath) else {
            JPrint("不存在JSON文件！")
            return nil
        }
        
        guard File.manager.fileExists(imageDirPath) else {
            JPrint("不存在图片文件夹！")
            return nil
        }
        
        guard let animation = LottieAnimation.filepath(jsonPath, animationCache: LRUAnimationCache.sharedCache) else {
            JPrint("animation错误！")
            return nil
        }
        
        guard let provider = DecodeImageProvider(imageDirPath: imageDirPath) else {
            JPrint("provider错误！")
            return nil
        }
        
        self.init(animation: animation, provider: provider, bgColor: bgColor, animSize: animSize, renderScale: renderScale)
    }
    
    convenience init?(lottieName: String, bgColor: UIColor? = nil, animSize: CGSize? = nil, renderScale: CGFloat? = nil) {
        guard let directoryPath = Bundle.main.path(forResource: "lottie/\(lottieName)", ofType: nil) else {
            JPrint("路径错误！")
            return nil
        }
        self.init(directoryPath: directoryPath, bgColor: bgColor, animSize: animSize, renderScale: renderScale)
    }
}

extension LottieImagePicker {
    /// Converts Frame Time (Seconds * Framerate) into Progress Time (0 to 1).
    /// 这一帧是多少进度
    func progressTime(forFrame frameTime: CGFloat) -> CGFloat {
        if frameTime <= animStartFrame { return 0 }
        if frameTime >= animEndFrame { return 1 }
        return (frameTime - animStartFrame) / animTotalFrame
    }

    /// Converts Progress Time (0 to 1) into Frame Time (Seconds * Framerate)
    /// 这进度是第几帧
    func frameTime(forProgress progressTime: CGFloat) -> CGFloat {
      return ((animEndFrame - animStartFrame) * progressTime) + animStartFrame
    }

    /// Converts Frame Time (Seconds * Framerate) into Time (Seconds)
    /// 这一帧是多少秒
    func time(forFrame frameTime: CGFloat) -> TimeInterval {
      return Double(frameTime - animStartFrame) / animFramerate
    }

    /// Converts Time (Seconds) into Frame Time (Seconds * Framerate)
    /// 这一秒是第几帧
    func frameTime(forTime time: TimeInterval) -> CGFloat {
      return CGFloat(time * animFramerate) + animStartFrame
    }
}
