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
    private let svgaView = SVGAExPlayer()
    private let gifView = UIImageView()
    private var gif: (images: [UIImage], currentFrame: Int) = ([], 0)
    
    var isEnable: Bool {
        store != nil
    }
    
    var currentFrame: CGFloat {
        set {
            if !lottieView.isHidden {
                lottieView.currentFrame = newValue
            }
            else if !svgaView.isHidden {
                svgaView.play(fromFrame: Int(newValue), isAutoPlay: false)
            }
            else if !gifView.isHidden {
                gif.1 = Int(newValue)
                guard gif.1 < gif.0.count else { return }
                gifView.image = gif.0[gif.1]
            }
        }
        get {
            if !lottieView.isHidden {
                return lottieView.currentFrame
            }
            else if !svgaView.isHidden {
                return CGFloat(svgaView.currentFrame)
            }
            else if !gifView.isHidden {
                return CGFloat(gif.1)
            }
            return 0
        }
    }
    
    init() {
        super.init(frame: .zero)
        setupBase()
        setupLottieView()
        setupSvgaView()
        setupGifView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension AnimationImageView {
    func setupBase() {
        backgroundColor = .rgb(41, 43, 51, a: 0.35)
        layer.borderColor = UIColor(white: 1, alpha: 0.25).cgColor
        layer.borderWidth = 4
        layer.cornerRadius = 16
        layer.masksToBounds = true
    }
    
    func setupLottieView() {
        lottieView.isHidden = true
        lottieView.contentMode = .scaleAspectFit
        addSubview(lottieView)
        lottieView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func setupSvgaView() {
        svgaView.isHidden = true
        svgaView.contentMode = .scaleAspectFit
        addSubview(svgaView)
        svgaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func setupGifView() {
        gifView.isHidden = true
        gifView.contentMode = .scaleAspectFit
        addSubview(gifView)
        gifView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func hiddenLottieView() {
        lottieView.stop()
        lottieView.animation = nil
        lottieView.isHidden = true
    }
    
    func hiddenSvgaView() {
        svgaView.clean()
        svgaView.isHidden = true
    }
    
    func hiddenGifView() {
        gif = ([], 0)
        gifView.image = nil
        gifView.isHidden = true
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
        case let .gif(images, _):
            replaceGIF(images)
        }
    }
}

private extension AnimationImageView {
    func replaceLottie(_ animation: LottieAnimation, _ provider: FilepathImageProvider) {
        hiddenSvgaView()
        hiddenGifView()
        
        lottieView.animation = animation
        lottieView.imageProvider = provider
        lottieView.isHidden = false
        
        updateLayout()
    }
    
    func replaceSVGA(_ entity: SVGAVideoEntity) {
        hiddenLottieView()
        hiddenGifView()
        
        svgaView.play(with: entity, fromFrame: 0, isAutoPlay: false)
        svgaView.isHidden = false
        
        updateLayout()
    }
    
    func replaceGIF(_ images: [UIImage]) {
        hiddenLottieView()
        hiddenSvgaView()
        
        gif = (images, 0)
        gifView.image = images.first
        gifView.isHidden = false
        
        updateLayout()
    }
}

private extension AnimationImageView {
    func removeAnimation() {
        hiddenLottieView()
        hiddenSvgaView()
        hiddenGifView()
        updateLayout()
    }
    
    func updateLayout() {
        lottieView.layoutIfNeeded()
        svgaView.layoutIfNeeded()
        gifView.layoutIfNeeded()
        
        UIView.transition(with: lottieView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
        
        UIView.transition(with: svgaView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
        
        UIView.transition(with: gifView,
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
            guard let drawLayer = svgaView.getDrawLayer() else {
                completion(.failure(reason: "图片截取失败"))
                return
            }
            
            layer = drawLayer
            size = entity.videoSize
            
        case .gif:
            guard let image = gifView.image else {
                completion(.failure(reason: "图片截取失败"))
                return
            }
            
            completion(.success(image: image))
            return
        }
        
        var newImage: UIImage?
        Asyncs.async {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false // false表示透明，这里需要透明背景
            format.scale = UIScreen.main.scale
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            newImage = renderer.image { ctx in
                DispatchQueue.main.sync {
                    layer.render(in: ctx.cgContext)
                }
            }
        } mainTask: {
            if let newImage {
                completion(.success(image: newImage))
            } else {
                completion(.failure(reason: "图片截取失败"))
            }
        }
    }
}
