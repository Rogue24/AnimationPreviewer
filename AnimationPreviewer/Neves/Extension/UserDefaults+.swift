//
//  UserDefault+.swift
//  AnimationPreviewer
//
//  Created by aa on 2023/8/30.
//

import Foundation

extension UserDefaults {
    /// 在这里注册`Key`
    enum Key: String, CaseIterable {
        case animationType
        case isSVGAMute
    }
}
