//
//  LayerImageRenderer.swift
//  Neves
//
//  Created by aa on 2026/8/7.
//

import UIKit

/// 高频渲染器：复用同一个`UIGraphicsImageRenderer`实例（即复用其底层 context 配置），
/// 适合【固定画布尺寸 + 同线程 + 高频】的场景（如逐帧视频），用多个`layer`反复生成`image`。
///
/// 说明：
/// - 复用的是`context`配置，每次`image(of:)`仍返回各自独立的`UIImage`（像素内存不共享，这是必须的）。
/// - 每次`image(of:)`系统都会给一块干净画布，**无需手动 clear**；绘制中的坐标变换由`CALayer.draw`内部`save/restore`复位，**无需外部恢复状态**。
/// - ⚠️ 非线程安全:创建后请始终在同一线程调用。
final class LayerImageRenderer {
    typealias LayerWithMode = (layer: CALayer, mode: CALayer.FitMode)
    typealias LayerWithRegion = (layer: CALayer, region: CGRect)
    
    let size: CGSize
    private let background: UIColor?
    private let renderer: UIGraphicsImageRenderer
    
    /// - Parameters:
    ///   - size: 固定的画布尺寸
    ///   - scale: 像素倍率。`nil` = 跟随屏幕（高清）；`1` = 严格按点=像素导出
    ///   - background: 画布底色，`nil`为透明
    init(size: CGSize, scale: CGFloat? = nil, background: UIColor? = nil) {
        let format = UIGraphicsImageRendererFormat()
        if let scale { format.scale = scale }
        format.opaque = (background != nil && background != .clear)
        self.size = size
        self.background = background
        self.renderer = UIGraphicsImageRenderer(size: size, format: format)
    }
    
    /// 按指定模式渲染一个`layer`为`image`（复用同一`renderer`）
    func image(of layer: CALayer, mode: CALayer.FitMode = .aspectFit) -> UIImage {
        image(of: layer, region: layer.fitRegion(in: size, mode: mode))
    }
    
    /// 按自定义区域渲染一个`layer`为`image`（复用同一`renderer`）
    func image(of layer: CALayer, region: CGRect) -> UIImage {
        renderer.image { context in
            let ctx = context.cgContext
            ctx.fill(background, size: size)
            layer.draw(in: ctx, region: region)
        }
    }
    
    /// 按指定模式渲染多个`layer`为`image`（复用同一`renderer`）
    func image(of layers: [LayerWithMode]) -> UIImage {
        image(of: layers.map { layer, mode in
            (layer, layer.fitRegion(in: size, mode: mode))
        })
    }
    
    /// 按自定义区域渲染多个`layer`为`image`（复用同一`renderer`）
    /// 多个`layer`按数组顺序自下而上叠加（先画的在底层）。
    func image(of layers: [LayerWithRegion]) -> UIImage {
        renderer.image { context in
            let ctx = context.cgContext
            // 背景只铺一次，避免每个`layer`各自铺背景把先画的`layer`覆盖掉
            ctx.fill(background, size: size)
            layers.forEach {
                $0.layer.draw(in: ctx, region: $0.region)
            }
        }
    }
}

/**
 * 自定义 CGBitmapContext 会不会比 UIGraphicsImageRenderer 更好？
 * 这个问题的答案分两层：单纯`自定义 CGBitmapContext`vs`UIGraphicsImageRenderer`，差别不大；但在你这条管线里，`自定义 context`能带来的真正价值，是让你彻底跳过中间那张 UIImage —— 那才是大头。
 *
 * 两者本身的对比：
 * 维度             |        `UIGraphicsImageRenderer`           |       `自定义 CGContext(CGContext(data:...))`
 * 易用性         |  高,闭包封装、自动管理                                    |  低,要手动管 bitmap 内存、bytesPerRow、色彩空间、字节序
 * 复用性         |  实例可复用,但每次 .image{} 返回新 UIImage   |  完全自己掌控,可反复画进同一块 buffer
 * 输出             |  直接给你 UIImage                                            |  给你 CGImage / 裸像素,要 UIImage 还得自己包
 * 坐标系         |  已自动翻转成 UIKit 习惯(左上原点)                  |  默认 Core Graphics 原点在左下,要自己翻转
 * 正确性风险  |  低,系统保证                                                      |  高,参数配错就是花屏/崩溃
 * 纯性能         |  已经很好(底层也是 IOSurface/位图)                 |  理论略优,但日常差距可忽略
 *
 * ✅ 结论：如果只是`layer → UIImage`，`UIGraphicsImageRenderer`更好 —— 性能相近，但安全、简洁。为了那点微乎其微的差距去手搓`bitmap context`，不划算。
 */
