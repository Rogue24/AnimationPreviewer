//
//  SVGAParsePlayer.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import UIKit
//import SVGAPlayer

@objc
protocol SVGAParsePlayerDelegate: NSObjectProtocol {
    @objc optional
    /// 状态发生改变
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         statusDidChanged status: SVGAParsePlayerStatus,
                         oldStatus: SVGAParsePlayerStatus)
    
    @objc optional
    /// SVGA未知来源
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         unknownSvga source: String)
    
    @objc optional
    /// SVGA资源加载失败
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         dataLoadFailed error: Error)
    
    @objc optional
    /// 加载的SVGA资源解析失败
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         dataParseFailed error: Error)
    
    @objc optional
    /// 本地SVGA资源解析失败
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         assetParseFailed error: Error)
    
    @objc optional
    /// SVGA资源解析成功
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         parseDone entity: SVGAVideoEntity)
    
    @objc optional
    /// SVGA动画执行回调
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         didAnimatedToFrame frame: Int)
    
    @objc optional
    /// SVGA动画结束
    func svgaParsePlayer(_ player: SVGAParsePlayer,
                         svga source: String,
                         didFinishedAnimation isUserStop: Bool)
}

@objc
enum SVGAParsePlayerStatus: Int {
    case idle
    case loading
    case playing
    case paused
    case stopped
}

enum SVGAParsePlayerError: Swift.Error, LocalizedError {
    case unknownSource(_ svgaSource: String)
    case dataLoadFailed(_ svgaSource: String, _ error: Swift.Error)
    case dataParseFailed(_ svgaSource: String, _ error: Swift.Error)
    case assetParseFailed(_ svgaSource: String, _ error: Swift.Error)
    
    var errorDescription: String? {
        switch self {
        case .unknownSource:
            return "未知来源"
        case let .dataLoadFailed(_, error): fallthrough
        case let .dataParseFailed(_, error): fallthrough
        case let .assetParseFailed(_, error):
            return (error as NSError).localizedDescription
        }
    }
}

@objcMembers
class SVGAParsePlayer: SVGAPlayer {
    typealias LoadSuccess = (_ data: Data) -> Void
    typealias LoadFailure = (_ error: Error) -> Void
    typealias ForwardLoad = (_ svgaSource: String) -> Void
    
    /// 自定义加载器
    static var loader: Loader? = nil
    typealias Loader = (_ svgaSource: String,
                        _ success: @escaping LoadSuccess,
                        _ failure: @escaping LoadFailure,
                        _ forwardDownload: @escaping ForwardLoad,
                        _ forwardLoadAsset: @escaping ForwardLoad) -> Void
    
    /// 自定义下载器
    static var downloader: Downloader? = nil
    typealias Downloader = (_ svgaSource: String,
                            _ success: @escaping LoadSuccess,
                            _ failure: @escaping LoadFailure) -> Void
    
    /// 打印调试日志
    static func debugLog(_ str: String) {
        print("jpjpjp \(str)")
    }
    
    private var asyncTag: UUID?
    private var isWillAutoPlay = false
    
    /// SVGA资源路径
    private(set) var svgaSource: String = ""
    
    /// SVGA资源
    private(set) var entity: SVGAVideoEntity?
    
    /// 动画时长
    var duration: TimeInterval { entity?.duration ?? 0 }
    
    /// 总帧数
    var frames: Int { Int(entity?.frames ?? 0) }
    
    /// 当前帧
    private(set) var currFrame: Int = 0
    
    /// 当前状态
    private(set) var status: SVGAParsePlayerStatus = .idle {
        didSet {
            guard let myDelegate, status != oldValue else { return }
            myDelegate.svgaParsePlayer?(self, statusDidChanged: status, oldStatus: oldValue)
        }
    }
    
    /// 是否正在空闲
    var isIdle: Bool { status == .idle }
    /// 是否正在加载
    var isLoading: Bool { status == .loading }
    /// 是否正在播放
    var isPlaying: Bool { status == .playing }
    /// 是否已暂停
    var isPaused: Bool { status == .paused }
    /// 是否已停止
    var isStopped: Bool { status == .stopped }
    
    /// 是否带动画过渡
    /// - 为`true`则会在「更换SVGA」和「播放/停止」的场景中带有淡入淡出的效果
    var isAnimated = false
    
    /// 是否在空闲/停止状态时隐藏自身
    var isHidesWhenStopped = false {
        didSet {
            if status == .idle || status == .loading || status == .stopped {
                alpha = isHidesWhenStopped ? 0 : 1
            } else {
                alpha = 1
            }
        }
    }
    
    /// 是否启用内存缓存（SVGAParser）
    var isEnabledMemoryCache = false
    
    /// 代理
    weak var myDelegate: (any SVGAParsePlayerDelegate)? = nil
    
    // MARK: - 初始化
    override init(frame: CGRect) {
        super.init(frame: frame)
        baseSetup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        baseSetup()
    }
    
    private func baseSetup() {
        delegate = self
    }
}

// MARK: - 开始加载SVGA | SVGA加载失败
private extension SVGAParsePlayer {
    func _loadSVGA(_ svgaSource: String, fromFrame: Int, isAutoPlay: Bool) {
        if svgaSource.count == 0 {
            _stopSVGA(isClear: true)
            _failedHandler(.unknownSource(svgaSource))
            return
        }
        
        if self.svgaSource == svgaSource, entity != nil {
            Self.debugLog("已经有了，不用加载 \(svgaSource)")
            asyncTag = nil
            _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        // 记录最新状态
        currFrame = fromFrame
        isWillAutoPlay = isAutoPlay
        
        guard !isLoading else {
            Self.debugLog("已经在加载了，不要重复加载 \(svgaSource)")
            return
        }
        status = .loading
        
        Self.debugLog("开始加载 \(svgaSource) - 先清空当前动画")
        stopAnimation()
        videoItem = nil
        clearDynamicObjects()
        
        let newTag = UUID()
        self.asyncTag = newTag
        
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
}

private extension SVGAParsePlayer {
    func _getLoadSuccess(_ svgaSource: String, _ asyncTag: UUID, _ isAutoPlay: Bool) -> LoadSuccess {
        return { [weak self] data in
            guard let self, self.asyncTag == asyncTag else { return }

            let newTag = UUID()
            self.asyncTag = newTag

            Self.debugLog("外部加载SVGA - 成功 \(svgaSource)")
            self._parseFromData(data, svgaSource, newTag, isAutoPlay)
        }
    }
    
    func _getLoadFailure(_ svgaSource: String, _ asyncTag: UUID, _ isAutoPlay: Bool) -> LoadFailure {
        return { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil

            Self.debugLog("外部加载SVGA - 失败 \(svgaSource)")
            self._stopSVGA(isClear: true)
            self._failedHandler(.dataLoadFailed(svgaSource, error))
        }
    }
    
    func _failedHandler(_ error: SVGAParsePlayerError) {
        guard let myDelegate else { return }
        
        switch error {
        case let .unknownSource(s):
            myDelegate.svgaParsePlayer?(self, unknownSvga: s)
            
        case let .dataLoadFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, dataLoadFailed: e)
            
        case let .dataParseFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, dataParseFailed: e)
            
        case let .assetParseFailed(s, e):
            myDelegate.svgaParsePlayer?(self, svga: s, assetParseFailed: e)
        }
    }
}

// MARK: - 下载Data | 解析Data | 解析Asset | 解析完成
private extension SVGAParsePlayer {
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
            _stopSVGA(isClear: true)
            _failedHandler(.unknownSource(svgaSource))
            return
        }
        
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: url) { [weak self] entity in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("内部下载远程SVGA - 成功 \(svgaSource)")
            
            if let entity {
                self._parseDone(svgaSource, entity)
                return
            }
            
            Self.debugLog("内部下载远程SVGA - 资源为空")
            self._stopSVGA(isClear: true)
            
            let error = NSError(domain: "SVGAParsePlayer", code: -3, userInfo: [NSLocalizedDescriptionKey: "SVGA资源为空"])
            self._failedHandler(.dataLoadFailed(svgaSource, error))
            
        } failureBlock: { [weak self] e in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("内部下载远程SVGA - 失败 \(svgaSource)")
            self._stopSVGA(isClear: true)
            
            let error = e ?? NSError(domain: "SVGAParsePlayer", code: -2, userInfo: [NSLocalizedDescriptionKey: "SVGA下载失败"])
            self._failedHandler(.dataLoadFailed(svgaSource, error))
        }
    }
    
    func _parseFromData(_ data: Data,
                        _ svgaSource: String,
                        _ asyncTag: UUID,
                        _ isAutoPlay: Bool) {
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(with: data, cacheKey: svgaSource.md5) { [weak self] entity in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("解析远程SVGA - 成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("解析远程SVGA - 失败 \(svgaSource) \(error)")
            self._stopSVGA(isClear: true)
            self._failedHandler(.dataParseFailed(svgaSource, error))
        }
    }
    
    func _parseFromAsset(_ svgaSource: String,
                         _ asyncTag: UUID,
                         _ isAutoPlay: Bool) {
        let parser = SVGAParser()
        parser.enabledMemoryCache = isEnabledMemoryCache
        parser.parse(withNamed: svgaSource, in: nil) { [weak self] entity in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("解析本地SVGA - 成功 \(svgaSource)")
            self._parseDone(svgaSource, entity)
            
        } failureBlock: { [weak self] error in
            guard let self, self.asyncTag == asyncTag else { return }
            self.asyncTag = nil
            
            Self.debugLog("解析本地SVGA - 失败 \(svgaSource) \(error)")
            self._stopSVGA(isClear: true)
            self._failedHandler(.assetParseFailed(svgaSource, error))
        }
    }
    
    func _parseDone(_ svgaSource: String, _ entity: SVGAVideoEntity) {
        guard self.svgaSource == svgaSource else { return }
        self.entity = entity
        videoItem = entity
        myDelegate?.svgaParsePlayer?(self, svga: svgaSource, parseDone: entity)
        _playSVGA(fromFrame: currFrame, isAutoPlay: isWillAutoPlay)
    }
}

// MARK: - 播放 | 停止
private extension SVGAParsePlayer {
    func _playSVGA(fromFrame: Int, isAutoPlay: Bool) {
        currFrame = fromFrame
        
        step(toFrame: fromFrame, andPlay: isAutoPlay)
        if isAutoPlay {
            Self.debugLog("跳至特定帧\(fromFrame) - 播放 \(svgaSource)")
            status = .playing
        } else {
            Self.debugLog("跳至特定帧\(fromFrame) - 暂停 \(svgaSource)")
            status = .paused
        }
        
        _show()
    }
    
    func _stopSVGA(isClear: Bool) {
        asyncTag = nil
        stopAnimation()
        currFrame = 0
        
        if isClear {
            svgaSource = ""
            entity = nil
            videoItem = nil
            clearDynamicObjects()
            
            Self.debugLog("停止 - 清空")
            status = .idle
        } else {
            Self.debugLog("停止 - 不清空")
            status = .stopped
        }
    }
}

// MARK: - 展示 | 隐藏
private extension SVGAParsePlayer {
    func _show() {
        guard isAnimated else {
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
            self.asyncTag = newTag
            
            UIView.animate(withDuration: 0.2) {
                self.alpha = 0
            } completion: { _ in
                guard self.asyncTag == newTag else { return }
                self.asyncTag = nil
                completion()
            }
        } else {
            if isHidesWhenStopped { alpha = 0 }
            completion()
        }
    }
}

// MARK: - <SVGAPlayerDelegate>
extension SVGAParsePlayer: SVGAPlayerDelegate {
    func svgaPlayer(_ player: SVGAPlayer!, didAnimatedToFrame frame: Int) {
        currFrame = frame
        myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didAnimatedToFrame: frame)
    }
    
    func svgaPlayerDidFinishedAnimation(_ player: SVGAPlayer!) {
        let svgaSource = self.svgaSource
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._stopSVGA(isClear: false)
            self.myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didFinishedAnimation: false)
        }
        Self.debugLog("svgaPlayerDidFinishedAnimation！！！")
    }
}

// MARK: - API
extension SVGAParsePlayer {
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
        
        self.svgaSource = svgaSource
        entity = nil
        asyncTag = nil
        status = .idle
        
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
        }
    }
    
    /// 播放目标SVGA（从头开始、自动播放）
    /// - Parameters:
    ///   - svgaSource: SVGA资源路径
    func play(_ svgaSource: String) {
        play(svgaSource, fromFrame: 0, isAutoPlay: true)
    }
    
    /// 播放目标SVGA
    /// - Parameters:
    ///   - entity: SVGA资源（`svgaSource`为`entity`的内存地址）
    ///   - fromFrame: 从第几帧开始
    ///   - isAutoPlay: 是否自动开始播放
    func play(with entity: SVGAVideoEntity, fromFrame: Int, isAutoPlay: Bool) {
        asyncTag = nil
        
        let svgaSource = entity.memoryAddress
        guard self.svgaSource != svgaSource else {
            _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        self.svgaSource = svgaSource
        self.entity = nil
        status = .idle
        
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            
            self.stopAnimation()
            self.videoItem = nil
            self.clearDynamicObjects()
            
            self.entity = entity
            self.videoItem = entity
            
            self._playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay)
        }
    }
    
    /// 播放目标SVGA（从头开始、自动播放）
    /// - Parameters:
    ///   - entity: SVGA资源（`svgaSource`为`entity`的内存地址）
    func play(with entity: SVGAVideoEntity) {
        play(with: entity, fromFrame: 0, isAutoPlay: true)
    }
    
    /// 播放当前SVGA（从当前所在帧开始）
    func play() {
        switch status {
        case .paused:
            Self.debugLog("继续")
            startAnimation()
            status = .playing
        case .playing:
            return
        default:
            play(fromFrame: currFrame, isAutoPlay: true)
        }
    }
    
    /// 播放当前SVGA
    /// - Parameters:
    ///  - fromFrame: 从第几帧开始
    ///  - isAutoPlay: 是否自动开始播放
    func play(fromFrame: Int, isAutoPlay: Bool) {
        guard svgaSource.count > 0 else { return }
        
        if entity == nil {
            Self.debugLog("播放 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: fromFrame, isAutoPlay: isAutoPlay)
            return
        }
        
        Self.debugLog("播放 - 无需加载 继续")
        _playSVGA(fromFrame: fromFrame, isAutoPlay: isAutoPlay)
    }
    
    /// 重置当前SVGA（回到开头）
    /// - Parameters:
    ///   - isAutoPlay: 是否自动开始播放
    func reset(isAutoPlay: Bool = true) {
        guard svgaSource.count > 0 else { return }
        
        if entity == nil {
            Self.debugLog("重播 - 需要加载")
            _loadSVGA(svgaSource, fromFrame: 0, isAutoPlay: isAutoPlay)
            return
        }
        
        Self.debugLog("重播 - 无需加载")
        _playSVGA(fromFrame: 0, isAutoPlay: isAutoPlay)
    }
    
    /// 暂停
    func pause() {
        Self.debugLog("暂停")
        guard isPlaying else {
            isWillAutoPlay = false
            return
        }
        pauseAnimation()
        status = .paused
    }
    
    /// 停止
    /// - Parameters:
    ///   - isClear: 是否清空SVGA资源（清空的话下次播放就需要重新加载资源）
    func stop(isClear: Bool) {
        let svgaSource = self.svgaSource
        _hideIfNeeded { [weak self] in
            guard let self else { return }
            self._stopSVGA(isClear: isClear)
            self.myDelegate?.svgaParsePlayer?(self, svga: svgaSource, didFinishedAnimation: true)
        }
    }
}
