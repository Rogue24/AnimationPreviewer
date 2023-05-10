//
//  Gradientable.swift
//  Neves_Example
//
//  Created by aa on 2020/10/14.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

protocol Gradientable: UIView {
    var gLayer: CAGradientLayer { get }
}

extension Gradientable {
    @discardableResult
    func startPoint(_ x: CGFloat, _ y: CGFloat) -> Self {
        gLayer.startPoint = .init(x: x, y: y)
        return self
    }
    @discardableResult
    func startPoint(_ sp: CGPoint) -> Self {
        gLayer.startPoint = sp
        return self
    }
    var startPoint: CGPoint {
        set { gLayer.startPoint = newValue }
        get { gLayer.startPoint }
    }
    
    @discardableResult
    func endPoint(_ x: CGFloat, _ y: CGFloat) -> Self {
        gLayer.endPoint = .init(x: x, y: y)
        return self
    }
    @discardableResult
    func endPoint(_ ep: CGPoint) -> Self {
        gLayer.endPoint = ep
        return self
    }
    var endPoint: CGPoint {
        set { gLayer.endPoint = newValue }
        get { gLayer.endPoint }
    }
    
    @discardableResult
    func locations(_ ls: CGFloat...) -> Self {
        gLayer.locations = Self.cgFloats2nsNumbers(ls)
        return self
    }
    @discardableResult
    func locations(_ ls: [CGFloat]?) -> Self {
        gLayer.locations = Self.cgFloats2nsNumbers(ls)
        return self
    }
    @discardableResult
    func locations(_ ls: [NSNumber]?) -> Self {
        gLayer.locations = ls
        return self
    }
    var locations: [NSNumber]? {
        set { gLayer.locations = newValue }
        get { gLayer.locations }
    }
    
    @discardableResult
    func colors(_ uiColors: UIColor...) -> Self {
        gLayer.colors = Self.uiColors2cgColors(uiColors)
        return self
    }
    @discardableResult
    func colors(_ uiColors: [UIColor]?) -> Self {
        gLayer.colors = Self.uiColors2cgColors(uiColors)
        return self
    }
    var colors: [UIColor]? {
        set { gLayer.colors = Self.uiColors2cgColors(newValue) }
        get { gLayer.colors?.map { UIColor(cgColor: $0 as! CGColor) } }
    }
    
    private static func cgFloats2nsNumbers(_ cgFloats: [CGFloat]?) -> [NSNumber]? {
        guard let cfs = cgFloats, cfs.count > 0 else { return nil }
        return cfs.map { NSNumber(value: Double($0)) }
    }
    
    private static func uiColors2cgColors(_ uiColors: [UIColor]?) -> [Any]? {
        guard let colors = uiColors, colors.count > 0 else { return nil }
        if colors.count == 1 {
            let cgColor = colors.first!.cgColor
            return [cgColor, cgColor]
        }
        return colors.map { $0.cgColor }
    }
}
