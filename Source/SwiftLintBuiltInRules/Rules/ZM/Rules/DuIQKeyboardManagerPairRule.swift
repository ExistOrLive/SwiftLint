//
//  ZMIQKeyboardManagerPairRule.swift
//  SwiftLint
//
//  Created by 朱猛 on 2025/5/6.
//


import Foundation
import SwiftSyntax

/**
  * 使用IQKeyboardManager打开/关闭代码需要成对使用 
 */

struct ZMIQKeyboardManagerPairRule: SwiftSyntaxRule {

    var configuration = SeverityConfiguration<Self>(.warning)

    init() {}

    static let description = RuleDescription(
        identifier: "ZM_IQKeyboardManager_Pair_Rule",
        name: "ZM IQKeyboardManager Pair Rule",
        description: "使用IQKeyboardManager打开/关闭代码需要成对使用",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""

        """)
        ],
        triggeringExamples: [
            Example("""

        """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor<ConfigurationType> {
        Visitor(configuration: configuration, file: file)
    }
}


extension ZMIQKeyboardManagerPairRule {

    class ZMIQKeyboardManagerPairDataContext {
        var isEnableCode: Bool = false
        var codeFunction: String = ""
        var node: CodeBlockItemSyntax? = nil 
    }

    final class Visitor: ZMFileContextVisitor<ConfigurationType> {

        /// class Name 
        var IQKeyboardManagerPairDataDic: [String: [ZMIQKeyboardManagerPairDataContext]] = [:]
        /// 标识符
        override func visitPost(_ node: CodeBlockItemSyntax) {
            super.visitPost(node)

            guard case .expr(let expr) = node.item else { return }

            let str = ZMSwiftSyntaxTool.syntaxStr(expr)

            if str == "IQKeyboardManager.shared.enable=true" {
                if let functionName = findFirstFunctioneEnvironment(currentLexicalEnvironmentContext),
                   let className = findFirstClassOrExtensionEnvironment(currentLexicalEnvironmentContext) {
                    let data = ZMIQKeyboardManagerPairDataContext()
                    data.codeFunction = functionName
                    data.isEnableCode = true 
                    data.node = node 

                    var array: [ZMIQKeyboardManagerPairDataContext] = []
                    if let tmpArray = IQKeyboardManagerPairDataDic[className] {
                        array = tmpArray
                    } 
                    array.append(data)
                    IQKeyboardManagerPairDataDic[className] = array
                }
            } else if str == "IQKeyboardManager.shared.enable=false" {
                if let functionName = findFirstFunctioneEnvironment(currentLexicalEnvironmentContext),
                   let className = findFirstClassOrExtensionEnvironment(currentLexicalEnvironmentContext) {
                    let data = ZMIQKeyboardManagerPairDataContext()
                    data.codeFunction = functionName
                    data.isEnableCode = false 
                    data.node = node 

                    var array: [ZMIQKeyboardManagerPairDataContext] = []
                    if let tmpArray = IQKeyboardManagerPairDataDic[className] {
                        array = tmpArray
                    } 
                    array.append(data)
                    IQKeyboardManagerPairDataDic[className] = array
                }
            }

        }

        override func visitPost(_ node: ClassDeclSyntax) {
            super.visitPost(node)
            let className = node.name.text 
            guard let array = IQKeyboardManagerPairDataDic[className] else {
                return 
            }
            IQKeyboardManagerPairDataDic.removeValue(forKey: className)

            var enableCodeArray: [ZMIQKeyboardManagerPairDataContext] = []
            var disableCodeArray: [ZMIQKeyboardManagerPairDataContext] = []
            for code in array {
                if code.isEnableCode {
                    enableCodeArray.append(code)
                } else {
                    disableCodeArray.append(code)
                }
            }

            if enableCodeArray.count != disableCodeArray.count {
               violations.append(contentsOf: enableCodeArray.compactMap({ $0.node?.positionAfterSkippingLeadingTrivia} ))
               return 
            }

            for enableCode in enableCodeArray {
                if enableCode.codeFunction == "viewDidAppear" || enableCode.codeFunction == "viewWillAppear" {
                    if !disableCodeArray.contains(where: { $0.codeFunction == "viewDidDisappear" ||  $0.codeFunction == "viewWillDisappear" }) {
                        violations.append(contentsOf: enableCodeArray.compactMap({ $0.node?.positionAfterSkippingLeadingTrivia} ))
                    }
                } else if enableCode.codeFunction == "viewDidDisappear" ||  enableCode.codeFunction == "viewWillDisappear" {
                    if !disableCodeArray.contains(where: { $0.codeFunction == "viewDidAppear" || $0.codeFunction == "viewWillAppear" }) {
                        violations.append(contentsOf: enableCodeArray.compactMap({ $0.node?.positionAfterSkippingLeadingTrivia} ))
                    }
                }
            }
        }


        func findFirstFunctioneEnvironment(_ context:  ZMFileLexicalEnvironmentContext?) -> String? {
            guard let context else { return nil }
            if context.type == .functionType {
                return context.name
            } else {
                return findFirstFunctioneEnvironment(context.parentLexicalEnvironment)
            }
        }

        func findFirstClassOrExtensionEnvironment(_ context:  ZMFileLexicalEnvironmentContext?) -> String? {
            guard let context else { return nil }
            if context.type == .classType ||  context.type == .extensionType || context.type == .structType  {
                return context.name
            } else {
                return findFirstClassOrExtensionEnvironment(context.parentLexicalEnvironment)
            }
        }
    }


}
