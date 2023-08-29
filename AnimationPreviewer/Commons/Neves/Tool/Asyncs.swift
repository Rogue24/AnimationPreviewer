//
//  Asyncs.swift
//  Neves_Example
//
//  Created by aa on 2020/10/15.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation

public typealias MyTask = () -> Void
public typealias DelayTask = (_ isCancelled: Bool) -> Void

struct Asyncs {
    /// 异步执行
    public static func async(_ task: @escaping MyTask) {
        _async(task)
    }
    
    /// 异步执行+主队列回调
    public static func async(_ task: @escaping MyTask, mainTask: @escaping MyTask) {
        _async(task, mainTask)
    }
    
    /// 返回主队列执行
    public static func main(_ task: @escaping MyTask) {
        DispatchQueue.main.async(execute: task)
    }
    
    /// 主队列延时执行
    @discardableResult
    public static func mainDelay(_ seconds: Double, _ task: @escaping MyTask) -> DispatchWorkItem {
        let item = DispatchWorkItem(block: task)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds, execute: item)
        return item
    }
    
    /// 异步延时执行
    @discardableResult
    public static func asyncDelay(_ seconds: Double, _ task: @escaping MyTask) -> DispatchWorkItem { _asyncDelay(seconds, task)
    }
    
    /// 异步延时执行+主队列回调（不管任务是否中途被取消，都会【主队列回调】）
    @discardableResult
    public static func asyncDelay(_ seconds: Double, _ task: @escaping MyTask, mainTask: @escaping MyTask) -> DispatchWorkItem {
        _asyncDelay(seconds, task, mainTask)
    }
    
    /// 异步延时执行+主队列回调（不管任务是否中途被取消都会【主队列回调】，带 isCancelled 参数）
    @discardableResult
    public static func asyncDelay(_ seconds: Double, _ task: @escaping MyTask, mainTask: @escaping DelayTask) -> DispatchWorkItem {
        let item = DispatchWorkItem(block: task)
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + seconds, execute: item)
        item.notify(queue: DispatchQueue.main, execute: { mainTask(item.isCancelled) })
        return item
    }
}

private extension Asyncs {
    private static func _async(_ task: @escaping MyTask, _ mainTask: MyTask? = nil) {
        let item = DispatchWorkItem(block: task)
        DispatchQueue.global().async(execute: item)
        if let mt = mainTask { item.notify(queue: DispatchQueue.main, execute: mt) }
    }
    
    private static func _asyncDelay(_ seconds: Double, _ task: @escaping MyTask, _ mainTask: MyTask? = nil) -> DispatchWorkItem {
        let item = DispatchWorkItem(block: task)
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + seconds, execute: item)
        if let mt = mainTask { item.notify(queue: DispatchQueue.main, execute: mt) }
        return item
    }
}
