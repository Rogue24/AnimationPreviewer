//
//  UIImage+.swift
//  AnimationPreviewer
//
//  Created by aa on 2025/4/12.
//

import UIKit

extension UIImage {
    /// 透明格子图片
    static let transparentGrid: UIImage = {
        let size = CGSize(width: 20, height: 20)
        let gridWH = size.width * 0.5
        
//        UIGraphicsBeginImageContextWithOptions(size, false, 0)
//        // 获取绘图上下文
//        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
//
//        // 背景颜色
//        UIColor(white: 1, alpha: 0.9).setFill()
//        context.fill(CGRect(origin: .zero, size: size))
//        
//        // 小方块颜色
//        UIColor(white: 0.75, alpha: 0.9).setFill()
//        context.fill(CGRect(x: 0, y: 0, width: gridWH, height: gridWH))
//        context.fill(CGRect(x: gridWH, y: gridWH, width: gridWH, height: gridWH))
//
//        let image = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        
//        return image ?? UIImage()
        
        /// ⚡️性能提升：
        /// 相对于`UIGraphicsBeginImageContextWithOptions`，`UIGraphicsImageRenderer`是更推荐的方式，
        /// 尤其是在需要高效生成图像时。
        
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = UIScreen.main.scale
        
        // 使用 renderer 生成图像
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)
        return renderer.image { context in
            // 获取绘图上下文
            let ctx = context.cgContext
            
            // 背景填充
            UIColor(white: 1, alpha: 0.9).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            
            // 绘制小格子
            UIColor(white: 0.75, alpha: 0.9).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: gridWH, height: gridWH))
            ctx.fill(CGRect(x: gridWH, y: gridWH, width: gridWH, height: gridWH))
        }
    }()
}
