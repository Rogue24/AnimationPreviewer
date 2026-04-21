//
//  UserDefault+.swift
//  AnimationPreviewer
//
//  Created by aa on 2023/8/30.
//

import Foundation

extension UserDefaults {
    /// 在这里注册`Key`
    enum Key: String, CaseIterable {
        case animationType
        case isSVGAMute
        case bgImageType
    }
}

extension UserDefaults: JPCompatible {}
extension JP where Base: UserDefaults {
    private func keyValue(_ key: UserDefaults.Key, id: Int?) -> String {
        if let id {
            return key.rawValue + "_\(id)"
        }
        return key.rawValue
    }
    
    private func keyValue(_ defaultName: String, id: Int?) -> String {
        if let id {
            return defaultName + "_\(id)"
        }
        return defaultName
    }
    
    
    func object(forKey key: UserDefaults.Key, id: Int? = nil) -> Any? {
        base.object(forKey: keyValue(key, id: id))
    }
    
    func object(forKey defaultName: String, id: Int? = nil) -> Any? {
        base.object(forKey: keyValue(defaultName, id: id))
    }

    
    func set(_ value: Any?, forKey key: UserDefaults.Key, id: Int? = nil) {
        base.set(value, forKey: keyValue(key, id: id))
    }
    
    func set(_ value: Any?, forKey defaultName: String, id: Int? = nil) {
        base.set(value, forKey: keyValue(defaultName, id: id))
    }


    func removeObject(forKey key: UserDefaults.Key, id: Int? = nil) {
        base.removeObject(forKey: keyValue(key, id: id))
    }
    
    func removeObject(forKey defaultName: String, id: Int? = nil) {
        base.removeObject(forKey: keyValue(defaultName, id: id))
    }


    func string(forKey key: UserDefaults.Key, id: Int? = nil) -> String? {
        base.string(forKey: keyValue(key, id: id))
    }
    
    func string(forKey defaultName: String, id: Int? = nil) -> String? {
        base.string(forKey: keyValue(defaultName, id: id))
    }


    func array(forKey key: UserDefaults.Key, id: Int? = nil) -> [Any]? {
        base.array(forKey: keyValue(key, id: id))
    }
    
    func array(forKey defaultName: String, id: Int? = nil) -> [Any]? {
        base.array(forKey: keyValue(defaultName, id: id))
    }

    
    func dictionary(forKey key: UserDefaults.Key, id: Int? = nil) -> [String : Any]? {
        base.dictionary(forKey: keyValue(key, id: id))
    }
    
    func dictionary(forKey defaultName: String, id: Int? = nil) -> [String : Any]? {
        base.dictionary(forKey: keyValue(defaultName, id: id))
    }

    
    func data(forKey key: UserDefaults.Key, id: Int? = nil) -> Data? {
        base.data(forKey: keyValue(key, id: id))
    }
    
    func data(forKey defaultName: String, id: Int? = nil) -> Data? {
        base.data(forKey: keyValue(defaultName, id: id))
    }

    
    func stringArray(forKey key: UserDefaults.Key, id: Int? = nil) -> [String]? {
        base.stringArray(forKey: keyValue(key, id: id))
    }
    
    func stringArray(forKey defaultName: String, id: Int? = nil) -> [String]? {
        base.stringArray(forKey: keyValue(defaultName, id: id))
    }

    
    func integer(forKey key: UserDefaults.Key, id: Int? = nil) -> Int {
        base.integer(forKey: keyValue(key, id: id))
    }
    
    func integer(forKey defaultName: String, id: Int? = nil) -> Int {
        base.integer(forKey: keyValue(defaultName, id: id))
    }

    
    func float(forKey key: UserDefaults.Key, id: Int? = nil) -> Float {
        base.float(forKey: keyValue(key, id: id))
    }
    
    func float(forKey defaultName: String, id: Int? = nil) -> Float {
        base.float(forKey: keyValue(defaultName, id: id))
    }

    
    func double(forKey key: UserDefaults.Key, id: Int? = nil) -> Double {
        base.double(forKey: keyValue(key, id: id))
    }
    
    func double(forKey defaultName: String, id: Int? = nil) -> Double {
        base.double(forKey: keyValue(defaultName, id: id))
    }

    
    func bool(forKey key: UserDefaults.Key, id: Int? = nil) -> Bool {
        base.bool(forKey: keyValue(key, id: id))
    }
    
    func bool(forKey defaultName: String, id: Int? = nil) -> Bool {
        base.bool(forKey: keyValue(defaultName, id: id))
    }

    
    func url(forKey key: UserDefaults.Key, id: Int? = nil) -> URL? {
        base.url(forKey: keyValue(key, id: id))
    }
    
    func url(forKey defaultName: String, id: Int? = nil) -> URL? {
        base.url(forKey: keyValue(defaultName, id: id))
    }

    
    func set(_ value: Int, forKey key: UserDefaults.Key, id: Int? = nil) {
        base.set(value, forKey: keyValue(key, id: id))
    }
    
    func set(_ value: Int, forKey defaultName: String, id: Int? = nil) {
        base.set(value, forKey: keyValue(defaultName, id: id))
    }

    
    func set(_ value: Float, forKey key: UserDefaults.Key, id: Int? = nil) {
        base.set(value, forKey: keyValue(key, id: id))
    }
    
    func set(_ value: Float, forKey defaultName: String, id: Int? = nil) {
        base.set(value, forKey: keyValue(defaultName, id: id))
    }

    
    func set(_ value: Double, forKey key: UserDefaults.Key, id: Int? = nil) {
        base.set(value, forKey: keyValue(key, id: id))
    }
    
    func set(_ value: Double, forKey defaultName: String, id: Int? = nil) {
        base.set(value, forKey: keyValue(defaultName, id: id))
    }

    
    func set(_ value: Bool, forKey key: UserDefaults.Key, id: Int? = nil) {
        base.set(value, forKey: keyValue(key, id: id))
    }
    
    func set(_ value: Bool, forKey defaultName: String, id: Int? = nil) {
        base.set(value, forKey: keyValue(defaultName, id: id))
    }

    
    func set(_ url: URL?, forKey key: UserDefaults.Key, id: Int? = nil) {
        base.set(url, forKey: keyValue(key, id: id))
    }
    
    func set(_ url: URL?, forKey defaultName: String, id: Int? = nil) {
        base.set(url, forKey: keyValue(defaultName, id: id))
    }
}
