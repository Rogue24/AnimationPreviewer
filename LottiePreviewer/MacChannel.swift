//
//  MacChannel.swift
//  LottiePreviewer
//
//  Created by 周健平 on 2023/5/9.
//

enum MacChannel {
    static var channel: Channel?
    
    static func shared() -> Channel {
        if let channel = channel {
            return channel
        }
        
        let bundleFileName = "MacPlugin.bundle"
        let bundleURL = Bundle.main.builtInPlugInsURL!.appendingPathComponent(bundleFileName)
     
        let bundle = Bundle(url: bundleURL)!
        
        let className = "MacPlugin.MacPlugin"
        let ChannelCls = bundle.classNamed(className) as! Channel.Type
        let channel = ChannelCls.init()
        
        self.channel = channel
        return channel
    }
}
