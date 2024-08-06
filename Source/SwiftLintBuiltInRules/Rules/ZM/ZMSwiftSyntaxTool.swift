//
//  ZMSwiftSyntaxTool.swift
//
//
//  Created by 朱猛 on 2024/8/6.
//

import Foundation
import SwiftSyntax

class ZMSwiftSyntaxTool {

    /// 查找祖先节点中的函数声明和闭包表达式
    static func findSuperFunctionDeclOrClosureExpr(_ node: any SyntaxProtocol) -> (any SyntaxProtocol)? {

        var currentNode: any SyntaxProtocol = node
        while true {
            if let parentNode = currentNode.parent {
                if let functionCallExpr = parentNode.as(FunctionDeclSyntax.self) {
                    return functionCallExpr
                } else if let closureExprSyntax = parentNode.as(ClosureExprSyntax.self) {
                    if closureExprSyntax.parent?.is(FunctionCallExprSyntax.self) ?? false {
                        /// 如果闭包表达式声明后直接调用，则不认为是危险代码
                        return nil
                    }
                    return closureExprSyntax
                }
                currentNode = parentNode
            } else {
                break
            }
        }
        return nil
    }

    static func syntaxStr(_ node: any SyntaxProtocol) -> String {
        let children = node.children(viewMode: .sourceAccurate)
        var string = ""

        children.forEach({ node  in
           if let token = node.as(TokenSyntax.self) {
              string = string + token.text
           } else {
              string = string + ZMSwiftSyntaxTool.syntaxStr(node)
           }

        })
        return string
    }
}
