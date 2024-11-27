//
//  VideoMaker+ImageTest.swift
//  Neves
//
//  Created by aa on 2021/10/25.
//

import UIKit
import AVFoundation

extension VideoMaker {
    static func makeVideoTest(framerate: Int,
                          frameInterval: Int,
                          duration: TimeInterval,
                          size: CGSize,
                          audioPath: String? = nil,
                          animLayer: VideoAnimationLayer? = nil,
                          imageStores: [VideoImageStore],
                          completion: @escaping Completion) {
        
        guard !Thread.isMainThread else {
            Asyncs.async {
                makeVideo(framerate: framerate,
                          frameInterval: frameInterval,
                          duration: duration,
                          size: size,
                          audioPath: audioPath,
                          animLayer: animLayer,
                          imageStores: imageStores,
                          completion: completion)
            }
            return
        }
//        JPrint("makeVideo", Thread.current)
        
//        UIGraphicsBeginImageContextWithOptions(size, false, 1)
//        defer { UIGraphicsEndImageContext() }
//
//        guard let ctx = UIGraphicsGetCurrentContext() else {
//            Asyncs.main { completion(.failure(.writerError)) }
//            return
//        }
        
        let videoName = "\(Int(Date().timeIntervalSince1970)).mp4"
        let videoPath = File.tmpFilePath(videoName)
        
        guard let videoWriter = try? AVAssetWriter(url: URL(fileURLWithPath: videoPath), fileType: .mp4) else {
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        videoWriter.shouldOptimizeForNetworkUse = true
        
        let writerInput = createVideoWriterInput(frameInterval: frameInterval, size: size)
        
        var keyCallBacks = kCFTypeDictionaryKeyCallBacks
        var valCallBacks = kCFTypeDictionaryValueCallBacks
        guard let empty = CFDictionaryCreate(kCFAllocatorDefault, nil, nil, 0, &keyCallBacks, &valCallBacks) else {
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: empty
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: attributes as [String: Any])
        
        guard videoWriter.canAdd(writerInput) else {
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        videoWriter.add(writerInput)
        
        guard videoWriter.startWriting() else {
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        videoWriter.startSession(atSourceTime: .zero)
        JPrint("startSession", Thread.current) // 卡顿所在
        
        let timescale = CMTimeScale(framerate)
        let fps: CGFloat = 1.0 / CGFloat(frameInterval)
        
        let totalFrame = framerate * Int(duration)
        let frameCount = frameInterval * Int(duration)
        
        var lastFrame: Int = -1
        var lastTime: CGFloat = -1
        var lastPixelBuffer: CVPixelBuffer? = nil
        
//        var bitmapRawValue = CGBitmapInfo.byteOrder32Little.rawValue
//        bitmapRawValue |= CGImageAlphaInfo.noneSkipFirst.rawValue
//        guard let context = CGContext(data: nil,
//                                      width: Int(size.width),
//                                      height: Int(size.height),
//                                      bitsPerComponent: 8,
//                                      bytesPerRow: 0,
//                                      space: ColorSpace,
//                                      bitmapInfo: bitmapRawValue) else { return }
        
        var bitmapRawValue = CGBitmapInfo.byteOrder32Little.rawValue
        bitmapRawValue |= CGImageAlphaInfo.noneSkipFirst.rawValue
        guard let context = CGContext(data: nil,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: ColorSpace,
                                      bitmapInfo: bitmapRawValue) else { return }
        
        for i in 0 ... frameCount {
            // framerate和frameInterval不一样的情况，该处理有待考量
            let currentFrame: Int
            if framerate == frameInterval {
                currentFrame = i
            } else {
                let progress = CGFloat(i) / CGFloat(frameCount)
                currentFrame = Int(round(Double(totalFrame) * progress))
            }
            let currentTime = CGFloat(currentFrame) * fps
            
            if lastTime == currentTime {
                JPrint("这两个时间一样 lastTime", lastTime, ", currentTime", currentTime)
            }
            lastTime = currentTime
            
            // 这里会有一定概率出现错误：Code=-11800 "The operation could not be completed"
            // 这是因为写入了相同的currentFrame造成的，所以要这里做判断，相同就跳过
            if lastFrame == currentFrame {
                JPrint("这两个frame一样 lastFrame", lastFrame, ", currentFrame", currentFrame)
                continue
            }
            lastFrame = currentFrame
            
            while true {
                if adaptor.assetWriterInput.isReadyForMoreMediaData ||
                   videoWriter.status != .writing {
                    break
                }
            }
            if videoWriter.status != .writing {
                // 其中一个错误：Code=-11800 "The operation could not be completed"
                // 这是因为写入了相同的currentFrame造成的
                JPrint("失败？？？", videoWriter.status.rawValue,
                       videoWriter.error ?? "",
                       adaptor.assetWriterInput.isReadyForMoreMediaData)
                
                File.manager.deleteFile(videoPath)
                Asyncs.main { completion(.failure(.writerError)) }
                return
            }
            
            var kCgImage: CGImage?
            autoreleasepool {
                if let girl = UIImage(contentsOfFile: Bundle.main.path(forResource: "girl", ofType: "jpg")!)?.cgImage {
                    context.draw(girl, in: [HalfDiffValue(size.width, CGFloat(girl.width)), 0, size.height * (CGFloat(girl.width) / CGFloat(girl.height)), size.height])
                }
                if let bg = UIImage(named: "album_videobg_jielong")?.cgImage {
                    context.draw(bg, in: CGRect(origin: .zero, size: size))
                }
                for store in imageStores {
                    if let image = store.getImage(currentTime)?.cgImage {
                        context.draw(image, in: CGRect(origin: .zero, size: size))
                    }
                }
                if let cgImage = context.makeImage() {
                    kCgImage = cgImage
                    JPrint(i, cgImage.width)
                }
            }
            context.clear(CGRect(origin: .zero, size: size))
            
            var pixelBuffer: CVPixelBuffer?
            autoreleasepool {
                if let cgImage = kCgImage,
                   let pb = createPixelBufferWithImage(cgImage,
//                                                       pixelBufferPool: adaptor.pixelBufferPool,
                                                       size: size) {
                    lastPixelBuffer = pb
                    pixelBuffer = pb
                } else {
                    pixelBuffer = lastPixelBuffer ?? {
                        let pb = createPixelBufferWithImage(UIColor.black.toImage(), size: size)!
                        lastPixelBuffer = pb
                        return pb
                    }()
                }
            }

            if let pixelBuffer = pixelBuffer {
                let frameTime = CMTime(value: CMTimeValue(currentFrame), timescale: timescale)
                adaptor.append(pixelBuffer, withPresentationTime: frameTime)
            }
        }
        
        writerInput.markAsFinished()
        JPrint("markAsFinished", Thread.current)
        
        let endTime = CMTime(value: CMTimeValue(totalFrame), timescale: timescale)
        videoWriter.endSession(atSourceTime: endTime)
        
        let lock = DispatchSemaphore(value: 0)
        videoWriter.finishWriting { lock.signal() }
        lock.wait()
        
        switch videoWriter.status {
        case .completed:
            break
        default:
            File.manager.deleteFile(videoPath)
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        let cachePath = File.cacheFilePath(videoName)
        File.manager.deleteFile(cachePath)
        
        guard let audioPath = audioPath else {
            File.manager.moveFile(videoPath, toPath: cachePath)
            Asyncs.main { completion(.success(cachePath)) }
            return
        }
        
        let videoAsset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
        let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))
        
        let videoDuration = videoAsset.duration
        
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first,
              let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
            File.manager.deleteFile(videoPath)
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        let mixComposition = AVMutableComposition()
        
        guard let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            File.manager.deleteFile(videoPath)
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        do {
            try compositionVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)
            
            var audioDuration = audioAsset.duration
            if audioDuration > videoDuration {
                audioDuration = videoDuration
            }
            try compositionAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: audioDuration), of: audioTrack, at: .zero)
        } catch {
            File.manager.deleteFile(videoPath)
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        var videoComposition: AVMutableVideoComposition?
        if let animLayer = animLayer {
            let layerInstruciton = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: videoDuration)
            instruction.layerInstructions = [layerInstruciton]
            
            let composition = AVMutableVideoComposition()
            composition.instructions = [instruction]
            composition.frameDuration = CMTime(value: 1, timescale: timescale)
            composition.renderScale = 1
            composition.renderSize = size
            
            // 视频layer
            let videoLayer = CALayer()
            videoLayer.frame = CGRect(origin: .zero, size: size)
            videoLayer.addSublayer(animLayer)
            
            // 父layer
            let parentLayer = CALayer()
            parentLayer.frame = CGRect(origin: .zero, size: size)
            parentLayer.contentsScale = 1
            parentLayer.isGeometryFlipped = true
            parentLayer.addSublayer(videoLayer)
            
            // 将合成的parentLayer关联到composition中
            composition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
            
            animLayer.addAnimate()
            videoComposition = composition
        }
        
        guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            File.manager.deleteFile(videoPath)
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        exportSession.outputFileType = .mp4
        exportSession.outputURL = URL(fileURLWithPath: cachePath)
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition
        
        exportSession.exportAsynchronously {
            File.manager.deleteFile(videoPath)
            switch exportSession.status {
            case .completed:
                Asyncs.main { completion(.success(cachePath)) }
            default:
                Asyncs.main { completion(.failure(.writerError)) }
            }
        }
    }
}

