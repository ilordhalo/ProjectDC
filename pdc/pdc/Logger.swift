//
//  Logger.swift
//  pdc
//
//  Created by zhangjiahao.me on 3/13/24.
//

import Foundation
import Logging
import FileLogging

class Logger : ObservableObject {
    @Published var log: String = ""
    
    static let shared = Logger()
    
    private var logger: Logging.Logger?
    
    init() {
    }
    
    func setupLoggingSystem(logURL: URL? = nil) {
        let scriptPath = CommandLine.arguments[0]
        let scriptURL = URL(fileURLWithPath: scriptPath)
        let directoryPath = scriptURL.deletingLastPathComponent().path
        var logFileURL = URL(filePath: directoryPath)
        logFileURL.appendPathComponent("pdc.log")
        
        if let logURL {
            logFileURL = logURL
        }
        
        guard let fileLogger = try? FileLogging(to: logFileURL) else {
            fatalError("Logger init error.")
        }
        
        LoggingSystem.bootstrap { label in
            let handlers:[LogHandler] = [
                FileLogHandler(label: label, fileLogger: fileLogger),
                StreamLogHandler.standardOutput(label: label)
            ]

            return MultiplexLogHandler(handlers)
        }
        
        self.logger = Logging.Logger(label: "com.inflosoft.pdc")
    }

    func log(_ newEntry: String) {
        guard let logger else {
            fatalError("Should setupLoggingSystem first.")
        }
        logger.info("\(newEntry)")
    }
    
    func logError(_ error: Error) {
        guard let logger else {
            fatalError("Should setupLoggingSystem first.")
        }
        logger.error("ERROR: \(String(describing: error))")
    }
    
    func logError(msg: String) {
        guard let logger else {
            fatalError("Should setupLoggingSystem first.")
        }
        logger.error("ERROR: \(msg)")
    }

}
