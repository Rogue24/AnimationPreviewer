//
//  SVGAParsePlayer+.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import UIKit
import CryptoKit

extension SVGAVideoEntity {
    var duration: TimeInterval {
        guard frames > 0, fps > 0 else { return 0 }
        return TimeInterval(frames) / TimeInterval(fps)
    }
}

extension String {
    var md5 : String {
        let data = Data(self.utf8)
        let hashed = Insecure.MD5.hash(data: data)
        return hashed.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension NSObject {
    var memoryAddress: String {
        let address = unsafeBitCast(self, to: Int.self)
        return String(format: "%p", address)
    }
}
