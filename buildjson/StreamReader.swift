//
//  StreamReader.swift
//  eBirdClient
//
//  Created by Fred Hewett on 1/6/15.
//  Copyright (c) 2015 Appleton Software. All rights reserved.
//

// from http://stackoverflow.com/questions/24581517/read-a-file-url-line-by-line-in-swift

import Foundation
class StreamReader  {
    
    let encoding : UInt
    let chunkSize : Int
    
    var fileHandle : NSFileHandle!
    var buffer : NSMutableData!
    var delimData : NSData!
    var atEof : Bool = false
    
    init?(path: String, delimiter: String = "\n", encoding : UInt = NSUTF8StringEncoding, chunkSize : Int = 4096) {
        self.chunkSize = chunkSize
        self.encoding = encoding
        
        self.fileHandle = nil
        self.delimData = nil
        self.buffer = nil
        
        if let fileHandle = NSFileHandle(forReadingAtPath: path) {
            self.fileHandle = fileHandle
        } else {
            return nil
        }
        // Create NSData object containing the line delimiter:
        if let delimData = delimiter.dataUsingEncoding(NSUTF8StringEncoding) {
            self.delimData = delimData
        } else {
            return nil
        }
        if let buffer = NSMutableData(capacity: chunkSize) {
            self.buffer = buffer
        } else {
            return nil
        }
    }
    
    deinit {
        self.close()
    }
    
    /// Return next line, or nil on EOF.
    func nextLine() -> String? {
        
        if atEof {
            return nil
        }
        
        // Read data chunks from file until a line delimiter is found:
        var range = buffer.rangeOfData(delimData, options: [], range: NSMakeRange(0, buffer.length))
        while range.location == NSNotFound {
            let tmpData = fileHandle.readDataOfLength(chunkSize)
            if tmpData.length == 0 {
                // EOF or read error.
                atEof = true
                if buffer.length > 0 {
                    // Buffer contains last line in file (not terminated by delimiter).
                    let line = NSString(data: buffer, encoding: encoding);
                    buffer.length = 0
                    return line as String?
                }
                // No more lines.
                return nil
            }
            buffer.appendData(tmpData)
            range = buffer.rangeOfData(delimData, options: [], range: NSMakeRange(0, buffer.length))
        }
        
        // Convert complete line (excluding the delimiter) to a string:
        let line = NSString(data: buffer.subdataWithRange(NSMakeRange(0, range.location)),
            encoding: encoding)
        // Remove line (and the delimiter) from the buffer:
        buffer.replaceBytesInRange(NSMakeRange(0, range.location + range.length), withBytes: nil, length: 0)

        
        if line == nil {
            return nil;
        }
        
        
        return line as String?
    }
    
    /// Start reading from the beginning of file.
    func rewind() -> Void {
        fileHandle.seekToFileOffset(0)
        buffer.length = 0
        atEof = false
    }
    
    /// Close the underlying file. No reading must be done after calling this method.
    func close() -> Void {
        if fileHandle != nil {
            fileHandle.closeFile()
            fileHandle = nil
        }
    }
}




