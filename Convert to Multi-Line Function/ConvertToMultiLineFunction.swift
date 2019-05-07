//
//  ConvertToMultiLineFunction.swift
//  Convert To Multi-Line Function
//
//  Created by Christopher Chute on 5/6/19.
//  Copyright © 2019 chute. All rights reserved.
//

import Foundation
import XcodeKit

class ConvertToMultiLineFunction: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        defer { completionHandler(nil) }
        
        // At least something is selected
        guard let firstSelection = invocation.buffer.selections.firstObject as? XCSourceTextRange,
            let lastSelection = invocation.buffer.selections.lastObject as? XCSourceTextRange else {
                return
        }
        
        // One line is selected
        let firstLine = firstSelection.start.line
        let lastLine = lastSelection.end.line
        guard firstLine <= lastLine, firstLine >= 0, lastLine < invocation.buffer.lines.count else {
            return
        }
        
        putEachArgumentOnItsOwnLine(invocation.buffer.lines, in: firstLine...lastLine)
    }
    
    private func putEachArgumentOnItsOwnLine(_ allLines: NSMutableArray, in range: CountableClosedRange<Int>) {
        // Get selected lines
        let lines = allLines.compactMap { $0 as? String }
        let selection = lines[range].joined()
        
        // Build up list of updated lines
        let parsed = parse(selection)
        
        // Make updated lines
        var updatedLines = [String]()
        updatedLines.append(parsed.indent + parsed.funcName + "(")
        for (argIndex, arg) in parsed.args.enumerated() {
            let isLastArg = argIndex == parsed.args.count - 1
            updatedLines.append(parsed.indent + "    " + arg + (isLastArg ? "" : ","))
        }
        updatedLines.append(parsed.indent + parsed.trailingText)
        
        // Overwrite lines
        allLines.replaceObjects(in: NSRange(range), withObjectsFrom: updatedLines)
    }
    
    private func parse(_ originalText: String) -> (indent: String, funcName: String, args: [String], trailingText: String) {
        // Get indentation
        var indent = ""
        for char in originalText {
            if char.isWhitespace {
                indent += String(char)
            } else {
                break
            }
        }
        
        // Get function name
        var isLeadingWhitespace = true
        var funcName = ""
        for char in originalText {
            if char.isWhitespace, isLeadingWhitespace {
                continue
            } else if char == "(" {
                break
            } else {
                isLeadingWhitespace = false
                funcName += String(char)
            }
        }
        
        // Get args
        var args = [String]()
        var currentArg = ""
        var trailingText = ""
        var parenDepth = 0
        var seenParentheses = false
        for char in originalText {
            // Keep track of parentheses depth
            if char == "(" {
                seenParentheses = true
                parenDepth += 1
                if parenDepth == 1 { continue }
            } else if char == ")" {
                parenDepth -= 1
            }
            
            // Nothing tracked outside parentheses
            if parenDepth == 0, !seenParentheses {
                continue
            }
            
            if parenDepth == 1, char == "," {
                let trimmedArg = currentArg.trimmingCharacters(in: .whitespacesAndNewlines)
                args.append(trimmedArg)
                currentArg = ""
            } else if parenDepth > 0 {
                currentArg += String(char)
            } else {
                trailingText += String(char)
            }
        }
        
        let trimmedArg = currentArg.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedArg.isEmpty {
            args.append(trimmedArg)
        }
        
        return (indent: indent, funcName: funcName, args: args, trailingText: trailingText)
    }
    
}
