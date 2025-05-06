//
//  ZMRules.swift
//  
//
//  Created by 朱猛 on 2024/8/7.
//

import Foundation

public let ZM_Rules: [any Rule.Type] = [
    ZMLazyViewRule.self,
    ZMBlockCycleReferenceRule.self,
    ZMBlockCycleReferenceV2Rule.self,
    ZMForbidFloatLiteralInLayoutRule.self,
    ZMForbidArrayFilterFirstRule.self,
    ZMForbidFunctionCallRule.self,
    ZMForbidMemberAccessRule.self,
    ZMIQKeyboardManagerPairRule.self,
    ZMiOSVersionAvailableRule.self
]
