//
//  AnimationData.swift
//  AnimationPreviewer
//
//  Created by aa on 2023/8/22.
//

import Foundation
import UniformTypeIdentifiers

class AnimationData: NSObject, NSItemProviderReading {
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        return try Self.init(itemProviderData: data, typeIdentifier: typeIdentifier)
    }
    
    static var readableTypeIdentifiersForItemProvider: [String] {
        return [UTType.zip.identifier, UTType.directory.identifier, UTType.data.identifier]
    }
    
    let rawData: Data
    init(rawData: Data) {
        self.rawData = rawData
    }
    
    required convenience init(itemProviderData data: Data, typeIdentifier: String) throws {
        guard let data = NSData(data: data) as Data? else {
            throw NSError(domain: "AnimationData", code: -1, userInfo: [NSLocalizedDescriptionKey: "数据错误"])
        }
        self.init(rawData: data)
    }
}
