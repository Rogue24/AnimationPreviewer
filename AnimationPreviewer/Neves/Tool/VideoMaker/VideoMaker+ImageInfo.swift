//
//  VideoMaker+ImageInfo.swift
//  Neves
//
//  Created by aa on 2021/10/15.
//

import UIKit
import AVFoundation

extension VideoMaker {
    
    struct ImageInfo {
        let image: UIImage
        let duration: TimeInterval
        var pixelBuffer: CVPixelBuffer? = nil
    }
    
    static func makeVideo(withImageInfos infos: [ImageInfo], size: CGSize, completion: @escaping (Result<String, MakeError>) -> ()) {
        if Thread.isMainThread {
            Asyncs.async {
                makeVideo(withImageInfos: infos, size: size, completion: completion)
            }
            return
        }
        
        var imageInfos = infos
        
        let maxConcurrentOperationCount = 10
        
        let operationLock = DispatchSemaphore(value: 1)
        let concurrentLock = DispatchSemaphore(value: maxConcurrentOperationCount)
        
        DispatchQueue.concurrentPerform(iterations: imageInfos.count) { i in
            concurrentLock.wait()
            defer { concurrentLock.signal() }
            
            operationLock.wait()
            var imageInfo = imageInfos[i]
            if imageInfo.pixelBuffer == nil, let pixelBuffer = createPixelBufferWithImage(imageInfo.image, size: size) {
                imageInfo.pixelBuffer = pixelBuffer
                imageInfos[i] = imageInfo
            }
            operationLock.signal()
        }
        
        _createVideo(withImageInfos: imageInfos, size: size, completion: completion)
    }
    
    private static func _createVideo(withImageInfos imageInfos: [ImageInfo], size: CGSize, completion: @escaping (Result<String, MakeError>) -> ()) {
        
        let videoName = "\(Int(Date().timeIntervalSince1970)).mp4"
        let videoPath = File.tmpFilePath(videoName)
        
        guard let videoWriter = try? AVAssetWriter(url: URL(fileURLWithPath: videoPath), fileType: .mp4) else {
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        let writerInput = createVideoWriterInput(size)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: nil)
        
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
        
        var duration: TimeInterval = 0
        
        // test：放一张纯色图，占3秒
//        let renderer = UIGraphicsImageRenderer(size: size)
//        let transparentImage = renderer.image { context in
//            // 默认情况下，图形上下文的背景是透明的
//            UIColor.systemBlue.setFill()
//            context.fill(CGRect(origin: .zero, size: size))
//        }
//        if let pixelBuffer = Self.createPixelBufferWithImage(transparentImage, size: size) {
//            while true {
//                if adaptor.assetWriterInput.isReadyForMoreMediaData || videoWriter.status != .writing {
//                    break
//                }
//                Thread.sleep(forTimeInterval: 0.01)
//            }
//            if videoWriter.status != .writing {
//                Asyncs.main { completion(.failure(.writerError)) }
//                return
//            }
//            let presentationTime = CMTimeMake(value: Int64(duration * 1000), timescale: 1000)
//            // 从`presentationTime`这一刻插入图片帧，直至下一张图片覆盖现在的图片帧，没有则直至最后一帧都是这张图片
//            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
//            duration += 3
//        }
        
        for imageInfo in imageInfos {
            guard let pixelBuffer = imageInfo.pixelBuffer else {
                Asyncs.main { completion(.failure(.writerError)) }
                return
            }
            
//            while true {
//                if adaptor.assetWriterInput.isReadyForMoreMediaData || videoWriter.status != .writing {
//                    break
//                }
//                Thread.sleep(forTimeInterval: 0.01)
//            }
            while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }

            if videoWriter.status != .writing {
                Asyncs.main { completion(.failure(.writerError)) }
                return
            }
            
            let presentationTime = CMTimeMake(value: Int64(duration * 1000), timescale: 1000)
            // 从`presentationTime`这一刻插入图片帧，直至下一张图片覆盖现在的图片帧，没有则直至最后一帧都是这张图片
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            
            duration += imageInfo.duration
        }
        
        // test：放一张纯色图，占3秒
//        let renderer2 = UIGraphicsImageRenderer(size: size)
//        let transparentImage2 = renderer2.image { context in
//            // 默认情况下，图形上下文的背景是透明的
//            UIColor.systemYellow.setFill()
//            context.fill(CGRect(origin: .zero, size: size))
//        }
//        if let pixelBuffer = Self.createPixelBufferWithImage(transparentImage2, size: size) {
//            while true {
//                if adaptor.assetWriterInput.isReadyForMoreMediaData || videoWriter.status != .writing {
//                    break
//                }
//                Thread.sleep(forTimeInterval: 0.01)
//            }
//            if videoWriter.status != .writing {
//                Asyncs.main { completion(.failure(.writerError)) }
//                return
//            }
//            let presentationTime = CMTimeMake(value: Int64(duration * 1000), timescale: 1000)
//            // 从`presentationTime`这一刻插入图片帧，直至下一张图片覆盖现在的图片帧，没有则直至最后一帧都是这张图片
//            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
//            duration += 3
//        }
        
        writerInput.markAsFinished()
        
        let endTime = CMTimeMake(value: Int64(duration * 1000), timescale: 1000)
        videoWriter.endSession(atSourceTime: endTime)
        
        videoWriter.finishWriting {
            switch videoWriter.status {
            case .completed:
                let cachePath = File.cacheFilePath(videoName)
                File.manager.deleteFile(cachePath)
                File.manager.moveFile(videoPath, toPath: cachePath)
                File.manager.deleteFile(videoPath)
                Asyncs.main { completion(.success(cachePath)) }
            default:
                Asyncs.main { completion(.failure(.writerError)) }
            }
        }
    }
}
