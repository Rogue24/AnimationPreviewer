//
//  Done.swift
//  Neves
//
//  Created by aa on 2021/2/4.
//

struct Done {
    typealias Map<O, T> = (O) -> T
    typealias Complete<T> = (Result<T>) -> ()
    
    struct Fail {
        var error: Error?
        var msg: String
        var errorMsg: String { error.map { $0.localizedDescription } ?? "" }
        /// 错误信息的优先级：高 msg -> localizedDescription -> defaultMsg 低
        init(_ error: Error?, msg: String? = nil, _ defaultMsg: @autoclosure () -> String?) {
            self.error = error
            self.msg = msg ?? error.map { $0.localizedDescription } ?? defaultMsg() ?? ""
        }
    }
    
    enum Result<T> {
        case success(_ data: T)
        case failed(_ fail: Fail?)
    }
}
