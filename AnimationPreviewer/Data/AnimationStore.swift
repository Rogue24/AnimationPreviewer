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
    case gif = 3
}

enum AnimationStore {
    case lottie(animation: LottieAnimation, provider: FilepathImageProvider)
    case svga(entity: SVGAVideoEntity)
    case gif(images: [UIImage], duration: TimeInterval)
    
    var isLottie: Bool {
        switch self {
        case .lottie:
            return true
        default:
            return false
        }
    }
    
    var isSVGA: Bool {
        switch self {
        case .svga:
            return true
        default:
            return false
        }
    }
    
    var isGIF: Bool {
        switch self {
        case .gif:
            return true
        default:
            return false
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
        /// `GIF`解码失败
        case decodeGIFFailed
        
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
            case .decodeGIFFailed:
                return "GIF解码失败"
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
                // 不是，去看看是不是svga
                // 内部会先看看是不是lottie_json，再看看是不是gif，接着解析svga，如果连svga都不是就去看看是不是lottie_dir
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
                // 还是文件夹，看看是不是lottie（其内部会检查有没有svga/gif文件）
                store = try loadLottieData(fileURL)
            } else {
                // 不是文件夹，看看是不是svga
                // 内部会先看看是不是lottie_json，再看看是不是gif，接着解析svga，如果连svga都不是就去看看是不是lottie_dir
                store = try loadSVGAData(fileURL)
            }
            
            Asyncs.main { success(store) }
            
        } catch {
            Asyncs.main { failure(error) }
        }
    }
}

// MARK: - lottie/SVGA/GIF数据加载
private extension AnimationStore {
    static func loadGIFData(_ tmpFileURL: URL) throws -> AnimationStore {
        let tmpData = try Data(contentsOf: tmpFileURL)
        
        guard tmpData.jp.isGIF else {
            return try loadSVGAData(tmpFileURL)
        }
        
        guard let gif = decodeGIF(tmpData) else {
            throw Self.Error.decodeGIFFailed
        }
        
        try cacheFile(tmpFileURL, for: .gif)
        
        let store = AnimationStore.gif(images: gif.0, duration: gif.1)
        cache = store
        
        return store
    }
    
    static func loadSVGAData(_ tmpFileURL: URL) throws -> AnimationStore {
        let tmpData = try Data(contentsOf: tmpFileURL)
        
        if tmpData.jp.isJSON {
            return try loadLottieData(tmpFileURL, isDir: false)
        }
        
        if tmpData.jp.isGIF {
            return try loadGIFData(tmpFileURL)
        }
        
        guard let entity = parseSVGA(tmpData) else {
            // 不是svga，去看看是不是lottie
            return try loadLottieData(tmpFileURL)
        }
        
        try cacheFile(tmpFileURL, for: .svga)
        
        let store = AnimationStore.svga(entity: entity)
        cache = store
        
        return store
    }
    
    static func loadLottieData(_ tmpFileURL: URL, isDir: Bool = true) throws -> AnimationStore {
        // 非文件夹就是lottie_json（纯矢量动画）
        if !isDir {
            let tmpData = try Data(contentsOf: tmpFileURL)
            let animation = try LottieAnimation.from(data: tmpData)
            
            try cacheFile(tmpFileURL, for: .lottie)
            
            let provider = FilepathImageProvider(filepath: cacheFilePath)
            let store = AnimationStore.lottie(animation: animation, provider: provider)
            cache = store
            
            return store
        }
        
        let fileURLs = try FileManager.default.contentsOfDirectory(at: tmpFileURL,
                                                                   includingPropertiesForKeys: nil,
                                                                   options: .skipsHiddenFiles)
        // 如果就是lottie文件
        var isLottieDir: (hadJsonFile: Bool, hadImagesDir: Bool) = (false, false)
        for fileURL in fileURLs {
            // 居然有gif文件
            if fileURL.pathExtension.lowercased() == "gif" {
                return try loadGIFData(fileURL)
            }
            
            // 居然有svga文件
            if fileURL.pathExtension.lowercased() == "svga" {
                return try loadSVGAData(fileURL)
            }
            
            if fileURL.lastPathComponent.lowercased() == "data.json" {
                isLottieDir.hadJsonFile = true
            } else if fileURL.lastPathComponent.lowercased() == "images" {
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
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) else {
                clearCacheFile()
                return
            }
            
            // 文件夹是lottie_dir（自带图片的动画），非文件夹则是lottie_json（纯矢量动画）
            let jsonPath = isDirectory.boolValue ? "\(filePath)/data.json" : filePath
            guard let animation = LottieAnimation.filepath(jsonPath, animationCache: LRUAnimationCache.sharedCache) else {
                clearCacheFile()
                return
            }
            
            // animation 和 provider 是必须的
            let provider = FilepathImageProvider(filepath: filePath)
            cache = .lottie(animation: animation, provider: provider)
            
        case .svga:
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let entity = parseSVGA(data)
            else {
                clearCacheFile()
                return
            }
            cache = .svga(entity: entity)
            
        case .gif:
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let gif = decodeGIF(data)
            else {
                clearCacheFile()
                return
            }
            cache = .gif(images: gif.0, duration: gif.1)
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

// MARK: - SVGA相关
private extension AnimationStore {
    static func parseSVGA(_ data: Data) -> SVGAVideoEntity? {
        var entity: SVGAVideoEntity?
        let lock = DispatchSemaphore(value: 0)
        SVGAParser().parse(with: data, cacheKey: "") {
            entity = $0
            lock.signal()
        } failureBlock: { _ in
            lock.signal()
        }
        lock.wait()
        return entity
    }
}

// MARK: - GIF相关
private extension AnimationStore {
    static func decodeGIF(_ data: Data) -> ([UIImage], TimeInterval)? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        var images: [UIImage] = []
        var duration: TimeInterval = 0
        
        let count = CGImageSourceGetCount(imageSource)
        for i in 0 ..< count {
            guard let cgImg = CGImageSourceCreateImageAtIndex(imageSource, i, nil) else { continue }
            
            let img = UIImage(cgImage: cgImg)
            images.append(img)
            
            // CFDictionary的使用：https://www.jianshu.com/p/766acdbbe271
            guard let proertyDic = CGImageSourceCopyPropertiesAtIndex(imageSource, i, nil),
                  let gifDicValue = CFDictionaryGetValue(proertyDic, Unmanaged.passRetained(kCGImagePropertyGIFDictionary).autorelease().toOpaque()) else {
                duration += 0.1
                continue
            }
            
            let gifDic = Unmanaged<CFDictionary>.fromOpaque(gifDicValue).takeUnretainedValue()
            
            guard let delayValue = CFDictionaryGetValue(gifDic, Unmanaged.passRetained(kCGImagePropertyGIFUnclampedDelayTime).autorelease().toOpaque()) else {
                duration += 0.1
                continue
            }
            
            var delay = Unmanaged<NSNumber>.fromOpaque(delayValue).takeUnretainedValue().doubleValue
            if delay <= Double.ulpOfOne, let delayValue2 = CFDictionaryGetValue(gifDic, Unmanaged.passRetained(kCGImagePropertyGIFDelayTime).autorelease().toOpaque()) {
                delay = Unmanaged<NSNumber>.fromOpaque(delayValue2).takeUnretainedValue().doubleValue
            }
            
            duration += (delay < 0.02 ? 0.1 : delay)
        }
        
        return (images, duration)
    }
}
