//
//  AnimationImageView.swift
//  AnimationPreviewer
//
//  Created by 周健平 on 2023/5/9.
//

import UIKit
import SnapKit

class AnimationImageView: UIView {
    enum GetImageResult {
        case success(image: UIImage)
        case failure(reason: String)
    }
    
    private(set) var store: AnimationStore?
    
    private let placeholderView = UIView()
    private let lottieView = LottieAnimationView(animation: nil, imageProvider: nil)
    private let svgaView = SVGAParsePlayer()
    
    var isEnable: Bool {
        store != nil
    }
    
    var currentFrame: CGFloat {
        set {
            if !lottieView.isHidden {
                lottieView.currentFrame = newValue
            } else if !svgaView.isHidden {
                svgaView.play(fromFrame: Int(newValue), isAutoPlay: false)
            }
        }
        get {
            if !lottieView.isHidden {
                return lottieView.currentFrame
            } else if !svgaView.isHidden {
                return CGFloat(svgaView.currFrame)
            }
            return 0
        }
    }
    
    init() {
        super.init(frame: .zero)
        
        lottieView.isHidden = true
        lottieView.contentMode = .scaleAspectFit
        addSubview(lottieView)
        lottieView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        svgaView.isHidden = true
        svgaView.contentMode = .scaleAspectFit
        addSubview(svgaView)
        svgaView.snp.makeConstraints { make in
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
}

extension AnimationImageView {
    func replaceAnimation(_ store: AnimationStore?) {
        self.store = store
        guard let store else {
            removeAnimation()
            return
        }
        
        switch store {
        case let .lottie(animation, provider):
            replaceLottie(animation, provider)
        case let .svga(entity):
            replaceSVGA(entity)
        }
    }
}

private extension AnimationImageView {
    func replaceLottie(_ animation: LottieAnimation, _ provider: FilepathImageProvider) {
        svgaView.stop(isClear: true)
        svgaView.isHidden = true
        
        lottieView.animation = animation
        lottieView.imageProvider = provider
        lottieView.isHidden = false
        
        updateLayout()
    }
    
    func replaceSVGA(_ entity: SVGAVideoEntity) {
        lottieView.stop()
        lottieView.animation = nil
        lottieView.isHidden = true
        
        svgaView.play(with: entity, fromFrame: 0, isAutoPlay: false)
        svgaView.isHidden = false
        
        updateLayout()
    }
}

private extension AnimationImageView {
    func removeAnimation() {
        lottieView.stop()
        lottieView.animation = nil
        lottieView.isHidden = true
        
        svgaView.stop(isClear: true)
        svgaView.isHidden = true
        
        updateLayout()
    }
    
    func updateLayout() {
        lottieView.layoutIfNeeded()
        svgaView.layoutIfNeeded()
        
        UIView.transition(with: lottieView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
        
        UIView.transition(with: svgaView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
    }
}

extension AnimationImageView {
    func getCurrentImage(completion: @escaping (_ result: GetImageResult) -> ()) {
        guard let store else {
            completion(.failure(reason: "没有对象"))
            return
        }
        
        let layer: CALayer
        let size: CGSize
        
        switch store {
        case let .lottie(animation, provider):
            let animationLayer = MainThreadAnimationLayer(animation: animation,
                                                          imageProvider: provider,
                                                          textProvider: DefaultTextProvider(),
                                                          fontProvider: DefaultFontProvider(),
                                                          logger: LottieLogger.shared)
    
            animationLayer.frame = animation.bounds
            animationLayer.renderScale = UIScreen.mainScale
            animationLayer.setNeedsDisplay()
    
            animationLayer.currentFrame = lottieView.currentFrame
            animationLayer.display()
            
            layer = animationLayer
            size = animation.bounds.size
    
        case let .svga(entity):
            guard let drawLayer = svgaView.drawLayer else {
                completion(.failure(reason: "图片截取失败"))
                return
            }
            
            layer = drawLayer
            size = entity.videoSize
        }
        
        var newImage: UIImage?
        Asyncs.async {
            
            UIGraphicsBeginImageContextWithOptions(size, false, 0)
            guard let ctx = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndImageContext()
                return
            }
            
            layer.render(in: ctx)
            newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
        } mainTask: {
            if let newImage {
                completion(.success(image: newImage))
            } else {
                completion(.failure(reason: "图片截取失败"))
            }
        }
    }
}
