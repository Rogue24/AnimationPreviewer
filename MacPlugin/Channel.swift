//
//  Channel.swift
//  MacPlugin
//
//  Created by 周健平 on 2023/5/8.
//

import Foundation

@objc(Channel)
protocol Channel: NSObjectProtocol {
    init()
    
    /// 初始化
    func setup()
    
    /// 保存图片到下载文件夹
    func saveImage(_ imageData: Data, completion: @escaping (_ isSuccess: Bool) -> ())
    
    /// 保存视频到下载文件夹
    func saveVideo(_ videoPath: NSString, completion: @escaping (_ isSuccess: Bool) -> ())
    
    func pickLottie(completion: @escaping (_ data: Data?) -> ())
    
    func pickSVGA(completion: @escaping (_ data: Data?) -> ())
    
    func pickGIF(completion: @escaping (_ data: Data?) -> ())
    
    func pickImage(completion: @escaping (_ data: Data?) -> ())
}
