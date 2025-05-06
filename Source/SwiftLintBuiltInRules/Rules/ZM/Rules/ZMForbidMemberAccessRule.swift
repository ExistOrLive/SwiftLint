//
//  ZMForbidMemberAccessRuleData.swift
//  SwiftLint
//
//  Created by 朱猛 on 2025/5/6.
//


import Foundation
import SwiftSyntax

/**
  * 禁用指定Member Access代码调用
 **/
struct ZMForbidMemberAccessRule: SwiftSyntaxRule {

    var configuration = ZMForbidMemberAccessRuleConfiguartion<Self>()

    init() {}

    static let description = RuleDescription(
        identifier: "ZM_Forbid_Member_Access_Rule",
        name: "Forbid Member Access Rule",
        description: "禁用指定Member Access代码调用",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""
            UIScreen.main.bounds.size
        """)
        ],
        triggeringExamples: [
            Example("""
            UIScreen.mainSize
        """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor<ConfigurationType> {
        ZMForbidMemberAccessRuleVisitor(configuration: configuration, file: file)
    }
}

/// 禁用成员访问 配置
struct ZMForbidMemberAccessRuleData: Equatable, AcceptableByConfigurationElement {
    var memberAccessDescArray: [String]
    var fixTip: String
    
    init(fromAny value: Any, context ruleID: String) throws {
        guard let dic = value as? [String:Any],
              let memberAccessDescArray = dic["memberAccessDescArray"] as? [String],
              let fixTip = dic["fixTip"] as? String else {
            throw Issue.invalidConfiguration(ruleID: ruleID)
        }
        self.memberAccessDescArray = memberAccessDescArray
        self.fixTip = fixTip
    }

    func asOption() -> OptionType {
        return .nest {
            "memberAccessDescArray" => .list(memberAccessDescArray.map({ OptionType.string($0)}))
            "fixTip" => .string(fixTip)
        }
    }
}

@AutoApply
struct ZMForbidMemberAccessRuleConfiguartion<Parent: Rule>: SeverityBasedRuleConfiguration, Equatable {

    @ConfigurationElement(key: "forbid_member_access_array")
    private(set) var forbidMemberAccessArray: [ZMForbidMemberAccessRuleData] = []
    @ConfigurationElement(key: "severityConfiguration")
    var severityConfiguration: SeverityConfiguration<Parent> = .error
}



final class ZMForbidMemberAccessRuleVisitor<T: Rule>: ViolationsSyntaxVisitor<ZMForbidMemberAccessRuleConfiguartion<T>> {

    override func visitPost(_ node: MemberAccessExprSyntax) {
            if node.parent?.is(MemberAccessExprSyntax.self) ?? false {
                /// 不处理嵌套在MemberAccess中的MemberAccess
                return
            }

            let memberAccessStr = ZMSwiftSyntaxTool.syntaxStr(node)

            guard !memberAccessStr.isEmpty else { return }

            for memberAcceesData in configuration.forbidMemberAccessArray {
                if memberAcceesData.memberAccessDescArray.contains(where: {
                    memberAccessStr.contains($0)
                }) {
                     let violation = ReasonedRuleViolation(position: node.positionAfterSkippingLeadingTrivia, reason: memberAcceesData.fixTip)
                     violations.append(violation)
                }
            }
    }
}


///
