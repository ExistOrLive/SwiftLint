//
//  File.swift
//  
//
//  Created by 朱猛 on 2024/8/6.
//
import Foundation
import SwiftSyntax

struct ZMBlockCycleReferenceRule: SwiftSyntaxRule  {

    var configuration = SeverityConfiguration<Self>(.warning)

    init() {}

    static let description = RuleDescription(
        identifier: "ZM_Block_Cycle_Reference_Rule",
        name: "ZM Block Cycle Reference  Rule",
        description: "在Block中可能有循环引用问题，请仔细甄别",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""
            view.block = { [weak self, weak view] a in
                 view?.borderWidth = 1
            }

        """)
        ],
        triggeringExamples: [
            Example("""
            view.block = { [weak self] a in
                 view.borderWidth = 1
            }
        """)
        ]
    )
    
    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor<ConfigurationType> {
        return Visitor(configuration: configuration, file: file)
    }
}

extension ZMBlockCycleReferenceRule {
    class ClosureExprSyntaxContext {
        var node: ClosureExprSyntax
        var superContext: ClosureExprSyntaxContext?
        var undeclareIdentifiers: [String] = []

        init(node: ClosureExprSyntax, superContext: ClosureExprSyntaxContext? ) {
            self.node = node
            self.superContext = superContext
        }
    }
}

extension ZMBlockCycleReferenceRule {
    
    final class Visitor: ZMFileContextVisitor<ConfigurationType> {

        var currentContext:  ClosureExprSyntaxContext?

        /// 标识符
        override func visit(_ node: IdentifierExprSyntax) -> SyntaxVisitorContinueKind {
            /// 在闭包当中
            guard let currentContext = currentContext else { return .visitChildren}

            let name = node.identifier.text

            if name.hasPrefix("$") {
                return .visitChildren
            } else {
                /// 找出在当前闭包中捕获但为显式声明捕获的标识符
                let hasDeclare = findVariableDecIn(targetClosureExprNode: currentContext.node, targetIdentifier: name)
                if !hasDeclare {
                    currentContext.undeclareIdentifiers.append(name)
                }
            }

            return .visitChildren
        }


        /// 处理闭包
        override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
            let result = super.visit(node)
            currentContext = ClosureExprSyntaxContext(node: node, superContext: currentContext)
            return result
        }

        override func visitPost(_ node: ClosureExprSyntax) {
            if let currentContext, !currentContext.undeclareIdentifiers.isEmpty {

                /// 判断闭包调用
                /// 1. 赋值表达式 筛查出闭包作为右值赋值
                if let exprList = node.parent?.as(ExprListSyntax.self) {
                    dealWithAssignmentExpr(node: node, exprList: exprList)
                } else {
                    /// 2. 处理函数调用，传入闭包
                    dealWithFunctionCallExpr(node: node)
                }

                 /// 嵌套闭包，将下级闭包中的未声明捕获变量同步到上级闭包中
                if let superContext = currentContext.superContext {
                    /// 嵌套闭包，将下级闭包中的未声明捕获变量同步到上级闭包中
                    /// 找出在当前闭包中捕获但为显式声明捕获的标识符
                    for identifier in currentContext.undeclareIdentifiers {
                        let hasDeclare = findVariableDecIn(targetClosureExprNode: superContext.node, targetIdentifier: identifier)
                        if !hasDeclare {
                            superContext.undeclareIdentifiers.append(identifier)
                        }
                    }
                }
            }

            currentContext = currentContext?.superContext
            super.visitPost(node)
        }
    }


}

extension ZMBlockCycleReferenceRule.Visitor {

    func findVariableDecIn(targetClosureExprNode: ClosureExprSyntax, targetIdentifier: String) -> Bool {
        var lexicalEnvironmentContext = currentLexicalEnvironmentContext

        while(true) {
            guard let tmpLexicalEnvironmentContext = lexicalEnvironmentContext else { return false }

            for variable in  tmpLexicalEnvironmentContext.variableList {
                if variable.name == targetIdentifier {
                    return true
                }
            }

            if let closure = lexicalEnvironmentContext?.node.as(ClosureExprSyntax.self),
                closure ==  targetClosureExprNode {
                return false
            } else {
                lexicalEnvironmentContext = lexicalEnvironmentContext?.parentLexicalEnvironment
            }
        }
    }

    func findVariableDecByTree(currentLexicalEnvironmentContext: ZMFileLexicalEnvironmentContext?, targetIdentifier: String) -> ZMLexicalEnvironmentVariableModel? {

        var lexicalEnvironmentContext: ZMFileLexicalEnvironmentContext? = currentLexicalEnvironmentContext
        while(true) {
            guard let tmpLexicalEnvironmentContext = lexicalEnvironmentContext else { return nil }

            for variable in  tmpLexicalEnvironmentContext.variableList {
                if variable.name == targetIdentifier {
                    return  variable
                }
            }
            lexicalEnvironmentContext = lexicalEnvironmentContext?.parentLexicalEnvironment
        }
    }

    func findFunctionDecByTree(currentLexicalEnvironmentContext: ZMFileLexicalEnvironmentContext?, targetFunctionName: String) -> ZMLexicalEnvironmentFunctionModel? {

        var lexicalEnvironmentContext: ZMFileLexicalEnvironmentContext? = currentLexicalEnvironmentContext
        while(true) {
            guard let tmpLexicalEnvironmentContext = lexicalEnvironmentContext else { return nil }

            for function in  tmpLexicalEnvironmentContext.functionList {
                if function.name == targetFunctionName {
                    return  function
                }
            }
            lexicalEnvironmentContext = lexicalEnvironmentContext?.parentLexicalEnvironment
        }
    }


    func findOriginalFunctionCallIdentifier(calledExpression: ExprSyntax?) -> String? {
        var tmpcalledExpression: ExprSyntax? = calledExpression
        while(true) {
            if let memberAccess = tmpcalledExpression?.as(MemberAccessExprSyntax.self) {
                tmpcalledExpression = memberAccess.base
            } else if let functionCall = tmpcalledExpression?.as(FunctionCallExprSyntax.self) {
                tmpcalledExpression = functionCall.calledExpression
            } else if  let specializeExpr = tmpcalledExpression?.as(SpecializeExprSyntax.self) {
                 tmpcalledExpression = specializeExpr.expression
            } else if let identifier = tmpcalledExpression?.as(IdentifierExprSyntax.self)  {
                return identifier.identifier.text
            }  else {
                return nil
            }
        }
    }

    /// 处理赋值运算符
    func dealWithAssignmentExpr(node: ClosureExprSyntax, exprList : ExprListSyntax) {
        guard exprList.count == 3,
              let firstExpr = exprList.first,
              exprList[exprList.index(after: exprList.startIndex)].is(AssignmentExprSyntax.self) else { return }

        /// 1. 找到被赋值的标识符
        var targetIdentifier: String = ""
        var loopTarget: ExprSyntax? = firstExpr

        while(true) {
            if let identifier = loopTarget?.as(IdentifierExprSyntax.self) {
                targetIdentifier = identifier.identifier.text
                break
            }
            if let memberAccess = loopTarget?.as(MemberAccessExprSyntax.self) {
                loopTarget = memberAccess.base
                continue
            }
            break
        }

        guard !targetIdentifier.isEmpty else { return }

        if targetIdentifier == "self" {
            if currentContext?.undeclareIdentifiers.contains("self") ?? false {
                 violations.append(node.positionAfterSkippingLeadingTrivia)
               }
        } else if let variableDec = findVariableDecByTree(currentLexicalEnvironmentContext: currentLexicalEnvironmentContext?.parentLexicalEnvironment, targetIdentifier: targetIdentifier) {
            if currentContext?.undeclareIdentifiers.contains(targetIdentifier) ?? false {
                 violations.append(node.positionAfterSkippingLeadingTrivia)
            } else if variableDec.type == .field {
                 /// 如果是类的字段
                 if currentContext?.undeclareIdentifiers.contains("self") ?? false {
                    violations.append(node.positionAfterSkippingLeadingTrivia)
                 }
            }
        }
    }

    func dealWithFunctionCallExpr(node: ClosureExprSyntax) {

        /// 1. 如果是闭包声明时直接调用，与直接执行代码没有区别；过滤掉
        if let functionCallExpr = node.parent?.as(FunctionCallExprSyntax.self),
           let calledExpression =  functionCallExpr.calledExpression.as(ClosureExprSyntax.self),
           calledExpression == node  {
            return
        }

        /// 找到闭包作为参数传递的函数调用
        var targetFunctionCallExpr: FunctionCallExprSyntax? = nil

        /// 闭包作为参数传入方法
        if let tupleExprElementNode = node.parent?.as(TupleExprElementSyntax.self),
           let tupleExprElementListNode = tupleExprElementNode.parent?.as(TupleExprElementListSyntax.self),
           let functionCallExpr = tupleExprElementListNode.parent?.as(FunctionCallExprSyntax.self) {
            targetFunctionCallExpr = functionCallExpr
        }

        /// 尾随闭包
        if let functionCallExpr = node.parent?.as(FunctionCallExprSyntax.self),
           let trailingClosure =  functionCallExpr.trailingClosure?.as(ClosureExprSyntax.self),
           trailingClosure == node {
            targetFunctionCallExpr = functionCallExpr
        }

        /// 额外尾随闭包
        if let additionTailClosure = node.parent?.as(MultipleTrailingClosureElementSyntax.self),
           let functionCallExpr = additionTailClosure.parent?.parent?.as(FunctionCallExprSyntax.self) {
            targetFunctionCallExpr = functionCallExpr
        }

        /// 2. 筛除掉方法或函数传入的闭包都是同步调用，不会持有，不会引发内存问题
        ///     - 集合相关方法和高级函数；
        ///     - snpKit 方法
        let collectionFunctionNameArray = ["firstIndex", "first", "last", "lastIndex", "contains", "allSatisfy",  "map", "compactMap", "flatMap", "reduce", "filter", "sorted", "forEach","removeAll"]
        let snpkitArray: [String] = ["makeConstraints","remakeConstraints", "updateConstraints"]
        let uikitArray: [String] = ["dismiss"]
        let ignoreFunctionArray = collectionFunctionNameArray + snpkitArray + uikitArray

        let uikitCallExpressArray: [String] = ["UIView.animate","UIView.animateKeyframes", "UIView.addKeyframe","UIView.transition","UIView.modifyAnimations","UIView.performWithoutAnimation"]
        let dispatchQueueCallExpressArray: [String] = ["DispatchQueue.main.async","DispatchQueue.main.sync","DispatchQueue.main.asyncAfter","DispatchQueue.global().asyncAfter","DispatchQueue.global().async"]
        let ignoreCallExpressArray = uikitCallExpressArray + dispatchQueueCallExpressArray

        let ignoreSpecializeArray: [String] = ["TransformOf"]


        /// 筛除掉同步调用方法
        if let targetFunctionCallExpr {
                /// MemberAccess
                if let calledExpression = targetFunctionCallExpr.calledExpression.as(MemberAccessExprSyntax.self) {
                    let memberAccessStr = ZMSwiftSyntaxTool.syntaxStr(calledExpression)
                    if ignoreFunctionArray.contains(calledExpression.name.text) {
                        return
                    }
                    if ignoreCallExpressArray.contains(memberAccessStr) {
                        return
                    }
                }
                ///
                if let specializeExpr = targetFunctionCallExpr.calledExpression.as(SpecializeExprSyntax.self),
                   let identifierExpr = specializeExpr.expression.as(IdentifierExprSyntax.self),
                   ignoreSpecializeArray.contains(identifierExpr.identifier.text) {
                    return
                }
        }


        var targetIdentifier: String?
        var functionName: String?
        var targetExpr: ExprSyntax? = targetFunctionCallExpr?.calledExpression
        if let specializeExpr = targetExpr?.as(SpecializeExprSyntax.self) {
            targetExpr = specializeExpr.expression
        }

        if let targetFunctionCallExpr {
            if let identifier = targetFunctionCallExpr.calledExpression.as(IdentifierExprSyntax.self)  {
                functionName = identifier.identifier.text
            } else if let identifier = findOriginalFunctionCallIdentifier(calledExpression: targetExpr) {
                targetIdentifier = identifier
            }
        }

        if let targetIdentifier {
            guard !targetIdentifier.isEmpty else { return }

            if targetIdentifier == "self" {
                if currentContext?.undeclareIdentifiers.contains("self") ?? false {
                 violations.append(node.positionAfterSkippingLeadingTrivia)
               }
            } else if let variableDec = findVariableDecByTree(currentLexicalEnvironmentContext: currentLexicalEnvironmentContext?.parentLexicalEnvironment, targetIdentifier: targetIdentifier) {
                 if currentContext?.undeclareIdentifiers.contains(targetIdentifier) ?? false {
                        violations.append(node.positionAfterSkippingLeadingTrivia)
                 } else if variableDec.type == .field {
                      /// 如果是类的字段
                     if currentContext?.undeclareIdentifiers.contains("self") ?? false {
                        violations.append(node.positionAfterSkippingLeadingTrivia)
                     }
                 }
             }
        } else if let functionName {
            guard !functionName.isEmpty,
                  let funcDec = findFunctionDecByTree(currentLexicalEnvironmentContext: currentLexicalEnvironmentContext?.parentLexicalEnvironment, targetFunctionName: functionName)  else { return }

            if funcDec.type == .method {
                /// 如果是类的字段
                if currentContext?.undeclareIdentifiers.contains("self") ?? false {
                    violations.append(node.positionAfterSkippingLeadingTrivia)
                }
            }
        }
    }
}
