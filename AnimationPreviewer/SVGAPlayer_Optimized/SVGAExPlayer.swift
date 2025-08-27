//
//  SVGAExPlayer.swift
//  SVGAPlayer_Optimized
//
//  Created by aa on 2023/8/23.
//

import UIKit

@objc public
protocol SVGAExPlayerDelegate: NSObjectProtocol {
    // MARK: - 状态更新的回调
    
    /// 状态发生改变【状态更新】
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      statusDidChanged status: SVGAExPlayerStatus,
                      oldStatus: SVGAExPlayerStatus)
    
    
    // MARK: - 资源加载/解析相关回调
    
    /// SVGA未知来源【无法播放】
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      unknownSvga source: String)
    
    /// SVGA资源加载失败【无法播放】
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      dataLoadFailed error: Error)
    
    /// 加载的SVGA资源解析失败【无法播放】
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      dataParseFailed error: Error)
    
    /// 本地SVGA资源解析失败【无法播放】
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      assetParseFailed error: Error)
    
    /// SVGA资源无效【无法播放】
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      entity: SVGAVideoEntity,
                      invalid error: SVGAVideoEntityError)
    
    /// SVGA资源解析成功【可以播放】
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      parseDone entity: SVGAVideoEntity)
    
    
    // MARK: - 播放相关回调
    
    /// SVGA动画（本地/远程资源）已准备就绪即可播放【即将播放】
    /// - Parameters:
    ///   - isNewSource: 是否为新的资源（播放的资源需要加载、或者切换不同的`entity`则该值为`true`）
    ///   - fromFrame: 从第几帧开始
    ///   - isWillPlay: 是否即将开始播放
    ///   - resetHandler: 用于重置「从第几帧开始」和「是否开始播放」，如需更改调用该闭包并传入新值即可
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      readyForPlay isNewSource: Bool,
                      fromFrame: Int,
                      isWillPlay: Bool,
                      resetHandler: @escaping (_ newFrame: Int, _ isPlay: Bool) -> Void)
    
    /// SVGA动画执行回调【正在播放】
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationPlaying currentFrame: Int)
    
    /// SVGA动画完成一次播放【正在播放】
    /// - Note: 每一次动画的完成（无论是否循环播放）都会回调；若是「用户手动停止」则不会回调。
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationDidFinishedOnce loopCount: Int)
    
    /// SVGA动画完成所有播放【结束播放】
    /// - Note: 设置了`loops > 0`并且达到次数才会回调；若是「用户手动停止」或`loops = 0`则不会回调。
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationDidFinishedAll loopCount: Int)
    
    /// SVGA动画播放失败的回调【播放失败】
    /// - Note: 尝试播放时发现「没有SVGA资源」或「没有父视图」、SVGA资源只有一帧可播放帧（无法形成动画）就会触发该回调。
    @objc optional
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationPlayFailed error: SVGARePlayerPlayError)
}


// MARK: - 播放器状态
@objc public
enum SVGAExPlayerStatus: Int {
    case idle
    case loading
    case playing
    case paused
    case stopped
}


// MARK: - 播放器错误类型
public
enum SVGAExPlayerError: Swift.Error, LocalizedError {
    case unknownSource(_ svgaSource: String)
    case dataLoadFailed(_ svgaSource: String, _ error: Swift.Error)
    case dataParseFailed(_ svgaSource: String, _ error: Swift.Error)
    case assetParseFailed(_ svgaSource: String, _ error: Swift.Error)
    case entityInvalid(_ svgaSource: String, _ entity: SVGAVideoEntity, _ error: SVGAVideoEntityError)
    case playFailed(_ svgaSource: String, _ error: SVGARePlayerPlayError)
}

@objcMembers open
class SVGAExPlayer: SVGARePlayer {
    // MARK: - 自定义加载器/下载器/缓存键生成器
    public typealias LoadSuccess = (_ data: Data) -> Void
    public typealias LoadFailure = (_ error: Error) -> Void
    public typealias ForwardLoad = (_ svgaSource: String) -> Void
    
    public typealias Loader = (_ svgaSource: String,
                               _ success: @escaping LoadSuccess,
                               _ failure: @escaping LoadFailure,
                               _ forwardDownload: @escaping ForwardLoad,
                               _ forwardLoadAsset: @escaping ForwardLoad) -> Void
    
    public typealias Downloader = (_ svgaSource: String,
                                   _ success: @escaping LoadSuccess,
                                   _ failure: @escaping LoadFailure) -> Void
    
    public typealias CacheKeyGenerator = (_ svgaSource: String) -> String
    
    // MARK: 全局通用
    /// 自定义加载器（通用）
    public static var loader: Loader? = nil
    /// 自定义下载器（通用）
    public static var downloader: Downloader? = nil
    /// 自定义缓存键生成器（通用）
    public static var cacheKeyGenerator: CacheKeyGenerator? = nil
    
    // MARK: 自身使用
    /// 自定义加载器（自用）
    public var loader: Loader? = nil
    /// 自定义下载器（自用）
    public var downloader: Downloader? = nil
    /// 自定义缓存键生成器（自用）
    public var cacheKeyGenerator: CacheKeyGenerator? = nil
    
    // MARK: - 用户【手动调用】停止/清空的回调
    /// 执行`stop(...)`or`clean(...)` 完成后的闭包
    public typealias UserStopCompletion = (_ svgaSource: String, _ loopCount: Int) -> Void
    
    
    // MARK: - 可读可写属性
    
    /// 代理（代替原`delegate`）
    public weak var exDelegate: (any SVGAExPlayerDelegate)? = nil
    
    /// 是否带动画过渡（默认为`false`）
    /// - 为`true`则会在「更换SVGA」和「播放/停止」的场景中带有淡入淡出的效果
    public var isAnimated = false
    
    /// 是否在【非动画】状态时隐藏自身（默认为`true`）
    /// - 在`idle`/`loading`/`stopped`状态下会隐藏自身（播放中`playing`和暂停`paused`除外）
    /// - PS: 切换新的SVGA资源也会隐藏自身，因为状态会先变为`loading`，播放时自动展示。
    public var isHideWhenStopped = true {
        didSet {
            if status == .idle || status == .loading || status == .stopped {
                super.alpha = isHideWhenStopped ? 0 : 1
            } else {
                super.alpha = 1
            }
        }
    }
    
    /// 是否在【切换SVGA资源】前「立即」隐藏自身（默认为`false`）
    /// - 为`true`时，在【切换SVGA资源】前立即隐藏自身，不带淡入淡出的效果。
    /// - 为`false`时，如果`isAnimated`和`isHideWhenStopped`都为`true`时，先淡入淡出隐藏自身再【切换SVGA资源】，否则直接切换。
    /// - PS: 适用于滑动复用列表（`tableView`、`collectionView`）的场景，`cell`能快速清空旧内容，然后切换新内容。
    public var isHideWhenSwitchSourceWithoutAnimtion = false
    
    /// 展示的动画时间（当`isAnimated`为`true`时才有效，默认为`0.2`）
    public var showDuration: TimeInterval = 0.2
    
    /// 隐藏的动画时间（当`isAnimated`为`true`时才有效，默认为`0.2`）
    public var hideDuration: TimeInterval = 0.2
    
    /// 是否在【停止】状态时重置`loopCount`（默认为`true`）
    public var isResetLoopCountWhenStopped = true
    
    /// 是否启用内存缓存（主要是给到`SVGAParser`使用，默认为`false`）
    public var isEnabledMemoryCache = false
    
    
    // MARK: - 只读属性
    
    /// 是否打印调试日志（仅限`DEBUG`环境，默认为`false`）
    public var isDebugLog = false {
        willSet {
#if DEBUG
            guard isDebugLog != newValue, !newValue else { return }
            _debugLog("close debug log")
#endif
        }
        didSet {
#if DEBUG
            guard isDebugLog != oldValue, !oldValue else { return }
            _debugLog("open debug log")
#endif
        }
    }
    
    /// 调试信息（仅限`DEBUG`环境）
    public var debugInfo: String {
#if DEBUG
        "\(myProfile) svgaSource: \(svgaSource), status: \(status), startFrame: \(startFrame), endFrame: \(endFrame), currentFrame: \(currentFrame), loops: \(loops), loopCount:\(loopCount)"
#else
        ""
#endif
    }
    
    /// SVGA资源标识（路径）
    public private(set) var svgaSource: String = ""
    
    /// SVGA资源对象
    public private(set) var entity: SVGAVideoEntity?
    
    /// 当前状态
    public private(set) var status: SVGAExPlayerStatus = .idle {
        didSet {
            guard let exDelegate, status != oldValue else { return }
            exDelegate.svgaExPlayer?(self, statusDidChanged: status, oldStatus: oldValue)
        }
    }
    /// 是否正在空闲
    public var isIdle: Bool { status == .idle }
    /// 是否正在加载
    public var isLoading: Bool { status == .loading }
    /// 是否正在播放
    public var isPlaying: Bool { status == .playing }
    /// 是否已暂停
    public var isPaused: Bool { status == .paused }
    /// 是否已停止
    public var isStopped: Bool { status == .stopped }
    
    
    // MARK: - 私有属性
    
#if DEBUG
    /// 标识（用于日志打印）
    private var myProfile: String {
        "[" + String(describing: Self.self) + "_" + String(format: "%p", self) + "]"
    }
#endif
    
    /// 加载回调标识（异步）
    private var _loadTag: UUID?
    /// 隐藏回调标识（异步）
    private var _hideTag: UUID?
    
    /// 用于记录异步回调时的停止情景（用于如果在SVGA资源加载过程中停止了动画，加载完成时还原停止的场景）
    private var _willStopScene: SVGARePlayerStoppedScene? = nil
    /// 用于记录异步回调时的启动帧数
    private var _willFromFrame = 0
    /// 用于记录异步回调时是否自动播放
    private var _isWillAutoPlay = false
    
    
    // MARK: - Initializer & Override
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        _baseSetup()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        _baseSetup()
    }
    
    public override func willMove(toSuperview newSuperview: UIView?) {
        let isNullSuperview = newSuperview == nil
        
        if isNullSuperview {
            _debugLog("没有父视图了，即将停止并清空图层")
            _loadTag = nil
            _hideTag = nil
        }
        
        /// 当`newSuperview`为空，父类方法中会停止动画并清空图层：
        /// 内部调用`[self stopAnimation:SVGARePlayerStoppedScene_ClearLayers];`
        super.willMove(toSuperview: newSuperview)
        
        /// 停止并清空图层后，刷新状态
        if isNullSuperview {
            _afterStopSVGA()
        }
    }
    
    /// 请尽量不要在外部修改`alpha`，因为内部会自行修改`alpha`，以此控制「展示」与「隐藏」，并实现淡入淡出的效果。
    /// - 注意：SVGA停止播放后，若`isHideWhenStopped`为`false`则`alpha`会被设置为`1`，反之为`0`（所以可能与外部修改的值不符）。
    /// - 如需修改请确保`isAnimated`为`false`。
    public override var alpha: CGFloat {
        get { super.alpha }
        @available(*, deprecated, message: "请不要修改此属性（内部会自行修改以此控制视图的展示与隐藏），请使用其他替代方案。")
        set { super.alpha = newValue }
    }
    
    /// 原代理已被`self`遵守，请使用`exDelegate`来进行监听
    @available(*, deprecated, message: "delegate不提供外部使用，请使用exDelegate")
    public override var delegate: (any SVGARePlayerDelegate)? {
        get { super.delegate }
        set { super.delegate = self }
    }
    
    deinit {
        _debugLog("死亡")
    }
    
    
    // MARK: - 初始化设置
    private func _baseSetup() {
        _debugLog("出生")
        
        super.alpha = isHideWhenStopped ? 0 : 1
        super.delegate = self
        
        userStoppedScene = .stepToLeading
        finishedAllScene = .stepToTrailing
    }
    
    /// 打印调试日志（仅限DEBUG环境）
    private func _debugLog(_ str: String) {
#if DEBUG
        guard isDebugLog else { return }
        print("\(myProfile) \(str)")
#endif
    }
}


// MARK: - 与父类互斥的属性和方法
/**
 * 原代理已被`self`遵守，请使用`exDelegate`来进行监听
 *  `@property (nonatomic, weak) id<SVGAOptimizedPlayerDelegate> delegate;`
 *
 * 内部会自行修改`alpha`，以此控制「展示」与「隐藏」，并实现淡入淡出的效果，因此请尽量不要在外部修改`alpha`
 *  `@property (nonatomic) CGFloat alpha;`
 *
 * 不允许外部设置`videoItem`，内部已为其设置
 *  `@property (nonatomic, strong, nullable) SVGAVideoEntity *videoItem;`
 *  `- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem currentFrame:(NSInteger)currentFrame;`
 *  `- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem startFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame;`
 *  `- (void)setVideoItem:(nullable SVGAVideoEntity *)videoItem startFrame:(NSInteger)startFrame endFrame:(NSInteger)endFrame currentFrame:(NSInteger)currentFrame;`
 *
 * 与原播放逻辑互斥，请使用`play`开头的API进行加载和播放
 *  `- (BOOL)startAnimation;`
 *  `- (BOOL)stepToFrame:(NSInteger)frame;`
 *  `- (BOOL)stepToFrame:(NSInteger)frame andPlay:(BOOL)andPlay;`
 *
 * 与原播放逻辑互斥，请使用`pause()`进行暂停
 *  `- (void)pauseAnimation;`
 *
 * 与原播放逻辑互斥，请使用`stop(with scene: SVGARePlayerStoppedScene)`进行停止
 *  `- (void)stopAnimation;`
 *  `- (void)stopAnimation:(SVGARePlayerStoppedScene)scene;`
 */


// MARK: - 失败回调
private extension SVGAExPlayer {
    func _failedCallback(_ error: SVGAExPlayerError) {
        guard let exDelegate else { return }
        switch error {
        case let .unknownSource(s):
            exDelegate.svgaExPlayer?(self, unknownSvga: s)
            
        case let .dataLoadFailed(s, e):
            exDelegate.svgaExPlayer?(self, svga: s, dataLoadFailed: e)
            
        case let .dataParseFailed(s, e):
            exDelegate.svgaExPlayer?(self, svga: s, dataParseFailed: e)
            
        case let .assetParseFailed(s, e):
            exDelegate.svgaExPlayer?(self, svga: s, assetParseFailed: e)
            
        case let .entityInvalid(s, entity, error):
            exDelegate.svgaExPlayer?(self, svga: s, entity: entity, invalid: error)
            
        case let .playFailed(s, e):
            exDelegate.svgaExPlayer?(self, svga: s, animationPlayFailed: e)
        }
    }
}


// MARK: - 加载SVGA
private extension SVGAExPlayer {
    func _loadSVGA(_ svgaSource: String, fromFrame: Int, isAutoPlay: Bool) {
        if svgaSource.count == 0 {
            _cleanAll()
            _failedCallback(.unknownSource(svgaSource))
            return
        }
        
        if self.svgaSource == svgaSource, entity != nil {
            _loadTag = nil
            _debugLog("已经有了，不用加载 \(svgaSource)")
            resetLoopCount()
            _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: false)
            return
        }
        
        // 记录最新状态
        _willFromFrame = fromFrame
        _isWillAutoPlay = isAutoPlay
        
        guard !isLoading else {
            _debugLog("已经在加载了，不要重复加载 \(svgaSource)")
            return
        }
        
        _debugLog("开始加载 \(svgaSource) - 先清空当前动画")
        status = .loading
        
        let newTag = UUID()
        _loadTag = newTag
        
        stopAnimation(.clearLayers)
        clearDynamicObjects()
        videoItem = nil
        
        guard let loader = self.loader ?? Self.loader else {
            if svgaSource.hasPrefix("http://") || svgaSource.hasPrefix("https://") {
                _downloadData(svgaSource, newTag, isAutoPlay)
            } else {
                _parseFromAsset(svgaSource, newTag, isAutoPlay)
            }
            return
        }
        
        let success = _getLoadSuccess(svgaSource, newTag, isAutoPlay)
        let failure = _getLoadFailure(svgaSource, newTag, isAutoPlay)
        let forwardDownload: ForwardLoad = { [weak self] in self?._downloadData($0, newTag, isAutoPlay) }
        let forwardLoadAsset: ForwardLoad = { [weak self] in self?._parseFromAsset($0, newTag, isAutoPlay) }
        loader(svgaSource, success, failure, forwardDownload, forwardLoadAsset)
    }
    
    func _getLoadSuccess(_ svgaSource: String, _ loadTag: UUID, _ isAutoPlay: Bool) -> LoadSuccess {
        return { [weak self] data in
            guard let self, self._loadTag == loadTag else { return }
            let newTag = UUID()
            self._loadTag = newTag
            
            self._debugLog("外部加载SVGA - 成功 \(svgaSource)")
            self._parseFromData(data, svgaSource, newTag, isAutoPlay)
        }
    }
    
    func _getLoadFailure(_ svgaSource: String, _ loadTag: UUID, _ isAutoPlay: Bool) -> LoadFailure {
        return { [weak self] error in
            guard let self, self._loadTag == loadTag else { return }
            self._loadTag = nil
            
            self._debugLog("外部加载SVGA - 失败 \(svgaSource)")
            self._cleanAll()
            self._failedCallback(.dataLoadFailed(svgaSource, error))
        }
    }
}


// MARK: - 下载/解析 ~> Data/Asset
private extension SVGAExPlayer {
    func _downloadData(_ svgaSource: String,
                       _ loadTag: UUID,
                       _ isAutoPlay: Bool) {
        guard let downloader = self.downloader ?? Self.downloader else {
            _parseFromUrl(svgaSource, loadTag, isAutoPlay)
            return
        }
        
        let success = _getLoadSuccess(svgaSource, loadTag, isAutoPlay)
        let failure = _getLoadFailure(svgaSource, loadTag, isAutoPlay)
        downloader(svgaSource, success, failure)
    }
    
    func _parseFromUrl(_ svgaSource: String,
                       _ loadTag: UUID,
                       _ isAutoPlay: Bool) {
        guard let url = URL(string: svgaSource) else {
            _cleanAll()
            _failedCallback(.unknownSource(svgaSource))
            return
        }
        
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: url) { [weak self] entity in
            guard let self, self._loadTag == loadTag else { return }
            self._loadTag = nil
            
            if let entity {
                self._debugLog("内部下载远程SVGA - 成功 \(svgaSource)")
                self._parseDone(svgaSource, entity)
                return
            }
            
            self._debugLog("内部下载远程SVGA - 成功，但资源为空")
            self._cleanAll()
            let error = NSError(domain: "SVGAExPlayer", code: -3, userInfo: [NSLocalizedDescriptionKey: "下载的SVGA资源为空"])
            self._failedCallback(.dataLoadFailed(svgaSource, error))
            
        } failureBlock: { [weak self] e in
            guard let self, self._loadTag == loadTag else { return }
            self._loadTag = nil
            
            self._debugLog("内部下载远程SVGA - 失败 \(svgaSource)")
            self._cleanAll()
            let error = e ?? NSError(domain: "SVGAExPlayer", code: -2, userInfo: [NSLocalizedDescriptionKey: "SVGA下载失败"])
            self._failedCallback(.dataLoadFailed(svgaSource, error))
        }
    }
    
    func _parseFromData(_ data: Data,
                        _ svgaSource: String,
                        _ loadTag: UUID,
                        _ isAutoPlay: Bool) {
        let cacheKey = cacheKeyGenerator?(svgaSource) ?? (Self.cacheKeyGenerator?(svgaSource) ?? svgaSource)
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: data, cacheKey: cacheKey) { [weak self] entity in
            guard let self, self._loadTag == loadTag else { return }
            self._loadTag = nil
            
            self._debugLog("解析远程SVGA - 成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self._loadTag == loadTag else { return }
            self._loadTag = nil
            
            self._debugLog("解析远程SVGA - 失败 \(svgaSource) \(error)")
            self._cleanAll()
            self._failedCallback(.dataParseFailed(svgaSource, error))
        }
    }
    
    func _parseFromAsset(_ svgaSource: String,
                         _ loadTag: UUID,
                         _ isAutoPlay: Bool) {
        // PS：parser内部会自动补上".svga"后缀，如果本身就有该后缀，那就去掉再给parser
        var source = svgaSource
        var components = source.components(separatedBy: ".")
        if components.count > 1 {
            components.removeAll { $0 == "svga" }
            source = components.joined(separator: ".")
        }
        
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(withNamed: source, in: nil) { [weak self] entity in
            guard let self, self._loadTag == loadTag else { return }
            self._loadTag = nil
            
            self._debugLog("解析本地SVGA - 成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self._loadTag == loadTag else { return }
            self._loadTag = nil
            
            self._debugLog("解析本地SVGA - 失败 \(svgaSource) \(error)")
            self._cleanAll()
            self._failedCallback(.assetParseFailed(svgaSource, error))
        }
    }
    
    func _checkEntityIsInvalid(_ entity: SVGAVideoEntity, for svgaSource: String) -> Bool {
        let error = entity.entityError
        guard error != .none else { return false }
        _cleanAll()
        _failedCallback(.entityInvalid(svgaSource, entity, error))
        return true
    }
    
    func _parseDone(_ svgaSource: String, _ entity: SVGAVideoEntity) {
        guard !_checkEntityIsInvalid(entity, for: svgaSource) else { return }
        guard self.svgaSource == svgaSource else { return }
        self.entity = entity
        videoItem = entity
        exDelegate?.svgaExPlayer?(self, svga: svgaSource, parseDone: entity)
        // 如果SVGA资源加载过程中停止了动画，则还原停止的场景
        if let scene = _willStopScene {
            _stopSVGA(scene)
        } else {
            _playSVGA(fromFrame: _willFromFrame, isAutoPlay: _isWillAutoPlay, isNew: true)
        }
    }
}


// MARK: - 播放 | 停止 | 清空
private extension SVGAExPlayer {
    func _playSVGA(fromFrame: Int, isAutoPlay: Bool, isNew: Bool) {
        var kFrame = fromFrame
        var isPlay = isAutoPlay
        
        if let exDelegate, let readyForPlay = exDelegate.svgaExPlayer(_:svga:readyForPlay:fromFrame:isWillPlay:resetHandler:) {
            readyForPlay(self, svgaSource, isNew, fromFrame, isAutoPlay, {
                kFrame = $0
                isPlay = $1
            })
        }
        
        guard step(toFrame: kFrame, andPlay: isPlay) else { return }
        
        if isPlay {
            _debugLog("成功跳至特定帧\(kFrame)，并且开始播放 - 播放 \(svgaSource)")
            status = .playing
        } else {
            _debugLog("成功跳至特定帧\(kFrame)，并且不播放 - 暂停 \(svgaSource)")
            status = .paused
        }
        
        _show()
    }
    
    func _stopSVGA(_ scene: SVGARePlayerStoppedScene) {
        // 只是停止动画，不会中断SVGA资源的加载，记录加载完成后的停止场景
        _willStopScene = _loadTag == nil ? nil : scene
        stopAnimation(scene)
        _afterStopSVGA()
    }
    
    func _afterStopSVGA() {
        if status != .idle {
            _debugLog("停止了 - 清空图层/回到开头or结尾处")
            status = .stopped
        } else {
            _debugLog("停止了？- 本来就空空如也")
        }
        
        if isResetLoopCountWhenStopped {
            resetLoopCount()
        }
        
        super.alpha = isHideWhenStopped ? 0 : 1
    }
    
    func _cleanAll() {
        _debugLog("清空一切")
        
        _loadTag = nil
        _hideTag = nil
        
        _willStopScene = nil
        
        stopAnimation(.clearLayers)
        clearDynamicObjects()
        videoItem = nil
        
        svgaSource = ""
        entity = nil
        status = .idle
        
        super.alpha = isHideWhenStopped ? 0 : 1
    }
}


// MARK: - 展示 | 隐藏
private extension SVGAExPlayer {
    func _show() {
        _hideTag = nil
        layer.removeAnimation(forKey: "opacity")
        
        guard super.alpha < 1, isAnimated else {
            super.alpha = 1
            return
        }

        UIView.animate(withDuration: showDuration) {
            super.alpha = 1
        }
    }
    
    func _hideForSwitchSourceIfNeeded(completion: @escaping () -> Void) {
        _hideTag = nil
        layer.removeAnimation(forKey: "opacity")
        
        if isHideWhenSwitchSourceWithoutAnimtion {
            super.alpha = 0
            completion()
            return
        }
        
        guard isHideWhenStopped else {
            completion()
            return
        }
        
        __hide(animated: isAnimated, completion: completion)
    }
    
    func _hideForEndAnimationIfNeeded(completion: @escaping () -> Void) {
        _hideTag = nil
        layer.removeAnimation(forKey: "opacity")
        
        guard isHideWhenStopped else {
            completion()
            return
        }
        
        __hide(animated: isAnimated, completion: completion)
    }
    
    func __hide(animated: Bool, completion: @escaping () -> Void) {
        guard animated else {
            super.alpha = 0
            completion()
            return
        }
        
        let newTag = UUID()
        _hideTag = newTag
        
        UIView.animate(withDuration: hideDuration) {
            super.alpha = 0
        } completion: { _ in
            guard self._hideTag == newTag else { return }
            self._hideTag = nil
            completion()
        }
    }
}


// MARK: - <SVGARePlayerDelegate>
extension SVGAExPlayer: SVGARePlayerDelegate {
    public func svgaRePlayer(_ player: SVGARePlayer, animationPlaying currentFrame: Int) {
        exDelegate?.svgaExPlayer?(self, svga: svgaSource, animationPlaying: currentFrame)
    }
    
    public func svgaRePlayer(_ player: SVGARePlayer, animationDidFinishedOnce loopCount: Int) {
        exDelegate?.svgaExPlayer?(self, svga: svgaSource, animationDidFinishedOnce: loopCount)
    }
    
    public func svgaRePlayer(_ player: SVGARePlayer, animationDidFinishedAll loopCount: Int) {
        let svgaSource = self.svgaSource
        _debugLog("全部播完了：\(svgaSource) - \(loopCount)")
        _hideForEndAnimationIfNeeded { [weak self] in
            guard let self else { return }
            self._afterStopSVGA()
            self.exDelegate?.svgaExPlayer?(self, svga: svgaSource, animationDidFinishedAll: loopCount)
        }
    }
    
    public func svgaRePlayer(_ player: SVGARePlayer, animationPlayFailed error: SVGARePlayerPlayError) {
        switch error {
        case .onlyOnePlayableFrame:
            _debugLog("只有一帧可播放帧，无法形成动画：\(svgaSource)")
            status = .paused
        case .nullSuperview:
            _debugLog("父视图是空的，无法播放：\(svgaSource)")
            _afterStopSVGA()
        default:
            _debugLog("SVGA资源是空的，无法播放：\(svgaSource)")
            _cleanAll()
        }
        _failedCallback(.playFailed(svgaSource, error))
    }
}


// MARK: - API
public extension SVGAExPlayer {
    // MARK: Play
    /// 播放目标SVGA
    /// - Parameters:
    ///   - svgaSource: SVGA资源路径
    ///   - fromFrame: 从第几帧开始
    ///   - isAutoPlay: 是否自动开始播放
    func play(_ svgaSource: String, fromFrame: Int, isAutoPlay: Bool) {
        _willStopScene = nil // 取消原本加载完成后的停止操作
        guard self.svgaSource != svgaSource else {
            _loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        _loadTag = nil
        
        self.svgaSource = svgaSource
        entity = nil
        
        status = .idle
        _hideForSwitchSourceIfNeeded { [weak self] in
            guard let self else { return }
            self._loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
        }
    }
    
    /// 播放目标SVGA（从头开始、自动播放）
    /// 如果设置过`startFrame`或`endFrame`，则从`leadingFrame`开始
    /// - Parameters:
    ///   - svgaSource: SVGA资源路径
    func play(_ svgaSource: String) {
        play(svgaSource, fromFrame: leadingFrame, isAutoPlay: true)
    }
    
    /// 播放目标SVGA
    /// - Parameters:
    ///   - entity: SVGA资源（`svgaSource`为`entity`的内存地址）
    ///   - fromFrame: 从第几帧开始
    ///   - isAutoPlay: 是否自动开始播放
    func play(with entity: SVGAVideoEntity, fromFrame: Int, isAutoPlay: Bool) {
        _loadTag = nil // 取消当前加载
        _willStopScene = nil // 取消原本加载完成后的停止操作
        
        let memoryAddress = unsafeBitCast(entity, to: Int.self)
        let svgaSource = String(format: "%p", memoryAddress)
        guard !_checkEntityIsInvalid(entity, for: svgaSource) else { return }
        
        if self.svgaSource == svgaSource, self.entity != nil {
            _debugLog("已经有了，不用加载 \(svgaSource)")
            resetLoopCount()
            _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: false)
            return
        }
        
        self.svgaSource = svgaSource
        self.entity = nil
        
        status = .idle
        _hideForSwitchSourceIfNeeded { [weak self] in
            guard let self else { return }
            
            self.stopAnimation(.clearLayers)
            self.clearDynamicObjects()
            self.videoItem = entity
            self.entity = entity
            
            self._playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: true)
        }
    }
    
    /// 播放目标SVGA（从头开始、自动播放）
    /// 如果设置过`startFrame`或`endFrame`，则从`leadingFrame`开始
    /// - Parameters:
    ///   - entity: SVGA资源（`svgaSource`为`entity`的内存地址）
    func play(with entity: SVGAVideoEntity) {
        play(with: entity, fromFrame: leadingFrame, isAutoPlay: true)
    }
    
    /// 播放当前SVGA（从当前所在帧开始）
    func play() {
        _willStopScene = nil // 取消原本加载完成后的停止操作
        switch status {
        case .playing: return
        case .paused:
            if startAnimation() {
                _debugLog("继续播放")
                status = .playing
            }
        default:
            play(fromFrame: currentFrame, isAutoPlay: true)
        }
    }
    
    /// 播放当前SVGA
    /// - Parameters:
    ///  - fromFrame: 从第几帧开始
    ///  - isAutoPlay: 是否自动开始播放
    func play(fromFrame: Int, isAutoPlay: Bool) {
        guard svgaSource.count > 0 else { return }
        _willStopScene = nil // 取消原本加载完成后的停止操作
        
        if entity == nil {
            _debugLog("播放 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        _debugLog("播放 - 无需加载 继续")
        _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: false)
    }
    
    // MARK: Pause
    /// 暂停
    func pause() {
        guard svgaSource.count > 0 else { return }
        _willStopScene = nil // 取消原本加载完成后的停止操作
        guard isPlaying else {
            _isWillAutoPlay = false
            return
        }
        _debugLog("暂停")
        pauseAnimation()
        status = .paused
    }
    
    // MARK: Reset
    /// 重置当前SVGA（回到开头，重置完成次数）
    /// 如果设置过`startFrame`或`endFrame`，则从`leadingFrame`开始
    /// - Parameters:
    ///   - isAutoPlay: 是否自动开始播放
    func reset(isAutoPlay: Bool = true) {
        guard svgaSource.count > 0 else { return }
        _willStopScene = nil // 取消原本加载完成后的停止操作
        resetLoopCount() // 重置完成次数
        
        if entity == nil {
            _debugLog("重播 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: leadingFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        _debugLog("重播 - 无需加载")
        _playSVGA(fromFrame: leadingFrame, isAutoPlay: isAutoPlay, isNew: false)
    }
    
    // MARK: Stop & Clean
    /// 停止
    /// - Parameters:
    ///   - scene: 停止后的场景
    ///     - clearLayers: 清空图层
    ///     - stepToTrailing: 去到尾帧
    ///     - stepToLeading: 回到头帧
    func stop(then scene: SVGARePlayerStoppedScene, completion: UserStopCompletion? = nil) {
        guard svgaSource.count > 0 else { return }
        _willStopScene = scene // 记录加载完成后的停止场景，不中断SVGA资源的加载
        _hideForEndAnimationIfNeeded { [weak self] in
            guard let self else { return }
            let svgaSource = self.svgaSource
            let loopCount = self.loopCount
            self._stopSVGA(scene)
            completion?(svgaSource, loopCount)
        }
    }
    
    /// 停止
    /// - 等同于:`stop(then: userStoppedScene, completion: completion)`
    func stop(completion: UserStopCompletion? = nil) {
        stop(then: userStoppedScene, completion: completion)
    }
    
    /// 清空
    func clean(completion: UserStopCompletion? = nil) {
        guard svgaSource.count > 0 else { return }
        _loadTag = nil // 取消当前加载
        _willStopScene = nil // 取消原本加载完成后的停止操作
        _hideForEndAnimationIfNeeded { [weak self] in
            guard let self else { return }
            let svgaSource = self.svgaSource
            let loopCount = self.loopCount
            self._cleanAll()
            completion?(svgaSource, loopCount)
        }
    }
}
