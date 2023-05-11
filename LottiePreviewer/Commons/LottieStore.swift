//
//  LottieStore.swift
//  LottiePreviewer
//
//  Created by 周健平 on 2023/5/9.
//



enum LottieStore {
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
    
    
    static var tmpDirPath: String { File.tmpFilePath("LottiePreviewer") }
    static var cacheDirPath: String { File.cacheFilePath("LottiePreviewer") }
    
    static func getTmpFilePath(_ fileName: String) -> String { tmpDirPath + "/" + fileName }
    static func getCacheFilePath(_ fileName: String) -> String { cacheDirPath + "/" + fileName }
    
    @UserDefault("lottieName") static var lottieName: String?
    static var lottieFilePath: String? {
        guard let lottieName = lottieName else { return nil }
        return getCacheFilePath(lottieName)
    }
    
    static func clearCache() {
        if let lottieFilePath = lottieFilePath {
            File.manager.deleteFile(lottieFilePath)
        }
        lottieName = nil
    }
    
    static func setup() {
        File.manager.createDirectory(tmpDirPath)
        File.manager.createDirectory(cacheDirPath)
//        JPrint("tmpDirPath ---", tmpDirPath)
//        JPrint("cacheDirPath ---", cacheDirPath)
        
        guard let lottiePath = LottieStore.lottieFilePath,
              !File.manager.fileExists(lottiePath)
        else { return }
        
        lottieName = nil
    }
    
    static func loadZipData(_ zipData: Data) throws {
        File.manager.clearDirectory(tmpDirPath)
        
        let tmpFilePath = getTmpFilePath("jp123")
        let tmpFileURL = URL(fileURLWithPath: tmpFilePath)
        do {
            try zipData.write(to: tmpFileURL)
        } catch {
            throw error
        }
        
        let unzipDirPath = getTmpFilePath("jp456")
        SSZipArchive.unzipFile(atPath: tmpFilePath, toDestination: unzipDirPath)
        defer {
            File.manager.clearDirectory(tmpDirPath)
        }
        
        guard File.manager.fileExists(unzipDirPath) else {
            throw LottieStore.Error.unzipFailed
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: unzipDirPath), includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
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
                let contents = try FileManager.default.contentsOfDirectory(atPath: cacheDirPath)
                for oldFileName in contents {
                    let oldFilePath = (cacheDirPath as NSString).appendingPathComponent(oldFileName)
                    try FileManager.default.removeItem(atPath: oldFilePath)
                }
                
                let fileName = "jp_lottie"
                try FileManager.default.moveItem(at: URL(fileURLWithPath: unzipDirPath), to: URL(fileURLWithPath: getCacheFilePath(fileName)))
                lottieName = fileName
                
                return
            }
            
            // 或者是套了一层
            for fileURL in fileURLs {
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                guard let isDirectory = resourceValues.isDirectory, isDirectory else {
                    continue
                }
                
                let jsonPath = (fileURL.path as NSString).appendingPathComponent("data.json")
                guard File.manager.fileExists(jsonPath) else {
                    throw LottieStore.Error.withoutJsonFile
                }
                
                let imageDirPath = (fileURL.path as NSString).appendingPathComponent("images")
                guard File.manager.fileExists(imageDirPath) else {
                    throw LottieStore.Error.withoutImagesDir
                }
                
                let oldLottieName = lottieName ?? ""
                let contents = try FileManager.default.contentsOfDirectory(atPath: cacheDirPath)
                for oldFileName in contents {
                    let oldFilePath = (cacheDirPath as NSString).appendingPathComponent(oldFileName)
                    try FileManager.default.removeItem(atPath: oldFilePath)
                    if oldFileName == oldLottieName {
                        lottieName = nil
                    }
                }
                
                let fileName = fileURL.lastPathComponent
                try FileManager.default.moveItem(at: fileURL, to: URL(fileURLWithPath: getCacheFilePath(fileName)))
                lottieName = fileName
                
                return
            }
            
            throw LottieStore.Error.unzipFailed
        } catch {
            throw error
        }
    }
    
}
