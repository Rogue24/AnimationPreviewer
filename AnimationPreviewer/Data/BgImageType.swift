//
//  BgImageType.swift
//  AnimationPreviewer
//
//  Created by aa on 2024/11/29.
//

import UIKit

enum BgImageType: Int {
    case null = 0
    case builtIn1 = 1
    case builtIn2 = 2
    case custom = 3
    
    static var customBgImageDataPath: String { File.cacheFilePath("jp_bgImageData") }
    
    static func removeCustomBgImageData() {
        File.manager.deleteFile(customBgImageDataPath)
    }
    
    static func cacheCustomBgImageData(_ data: Data) -> Bool {
        do {
            try data.write(to: URL(fileURLWithPath: customBgImageDataPath))
            return true
        } catch {
            return false
        }
    }
    
    var bgImage: UIImage? {
        switch self {
        case .null:
            return nil
        case .builtIn1:
            return UIImage(contentsOfFile: Bundle.jp.resourcePath(withName: "background1", type: "jpg"))
        case .builtIn2:
            return UIImage(contentsOfFile: Bundle.jp.resourcePath(withName: "background2", type: "jpg"))
        case .custom:
            return UIImage(contentsOfFile: Self.customBgImageDataPath)
        }
    }
}
