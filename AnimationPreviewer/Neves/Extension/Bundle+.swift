//
//  Bundle.Extension.swift
//  Neves_Example
//
//  Created by 周健平 on 2020/10/9.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation

extension Bundle {
    // 参考 Alamofire
    var executable: String {
        (infoDictionary?[kCFBundleExecutableKey as String] as? String) ??
        (ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
        "Unknown"
    }
    
    var bundle: String { infoDictionary?[kCFBundleIdentifierKey as String] as? String ?? "Unknown" }
    
    var appVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown" }
    
    var appBuild: String { infoDictionary?[kCFBundleVersionKey as String] as? String ?? "Unknown" }
    
    var appName: String { infoDictionary?[kCFBundleNameKey as String] as? String ?? "Unknown" }
    
    var osNameVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let osName: String = {
            #if os(iOS)
            return "iOS"
            #elseif os(watchOS)
            return "watchOS"
            #elseif os(tvOS)
            return "tvOS"
            #elseif os(macOS)
            return "macOS"
            #elseif os(Linux)
            return "Linux"
            #elseif os(Windows)
            return "Windows"
            #else
            return "Unknown"
            #endif
        }()
        return "\(osName) \(versionString)"
    }
}

extension Bundle: JPCompatible {}
extension JP where Base: Bundle {
    static func executable() -> String {
        Base.main.executable
    }
    
    static func resourcePath(withName name: String, type: String? = nil) -> String {
        guard let path = Base.main.path(forResource: name, ofType: type) else { fatalError("路径不存在") }
        return path
    }
}
