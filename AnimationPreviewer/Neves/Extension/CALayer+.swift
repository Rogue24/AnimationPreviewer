//
//  CALayer+.swift
//  Neves
//
//  Created by aa on 2026/8/7.
//

import UIKit

// MARK: - 👉🏻 UIImage
extension CALayer {
    /// `layer`缩放适配画布的模式
    enum FitMode {
        case aspectFit   // 等比缩放，完整显示，可能留白
        case aspectFill  // 等比缩放，填满画布，超出裁剪
        case fill        // 拉伸填满，不保持比例（可能变形）
    }
    
    /// 按指定模式将`layer`绘制到整个画布，生成`image`
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸，任意比例都能自动适配
    ///   - mode: 适配模式，默认`aspectFit`
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    func image(size: CGSize,
               mode: FitMode = .aspectFit,
               scale: CGFloat? = nil,
               background: UIColor? = nil) -> UIImage {
        image(size: size, region: fitRegion(in: size, mode: mode), scale: scale, background: background)
    }
    
    /// 按`layer`自身尺寸（`bounds`）原样生成`image`（内容 1:1，不缩放、不留白）
    /// - Parameters:
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    func image(scale: CGFloat? = nil,
               background: UIColor? = nil) -> UIImage {
        image(size: bounds.size, region: CGRect(origin: .zero, size: bounds.size), scale: scale, background: background)
    }
    
    /// 将`layer`拉伸铺满画布中的指定区域（不保持比例），超出画布的部分自动裁剪，生成`image`
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸
    ///   - region: 目标区域（画布坐标系内，位置和大小均可自由指定）
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    func image(size: CGSize,
               region: CGRect,
               scale: CGFloat? = nil,
               background: UIColor? = nil) -> UIImage {
        UIGraphicsImageRenderer(
            size: size,
            format: makeFormat(scale, background)
        ).image(
            actions: makeActions(size, region, background)
        )
    }
}

// MARK: - 👉🏻 PNG/JPEG Data
extension CALayer {
    /// 按指定模式将`layer`绘制到整个画布，生成`PNG data`（无损，支持透明）
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸，任意比例都能自动适配
    ///   - mode: 适配模式，默认`aspectFit`
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    func pngData(size: CGSize,
                 mode: FitMode = .aspectFit,
                 scale: CGFloat? = nil,
                 background: UIColor? = nil) -> Data {
        pngData(size: size, region: fitRegion(in: size, mode: mode), scale: scale, background: background)
    }
    
    /// 按`layer`自身尺寸（`bounds`）原样生成`PNG data`（内容 1:1，不缩放、不留白）
    /// - Parameters:
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    func pngData(scale: CGFloat? = nil,
                 background: UIColor? = nil) -> Data {
        pngData(size: bounds.size, region: CGRect(origin: .zero, size: bounds.size), scale: scale, background: background)
    }
    
    /// 将`layer`拉伸铺满画布中的指定区域（不保持比例），超出画布的部分自动裁剪，生成`PNG data`（无损，支持透明）
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸
    ///   - region: 目标区域（画布坐标系内，位置和大小均可自由指定）
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    func pngData(size: CGSize,
                 region: CGRect,
                 scale: CGFloat? = nil,
                 background: UIColor? = nil) -> Data {
        UIGraphicsImageRenderer(
            size: size,
            format: makeFormat(scale, background)
        ).pngData(
            actions: makeActions(size, region, background)
        )
    }
    
    /// 按指定模式将`layer`绘制到整个画布，生成`JPEG data`（有损，**不支持透明**）
    /// - Note: JPEG 无 alpha 通道，未铺背景（`background`为`nil/.clear`）时透明区域会被填成黑色，需要透明请改用`pngData`
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸，任意比例都能自动适配
    ///   - mode: 适配模式，默认`aspectFit`
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - quality: JPEG 压缩质量，`0`（最小体积） ~ `1`（最高质量），默认`0.9`
    func jpegData(size: CGSize,
                  mode: FitMode = .aspectFit,
                  scale: CGFloat? = nil,
                  background: UIColor? = nil,
                  quality: CGFloat = 0.9) -> Data {
        jpegData(size: size, region: fitRegion(in: size, mode: mode), scale: scale, background: background, quality: quality)
    }
    
    /// 按`layer`自身尺寸（`bounds`）原样生成`JPEG data`（内容 1:1，不缩放、不留白）
    /// - Note: JPEG 无 alpha 通道，未铺背景（`background`为`nil/.clear`）时透明区域会被填成黑色，需要透明请改用`pngData`
    /// - Parameters:
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - quality: JPEG 压缩质量，`0`（最小体积） ~ `1`（最高质量），默认`0.9`
    func jpegData(scale: CGFloat? = nil,
                  background: UIColor? = nil,
                  quality: CGFloat = 0.9) -> Data {
        jpegData(size: bounds.size, region: CGRect(origin: .zero, size: bounds.size), scale: scale, background: background, quality: quality)
    }
    
    /// 将`layer`拉伸铺满画布中的指定区域（不保持比例），超出画布的部分自动裁剪，生成`JPEG data`（有损，**不支持透明**）
    /// - Note: JPEG 无 alpha 通道，未铺背景（`background`为`nil/.clear`）时透明区域会被填成黑色，需要透明请改用`pngData`
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸
    ///   - region: 目标区域（画布坐标系内，位置和大小均可自由指定）
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - quality: JPEG 压缩质量，`0`（最小体积） ~ `1`（最高质量），默认`0.9`
    func jpegData(size: CGSize,
                  region: CGRect,
                  scale: CGFloat? = nil,
                  background: UIColor? = nil,
                  quality: CGFloat = 0.9) -> Data {
        UIGraphicsImageRenderer(
            size: size,
            format: makeFormat(scale, background)
        ).jpegData(
            withCompressionQuality: quality,
            actions: makeActions(size, region, background)
        )
    }
}

// MARK: - 计算&绘制
extension CALayer {
    /// 计算指定模式下`layer`在画布中的目标区域
    /// - Parameters:
    ///   - size: 画布尺寸
    ///   - mode: 适配模式
    /// - Returns: `layer`应铺满的区域（画布坐标系内）
    func fitRegion(in size: CGSize, mode: FitMode) -> CGRect {
        let layerSize = bounds.size
        switch mode {
        case .fill:
            return CGRect(origin: .zero, size: size)
        case .aspectFit, .aspectFill:
            guard layerSize.width > 0, layerSize.height > 0 else {
                return CGRect(origin: .zero, size: size)
            }
            let sx = size.width / layerSize.width
            let sy = size.height / layerSize.height
            let ratio = mode == .aspectFit ? min(sx, sy) : max(sx, sy)
            let fitted = CGSize(width: layerSize.width * ratio, height: layerSize.height * ratio)
            return CGRect(
                x: (size.width - fitted.width) / 2,
                y: (size.height - fitted.height) / 2,
                width: fitted.width,
                height: fitted.height
            )
        }
    }
    
    /// 核心绘制：把`layer`铺满`region`。
    /// 内部用`save/restore`包裹，**自包含、不污染传入的 context**，因此可安全用于共用同一个`context`连续绘制多个`layer`。
    /// 注意：**不负责背景**，如需底色请先调用`ctx.fill(_:size:)`。
    /// - Parameters:
    ///   - ctx: 目标绘制上下文
    ///   - region: `layer`铺满的目标区域
    func draw(in ctx: CGContext, region: CGRect) {
        let layerSize = bounds.size
        guard layerSize.width > 0, layerSize.height > 0,
              region.width > 0, region.height > 0
        else { return }
        
        ctx.saveGState()
        defer { ctx.restoreGState() }
        
        // 平移到区域原点，再按宽高分别拉伸铺满整个`region`（不保持比例）
        ctx.translateBy(x: region.minX, y: region.minY)
        ctx.scaleBy(x: region.width  / layerSize.width,
                    y: region.height / layerSize.height)
        
        // ⚠️`region`超出画布（size）的部分会被上下文自动裁剪掉，无需手动`clip`
        render(in: ctx)
    }
}

// MARK: - 私有方法
private extension CALayer {
    func makeFormat(_ scale: CGFloat?, _ background: UIColor?) -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        if let scale { format.scale = scale }
        format.opaque = (background != nil && background != .clear)
        return format
    }
    
    func makeActions(_ size: CGSize, _ region: CGRect, _ background: UIColor?) -> (UIGraphicsImageRendererContext) -> Void {
        return { context in
            let ctx = context.cgContext
            ctx.fill(background, size: size)
            self.draw(in: ctx, region: region)
        }
    }
}
