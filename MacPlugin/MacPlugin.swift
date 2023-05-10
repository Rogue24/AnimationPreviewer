//
//  MacPlugin.swift
//  MacPlugin
//
//  Created by 周健平 on 2023/5/9.
//

import AppKit

class MacPlugin: NSObject, Channel {
    var statusItem: NSStatusItem?
    
// MARK: - <Channel>
    required override init() {}
    
    func setup() {
        NSApplication.shared.delegate = self
        
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            let image = NSImage(named: NSImage.applicationIconName)
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
}

extension MacPlugin {
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
