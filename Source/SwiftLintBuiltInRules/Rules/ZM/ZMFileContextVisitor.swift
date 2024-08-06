//
//  ZMFileContextVisitor.swift
//  
//
//  Created by 朱猛 on 2024/8/6.
//

import SwiftSyntax

/// 类，结构体，扩展，闭包，函数，代码块 是词法环境
class ZMFileLexicalEnvironmentContext {
    let node: any SyntaxProtocol
    let type: ZMFileLexicalEnvironmentType
    let name: String

    /// 父词法环境
    weak var parentLexicalEnvironment: ZMFileLexicalEnvironmentContext?  /// 父级词法环境
    /// 子词法环境
    var childLexicalEnvironmentArray: [ZMFileLexicalEnvironmentContext] = []

    /// 变量列表
    var variableList: [ZMLexicalEnvironmentVariableModel] = []
    /// 方法列表
    var functionList: [ZMLexicalEnvironmentFunctionModel] = []

    init(type: ZMFileLexicalEnvironmentType, node: any SyntaxProtocol, name: String, parentLexicalEnvironment: ZMFileLexicalEnvironmentContext?) {
        self.type = type
        self.node = node
        self.name = name
        self.parentLexicalEnvironment = parentLexicalEnvironment
    }
}

/// 词法环境类型
enum ZMFileLexicalEnvironmentType: String {
    case classType           // 类          ClassDeclSyntax
    case structType          // 结构体       StructDeclSyntax
    case enumType            // 枚举         EnumDeclSyntax
    case closureType         // 闭包         ClosureExprSyntax
    case functionType        // 函数/方法     FunctionDeclSyntax
    case codeBlockType       // 代码块
    case extensionType       // 扩展        ExtensionDeclSyntax
    case fileRoot            // 文件顶级     SourceFileSyntax

}


/// 词法环境变量类型
enum ZMLexicalEnvironmentVariableType: String {
    case localVariable             /// 局部变量
    case capatureVariable          /// 捕获参数列表             ClosureCaptureItemSyntax
    case field                     /// 类，结构体，枚举的字段
    case staticFiled               /// 类，结构体，枚举的静态字段
    case functionParam             /// 方法/函数的参数
    case gobalVariable             /// 全局变量
}

/// 词法环境变量model
class ZMLexicalEnvironmentVariableModel {
    let type: ZMLexicalEnvironmentVariableType
    let node: any SyntaxProtocol
    let name: String
    let typeName: String
    var isWeak: Bool
    var isUnowned: Bool
    weak var lexicalEnvironment: ZMFileLexicalEnvironmentContext?

    init(type: ZMLexicalEnvironmentVariableType,
         node: any SyntaxProtocol,
         name: String,
         typeName: String,
         isWeak: Bool,
         isUnowned: Bool,
         lexicalEnvironment: ZMFileLexicalEnvironmentContext) {
            self.type = type
            self.node = node
            self.name = name
            self.typeName = typeName
            self.isWeak = isWeak
            self.isUnowned = isUnowned
            self.lexicalEnvironment = lexicalEnvironment
    }

    var description: String {
        return "变量 \(name) \(type.rawValue) \(typeName) \(isWeak) \(isUnowned) \(node.id)"
    }
}


/// 词法环境变量类型
enum ZMLexicalEnvironmentFuntionType: String {
    case globalFunction            /// 全局函数
    case localFunction             /// 本地函数声明
    case method                    /// 类，结构体，枚举方法
    case staticMethod              /// 方法

}

/// 词法环境变量model
class ZMLexicalEnvironmentFunctionModel {
    let type: ZMLexicalEnvironmentFuntionType
    let node: any SyntaxProtocol
    let name: String
    let fullName: String
    weak var lexicalEnvironment: ZMFileLexicalEnvironmentContext?

    init(type: ZMLexicalEnvironmentFuntionType,
         node: any SyntaxProtocol,
         name: String,
         fullName: String,
         lexicalEnvironment: ZMFileLexicalEnvironmentContext) {
            self.type = type
            self.node = node
            self.name = name
            self.lexicalEnvironment = lexicalEnvironment
            self.fullName = fullName
    }

    var description: String {
        return "函数 \(name) \(type.rawValue) \(node.id)"
    }
}

class ZMFileContextVisitor<Configuration: RuleConfiguration>: ViolationsSyntaxVisitor<Configuration> {

    var fileRootEnvironment: ZMFileLexicalEnvironmentContext?

    /// 当前词法环境
    var currentLexicalEnvironmentContext:  ZMFileLexicalEnvironmentContext?

    override func visit(_ node: SourceFileSyntax) -> SyntaxVisitorContinueKind {
        let context = ZMFileLexicalEnvironmentContext(type: .fileRoot, node: node, name: "", parentLexicalEnvironment: nil)
        self.fileRootEnvironment = context
        self.currentLexicalEnvironmentContext = context
        return super.visit(node)
    }

    override func visitPost(_ node: SourceFileSyntax) {
        super.visitPost(node)
        self.currentLexicalEnvironmentContext =  self.currentLexicalEnvironmentContext?.parentLexicalEnvironment
    }

    /// 类声明词法环境处理
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        if let parentContext = currentLexicalEnvironmentContext {
             let name = node.identifier.text
             let context = ZMFileLexicalEnvironmentContext(type: .classType, node: node, name: name, parentLexicalEnvironment: parentContext)
             parentContext.childLexicalEnvironmentArray.append(context)
             self.currentLexicalEnvironmentContext = context
        }
        return super.visit(node)
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        super.visitPost(node)
        self.currentLexicalEnvironmentContext =  self.currentLexicalEnvironmentContext?.parentLexicalEnvironment
    }

      /// 结构体声明词法环境处理
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if let parentContext = currentLexicalEnvironmentContext {
             let name = node.identifier.text
             let context = ZMFileLexicalEnvironmentContext(type: .structType, node: node, name: name, parentLexicalEnvironment: parentContext)
             parentContext.childLexicalEnvironmentArray.append(context)
             self.currentLexicalEnvironmentContext = context
        }
        return super.visit(node)
    }

    override func visitPost(_ node: StructDeclSyntax) {
        super.visitPost(node)
        self.currentLexicalEnvironmentContext =  self.currentLexicalEnvironmentContext?.parentLexicalEnvironment
    }

      /// 扩展声明词法环境处理
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {

        if let parentContext = currentLexicalEnvironmentContext {
             let name = node.extendedType.as(SimpleTypeIdentifierSyntax.self)?.name.text ?? ""
             if let originDeclContext = parentContext.childLexicalEnvironmentArray.first(where: { $0.name ==  name && ($0.type == .structType || $0.type == .enumType || $0.type == .classType || $0.type == .extensionType) }) {
                /// 找到原类，结构体，枚举或者 第一个扩展的词法环境
                self.currentLexicalEnvironmentContext = originDeclContext
             } else {
                let context = ZMFileLexicalEnvironmentContext(type: .extensionType, node: node, name: name, parentLexicalEnvironment: parentContext)
                parentContext.childLexicalEnvironmentArray.append(context)
                self.currentLexicalEnvironmentContext = context
             }
        }
        return super.visit(node)
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        super.visitPost(node)
        self.currentLexicalEnvironmentContext =  self.currentLexicalEnvironmentContext?.parentLexicalEnvironment
    }

    /// 枚举声明词法环境处理
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        if let parentContext = currentLexicalEnvironmentContext {
             let name = node.identifier.text
             let context = ZMFileLexicalEnvironmentContext(type: .structType, node: node, name: name, parentLexicalEnvironment: parentContext)
             parentContext.childLexicalEnvironmentArray.append(context)
             self.currentLexicalEnvironmentContext = context
        }
        return super.visit(node)
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        super.visitPost(node)
        self.currentLexicalEnvironmentContext =  self.currentLexicalEnvironmentContext?.parentLexicalEnvironment
    }

    /// 处理闭包
    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        if let parentContext = currentLexicalEnvironmentContext {
             let context = ZMFileLexicalEnvironmentContext(type: .closureType, node: node, name: "", parentLexicalEnvironment: parentContext)
             if let signature = node.signature {

                /// 1. 处理捕获列表
                if let captures = signature.capture {
                    captures.items.forEach{ item in
                        let name = item.expression.as(IdentifierExprSyntax.self)?.identifier.text ?? ""
                        var isWeak = false
                        var isUnowned =  false
                        let specifierText = item.specifier?.specifier.text ?? ""
                        if specifierText == "weak" {
                            isWeak = true
                        }
                        if specifierText == "unowned" {
                            isUnowned = true
                        }
                        let captureVariable = ZMLexicalEnvironmentVariableModel(type: .capatureVariable, node: item, name: name, typeName: "", isWeak: isWeak, isUnowned: isUnowned, lexicalEnvironment: context)
                        context.variableList.append(captureVariable)
                    }
                }

                 /// 2. 闭包入参
                if let parameterList = signature.input?.as(ClosureParameterClauseSyntax.self)?.parameterList {
                      // 带括号
                     parameterList.forEach { parameter in
                         let name = parameter.firstName.text
                         let type = parameter.type?.description ?? ""
                         let param = ZMLexicalEnvironmentVariableModel(type: .functionParam, node: parameter, name: name, typeName: type, isWeak: false, isUnowned: false, lexicalEnvironment: context)
                         context.variableList.append(param)
                     }
                } else if let parameterList = signature.input?.as(ClosureParamListSyntax.self) {
                    /// 不带括号
                    parameterList.forEach { parameter in
                         let name = parameter.name.text
                         let type = ""
                         let param = ZMLexicalEnvironmentVariableModel(type: .functionParam, node: parameter, name: name, typeName: type, isWeak: false, isUnowned: false, lexicalEnvironment: context)
                         context.variableList.append(param)
                     }
                }

             }
             parentContext.childLexicalEnvironmentArray.append(context)
             self.currentLexicalEnvironmentContext = context
        }
        return super.visit(node)
    }

    override func visitPost(_ node: ClosureExprSyntax) {
        super.visitPost(node)
        self.currentLexicalEnvironmentContext =  self.currentLexicalEnvironmentContext?.parentLexicalEnvironment
    }

    /// 处理函数声明
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let parentContext = currentLexicalEnvironmentContext {
             let name = node.identifier.text
             let fullName = node.identifier.text + node.signature.description
             /// 函数词法环境
             let context = ZMFileLexicalEnvironmentContext(type: .functionType, node: node, name: name, parentLexicalEnvironment: parentContext)
             node.signature.input.parameterList.forEach { parameter in
                   var name = parameter.firstName.text
                   if let secondName = parameter.secondName?.text {
                       name  = secondName
                   }
                   let type = parameter.type.description
                   let param = ZMLexicalEnvironmentVariableModel(type: .functionParam, node: parameter, name: name, typeName: type, isWeak: false, isUnowned: false, lexicalEnvironment: context)
                   context.variableList.append(param)
             }
             parentContext.childLexicalEnvironmentArray.append(context)

             /// 静态函数
             var isStatic = false
            
            node.modifiers.forEach { (node: DeclModifierSyntax) in
                if node.name.text == "static" {
                    isStatic = true
                }
            }
             

             var functionType: ZMLexicalEnvironmentFuntionType = .globalFunction
             switch parentContext.type {
                case .classType,.structType,.enumType,.extensionType :
                    functionType = isStatic ? .staticMethod : .method
                case .fileRoot:
                    functionType = .globalFunction
                default:
                    functionType = .localFunction
             }
             let functionModel = ZMLexicalEnvironmentFunctionModel(type: functionType, node: node, name: name, fullName: fullName,lexicalEnvironment: parentContext)
             parentContext.functionList.append(functionModel)

             self.currentLexicalEnvironmentContext = context
        }
        return super.visit(node)
    }

    override func visitPost(_ node: FunctionDeclSyntax)  {
        super.visitPost(node)
        self.currentLexicalEnvironmentContext =  self.currentLexicalEnvironmentContext?.parentLexicalEnvironment
    }

      /// 处理代码块词法环境
    override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
        if let parentContext = currentLexicalEnvironmentContext {
             let context = ZMFileLexicalEnvironmentContext(type: .codeBlockType, node: node, name: "", parentLexicalEnvironment: parentContext)
             parentContext.childLexicalEnvironmentArray.append(context)
             self.currentLexicalEnvironmentContext = context
        }
        return super.visit(node)
    }

    override func visitPost(_ node: CodeBlockSyntax)  {
        super.visitPost(node)
        self.currentLexicalEnvironmentContext =  self.currentLexicalEnvironmentContext?.parentLexicalEnvironment
    }

    /// 变量声明
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if let currentLexicalEnvironmentContext = currentLexicalEnvironmentContext {
            var isWeak = false
            var isStatic = false

            
            node.modifiers.forEach { (modifier: DeclModifierSyntax) in
                if modifier.name.text == "weak" {
                    isWeak = true
                }
                if modifier.name.text == "static" {
                    isStatic = true
                }
            }
        

        for binding  in node.bindings {
            if let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
                var type = ""
                if let typeAnnotation = binding.typeAnnotation {
                    type = typeAnnotation.type.description
                }
                var variableType: ZMLexicalEnvironmentVariableType = .localVariable
                switch currentLexicalEnvironmentContext.type {
                    case .classType,.structType,.enumType,.extensionType:
                        variableType =   isStatic ? .staticFiled : .field
                    case .fileRoot:
                        variableType = .gobalVariable
                    default:
                        variableType = .localVariable
                }
                let variable = ZMLexicalEnvironmentVariableModel(type: variableType, node: node, name: name, typeName: type, isWeak: isWeak, isUnowned: false, lexicalEnvironment: currentLexicalEnvironmentContext)
                currentLexicalEnvironmentContext.variableList.append(variable)
            }
        }
        }
        return super.visit(node)
    }

    ///
    override func visitPost(_ node: VariableDeclSyntax) { }

    /// 处理可选绑定
    override func visit(_ node: OptionalBindingConditionSyntax) -> SyntaxVisitorContinueKind {
        if let currentLexicalEnvironmentContext = currentLexicalEnvironmentContext {
             if let bindingIdentifier = node.pattern.as(IdentifierPatternSyntax.self) {
                let name = bindingIdentifier.identifier.text
                let variable = ZMLexicalEnvironmentVariableModel(type: .localVariable, node: node, name: name, typeName: "", isWeak: false, isUnowned: false, lexicalEnvironment: currentLexicalEnvironmentContext)
                currentLexicalEnvironmentContext.variableList.append(variable)
            }
        }
        return .visitChildren
    }

    override func visitPost(_ node: OptionalBindingConditionSyntax) {

    }
}


extension ZMFileContextVisitor {
    func printAllLexicalEnvironment() {
        // guard let root = fileRootEnvironment else { return }
        // var array: [ZMFileLexicalEnvironmentContext] = [root]

        // while(!array.isEmpty) {
        //     let context = array[0]
        //     array.append(contentsOf: context.childLexicalEnvironmentArray)
        //     printLexicalEnvironment(context: context)
        //     array.removeFirst()
        // }

    }

    func printLexicalEnvironment(context: ZMFileLexicalEnvironmentContext) {
        // if context.type == .closureType || context.type == .codeBlockType {
        //     print("打印 \(context.node.description) \(context.node._syntaxNode.id)----- ")
        // } else {
        //     print("打印 \(context.name) \(context.node._syntaxNode.id)----- ")
        // }


        // print("词法环境类型 \(context.type.rawValue)")

        // print("词法环境变量列表")
        // context.variableList.forEach { model in
        //     print(model.description)
        // }

        // print("词法环境函数列表")
        // context.functionList.forEach { model in
        //     print(model.description)
        // }

        // print("")
    }
}
