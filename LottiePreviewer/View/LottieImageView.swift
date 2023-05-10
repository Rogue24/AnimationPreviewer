//
//  LottieImageView.swift
//  LottiePreviewer
//
//  Created by 周健平 on 2023/5/9.
//

import UIKit
import SnapKit

class LottieImageView: UIView {
    private let animView = LottieAnimationView(animation: nil, imageProvider: nil)
    
    var isEnable: Bool {
        animView.animation != nil
    }
    
    var currentFrame: CGFloat {
        set { animView.currentFrame = newValue }
        get { animView.currentFrame }
    }
    
    init() {
        super.init(frame: .zero)
        
        animView.contentMode = .scaleAspectFit
        addSubview(animView)
        animView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        backgroundColor = .rgb(41, 43, 51, a: 0.35)
        layer.borderColor = UIColor(white: 1, alpha: 0.25).cgColor
        layer.borderWidth = 4
        layer.cornerRadius = 16
        layer.masksToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func replaceLottie(_ tuple: LottieTuple?) {
        animView.currentProgress = 0
        if let tuple = tuple {
            animView.animation = tuple.animation
            animView.imageProvider = tuple.provider
            animView.isHidden = false
        } else {
            animView.animation = nil
            animView.isHidden = true
        }
        
        animView.layoutIfNeeded()
        
        UIView.transition(with: animView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
    }
    
    func getCurrentImage(completion: @escaping (_ image: UIImage?) -> ()) {
        guard let animation = animView.animation else {
            completion(nil)
            return
        }
        let provider = animView.imageProvider
        
        let animationLayer = MainThreadAnimationLayer(animation: animation, imageProvider: provider, textProvider: DefaultTextProvider(), fontProvider: DefaultFontProvider(), logger: LottieLogger.shared)
        
        animationLayer.frame = animation.bounds
        animationLayer.renderScale = UIScreen.mainScale
        animationLayer.setNeedsDisplay()

        animationLayer.currentFrame = animView.currentFrame
        animationLayer.display()
        
        var newImage: UIImage?
        Asyncs.async {
            UIGraphicsBeginImageContextWithOptions(animation.bounds.size, false, 0)
            guard let ctx = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                return
            }
            
            animationLayer.render(in: ctx)
            
            newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        } mainTask: {
            completion(newImage)
        }
    }
}
