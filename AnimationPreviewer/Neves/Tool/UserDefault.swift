//
//  UserDefault.swift
//  Neves
//
//  Created by aa on 2022/4/21.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation

@propertyWrapper
struct UserDefault<T> {
    let key: UserDefaults.Key
    let id: Int?
    let suiteName: String?
    let defaultValue: T
    
    private var userDefaults: UserDefaults {
        if let suiteName, let uds = UserDefaults(suiteName: suiteName) {
            return uds
        }
        return UserDefaults.standard
    }
    
    var keyValue: String {
        if let id {
            return key.rawValue + "_\(id)"
        }
        return key.rawValue
    }
    
    var wrappedValue: T {
        get { userDefaults.object(forKey: keyValue) as? T ?? defaultValue }
        set {
            userDefaults.set(newValue, forKey: keyValue)
            userDefaults.synchronize()
        }
    }
    
    /// 该属性能让外部可以用`$外部属性名`的方式访问该属性值
    var projectedValue: T? {
        userDefaults.object(forKey: keyValue) as? T
    }
    
    init(wrappedValue: T, _ key: UserDefaults.Key, id: Int? = nil, suiteName: String? = nil) {
        self.key = key
        self.id = id
        self.suiteName = suiteName
        self.defaultValue = wrappedValue
    }
}


