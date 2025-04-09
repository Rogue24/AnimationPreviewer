//
//  AnimationPlayView.swift
//  AnimationPreviewer
//
//  Created by 周健平 on 2023/5/9.
//

import UIKit
import SnapKit

class AnimationPlayView: UIView {
    enum LoopMode: CaseIterable {
        case forward
        case backwards
        case reverse
        case forwardOnce
        case backwardsOnce
        
        var title: String {
            switch self {
            case .forward:
                return "Forward loop"
            case .backwards:
                return "Backwards loop"
            case .reverse:
                return "Reverse loop"
            case .forwardOnce:
                return "Forward once"
            case .backwardsOnce:
                return "Backwards once"
            }
        }
        
        var lottieLoopMode: LottieLoopMode {
            switch self {
            case .forward, .backwards:
                return .loop
            case .reverse:
                return .autoReverse
            case .forwardOnce, .backwardsOnce:
                return .playOnce
            }
        }
        
        var isOnce: Bool {
            switch self {
            case .forwardOnce, .backwardsOnce:
                return true
            default:
                return false
            }
        }
        
        var isForwar: Bool {
            switch self {
            case .forward, .forwardOnce:
                return true
            default:
                return false
            }
        }
        
        var isBackwards: Bool {
            switch self {
            case .backwards, .backwardsOnce:
                return true
            default:
                return false
            }
        }
    }
    
    enum MakeVideoResult {
        case success(videoPath: String)
        case failure(reason: String)
    }
    
    private(set) var store: AnimationStore?
    
    var isEnable: Bool {
        store != nil
    }
    
    var isPlaying: Bool {
        if !lottieView.isHidden {
            return lottieView.isAnimationPlaying
        } else if !svgaView.isHidden {
            return svgaView.isPlaying
        } else if !gifView.isHidden {
            return gifView.isAnimating
        }
        return false
    }
    
    var loopMode: LoopMode = .forward {
        didSet {
            cancelDelayDone()
            
            // 换成单次播放则重新设置进度
            if loopMode.isOnce {
                // 这里不能暂停，需要【停止】之后再设置进度
                if !lottieView.isHidden {
                    lottieView.stop()
                }
                else if !svgaView.isHidden {
                    svgaView.stop(then: .clearLayers)
                }
                else if !gifView.isHidden {
                    gifView.stopAnimating()
                }
            }
            
            play()
        }
    }
    
    @UserDefault(.isSVGAMute) private var _isSVGAMute: Bool = false
    var isSVGAMute: Bool {
        get { _isSVGAMute }
        set {
            _isSVGAMute = newValue
            svgaView.isMute = newValue
        }
    }
    
    var playOnceDoneHandler: (() -> Void)?
    private var delayDoneWorkItem: DispatchWorkItem? = nil
    
    private let placeholderView = UIView()
    private let lottieView = LottieAnimationView(animation: nil, imageProvider: nil)
    private let svgaView = SVGAExPlayer()
    private let gifView = UIImageView()
    private var gif: (images: [UIImage], duration: TimeInterval) = ([], 0)
    
    init() {
        super.init(frame: .zero)
        setupBase()
        setupPlaceholderView()
        setupLottieView()
        setupSvgaView()
        setupGifView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private extension AnimationPlayView {
    func setupBase() {
        backgroundColor = .rgb(41, 43, 51, a: 0.35)
        layer.borderColor = UIColor(white: 1, alpha: 0.25).cgColor
        layer.borderWidth = 4
        layer.cornerRadius = 16
        layer.masksToBounds = true
    }
    
    func setupPlaceholderView() {
        let config = UIImage.SymbolConfiguration(
            pointSize: 82, weight: .medium, scale: .default)
        let dragIcon = UIImageView(image: UIImage(systemName: "arrow.turn.right.down", withConfiguration: config))
        dragIcon.contentMode = .scaleAspectFit
        dragIcon.tintColor = UIColor(white: 1, alpha: 0.8)
        
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.textColor = UIColor(white: 1, alpha: 0.8)
        label.text = "把「Lottie / SVGA / GIF」丢到这里来吧"
        
        placeholderView.clipsToBounds = false
        placeholderView.addSubview(dragIcon)
        placeholderView.addSubview(label)
        addSubview(placeholderView)
        
        dragIcon.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(110)
        }
        
        label.snp.makeConstraints { make in
            make.top.equalTo(dragIcon.snp.bottom).offset(20)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        placeholderView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
        }
    }
    
    func setupLottieView() {
        lottieView.isHidden = true
        lottieView.contentMode = .scaleAspectFit
        lottieView.loopMode = loopMode.lottieLoopMode
        addSubview(lottieView)
        lottieView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func setupSvgaView() {
        svgaView.isHidden = true
        svgaView.contentMode = .scaleAspectFit
        svgaView.isMute = isSVGAMute
        svgaView.isHideWhenStopped = false
        svgaView.exDelegate = self
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
        gifView.stopAnimating()
        gifView.animationImages = nil
        gifView.animationDuration = 0
        gifView.image = nil
        gifView.isHidden = true
    }
}

// MARK: - <SVGAExPlayerDelegate>
extension AnimationPlayView: SVGAExPlayerDelegate {
    func svgaExPlayer(_ player: SVGAExPlayer, svga source: String, animationDidFinishedOnce loopCount: Int) {
        if loopMode == .reverse {
            player.isReversing.toggle()
        }
    }
}

extension AnimationPlayView {
    func replaceAnimation(_ store: AnimationStore?) {
        cancelDelayDone()
        
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
        case let .gif(images, duration):
            replaceGIF(images, duration)
        }
        
        play()
    }
}

private extension AnimationPlayView {
    func replaceLottie(_ animation: LottieAnimation, _ provider: FilepathImageProvider) {
        placeholderView.isHidden = true
        hiddenSvgaView()
        hiddenGifView()
        
        lottieView.animation = animation
        lottieView.imageProvider = provider
        lottieView.isHidden = false
        
        updateLayout()
    }
    
    func replaceSVGA(_ entity: SVGAVideoEntity) {
        placeholderView.isHidden = true
        hiddenLottieView()
        hiddenGifView()
        
        let fromFrame = svgaView.isReversing ? entity.maxFrame : entity.minFrame
        svgaView.play(with: entity, fromFrame: fromFrame, isAutoPlay: false)
        svgaView.isHidden = false
        
        updateLayout()
    }
    
    func replaceGIF(_ images: [UIImage], _ duration: TimeInterval) {
        placeholderView.isHidden = true
        hiddenLottieView()
        hiddenSvgaView()
        
        gif = (images, duration)
        gifView.stopAnimating()
        gifView.animationImages = nil
        gifView.animationDuration = 0
        gifView.image = nil
        gifView.isHidden = false
        
        updateLayout()
    }
}

private extension AnimationPlayView {
    func cancelDelayDone() {
        delayDoneWorkItem?.cancel()
        delayDoneWorkItem = nil
    }
    
    func removeAnimation() {
        placeholderView.isHidden = false
        hiddenLottieView()
        hiddenSvgaView()
        hiddenGifView()
        updateLayout()
    }
    
    func updateLayout() {
        placeholderView.layoutIfNeeded()
        lottieView.layoutIfNeeded()
        svgaView.layoutIfNeeded()
        gifView.layoutIfNeeded()
        
        UIView.transition(with: placeholderView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
        
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

extension AnimationPlayView {
    func play() {
        cancelDelayDone()
        
        var delay: TimeInterval = 0
        
        if !lottieView.isHidden {
            if loopMode.isOnce {
                delay = lottieView.animation?.duration ?? 0
                let progress = lottieView.currentProgress
                if progress > 0, progress < 1 {
                    if loopMode.isBackwards {
                        delay *= progress
                    } else {
                        delay *= (1 - progress)
                    }
                }
            }
            
            // 如果是暂停中调用以下方法不会重新播放，会继续播放
            if loopMode.isBackwards {
                lottieView.play(fromProgress: 1, toProgress: 0, loopMode: loopMode.lottieLoopMode)
            } else {
                lottieView.play(fromProgress: 0, toProgress: 1, loopMode: loopMode.lottieLoopMode)
            }
        }
        else if !svgaView.isHidden {
            switch loopMode {
            case .forward:
                svgaView.loops = 0
                svgaView.isReversing = false
                
            case .backwards:
                svgaView.loops = 0
                svgaView.isReversing = true
                
            case .reverse:
                svgaView.loops = 0
                
            case .forwardOnce:
                svgaView.loops = 1
                svgaView.isReversing = false
                svgaView.finishedAllScene = .stepToTrailing
                
            case .backwardsOnce:
                svgaView.loops = 1
                svgaView.isReversing = true
                svgaView.finishedAllScene = .stepToTrailing
            }
            
            if loopMode.isOnce {
                delay = svgaView.videoItem?.duration ?? 0
                let progress = Double(svgaView.progress)
                if progress > 0, progress < 1 {
                    if svgaView.isReversing {
                        delay *= progress
                    } else {
                        delay *= (1 - progress)
                    }
                } else {
                    // 不是播放中则重新播放
                    svgaView.step(toFrame: svgaView.leadingFrame)
                }
            }
            
            svgaView.play()
        }
        else if !gifView.isHidden {
            switch loopMode {
            case .forward:
                gifView.image = gif.0.first
                gifView.animationImages = gif.0
                gifView.animationDuration = gif.1
                gifView.animationRepeatCount = 0
                
            case .backwards:
                gifView.image = gif.0.last
                gifView.animationImages = gif.0.reversed()
                gifView.animationDuration = gif.1
                gifView.animationRepeatCount = 0
                
            case .reverse:
                gifView.image = gif.0.first
                gifView.animationImages = gif.0 + gif.0.reversed()
                gifView.animationDuration = gif.1 * 2
                gifView.animationRepeatCount = 0
                
            case .forwardOnce:
                gifView.image = gif.0.first
                gifView.animationImages = gif.0
                gifView.animationDuration = gif.1
                gifView.animationRepeatCount = 1
                delay = gif.1
                
            case .backwardsOnce:
                gifView.image = gif.0.last
                gifView.animationImages = gif.0.reversed()
                gifView.animationDuration = gif.1
                gifView.animationRepeatCount = 1
                delay = gif.1
            }
            
            // gif没有暂停，所以不用看进度
            gifView.startAnimating()
        }
        
        guard delay > 0 else { return }
        delayDoneWorkItem = Asyncs.mainDelay(delay) { [weak self] in
            self?.playOnceDoneHandler?()
        }
    }
    
    func pause() {
        cancelDelayDone()
        
        if !lottieView.isHidden {
            lottieView.pause()
        }
        else if !svgaView.isHidden {
            svgaView.pause()
        }
        else if !gifView.isHidden {
            gifView.stopAnimating()
        }
    }
    
    func stop() {
        cancelDelayDone()
        
        if !lottieView.isHidden {
            lottieView.stop()
        }
        else if !svgaView.isHidden {
            svgaView.stop()
        }
        else if !gifView.isHidden {
            gifView.stopAnimating()
        }
    }
}

// MARK: - 制作视频
extension AnimationPlayView {
    func makeVideo(progressHandler: @escaping (_ progress: Float) -> (),
                   otherHandler: @escaping (_ text: String) -> (),
                   completion: @escaping (_ result: MakeVideoResult) -> ()) {
        guard let store else {
            completion(.failure(reason: "没有对象"))
            return
        }
        
        switch store {
        case let .lottie(animation, provider):
            if animation.duration < 1 {
                completion(.failure(reason: "动画时长过短，无法生成视频"))
                return
            }
            
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
                Asyncs.main { progressHandler(progress) }
            } completion: { result in
                switch result {
                case let .success(path):
                    completion(.success(videoPath: path))
                case let .failure(error):
                    completion(.failure(reason: error.localizedDescription))
                }
            }
            
        case let .svga(entity):
            if entity.duration < 1 {
                completion(.failure(reason: "动画时长过短，无法生成视频"))
                return
            }
            
            VideoMaker.makeVideo(withSVGAEntity: entity, size: [720, 720]) { currentFrame, totalFrame in
                let progress = Float(currentFrame) / Float(totalFrame)
                Asyncs.main { progressHandler(progress) }
            } startMergeAudio: {
                Asyncs.main { otherHandler("合成动画音频中...") }
            } completion: { result in
                switch result {
                case let .success(path):
                    completion(.success(videoPath: path))
                case let .failure(error):
                    completion(.failure(reason: error.localizedDescription))
                }
            }
            
        case let .gif(images, duration):
            if duration < 1 {
                completion(.failure(reason: "动画时长过短，无法生成视频"))
                return
            }
            
            VideoMaker.makeVideo(withImages: images, duration: duration, size: [720, 720]) { currentFrame, totalFrame in
                let progress = Float(currentFrame) / Float(totalFrame)
                Asyncs.main { progressHandler(progress) }
            } completion: { result in
                switch result {
                case let .success(path):
                    completion(.success(videoPath: path))
                case let .failure(error):
                    completion(.failure(reason: error.localizedDescription))
                }
            }
            
//            Asyncs.async {
//                let frameDuration = duration / Double(images.count)
//                
//                let imageInfos: [VideoMaker.ImageInfo] = images.map {
//                    .init(image: $0, duration: frameDuration)
//                }
//                
//                let videoSize: CGSize = [720, 720]
//                
//                VideoMaker.makeVideo(withImageInfos: imageInfos, size: videoSize) { result in
//                    switch result {
//                    case let .success(path):
//                        completion(.success(videoPath: path))
//                    case let .failure(error):
//                        completion(.failure(reason: error.localizedDescription))
//                    }
//                }
//            }
        }
    }
}
