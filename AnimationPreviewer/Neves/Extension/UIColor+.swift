//
//  UIColor.Extension.swift
//  Neves_Example
//
//  Created by 周健平 on 2020/10/9.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

extension UIColor {
    /// 透明格子颜色
    static var transparentGrid: UIColor {
        UIColor(patternImage: .transparentGrid)
    }
    
    /// 默认背景色
    static var defaultBgColor: UIColor {
        .rgb(41, 43, 51, a: 0.35)
    }
}

extension UIColor {
    struct RGBA: Equatable {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 1
        
        static func randomRGBA(_ a: CGFloat = 1.0) -> Self {
            RGBA(r: CGFloat.random(in: 0...255),
                 g: CGFloat.random(in: 0...255),
                 b: CGFloat.random(in: 0...255),
                 a: a)
        }
        
        static func == (rgba1: Self, rgba2: Self) -> Bool {
            (rgba1.r == rgba2.r) &&
            (rgba1.g == rgba2.g) &&
            (rgba1.b == rgba2.b) &&
            (rgba1.a == rgba2.a)
        }
        
        static func + (rgba1: Self, rgba2: Self) -> Self {
            RGBA(r: rgba1.r + rgba2.r,
                 g: rgba1.g + rgba2.g,
                 b: rgba1.b + rgba2.b,
                 a: rgba1.a + rgba2.a)
        }
        
        static func - (rgba1: Self, rgba2: Self) -> Self {
            RGBA(r: rgba1.r - rgba2.r,
                 g: rgba1.g - rgba2.g,
                 b: rgba1.b - rgba2.b,
                 a: rgba1.a - rgba2.a)
        }
        
        static func * (rgba: Self, progress: CGFloat) -> Self {
            RGBA(r: rgba.r * progress,
                 g: rgba.g * progress,
                 b: rgba.b * progress,
                 a: rgba.a * progress)
        }
        
        static func fromSourceToTargetRgba(_ sourceRgba: Self, _ differRgba: Self, progress: CGFloat) -> Self {
            sourceRgba + (differRgba * progress)
        }
        
        static func fromSourceRgba(_ sourceRgba: Self, toTargetRgba targetRgba: Self, progress: CGFloat) -> Self {
            sourceRgba + ((targetRgba - sourceRgba) * progress)
        }
    }
    
    // MARK: - 从颜色中获取rgba
    var rgba: RGBA {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBA(r: r * 255, g: g * 255, b: b * 255, a: a)
    }
    
    // MARK: - 通过RGBA创建颜色
    class func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, a: CGFloat = 1) -> Self {
        Self.init(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
    }
    class func rgba(_ rgba: RGBA) -> Self {
        Self.init(red: rgba.r / 255.0, green: rgba.g / 255.0, blue: rgba.b / 255.0, alpha: rgba.a)
    }
    
    // MARK: - 通过十六进制颜色值创建颜色
    class func hex(_ hex: UInt32, a: CGFloat = 1) -> Self {
        let r = CGFloat((hex & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hex & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(hex & 0x0000FF) / 255.0
        return Self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    // MARK: - 随机颜色
    class var randomColor: UIColor { UIColor.rgba(RGBA.randomRGBA()) }
    class func randomColor(_ a: CGFloat = 1.0) -> UIColor { UIColor.rgba(RGBA.randomRGBA(a)) }
    
    // MARK: - 颜色转图片
    func toImage(size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = UIScreen.main.scale
        rendererFormat.opaque = false // 是否“完全不透明” --- false：可能有透明
        
        // 使用 renderer 生成图像
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        return renderer.image {
            // 背景填充
            self.setFill()
            $0.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}

extension CGColor {
    // MARK: - 通过RGBA创建颜色
    class func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, a: CGFloat = 1) -> CGColor {
        UIColor(red: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a).cgColor
    }
    class func rgba(_ rgba: UIColor.RGBA) -> CGColor {
        UIColor(red: rgba.r / 255.0, green: rgba.g / 255.0, blue: rgba.b / 255.0, alpha: rgba.a).cgColor
    }
    
    // MARK: - 通过十六进制颜色值创建颜色
    class func hex(_ hex: UInt32, a: CGFloat = 1) -> CGColor {
        UIColor.hex(hex, a: a).cgColor
    }
    
    // MARK: - 随机颜色
    class var randomColor: CGColor { UIColor.rgba(UIColor.RGBA.randomRGBA()).cgColor }
    class func randomColor(_ a: CGFloat = 1.0) -> CGColor { UIColor.rgba(UIColor.RGBA.randomRGBA(a)).cgColor }
}
