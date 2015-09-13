//
//  ViewController.swift
//  FFCreator
//
//  Created by Jieyi Hu on 9/1/15.
//  Copyright © 2015 fullstackpug. All rights reserved.
//

import Cocoa
import AppKit

class ViewController: NSViewController, NSFileManagerDelegate {
    
    var inputURL : NSURL?
    var outputURL : NSURL?
    var possibleName : String?
    var osFrameworkPath : String?
    var simFrameworkPath : String?
    var osFrameworkBin : String? {
        get{
            if possibleName != nil && osFrameworkPath != nil {
                return (osFrameworkPath! as NSString).stringByAppendingPathComponent(possibleName!)
            } else {return nil}
        }
    }
    var simFrameworkBin : String? {
        get{
            if possibleName != nil && simFrameworkPath != nil {
                return (simFrameworkPath! as NSString).stringByAppendingPathComponent(possibleName!)
            } else {return nil}
        }
    }
    var productDir : String? {
        get{
            if osFrameworkPath != nil {
                return ((osFrameworkPath! as NSString).stringByDeletingLastPathComponent as NSString).stringByDeletingLastPathComponent
            } else {return nil}
        }
    }
    

    @IBOutlet weak var dropView: DropView!
    @IBOutlet var inputTextField: NSTextField!
    @IBOutlet var outputTextField: NSTextField!
    @IBAction func inputButtonClicked(sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModalForWindow(NSApplication.sharedApplication().windows[0], completionHandler: {respond in
            switch(respond) {
            case NSModalResponseOK:
                self.inputURL = panel.URL
                if self.inputURL != nil{
                    self.inputTextField.stringValue = self.inputURL!.absoluteString
                    self.findPossibleName(self.inputURL)
                }
            default:
                print("input selection cancel")
            }
        })
    }
    @IBAction func outputButtonClicked(sender: NSButton) {
        let panel = NSSavePanel()
        panel.extensionHidden = false
        panel.allowedFileTypes = ["framework"]
        panel.canCreateDirectories = true
        panel.canSelectHiddenExtension = false
        if possibleName != nil {panel.nameFieldStringValue = possibleName!}
        panel.directoryURL = NSURL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DesktopDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0])
        panel.beginSheetModalForWindow(NSApplication.sharedApplication().windows[0], completionHandler: {respond in
            switch(respond) {
            case NSModalResponseOK:
                self.outputURL = panel.URL
                if self.outputURL != nil {
                    self.outputTextField.stringValue = self.outputURL!.absoluteString
                }
            default:
                print("output selection cancel")
            }
        })
    }
    @IBAction func createButtonClicked(sender: NSButton) {
        if inputURL != nil && outputURL != nil {
            osFrameworkPath = getPath(inputURL!)
            simFrameworkPath = osFrameworkPath?.stringByReplacingOccurrencesOfString("-iphoneos", withString: "-iphonesimulator")
            copyModuleFromSimToOS("i386.swiftdoc")
            copyModuleFromSimToOS("i386.swiftmodule")
            copyModuleFromSimToOS("x86_64.swiftdoc")
            copyModuleFromSimToOS("x86_64.swiftmodule")
            extract([
                        "i386" : simFrameworkBin!,
                        "x86_64" : simFrameworkBin!,
                        "armv7" : osFrameworkBin! ,
                        "arm64" : osFrameworkBin!,
                    ], output: productDir!)
            NSApp.terminate(nil)
        }
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        NSFileManager.defaultManager().delegate = self
        dropView.registerForDragOperation({info in
            if let paths = info.draggingPasteboard().propertyListForType(NSFilenamesPboardType) as? [String] {
                if paths.count > 0 {
                    self.inputURL = NSURL(fileURLWithPath: paths[0])
                    self.inputTextField.stringValue = self.inputURL!.absoluteString
                    self.findPossibleName(self.inputURL)
                    return true
                }
            }
            return false
        })
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func findPossibleName(url : NSURL?){
        if let pathComponents = url?.pathComponents {
            if pathComponents.count > 0 {
                let name = pathComponents[pathComponents.count - 1] as NSString
                possibleName = name.stringByDeletingPathExtension
            }
        }
    }
    
    func getPath(url : NSURL) -> String {
        let path = url.absoluteString
        if path.containsString("file://") {
            let NSstr = path as NSString
            let range = NSstr.rangeOfString("file://")
            let index = range.location + range.length
            return NSstr.substringFromIndex(index)
        }
        return path
    }
    
    func copyModuleFromSimToOS(moduleName : String) {
        if let osFrameworkPath = osFrameworkPath {
            if let simFrameworkPath = simFrameworkPath {
                do{
                    let srcPath = (((simFrameworkPath as NSString).stringByAppendingPathComponent("Modules") as NSString).stringByAppendingPathComponent("SlidesKit.swiftmodule") as NSString).stringByAppendingPathComponent(moduleName)
                    let toPath = (((osFrameworkPath as NSString).stringByAppendingPathComponent("Modules") as NSString).stringByAppendingPathComponent("SlidesKit.swiftmodule") as NSString).stringByAppendingPathComponent(moduleName)
                    try NSFileManager.defaultManager().copyItemAtPath(srcPath, toPath: toPath)
                } catch let error as NSError {
                    print(error)
                }
            }
        }
    }
    
    func extract(inputs : [String : String], output : String) {
        var script = "tell application \"Terminal\"\n do shell script \""
        for (key,value) in inputs {
            let lipoCMD = "lipo -extract \(key) \(value) -o \((output as NSString).stringByAppendingPathComponent(key)) \n"
            script = script.stringByAppendingString(lipoCMD)
        }
        
        script = script.stringByAppendingString("lipo -create ")
        
        for(key,value) in inputs {
            script = script.stringByAppendingString((output as NSString).stringByAppendingPathComponent(key)) + " "
        }

        let destPath = (osFrameworkPath! as NSString).stringByAppendingPathComponent(possibleName!)
        
        script = script.stringByAppendingString("-o \(destPath)")
        
        script = script.stringByAppendingString("\"\n")
        
        script = script.stringByAppendingString("end tell\n")
        
        script = script.stringByAppendingString("tell application \"Terminal\" to quit\n")
        
//        do{try script.writeToFile(NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DesktopDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0].stringByAppendingString("/script.txt"), atomically: true, encoding: NSUTF8StringEncoding)}catch {}

        let errorInfo = AutoreleasingUnsafeMutablePointer<NSDictionary?>()
        NSAppleScript(source: script)?.executeAndReturnError(errorInfo)
        
        for(key,value) in inputs {
            do{try NSFileManager.defaultManager().removeItemAtPath((output as NSString).stringByAppendingPathComponent(key))}catch{}
        }
        
        do{
            try NSFileManager.defaultManager().copyItemAtURL(NSURL(fileURLWithPath: osFrameworkPath!), toURL: outputURL!)
        }catch let error as NSError {
            print(error)
        }
    }

    func fileManager(fileManager: NSFileManager, shouldProceedAfterError error: NSError, copyingItemAtURL srcURL: NSURL, toURL dstURL: NSURL) -> Bool {
        if error.code == NSFileWriteFileExistsError {
            return true
        }
        return false
    }
}

