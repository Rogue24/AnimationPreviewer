//
//  VideoMaker.Lottie.swift
//  Neves
//
//  Created by aa on 2021/10/15.
//

extension VideoMaker {
    
    func makeVideo(with picker: LottieImagePicker, completion: @escaping (Result<String, MakeError>) -> ()) {
        Asyncs.async {
            
            let framerate = Int(picker.animFramerate)
//            let frameInterval = framerate
            let frameInterval = framerate / 2
            let duration = picker.animDuration
            let animLayer = picker.animLayer
            let size = animLayer.frame.size
            let scale = animLayer.renderScale
            
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            
            guard let ctx = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                Asyncs.main { completion(.failure(.writerError)) }
                return
            }
            
            let bgImage = UIImage(named: "album_videobg_jielong")!.cgImage!
            
            
            let lock = DispatchSemaphore(value: 0)
            Self.createVideo(framerate: framerate, frameInterval: frameInterval, duration: duration, size: size) { currentFrame, _ in
                
                // 渲染
                DispatchQueue.main.sync {
                    animLayer.currentFrame = CGFloat(currentFrame)
                    animLayer.display()
                    lock.signal()
                }
                lock.wait()
                
                // 画
                ctx.saveGState()
                
                ctx.draw(bgImage, in: CGRect(origin: .zero, size: size))
                
                animLayer.render(in: ctx)
                let image = UIGraphicsGetImageFromCurrentImageContext()
                
                ctx.clear(CGRect(origin: .zero, size: size))
                ctx.restoreGState()
                
                return image
                
            } completion: { result in
                UIGraphicsEndImageContext()
                Asyncs.main { completion(result) }
            }
            
        }
    }
    
    
    
}
