//
//  Literal.Extension.swift
//  Neves_Example
//
//  Created by 周健平 on 2020/10/18.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

/*
    struct Point {
        var x = 0.0, y = 0.0
    }
    extension Point : ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
        init(sss: Double) {
            self.y = sss
        }
        init(arrayLiteral elements: Double...) {
            guard elements.count > 0 else { return }
            self.x = elements[0]
            guard elements.count > 1 else { return }
            self.y = elements[1]
        }
        init(dictionaryLiteral elements: (String, Double)...) {
            for (k, v) in elements {
                if k == "x" {
                    self.x = v
                } else if k == "y" {
                    self.y = v
                }
            }
        }
    }
    var p: Point = [10.5, 20.5]
    p = ["x" : 11, "y" : 22]

    class Student : ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral, CustomStringConvertible {
        var name: String = ""
        var score: Double = 0
        required init(floatLiteral value: Double) { self.score = value }
        required init(integerLiteral value: Int) { self.score = Double(value) }
        required init(stringLiteral value: String) { self.name = value }
        required init(unicodeScalarLiteral value: String) { self.name = value }
        required init(extendedGraphemeClusterLiteral value: String) { self.name = value } var description: String { "name=\(name),score=\(score)" }
    }
    var stu: Student = 90
 */

extension Int: ExpressibleByBooleanLiteral, ExpressibleByStringLiteral {
    public init(booleanLiteral value: Bool) { self = value ? 1 : 0 }
    public init(stringLiteral value: String) { self = Int(Double(stringLiteral: value)) }
    public init(unicodeScalarLiteral value: String) { self = Int(Double(stringLiteral: value)) }
    public init(extendedGraphemeClusterLiteral value: String) { self = Int(Double(stringLiteral: value)) }
}

extension Float: ExpressibleByBooleanLiteral, ExpressibleByStringLiteral {
    public init(booleanLiteral value: Bool) { self = value ? 1 : 0 }
    public init(stringLiteral value: String) { self = Float(value) ?? 0 }
    public init(unicodeScalarLiteral value: String) { self = Float(value) ?? 0 }
    public init(extendedGraphemeClusterLiteral value: String) { self = Float(value) ?? 0 }
}

extension Double: ExpressibleByBooleanLiteral, ExpressibleByStringLiteral {
    public init(booleanLiteral value: Bool) { self = value ? 1 : 0 }
    public init(stringLiteral value: String) { self = Double(value) ?? 0 }
    public init(unicodeScalarLiteral value: String) { self = Double(value) ?? 0 }
    public init(extendedGraphemeClusterLiteral value: String) { self = Double(value) ?? 0 }
}

extension Bool: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public init(integerLiteral value: Int) { self = value > 0 }
    public init(floatLiteral value: Double) { self = value > 0 }
}

extension CGPoint: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: CGFloat...) {
        if elements.count == 2 {
            self = .init(x: elements[0], y: elements[1])
        } else {
            self = .zero
        }
    }
}

extension CGSize: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: CGFloat...) {
        if elements.count == 2 {
            self = .init(width: elements[0], height: elements[1])
        } else {
            self = .zero
        }
    }
}

extension CGRect: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: CGFloat...) {
        if elements.count == 4 {
            self = .init(x: elements[0], y: elements[1], width: elements[2], height: elements[3])
        } else {
            self = .zero
        }
    }
}
