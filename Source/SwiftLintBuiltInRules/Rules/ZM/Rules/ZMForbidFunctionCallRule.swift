//
//  ZMForbidFunctionCallRule.swift
//  SwiftLint
//
//  Created by 朱猛 on 2025/5/5.
//
import Foundation
import SwiftSyntax

/**
 *  ZMForbidFunctionCallRule 禁用指定函数调用
 *  */
struct ZMForbidFunctionCallRule: SwiftSyntaxRule {

    var configuration = ZMForbidFunctionCallRuleConfiguartion<Self>()

    init() {}

    static let description = RuleDescription(
        identifier: "ZM_Forbid_Function_Call_Rule",
        name: "Forbid Function Call Rule",
        description: "禁用指定函数调用",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""
            UIFont.init(name: Font_PingFangSCRegular, size: 14)
        """)
        ],
        triggeringExamples: [
            Example("""
            UIFont.systemFont(ofSize: 14)
        """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor<ZMForbidFunctionCallRuleConfiguartion<Self>> {
        ZMForbidFunctionCallRuleVisitor(configuration: configuration, file: file)
    }
}


struct ZMForbidFunctionCallRuleData: Equatable, AcceptableByConfigurationElement {
    
    var type: String
    var functionDescArray: [String]
    var fixTip: String

    static let FunctionNameType: String = "FunctionNameType"
    static let FunctionCallType: String = "FunctionCallType"
    
    init(fromAny value: Any, context ruleID: String) throws {
        guard let dateDelimiters = value as? [String: Any],
              let type = dateDelimiters["type"] as? String,
              let functionDescArray = dateDelimiters["functionDescArray"] as? [String],
              let fixTip = dateDelimiters["fixTip"] as? String else {
                  throw Issue.invalidConfiguration(ruleID: ruleID)
              }
        self.type = type
        self.functionDescArray = functionDescArray
        self.fixTip = fixTip
    }
   
    func asOption() -> OptionType {
        return .nest {
            "type" => .string(type)
            "functionName" => .list(functionDescArray.map({ OptionType.string($0)}))
            "fixTip" => .string(fixTip)
        }
    }
}

@AutoApply
struct ZMForbidFunctionCallRuleConfiguartion<Parent: Rule>: SeverityBasedRuleConfiguration, Equatable {
    @ConfigurationElement(key: "forbid_function_call_array")
    private(set) var forbidFunctionCallArray: [ZMForbidFunctionCallRuleData] = []
    @ConfigurationElement(key: "severityConfiguration")
    var severityConfiguration: SeverityConfiguration<Parent> = .error
}

final class ZMForbidFunctionCallRuleVisitor<T: Rule>: ViolationsSyntaxVisitor<ZMForbidFunctionCallRuleConfiguartion<T>> {
    
    
    override func visitPost(_ node: FunctionCallExprSyntax) {
        var functionName: String = ""
        var functionCall: String = ""
        if let memberAccessExpr = node.calledExpression.as(MemberAccessExprSyntax.self) {
            functionName = memberAccessExpr.declName.baseName.text
            functionCall = ZMSwiftSyntaxTool.syntaxStr(memberAccessExpr)
        } else if let identifierExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
        } else if let identifierExpr = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            functionName = identifierExpr.baseName.text
            functionCall = identifierExpr.baseName.text
        }
        
        for forbidFunctionCall in configuration.forbidFunctionCallArray {
            if forbidFunctionCall.type == ZMForbidFunctionCallRuleData.FunctionNameType,
               !functionName.isEmpty  {
                
                if forbidFunctionCall.functionDescArray.contains(where: { $0 == functionName }) {
                    let violation = ReasonedRuleViolation(position: node.positionAfterSkippingLeadingTrivia, reason: forbidFunctionCall.fixTip)
                    violations.append(violation)
                }
                
            } else if forbidFunctionCall.type == ZMForbidFunctionCallRuleData.FunctionCallType,
                      !functionCall.isEmpty {
                if forbidFunctionCall.functionDescArray.contains(where: { $0 == functionCall }) {
                    let violation = ReasonedRuleViolation(position: node.positionAfterSkippingLeadingTrivia, reason: forbidFunctionCall.fixTip)
                    violations.append(violation)
                }
            }
        }
    }
}

