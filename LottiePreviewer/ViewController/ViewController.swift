//
//  ViewController.swift
//  LottiePreviewer
//
//  Created by 周健平 on 2023/5/8.
//

import UIKit
import SnapKit

typealias LottieTuple = (animation: LottieAnimation, provider: FilepathImageProvider)

class ViewController: UIViewController {
    @IBOutlet weak var contentView: UIView!
    
    let animView = LottieAnimView()
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
    
    let imageView = LottieImageView()
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
    var isAppear: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBgView()
        addSubviews()
        setupSubviewsLayout()
        addSubviewsTarget()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard !isAppear else { return }
        isAppear = true
        
        // 初始化缓存
        guard let lottiePath = LottieStore.lottieFilePath,
              let animation = LottieAnimation.filepath("\(lottiePath)/data.json", animationCache: LRUAnimationCache.sharedCache) else { return }
        let provider = FilepathImageProvider(filepath: lottiePath)
        replaceLottie((animation, provider))
    }
}

// MARK: - UI工厂
extension ViewController {
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
        contentView.addSubview(animView)
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
        animView.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.top.equalTo(20)
            make.right.equalTo(imageView.snp.left).offset(-20)
        }
        stackView.snp.makeConstraints { make in
            make.left.right.equalTo(animView)
            make.top.equalTo(animView.snp.bottom).offset(10)
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
            make.width.equalTo(animView)
            make.height.equalTo(animView)
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
        
        animView.addInteraction(dropInteraction)
    }
}

// MARK: - Actions
extension ViewController {
    
    // MARK: 播放/暂停
    @objc func playAction(_ sender: UIButton) {
        guard animView.isEnable else { return }
        sender.isSelected.toggle()
        if sender.isSelected {
            animView.play()
        } else {
            animView.pause()
        }
    }
    
    // MARK: 播放模式
    @objc func modeAction(_ sender: UIButton) {
        guard animView.isEnable else { return }
        let alertCtr = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for loopMode in LottieAnimView.LoopMode.allCases {
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
                    self.animView.loopMode = loopMode
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
    
    // MARK: 制作视频
    @objc func videoAction(_ sender: UIButton) {
        guard animView.isEnable else { return }
        JPProgressHUD.show(withStatus: "视频制作中...")
        animView.makeVideo { progressStr in
            JPProgressHUD.show(withStatus: progressStr)
        } completion: { videoPath in
            guard let videoPath = videoPath, File.manager.fileExists(videoPath) else {
                JPProgressHUD.showError(withStatus: "视频制作失败", userInteractionEnabled: true)
                return
            }
            MacChannel.shared().saveVideo(videoPath as NSString) { isSuccess in
                if isSuccess {
                    JPProgressHUD.dismiss()
                } else {
                    JPProgressHUD.showError(withStatus: "视频制作失败", userInteractionEnabled: true)
                }
                File.manager.deleteFile(videoPath)
            }
        }
    }
    
    // MARK: 删除
    @objc func deleteAction(_ sender: UIButton) {
        guard animView.isEnable else { return }
        replaceLottie(nil)
        LottieStore.clearCache()
    }
    
    // MARK: 截取当前帧生成图片
    @objc func imageAction(_ sender: UIButton) {
        guard imageView.isEnable else { return }
        JPProgressHUD.show()
        imageView.getCurrentImage() { image in
            guard let image = image, let data = image.pngData() else {
                JPProgressHUD.showError(withStatus: "图片截取失败", userInteractionEnabled: true)
                return
            }
            MacChannel.shared().saveImage(data) { isSuccess in
                if isSuccess {
                    JPProgressHUD.dismiss()
                } else {
                    JPProgressHUD.showError(withStatus: "图片截取失败", userInteractionEnabled: true)
                }
            }
        }
    }
    
    // MARK: 滑动浏览帧
    @objc func sliderDidChanged(_ slider: UISlider) {
        imageView.currentFrame = CGFloat(slider.value)
        valueLabel.text = String(format: "%0.lf", slider.value)
    }
}


// MARK: - 替换/移除Lottie
extension ViewController {
    func replaceLottie(_ tuple: LottieTuple?) {
        animView.replaceLottie(tuple)
        imageView.replaceLottie(tuple)
        if let tuple = tuple {
            playBtn.isSelected = true
            slider.minimumValue = Float(tuple.animation.startFrame)
            slider.maximumValue = Float(tuple.animation.endFrame)
        } else {
            playBtn.isSelected = false
            slider.minimumValue = 0
            slider.maximumValue = 1
        }
        slider.value = slider.minimumValue
        valueLabel.text = String(format: "%0.lf", slider.value)
    }
}
