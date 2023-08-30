//
//  AnimationStore.swift
//  AnimationPreviewer
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
        /// 无法识别的文件
        case unrecognizedFile
        /// `lottie`没有JSON文件
        case lottieWithoutJsonFile
        /// `lottie`没有图片文件夹
        case lottieWithoutImagesDir
        
        var errorDescription: String? {
            switch self {
            case .unzipFailed:
                return "文件解压失败"
            case .unrecognizedFile:
                return "无法识别的文件"
            case .lottieWithoutJsonFile:
                return "lottie文件错误：没有data.json文件"
            case .lottieWithoutImagesDir:
                return "lottie文件错误：没有images目录"
            }
        }
    }
}

// MARK: - 公开API
extension AnimationStore {
    static private(set) var cache: AnimationStore? = nil
    
    static func setup(completion: @escaping () -> Void) {
        doInMyQueue {
            File.manager.createDirectory(tmpDirPath)
            File.manager.createDirectory(cacheDirPath)
            loadCacheData()
            Asyncs.main { completion() }
        }
    }
    
    static func clearCache() {
        doInMyQueue {
            clearCacheFile()
        }
    }
    
    static func loadData(_ data: Data,
                         success: @escaping (_ store: AnimationStore) -> Void,
                         failure: @escaping (_ error: Swift.Error) -> Void) {
        guard isInMyQueue else {
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
                // 不是，先去看看是不是svga（不是的话其内部会去看看是不是lottie）
                let store = try loadSVGAData(tmpFileURL)
                Asyncs.main { success(store) }
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
                // 不是，去看看是不是svga（不是的话其内部会去看看是不是lottie）
                let store = try loadSVGAData(unzipDirURL)
                Asyncs.main { success(store) }
                return
            }
            
            // 取出文件夹里面的第一个文件
            let fileURLs = try FileManager.default.contentsOfDirectory(at: unzipDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            guard let fileURL = fileURLs.first else {
                throw Self.Error.unrecognizedFile
            }
            
            let store: AnimationStore
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if let isDir = resourceValues.isDirectory, isDir {
                // 还是文件夹，看看是不是lottie（其内部会检查有没有svga文件）
                store = try loadLottieData(fileURL)
            } else {
                // 不是文件夹，看看是不是svga（不是的话其内部会去看看是不是lottie）
                store = try loadSVGAData(fileURL)
            }
            
            Asyncs.main { success(store) }
            
        } catch {
            Asyncs.main { failure(error) }
        }
    }
}

// MARK: - lottie/SVGA数据加载
private extension AnimationStore {
    static func loadSVGAData(_ tmpFileURL: URL) throws -> AnimationStore {
        let tmpData = try Data(contentsOf: tmpFileURL)
        
        var entity: SVGAVideoEntity?
        let lock = DispatchSemaphore(value: 0)
        SVGAParser().parse(with: tmpData, cacheKey: "") {
            entity = $0
            lock.signal()
        } failureBlock: { _ in
            lock.signal()
        }
        lock.wait()
        
        guard let entity else {
            // 不是svga，去看看是不是lottie
            return try loadLottieData(tmpFileURL)
        }
        
        try cacheFile(tmpFileURL, for: .svga)
        
        let store = AnimationStore.svga(entity: entity)
        cache = store
        
        return store
    }
    
    static func loadLottieData(_ tmpFileURL: URL) throws -> AnimationStore {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: tmpFileURL,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: .skipsHiddenFiles)
        // 如果就是lottie文件
        var isLottieDir: (hadJsonFile: Bool, hadImagesDir: Bool) = (false, false)
        for fileURL in fileURLs {
            // 居然有svga文件
            if fileURL.pathExtension == "svga" {
                return try loadSVGAData(fileURL)
            }
            
            if fileURL.lastPathComponent == "data.json" {
                isLottieDir.hadJsonFile = true
            } else if fileURL.lastPathComponent == "images" {
                isLottieDir.hadImagesDir = true
            }
        }
        if isLottieDir.hadJsonFile, isLottieDir.hadImagesDir {
            let jsonPath = tmpFileURL.appendingPathComponent("data.json").path
            guard let animation = LottieAnimation.filepath(jsonPath, animationCache: LRUAnimationCache.sharedCache) else {
                throw Self.Error.lottieWithoutJsonFile
            }
            
            try cacheFile(tmpFileURL, for: .lottie)
            
            let provider = FilepathImageProvider(filepath: cacheFilePath)
            let store = AnimationStore.lottie(animation: animation, provider: provider)
            cache = store
            
            return store
        }
        
        // 或者是套了一层
        for fileURL in fileURLs {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            guard let isDirectory = resourceValues.isDirectory, isDirectory else {
                continue
            }

            let jsonPath = fileURL.appendingPathComponent("data.json").path
            guard File.manager.fileExists(jsonPath) else {
                throw Self.Error.lottieWithoutJsonFile
            }

            let imageDirPath = fileURL.appendingPathComponent("images").path
            guard File.manager.fileExists(imageDirPath) else {
                throw Self.Error.lottieWithoutImagesDir
            }
            
            guard let animation = LottieAnimation.filepath(jsonPath, animationCache: LRUAnimationCache.sharedCache) else {
                throw Self.Error.unzipFailed
            }
            
            try cacheFile(fileURL, for: .lottie)
            
            let provider = FilepathImageProvider(filepath: cacheFilePath)
            let store = AnimationStore.lottie(animation: animation, provider: provider)
            cache = store
            
            return store
        }

        throw Self.Error.unrecognizedFile
    }
}

// MARK: - 缓存管理
private extension AnimationStore {
    static var tmpDirPath: String { File.tmpFilePath("AnimationStore") }
    static var cacheDirPath: String { File.cacheFilePath("AnimationStore") }
    
    static func getTmpFilePath(_ fileName: String) -> String { tmpDirPath + "/" + fileName }
    static func getCacheFilePath(_ fileName: String) -> String { cacheDirPath + "/" + fileName }
    
    @UserDefault(.animationType) static var cacheType: AnimationType.RawValue = 0
    static var cacheFilePath: String { getCacheFilePath("jp_animation") }
    
    static func clearCacheFile() {
        cache = nil
        cacheType = 0
        File.manager.clearDirectory(cacheDirPath)
    }
    
    static func cacheFile(_ fileURL: URL, for type: AnimationType) throws {
        clearCacheFile()
        try FileManager.default.moveItem(at: fileURL, to: URL(fileURLWithPath: cacheFilePath))
        cacheType = type.rawValue
    }
    
    static func loadCacheData() {
        let filePath = cacheFilePath
        guard let cacheType = AnimationType(rawValue: cacheType), File.manager.fileExists(filePath) else {
            clearCacheFile()
            return
        }
        
        switch cacheType {
        case .lottie:
            let jsonPath = "\(filePath)/data.json"
            guard let animation = LottieAnimation.filepath(jsonPath, animationCache: LRUAnimationCache.sharedCache) else {
                clearCacheFile()
                return
            }
            
            // animation 和 provider 是必须的
            let provider = FilepathImageProvider(filepath: filePath)
            cache = .lottie(animation: animation, provider: provider)
            
        case .svga:
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
                clearCacheFile()
                return
            }
            
            var entity: SVGAVideoEntity?
            let lock = DispatchSemaphore(value: 0)
            SVGAParser().parse(with: data, cacheKey: "") {
                entity = $0
                lock.signal()
            } failureBlock: { _ in
                lock.signal()
            }
            lock.wait()
            
            guard let entity else {
                clearCacheFile()
                return
            }
            
            cache = .svga(entity: entity)
        }
    }
}

// MARK: - 队列管理
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
}
