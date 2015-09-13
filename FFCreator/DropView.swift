//
//  DropView.swift
//  FFCreator
//
//  Created by Jieyi Hu on 9/1/15.
//  Copyright © 2015 fullstackpug. All rights reserved.
//

import AppKit

class DropView: NSView {
    
    private var dragOperation : ((NSDraggingInfo)->Bool)?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([NSFilenamesPboardType])
    }
    
    internal func registerForDragOperation(operation : (NSDraggingInfo)->Bool) {
        dragOperation = operation
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        if let operation = dragOperation {
            return operation(sender)
        }
        return false
    }
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        let pBoard = sender.draggingPasteboard()
        if let fileTypes = pBoard.types {
            if fileTypes.contains(NSFilenamesPboardType) {
                let paths = pBoard.propertyListForType(NSFilenamesPboardType) as! [String]
                for path in paths {
                    do{
                        let type = try NSWorkspace.sharedWorkspace().typeOfFile(path)
                        if NSWorkspace.sharedWorkspace().type(type, conformsToType: "com.apple.framework") {
                            return NSDragOperation.Every
                        }
                    } catch let error as NSError {
                        print(error)
                    }
                }
            }
        }
        return NSDragOperation.None
    }
}
