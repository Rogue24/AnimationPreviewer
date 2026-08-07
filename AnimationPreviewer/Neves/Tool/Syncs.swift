//
//  Syncs.swift
//  Neves
//
//  Created by aa on 2021/10/22.
//

import Foundation

struct Syncs {
    /// 返回主队列执行
    public static func main(_ task: @escaping Asyncs.BaseTask) {
        if Thread.isMainThread {
            task()
            return
        }
        
        DispatchQueue.main.sync(execute: task)
    }
}
