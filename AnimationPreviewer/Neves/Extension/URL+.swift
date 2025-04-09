//
//  URL+.swift
//  AnimationPreviewer
//
//  Created by aa on 2025/4/9.
//

import Foundation

extension URL: JPCompatible {}
extension JP where Base == URL {
    /// 安全获取路径，支持选择是否保留百分号编码（兼容旧版本）
    /// 🌰🌰🌰 `"file:///Users/zhoujianping/My%20Documents/file.txt"`
    /// `percentEncoded: false => /Users/zhoujianping/My Documents/file.txt`
    /// `percentEncoded: true => /Users/zhoujianping/My%20Documents/file.txt`
    func safePath(percentEncoded: Bool = true) -> String {
        if #available(iOS 16.0, macOS 13.0, *) {
            return base.path(percentEncoded: percentEncoded)
        }
        
        // iOS 15 及以下用 URLComponents 实现
        guard percentEncoded, let components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            return base.path
        }
        
        return components.percentEncodedPath
    }
}
