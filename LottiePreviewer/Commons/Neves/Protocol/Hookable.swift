//
//  Hookable.swift
//  Neves
//
//  Created by aa on 2023/1/17.
//

protocol Hookable: NSObject {}
extension Hookable {
    static func swizzlingInstanceMethods(_ originalSelector: Selector, _ swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
