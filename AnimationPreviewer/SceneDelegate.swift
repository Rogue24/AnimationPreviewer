//
//  SceneDelegate.swift
//  AnimationPreviewer
//
//  Created by 周健平 on 2023/5/8.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        
        (UIApplication.shared.delegate as? AppDelegate)?.window = window
        
        // 使用深色模式
        window?.overrideUserInterfaceStyle = .dark
        
        MacChannel.shared().setup()
        
        JPHUD.setMaxSupportedWindowLevel(.alert)
        JPHUD.setMinimumDismissTimeInterval(1.3)

        // 冷启动双击文件：URL随场景一起送到
        if let url = connectionOptions.urlContexts.first?.url {
            open(url)
        }
    }
    
    // App已经在运行，用户又双击了文件
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        open(url)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
}

// MARK: - 打开外部文件
private extension SceneDelegate {
    /// 双击进来的文件一律替换当前窗口的动画
    ///
    /// 单窗口，所以不必判断该复用还是另开 —— 这也正是改回单窗口的原因：
    /// 一旦允许多场景，文件落到哪个窗口就取决于系统怎么增建/销毁场景，不可控
    func open(_ url: URL) {
        // 这次要看的就是这个文件。把「上次动画」的记录清掉，
        // 窗口不该再去恢复上次那个；万一文件读取失败，
        // 也顶多是空画面，不会冒出上次的动画
        AnimationStore.clearCache()
        
        guard let mainVC = window?.rootViewController as? ViewController else { return }
        // `willConnectTo`早于`viewDidLoad`，此时先寄存URL，
        // 等`ViewController`准备好目录后再消费，免得和「恢复上次动画」的异步回调打架
        if mainVC.isViewLoaded {
            mainVC.openAnimationFile(at: url)
        } else {
            mainVC.pendingFileURL = url
        }
    }
}
