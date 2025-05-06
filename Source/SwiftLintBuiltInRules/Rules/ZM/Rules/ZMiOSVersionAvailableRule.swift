//
//  ZMiOSVersionAvailableConfiguration.swift
//  SwiftLint
//
//  Created by 朱猛 on 2025/5/6.
//


import Foundation
import SwiftSyntax
import SwiftLintCore

/**
 请确认App最低iOS版本限制，删除无效的#available()代码
 */
struct ZMiOSVersionAvailableRule: SwiftSyntaxRule {

    var configuration = ZMiOSVersionAvailableConfiguration(majorVersion: 12, minorVersion: 4, severityConfiguration: .error)

    init() {}

    static let description = RuleDescription(
        identifier: "ZM_iOS_Version_Available_Rule",
        name: "iOS Version Rule",
        description: "请确认App最低iOS版本限制，删除无效的#available()代码",
        kind: .lint,
        nonTriggeringExamples: [
            Example("""
            if #available(iOS 13, *) {

            }
        """)
        ],
        triggeringExamples: [
            Example("""
            if #available(iOS 10, *) {

            }
        """)
        ]
    )

    func makeVisitor(file: SwiftLintFile) -> ViolationsSyntaxVisitor<ConfigurationType> {
        Visitor(configuration: configuration, file: file)
    }

    func makeViolation(file: SwiftLintFile, violation: ReasonedRuleViolation) -> StyleViolation {
        return StyleViolation(
            ruleDescription: Self.description,
            severity: configuration.severity,
            location: Location(file: file, position: violation.position),
            reason: violation.reason
        )
    }
}


extension ZMiOSVersionAvailableRule {

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {

        override func visitPost(_ node: AvailabilityConditionSyntax) {
            for argument in node.availabilityArguments {
                if let restriction = argument.argument.as(PlatformVersionSyntax.self),
                  restriction.platform.text == "iOS",
                  let version = restriction.version {
                    let majorVersion = Int(version.major.text) ?? 0
                    var minorVersion = 0
                    version.components.enumerated().forEach({(index, version) in
                        if index == 0 {
                            minorVersion = Int(version.number.text) ?? 0
                        }
                    })
                    
                    
                    let reason = "当前App最低支持iOS版本为\(configuration.majorVersion).\(configuration.minorVersion)，请删除无效的#available()代码"
                    if majorVersion < configuration.majorVersion {
                        let violation = ReasonedRuleViolation(position: node.positionAfterSkippingLeadingTrivia, reason: reason) 
                        violations.append(violation)
                        break 
                    } else if majorVersion == configuration.majorVersion  && minorVersion < configuration.minorVersion {
                        let violation = ReasonedRuleViolation(position: node.positionAfterSkippingLeadingTrivia, reason: reason) 
                        violations.append(violation)
                        break 
                    }
               }
           }
        }

    }

}

@AutoApply
struct ZMiOSVersionAvailableConfiguration: SeverityBasedRuleConfiguration, Equatable {
    typealias Parent = ZMiOSVersionAvailableRule
    typealias Severity = SeverityConfiguration<ZMiOSVersionAvailableRule>

    @ConfigurationElement(key: "major_version")
    private(set) var majorVersion = 12
    @ConfigurationElement(key: "minor_version")
    private(set) var minorVersion = 4
    @ConfigurationElement(key: "severityConfiguration")
    var severityConfiguration = Severity.error
}
