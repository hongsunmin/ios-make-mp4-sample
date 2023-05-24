import Foundation
import os

public class Log {
    
    enum LogEvent: String {
        case e = "❌"
        case d = "◾️"
        case i = "🔷"
    }
    
    static let os = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "MakeMP4Sample")
    
    public class func i<T>(_ object: T?, filename: String = #file, line: Int = #line, funcName: String = #function) {
        print(object ?? "nil", event: LogEvent.i, filename: filename, line: line, funcName: funcName)
    }
    
    public class func d<T>(_ object: T?, filename: String = #file, line: Int = #line, funcName: String = #function) {
        print(object ?? "nil", event: LogEvent.d, filename: filename, line: line, funcName: funcName)
    }
    
    public class func e<T>(_ object: T?, filename: String = #file, line: Int = #line, funcName: String = #function) {
        print(object ?? "nil", event: LogEvent.e, filename: filename, line: line, funcName: funcName)
    }
    
    fileprivate class func print(_ object: Any, event:LogEvent, filename: String, line: Int, funcName: String) {
        #if DEBUG
//        let th = Thread.current.isMainThread ? "main": Thread.current.name ?? "-"
//        Swift.print("\(event.rawValue) \(Date()) \(th) \(filename.components(separatedBy: "/").last ?? ""):\(line) - \(funcName) > \(object)")
        
        var osLogType: OSLogType = .default
        switch event {
        case .d: osLogType = .debug
        case .i: osLogType = .info
        case .e: osLogType = .error
        }
        os_log("%{public}@ %{public}@ %{public}@ > %{public}@", log: os, type: osLogType,  event.rawValue, filename.components(separatedBy: "/").last ?? "", funcName, String(describing: object))
        #endif
    }
    
}
