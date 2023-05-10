//
//  UserDefault.swift
//  Neves
//
//  Created by aa on 2022/4/21.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T?
    let projectedValue: T? // 该属性能让外部可以用 $外部属性名 的方式访问该属性值

    init(_ key: String, defaultValue: T? = nil, projectedValue: T? = nil) {
        self.key = key
        self.defaultValue = defaultValue
        self.projectedValue = projectedValue
    }
    
    var wrappedValue: T? {
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            UserDefaults.standard.synchronize()
        }
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
    }
}

