//
//  VideoMaker.ImageInfo.swift
//  Neves
//
//  Created by aa on 2021/10/15.
//

import AVFoundation

extension VideoMaker {
    
    struct ImageInfo {
        let image: UIImage
        let duration: TimeInterval
        var pixelBuffer: CVPixelBuffer? = nil
    }
    
    func makeVideo(with infos: [ImageInfo], completion: @escaping (Result<String, MakeError>) -> ()) {
        Asyncs.async {
            var imageInfos = infos
            
            let operationLock = DispatchSemaphore(value: 1)
            let concurrentLock = DispatchSemaphore(value: self.maxConcurrentOperationCount)
            
            DispatchQueue.concurrentPerform(iterations: imageInfos.count) { [weak self] i in
                guard let self = self else { return }
                
                concurrentLock.wait()
                defer { concurrentLock.signal() }
                
                operationLock.wait()
                var imageInfo = imageInfos[i]
                if imageInfo.pixelBuffer == nil, let pixelBuffer = Self.createPixelBufferWithImage(imageInfo.image, size: self.videoSize) {
                    imageInfo.pixelBuffer = pixelBuffer
                    imageInfos[i] = imageInfo
                }
                operationLock.signal()
            }
            
            Self.createVideoWithImageInfos(imageInfos, size: self.videoSize, frameInterval: self.frameInterval, completion: completion)
        }
    }
    
    static func createVideoWithImageInfos(_ imageInfos: [ImageInfo], size: CGSize, frameInterval: Int, completion: @escaping (Result<String, MakeError>) -> ()) {
        
        let videoName = "\(Int(Date().timeIntervalSince1970)).mp4"
        let videoPath = File.tmpFilePath(videoName)
        
        guard let videoWriter = try? AVAssetWriter(url: URL(fileURLWithPath: videoPath), fileType: .mp4) else {
            completion(.failure(.writerError))
            return
        }
        
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
        
//        JPrint("000 ---", videoWriter.status.rawValue, adaptor.assetWriterInput.isReadyForMoreMediaData)
        videoWriter.add(writerInput)
//        JPrint("111 ---", videoWriter.status.rawValue, adaptor.assetWriterInput.isReadyForMoreMediaData);
        
//        JPrint("222 ---", videoWriter.status.rawValue, adaptor.assetWriterInput.isReadyForMoreMediaData);
        guard videoWriter.startWriting() else {
            completion(.failure(.writerError))
            return
        }
//        JPrint("333 ---", videoWriter.status.rawValue, adaptor.assetWriterInput.isReadyForMoreMediaData);
        
//        JPrint("444 ---", videoWriter.status.rawValue, adaptor.assetWriterInput.isReadyForMoreMediaData);
        videoWriter.startSession(atSourceTime: .zero)
//        JPrint("555 ---", videoWriter.status.rawValue, adaptor.assetWriterInput.isReadyForMoreMediaData);
        
        var currentFrame = 0
        let timescale = CMTimeScale(frameInterval)
        
        for imageInfo in imageInfos {
            guard let pixelBuffer = imageInfo.pixelBuffer else {
                completion(.failure(.writerError))
                return
            }
            
            let imageTotalFrame = Int(ceil(imageInfo.duration)) * frameInterval
            
            for _ in 0 ..< imageTotalFrame {
                while true {
                    if adaptor.assetWriterInput.isReadyForMoreMediaData || videoWriter.status != .writing {
//                        JPrint("xxx ---", videoWriter.status.rawValue, adaptor.assetWriterInput.isReadyForMoreMediaData);
                        break
                    }
                }
                
                if videoWriter.status != .writing {
                    completion(.failure(.writerError))
                    return
                }
                
                let currentTime = CMTime(value: CMTimeValue(currentFrame), timescale: timescale)
                adaptor.append(pixelBuffer, withPresentationTime: currentTime)
                currentFrame += 1
            }
        }
        
        writerInput.markAsFinished()
        
        let endTime = CMTime(value: CMTimeValue(currentFrame), timescale: timescale)
        videoWriter.endSession(atSourceTime: endTime)
        
        videoWriter.finishWriting {
            switch videoWriter.status {
            case .completed:
                let cachePath = File.cacheFilePath(videoName)
                File.manager.deleteFile(cachePath)
                File.manager.moveFile(videoPath, toPath: cachePath)
                File.manager.deleteFile(videoPath)
                completion(.success(cachePath))
                
            default:
                completion(.failure(.writerError))
            }
        }
    }
}
