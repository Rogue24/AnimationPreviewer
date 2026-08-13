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
    
    private lazy var dropInteraction = UIDropInteraction(delegate: self)
    
    /// 待加载的外部文件（双击文件、拖到Dock图标、右键「打开方式」）
    ///
    /// 冷启动时`SceneDelegate`拿到URL的时机早于`viewDidLoad`，先存下来延后消费，
    /// 免得和「恢复上次动画」的异步回调打架
    var pendingFileURL: URL?
    
    /// 本窗口是否已经接手过外部文件，用来取消「延迟恢复上次动画」
    private var didLoadExternalFile = false
    
    /// 当前画面是不是启动时从缓存恢复的「上次的残留」
    ///
    /// 双击进来的文件会顶掉这种画面；用户主动打开的动画则不该被无声清掉
    private var isShowingRestoredCache = false
    
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
    
    private lazy var paletteBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(named: "color_palette_icon")?.withRenderingMode(.alwaysOriginal), for: .normal)
        btn.alpha = 0.8
        return btn
    }()
    
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
    
    private lazy var trashBtn: UIButton = {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium, scale: .default)
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "trash", withConfiguration: config), for: .normal)
        btn.tintColor = UIColor(white: 1, alpha: 0.8)
        return btn
    }()
    
    // ================ 右边区域 ================
    private let imageView = AnimationImageView()
    
    private lazy var imgBtn: UIButton = {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium, scale: .default)
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "square.and.arrow.down.on.square", withConfiguration: config), for: .normal)
        btn.tintColor = UIColor(white: 1, alpha: 0.8)
        return btn
    }()
    
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
        // 只准备目录，先别碰缓存：要不要解析缓存，得等下面判断完
        AnimationStore.prepare { [weak self] in
            self?.loadInitialAnimation()
        }
    }
    
    deinit {
        // 本窗口占用的缓存目录可以回收了
        AnimationStore.releaseCacheDir(for: self)
        AnimationStore.collectGarbage()
    }
    
    // 窗口变化
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        JPHUD.positionHUD()
    }
}

// MARK: - 首次加载动画（外部点击打开的动画 or 上次退出前最后加载的动画）
private extension ViewController {
    /// 决定窗口初始显示什么：双击进来的文件，还是上次留下的动画
    func loadInitialAnimation() {
        // 冷启动双击：URL已经在手上了
        if let fileURL = pendingFileURL {
            pendingFileURL = nil
            openAnimationFile(at: fileURL)
            return
        }
        
        // 顺手回收上次运行残留的缓存目录
        AnimationStore.collectGarbage()
        
        // 双击文件启动时，系统建场景的那一刻还不知道有文件要开，
        // URL要晚一步才通过`scene(_:openURLContexts:)`送来（实测20~120ms不定），
        // 所以先等一个窗口期再决定，期间来了文件就以文件为准。
        //
        // 等这一下的关键收益不只是不显示上次的动画：解析缓存和加载双击的文件
        // 共用同一条串行队列，抢先解析缓存会把双击的文件堵在后面，
        // 文件越大、旧动画就在画面上停留越久。
        Asyncs.mainDelay(0.3) { [weak self] in
            guard let self, !self.didLoadExternalFile else { return }
            self.restoreLastAnimation()
        }
    }
    
    /// 恢复上次留下的动画（只有确认不是双击文件启动时才走到这里）
    func restoreLastAnimation() {
        AnimationStore.loadCache { [weak self] result in
            // 解析期间也可能来了文件，再确认一次
            guard let result, let self, !self.didLoadExternalFile else { return }
            self._replaceAnimation(result.store, cacheDirName: result.cacheDirName, isRestoredCache: true)
        }
    }
}

// MARK: - 打开外部文件（双击文件、拖到Dock图标、右键「打开方式」）
extension ViewController {
    func openAnimationFile(at url: URL) {
        // 读取失败也算「接手过」：用户明确双击了文件，
        // 此时该显示错误，而不是莫名其妙冒出上次的动画。
        didLoadExternalFile = true
        
        // 「上次的残留」即将被这个文件取代，先清掉画面：
        // 万一文件读取或解析失败，也不该让用户对着上次的动画，
        // 误以为打开的就是自己双击的那个。
        if isShowingRestoredCache {
            _replaceAnimation(nil)
        }
        
        // 沙盒下由系统递过来的文件是security-scoped资源，要成对开关才读得到
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped { url.stopAccessingSecurityScopedResource() }
        }
        
        guard let data = try? Data(contentsOf: url) else {
            JPHUD.showError(withStatus: "文件读取失败：\(url.lastPathComponent)")
            return
        }
        
        replaceAnimation(with: data, fileExtension: url.pathExtension.lowercased())
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
        stackView.addArrangedSubview(paletteBtn)
        stackView.addArrangedSubview(videoBtn)
        stackView.addArrangedSubview(volumeBtn)
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
        
        paletteBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        
        videoBtn.snp.makeConstraints { make in
            make.width.height.equalTo(51)
        }
        
        volumeBtn.snp.makeConstraints { make in
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
        paletteBtn.addTarget(self, action: #selector(paletteAction(_:)), for: .touchUpInside)
        videoBtn.addTarget(self, action: #selector(videoAction(_:)), for: .touchUpInside)
        volumeBtn.addTarget(self, action: #selector(volumeAction(_:)), for: .touchUpInside)
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
    
    // MARK: - 选择背景色
    @objc func paletteAction(_ sender: UIButton) {
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
    
    // MARK: - 制作视频
    @objc func videoAction(_ sender: UIButton) {
        JPHUD.show(withStatus: "视频制作中...")
        playView.makeVideo { progress in
            JPHUD.showProgress(progress, status: String(format: "视频制作中...%.0lf%%", progress * 100))
        } otherHandler: { text in
            JPHUD.show(withStatus: text)
        } completion: { result in
            switch result {
            case let .success(videoPath):
                Self.saveVideo(videoPath)
            case let .failure(reason):
                JPHUD.showError(withStatus: reason)
            }
        }
    }
    
    // MARK: - 声音设置
    @objc func volumeAction(_ sender: UIButton) {
        sender.isSelected.toggle()
        playView.isSVGAMute = sender.isSelected
    }
    
    // MARK: - 删除
    @objc func deleteAction(_ sender: UIButton) {
        guard playView.isEnable else { return }
        _replaceAnimation(nil)
        AnimationStore.clearCache()
    }
    
    // MARK: - 截取当前帧生成图片
    @objc func imageAction(_ sender: UIButton) {
        guard imageView.isEnable else { return }
        JPHUD.show()
        imageView.getCurrentImage() { result in
            switch result {
            case let .success(image):
                Self.saveImage(image)
            case let .failure(reason):
                JPHUD.showError(withStatus: reason)
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
                JPHUD.showSuccess(withStatus: "视频制作成功")
            } else {
                JPHUD.showError(withStatus: "视频保存失败")
            }
            File.manager.deleteFile(videoPath)
        }
    }
    
    static func saveImage(_ image: UIImage) {
        guard let data = image.pngData() else {
            JPHUD.showError(withStatus: "图片生成失败")
            return
        }
        
        MacChannel.shared().saveImage(data) { isSuccess in
            if isSuccess {
                JPHUD.dismiss()
            } else {
                JPHUD.showError(withStatus: "图片保存失败")
            }
        }
    }
}

// MARK: - 替换&移除·动画（Lottie/SVGA/GIF）
extension ViewController {
    func replaceAnimation(with data: Data, fileExtension ext: String?) {
        JPHUD.show(withStatus: "Loding...")
        AnimationStore.loadData(data, fileExtension: ext) { [weak self] store, cacheDirName in
            JPHUD.dismiss()
            self?._replaceAnimation(store, cacheDirName: cacheDirName)
        } failure: { error in
            JPHUD.showError(withStatus: error.localizedDescription)
        }
    }
    
    private func _replaceAnimation(_ store: AnimationStore?, cacheDirName: String? = nil, isRestoredCache: Bool = false) {
        // 除了「启动时恢复上次动画」，其余入口（双击文件、拖拽、菜单）都是用户主动行为
        isShowingRestoredCache = isRestoredCache
        
        // 登记本窗口正在用的缓存目录，别的窗口加载新动画时才不会把它清掉
        AnimationStore.retainCacheDir(cacheDirName, for: self)
        AnimationStore.collectGarbage()
        
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
        case let .dotLottie(file):
            let animation = file.animations.first?.animation
            volumeBtn.isHidden = true
            slider.minimumValue = Float(animation?.startFrame ?? 0)
            slider.maximumValue = Float(animation?.endFrame ?? 0)
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
