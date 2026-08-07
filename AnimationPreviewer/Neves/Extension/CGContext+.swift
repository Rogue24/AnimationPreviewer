//
//  CGContext+.swift
//  Neves
//
//  Created by aa on 2026/8/7.
//

import UIKit

extension CGContext {
    /// 用指定底色铺满整块画布。`color`为`nil`或`.clear`时不做任何绘制（保持透明）。
    /// 背景应在绘制内容之前、任何坐标变换之外调用。
    /// - Parameters:
    ///   - color: 画布底色，`nil`为透明
    ///   - size: 画布尺寸
    func fill(_ color: UIColor?, size: CGSize) {
        guard let color, color != .clear else { return }
        color.setFill()
        fill(CGRect(origin: .zero, size: size))
    }
}
