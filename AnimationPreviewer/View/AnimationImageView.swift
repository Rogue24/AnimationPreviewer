//
//  AnimationImageView.swift
//  AnimationPreviewer
//
//  Created by 周健平 on 2023/5/9.
//

import UIKit
import SnapKit
import SVGAPlayer_Optimized
import Lottie

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
        case let .dotLottie(file):
            replaceDotLottie(file)
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
    func replaceDotLottie(_ file: DotLottieFile) {
        hiddenSvgaView()
        hiddenGifView()
        
        lottieView.loadAnimation(from: file)
        lottieView.isHidden = false
        
        updateLayout()
    }
    
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

// MARK: - 截取当前帧为图片
extension AnimationImageView {
    func getCurrentImage(completion: @escaping (_ result: GetImageResult) -> Void) {
        guard let store else {
            completion(.failure(reason: "没有对象"))
            return
        }
        
        var delay: TimeInterval = 0
        var newImage: UIImage? = nil
        let task: Asyncs.BaseTask
        
        switch store {
        case let .dotLottie(file):
            let lottieLayer = LottieAnimationLayer(
                dotLottie: file,
                configuration: LottieConfiguration(renderingEngine: .mainThread)
            )
            
            guard let animation = file.animations.first?.animation,
                  let animationLayer = lottieLayer.animationLayer as? MainThreadAnimationLayer
            else {
                completion(.failure(reason: "图片截取失败"))
                return
            }
            
            lottieLayer.currentFrame = lottieView.currentFrame
            lottieLayer.forceDisplayUpdate()
            
            delay = 0.01 // 延迟一下等lottieLayer把画面渲染好
            let size = animation.bounds.size
            let layer = animationLayer
            task = {
                newImage = layer.image(size: size, scale: 1)
            }
            
        case let .lottie(animation, provider):
            let lottieLayer = LottieAnimationLayer(
                animation: animation,
                imageProvider: provider,
                configuration: LottieConfiguration(renderingEngine: .mainThread)
            )
            
            guard let animationLayer = lottieLayer.animationLayer as? MainThreadAnimationLayer else {
                completion(.failure(reason: "图片截取失败"))
                return
            }
            
            lottieLayer.currentFrame = lottieView.currentFrame
            lottieLayer.forceDisplayUpdate()
            
            delay = 0.01 // 延迟一下等lottieLayer把画面渲染好
            let size = animation.bounds.size
            let layer = animationLayer
            task = {
                newImage = layer.image(size: size, scale: 1)
            }
            
        case .svga:
            let svgaView = self.svgaView
            task = {
                newImage = svgaView.snapshotCurrentFrameWith(asPNG: true)
            }
            
        case .gif:
            let gifView = self.gifView
            task = {
                guard let image = gifView.image,
                      let pngData = image.pngData(),
                      let pngImg = UIImage(data: pngData)
                else { return }
                newImage = pngImg
            }
        }
        
        Asyncs.asyncDelay(delay, task) {
            if let newImage {
                completion(.success(image: newImage))
            } else {
                completion(.failure(reason: "图片截取失败"))
            }
        }
    }
}
