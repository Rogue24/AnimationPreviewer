//
//  DecodeImageProvider.swift
//  Neves
//
//  Created by aa on 2021/10/22.
//

class DecodeImageProvider: AnimationImageProvider {
    let images: [String: CGImage]
    let replacement: [String: CGImage]?
    
    init?(imageDirPath: String, imageReplacement: [String: CGImage]? = nil) {
        guard File.manager.fileExists(imageDirPath) else {
            JPrint("不存在图片文件夹！")
            return nil
        }
        
        guard let fileNames = try? FileManager.default.subpathsOfDirectory(atPath: imageDirPath) else {
            JPrint("不存在图片！")
            return nil
        }
        
        var images: [String: CGImage] = [:]
        for fileName in fileNames {
            let imagePath = imageDirPath + "/\(fileName)"
            guard let image = UIImage(contentsOfFile: imagePath),
                  let cgImg = image.cgImage else { return nil }
            images[fileName] = DecodeImage(cgImg) ?? cgImg
        }
        
        self.images = images
        self.replacement = imageReplacement
    }
    
    func imageForAsset(asset: ImageAsset) -> CGImage? {
        replacement.map { $0[asset.name] } ?? images[asset.name]
    }
}
