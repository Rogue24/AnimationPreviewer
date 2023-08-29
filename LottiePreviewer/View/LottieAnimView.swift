//
//  LottieAnimView.swift
//  LottiePreviewer
//
//  Created by 周健平 on 2023/5/9.
//

import UIKit
import SnapKit

class LottieAnimView: UIView {
    enum LoopMode: CaseIterable {
        case forward
        case reverse
        case backwards
        
        var lottieLoopMode: LottieLoopMode {
            switch self {
            case .forward, .backwards:
                return .loop
            case .reverse:
                return .autoReverse
            }
        }
    }
    
    private var store: AnimationStore?
    
    private let placeholderView = UIView()
    private let lottieView = LottieAnimationView(animation: nil, imageProvider: nil)
    private let svgaView = SVGAParsePlayer()
    
    
    var isEnable: Bool {
        store != nil
    }
    
    var isPlaying: Bool {
        if !lottieView.isHidden {
            return lottieView.isAnimationPlaying
        } else if !svgaView.isHidden {
            return svgaView.status == .playing
        }
        return false
    }
    
    var loopMode: LoopMode = .forward {
        didSet {
//            animView.stop()
//            animView.loopMode = loopMode.lottieLoopMode
//            if loopMode == .backwards {
//                animView.play(fromProgress: 1, toProgress: 0, loopMode: .loop)
//            } else {
//                animView.play(fromProgress: 0, toProgress: 1, loopMode: animView.loopMode)
//            }
        }
    }
    
    init() {
        super.init(frame: .zero)
        
        let config = UIImage.SymbolConfiguration(
            pointSize: 82, weight: .medium, scale: .default)
        let dragIcon = UIImageView(image: UIImage(systemName: "arrow.turn.right.down", withConfiguration: config))
        dragIcon.contentMode = .scaleAspectFit
        dragIcon.tintColor = UIColor(white: 1, alpha: 0.8)
        
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = UIColor(white: 1, alpha: 0.8)
        label.text = "把Lottie/SVGA的文件丢到这里来吧"
        
        placeholderView.clipsToBounds = false
        placeholderView.addSubview(dragIcon)
        placeholderView.addSubview(label)
        addSubview(placeholderView)
        
        dragIcon.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.width.height.equalTo(110)
        }
        
        label.snp.makeConstraints { make in
            make.top.equalTo(dragIcon.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        placeholderView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        lottieView.isHidden = true
        lottieView.contentMode = .scaleAspectFit
        lottieView.loopMode = loopMode.lottieLoopMode
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
        
//        guard SVGAParsePlayer.loader == nil else { return }
//        SVGAParsePlayer.loader = { svgaSource, success, failure, _, _ in
//            if let data = AnimationStore.cacheSVGAData {
//                success(data)
//            } else {
//                let error = NSError(domain: "AnimationData", code: -2, userInfo: [NSLocalizedDescriptionKey: "数据为空"])
//                failure(error)
//            }
//        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func play() {
        if !lottieView.isHidden {
            if loopMode == .backwards {
                lottieView.play(fromProgress: 1, toProgress: 0, loopMode: .loop)
            } else {
                lottieView.play(fromProgress: 0, toProgress: 1, loopMode: lottieView.loopMode)
            }
        } else if !svgaView.isHidden {
            svgaView.play()
        }
    }
    
    func pause() {
        if !lottieView.isHidden {
            lottieView.pause()
        } else if !svgaView.isHidden {
            svgaView.pause()
        }
    }
    
    func stop() {
        if !lottieView.isHidden {
            lottieView.stop()
        } else if !svgaView.isHidden {
            svgaView.stop(isClear: false)
        }
    }
    
    func makeVideo(progressHandler: @escaping (_ progress: Float) -> (), completion: @escaping (_ videoPath: String?) -> ()) {
        guard let store, store.isLottie, let animation = lottieView.animation else {
            completion(nil)
            return
        }
        
        if animation.duration < 1 {
            JPrint("动画时长太短了")
            completion(nil)
            return
        }
        
        let provider = lottieView.imageProvider
        
        Asyncs.async {
            let picker = LottieImagePicker(animation: animation,
                                           provider: provider,
                                           bgColor: UIColor.black,
                                           animSize: [720, 720],
                                           renderScale: UIScreen.mainScale)
            
            VideoMaker.makeVideo(framerate: 20,
                                 frameInterval: 20,
                                 duration: animation.duration,
                                 size: [720, 720]) { currentFrame, currentTime, _ in
                picker.update(currentTime)
                return [picker.animLayer]
            } progress: { currentFrame, totalFrame in
                let progress = Float(currentFrame) / Float(totalFrame)
                Asyncs.main {
                    progressHandler(progress)
                }
            } completion: { result in
                switch result {
                case let .success(path):
                    completion(path)
                case .failure:
                    completion(nil)
                }
            }
        }
    }
    
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

private extension LottieAnimView {
    func removeAnimation() {
        lottieView.stop()
        lottieView.animation = nil
        lottieView.isHidden = true
        
        svgaView.stop(isClear: true)
        svgaView.isHidden = true
        
        placeholderView.isHidden = false
        
        updateLayout()
    }
    
    func updateLayout() {
        lottieView.layoutIfNeeded()
        svgaView.layoutIfNeeded()
        placeholderView.layoutIfNeeded()
        
        UIView.transition(with: lottieView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
        
        UIView.transition(with: svgaView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
        
        UIView.transition(with: placeholderView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
    }
    
}

private extension LottieAnimView {
    func replaceLottie(_ animation: LottieAnimation, _ provider: FilepathImageProvider) {
        placeholderView.isHidden = true
        
        svgaView.stop(isClear: true)
        svgaView.isHidden = true
        
        lottieView.animation = animation
        lottieView.imageProvider = provider
        lottieView.play()
        lottieView.isHidden = false
        
        updateLayout()
    }
}

extension LottieAnimView {
    func replaceSVGA(_ entity: SVGAVideoEntity) {
        placeholderView.isHidden = true
        
        lottieView.stop()
        lottieView.animation = nil
        lottieView.isHidden = true
        
        svgaView.play(with: entity)
        svgaView.isHidden = false
        
        updateLayout()
    }
}
