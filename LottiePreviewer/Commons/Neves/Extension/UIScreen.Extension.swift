//
//  UIScreen.Extension.swift
//  Neves_Example
//
//  Created by 周健平 on 2020/10/9.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

extension UIScreen {
    static var mainScale: CGFloat { main.scale }
    static var mainBounds: CGRect { main.bounds }
    static var mainSize: CGSize { main.bounds.size }
    static var mainWidth: CGFloat { main.bounds.width }
    static var mainHeight: CGFloat { main.bounds.height }
}
