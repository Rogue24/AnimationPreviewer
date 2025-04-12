//
//  AppDelegate.swift
//  AnimationPreviewer
//
//  Created by 周健平 on 2023/5/8.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    @objc var window: UIWindow? {
        set {}
        get {
            guard let scene = UIApplication.shared.connectedScenes.first,
                  let windowSceneDelegate = scene.delegate as? UIWindowSceneDelegate,
                  let window = windowSceneDelegate.window
            else {
                return nil
            }
            return window
        }
    }
    
    private var mainVC: ViewController? {
        window?.rootViewController as? ViewController
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // 使用深色模式
        if #available(macCatalyst 13.0, *) {
            window?.overrideUserInterfaceStyle = .dark
        }
        
        JPProgressHUD.setMaxSupportedWindowLevel(.alert)
        JPProgressHUD.setMinimumDismissTimeInterval(1.3)
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        // 确保在 macOS 上构建菜单
        guard builder.system == .main else { return }
        // 移除不需要的菜单
        builder.remove(menu: .format)
        // 自定义菜单栏
        insertCustomMenuAtFileMenu(with: builder)
        replaceEditMenu(with: builder)
    }
    
}

// MARK: - 自定义菜单栏·打开动画文件
private extension AppDelegate {
    func insertCustomMenuAtFileMenu(with builder: any UIMenuBuilder) {
        let openLottieFileAction = UIKeyCommand(title: "Open Lottie File",
                                                action: #selector(openLottieFile),
                                                input: "L", modifierFlags: [.command])
        openLottieFileAction.discoverabilityTitle = "选中一个Lottie文件或zip文件"
        
        let openSVGAFileAction = UIKeyCommand(title: "Open SVGA File",
                                              action: #selector(openSVGAFile),
                                              input: "S", modifierFlags: [.command])
        openSVGAFileAction.discoverabilityTitle = "选中一个svga文件"
        
        let openGIFFileAction = UIKeyCommand(title: "Open GIF File",
                                             action: #selector(openGIFFile),
                                             input: "G", modifierFlags: [.command])
        openGIFFileAction.discoverabilityTitle = "选中一个gif文件"
        
        let openAnimFileMenu = UIMenu(title: "Open Animation File", children: [
            openLottieFileAction,
            openSVGAFileAction,
            openGIFFileAction,
        ])
        
        // 插入File菜单的第一个位置
        builder.insertChild(openAnimFileMenu, atStartOfMenu: .file)
    }
    
    @objc func openLottieFile() {
        MacChannel.shared().pickLottie { [weak self] data in
            guard let data, let mainVC = self?.mainVC else { return }
            mainVC.replaceAnimation(with: data)
        }
    }
    
    @objc func openSVGAFile() {
        MacChannel.shared().pickSVGA { [weak self] data in
            guard let data, let mainVC = self?.mainVC else { return }
            mainVC.replaceAnimation(with: data)
        }
    }
    
    @objc func openGIFFile() {
        MacChannel.shared().pickGIF { [weak self] data in
            guard let data, let mainVC = self?.mainVC else { return }
            mainVC.replaceAnimation(with: data)
        }
    }
}

// MARK: - 自定义菜单栏·修改背景图
private extension AppDelegate {
    func replaceEditMenu(with builder: any UIMenuBuilder) {
        // 替换Edit菜单
        guard let editMenu = builder.menu(for: .edit) else { return }
        
        let openImageFileAction = UIAction(title: "Choose Background Image") { [weak self] _ in
            self?.openImageFile()
        }
        
        let useBuiltIn1BackgroundAction = UIAction(title: "Use Built-in Background 1") { [weak self] _ in
            self?.useBuiltIn1Background()
        }
        
        let useBuiltIn2BackgroundAction = UIAction(title: "Use Built-in Background 2") { [weak self] _ in
            self?.useBuiltIn2Background()
        }
        
        let clearBackgroundAction = UIAction(title: "Clear Background") { [weak self] _ in
            self?.clearBackground()
        }
        
        // 使用一个空的内联菜单作为分隔符
        let separatorMenu = UIMenu(title: "", options: .displayInline, children: [])
        
        let updatedEditMenu = editMenu.replacingChildren([
            openImageFileAction,
            useBuiltIn1BackgroundAction,
            useBuiltIn2BackgroundAction,
            separatorMenu,
            clearBackgroundAction
        ])
        
        builder.replace(menu: .edit, with: updatedEditMenu)
    }
    
    func openImageFile() {
        MacChannel.shared().pickImage { [weak self] data in
            guard let data, let mainVC = self?.mainVC else { return }
            mainVC.setupCustomBgImage(data)
        }
    }
    
    func useBuiltIn1Background() {
        guard let mainVC else { return }
        mainVC.setupBuiltIn1BgImage()
    }
    
    func useBuiltIn2Background() {
        guard let mainVC else { return }
        mainVC.setupBuiltIn2BgImage()
    }
    
    func clearBackground() {
        guard let mainVC else { return }
        mainVC.removeBgImage()
    }
}
