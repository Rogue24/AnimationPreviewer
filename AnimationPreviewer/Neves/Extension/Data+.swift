//
//  Data+.swift
//  AnimationPreviewer
//
//  Created by aa on 2023/8/24.
//

import Foundation

private let zipMagicNumber: [UInt8] = [0x50, 0x4B, 0x03, 0x04] // "PK\x03\x04"
private let gifIdentifier = Data([0x47, 0x49, 0x46])

extension Data: JPCompatible {}
extension JP where Base == Data {
    var isZip: Bool {
        guard base.count >= zipMagicNumber.count else {
            return false
        }
        let magicNumberBytes = base.prefix(zipMagicNumber.count)
        return magicNumberBytes.elementsEqual(zipMagicNumber)
    }
    
    var isGIF: Bool {
        guard base.count >= gifIdentifier.count else {
            return false
        }
        
        let prefix = base.prefix(gifIdentifier.count)
        return prefix.elementsEqual(gifIdentifier)
    }
    
    var isJSON: Bool {
        do {
            _ = try JSONSerialization.jsonObject(with: base, options: [])
            return true
        } catch {
            return false
        }
    }
}
