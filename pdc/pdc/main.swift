//
//  main.swift
//  pdc
//
//  Created by zhangjiahao.me on 3/10/24.
//

import Foundation
import AppKit
import Cocoa
import ArgumentParser

PDCEntrance.main()

struct PDCEntrance: ParsableCommand {
    @Flag(name: .customShort("i"), help: "Save pasteboard images to local file.")
    var generateImage = false
    
    @Flag(name: .customShort("h"), help: "Save pasteboard rich text content to html file.")
    var generateHTML = false
    
    @Flag(name: .customShort("r"), help: "Save pasteboard rich text content to rtfd file.")
    var generateRTFD = false
    
    @Flag(name: .customShort("f"), help: "Save pasteboard files to local.")
    var generateFile = false
    
    var name = ""
    var directory = ""
    
    mutating func run() {
        readConfig()
        generateFileName()
        
        if generateFile, saveFiles() {
            return
        }
        
        if generateImage {
            let success = saveClipboardImageToLocal()
            if !success {
                saveImages()
            }
        }
        
        if generateHTML {
            saveHTML()
        }
        
        if generateRTFD {
            saveRTFD()
        }
    }
    
    mutating func readConfig() {
        if let configData = try? Data(contentsOf: URL(fileURLWithPath: "./config.plist")), let config = try? PropertyListSerialization.propertyList(from: configData, format: nil) as? [String: Any] {
            directory = config["output"] as! String
            if let logPath = config["log"] as? String {
                let logURL = URL(fileURLWithPath: logPath)
                Logger.shared.setupLoggingSystem(logURL: logURL)
            } else {
                Logger.shared.setupLoggingSystem()
            }
            
        } else {
            fatalError("Can't find config.plist")
        }
    }
    
    mutating func generateFileName() {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.current
        name = dateFormatter.string(from: Date())
        Logger.shared.log("The file name is \(name)")
    }
    
    func getFileURL(suffix: String) -> URL {
        return URL(fileURLWithPath: directory + name + suffix)
    }
    
    func saveFiles() -> Bool {
        let pasteboard = NSPasteboard.general

        guard let types = pasteboard.types, types.contains(.fileURL) else {
            return false
        }
        
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return false
        }
        
        let directoryURL = URL(fileURLWithPath: directory)
        do {
            let fileManager = FileManager.default
            for url in urls {
                var mDirectoryURL = directoryURL
                let fileName = name + "_" + url.lastPathComponent
                mDirectoryURL.appendPathComponent(fileName)
                try fileManager.copyItem(at: url, to: mDirectoryURL)
                Logger.shared.log("Save clipboard files to disk successful. File name: \(fileName)")
            }
        } catch {
            Logger.shared.logError(msg: "Save clipboard files to disk failed. Error: \(error)")
        }
        return true
    }
    
    func saveHTML() {
        let pasteboard = NSPasteboard.general
        if let items = pasteboard.pasteboardItems,
           let item = items.first,
           let htmlData = item.data(forType: .html),
           let htmlString = String(data: htmlData, encoding: .utf8) {
            let fileURL = getFileURL(suffix: ".html")

            do {
                try htmlString.write(to: fileURL, atomically: true, encoding: .utf8)
                Logger.shared.log("Save clipboard content to html file successful. File name: \(fileURL.lastPathComponent)")
            } catch {
                Logger.shared.logError(msg: "Save clipboard content to html file failed. Error: \(error)")
            }
        }
    }
    
    func saveRTFD() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.canReadObject(forClasses: [NSAttributedString.self], options: nil) else {
            return
        }
        
        let objects = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)
        let attributedStrings = objects as? [NSAttributedString]
        
        guard let firstAttributedString = attributedStrings?.first else {
            return
        }
        
        do {
            let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [.documentType: NSAttributedString.DocumentType.rtfd]
            let fileWrapper = try firstAttributedString.fileWrapper(from: NSMakeRange(0, firstAttributedString.length), documentAttributes: documentAttributes)
            let url = getFileURL(suffix: ".rtfd")
            try fileWrapper.write(to: url, options: .atomic, originalContentsURL: nil)
            Logger.shared.log("Save clipboard content to RTFD file successful. File name: \(url.lastPathComponent)")
        } catch {
            Logger.shared.logError(msg: "Save clipboard content to RTFD file failed. Error: \(error)")
        }
    }
    
    func saveClipboardImageToLocal() -> Bool {
        let pasteboard = NSPasteboard.general

        guard let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
            return false
        }
        
        guard let tiffRepresentation = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return false
        }
        
        guard let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return false
        }

        let fileURL = getFileURL(suffix: ".png")
        do {
            try pngData.write(to: fileURL, options: .atomic)
            Logger.shared.log("Save clipboard image to local file successful. File name: \(fileURL.lastPathComponent)")
        } catch {
            Logger.shared.logError(msg: "Save clipboard image to local file failed. Error: \(error)")
            return false
        }
        
        return true
    }
    
    func saveImages() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.canReadObject(forClasses: [NSAttributedString.self], options: nil) else {
            return
        }
        
        let objects = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)
        let attributedStrings = objects as? [NSAttributedString]
        
        guard let firstAttributedString = attributedStrings?.first else {
            return
        }

        var dataArray = [Data]()
        firstAttributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: firstAttributedString.length), options: []) { (value, range, stop) in
            if let textAttachment = value as? NSTextAttachment {
                let data = textAttachment.fileWrapper!.regularFileContents!
                dataArray.append(data)
            }
        }
        
        do {
            if dataArray.count == 1 {
                let data = dataArray.first!
                let url = getFileURL(suffix: ".png")
                try data.write(to: url)
                Logger.shared.log("Save clipboard images to local file successful. File name: \(url.lastPathComponent)")
            } else {
                for (index, data) in dataArray.enumerated() {
                    let url = getFileURL(suffix: "_\(index).png")
                    try data.write(to: url)
                    Logger.shared.log("Save clipboard images to local file successful. File name: \(url.lastPathComponent)")
                }
            }
        } catch {
            Logger.shared.logError(msg: "Save clipboard images to local file failed. Error: \(error)")
        }

    }
}






//let pasteboard = NSPasteboard.general
//
//if pasteboard.canReadObject(forClasses: [NSAttributedString.self], options: nil) {
//    let objects = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)
//    let attributedStrings = objects as? [NSAttributedString]
//    if let firstAttributedString = attributedStrings?.first {
////        let muAtt = NSMutableAttributedString(attributedString: firstAttributedString)
//        let muAtt = NSMutableAttributedString()
//        firstAttributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: firstAttributedString.length), options: []) { (value, range, stop) in
//            if let textAttachment = value as? NSTextAttachment {
//                do {
////                    saveImageToLocal(data: textAttachment.fileWrapper!.regularFileContents!)
//                    let image = NSImage(data: textAttachment.fileWrapper!.regularFileContents!);
////                    textAttachment.image = image
////                    textAttachment.bounds = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 30, height: 30))
//                    let imgAtt = NSTextAttachment()
//                    imgAtt.image = image
//                    imgAtt.bounds = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 10, height: 10))
//                    let a = NSAttributedString(attachment: imgAtt)
//                    muAtt.append(a)
////                    muAtt.replaceCharacters(in: range, with: a)
////                    print("fuck \(image)")
//                } catch let e {
//                    print(e)
//                }
//
//            }
//        }
//        
//        do {
//             let documentAttributes: [NSAttributedString.DocumentAttributeKey: Any] = [.documentType: NSAttributedString.DocumentType.rtfd]
//             let data = try muAtt.data(
//                 from: NSRange(location: 0, length: muAtt.length),
//                 documentAttributes: documentAttributes
//             )
//            let fileWrapper = try muAtt.fileWrapper(from: NSMakeRange(0, muAtt.length), documentAttributes: documentAttributes)
//            let url = URL(fileURLWithPath: "./file.rtfd") // 将路径替换为你想要保存的文件路径
//            do {
//                try fileWrapper.write(to: url, options: .atomic, originalContentsURL: nil)
//                print("saved")
//            } catch {
//                print(error)
//            }
////             let url = URL(fileURLWithPath: "./file.rtfd") // 将路径替换为你想要保存的文件路径
////             try data.write(to: url)
////             print("成功保存到文件: \(url.path)")
////             if let rtfString = String(data: data, encoding: .utf8) {
////                 print(rtfString)
////             }
//         } catch {
//             print("转换失败: \(error)")
//         }
//    }
//}
//
//if let image = NSImage(pasteboard: pasteboard) {
//    print("找到图片。")
//    // 之后你可以处理或者保存这个`image`
//} else {
//    print("剪贴板中未找到图片。")
//}


