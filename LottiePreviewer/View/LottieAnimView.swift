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
            case .forward:
                return .loop
            case .reverse:
                return .autoReverse
            case .backwards:
                return .loop
            }
        }
    }
    
    private let placeholderView = UIView()
    private let animView = LottieAnimationView(animation: nil, imageProvider: nil)
    
    var isEnable: Bool {
        animView.animation != nil
    }
    
    var isPlaying: Bool {
        animView.isAnimationPlaying
    }
    
    var loopMode: LoopMode = .forward {
        didSet {
            animView.stop()
            animView.loopMode = loopMode.lottieLoopMode
            if loopMode == .backwards {
                animView.play(fromProgress: 1, toProgress: 0, loopMode: .loop)
            } else {
                animView.play(fromProgress: 0, toProgress: 1, loopMode: animView.loopMode)
            }
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
        label.text = "把lottie的压缩包丢到这里来吧"
        
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
        
        animView.isHidden = true
        animView.contentMode = .scaleAspectFit
        animView.loopMode = loopMode.lottieLoopMode
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
            animView.play()
            animView.isHidden = false
            placeholderView.isHidden = true
        } else {
            animView.stop()
            animView.animation = nil
            animView.isHidden = true
            placeholderView.isHidden = false
        }
        
        animView.layoutIfNeeded()
        placeholderView.layoutIfNeeded()
        
        UIView.transition(with: animView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
        UIView.transition(with: placeholderView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: {})
    }
    
    
    func play() {
        if loopMode == .backwards {
            animView.play(fromProgress: 1, toProgress: 0, loopMode: .loop)
        } else {
            animView.play(fromProgress: 0, toProgress: 1, loopMode: animView.loopMode)
        }
    }
    
    func pause() {
        animView.pause()
    }
    
    func stop() {
        animView.stop()
    }
    
    func makeVideo(progressHandler: @escaping (_ progressStr: String) -> (), completion: @escaping (_ videoPath: String?) -> ()) {
        guard let animation = animView.animation else {
            completion(nil)
            return
        }
        
        if animation.duration < 1 {
            JPrint("动画时长太短了")
            completion(nil)
            return
        }
        
        let provider = animView.imageProvider
        
        Asyncs.async {
            let picker = LottieImagePicker(animation: animation,
                                           provider: provider,
                                           bgColor: UIColor.black,
                                           animSize: [720, 720],
                                           renderScale: UIScreen.mainScale)
            
            VideoMaker.makeVideo(framerate: 20,
                                 frameInterval: 20,
                                 duration: animation.duration,
                                 size: [720, 720])
            { currentFrame, currentTime, _ in
                picker.update(currentTime)
                return [picker.animLayer]
            } progress: { currentFrame, totalFrame in
                let progress = Double(currentFrame) / Double(totalFrame)
                let progressStr = String(format: "视频制作中...%.0lf%%", progress * 100)
                Asyncs.main {
                    progressHandler(progressStr)
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
}


