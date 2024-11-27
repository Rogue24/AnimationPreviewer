//
//  VideoMaker.swift
//  Neves
//
//  Created by aa on 2021/9/27.
//

import UIKit
import AVFoundation

let ColorSpace = CGColorSpaceCreateDeviceRGB()

class VideoMaker {
    
    typealias LayerProvider = (_ currentFrame: Int, _ currentTime: TimeInterval, _ size: CGSize) -> [CALayer?]
    typealias ImageProvider = (_ currentFrame: Int, _ currentTime: TimeInterval, _ size: CGSize) -> [UIImage?]
    typealias Progress = (_ currentFrame: Int, _ totalFrame: Int) -> ()
    typealias Completion = (Result<String, MakeError>) -> ()
    
    
    enum MakeError: Swift.Error, LocalizedError {
        case writerError
        
        var errorDescription: String? {
            switch self {
            case .writerError:
                return "写入发生错误"
            }
        }
    }
    
    var videoSize: CGSize = [700, 700 / (16.0 / 9.0)]
    var frameInterval = 15
    
    var pixelBufferMap: [Int: CVPixelBuffer] = [:]
    
    let maxConcurrentOperationCount: Int = 10
}

extension VideoMaker {
    static func createVideoWriterInput(frameInterval: Int, size: CGSize) -> AVAssetWriterInput {
        let bitsPerSecond = 5000 * 1024
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitsPerSecond, // 平均比特率
                AVVideoMaxKeyFrameIntervalKey: frameInterval, // 最大关键帧间隔
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ] as [String : Any]
        ]
        /// `AVVideoMaxKeyFrameIntervalKey`的作用：
        /// 该参数定义了两帧关键帧之间的最大帧数，即 关键帧间隔（GOP: Group of Pictures）。其值越大：
        /// 1. 视频压缩率更高：
        ///   - 关键帧的数据量较大，间隔越长，视频的压缩效率越高，生成的文件体积越小。
        /// 2. 视频质量可能下降：
        ///   - 非关键帧依赖前面的关键帧，间隔过大会导致解码过程中的误差积累，影响视频质量。
        /// 3. 解码性能可能降低：
        ///   - 解码时若需要查找很久之前的关键帧，性能会有所降低，尤其是在视频快进、回退时。
        ///
        /// 常见取值
        /// 1：每帧都是关键帧（无预测帧），质量最高，但文件体积非常大。
        /// 10~30：通常适用于实时视频通话或低延迟场景，提供较好的平衡。
        /// 60 或更大：用于非实时视频，例如电影或录播，最大化压缩率。
        return AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    }
    
    static func createVideoWriterInput(_ size: CGSize) -> AVAssetWriterInput {
        return createVideoWriterInput(frameInterval: 15, size: size)
    }
    
    static func createSourcePixelBufferAttributes() -> [String: Any]? {
        var keyCallBacks = kCFTypeDictionaryKeyCallBacks
        var valCallBacks = kCFTypeDictionaryValueCallBacks
        guard let empty = CFDictionaryCreate(kCFAllocatorDefault, nil, nil, 0, &keyCallBacks, &valCallBacks) else {
            return nil
        }
        return [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: empty
        ] as [String: Any]
    }
    
    static func createPixelBufferWithImage(_ image: UIImage, pixelBufferPool: CVPixelBufferPool? = nil, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        return createPixelBufferWithImage(cgImage, pixelBufferPool: pixelBufferPool, size: size)
    }
    
    static func createPixelBufferWithImage(_ cgImage: CGImage, pixelBufferPool: CVPixelBufferPool? = nil, size: CGSize) -> CVPixelBuffer? {
        
        var pixelBuffer: CVPixelBuffer? = nil
        // 创建 pixel buffer
        let status: CVReturn
        if let pixelBufferPool = pixelBufferPool {
//            status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(
//                            kCFAllocatorDefault,
//                            pixelBufferPool,
//                            options as CFDictionary,
//                            &pixelBuffer
//                        )
            status = CVPixelBufferPoolCreatePixelBuffer(
                            kCFAllocatorDefault,
                            pixelBufferPool,
                            &pixelBuffer
                        )
        } else {
//            var keyCallBacks = kCFTypeDictionaryKeyCallBacks
//            var valCallBacks = kCFTypeDictionaryValueCallBacks
//            guard let empty = CFDictionaryCreate(kCFAllocatorDefault, nil, nil, 0, &keyCallBacks, &valCallBacks) else {
//                return nil
//            }
            let attributes: [CFString: Any] = [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
//                kCVPixelBufferIOSurfacePropertiesKey: empty,
            ]
            
            status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(size.width),
                                         Int(size.height),
                                         kCVPixelFormatType_32BGRA,
                                         attributes as CFDictionary,
                                         &pixelBuffer)
        }
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        // 锁定 pixel buffer 的基地址
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        // 获取 pixel buffer 的基地址
        guard let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            // 解锁 pixel buffer
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        var bitmapRawValue = CGBitmapInfo.byteOrder32Little.rawValue
        let alphaInfo = cgImage.alphaInfo
        if alphaInfo == .premultipliedLast ||
            alphaInfo == .premultipliedFirst ||
            alphaInfo == .last ||
            alphaInfo == .first {
            bitmapRawValue |= CGImageAlphaInfo.premultipliedFirst.rawValue
        } else {
            bitmapRawValue |= CGImageAlphaInfo.noneSkipFirst.rawValue
        }
        
        // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
        guard let context = CGContext(data: pixelData,
                                      width: Int(size.width),
                                      height: Int(size.height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: ColorSpace,
                                      bitmapInfo: bitmapRawValue) else {
            // 解锁 pixel buffer
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        context.clear(CGRect(origin: .zero, size: size))
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        let rect: CGRect
        if (width > height) {
            let h = size.width * (height / width)
            rect = [0, HalfDiffValue(size.height, h), size.width, h]
        } else {
            let w = size.height * (width / height)
            rect = [HalfDiffValue(size.width, w), 0, w, size.height]
        }
        
        context.draw(cgImage, in: rect)
        
        // 解锁 pixel buffer
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
}

extension VideoMaker {
    static func getWriterInput() {
        
    }
}

extension VideoMaker {
    static func createVideo(framerate: Int,
                            frameInterval: Int,
                            duration: TimeInterval,
                            size: CGSize,
                            imageProvider: @escaping (Int, TimeInterval) -> UIImage?,
                            completion: @escaping (Result<String, MakeError>) -> ()) {
        
        let videoName = "\(Int(Date().timeIntervalSince1970)).mp4"
        let videoPath = File.tmpFilePath(videoName)
        
        guard let videoWriter = try? AVAssetWriter(url: URL(fileURLWithPath: videoPath), fileType: .mp4) else {
            completion(.failure(.writerError))
            return
        }
        videoWriter.shouldOptimizeForNetworkUse = false
        
        let writerInput = createVideoWriterInput(frameInterval: frameInterval, size: size)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
        
        guard videoWriter.canAdd(writerInput) else {
            completion(.failure(.writerError))
            return
        }
        videoWriter.add(writerInput)
        
        guard videoWriter.startWriting() else {
            completion(.failure(.writerError))
            return
        }
        videoWriter.startSession(atSourceTime: .zero)
        
        let timescale = CMTimeScale(framerate)
        
        let totalFrame = framerate * Int(duration)
        
        let frameCount = frameInterval * Int(duration)
        
        var lastFrame: Int = 0
        var lastPixelBuffer: CVPixelBuffer? = nil
        
        for i in 0 ... frameCount {
            
            let progress = CGFloat(i) / CGFloat(frameCount)
            let currentFrame = Int(CGFloat(totalFrame) * progress)
            
            // 这里会有一定概率出现错误：Code=-11800 "The operation could not be completed"
            // 这是因为写入了相同的currentFrame造成的，所以要这里做判断，相同就跳过
            if lastFrame == currentFrame { continue }
            lastFrame = currentFrame
//            JPrint("progress", progress, ", currentFrame", currentFrame)
            
            let pixelBuffer: CVPixelBuffer
            if let image = imageProvider(currentFrame, duration * progress),
               let pb = createPixelBufferWithImage(image, size: size) {
                lastPixelBuffer = pb
                pixelBuffer = pb
            } else {
                pixelBuffer = lastPixelBuffer ?? {
                    let pb = createPixelBufferWithImage(UIColor.black.toImage(), size: size)!
                    lastPixelBuffer = pb
                    return pb
                }()
            }
            
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
                
                completion(.failure(.writerError))
                File.manager.deleteFile(videoPath)
                return
            }
            
            let currentTime = CMTime(value: CMTimeValue(currentFrame), timescale: timescale)
            adaptor.append(pixelBuffer, withPresentationTime: currentTime)
        }
        
        writerInput.markAsFinished()
        
        let endTime = CMTime(value: CMTimeValue(totalFrame), timescale: timescale)
        videoWriter.endSession(atSourceTime: endTime)
        
        videoWriter.finishWriting {
            switch videoWriter.status {
            case .completed:
                let cachePath = File.cacheFilePath(videoName)
                File.manager.deleteFile(cachePath)
                File.manager.moveFile(videoPath, toPath: cachePath)
                completion(.success(cachePath))
            default:
                completion(.failure(.writerError))
            }
            File.manager.deleteFile(videoPath)
        }
    }
}
