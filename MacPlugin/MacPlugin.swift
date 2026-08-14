//
//  MacPlugin.swift
//  MacPlugin
//
//  Created by 周健平 on 2023/5/9.
//

import AppKit
import UniformTypeIdentifiers

class MacPlugin: NSObject, Channel {
    private var statusItem: NSStatusItem? = nil
    
    /// UIKit 原本的`NSApplication`代理
//    private var uikitDelegate: NSApplicationDelegate?
    
    /// `setup`可能被调多次，窗口通知只注册一次
    private var isObservingWindows = false
    
    // MARK: - <Channel>
    
    required override init() {}
    
    func setup() {
        /// 📢 注意：不要去接管`NSApplication.shared.delegate`。
        /// Catalyst 底层跑的是 AppKit，UIKit 装了一个 shim 当这个代理，
        /// 负责把 AppKit 事件转发给 UIScene；把它顶掉，「双击文件打开」就没人接了，
        /// AppKit 会回落到`NSDocumentController`，弹出`cannot open files in the “XXX” format`。
        /// 状态栏图标和下面的关闭按钮接管都不需要代理身份，别为它们动这个代理。
//        if NSApplication.shared.delegate !== self {
//            // `setup`每个场景都会调一次，只在第一次接管，
//            // 否则第二次会把`uikitDelegate`指向自己，转发时无限递归。
//            uikitDelegate = NSApplication.shared.delegate
//            NSApplication.shared.delegate = self
//        }
        
        // 关闭按钮改成「收起App」，这样点关闭才不会退出
        observeWindowAppearance()
        
        // 场景可能断开又重连，`setup`会再跑一次，状态栏图标别重复创建
        guard statusItem == nil else { return }
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            let image = NSImage(named: NSImage.Name("bar_cat"))
            button.image = image
            button.action = #selector(openMainWindow)
            button.target = self
        }
        
        self.statusItem = statusItem
    }
    
    func saveImage(_ imageData: Data, completion: @escaping Channel.SaveCompletion) {
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
    
    func saveVideo(_ videoPath: NSString, completion: @escaping Channel.SaveCompletion) {
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
    
    func pickLottie(completion: @escaping Channel.PickCompletion) {
        let openPanel = getOpenPanel([
            .zip,
            .directory,
            UTType(exportedAs: "lottie", conformingTo: .data),
        ], canChooseDirectories: true)
        
        guard openPanel.runModal() == .OK else { return }
        
        guard let url = openPanel.url else {
            print("没有找到符合要求的文件或文件夹")
            completion(nil, nil)
            return
        }
        
        if isDirectory(at: url), let zipData = zipFolderWithLottieContents(folderURL: url) {
            print("成功获取zip文件的Data, 大小: \(zipData.count)字节")
            completion(zipData, nil)
        }
        else if let data = try? Data(contentsOf: url) {
            print("成功获取Data, 大小: \(data.count)字节")
            completion(data, url.pathExtension.lowercased())
        }
        else {
            print("没有找到符合要求的文件或文件夹")
            completion(nil, nil)
        }
    }
    
    func pickSVGA(completion: @escaping Channel.PickCompletion) {
        let openPanel = getOpenPanel([
            UTType(exportedAs: "svga", conformingTo: .data),
        ])
        
        guard openPanel.runModal() == .OK else { return }
        
        if let url = openPanel.url, let data = try? Data(contentsOf: url) {
            print("成功获取Data, 大小: \(data.count)字节")
            completion(data, url.pathExtension.lowercased())
        }
        else {
            print("没有找到符合要求的文件")
            completion(nil, nil)
        }
    }
    
    func pickGIF(completion: @escaping Channel.PickCompletion) {
        let openPanel = getOpenPanel([.gif])
        
        guard openPanel.runModal() == .OK else { return }
        
        if let url = openPanel.url, let data = try? Data(contentsOf: url) {
            print("成功获取Data, 大小: \(data.count)字节")
            completion(data, url.pathExtension.lowercased())
        }
        else {
            print("没有找到符合要求的文件")
            completion(nil, nil)
        }
    }
    
    func pickImage(completion: @escaping Channel.PickCompletion) {
        let openPanel = getOpenPanel([.jpeg, .png])
        
        guard openPanel.runModal() == .OK else { return }
        
        if let url = openPanel.url, let data = try? Data(contentsOf: url) {
            print("成功获取Data, 大小: \(data.count)字节")
            completion(data, url.pathExtension.lowercased())
        }
        else {
            print("没有找到符合要求的文件")
            completion(nil, nil)
        }
    }
}

// MARK: - 文件操作
private extension MacPlugin {
    func getOpenPanel(_ types: [UTType], canChooseDirectories: Bool = false) -> NSOpenPanel {
        let openPanel = NSOpenPanel()
        openPanel.showsHiddenFiles = true // 显示隐藏文件
        openPanel.canChooseFiles = true // 可以选择文件
        openPanel.canChooseDirectories = canChooseDirectories // 是否可以选择文件夹
        openPanel.allowsMultipleSelection = false // 单选
        openPanel.allowedContentTypes = types
        return openPanel
    }
    
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
            let dataFile = folderContents.first { $0.pathExtension.lowercased() == "json" }
            guard let dataFileURL = dataFile else {
                print("文件夹内容不符合要求，缺少 data.json")
                return nil
            }
            
            let imagesFolder = folderContents.first { $0.lastPathComponent == "images" && isDirectory(at: $0) }
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

// MARK: - 点关闭按钮只收起App，不退出
//
// 试过无效，别再走的两条路：
// 1.`applicationShouldTerminateAfterLastWindowClosed`返回false
//  — Catalyst下窗口一旦真的关闭，UIKit 就断开场景并终止进程，它不问这个 AppKit 回调。
// 2.窗口代理的`windowShouldClose` —— UIKit 同样不经过它。
//
// 所以改成：接管【关闭按钮】的动作，从源头上不让窗口走进关闭流程。
private extension MacPlugin {
    /// 窗口是 UIKit 建的，`setup`时可能还不存在，所以监听通知等它出现
    func observeWindowAppearance() {
        guard !isObservingWindows else { return }
        isObservingWindows = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(takeOverCloseButton(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
    }
    
    @objc func takeOverCloseButton(_ note: Notification) {
        guard let window = note.object as? NSWindow,
              let closeButton = window.standardWindowButton(.closeButton),
              closeButton.target !== self
        else { return }
        
        closeButton.target = self
        closeButton.action = #selector(hideWindow(_:))
    }
    
    /// 点关闭按钮：收起整个App（等同 Cmd+H）
    ///
    /// 必须是`NSApp.hide`而不是`window.orderOut`：前者是系统认得的「应用已隐藏」状态，
    /// 系统激活App时会自己把窗口恢复回来；后者只是把窗口挪出屏幕，
    /// 而 Catalyst 下窗口归 UIKit 管，想再显示回来就得跟 UIKit 抢，试过多种写法都不稳。
    @objc func hideWindow(_ sender: Any?) {
        NSApplication.shared.hide(nil)
    }
    
    /// 点状态栏图标：请系统「打开」本App，走和点Dock图标同一条路
    ///
    /// 不能自己调`activate`：App 自己抢激活会被系统随后撤销（表现为闪一下又切回去，延迟到1秒也没用）。
    /// Dock点击好使正是因为激活由系统发起，这里把它交还给系统。
    @objc func openMainWindow() {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config)
    }
}
