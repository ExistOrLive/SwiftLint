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
    ZMForbidFloatLiteralInLayoutRule.self
]
