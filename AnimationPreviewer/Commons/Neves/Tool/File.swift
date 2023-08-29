//
//  File.swift
//  Neves
//
//  Created by aa on 2020/11/13.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

struct File {
    static var documentDirPath: String { NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, .userDomainMask, true).last ?? "" }
    static func documentFilePath(_ fileName: String) -> String { documentDirPath + "/" + fileName }
    
    static var cacheDirPath: String { NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, .userDomainMask, true).first ?? "" }
    static func cacheFilePath(_ fileName: String) -> String { cacheDirPath + "/" + fileName }
    
    static var tmpDirPath: String { NSTemporaryDirectory() } // 这个最后自带“/”
    static func tmpFilePath(_ fileName: String) -> String { tmpDirPath + fileName }
    
    struct manager {
        typealias ExecuteError = (Error) -> ()
        
        static func fileExists(_ atPath: String?) -> Bool {
            guard let filePath = atPath else { return false }
            return FileManager.default.fileExists(atPath: filePath)
        }
        
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
    }
}


