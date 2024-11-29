//
//  MacPlugin.swift
//  MacPlugin
//
//  Created by 周健平 on 2023/5/9.
//

import AppKit
import UniformTypeIdentifiers

class MacPlugin: NSObject, Channel {
    var statusItem: NSStatusItem?
    
// MARK: - <Channel>
    
    required override init() {}
    
    func setup() {
        NSApplication.shared.delegate = self
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            let image = NSImage(named: NSImage.Name("bar_cat"))
            button.image = image
            button.action = #selector(openMainWindow)
            button.target = self
        }
        
        self.statusItem = statusItem
    }
    
    func saveImage(_ imageData: Data, completion: @escaping (_ isSuccess: Bool) -> ()) {
        guard let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("找不到下载文件夹")
            completion(false)
            return
        }
        
        let fileName = "jp_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = url.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            // 打开文件所在目录
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            completion(true)
        } catch {
            print("保存失败 \(error)")
            completion(false)
        }
    }
    
    func saveVideo(_ videoPath: NSString, completion: @escaping (_ isSuccess: Bool) -> ()) {
        guard let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            print("找不到下载文件夹")
            completion(false)
            return
        }
        
        let fileName = "jp_\(videoPath.lastPathComponent)" // 替换为您保存的文件名
        let fileURL = url.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.moveItem(atPath: videoPath as String, toPath: fileURL.path)
            // 打开文件所在目录
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            completion(true)
        } catch {
            print("保存失败 \(error)")
            completion(false)
        }
    }
    
    func pickLottie(completion: @escaping (_ data: Data?) -> ()) {
        let openPanel = NSOpenPanel()
        openPanel.showsHiddenFiles = true // 显示隐藏文件
        openPanel.canChooseFiles = true // 可以选择文件
        openPanel.canChooseDirectories = true // 可以选择文件夹
        openPanel.allowsMultipleSelection = false // 单选
        openPanel.allowedContentTypes = [.zip, .directory]
        
        guard openPanel.runModal() == .OK else { return }
        
        guard let url = openPanel.url else {
            print("没有找到符合要求的文件或文件夹")
            completion(nil)
            return
        }
        
        if isDirectory(at: url), let zipData = zipFolderWithLottieContents(folderURL: url) {
            print("成功获取zip文件的Data, 大小: \(zipData.count)字节")
            completion(zipData)
        }
        else if let data = try? Data(contentsOf: url) {
            print("成功获取Data, 大小: \(data.count)字节")
            completion(data)
        }
        else {
            print("没有找到符合要求的文件或文件夹")
            completion(nil)
        }
    }
    
    func pickSVGA(completion: @escaping (_ data: Data?) -> ()) {
        let openPanel = NSOpenPanel()
        openPanel.showsHiddenFiles = true // 显示隐藏文件
        openPanel.canChooseFiles = true // 可以选择文件
        openPanel.canChooseDirectories = false // 不能选择文件夹
        openPanel.allowsMultipleSelection = false // 单选
        openPanel.allowedContentTypes = [UTType(exportedAs: "svga", conformingTo: .data)]
        
        guard openPanel.runModal() == .OK else { return }
        
        if let url = openPanel.url, let data = try? Data(contentsOf: url) {
            print("成功获取Data, 大小: \(data.count)字节")
            completion(data)
        }
        else {
            print("没有找到符合要求的文件")
            completion(nil)
        }
    }
    
    func pickGIF(completion: @escaping (_ data: Data?) -> ()) {
        let openPanel = NSOpenPanel()
        openPanel.showsHiddenFiles = true // 显示隐藏文件
        openPanel.canChooseFiles = true // 可以选择文件
        openPanel.canChooseDirectories = false // 不能选择文件夹
        openPanel.allowsMultipleSelection = false // 单选
        openPanel.allowedContentTypes = [.gif]
        
        guard openPanel.runModal() == .OK else { return }
        
        if let url = openPanel.url, let data = try? Data(contentsOf: url) {
            print("成功获取Data, 大小: \(data.count)字节")
            completion(data)
        }
        else {
            print("没有找到符合要求的文件")
            completion(nil)
        }
    }
    
    func pickImage(completion: @escaping (_ data: Data?) -> ()) {
        let openPanel = NSOpenPanel()
        openPanel.showsHiddenFiles = true // 显示隐藏文件
        openPanel.canChooseFiles = true // 可以选择文件
        openPanel.canChooseDirectories = false // 不能选择文件夹
        openPanel.allowsMultipleSelection = false // 单选
        openPanel.allowedContentTypes = [.jpeg, .png]
        
        guard openPanel.runModal() == .OK else { return }
        
        if let url = openPanel.url, let data = try? Data(contentsOf: url) {
            print("成功获取Data, 大小: \(data.count)字节")
            completion(data)
        }
        else {
            print("没有找到符合要求的文件")
            completion(nil)
        }
    }
}

// MARK: - 文件操作
private extension MacPlugin {
    /// 该路径是否文件夹
    func isDirectory(at url: URL) -> Bool {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        // 检查路径是否存在，并判断它是否是一个文件夹
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        return exists && isDirectory.boolValue
    }
    
    /// 将 Lottie 所需文件放入到一个临时文件夹中再进行压缩
    func zipFolderWithLottieContents(folderURL: URL) -> Data? {
        let fileManager = FileManager.default
        
        do {
            // 获取文件夹中的所有内容
            let folderContents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])
            
            // 检查文件夹中是否包含"data.json"和"images"文件夹
            let dataFile = folderContents.first { $0.lastPathComponent == "data.json" }
            guard let dataFileURL = dataFile else {
                print("文件夹内容不符合要求，缺少 data.json")
                return nil
            }
            
            let imagesFolder = folderContents.first { $0.lastPathComponent == "images" && $0.hasDirectoryPath }
            guard let imagesFolderURL = imagesFolder else {
                print("文件夹内容不符合要求，缺少 images 文件夹")
                return nil
            }
            
            // 创建一个临时文件夹来存放需要压缩的内容
            let tempDirectory = fileManager.temporaryDirectory
            let tempFolderURL = tempDirectory.appendingPathComponent(UUID().uuidString)
            
            // 创建临时文件夹
            try fileManager.createDirectory(at: tempFolderURL, withIntermediateDirectories: true, attributes: nil)
            
            // 将"data.json"文件和"images"文件夹复制到临时文件夹中
            let destinationDataFileURL = tempFolderURL.appendingPathComponent("data.json")
            let destinationImagesFolderURL = tempFolderURL.appendingPathComponent("images")
            
            try fileManager.copyItem(at: dataFileURL, to: destinationDataFileURL)
            try fileManager.copyItem(at: imagesFolderURL, to: destinationImagesFolderURL)
            
            // 压缩临时文件夹
            return zipFolderToData(folderURL: tempFolderURL)
            
        } catch {
            print("操作失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 压缩文件夹
    func zipFolderToData(folderURL: URL) -> Data? {
        let fileManager = FileManager.default
        let archiveURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("zip")
        
        // 创建zip压缩任务
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/zip") // macOS自带zip命令
        task.arguments = ["-r", archiveURL.path, folderURL.lastPathComponent]
        task.currentDirectoryURL = folderURL.deletingLastPathComponent()
        
        // 设置管道来捕获zip命令的输出
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        // 执行压缩任务
        do {
            try task.run()
            task.waitUntilExit()
            
            // 检查文件是否成功创建
            if task.terminationStatus == 0, fileManager.fileExists(atPath: archiveURL.path) {
                // 读取生成的zip文件数据
                let zipData = try Data(contentsOf: archiveURL)
                // 删除临时zip文件
                try fileManager.removeItem(at: archiveURL)
                return zipData
            } else {
                print("压缩失败，退出状态: \(task.terminationStatus)")
                return nil
            }
        } catch {
            print("错误: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - 打开主窗口
private extension MacPlugin {
    @objc func openMainWindow() {
        NSApplication.shared.mainWindow?.windowController?.showWindow(NSApplication.shared.mainWindow)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

// MARK: - <NSApplicationDelegate>
extension MacPlugin: NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 返回true确保点击关闭后app真的死掉，否则只是隐藏
        return true
    }
}
