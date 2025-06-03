//
//  VideoMaker+SVGA.swift
//  AnimationPreviewer
//
//  Created by aa on 2024/11/26.
//

import UIKit
import AVFoundation
import SVGAPlayer

extension VideoMaker {
    static func makeVideo(withSVGAEntity entity: SVGAVideoEntity,
                          size: CGSize,
                          progress: Progress?,
                          startMergeAudio: (() -> Void)?,
                          completion: @escaping Completion) {
        if Thread.isMainThread {
            Asyncs.async {
                makeVideo(withSVGAEntity: entity, size: size, progress: progress, startMergeAudio: startMergeAudio, completion: completion)
            }
            return
        }
        
        let videoName = "\(Int(Date().timeIntervalSince1970)).mp4"
        let videoPath = File.tmpFilePath(videoName)
        
        guard let videoWriter = try? AVAssetWriter(url: URL(fileURLWithPath: videoPath), fileType: .mp4) else {
            Asyncs.main { completion(.failure(.writerError)) }
            return
        }
        
        videoWriter.shouldOptimizeForNetworkUse = true
        
        let writerInput = createVideoWriterInput(size)
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
        
        let fps = entity.fps
        let svgaSize = entity.videoSize
        
        var container: UIView!
        var svgaView: SVGAExPlayer!
        DispatchQueue.main.sync {
            container = UIView(frame: CGRect(origin: .zero, size: svgaSize))
            svgaView = SVGAExPlayer()
            svgaView.frame = container.bounds
            svgaView.contentMode = .scaleAspectFit
            container.addSubview(svgaView)
            svgaView.play(with: entity, fromFrame: 0, isAutoPlay: false)
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false // false表示透明，这里需要透明背景
        format.scale = UIScreen.main.scale
        
        let frameCount = Int(entity.frames)
        
        var frameTime = CMTime.zero
        for i in 0 ..< frameCount {
            autoreleasepool {
                let renderer = UIGraphicsImageRenderer(size: svgaSize, format: format)
                let image = renderer.image { ctx in
                    DispatchQueue.main.sync {
                        svgaView.play(fromFrame: i, isAutoPlay: false)
                        if let drawLayer = svgaView.getDrawLayer() {
                            drawLayer.render(in: ctx.cgContext)
                        }
                    }
                }
                
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
                
                progress?(i, frameCount)
            }
        }
        
        writerInput.markAsFinished()
        
        let endTime = CMTime(value: CMTimeValue(entity.frames), timescale: fps)
        videoWriter.endSession(atSourceTime: endTime)
        
        videoWriter.finishWriting {
            switch videoWriter.status {
            case .completed:
                guard entity.isHasAudio else {
                    let cachePath = File.cacheFilePath(videoName)
                    File.manager.deleteFile(cachePath)
                    File.manager.moveFile(videoPath, toPath: cachePath)
                    File.manager.deleteFile(videoPath)
                    Asyncs.main { completion(.success(cachePath)) }
                    return
                }
                
                startMergeAudio?()
                _mergeAudio(withSVGAEntity: entity, videoPath: videoPath) { outputPath in
                    guard let outputPath else {
                        Asyncs.main { completion(.failure(.writerError)) }
                        return
                    }
                    let cachePath = File.cacheFilePath(videoName)
                    File.manager.deleteFile(cachePath)
                    File.manager.moveFile(outputPath, toPath: cachePath)
                    File.manager.deleteFile(outputPath)
                    Asyncs.main { completion(.success(cachePath)) }
                }
                
            default:
                File.manager.deleteFile(videoPath)
                Asyncs.main { completion(.failure(.writerError)) }
            }
        }
        
    }
    
    private static func _mergeAudio(withSVGAEntity entity: SVGAVideoEntity, videoPath: String, completion: @escaping (_ outputPath: String?) -> Void) {
        
        let composition = AVMutableComposition()
        
        // 添加视频轨道
        let videoAsset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            File.manager.deleteFile(videoPath)
            completion(nil)
            return
        }
        
        let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try? videoCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: videoTrack, at: .zero)
        
        // 添加音频轨道
        var audiosData: [String: String] = [:]
        for (name, data) in entity.audiosData {
            let audioPath = File.tmpFilePath(name) + ".mp3"
            try? data.write(to: URL(fileURLWithPath: audioPath))
            audiosData[name] = audioPath
        }
        
        let fps = entity.fps
        for audioInfo in entity.audios {
            guard let audioPath = audiosData[audioInfo.audioKey] else { continue }
            
            let audioAsset = AVURLAsset(url: URL(fileURLWithPath: audioPath))
            guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else { continue }
            
            let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            let start = CMTimeMake(value: Int64(audioInfo.startTime), timescale: fps)
            let duration = CMTimeMake(value: Int64(audioInfo.endFrame - audioInfo.startFrame), timescale: fps)
            let atTime = CMTimeMake(value: Int64(audioInfo.startFrame), timescale: fps)
            try? audioCompositionTrack?.insertTimeRange(CMTimeRange(start: start, duration: duration), of: audioTrack, at: atTime)
        }
        
        // 📢：如果插入多段音频，并且时间重合，需要创建AVMutableAudioMix控制各段音频的混音，
        // 否则只有第一段音频有声音，其他音频声音会被覆盖。
        let audioMix = AVMutableAudioMix()
        // 获取所有音频轨道并设置混音参数
        var inputParametersArray: [AVMutableAudioMixInputParameters] = []
        for audioTrack in composition.tracks(withMediaType: .audio) {
            let inputParameters = AVMutableAudioMixInputParameters(track: audioTrack)
            // 设置音量 - 可根据需要调整不同轨道的音量
            inputParameters.setVolume(1.0, at: .zero)  // 设置音量为1.0（正常音量）
            // 也可以设置特定时间段的音量，例如：
            // inputParameters.setVolume(0.5, at: CMTime(seconds: 2, preferredTimescale: 600)) // 2秒时将音量减半
            inputParametersArray.append(inputParameters)
        }
        // 设置音频混合输入参数
        audioMix.inputParameters = inputParametersArray
        
        // 导出最终视频
        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            audiosData.values.forEach { File.manager.deleteFile($0) }
            File.manager.deleteFile(videoPath)
            completion(nil)
            return
        }
        exporter.shouldOptimizeForNetworkUse = true
        exporter.timeRange = CMTimeRange(start: .zero, duration: videoAsset.duration)
        exporter.audioMix = audioMix
        
        let outputPath = File.tmpFilePath("final_output.mp4")
        File.manager.deleteFile(outputPath)
        
        let outputURL =  URL(fileURLWithPath: outputPath)
        Task {
            if #available(macCatalyst 18, *) {
                try? await exporter.export(to: outputURL, as: .mp4)
            } else {
                exporter.outputURL = outputURL
                exporter.outputFileType = .mp4
                await exporter.export()
            }
            
            audiosData.values.forEach { File.manager.deleteFile($0) }
            File.manager.deleteFile(videoPath)
            
            switch exporter.status {
            case .completed:
                completion(outputPath)
            default:
                File.manager.deleteFile(outputPath)
                completion(nil)
            }
        }
    }
}
