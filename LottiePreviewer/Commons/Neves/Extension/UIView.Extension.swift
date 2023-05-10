//
//  UIView.Extension.swift
//  Neves_Example
//
//  Created by 周健平 on 2020/10/10.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

extension UIView {
    
    var x: CGFloat {
        set { frame.origin.x = newValue }
        get { frame.origin.x }
    }
    var midX: CGFloat {
        set { frame.origin.x += (newValue - frame.midX) }
        get { frame.midX }
    }
    var maxX: CGFloat {
        set { frame.origin.x += (newValue - frame.maxX) }
        get { frame.maxX }
    }
    
    var y: CGFloat {
        set { frame.origin.y = newValue }
        get { frame.origin.y }
    }
    var midY: CGFloat {
        set { frame.origin.y += (newValue - frame.midY) }
        get { frame.midY }
    }
    var maxY: CGFloat {
        set { frame.origin.y += (newValue - frame.maxY) }
        get { frame.maxY }
    }
    
    var width: CGFloat {
        set { frame.size.width = newValue }
        get { frame.width }
    }
    
    var height: CGFloat {
        set { frame.size.height = newValue }
        get { frame.height }
    }
    
    var centerX: CGFloat {
        set { center.x = newValue }
        get { center.x }
    }
    var centerY: CGFloat {
        set { center.y = newValue }
        get { center.y }
    }
    
    var origin: CGPoint {
        set { frame.origin = newValue }
        get { frame.origin }
    }
    
    var size: CGSize {
        set { frame.size = newValue }
        get { frame.size }
    }
    
    var right: CGFloat {
        set {
            guard let superview = self.superview else { return }
            x = superview.width - width - newValue
        }
        get {
            guard let superview = self.superview else { return 0 }
            return superview.width - maxX
        }
    }
    
    var bottom: CGFloat {
        set {
            guard let superview = self.superview else { return }
            y = superview.height - height - newValue
        }
        get {
            guard let superview = self.superview else { return 0 }
            return superview.height - maxY
        }
    }
    
    var radian: CGFloat { CGFloat(atan2(Double(transform.b), Double(transform.a))) }
    
    var angle: CGFloat { (radian * 180.0) / CGFloat.pi }
    
    var scaleX: CGFloat { CGFloat(sqrt(pow(transform.a, 2) + pow(transform.c, 2))) }
    
    var scaleY: CGFloat { CGFloat(sqrt(pow(transform.b, 2) + pow(transform.d, 2))) }
    
    var scale: CGPoint { .init(x: scaleX, y: scaleY) }
    
    var translationX: CGFloat { transform.tx }
    
    var translationY: CGFloat { transform.ty }
    
    var translation: CGPoint { .init(x: translationX, y: translationY) }
    
    static func loadFromNib(_ nibName: String? = nil, bundle: Bundle = Bundle.main) -> Self {
        let nibNamed = nibName ?? "\(self)"
        return bundle.loadNibNamed(nibNamed, owner: nil, options: nil)?.first as! Self
    }
    
    static func nib(_ nibName: String? = nil, bundle: Bundle = Bundle.main) -> UINib? {
        let nibNamed = nibName ?? "\(self)"
        return UINib(nibName: nibNamed, bundle: bundle)
    }
}

extension UIView: JPCompatible {}
extension JP where Base: UIView {
    var topVC: UIViewController? { base.window?.jp.topVC }
    var topNavCtr: UINavigationController? { topVC?.navigationController }
}
