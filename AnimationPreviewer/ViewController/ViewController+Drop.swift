//
//  ViewController+Drop.swift
//  AnimationPreviewer
//
//  Created by 周健平 on 2023/5/10.
//

import UIKit
import UniformTypeIdentifiers

// MARK: - <UIDropInteractionDelegate>
extension ViewController: UIDropInteractionDelegate {
    
    // 确定传入的物体是否为`AnimationData`对象
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: AnimationData.self)
    }
    
    // 提取数据
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
//        let dropLocation = session.location(in: animView)
        let operation: UIDropOperation
        if session.canLoadObjects(ofClass: AnimationData.self) {
            operation = session.localDragSession == nil ? .copy : .move
        } else {
            operation = .cancel
        }
        return UIDropProposal(operation: operation)
    }
    
    // 加载数据
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: AnimationData.self) { [weak self] items in
            guard let self = self, let animData = items.first as? AnimationData else { return }
            self.replaceAnimation(with: animData.rawData)
        }
    }
    
    // 数据划出
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        
    }
    
}


