//
//  ViewController.Drop.swift
//  LottiePreviewer
//
//  Created by 周健平 on 2023/5/10.
//

import UIKit
import UniformTypeIdentifiers

// MARK: - <UIDropInteractionDelegate>
extension ViewController: UIDropInteractionDelegate {
    class ZipObject: NSObject, NSItemProviderReading {
        static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
            return try Self.init(itemProviderData: data, typeIdentifier: typeIdentifier)
        }
        
        static var readableTypeIdentifiersForItemProvider: [String] {
            return [UTType.zip.identifier]
        }
        
        let data: Data
        
        init(data: Data) {
            self.data = data
        }
        
        required convenience init(itemProviderData data: Data, typeIdentifier: String) throws {
            guard let data = NSData(data: data) as Data? else {
                throw NSError(domain: "myDomain", code: 1, userInfo: nil)
            }
            self.init(data: data)
        }
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        // 用来确定传入的物体是否是`ZipObject`对象
        return session.canLoadObjects(ofClass: ZipObject.self)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        // 提取数据
//        let dropLocation = session.location(in: animView)
        let operation: UIDropOperation
        if session.canLoadObjects(ofClass: ZipObject.self) {
            operation = session.localDragSession == nil ? .copy : .move
        } else {
            operation = .cancel
        }
        return UIDropProposal(operation: operation)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        // 加载数据
        session.loadObjects(ofClass: ZipObject.self) { [weak self] items in
            guard let self = self, let zipObject = items.first as? ZipObject else {
                return
            }
            
            JPProgressHUD.show()
            var kError: Error?
            Asyncs.async {
                do {
                    try LottieStore.loadZipData(zipObject.data)
                } catch {
                    kError = error
                }
            } mainTask: {
                if let error = kError {
                    JPProgressHUD.showError(withStatus: error.localizedDescription, userInteractionEnabled: true)
                    return
                }
                
                JPProgressHUD.dismiss()
                guard let lottiePath = LottieStore.lottieFilePath,
                      let animation = LottieAnimation.filepath("\(lottiePath)/data.json", animationCache: LRUAnimationCache.sharedCache)
                else { return }
                
                // animation 和 provider 是必须的
                let provider = FilepathImageProvider(filepath: lottiePath)
                self.replaceLottie((animation, provider))
            }
        }
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        // 数据划出
    }
}


