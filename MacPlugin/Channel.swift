//
//  Channel.swift
//  MacPlugin
//
//  Created by 周健平 on 2023/5/8.
//

import Foundation

@objc(Channel)
protocol Channel: NSObjectProtocol {
    typealias SaveCompletion = (_ isSuccess: Bool) -> Void
    typealias PickCompletion = (_ data: Data?, _ ext: String?) -> Void
    
    /// 初始化
    init()
    
    /// 初始化配置
    func setup()
    
    /// 保存图片到下载文件夹
    func saveImage(_ imageData: Data, completion: @escaping SaveCompletion)
    
    /// 保存视频到下载文件夹
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
