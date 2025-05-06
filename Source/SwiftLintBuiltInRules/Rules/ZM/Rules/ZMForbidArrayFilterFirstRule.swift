//
//  ZMForbidArrayFilterFirstRule.swift
//  SwiftLint
//
//  Created by 朱猛 on 2025/5/5.
//


import Foundation
import SwiftSyntax


/**
 * 建议使用 first(where:) 替换  filter { ... }.first 
 */

struct ZMForbidArrayFilterFirstRule: SwiftSyntaxRule {

    var configuration = SeverityConfiguration<Self>(.warning)

    init() {}

    static let description = RuleDescription(
        identifier: "ZM_Forbid_Array_Filter_First_Rule",
        name: "ZM Forbid Array Filter First Rule",
        description: "建议使用 first(where:) 替换  filter { ... }.first ",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""
            filter { ... }.first
        """)
        ],
        triggeringExamples: [
            Example("""
            first(where:)
        """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor<ConfigurationType> {
        Visitor(configuration: configuration, file: file)
    }
}


extension ZMForbidArrayFilterFirstRule {

    final class Visitor: ZMFileContextVisitor<ConfigurationType> {

        override func visitPost(_ node: MemberAccessExprSyntax) {
            super.visitPost(node)
            guard node.declName.baseName.text == "first" else { return }

            guard let functionCall = node.base?.as(FunctionCallExprSyntax.self) else { return }

            /// array.filter({ $0 > 0}).first
            /// array.filter { $0 > 0 }.first
            if let functionCall = functionCall.calledExpression.as(MemberAccessExprSyntax.self),
               functionCall.declName.baseName.text == "filter" {
               violations.append(node.positionAfterSkippingLeadingTrivia)
            }
        }

    }


}
