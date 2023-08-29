//
//  ViewController.swift
//  LottiePreviewer
//
//  Created by 周健平 on 2023/5/8.
//

import UIKit
import SnapKit

class ViewController: UIViewController {
    @IBOutlet weak var contentView: UIView!
    
    let playView = AnimationPlayView()
    let stackView: UIStackView = {
        let s = UIStackView()
        s.backgroundColor = .clear
        s.axis = .horizontal
        s.distribution = .fillEqually
        return s
    }()
    lazy var playBtn: NoHighlightButton = {
        let b = NoHighlightButton(type: .custom)
        b.setImage(UIImage(systemName: "play.circle", withConfiguration: sfConfig), for: .normal)
        b.setImage(UIImage(systemName: "pause.circle", withConfiguration: sfConfig), for: .selected)
        b.tintColor = UIColor(white: 1, alpha: 0.8)
        return b
    }()
    lazy var modeBtn = createBtn("repeat.circle")
    lazy var videoBtn = createBtn("arrow.down.left.video")
    lazy var trashBtn = createBtn("trash")
    
    let imageView = AnimationImageView()
    lazy var imgBtn = createBtn("square.and.arrow.down.on.square")
    let slider = UISlider()
    let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17)
        l.textAlignment = .center
        l.text = "0"
        return l
    }()
    
    lazy var dropInteraction = UIDropInteraction(delegate: self)
    
    let sfConfig = UIImage.SymbolConfiguration(
        pointSize: 31, weight: .medium, scale: .default)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupBgView()
        addSubviews()
        setupSubviewsLayout()
        addSubviewsTarget()
        
        // 初始化缓存
        AnimationStore.setup() { [weak self] in
            guard let self, let store = AnimationStore.cache else { return }
            self.replaceAnimation(store)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        JPProgressHUD.positionHUD()
    }
}

// MARK: - UI工厂
private extension ViewController {
    func createBtn(_ sfName: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: sfName, withConfiguration: sfConfig), for: .normal)
        btn.tintColor = UIColor(white: 1, alpha: 0.8)
        return btn
    }
    
    func setupBgView() {
        let bgMaskView = UIView()
        bgMaskView.backgroundColor = .rgb(0, 0, 0, a: 0.25)
        view.insertSubview(bgMaskView, at: 0)
        bgMaskView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let bgImgView = UIImageView(image: UIImage(contentsOfFile: Bundle.jp.resourcePath(withName: "background", type: "jpg")))
        bgImgView.contentMode = .scaleAspectFill
        view.insertSubview(bgImgView, at: 0)
        bgImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func addSubviews() {
        contentView.addSubview(playView)
        contentView.addSubview(stackView)
        
        stackView.addArrangedSubview(playBtn)
        stackView.addArrangedSubview(modeBtn)
        stackView.addArrangedSubview(videoBtn)
        stackView.addArrangedSubview(trashBtn)
        
        contentView.addSubview(imageView)
        contentView.addSubview(imgBtn)
        contentView.addSubview(slider)
        contentView.addSubview(valueLabel)
    }
    
    func setupSubviewsLayout() {
        playView.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.top.equalTo(20)
            make.right.equalTo(imageView.snp.left).offset(-20)
        }
        stackView.snp.makeConstraints { make in
            make.left.right.equalTo(playView)
            make.top.equalTo(playView.snp.bottom).offset(10)
            make.bottom.equalTo(-20)
            make.height.equalTo(51)
        }
        playBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        modeBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        videoBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        trashBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        
        imageView.snp.makeConstraints { make in
            make.right.equalTo(-20)
            make.top.equalTo(20)
            make.width.equalTo(playView)
            make.height.equalTo(playView)
        }
        imgBtn.snp.makeConstraints { make in
            make.left.equalTo(imageView).offset(20)
            make.centerY.equalTo(slider)
            make.width.height.equalTo(51)
        }
        slider.snp.makeConstraints { make in
            make.left.equalTo(imgBtn.snp.right).offset(15)
            make.right.equalTo(valueLabel.snp.left)
            make.top.equalTo(imageView.snp.bottom).offset(20)
        }
        valueLabel.snp.makeConstraints { make in
            make.right.equalTo(imageView)
            make.centerY.equalTo(slider)
            make.width.equalTo(60)
        }
    }
    
    func addSubviewsTarget() {
        playBtn.addTarget(self, action: #selector(playAction(_:)), for: .touchUpInside)
        modeBtn.addTarget(self, action: #selector(modeAction(_:)), for: .touchUpInside)
        videoBtn.addTarget(self, action: #selector(videoAction(_:)), for: .touchUpInside)
        trashBtn.addTarget(self, action: #selector(deleteAction(_:)), for: .touchUpInside)
        imgBtn.addTarget(self, action: #selector(imageAction(_:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(sliderDidChanged(_:)), for: .valueChanged)
        
        playView.addInteraction(dropInteraction)
    }
}

// MARK: - Actions
extension ViewController {
    /// 播放/暂停
    @objc func playAction(_ sender: UIButton) {
        guard playView.isEnable else { return }
        sender.isSelected.toggle()
        if sender.isSelected {
            playView.play()
        } else {
            playView.pause()
        }
    }
    
    /// 播放模式
    @objc func modeAction(_ sender: UIButton) {
        guard let store = playView.store else { return }
        guard store.isLottie else {
            JPProgressHUD.showInfo(withStatus: "暂不支持SVGA")
            return
        }
        
        let alertCtr = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for loopMode in AnimationPlayView.LoopMode.allCases {
            let title: String
            switch loopMode {
            case .forward:
                title = "Forward loop"
            case .reverse:
                title = "Reverse loop"
            case .backwards:
                title = "Backwards loop"
            }
            alertCtr.addAction(
                UIAlertAction(title: title, style: .default) { _ in
                    self.playView.loopMode = loopMode
                    self.playBtn.isSelected = true
                }
            )
        }
        alertCtr.addAction(UIAlertAction(title: "取消", style: .cancel))
        
        if let popover = alertCtr.popoverPresentationController {
            popover.sourceView = sender
            popover.permittedArrowDirections = .down
        }
        present(alertCtr, animated: true)
    }
    
    /// 制作视频
    @objc func videoAction(_ sender: UIButton) {
        guard let store = playView.store else { return }
        guard store.isLottie else {
            JPProgressHUD.showInfo(withStatus: "暂不支持SVGA")
            return
        }
        
        JPProgressHUD.show(withStatus: "视频制作中...")
        playView.makeVideo { progress in
            JPProgressHUD.showProgress(progress, status: String(format: "视频制作中...%.0lf%%", progress * 100))
        } completion: { result in
            switch result {
            case let .success(videoPath):
                Self.saveVideo(videoPath)
            case let .failure(reason):
                JPProgressHUD.showError(withStatus: reason)
            }
        }
    }
    
    /// 删除
    @objc func deleteAction(_ sender: UIButton) {
        guard playView.isEnable else { return }
        replaceAnimation(nil)
        AnimationStore.clearCache()
    }
    
    /// 截取当前帧生成图片
    @objc func imageAction(_ sender: UIButton) {
        guard imageView.isEnable else { return }
        JPProgressHUD.show()
        imageView.getCurrentImage() { result in
            switch result {
            case let .success(image):
                Self.saveImage(image)
            case let .failure(reason):
                JPProgressHUD.showError(withStatus: reason)
            }
        }
    }
    
    /// 滑动浏览帧
    @objc func sliderDidChanged(_ slider: UISlider) {
        imageView.currentFrame = CGFloat(slider.value)
        valueLabel.text = String(format: "%0.lf", slider.value)
    }
}

// MARK: - 保存视频/图片
private extension ViewController {
    static func saveVideo(_ videoPath: String) {
        MacChannel.shared().saveVideo(videoPath as NSString) { isSuccess in
            if isSuccess {
                JPProgressHUD.dismiss()
            } else {
                JPProgressHUD.showError(withStatus: "视频保存失败")
            }
            File.manager.deleteFile(videoPath)
        }
    }
    
    static func saveImage(_ image: UIImage) {
        guard let data = image.pngData() else {
            JPProgressHUD.showError(withStatus: "图片生成失败")
            return
        }
        
        MacChannel.shared().saveImage(data) { isSuccess in
            if isSuccess {
                JPProgressHUD.dismiss()
            } else {
                JPProgressHUD.showError(withStatus: "图片保存失败")
            }
        }
    }
}

// MARK: - 替换/移除Lottie
extension ViewController {
    func replaceAnimation(_ store: AnimationStore?) {
        playView.replaceAnimation(store)
        imageView.replaceAnimation(store)
        
        defer {
            slider.value = slider.minimumValue
            valueLabel.text = "0"
        }
        
        guard let store else {
            playBtn.isSelected = false
            slider.minimumValue = 0
            slider.maximumValue = 1
            return
        }
        
        playBtn.isSelected = true
        switch store {
        case let .lottie(animation, _):
            slider.minimumValue = Float(animation.startFrame)
            slider.maximumValue = Float(animation.endFrame)
        case let .svga(entity):
            slider.minimumValue = 0
            slider.maximumValue = Float(entity.frames)
        }
    }
}
