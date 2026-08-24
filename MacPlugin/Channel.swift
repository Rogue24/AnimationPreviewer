//
//  Channel.swift
//  MacPlugin
//
//  Created by 周健平 on 2023/5/8.
//

import Foundation

@objc(Channel)
protocol Channel: NSObjectProtocol {
    /// 保存结果回调
    /// - isSuccess: 是否保存成功
    /// - isCancelled: 用户在保存面板点了「取消」（此时`isSuccess`为false，但不该提示错误）
    typealias SaveCompletion = (_ isSuccess: Bool, _ isCancelled: Bool) -> Void
    typealias PickCompletion = (_ data: Data?, _ ext: String?) -> Void
    
    /// 初始化
    init()
    
    /// 初始化配置
    func setup()
    
    /// 弹保存面板，由用户选择位置保存图片
    func saveImage(_ imageData: Data, completion: @escaping SaveCompletion)

    /// 弹保存面板，由用户选择位置保存视频
    func saveVideo(_ videoPath: NSString, completion: @escaping SaveCompletion)
    
    /// 打开Lottie文件夹或zip文件
    func pickLottie(completion: @escaping PickCompletion)
    
    /// 打开SVGA文件
    func pickSVGA(completion: @escaping PickCompletion)
    
    /// 打开GIF文件
    func pickGIF(completion: @escaping PickCompletion)
    
    /// 打开图片 ( jpeg, png )
    func pickImage(completion: @escaping PickCompletion)
}
