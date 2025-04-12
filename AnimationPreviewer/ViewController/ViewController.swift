//
//  ViewController.swift
//  AnimationPreviewer
//
//  Created by 周健平 on 2023/5/8.
//

import UIKit
import SnapKit

class ViewController: UIViewController {
    @IBOutlet weak var contentView: UIView!
    
    lazy var dropInteraction = UIDropInteraction(delegate: self)
    
    private let sfConfig = UIImage.SymbolConfiguration(pointSize: 31, weight: .medium, scale: .default)
    
    @UserDefault(.bgImageType) private var bgImageType: BgImageType.RawValue = 1
    
    private var originColor: UIColor = .defaultBgColor
    private var isTransparentGridBgColor: Bool = false
    
    private var bgColor: UIColor = .defaultBgColor {
        didSet {
            playView.backgroundColor = bgColor
            imageView.backgroundColor = bgColor
        }
    }
    
    // ================ 背景 ================
    private let bgImgView = UIImageView()
    
    // ================ 左边区域 ================
    private let playView = AnimationPlayView()
    
    private let stackView: UIStackView = {
        let s = UIStackView()
        s.backgroundColor = .clear
        s.axis = .horizontal
        s.distribution = .fillEqually
        return s
    }()
    
    private lazy var playBtn: NoHighlightButton = {
        let b = NoHighlightButton(type: .custom)
        b.setImage(UIImage(systemName: "play.circle", withConfiguration: sfConfig), for: .normal)
        b.setImage(UIImage(systemName: "pause.circle", withConfiguration: sfConfig), for: .selected)
        b.tintColor = UIColor(white: 1, alpha: 0.8)
        return b
    }()
    
    private lazy var modeBtn = createBtn("repeat.circle")
    
    private lazy var videoBtn = createBtn("arrow.down.left.video")
    
    private lazy var volumeBtn: NoHighlightButton = {
        let b = NoHighlightButton(type: .custom)
        b.setImage(UIImage(systemName: "speaker.wave.2", withConfiguration: sfConfig), for: .normal)
        b.setImage(UIImage(systemName: "speaker.slash", withConfiguration: sfConfig), for: .selected)
        b.tintColor = UIColor(white: 1, alpha: 0.8)
        b.isSelected = playView.isSVGAMute
        b.isHidden = true
        return b
    }()
    
    private lazy var bgColorBtn: NoHighlightButton = {
        let b = NoHighlightButton(type: .custom)
        b.backgroundColor = .randomColor
        return b
    }()
    
    private lazy var trashBtn = createBtn("trash")
    
    // ================ 右边区域 ================
    private let imageView = AnimationImageView()
    
    private lazy var imgBtn = createBtn("square.and.arrow.down.on.square")
    
    private let slider: UISlider = {
        let slider = UISlider()
        slider.maximumTrackTintColor = UIColor(white: 1, alpha: 0.25)
        return slider
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17)
        label.textColor = .white
        label.textAlignment = .center
        label.text = "0"
        return label
    }()
    
    // MARK: - 生命周期
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

// MARK: - UI Build & Setup
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
        
        bgImgView.contentMode = .scaleAspectFill
        view.insertSubview(bgImgView, at: 0)
        bgImgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        var type = BgImageType(rawValue: bgImageType) ?? .builtIn1
        guard type == .custom else {
            BgImageType.removeCustomBgImageData()
            bgImgView.image = type.bgImage
            return
        }
        
        if let image = type.bgImage {
            bgImgView.image = image
        } else {
            // 如果没有缓存的自定义背景图，则使用内置背景图1
            type = BgImageType.builtIn1
            BgImageType.removeCustomBgImageData()
            bgImgView.image = type.bgImage
            bgImageType = type.rawValue
        }
    }
    
    func addSubviews() {
        playView.backgroundColor = bgColor
        contentView.addSubview(playView)
        contentView.addSubview(stackView)
        
        stackView.addArrangedSubview(playBtn)
        stackView.addArrangedSubview(modeBtn)
        stackView.addArrangedSubview(videoBtn)
        stackView.addArrangedSubview(volumeBtn)
        stackView.addArrangedSubview(bgColorBtn)
        stackView.addArrangedSubview(trashBtn)
        
        imageView.backgroundColor = bgColor
        contentView.addSubview(imageView)
        contentView.addSubview(imgBtn)
        contentView.addSubview(slider)
        contentView.addSubview(valueLabel)
    }
    
    func setupSubviewsLayout() {
        // ================ 左边区域 ================
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
        
        volumeBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        
        bgColorBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        
        trashBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        
        // ================ 右边区域 ================
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
        // ================ 左边区域 ================
        playView.addInteraction(dropInteraction)
        playView.playOnceDoneHandler = { [weak self] in
            guard let self else { return }
            self.playBtn.isSelected = false // 恢复▶️
        }
        playBtn.addTarget(self, action: #selector(playAction(_:)), for: .touchUpInside)
        modeBtn.addTarget(self, action: #selector(modeAction(_:)), for: .touchUpInside)
        videoBtn.addTarget(self, action: #selector(videoAction(_:)), for: .touchUpInside)
        volumeBtn.addTarget(self, action: #selector(volumeAction(_:)), for: .touchUpInside)
        bgColorBtn.addTarget(self, action: #selector(bgColorAction(_:)), for: .touchUpInside)
        trashBtn.addTarget(self, action: #selector(deleteAction(_:)), for: .touchUpInside)
        
        // ================ 右边区域 ================
        imgBtn.addTarget(self, action: #selector(imageAction(_:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(sliderDidChanged(_:)), for: .valueChanged)
    }
}

private extension ViewController {
    // MARK: - 播放/暂停
    @objc func playAction(_ sender: UIButton) {
        guard playView.isEnable else { return }
        sender.isSelected.toggle()
        if sender.isSelected {
            playView.play()
        } else {
            playView.pause()
        }
    }
    
    // MARK: - 选择播放模式
    @objc func modeAction(_ sender: UIButton) {
        let allModes = AnimationPlayView.LoopMode.allCases
        
        let alertCtr = UIViewController()
        alertCtr.modalPresentationStyle = .popover
        alertCtr.preferredContentSize = [220, 10 + 44.0 * CGFloat(allModes.count) + 10]
        if let popover = alertCtr.popoverPresentationController {
            popover.sourceView = sender
            popover.permittedArrowDirections = .down
        }
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        alertCtr.view.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        for (i, loopMode) in allModes.enumerated() {
            let title = (playView.loopMode == loopMode ? "✅ " : "") + loopMode.title
            let color = playView.loopMode == loopMode ? UIColor.systemBlue : UIColor.white
            let btn = UIButton(type: .system)
            btn.tag = i
            btn.setTitle(title, for: .normal)
            btn.setTitleColor(color, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            btn.addTarget(self, action: #selector(_modeBtnDidClick(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(btn)
            btn.snp.makeConstraints { make in
                make.width.equalTo(220)
                make.height.equalTo(44)
            }
        }
        
        present(alertCtr, animated: true)
    }
    
    @objc func _modeBtnDidClick(_ sender: UIButton) {
        playView.loopMode = AnimationPlayView.LoopMode.allCases[sender.tag]
        playBtn.isSelected = true
        dismiss(animated: true)
    }
    
    // MARK: - 制作视频
    @objc func videoAction(_ sender: UIButton) {
        JPProgressHUD.show(withStatus: "视频制作中...")
        playView.makeVideo { progress in
            JPProgressHUD.showProgress(progress, status: String(format: "视频制作中...%.0lf%%", progress * 100))
        } otherHandler: { text in
            JPProgressHUD.show(withStatus: text)
        } completion: { result in
            switch result {
            case let .success(videoPath):
                Self.saveVideo(videoPath)
            case let .failure(reason):
                JPProgressHUD.showError(withStatus: reason)
            }
        }
    }
    
    // MARK: - 声音设置
    @objc func volumeAction(_ sender: UIButton) {
        sender.isSelected.toggle()
        playView.isSVGAMute = sender.isSelected
    }
    
    // MARK: - 背景色设置
    @objc func bgColorAction(_ sender: UIButton) {
        if !isTransparentGridBgColor {
            originColor = bgColor
        }
        
        let colorBoard = DSDetailColorBoard()
        
        let alertCtr = UIViewController()
        alertCtr.modalPresentationStyle = .popover
        alertCtr.preferredContentSize = colorBoard.frame.size
        if let popover = alertCtr.popoverPresentationController {
            popover.sourceView = sender
            popover.permittedArrowDirections = .down
        }
        
        alertCtr.view.addSubview(colorBoard)
        
        present(alertCtr, animated: true) {
            colorBoard.delegate = self
        }
    }
    
    // MARK: - 删除
    @objc func deleteAction(_ sender: UIButton) {
        guard playView.isEnable else { return }
        replaceAnimation(nil)
        AnimationStore.clearCache()
    }
    
    // MARK: - 截取当前帧生成图片
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
    
    // MARK: - 滑动浏览每一帧
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
                JPProgressHUD.showSuccess(withStatus: "视频制作成功")
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

// MARK: - 替换&移除·动画（Lottie/SVGA/GIF）
extension ViewController {
    func replaceAnimation(with data: Data) {
        JPProgressHUD.show(withStatus: "Loding...")
        AnimationStore.loadData(data) { [weak self] store in
            JPProgressHUD.dismiss()
            self?.replaceAnimation(store)
        } failure: { error in
            JPProgressHUD.showError(withStatus: error.localizedDescription)
        }
    }
    
    private func replaceAnimation(_ store: AnimationStore?) {
        playView.replaceAnimation(store)
        imageView.replaceAnimation(store)
        
        defer {
            slider.value = slider.minimumValue
            valueLabel.text = "0"
        }
        
        guard let store else {
            playBtn.isSelected = false
            volumeBtn.isHidden = true
            slider.minimumValue = 0
            slider.maximumValue = 1
            return
        }
        
        playBtn.isSelected = true
        switch store {
        case let .lottie(animation, _):
            volumeBtn.isHidden = true
            slider.minimumValue = Float(animation.startFrame)
            slider.maximumValue = Float(animation.endFrame)
        case let .svga(entity):
            volumeBtn.isHidden = false
            slider.minimumValue = 0
            slider.maximumValue = Float(entity.frames)
        case let .gif(images, _):
            volumeBtn.isHidden = true
            slider.minimumValue = 0
            slider.maximumValue = Float(images.count - 1)
        }
    }
}

// MARK: - 替换&移除·背景图片
extension ViewController {
    func removeBgImage() {
        replaceBgImage(for: .null)
    }
    
    func setupBuiltIn1BgImage() {
        replaceBgImage(for: .builtIn1)
    }
    
    func setupBuiltIn2BgImage() {
        replaceBgImage(for: .builtIn2)
    }
    
    func setupCustomBgImage(_ imageData: Data) {
        replaceBgImage(with: imageData, for: .custom)
    }
    
    private func replaceBgImage(with data: Data? = nil, for type: BgImageType) {
        guard type == .custom else {
            UIView.transition(with: bgImgView, duration: 0.5, options: .transitionCrossDissolve) {
                self.bgImgView.image = type.bgImage
            }
            Asyncs.async {
                BgImageType.removeCustomBgImageData()
                self.bgImageType = type.rawValue
            }
            return
        }
        
        let image = data.map { UIImage(data: $0) } ?? nil
        UIView.transition(with: bgImgView, duration: 0.5, options: .transitionCrossDissolve) {
            self.bgImgView.image = image
        }
        
        Asyncs.async {
            BgImageType.removeCustomBgImageData()
            if image != nil, let data, BgImageType.cacheCustomBgImageData(data) {
                self.bgImageType = BgImageType.custom.rawValue
            } else {
                self.bgImageType = BgImageType.null.rawValue
            }
        }
    }
}

// MARK: - <DSDetailColorBoardDelegate>
extension ViewController: DSDetailColorBoardDelegate {
    func detailColorBoardDidChooseOriginColor() {
        if isTransparentGridBgColor {
            bgColor = .transparentGrid
        } else {
            bgColor = originColor
        }
    }
    
    func detailColorBoardDidChooseDefaultColor() {
        isTransparentGridBgColor = false
        bgColor = .defaultBgColor
    }
    
    func detailColorBoardDidChooseTransparentGridColor() {
        isTransparentGridBgColor = true
        bgColor = .transparentGrid
    }
    
    func detailColorBoardDidChooseCustomColor(_ color: UIColor) {
        isTransparentGridBgColor = false
        bgColor = color
    }
}
