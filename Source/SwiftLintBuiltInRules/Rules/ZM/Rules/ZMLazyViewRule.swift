//
//  ZMLazyViewRule.swift
//
//
//  Created by 朱猛 on 2024/8/6.
//

import Foundation
import SwiftSyntax

struct ZMLazyViewRule: SwiftSyntaxRule {


    var configuration = SeverityConfiguration<Self>(.warning)

    init() {}

    static let description = RuleDescription(
        identifier: "ZM_Lazy_Property_Rule",
        name: "Lazy Property Rule",
        description: "使用闭包调用结果赋值的属性需要使用懒加载",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""
            lazy var successImageView: UIImageView = {
                let img = UIImageView()
                img.image = UIImage(named: "pay_success")
                return img
            }()
        """)
        ],
        triggeringExamples: [
            Example("""
            var successImageView: UIImageView = {
                let img = UIImageView()
                img.image = UIImage(named: "pay_success")
                return img
            }()
        """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor<ConfigurationType> {
        return Visitor(configuration: configuration, file: file)
    }
}


extension ZMLazyViewRule {

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {

        override func visitPost(_ node: VariableDeclSyntax) {

            /// 1. 检查属性声明是否在class，struct 的成员声明中
            guard let superSyntax = node.parent,
                  superSyntax.is(MemberBlockItemSyntax.self) else {
                return
            }

            /// 2. 检查是否有lazy修饰 且 非 static
            var hasLazyModifier: Bool = false
            var hasStaticModifier: Bool = false
           
            for modifier in node.modifiers {
                    if modifier.name.text == "lazy" {
                        hasLazyModifier = true
                    }
                    if modifier.name.text == "static" {
                        hasStaticModifier = true
                    }
            }
            

            guard !hasLazyModifier && !hasStaticModifier else {
                return
            }

            /// 3. 检查赋值语句
            guard node.bindings.count == 1,
                  let bindding = node.bindings.first,
                  let initializer = bindding.initializer else {
                return
            }


            /// 4. 如果赋值语句为闭包函数调用
            if let functionCallExprSyntax = initializer.value.as(FunctionCallExprSyntax.self),
               functionCallExprSyntax.calledExpression.is(ClosureExprSyntax.self)  {
                violations.append(node.positionAfterSkippingLeadingTrivia)
            }
        }
    }

}
