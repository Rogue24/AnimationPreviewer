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
    
}

private extension AppDelegate {
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
    
    @objc func openImageFile() {
        MacChannel.shared().pickImage { [weak self] data in
            guard let data, let mainVC = self?.mainVC else { return }
            mainVC.setupCustomBgImage(data)
        }
    }
    
    @objc func useBuiltIn1Background() {
        guard let mainVC else { return }
        mainVC.setupBuiltIn1BgImage()
    }
    
    @objc func useBuiltIn2Background() {
        guard let mainVC else { return }
        mainVC.setupBuiltIn2BgImage()
    }
    
    @objc func clearBackground() {
        guard let mainVC else { return }
        mainVC.removeBgImage()
    }
}
