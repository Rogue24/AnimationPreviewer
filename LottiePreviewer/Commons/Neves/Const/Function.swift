//
//  Function.swift
//  Neves_Example
//
//  Created by aa on 2020/10/12.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation

let hhmmssSSFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "hh:mm:ss:SS"
    return formatter
}()

private let JPrintQueue = DispatchQueue(label: "JPrintQueue")
/// 自定义日志
func JPrint(_ msg: Any..., file: NSString = #file, line: Int = #line, fn: String = #function) {
#if DEBUG
    guard msg.count != 0, let lastItem = msg.last else { return }
    
    // 时间+文件位置+行数
    let date = hhmmssSSFormatter.string(from: Date()).utf8
//    let fileName = (file.lastPathComponent as NSString).deletingPathExtension
//    let prefix = "[\(date)] [\(fileName) \(fn)] [第\(line)行]:"
    let prefix = "jpjpjp [\(date)]:"
    
    // 获取【除最后一个】的其他部分
    let items = msg.count > 1 ? msg[..<(msg.count - 1)] : []
    
    JPrintQueue.sync {
        print(prefix, terminator: " ")
        items.forEach { print($0, terminator: " ") }
        print(lastItem)
    }
#endif
}

/// 互换两个值
func swapValues<T>(_ a: inout T, _ b: inout T) {
    (a, b) = (b, a)
}

/// 一半的差值
func HalfDiffValue(_ superValue: CGFloat, _ subValue: CGFloat) -> CGFloat {
    (superValue - subValue) * 0.5
}

/// 解码图片
func DecodeImage(_ cgImage: CGImage) -> CGImage? {
    let width = cgImage.width
    let height = cgImage.height
    
    var bitmapRawValue = CGBitmapInfo.byteOrder32Little.rawValue
    let alphaInfo = cgImage.alphaInfo
    if alphaInfo == .premultipliedLast ||
        alphaInfo == .premultipliedFirst ||
        alphaInfo == .last ||
        alphaInfo == .first {
        bitmapRawValue |= CGImageAlphaInfo.premultipliedFirst.rawValue
    } else {
        bitmapRawValue |= CGImageAlphaInfo.noneSkipFirst.rawValue
    }
    
    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: ColorSpace,
                                  bitmapInfo: bitmapRawValue) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    let decodeImg = context.makeImage()
    return decodeImg
}
