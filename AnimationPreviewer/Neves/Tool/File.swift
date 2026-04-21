//
//  File.swift
//  Neves
//
//  Created by aa on 2020/11/13.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

enum File {
    enum manager {
        typealias ExecuteError = (_ error: Error) -> Void
    }
}

// MARK: - String
extension File {
    /// Documents 目录
    static var documentDirPath: String {
        NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, .userDomainMask, true).first ?? ""
    }
    /// 拼接 Documents 下的文件
    static func documentFilePath(_ fileName: String) -> String {
        documentDirPath + "/" + fileName
    }
    
    /// Cache 目录
    static var cacheDirPath: String {
        NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, .userDomainMask, true).first ?? ""
    }
    /// 拼接 Cache 下的文件
    static func cacheFilePath(_ fileName: String) -> String {
        cacheDirPath + "/" + fileName
    }
    
    /// 临时目录
    static var tmpDirPath: String {
        NSTemporaryDirectory() // 这个最后自带“/”
    }
    /// 拼接临时目录下的文件
    static func tmpFilePath(_ fileName: String) -> String {
        tmpDirPath + fileName
    }
}

extension File.manager {
    // MARK: Exists
    static func fileExists(_ atPath: String?) -> Bool {
        guard let filePath = atPath else { return false }
        return FileManager.default.fileExists(atPath: filePath)
    }
    
    // MARK: 是否是文件
    static func isFile(_ atPath: String?) -> Bool {
        guard let path = atPath else { return false }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && !isDir.boolValue
    }
    
    // MARK: 是否是文件夹
    static func isDirectory(_ atPath: String?) -> Bool {
        guard let path = atPath else { return false }
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }
    
    // MARK: 创建文件夹
    @discardableResult
    static func createDirectory(_ atPath: String?, executeError: ExecuteError? = nil) -> Bool {
        guard let dirPath = atPath,
              !FileManager.default.fileExists(atPath: dirPath) else { return true }
        do {
            try FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 清空文件夹
    @discardableResult
    static func clearDirectory(_ atPath: String?, executeError: ExecuteError? = nil) -> Bool {
        guard let dirPath = atPath,
              FileManager.default.fileExists(atPath: dirPath) else { return true }
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
            for fileName in contents {
                let filePath = (dirPath as NSString).appendingPathComponent(fileName)
                try FileManager.default.removeItem(atPath: filePath)
            }
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 删除
    @discardableResult
    static func deleteFile(_ atPath: String?, executeError: ExecuteError? = nil) -> Bool {
        guard let filePath = atPath,
              FileManager.default.fileExists(atPath: filePath) else { return true }
        do {
            try FileManager.default.removeItem(atPath: filePath)
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 拷贝
    @discardableResult
    static func copyFile(_ atPath: String?, toPath: String?, executeError: ExecuteError? = nil) -> Bool {
        guard let fromFilePath = atPath,
              let toFilePath = toPath,
              FileManager.default.fileExists(atPath: fromFilePath),
              FileManager.default.fileExists(atPath: toFilePath) == false else { return false }
        do {
            try FileManager.default.copyItem(atPath: fromFilePath, toPath: toFilePath)
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 移动
    @discardableResult
    static func moveFile(_ atPath: String?, toPath: String?, executeError: ExecuteError? = nil) -> Bool {
        guard let fromFilePath = atPath,
              let toFilePath = toPath,
              FileManager.default.fileExists(atPath: fromFilePath),
              FileManager.default.fileExists(atPath: toFilePath) == false else { return false }
        do {
            try FileManager.default.moveItem(atPath: fromFilePath, toPath: toFilePath)
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 批量读取
    static func list(_ atPath: String?) -> [String] {
        guard let path = atPath else { return [] }
        // contentsOfDirectory 同样是高性能批量 API
        return (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }
}

// MARK: - URL
extension File {
    /// Documents 目录
    static var documentURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    /// 拼接 Documents 下的文件
    static func documentFileURL(_ fileName: String) -> URL {
        // 使用 URL 进行拼接，避免字符串路径问题
        documentURL.appendingPathComponent(fileName)
    }
    
    /// Cache 目录
    static var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }
    /// 拼接 Cache 下的文件
    static func cacheFileURL(_ fileName: String) -> URL {
        cacheURL.appendingPathComponent(fileName)
    }
    
    /// 临时目录
    static var tmpURL: URL {
        // isDirectory: true 可以让系统更准确处理路径
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
    /// 拼接临时目录下的文件
    static func tmpFileURL(_ fileName: String) -> URL {
        tmpURL.appendingPathComponent(fileName)
    }
}

extension File.manager {
    // MARK: Exists
    static func exists(_ url: URL?) -> Bool {
        guard let url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // MARK: 是否是文件
    static func isFile(_ atURL: URL?) -> Bool {
        guard let url = atURL else { return false }
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            // 明确等于 false 才是文件
            return values.isDirectory == false
        } catch {
            return false
        }
    }
    
    // MARK: 是否是文件夹
    static func isDirectory(_ atURL: URL?) -> Bool {
        guard let url = atURL else { return false }
        do {
            // resourceValues 是一次性读取文件元信息（metadata）
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            return values.isDirectory ?? false
        } catch {
            // 读取失败（比如权限问题）
            return false
        }
    }
    
    // MARK: 创建文件夹
    @discardableResult
    static func createDirectory(_ atURL: URL?, executeError: ExecuteError? = nil) -> Bool {
        guard let url = atURL else { return false }
        // 已存在直接返回成功（避免重复创建报错）
        if exists(url) {
            return true
        }
        do {
            // withIntermediateDirectories: true 表示中间路径不存在会自动创建
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 清空文件夹
    @discardableResult
    static func clearDirectory(_ atURL: URL?, executeError: ExecuteError? = nil) -> Bool {
        guard let url = atURL else { return false }
        do {
            // 一次性获取目录下所有文件（性能优于逐个判断）
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            for fileURL in contents {
                // 逐个删除
                try FileManager.default.removeItem(at: fileURL)
            }
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 删除
    @discardableResult
    static func delete(_ url: URL?, executeError: ExecuteError? = nil) -> Bool {
        guard let url, exists(url) else { return true }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 拷贝
    @discardableResult
    static func copy(_ from: URL?, to: URL?, executeError: ExecuteError? = nil) -> Bool {
        guard let from, let to,
              exists(from), !exists(to) else { return false }
        do {
            try FileManager.default.copyItem(at: from, to: to)
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 移动
    @discardableResult
    static func move(_ from: URL?, to: URL?, executeError: ExecuteError? = nil) -> Bool {
        guard let from, let to,
              exists(from), !exists(to) else { return false }
        do {
            try FileManager.default.moveItem(at: from, to: to)
            return true
        } catch {
            executeError?(error)
            return false
        }
    }
    
    // MARK: 批量读取
    static func list(_ url: URL?) -> [URL] {
        guard let url else { return [] }
        // contentsOfDirectory 是系统优化过的批量 API，比逐个 fileExists 判断性能高很多
        return (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
    }
}
