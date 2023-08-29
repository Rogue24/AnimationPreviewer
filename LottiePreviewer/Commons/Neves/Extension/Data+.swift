//
//  Data+.swift
//  LottiePreviewer
//
//  Created by aa on 2023/8/24.
//

let zipMagicNumber: [UInt8] = [0x50, 0x4B, 0x03, 0x04] // "PK\x03\x04"

extension Data: JPCompatible {}
extension JP where Base == Data {
    var isZip: Bool {
        guard base.count >= zipMagicNumber.count else {
            return false
        }
        let magicNumberBytes = base.prefix(zipMagicNumber.count)
        return magicNumberBytes.elementsEqual(zipMagicNumber)
    }
}
