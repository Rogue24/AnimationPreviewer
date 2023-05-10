//
//  GradientView.swift
//  Neves_Example
//
//  Created by aa on 2020/10/14.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class GradientView: UIView {
    // MARK: - 重写的父类函数
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
}

// MARK: - Gradientable
extension GradientView: Gradientable {
    convenience init(frame: CGRect = .zero,
                     startPoint: CGPoint = .zero,
                     endPoint: CGPoint = .zero,
                     locations: [NSNumber]? = nil,
                     colors: [UIColor]? = nil) {
        self.init(frame: frame)
        
        self.startPoint(startPoint)
            .endPoint(endPoint)
            .locations(locations)
            .colors(colors)
    }
    
    public var gLayer: CAGradientLayer { layer as! CAGradientLayer }
}
