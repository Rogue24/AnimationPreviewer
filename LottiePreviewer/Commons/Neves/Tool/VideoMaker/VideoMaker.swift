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
    
    
    enum MakeError: Error {
        case writerError
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
                AVVideoAverageBitRateKey: bitsPerSecond,
                AVVideoMaxKeyFrameIntervalKey: frameInterval,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ] as [String : Any]
        ]
        return AVAssetWriterInput(mediaType: .video, outputSettings: settings)
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
        
        let bitsPerSecond = 5000 * 1024
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitsPerSecond,
                AVVideoMaxKeyFrameIntervalKey: frameInterval,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ] as [String : Any]
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
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
