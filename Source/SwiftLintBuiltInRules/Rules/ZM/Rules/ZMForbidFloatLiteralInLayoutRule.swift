//
//  ZMForbidFloatLiteralInLayoutRule.swift
//
//
//
//  Created by 朱猛 on 2024/8/6.
//

import Foundation
import SwiftSyntax

struct ZMForbidFloatLiteralInLayoutRule: SwiftSyntaxRule {

    var configuration = SeverityConfiguration<Self>(.warning)

    init() {}

    static let description = RuleDescription(
        identifier: "ZM_Forbid_Float_Literal_In_Layout_Rule",
        name: "Forbid Float Literal In Layout Rule",
        description: "在布局计算中禁止使用浮点数字面值参与计算",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""
            var block = { [weak self] in
                self?.test()
            }
        """)
        ],
        triggeringExamples: [
            Example("""
            var block = {  in
                self.test()
            }
        """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor<ConfigurationType> {
        return Visitor(configuration: configuration, file: file)
    }
}


extension ZMForbidFloatLiteralInLayoutRule {

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {

        var snpFunctionCall: [FunctionCallExprSyntax] = []

        var rectFunctionCall: [FunctionCallExprSyntax] = []

        var exprList: [ExprListSyntax] = []

        override func visitPost(_ node: FloatLiteralExprSyntax) {

           guard let floatValue = Double(node.floatingDigits.text), floatValue == 0.5 || floatValue == 0.3 else { return }

           if !snpFunctionCall.isEmpty {
                violations.append(node.positionAfterSkippingLeadingTrivia)
           }

           if !rectFunctionCall.isEmpty {
                violations.append(node.positionAfterSkippingLeadingTrivia)
           }
        }

        override func visit(_ node: ExprListSyntax) -> SyntaxVisitorContinueKind  {
           return .skipChildren
        }

        override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            if !snpFunctionCall.isEmpty || !rectFunctionCall.isEmpty {
                return .visitChildren
            }


            if let memberAccessExpr = node.calledExpression.as(MemberAccessExprSyntax.self),
               ["makeConstraints","remakeConstraints","updateConstraints"].contains(memberAccessExpr.name.text) {
                snpFunctionCall.append(node)
            }

            if let identifierExpr = node.calledExpression.as(IdentifierExprSyntax.self),
               ["CGRect"].contains(identifierExpr.identifier.text) {
                rectFunctionCall.append(node)
            }

            return .visitChildren
        }


        override func visitPost(_ node: FunctionCallExprSyntax) {
            snpFunctionCall.removeAll(where: { $0 == node })
            rectFunctionCall.removeAll(where: { $0 == node})
        }

    }
}
