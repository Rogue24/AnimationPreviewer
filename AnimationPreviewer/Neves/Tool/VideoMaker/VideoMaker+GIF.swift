//
//  VideoMaker+GIF.swift
//  AnimationPreviewer
//
//  Created by aa on 2024/11/27.
//

import UIKit
import AVFoundation

extension VideoMaker {
    
    static func makeVideo(withImages images: [UIImage], duration: TimeInterval, size: CGSize, completion: @escaping (Result<String, MakeError>) -> ()) {
        if Thread.isMainThread {
            Asyncs.async {
                makeVideo(withImages: images, duration: duration, size: size, completion: completion)
            }
            return
        }
        
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
        
        let fps: Int32 = Int32(images.count) / Int32(duration)
        
        var frameTime = CMTime.zero
        for image in images {
            autoreleasepool {
                if let pixelBuffer = createPixelBufferWithImage(image, size: size) {
                    while !adaptor.assetWriterInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.01)
                    }

                    if videoWriter.status != .writing {
                        Asyncs.main { completion(.failure(.writerError)) }
                        return
                    }
                    
                    adaptor.append(pixelBuffer, withPresentationTime: frameTime)
                    frameTime = CMTimeAdd(frameTime, CMTimeMake(value: 1, timescale: fps))
                }
            }
        }
        
        writerInput.markAsFinished()
        
        videoWriter.endSession(atSourceTime: frameTime)
        
        videoWriter.finishWriting {
            switch videoWriter.status {
            case .completed:
                let cachePath = File.cacheFilePath(videoName)
                File.manager.deleteFile(cachePath)
                File.manager.moveFile(videoPath, toPath: cachePath)
                Asyncs.main { completion(.success(cachePath)) }
            default:
                Asyncs.main { completion(.failure(.writerError)) }
            }
            File.manager.deleteFile(videoPath)
        }
    }
}

