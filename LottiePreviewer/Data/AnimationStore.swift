//
//  AnimationStore.swift
//  LottiePreviewer
//
//  Created by aa on 2023/8/25.
//

import Foundation
import SSZipArchive

enum AnimationType: Int {
    case lottie = 1
    case svga = 2
}

enum AnimationStore {
    case lottie(animation: LottieAnimation, provider: FilepathImageProvider)
    case svga(entity: SVGAVideoEntity)
    
    var isLottie: Bool {
        switch self {
        case .lottie:
            return true
        case .svga:
            return false
        }
    }
    
    var isSVGA: Bool {
        switch self {
        case .lottie:
            return false
        case .svga:
            return true
        }
    }
    
    enum Error: Swift.Error, LocalizedError {
        /// 文件解压失败
        case unzipFailed
        /// 没有JSON文件
        case withoutJsonFile
        /// 没有图片文件夹
        case withoutImagesDir
        
        var errorDescription: String? {
            switch self {
            case .unzipFailed:
                return "文件解压失败"
            case .withoutJsonFile:
                return "文件错误：没有data.json文件"
            case .withoutImagesDir:
                return "文件错误：没有images目录"
            }
        }
    }
}

extension AnimationStore {
    static private(set) var cache: AnimationStore? = nil
    
    static func setup(completion: @escaping () -> Void) {
        doInMyQueue {
            File.manager.createDirectory(tmpDirPath)
            File.manager.createDirectory(cacheDirPath)
            setupCache()
            Asyncs.main { completion() }
        }
    }
    
    static func clearCache() {
        doInMyQueue {
            asyncTag = nil
            cache = nil
            try? clearCacheFile()
        }
    }
    
    static func loadData(_ data: Data,
                         success: @escaping (_ store: AnimationStore) -> Void,
                         failure: @escaping (_ error: Swift.Error) -> Void) {
        guard !isInMyQueue else {
            myQueue.async { loadData(data, success: success, failure: failure) }
            return
        }
        
        // 先清理Tmp文件夹
        File.manager.clearDirectory(tmpDirPath)
        
        do {
            // 写入Tmp文件夹
            let tmpFilePath = getTmpFilePath("jp123")
            let tmpFileURL = URL(fileURLWithPath: tmpFilePath)
            try data.write(to: tmpFileURL)
            
            // 检查是不是zip
            guard data.jp.isZip else {
                // 不是，先去看看是不是svga
                loadSVGAData(tmpFileURL, success: success, failure: failure)
                return
            }
            
            // 解压
            let unzipDirPath = getTmpFilePath("jp456")
            let unzipDirURL = URL(fileURLWithPath: unzipDirPath)
            SSZipArchive.unzipFile(atPath: tmpFilePath, toDestination: unzipDirPath)
            
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: unzipDirPath, isDirectory: &isDirectory) else {
                throw Self.Error.unzipFailed
            }
            
            // 检查是不是文件夹
            guard isDirectory.boolValue else {
                // 不是，先去看看是不是svga
                loadSVGAData(unzipDirURL, success: success, failure: failure)
                return
            }
            
            // 取出文件夹里面的第一个文件
            let fileURLs = try FileManager.default.contentsOfDirectory(at: unzipDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            guard let fileURL = fileURLs.first else {
                throw Self.Error.unzipFailed
            }
            
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if let isDir = resourceValues.isDirectory, isDir {
                // 还是文件夹，看看是不是lottie
                loadLottieData(fileURL, success: success, failure: failure)
            } else {
                // 不是，看看是不是svga
                loadSVGAData(fileURL, success: success, failure: failure)
            }
            
        } catch {
            Asyncs.main { failure(error) }
        }
    }
}

private extension AnimationStore {
    static var myQueueKey = DispatchSpecificKey<UUID>()
    static let myQueueID = UUID()
    
    static let myQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "com.zhoujianping.animationstore")
        queue.setSpecific(key: myQueueKey, value: myQueueID)
        return queue
    }()
    
    static var isInMyQueue: Bool { DispatchQueue.getSpecific(key: myQueueKey) == myQueueID }
    static func doInMyQueue(_ handler: @escaping () -> Void) {
        if isInMyQueue {
            handler()
        } else {
            myQueue.async { handler() }
        }
    }
    
    static var asyncTag: UUID?
}

private extension AnimationStore {
    static var tmpDirPath: String { File.tmpFilePath("AnimationStore") }
    static var cacheDirPath: String { File.cacheFilePath("AnimationStore") }
    
    static func getTmpFilePath(_ fileName: String) -> String { tmpDirPath + "/" + fileName }
    static func getCacheFilePath(_ fileName: String) -> String { cacheDirPath + "/" + fileName }
    
    @UserDefault("AnimationStore") static var cacheType: AnimationType.RawValue?
    static var cacheFilePath: String { getCacheFilePath("jp_animation") }
    
    static func setupCache() {
        asyncTag = nil
        cache = nil
        
        let filePath = cacheFilePath
        guard let cacheType = AnimationType(rawValue: cacheType ?? 0), File.manager.fileExists(filePath) else {
            return
        }
        
        switch cacheType {
        case .lottie:
            guard let animation = LottieAnimation.filepath("\(filePath)/data.json", animationCache: LRUAnimationCache.sharedCache) else { return }
            // animation 和 provider 是必须的
            let provider = FilepathImageProvider(filepath: filePath)
            cache = .lottie(animation: animation, provider: provider)
            
        case .svga:
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { return }
            
            let newTag = UUID()
            asyncTag = newTag
            
            var entity: SVGAVideoEntity?
            let lock = DispatchSemaphore(value: 0)
            SVGAParser().parse(with: data, cacheKey: "") {
                entity = $0
                lock.signal()
            } failureBlock: { _ in
                lock.signal()
            }
            lock.wait()
            
            if asyncTag == newTag {
                asyncTag = nil
                
                if let entity {
                    cache = .svga(entity: entity)
                }
            }
        }
    }
}

private extension AnimationStore {
    static func clearCacheFile() throws {
        cacheType = nil
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: cacheDirPath)
            for oldFileName in contents {
                let oldFilePath = (cacheDirPath as NSString).appendingPathComponent(oldFileName)
                try FileManager.default.removeItem(atPath: oldFilePath)
            }
        } catch {
            throw error
        }
    }
    
    static func cacheFile(_ fileURL: URL) throws {
        do {
            try clearCacheFile()
            try FileManager.default.moveItem(at: fileURL, to: URL(fileURLWithPath: cacheFilePath))
        } catch {
            throw error
        }
    }
}

private extension AnimationStore {
    static func loadSVGAData(_ tmpFileURL: URL,
                             success: @escaping (_ store: AnimationStore) -> Void,
                             failure: @escaping (_ error: Swift.Error) -> Void) {
        let tmpData: Data
        do {
            tmpData = try Data(contentsOf: tmpFileURL)
        } catch {
            Asyncs.main { failure(error) }
            return
        }
        
        let newTag = UUID()
        asyncTag = newTag
        
        let parser = SVGAParser()
        parser.parse(with: tmpData, cacheKey: "") { entity in
            doInMyQueue {
                guard asyncTag == newTag else { return }
                asyncTag = nil
                do {
                    try cacheFile(tmpFileURL)
                    cacheType = AnimationType.svga.rawValue
                    
                    let store = AnimationStore.svga(entity: entity)
                    cache = store
                    
                    Asyncs.main { success(store) }
                } catch {
                    Asyncs.main { failure(error) }
                }
            }
        } failureBlock: { _ in
            doInMyQueue {
                guard asyncTag == newTag else { return }
                asyncTag = nil
                // 不是svga，看看是不是lottie
                loadLottieData(tmpFileURL, success: success, failure: failure)
            }
        }
    }
    
    static func loadLottieData(_ tmpFileURL: URL,
                               success: @escaping (_ store: AnimationStore) -> Void,
                               failure: @escaping (_ error: Swift.Error) -> Void) {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: tmpFileURL,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: .skipsHiddenFiles)

            // 如果就是lottie文件
            var isLottieDir: (hadJsonFile: Bool, hadImagesDir: Bool) = (false, false)
            for fileURL in fileURLs {
                if fileURL.lastPathComponent == "data.json" {
                    isLottieDir.hadJsonFile = true
                } else if fileURL.lastPathComponent == "images" {
                    isLottieDir.hadImagesDir = true
                }
            }
            if isLottieDir.hadJsonFile, isLottieDir.hadImagesDir {
                let jsonPath = tmpFileURL.appendingPathComponent("data.json").path
                guard let animation = LottieAnimation.filepath(jsonPath, animationCache: LRUAnimationCache.sharedCache) else {
                    throw Self.Error.unzipFailed
                }
                
                try cacheFile(tmpFileURL)
                cacheType = AnimationType.lottie.rawValue
                
                let provider = FilepathImageProvider(filepath: cacheFilePath)
                let store = AnimationStore.lottie(animation: animation, provider: provider)
                cache = store
                
                Asyncs.main { success(store) }
                return
            }
            
            // 或者是套了一层
            for fileURL in fileURLs {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                guard let isDirectory = resourceValues.isDirectory, isDirectory else {
                    continue
                }

                let jsonPath = fileURL.appendingPathComponent("data.json").path
                guard File.manager.fileExists(jsonPath) else {
                    throw Self.Error.withoutJsonFile
                }

                let imageDirPath = fileURL.appendingPathComponent("images").path
                guard File.manager.fileExists(imageDirPath) else {
                    throw Self.Error.withoutImagesDir
                }
                
                guard let animation = LottieAnimation.filepath(jsonPath, animationCache: LRUAnimationCache.sharedCache) else {
                    throw Self.Error.unzipFailed
                }
                
                try cacheFile(fileURL)
                cacheType = AnimationType.lottie.rawValue
                
                let provider = FilepathImageProvider(filepath: cacheFilePath)
                let store = AnimationStore.lottie(animation: animation, provider: provider)
                cache = store
                
                Asyncs.main { success(store) }
                return
            }

            throw Self.Error.unzipFailed
            
        } catch {
            Asyncs.main { failure(error) }
        }
    }
}

