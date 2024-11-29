//
//  Channel.swift
//  MacPlugin
//
//  Created by 周健平 on 2023/5/8.
//

import Foundation

@objc(Channel)
protocol Channel: NSObjectProtocol {
    
    /// 初始化
    init()
    
    /// 初始化配置
    func setup()
    
    /// 保存图片到下载文件夹
    func saveImage(_ imageData: Data, completion: @escaping (_ isSuccess: Bool) -> ())
    
    /// 保存视频到下载文件夹
    func saveVideo(_ videoPath: NSString, completion: @escaping (_ isSuccess: Bool) -> ())
    
    /// 打开Lottie文件夹或zip文件
    func pickLottie(completion: @escaping (_ data: Data?) -> ())
    
    /// 打开SVGA文件
    func pickSVGA(completion: @escaping (_ data: Data?) -> ())
    
    /// 打开GIF文件
    func pickGIF(completion: @escaping (_ data: Data?) -> ())
    
    /// 打开图片 ( jpeg, png )
    func pickImage(completion: @escaping (_ data: Data?) -> ())
    
}
