//
//  VideoMaker+Layer.swift
//  Neves
//
//  Created by aa on 2021/10/19.
//

import UIKit
import AVFoundation

protocol VideoAnimationLayer: CALayer {
    func addAnimate()
}

extension VideoMaker {
    static func makeVideo(framerate: Int,
                          frameInterval: Int,
                          duration: TimeInterval,
                          size: CGSize,
                          audioPath: String? = nil,
                          animLayer: VideoAnimationLayer? = nil,
                          layerProvider: @escaping LayerProvider,
                          progress: Progress?,
                          completion: @escaping Completion) {
        
        guard !Thread.isMainThread else {
            Asyncs.async {
                makeVideo(framerate: framerate,
                          frameInterval: frameInterval,
                          duration: duration,
                          size: size,
                          audioPath: audioPath,
                          animLayer: animLayer,
                          layerProvider: layerProvider,
                          progress: progress,
                          completion: completion)
            }
            return
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        defer { UIGraphicsEndImageContext() }
        
        guard let ctx = UIGraphicsGetCurrentContext() else {
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        let videoName = "\(Int(Date().timeIntervalSince1970)).mp4"
        let videoPath = File.tmpFilePath(videoName)
        
        guard let videoWriter = try? AVAssetWriter(url: URL(fileURLWithPath: videoPath), fileType: .mp4) else {
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        videoWriter.shouldOptimizeForNetworkUse = true
        
        let writerInput = createVideoWriterInput(frameInterval: frameInterval, size: size)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: createSourcePixelBufferAttributes())
        
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
        
        let timescale = CMTimeScale(framerate)
        let fps: CGFloat = 1.0 / CGFloat(frameInterval)
        
        let totalFrame = framerate * Int(duration)
        let frameCount = frameInterval * Int(duration)
        
        var lastFrame: Int = -1
        var lastTime: CGFloat = -1
        var lastPixelBuffer: CVPixelBuffer? = nil
        
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
                JPrint("视频生成失败！", videoWriter.status.rawValue,
                       videoWriter.error ?? "",
                       adaptor.assetWriterInput.isReadyForMoreMediaData)
                
                File.manager.deleteFile(videoPath)
                Asyncs.main { completion(.failure(.writerError)) }
                return
            }
            
            var layers: [CALayer?] = []
            DispatchQueue.main.sync {
                layers = layerProvider(currentFrame, currentTime, size)
            }
            autoreleasepool {
                layers.forEach {
                    guard let layer = $0 else { return }
                    layer.render(in: ctx)
                }
                let image = UIGraphicsGetImageFromCurrentImageContext()
                ctx.clear(CGRect(origin: .zero, size: size))
                
                let pixelBuffer: CVPixelBuffer
                if let image = image,
                   let pb = createPixelBufferWithImage(image,
                                                       pixelBufferPool: adaptor.pixelBufferPool,
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
                let frameTime = CMTime(value: CMTimeValue(currentFrame), timescale: timescale)
                adaptor.append(pixelBuffer, withPresentationTime: frameTime)
                
                progress?(i, frameCount)
            }
        }
        
        writerInput.markAsFinished()
        
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
            print("videoPath \(videoPath)")
            print("cachePath \(cachePath)")
            File.manager.moveFile(videoPath, toPath: cachePath)
            File.manager.deleteFile(videoPath)
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
            print("videoPath \(videoPath)")
            print("cachePath \(cachePath)")
            File.manager.deleteFile(videoPath)
            switch exportSession.status {
            case .completed:
                Asyncs.main { completion(.success(cachePath)) }
            default:
                File.manager.deleteFile(cachePath)
                Asyncs.main { completion(.failure(.writerError)) }
            }
        }
    }
}
