//
//  UIView.Extension.swift
//  Neves_Example
//
//  Created by 周健平 on 2020/10/10.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

extension UIView {
    var x: CGFloat {
        set { frame.origin.x = newValue }
        get { frame.origin.x }
    }
    var midX: CGFloat {
        set { frame.origin.x += (newValue - frame.midX) }
        get { frame.midX }
    }
    var maxX: CGFloat {
        set { frame.origin.x += (newValue - frame.maxX) }
        get { frame.maxX }
    }
    
    var y: CGFloat {
        set { frame.origin.y = newValue }
        get { frame.origin.y }
    }
    var midY: CGFloat {
        set { frame.origin.y += (newValue - frame.midY) }
        get { frame.midY }
    }
    var maxY: CGFloat {
        set { frame.origin.y += (newValue - frame.maxY) }
        get { frame.maxY }
    }
    
    var width: CGFloat {
        set { frame.size.width = newValue }
        get { frame.width }
    }
    
    var height: CGFloat {
        set { frame.size.height = newValue }
        get { frame.height }
    }
    
    var centerX: CGFloat {
        set { center.x = newValue }
        get { center.x }
    }
    var centerY: CGFloat {
        set { center.y = newValue }
        get { center.y }
    }
    
    var origin: CGPoint {
        set { frame.origin = newValue }
        get { frame.origin }
    }
    
    var size: CGSize {
        set { frame.size = newValue }
        get { frame.size }
    }
    
    var right: CGFloat {
        set {
            guard let superview = self.superview else { return }
            x = superview.width - width - newValue
        }
        get {
            guard let superview = self.superview else { return 0 }
            return superview.width - maxX
        }
    }
    
    var bottom: CGFloat {
        set {
            guard let superview = self.superview else { return }
            y = superview.height - height - newValue
        }
        get {
            guard let superview = self.superview else { return 0 }
            return superview.height - maxY
        }
    }
    
    var radian: CGFloat { CGFloat(atan2(Double(transform.b), Double(transform.a))) }
    
    var angle: CGFloat { (radian * 180.0) / CGFloat.pi }
    
    var scaleX: CGFloat { CGFloat(sqrt(pow(transform.a, 2) + pow(transform.c, 2))) }
    
    var scaleY: CGFloat { CGFloat(sqrt(pow(transform.b, 2) + pow(transform.d, 2))) }
    
    var scale: CGPoint { .init(x: scaleX, y: scaleY) }
    
    var translationX: CGFloat { transform.tx }
    
    var translationY: CGFloat { transform.ty }
    
    var translation: CGPoint { .init(x: translationX, y: translationY) }
    
    static func loadFromNib(_ nibName: String? = nil, bundle: Bundle = Bundle.main) -> Self {
        let nibNamed = nibName ?? "\(self)"
        return bundle.loadNibNamed(nibNamed, owner: nil, options: nil)?.first as! Self
    }
    
    static func nib(_ nibName: String? = nil, bundle: Bundle = Bundle.main) -> UINib? {
        let nibNamed = nibName ?? "\(self)"
        return UINib(nibName: nibNamed, bundle: bundle)
    }
}

extension UIView: JPCompatible {}
extension JP where Base: UIView {
    var topVC: UIViewController? { base.window?.jp.topVC }
    var topNavCtr: UINavigationController? { topVC?.navigationController }
    
    func addFade(duration: TimeInterval = 0.12) {
        guard duration > 0 else { return }
        let transition = CATransition()
        transition.type = .fade
        transition.duration = duration
        base.layer.add(transition, forKey: "jp_fade")
    }
}

// MARK: - 👉🏻 UIImage
extension UIView {
    /// `view`缩放适配画布的模式
    enum FitMode {
        case aspectFit   // 等比缩放，完整显示，可能留白
        case aspectFill  // 等比缩放，填满画布，超出裁剪
        case fill        // 拉伸填满，不保持比例（可能变形）
    }
    
    /// 按指定模式将`view`绘制到整个画布，生成`image`
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸，任意比例都能自动适配
    ///   - mode: 适配模式，默认`aspectFit`
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func image(size: CGSize,
               mode: FitMode = .aspectFit,
               scale: CGFloat? = nil,
               background: UIColor? = nil,
               afterScreenUpdates: Bool = true) -> UIImage {
        image(size: size, region: fitRegion(in: size, mode: mode), scale: scale, background: background, afterScreenUpdates: afterScreenUpdates)
    }
    
    /// 按`view`自身尺寸（`bounds`）原样生成`image`（内容 1:1，不缩放、不留白）
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func image(scale: CGFloat? = nil,
               background: UIColor? = nil,
               afterScreenUpdates: Bool = true) -> UIImage {
        image(size: bounds.size, region: CGRect(origin: .zero, size: bounds.size), scale: scale, background: background, afterScreenUpdates: afterScreenUpdates)
    }
    
    /// 将`view`拉伸铺满画布中的指定区域（不保持比例），超出画布的部分自动裁剪，生成`image`
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸
    ///   - region: 目标区域（画布坐标系内，位置和大小均可自由指定）
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func image(size: CGSize,
               region: CGRect,
               scale: CGFloat? = nil,
               background: UIColor? = nil,
               afterScreenUpdates: Bool = true) -> UIImage {
        UIGraphicsImageRenderer(
            size: size,
            format: makeFormat(scale, background)
        ).image(
            actions: makeActions(size, region, background, afterScreenUpdates)
        )
    }
}

// MARK: - 👉🏻 PNG/JPEG Data
extension UIView {
    /// 按指定模式将`view`绘制到整个画布，生成`PNG data`（无损，支持透明）
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸，任意比例都能自动适配
    ///   - mode: 适配模式，默认`aspectFit`
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func pngData(size: CGSize,
                 mode: FitMode = .aspectFit,
                 scale: CGFloat? = nil,
                 background: UIColor? = nil,
                 afterScreenUpdates: Bool = true) -> Data {
        pngData(size: size, region: fitRegion(in: size, mode: mode), scale: scale, background: background, afterScreenUpdates: afterScreenUpdates)
    }
    
    /// 按`view`自身尺寸（`bounds`）原样生成`PNG data`（内容 1:1，不缩放、不留白）
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func pngData(scale: CGFloat? = nil,
                 background: UIColor? = nil,
                 afterScreenUpdates: Bool = true) -> Data {
        pngData(size: bounds.size, region: CGRect(origin: .zero, size: bounds.size), scale: scale, background: background, afterScreenUpdates: afterScreenUpdates)
    }
    
    /// 将`view`拉伸铺满画布中的指定区域（不保持比例），超出画布的部分自动裁剪，生成`PNG data`（无损，支持透明）
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸
    ///   - region: 目标区域（画布坐标系内，位置和大小均可自由指定）
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func pngData(size: CGSize,
                 region: CGRect,
                 scale: CGFloat? = nil,
                 background: UIColor? = nil,
                 afterScreenUpdates: Bool = true) -> Data {
        UIGraphicsImageRenderer(
            size: size,
            format: makeFormat(scale, background)
        ).pngData(
            actions: makeActions(size, region, background, afterScreenUpdates)
        )
    }
    
    /// 按指定模式将`view`绘制到整个画布，生成`JPEG data`（有损，**不支持透明**）
    /// - Note: JPEG 无 alpha 通道，未铺背景（`background`为`nil/.clear`）时透明区域会被填成黑色，需要透明请改用`pngData`
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸，任意比例都能自动适配
    ///   - mode: 适配模式，默认`aspectFit`
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - quality: JPEG 压缩质量，`0`（最小体积） ~ `1`（最高质量），默认`0.9`
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func jpegData(size: CGSize,
                  mode: FitMode = .aspectFit,
                  scale: CGFloat? = nil,
                  background: UIColor? = nil,
                  quality: CGFloat = 0.9,
                  afterScreenUpdates: Bool = true) -> Data {
        jpegData(size: size, region: fitRegion(in: size, mode: mode), scale: scale, background: background, quality: quality, afterScreenUpdates: afterScreenUpdates)
    }
    
    /// 按`view`自身尺寸（`bounds`）原样生成`JPEG data`（内容 1:1，不缩放、不留白）
    /// - Note: JPEG 无 alpha 通道，未铺背景（`background`为`nil/.clear`）时透明区域会被填成黑色，需要透明请改用`pngData`
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - quality: JPEG 压缩质量，`0`（最小体积） ~ `1`（最高质量），默认`0.9`
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func jpegData(scale: CGFloat? = nil,
                  background: UIColor? = nil,
                  quality: CGFloat = 0.9,
                  afterScreenUpdates: Bool = true) -> Data {
        jpegData(size: bounds.size, region: CGRect(origin: .zero, size: bounds.size), scale: scale, background: background, quality: quality, afterScreenUpdates: afterScreenUpdates)
    }
    
    /// 将`view`拉伸铺满画布中的指定区域（不保持比例），超出画布的部分自动裁剪，生成`JPEG data`（有损，**不支持透明**）
    /// - Note: JPEG 无 alpha 通道，未铺背景（`background`为`nil/.clear`）时透明区域会被填成黑色，需要透明请改用`pngData`
    /// - Important: 必须在主线程调用；视图需在窗口上，离屏可能截到空白
    /// - Parameters:
    ///   - size: 画布（最终图片）尺寸
    ///   - region: 目标区域（画布坐标系内，位置和大小均可自由指定）
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    ///   - quality: JPEG 压缩质量，`0`（最小体积） ~ `1`（最高质量），默认`0.9`
    ///   - afterScreenUpdates: 是否等视图刷新后再截，默认`true`（所见即所得，稍慢）
    func jpegData(size: CGSize,
                  region: CGRect,
                  scale: CGFloat? = nil,
                  background: UIColor? = nil,
                  quality: CGFloat = 0.9,
                  afterScreenUpdates: Bool = true) -> Data {
        UIGraphicsImageRenderer(
            size: size,
            format: makeFormat(scale, background)
        ).jpegData(
            withCompressionQuality: quality,
            actions: makeActions(size, region, background, afterScreenUpdates)
        )
    }
}

// MARK: - 计算&绘制
extension UIView {
    /// 计算指定模式下`view`在画布中的目标区域
    /// - Parameters:
    ///   - size: 画布尺寸
    ///   - mode: 适配模式
    /// - Returns: `view`应铺满的区域（画布坐标系内）
    func fitRegion(in size: CGSize, mode: FitMode) -> CGRect {
        let viewSize = bounds.size
        switch mode {
        case .fill:
            return CGRect(origin: .zero, size: size)
        case .aspectFit, .aspectFill:
            guard viewSize.width > 0, viewSize.height > 0 else {
                return CGRect(origin: .zero, size: size)
            }
            let sx = size.width / viewSize.width
            let sy = size.height / viewSize.height
            let ratio = mode == .aspectFit ? min(sx, sy) : max(sx, sy)
            let fitted = CGSize(width: viewSize.width * ratio, height: viewSize.height * ratio)
            return CGRect(
                x: (size.width - fitted.width) / 2,
                y: (size.height - fitted.height) / 2,
                width: fitted.width,
                height: fitted.height
            )
        }
    }
    
    /// 核心绘制：把`view`缩放铺满`region`（宽高比不一致会变形），超出画布部分自动裁剪。
    /// 缩放靠`region`尺寸而非 CTM（`drawHierarchy`对 CTM 的`scale`支持不稳定）；绘制到当前线程的图形上下文，故不收`context`参数，背景由外层先铺好。
    /// - Important: 必须在主线程调用；整条调用链都不可切换线程，否则会得到空白/黑图。
    func draw(in region: CGRect, afterScreenUpdates: Bool) {
        let viewSize = bounds.size
        guard viewSize.width > 0, viewSize.height > 0,
              region.width > 0, region.height > 0
        else { return }
        
        // 直接把目标尺寸烘进`region`交给`drawHierarchy`，缩放才可靠生效；
        // 同时能正确截取`UIVisualEffectView`模糊等 UIKit 特效
        drawHierarchy(in: region, afterScreenUpdates: afterScreenUpdates)
    }
}

// MARK: - 私有方法
private extension UIView {
    func makeFormat(_ scale: CGFloat?, _ background: UIColor?) -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        if let scale { format.scale = scale }
        format.opaque = (background != nil && background != .clear)
        return format
    }
    
    func makeActions(_ size: CGSize, _ region: CGRect, _ background: UIColor?, _ afterScreenUpdates: Bool) -> (UIGraphicsImageRendererContext) -> Void {
        return { context in
            let ctx = context.cgContext
            ctx.fill(background, size: size)
            self.draw(in: region, afterScreenUpdates: afterScreenUpdates)
        }
    }
}
