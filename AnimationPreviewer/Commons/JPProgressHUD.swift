//
//  JPProgressHUD.swift
//  LottiePreviewer
//
//  Created by aa on 2023/8/29.
//

import UIKit

enum JPProgressHUD {
    static var maskType: SVProgressHUDMaskType = .clear
}

// MARK: - 初始化配置
extension JPProgressHUD {
    static func setLightStyle() {
        SVProgressHUD.setDefaultStyle(.light)
    }

    static func setDarkStyle() {
        SVProgressHUD.setDefaultStyle(.dark)
    }

    static func setCustomStyle() {
        SVProgressHUD.setDefaultStyle(.custom)
    }
    
    static func setMinimumDismissTimeInterval(_ interval: TimeInterval) {
        SVProgressHUD.setMinimumDismissTimeInterval(interval)
    }

    static func setMaxSupportedWindowLevel(_ windowLevel: UIWindow.Level) {
        SVProgressHUD.setMaxSupportedWindowLevel(windowLevel)
    }

    static func setBackgroundColor(_ bgColor: UIColor) {
        SVProgressHUD.setBackgroundColor(bgColor)
    }

    static func setForegroundColor(_ fgColor: UIColor) {
        SVProgressHUD.setForegroundColor(fgColor)
    }

    static func setSuccessImage(_ successImage: UIImage) {
        SVProgressHUD.setSuccessImage(successImage)
    }

    static func setErrorImage(_ errorImage: UIImage) {
        SVProgressHUD.setErrorImage(errorImage)
    }

    static func setInfoImage(_ infoImage: UIImage) {
        SVProgressHUD.setInfoImage(infoImage)
    }
}

// MARK: - 使用方法
extension JPProgressHUD {
    static var isVisible: Bool {
        SVProgressHUD.isVisible()
    }
    
    static func positionHUD() {
        SVProgressHUD.positionHUD()
    }
    
    static func show(withStatus: String? = nil, isUserInteractionEnabled: Bool = false) {
        SVProgressHUD.setDefaultMaskType(isUserInteractionEnabled ? .none : maskType)
        SVProgressHUD.show(withStatus: withStatus)
    }
    
    static func showProgress(_ progress: Float, status: String? = nil, isUserInteractionEnabled: Bool = false) {
        SVProgressHUD.setDefaultMaskType(isUserInteractionEnabled ? .none : maskType)
        SVProgressHUD.showProgress(progress, status: status)
    }
    
    static func showInfo(withStatus: String?, isUserInteractionEnabled: Bool = true) {
        SVProgressHUD.setDefaultMaskType(isUserInteractionEnabled ? .none : maskType)
        SVProgressHUD.showInfo(withStatus: withStatus)
    }
    
    static func showSuccess(withStatus: String?, isUserInteractionEnabled: Bool = true) {
        SVProgressHUD.setDefaultMaskType(isUserInteractionEnabled ? .none : maskType)
        SVProgressHUD.showSuccess(withStatus: withStatus)
    }
    
    static func showError(withStatus: String?, isUserInteractionEnabled: Bool = true) {
        SVProgressHUD.setDefaultMaskType(isUserInteractionEnabled ? .none : maskType)
        SVProgressHUD.showError(withStatus: withStatus)
    }
    
    static func showImage(_ image: UIImage?, status: String?, isUserInteractionEnabled: Bool = true) {
        SVProgressHUD.setDefaultMaskType(isUserInteractionEnabled ? .none : maskType)
        SVProgressHUD.show(image ?? UIImage(), status: status)
    }
    
    static func dismiss(withDelay delay: TimeInterval = 0, completion: SVProgressHUDDismissCompletion? = nil) {
        SVProgressHUD.dismiss(withDelay: delay, completion: completion)
    }
}
