//
//  AnimationStore.swift
//  AnimationPreviewer
//
//  Created by aa on 2023/8/25.
//

import Foundation
import SVGAPlayer_Optimized
import ZipArchive
import Lottie

enum AnimationType: Int {
    case dotLottie = 1
    case lottie = 2
    case svga = 3
    case gif = 4
}

enum AnimationStore {
    case dotLottie(file: DotLottieFile)
    case lottie(animation: LottieAnimation, provider: FilepathImageProvider)
    case svga(entity: SVGAVideoEntity)
    case gif(images: [UIImage], duration: TimeInterval)
    
    var isLottie: Bool {
        switch self {
        case .dotLottie, .lottie:
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
        /// `lottie`文件解码失败
        case decodeLottieFailed
        /// `lottie`没有JSON文件
        case lottieWithoutJsonFile
        /// `lottie`没有图片文件夹
        case lottieWithoutImagesDir
        /// `GIF`解码失败
        case decodeGIFFailed
        /// 缓存目录创建失败
        case cacheDirCreateFailed
        
        var errorDescription: String? {
            switch self {
            case .unzipFailed:
                return "文件解压失败"
            case .unrecognizedFile:
                return "无法识别的文件"
            case .decodeLottieFailed:
                return "lottie文件解码失败"
            case .lottieWithoutJsonFile:
                return "lottie文件错误：没有动画json文件"
            case .lottieWithoutImagesDir:
                return "lottie文件错误：没有images目录"
            case .decodeGIFFailed:
                return "GIF解码失败"
            case .cacheDirCreateFailed:
                return "缓存目录创建失败"
            }
        }
    }
}

// MARK: - 公开API
extension AnimationStore {
    /// 加载结果：动画 + 它独占的缓存目录名
    typealias LoadResult = (store: AnimationStore, cacheDirName: String)
    
    /// 只准备目录，很快。`loadData`之前必须先调用
    static func prepare(completion: @escaping () -> Void) {
        doInMyQueue {
            File.manager.createDirectory(tmpDirPath)
            File.manager.createDirectory(cacheDirPath)
            Asyncs.main { completion() }
        }
    }
    
    /// 解析上次留下的动画
    ///
    /// 从`prepare`里拆出来单独调用：解析可能很慢，而它和`loadData`共用同一条串行队列。
    /// 双击文件启动时要是先解析缓存，双击的文件就被堵在后面，
    /// 窗口会先显示上次的动画、隔一会儿才换成双击的那个 —— 所以这种情况直接别调用它。
    static func loadCache(completion: @escaping (_ result: LoadResult?) -> Void) {
        doInMyQueue {
            let result = loadCacheData()
            Asyncs.main { completion(result) }
        }
    }
    
    /// 清掉「下次启动恢复」的记录（主线程调用）
    ///
    /// 只清记录，不直接删目录：别的窗口可能还在用自己的那份，不能一把清空整个缓存目录，
    /// 无人引用的目录由`collectGarbage`回收。
    static func clearCache() {
        resetCacheRecord()
        collectGarbage()
    }
    
    static func loadData(
        _ data: Data,
        fileExtension ext: String?,
        success: @escaping (_ result: LoadResult) -> Void,
        failure: @escaping (_ error: Swift.Error) -> Void
    ) {
        guard isInMyQueue else {
            myQueue.async { loadData(data, fileExtension: ext, success: success, failure: failure) }
            return
        }
        
        // 先清理Tmp文件夹
        File.manager.clearDirectory(tmpDirPath)
        
        do {
            // 写入Tmp文件夹
            let tmpFilePath = getTmpFilePath("jp123")
            let tmpFileURL = URL(fileURLWithPath: tmpFilePath)
            try data.write(to: tmpFileURL)
            
            if let ext, ext.count > 0 {
                switch ext {
                case "gif":
                    let result = try loadGIFData(tmpFileURL)
                    Asyncs.main { success(result) }
                    return
                case "svga":
                    let result = try loadSVGAData(tmpFileURL)
                    Asyncs.main { success(result) }
                    return
                case "lottie":
                    let result = try loadDotLottieData(tmpFileURL)
                    Asyncs.main { success(result) }
                    return
                default:
                    break
                }
            }
            
            // 检查是不是zip
            guard data.jp.isZip else {
                // 不是，先去看看是不是svga（不是的话其内部会去看看是不是lottie）
                let result = try loadSVGAData(tmpFileURL)
                Asyncs.main { success(result) }
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
                let result = try loadSVGAData(unzipDirURL)
                Asyncs.main { success(result) }
                return
            }
            
            // 是文件夹
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: unzipDirURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            
            // 取出文件夹里面的第一个文件
            guard let fileURL = fileURLs.first(where: {
                // 没有后缀，有可能是文件夹
                if $0.pathExtension.isEmpty {
                    return true
                }
                // 有后缀，只取规定格式的文件
                let pathExtension = $0.pathExtension.lowercased()
                return pathExtension == "json" || pathExtension == "svga" || pathExtension == "gif"
            }) else {
                throw Self.Error.unrecognizedFile
            }
            
            let result: LoadResult
            if fileURL.jp.isDirectory {
                // 还是文件夹，看看是不是lottie（其内部会检查有没有svga/gif文件）
                result = try loadLottieData(fileURL, isDir: true)
            } else {
                // 不是文件夹，看看是不是svga
                // 内部会先看看是不是lottie_json，再看看是不是gif，接着解析svga，如果连svga都不是就去看看是不是lottie_dir
                result = try loadSVGAData(fileURL)
            }
            
            Asyncs.main { success(result) }
            
        } catch {
            Asyncs.main { failure(error) }
        }
    }
}

// MARK: - lottie/SVGA/GIF数据加载
private extension AnimationStore {
    static func loadDotLottieData(_ tmpFileURL: URL) throws -> LoadResult {
        let result = DotLottieFile.SynchronouslyBlockingCurrentThread.loadedFrom(filepath: tmpFileURL.path, dotLottieCache: nil)
        switch result {
        case let .success(file):
            guard file.animations.first != nil else {
                print("DotLottie file.animations 为空！")
                throw Self.Error.decodeLottieFailed
            }
            
            let cached = try cacheFile(tmpFileURL, for: .dotLottie)
            
            let store = AnimationStore.dotLottie(file: file)
            cache = store
            cacheDirName = cached.dirName
            
            return (store, cached.dirName)
            
        case let .failure(error):
            print("DotLottie 解析错误：\(error.localizedDescription)")
            throw Self.Error.decodeLottieFailed
        }
    }
    
    static func loadLottieData(_ tmpFileURL: URL, isDir: Bool? = nil) throws -> LoadResult {
        let kIsDir: Bool
        if let isDir {
            kIsDir = isDir
        } else {
            kIsDir = tmpFileURL.jp.isDirectory
        }
        guard let result = try _loadLottieData(tmpFileURL, isDir: kIsDir, isNested: false) else {
            throw Self.Error.unrecognizedFile
        }
        return result
    }
    
    static func _loadLottieData(_ tmpFileURL: URL, isDir: Bool, isNested: Bool) throws -> LoadResult? {
        guard isDir else {
            // 非文件夹就是lottie_json（纯矢量动画）
            let tmpData = try Data(contentsOf: tmpFileURL)
            let animation = try LottieAnimation.from(data: tmpData)
            
            let cached = try cacheFile(tmpFileURL, for: .lottie)
            
            let provider = FilepathImageProvider(filepath: cached.filePath)
            let store = AnimationStore.lottie(animation: animation, provider: provider)
            cache = store
            cacheDirName = cached.dirName
            
            return (store, cached.dirName)
        }
        
        // 是文件夹，遍历找出lottie文件
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: tmpFileURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        var isLottieDir: (jsonFileName: String?, hadImagesDir: Bool) = (nil, false)
        for fileURL in fileURLs {
            let pathExtension = fileURL.pathExtension.lowercased()
            
            if !isNested {
                // 居然有gif文件
                if pathExtension == "gif" {
                    return try loadGIFData(fileURL)
                }
                
                // 居然有svga文件
                if pathExtension == "svga" {
                    return try loadSVGAData(fileURL)
                }
            }
            
            if pathExtension == "json" {
                if isLottieDir.jsonFileName == nil {
                    isLottieDir.jsonFileName = fileURL.lastPathComponent
                }
            } else if fileURL.lastPathComponent.lowercased() == "images" {
                isLottieDir.hadImagesDir = true
            }
        }
        
        if let jsonFileName = isLottieDir.jsonFileName {
            let jsonURL = tmpFileURL.appendingPathComponent(jsonFileName)
            
            guard isLottieDir.hadImagesDir else {
                // 只有json文件（纯矢量动画）
                let tmpData = try Data(contentsOf: jsonURL)
                let animation = try LottieAnimation.from(data: tmpData)
                
                let cached = try cacheFile(jsonURL, for: .lottie)
                
                let provider = FilepathImageProvider(filepath: cached.filePath)
                let store = AnimationStore.lottie(animation: animation, provider: provider)
                cache = store
                cacheDirName = cached.dirName
                
                return (store, cached.dirName)
            }
            
            // 还有images目录（自带图片的动画）
            let jsonPath = jsonURL.path
            guard let animation = LottieAnimation.filepath(jsonPath, animationCache: DefaultAnimationCache.sharedCache) else {
                throw Self.Error.lottieWithoutJsonFile
            }
            
            let cached = try cacheFile(tmpFileURL, for: .lottie)
            
            let provider = FilepathImageProvider(filepath: cached.filePath)
            let store = AnimationStore.lottie(animation: animation, provider: provider)
            cache = store
            cacheDirName = cached.dirName
            
            return (store, cached.dirName)
        }
        
        if !isNested {
            // 或者是套了一层
            for fileURL in fileURLs where fileURL.jp.isDirectory {
                guard let result = try _loadLottieData(fileURL, isDir: true, isNested: true) else { continue }
                return result
            }
        }
        
        // 已经嵌入一层去找了，还是找不着，没招了
        return nil
    }
    
    static func loadSVGAData(_ tmpFileURL: URL) throws -> LoadResult {
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
        
        let cached = try cacheFile(tmpFileURL, for: .svga)
        
        let store = AnimationStore.svga(entity: entity)
        cache = store
        cacheDirName = cached.dirName
        
        return (store, cached.dirName)
    }
    
    static func loadGIFData(_ tmpFileURL: URL) throws -> LoadResult {
        let tmpData = try Data(contentsOf: tmpFileURL)
        
        guard tmpData.jp.isGIF else {
            return try loadSVGAData(tmpFileURL)
        }
        
        guard let gif = decodeGIF(tmpData) else {
            throw Self.Error.decodeGIFFailed
        }
        
        let cached = try cacheFile(tmpFileURL, for: .gif)
        
        let store = AnimationStore.gif(images: gif.0, duration: gif.1)
        cache = store
        cacheDirName = cached.dirName
        
        return (store, cached.dirName)
    }
}

// MARK: - 缓存目录的引用管理（多窗口预埋）
extension AnimationStore {
    /// 各窗口当前正在引用的缓存目录名（只在主线程读写）
    private static var retainedDirNames: [ObjectIdentifier: String] = [:]
    
    /// 声明`owner`正在使用某个缓存目录，使其不被`collectGarbage`回收
    ///
    /// 传`nil`表示`owner`当前没有引用任何目录。
    static func retainCacheDir(_ dirName: String?, for owner: AnyObject) {
        let key = ObjectIdentifier(owner)
        if let dirName {
            retainedDirNames[key] = dirName
        } else {
            retainedDirNames.removeValue(forKey: key)
        }
    }
    
    static func releaseCacheDir(for owner: AnyObject) {
        retainedDirNames.removeValue(forKey: ObjectIdentifier(owner))
    }
    
    /// 回收没有窗口在引用、又不需要留给下次启动的缓存目录
    ///
    /// 必须在主线程调用（要读`retainedDirNames`），实际的删除回到`myQueue`执行，
    /// 与`loadData`串行，不会删到正在写入的目录。
    static func collectGarbage() {
        var aliveDirNames = Set(retainedDirNames.values)
        if !lastCacheDirName.isEmpty {
            aliveDirNames.insert(lastCacheDirName)
        }
        myQueue.async {
            for dirName in File.manager.list(cacheDirPath) where !aliveDirNames.contains(dirName) {
                File.manager.deleteFile(getCacheFilePath(dirName))
            }
        }
    }
}

// MARK: - 缓存管理
private extension AnimationStore {
    static var tmpDirPath: String { File.tmpFilePath("AnimationStore") }
    static var cacheDirPath: String { File.cacheFilePath("AnimationStore") }
    
    static func getTmpFilePath(_ fileName: String) -> String { tmpDirPath + "/" + fileName }
    static func getCacheFilePath(_ fileName: String) -> String { cacheDirPath + "/" + fileName }
    
    /// 上次退出前最后加载的动画（启动时恢复，经`loadCache`回调交出去）
    static var cache: AnimationStore? = nil
    /// `cache`所在的缓存目录名
    static var cacheDirName: String? = nil
    
    /// 最后一次加载的动画类型（留给下次启动恢复）
    @UserDefault(.animationType) static var lastCacheType: AnimationType.RawValue = 0
    /// 最后一次加载的动画所在的缓存目录名（留给下次启动恢复）
    @UserDefault(.animationCacheDirName) static var lastCacheDirName: String = ""
    
    /// 每个缓存目录里的动画文件都叫这个名（可能是文件，也可能是 lottie 的目录）
    static func animationFilePath(inDir dirName: String) -> String {
        getCacheFilePath(dirName) + "/jp_animation"
    }
    
    static func resetCacheRecord() {
        cache = nil
        cacheDirName = nil
        lastCacheType = 0
        lastCacheDirName = ""
    }
    
    /// 把动画文件搬进一个**新建的独立目录**，并记录为「最后一次加载」
    ///
    /// 每次加载都用新目录，而不是复用同一个固定路径，这样多个窗口各自的动画文件不会被后来者覆盖
    /// ——尤其是带`images`目录的lottie，它的`FilepathImageProvider`是按需从磁盘读图的，
    /// 文件一旦被删，已经在播的动画就会缺图
    static func cacheFile(_ fileURL: URL, for type: AnimationType) throws -> (dirName: String, filePath: String) {
        let dirName = UUID().uuidString
        guard File.manager.createDirectory(getCacheFilePath(dirName)) else {
            throw Self.Error.cacheDirCreateFailed
        }
        
        let filePath = animationFilePath(inDir: dirName)
        try FileManager.default.moveItem(at: fileURL, to: URL(fileURLWithPath: filePath))
        
        lastCacheType = type.rawValue
        lastCacheDirName = dirName
        
        return (dirName, filePath)
    }
    
    static func loadCacheData() -> LoadResult? {
        let dirName = lastCacheDirName
        let filePath = animationFilePath(inDir: dirName)
        guard let cacheType = AnimationType(rawValue: lastCacheType),
              !dirName.isEmpty,
              File.manager.fileExists(filePath)
        else {
            resetCacheRecord()
            return nil
        }
        
        let store: AnimationStore
        switch cacheType {
        case .dotLottie:
            let result = DotLottieFile.SynchronouslyBlockingCurrentThread.loadedFrom(filepath: filePath, dotLottieCache: nil)
            guard case let .success(file) = result, file.animations.first != nil else {
                resetCacheRecord()
                return nil
            }
            
            store = .dotLottie(file: file)
            
        case .lottie:
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory) else {
                resetCacheRecord()
                return nil
            }
            
            // 文件夹是lottie_dir（自带图片的动画），非文件夹则是lottie_json（纯矢量动画）
            let jsonPath: String
            if isDirectory.boolValue {
                guard let fileName = File.manager.list(filePath).first(where: {
                    ($0 as NSString).pathExtension.lowercased() == "json"
                }) else {
                    resetCacheRecord()
                    return nil // 找不到动画json文件
                }
                jsonPath = "\(filePath)/\(fileName)"
            } else {
                jsonPath = filePath
            }
            
            guard let animation = LottieAnimation.filepath(jsonPath, animationCache: DefaultAnimationCache.sharedCache) else {
                resetCacheRecord()
                return nil
            }
            
            // animation 和 provider 是必须的
            let provider = FilepathImageProvider(filepath: filePath)
            store = .lottie(animation: animation, provider: provider)
            
        case .svga:
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let entity = parseSVGA(data)
            else {
                resetCacheRecord()
                return nil
            }
            
            store = .svga(entity: entity)
            
        case .gif:
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let gif = decodeGIF(data)
            else {
                resetCacheRecord()
                return nil
            }
            
            store = .gif(images: gif.0, duration: gif.1)
        }
        
        cache = store
        cacheDirName = dirName
        
        return (store, dirName)
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
//        var entity: SVGAVideoEntity?
//        let lock = DispatchSemaphore(value: 0)
//        // `cacheKey`每次都得是新的：`SVGAParser`解析前会先拿它查内存缓存，
//        // 命中就直接把缓存里那一份`entity`原样返回。
//        // 这里原本传空字符串，等于所有svga共用一个键：
//        // 只要前一个`entity`还被某个窗口持有着（多窗口下必然如此），
//        // 后打开的svga就会拿到前一个的画面（文件、缓存目录都是对的，只有画面不对）。
//        SVGAParser().parse(with: data, cacheKey: UUID().uuidString) {
//            entity = $0
//            lock.signal()
//        } failureBlock: { _ in
//            lock.signal()
//        }
//        lock.wait()
//        return entity
        
        // 使用新API：直接同步解析，不经SVGAParser内部缓存获取。
        SVGAParser.parse(with: data)
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
