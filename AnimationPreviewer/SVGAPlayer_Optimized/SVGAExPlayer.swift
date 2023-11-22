//
//  SVGAExPlayer.swift
//  SVGAPlayer_OptimizedDemo
//
//  Created by aa on 2023/8/23.
//

import UIKit

@objc public
protocol SVGAExPlayerDelegate: NSObjectProtocol {
    // MARK: - 状态更新的回调
    @objc optional
    /// 状态发生改变【状态更新】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      statusDidChanged status: SVGAExPlayerStatus,
                      oldStatus: SVGAExPlayerStatus)
    
    // MARK: - 资源加载/解析相关回调
    @objc optional
    /// SVGA未知来源【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      unknownSvga source: String)
    
    @objc optional
    /// SVGA资源加载失败【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      dataLoadFailed error: Error)
    
    @objc optional
    /// 加载的SVGA资源解析失败【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      dataParseFailed error: Error)
    
    @objc optional
    /// 本地SVGA资源解析失败【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      assetParseFailed error: Error)
    
    @objc optional
    /// SVGA资源无效【无法播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      entity: SVGAVideoEntity,
                      invalid error: SVGAVideoEntityError)
    
    @objc optional
    /// SVGA资源解析成功【可以播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      parseDone entity: SVGAVideoEntity)
    
    // MARK: - 播放相关回调
    @objc optional
    /// SVGA动画已准备好可播放【即将播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      readyForPlay isPlay: Bool)
    
    @objc optional
    /// SVGA动画执行回调【正在播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationPlaying currentFrame: Int)
    
    @objc optional
    /// SVGA动画完成一次播放【正在播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationDidFinishedOnce loopCount: Int)
    
    @objc optional
    /// SVGA动画结束（用户手动停止 or 设置了`loops`并且达到次数）【结束播放】
    func svgaExPlayer(_ player: SVGAExPlayer,
                      svga source: String,
                      animationDidFinishedAll loopCount: Int,
                      isUserStop: Bool)
    
    @objc optional
    /// SVGA动画播放失败的回调【播放失败】
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

@objcMembers public
class SVGAExPlayer: SVGARePlayer {
    // MARK: - 自定义加载器/下载器/缓存键生成器
    public typealias LoadSuccess = (_ data: Data) -> Void
    public typealias LoadFailure = (_ error: Error) -> Void
    public typealias ForwardLoad = (_ svgaSource: String) -> Void
    
    /// 自定义加载器
    public static var loader: Loader? = nil
    public typealias Loader = (_ svgaSource: String,
                               _ success: @escaping LoadSuccess,
                               _ failure: @escaping LoadFailure,
                               _ forwardDownload: @escaping ForwardLoad,
                               _ forwardLoadAsset: @escaping ForwardLoad) -> Void
    
    /// 自定义下载器
    public static var downloader: Downloader? = nil
    public typealias Downloader = (_ svgaSource: String,
                                   _ success: @escaping LoadSuccess,
                                   _ failure: @escaping LoadFailure) -> Void
    
    /// 自定义缓存键生成器
    public static var cacheKeyGenerator: CacheKeyGenerator? = nil
    public typealias CacheKeyGenerator = (_ svgaSource: String) -> String
    
    // MARK: - 可读可写属性
    /// 代理（代替原`delegate`）
    public weak var exDelegate: (any SVGAExPlayerDelegate)? = nil
    
    /// 是否带动画过渡（默认为`false`）
    /// - 为`true`则会在「更换SVGA」和「播放/停止」的场景中带有淡入淡出的效果
    public var isAnimated = false
    
    /// 是否在【非播放/暂停】状态时隐藏自身（默认为`false`）
    public var isHidesWhenStopped = false {
        didSet {
            if status == .idle || status == .loading || status == .stopped {
                alpha = isHidesWhenStopped ? 0 : 1
            } else {
                alpha = 1
            }
        }
    }
    
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
        "[SVGAExPlayer_\(String(format: "%p", self))] svgaSource: \(svgaSource), status: \(status), startFrame: \(startFrame), endFrame: \(endFrame), currentFrame: \(currentFrame), loops: \(loops), loopCount:\(loopCount)"
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
    /// 异步标识
    private var _asyncTag: UUID?
    /// 用于记录异步回调时的启动帧数
    private var _willFromFrame = 0
    /// 用于记录异步回调时是否自动播放
    private var _isWillAutoPlay = false
    
    // MARK: - 初始化
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
            _asyncTag = nil
        }
        
        /// 当`newSuperview`为空，父类方法中会停止动画并清空图层：
        /// 内部调用`[self stopAnimation:SVGARePlayerStoppedScene_ClearLayers];`
        super.willMove(toSuperview: newSuperview)
        
        /// 停止并清空图层后，刷新状态
        if isNullSuperview {
            _afterStopSVGA()
        }
    }
    
    deinit {
        _debugLog("死亡")
    }
    
    // MARK: - 私有方法
    private func _baseSetup() {
        delegate = self
        userStoppedScene = .stepToLeading
        finishedAllScene = .stepToTrailing
        isAnimated = false
        isHidesWhenStopped = false
        isResetLoopCountWhenStopped = true
        isEnabledMemoryCache = false
    }
    
    /// 打印调试日志（仅限DEBUG环境）
    private func _debugLog(_ str: String) {
#if DEBUG
        guard isDebugLog else { return }
        print("[SVGAExPlayer_\(String(format: "%p", self))] \(str)")
#endif
    }
}

// MARK: - 与父类互斥的属性和方法
/**
 * 原代理已被`self`遵守，请使用`myDelegate`来进行监听
 *  `@property (nonatomic, weak) id<SVGAOptimizedPlayerDelegate> delegate;`
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
 *  `- (void)stopAnimation:(BOOL)isClear;`
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
            _asyncTag = nil
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
        _asyncTag = newTag
        
        stopAnimation(.clearLayers)
        clearDynamicObjects()
        videoItem = nil
        
        guard let loader = Self.loader else {
            if svgaSource.hasPrefix("http://") || svgaSource.hasPrefix("https://") {
                _downLoadData(svgaSource, newTag, isAutoPlay)
            } else {
                _parseFromAsset(svgaSource, newTag, isAutoPlay)
            }
            return
        }
        
        let success = _getLoadSuccess(svgaSource, newTag, isAutoPlay)
        let failure = _getLoadFailure(svgaSource, newTag, isAutoPlay)
        let forwardDownload: ForwardLoad = { [weak self] in self?._downLoadData($0, newTag, isAutoPlay) }
        let forwardLoadAsset: ForwardLoad = { [weak self] in self?._parseFromAsset($0, newTag, isAutoPlay) }
        loader(svgaSource, success, failure, forwardDownload, forwardLoadAsset)
    }
    
    func _getLoadSuccess(_ svgaSource: String, _ asyncTag: UUID, _ isAutoPlay: Bool) -> LoadSuccess {
        return { [weak self] data in
            guard let self, self._asyncTag == asyncTag else { return }
            let newTag = UUID()
            self._asyncTag = newTag
            
            self._debugLog("外部加载SVGA - 成功 \(svgaSource)")
            self._parseFromData(data, svgaSource, newTag, isAutoPlay)
        }
    }
    
    func _getLoadFailure(_ svgaSource: String, _ asyncTag: UUID, _ isAutoPlay: Bool) -> LoadFailure {
        return { [weak self] error in
            guard let self, self._asyncTag == asyncTag else { return }
            self._asyncTag = nil
            
            self._debugLog("外部加载SVGA - 失败 \(svgaSource)")
            self._cleanAll()
            self._failedCallback(.dataLoadFailed(svgaSource, error))
        }
    }
}

// MARK: - 下载/解析 ~> Data/Asset
private extension SVGAExPlayer {
    func _downLoadData(_ svgaSource: String,
                       _ asyncTag: UUID,
                       _ isAutoPlay: Bool) {
        guard let downloader = Self.downloader else {
            _parseFromUrl(svgaSource, asyncTag, isAutoPlay)
            return
        }
        
        let success = _getLoadSuccess(svgaSource, asyncTag, isAutoPlay)
        let failure = _getLoadFailure(svgaSource, asyncTag, isAutoPlay)
        downloader(svgaSource, success, failure)
    }
    
    func _parseFromUrl(_ svgaSource: String,
                       _ asyncTag: UUID,
                       _ isAutoPlay: Bool) {
        guard let url = URL(string: svgaSource) else {
            _cleanAll()
            _failedCallback(.unknownSource(svgaSource))
            return
        }
        
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: url) { [weak self] entity in
            guard let self, self._asyncTag == asyncTag else { return }
            self._asyncTag = nil
            
            if let entity {
                self._debugLog("内部下载远程SVGA - 成功 \(svgaSource)")
                self._parseDone(svgaSource, entity)
                return
            }
            
            self._debugLog("内部下载远程SVGA - 成功，但资源为空")
            self._cleanAll()
            let error = NSError(domain: "SVGAParsePlayer", code: -3, userInfo: [NSLocalizedDescriptionKey: "下载的SVGA资源为空"])
            self._failedCallback(.dataLoadFailed(svgaSource, error))
            
        } failureBlock: { [weak self] e in
            guard let self, self._asyncTag == asyncTag else { return }
            self._asyncTag = nil
            
            self._debugLog("内部下载远程SVGA - 失败 \(svgaSource)")
            self._cleanAll()
            let error = e ?? NSError(domain: "SVGAParsePlayer", code: -2, userInfo: [NSLocalizedDescriptionKey: "SVGA下载失败"])
            self._failedCallback(.dataLoadFailed(svgaSource, error))
        }
    }
    
    func _parseFromData(_ data: Data,
                        _ svgaSource: String,
                        _ asyncTag: UUID,
                        _ isAutoPlay: Bool) {
        let cacheKey = Self.cacheKeyGenerator?(svgaSource) ?? svgaSource
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: data, cacheKey: cacheKey) { [weak self] entity in
            guard let self, self._asyncTag == asyncTag else { return }
            self._asyncTag = nil
            
            self._debugLog("解析远程SVGA - 成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self._asyncTag == asyncTag else { return }
            self._asyncTag = nil
            
            self._debugLog("解析远程SVGA - 失败 \(svgaSource) \(error)")
            self._cleanAll()
            self._failedCallback(.dataParseFailed(svgaSource, error))
        }
    }
    
    func _parseFromAsset(_ svgaSource: String,
                         _ asyncTag: UUID,
                         _ isAutoPlay: Bool) {
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(withNamed: svgaSource, in: nil) { [weak self] entity in
            guard let self, self._asyncTag == asyncTag else { return }
            self._asyncTag = nil
            
            self._debugLog("解析本地SVGA - 成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self._asyncTag == asyncTag else { return }
            self._asyncTag = nil
            
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
        _playSVGA(fromFrame: _willFromFrame, isAutoPlay: _isWillAutoPlay, isNew: true)
    }
}

// MARK: - 播放 | 停止 | 清空
private extension SVGAExPlayer {
    func _playSVGA(fromFrame: Int, isAutoPlay: Bool, isNew: Bool) {
        if isNew {
            exDelegate?.svgaExPlayer?(self, svga: svgaSource, readyForPlay: isAutoPlay)
        }
        
        guard step(toFrame: fromFrame, andPlay: isAutoPlay) else { return }
        
        if isAutoPlay {
            _debugLog("成功跳至特定帧\(fromFrame)，并且自动播放 - 播放 \(svgaSource)")
            status = .playing
        } else {
            _debugLog("成功跳至特定帧\(fromFrame)，并且不播放 - 暂停 \(svgaSource)")
            status = .paused
        }
        
        _show()
    }
    
    func _stopSVGA(_ scene: SVGARePlayerStoppedScene) {
        _asyncTag = nil
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
        
        alpha = isHidesWhenStopped ? 0 : 1
    }
    
    func _cleanAll() {
        _debugLog("清空一切")
        _asyncTag = nil
        
        stopAnimation(.clearLayers)
        clearDynamicObjects()
        videoItem = nil
        
        svgaSource = ""
        entity = nil
        status = .idle
        
        alpha = isHidesWhenStopped ? 0 : 1
    }
}

// MARK: - 展示 | 隐藏
private extension SVGAExPlayer {
    func _show() {
        guard alpha < 1, isAnimated else {
            alpha = 1
            return
        }

        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }
    
    func _hideIfNeeded(completion: @escaping () -> Void) {
        if isHidesWhenStopped, isAnimated {
            let newTag = UUID()
            _asyncTag = newTag
            
            UIView.animate(withDuration: 0.2) {
                self.alpha = 0
            } completion: { _ in
                guard self._asyncTag == newTag else { return }
                self._asyncTag = nil
                completion()
            }
        } else {
            if isHidesWhenStopped { alpha = 0 }
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
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._afterStopSVGA()
            self.exDelegate?.svgaExPlayer?(self, svga: svgaSource, animationDidFinishedAll: loopCount, isUserStop: false)
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
    /// 播放目标SVGA
    /// - Parameters:
    ///   - svgaSource: SVGA资源路径
    ///   - fromFrame: 从第几帧开始
    ///   - isAutoPlay: 是否自动开始播放
    func play(_ svgaSource: String, fromFrame: Int, isAutoPlay: Bool) {
        guard self.svgaSource != svgaSource else {
            _loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        _asyncTag = nil
        
        self.svgaSource = svgaSource
        entity = nil
        
        status = .idle
        _hideIfNeeded { [weak self] in
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
        _asyncTag = nil
        
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
        _hideIfNeeded { [weak self] in
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
        
        if entity == nil {
            _debugLog("播放 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        _debugLog("播放 - 无需加载 继续")
        _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay, isNew: false)
    }
    
    /// 重置当前SVGA（回到开头，重置完成次数）
    /// 如果设置过`startFrame`或`endFrame`，则从`leadingFrame`开始
    /// - Parameters:
    ///   - isAutoPlay: 是否自动开始播放
    func reset(isAutoPlay: Bool = true) {
        guard svgaSource.count > 0 else { return }
        resetLoopCount()
        
        if entity == nil {
            _debugLog("重播 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: leadingFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        _debugLog("重播 - 无需加载")
        _playSVGA(fromFrame: leadingFrame, isAutoPlay: isAutoPlay, isNew: false)
    }
    
    /// 暂停
    func pause() {
        guard svgaSource.count > 0 else { return }
        guard isPlaying else {
            _isWillAutoPlay = false
            return
        }
        _debugLog("暂停")
        pauseAnimation()
        status = .paused
    }
    
    /// 停止
    /// - Parameters:
    ///   - scene: 停止后的场景
    ///     - clearLayers: 清空图层
    ///     - stepToTrailing: 去到尾帧
    ///     - stepToLeading: 回到头帧
    func stop(with scene: SVGARePlayerStoppedScene) {
        guard svgaSource.count > 0 else { return }
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._stopSVGA(scene)
            self.exDelegate?.svgaExPlayer?(self, svga: self.svgaSource,
                                           animationDidFinishedAll: self.loopCount,
                                           isUserStop: true)
        }
    }
    
    /// 停止
    /// - 等同于:`stop(with scene: userStoppedScene)`
    func stop() {
        stop(with: userStoppedScene)
    }
    
    /// 清空
    func clean() {
        guard svgaSource.count > 0 else { return }
        let needCallback = status != .stopped
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._cleanAll()
            guard needCallback else { return }
            self.exDelegate?.svgaExPlayer?(self, svga: self.svgaSource,
                                           animationDidFinishedAll: self.loopCount,
                                           isUserStop: true)
        }
    }
}
