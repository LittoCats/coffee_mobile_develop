//
//  CMNSAttributedStringExtension.swift
//  CoffeeMobile
//
//  Created by 程巍巍 on 5/25/15.
//  Copyright (c) 2015 Littocats. All rights reserved.
//

import Foundation
import UIKit

extension NSAttributedString {
    
    
    /**
    MARK: 由自定义的 xml 字符串生成  attributedString
    支持的 属性参照 NSAttributedString.XMLParser.ExpressionMap
    */
//    convenience init(xml: String){
//        self.init(xml:xml, defaultAttribute: [String: AnyObject]())
//    }
//    
//    convenience init(xml: String, defaultAttribute: [String: AnyObject]){
//        self.init(attributedString: XMLParser(xml: xml,defaultAttribute: defaultAttribute).parse().maString)
//    }
    
    private class XMLParser {
        private var maString = NSMutableAttributedString()
        private var attrStack = [[String: AnyObject]]()
        private var xml: NSString!
        private var regex: NSRegularExpression = NSRegularExpression(pattern: "([<][^<>]*>)", options: NSRegularExpressionOptions.allZeros, error: nil)!
        
        init(xml: String, defaultAttribute: [String: AnyObject]){
            var str = xml
            for (reg, re) in ["\\>": "&more", "\\<": "&less", "<br>": "\n"] {
                str = str.stringByReplacingOccurrencesOfString("\\>", withString: "&more", options: NSStringCompareOptions.allZeros, range: nil)
            }
            attrStack.append(defaultAttribute)
            self.xml = str as String
        }
        
        func parse()->XMLParser {
            regex.enumerateMatchesInString(xml as String, options: NSMatchingOptions.allZeros, range: NSMakeRange(0, xml.length)) {[unowned self] (result: NSTextCheckingResult!, flage: NSMatchingFlags, stop: UnsafeMutablePointer<ObjCBool>) -> Void in
                // 标签
                var label = self.xml.substringWithRange(result.range)
                self.analyzeLabel(label)
                // 文本
                var strStart = result.range.location + result.range.length
                var range = self.xml.rangeOfString("[^<>]*", options: NSStringCompareOptions.RegularExpressionSearch, range: NSMakeRange(strStart, self.xml.length - strStart))
                var str = self.xml.substringWithRange(range)
                if str.isEmpty {return}
                self.buildString(str)
            }
            return self
        }
        
        //MARK: 解析标签
        private func analyzeLabel(label: String){
            var str = label
            // 去除 <> 及多余的空格
            for (reg, re) in ["^<[\\s]*": "", "[\\s]*>$": "", "[\\s]+": " ", "[\\s]*=[\\s]*": "="] {
                str = str.stringByReplacingOccurrencesOfString(reg, withString: re, options: NSStringCompareOptions.RegularExpressionSearch, range: nil)
            }
            
            // 如果是结束标签，则从 stack 中移除最后组属性
            if str.hasPrefix("/"){
                attrStack.removeLast()
                return
            }
            
            if str.hasSuffix("/") {return}
            
            // 解析属性，包含单值表达式（只有key）和赋值表达式（key=value)两种情况, 单值表达式，将做为key value 相同的赋值表达式
            var arr = str.componentsSeparatedByString(" ")
            var kv: [String]
            var kvs: [String: AnyObject]!
            var attr: [String: AnyObject]
            
            if let at = attrStack.last { attr = at}
            else {attr = [String: AnyObject]()}
            
            for item in arr {
                kv = item.componentsSeparatedByString("=")
                if kv.count == 1 {
                    var key = kv[0].lowercaseString
                    kvs = analyzeExpression(key, value: key)
                }else if kv.count == 2 {
                    kvs = analyzeExpression(kv[0].lowercaseString, value: kv[1].lowercaseString)
                }
                
                if kvs != nil {
                    for (k,v) in kvs {
                        attr[k] = v
                    }
                }
            }
            attrStack.append(attr)
        }
        
        
        //MARK: 解析赋值表达式（key=value)
        private func analyzeExpression(key: String, value: String) ->[String: AnyObject] {
            if let analyzer = XMLParser.ExpressionMap[key] {
                return analyzer(key: key, value: value)
            }else{
                return [String: AnyObject]()
            }
        }
        
        //MARK: 解析文本
        private func buildString(str: String) {
            var string = str
            for (reg, re) in [">": "&more", "<": "&less"] {
                string = string.stringByReplacingOccurrencesOfString(re, withString: reg, options: NSStringCompareOptions.allZeros, range: nil)
            }
            if var at = attrStack.last{
                // font
                var font: UIFont?
                var family = at[CMTextFontFamilyAttributeName] as? String
                var size = at[CMTextFontSizeAttributeName] as? Float
                
                if size == nil {size = 17}
                if family == nil {
                    font = UIFont.systemFontOfSize(CGFloat(size!))
                }else{
                    font = UIFont(name: family!, size: CGFloat(size!))
                }
                if font != nil {
                    at[NSFontAttributeName] = font!
                }
                at.removeValueForKey(CMTextFontFamilyAttributeName)
                at.removeValueForKey(CMTextFontSizeAttributeName)
                
                // paragraph
                var para = NSMutableParagraphStyle()
                if let align = at[CMTextAlignmentAttributeName] as? Int {
                    para.alignment = NSTextAlignment(rawValue: align)!
                    at.removeValueForKey(CMTextAlignmentAttributeName)
                }
                if let firstLineHeadIndent = at[CMTextFirstLineHeadIndentAttributeName] as? Float {
                    para.firstLineHeadIndent = CGFloat(firstLineHeadIndent)
                    at.removeValueForKey(CMTextFirstLineHeadIndentAttributeName)
                }
                if let headIndent = at[CMTextHeadIndentAttributeName] as? Float {
                    para.headIndent = CGFloat(headIndent)
                    at.removeValueForKey(CMTextHeadIndentAttributeName)
                }
                if let tailIndent = at[CMTextTailIndentAttributeName] as? Float {
                    para.tailIndent = CGFloat(tailIndent)
                    at.removeValueForKey(CMTextTailIndentAttributeName)
                }
                if let lineSpace = at[CMTextLineSpaceAttributeName] as? Float {
                    para.lineSpacing = CGFloat(lineSpace)
                    at.removeValueForKey(CMTextLineSpaceAttributeName)
                }
                at[NSParagraphStyleAttributeName] = para
                
                // append
                maString.appendAttributedString(NSAttributedString(string: str, attributes: at))
            }else{
                maString.appendAttributedString(NSAttributedString(string: str))
            }
            
        }
    }
}
private let CMTextFontFamilyAttributeName = "CMTextFontFamilyAttributeName"
private let CMTextFontSizeAttributeName = "CMTextFontSizeAttributeName"

private let CMTextAlignmentAttributeName = "NSTextAlignmentAttributeName"
private let CMTextFirstLineHeadIndentAttributeName = "CMTextFirstLineHeadIndentAttributeName"
private let CMTextHeadIndentAttributeName = "CMTextHeadIndentAttributeName"
private let CMTextTailIndentAttributeName = "CMTextTailIndentAttributeName"
private let CMTextLineSpaceAttributeName = "CMTextLineSpaceAttributeName"

private func FloatValue(str: String)->Float {
    var float = (str as NSString).floatValue
    return float
}

extension NSAttributedString.XMLParser {
    typealias EXP = (key: String, value: String)->[String: AnyObject]
    
    static var ExpressionMap: [String: EXP] = [
        
        // foreground/background color
        "color": {EXP in [NSForegroundColorAttributeName: UIColor(script: EXP.1)]},
        "bgcolor": {EXP in [NSBackgroundColorAttributeName: UIColor(script: EXP.1)]},
        
        // font
        "font": {EXP in [CMTextFontFamilyAttributeName: EXP.1]},
        "size": {EXP in [CMTextFontSizeAttributeName: FloatValue(EXP.1)]},
        
        // under line
        "underline": {EXP in [NSUnderlineStyleAttributeName: FloatValue(EXP.1)]},
        "ul": {EXP in
            if EXP.0 == EXP.1 {
                return [NSUnderlineStyleAttributeName: 1]
            }
            return [NSUnderlineStyleAttributeName: FloatValue(EXP.1)]
        },
        "underlinecolor": {EXP in [NSUnderlineColorAttributeName: UIColor(script: EXP.1)]},
        "ulcolor": {EXP in [NSUnderlineColorAttributeName: UIColor(script: EXP.1)]},
        
        // strike though
        "strikethrough": {EXP in [NSStrikethroughStyleAttributeName: FloatValue(EXP.1)]},
        "st": {EXP in
            if EXP.0 == EXP.1 {
                return [NSStrikethroughStyleAttributeName: 1]
            }
            return [NSStrikethroughStyleAttributeName: FloatValue(EXP.1)]
        },
        "strikethroughcolor": {EXP in [NSStrikethroughColorAttributeName: UIColor(script: EXP.1)]},
        "stcolor": {EXP in [NSStrikethroughColorAttributeName: UIColor(script: EXP.1)]},
        
        // stroke 可以间接实现 字体加粗效果
        "strokecolor": {EXP in [NSStrikethroughColorAttributeName: UIColor(script: EXP.1)]},
        "stroke": {EXP in [NSStrokeWidthAttributeName: FloatValue(EXP.1)]},
        
        // paragraph
        // text align
        "-|": {EXP in [CMTextAlignmentAttributeName: NSTextAlignment.Right.rawValue]},
        "||": {EXP in [CMTextAlignmentAttributeName: NSTextAlignment.Center.rawValue]},
        "|-": {EXP in [CMTextAlignmentAttributeName: NSTextAlignment.Left.rawValue]},
        "center": {EXP in [CMTextAlignmentAttributeName: NSTextAlignment.Center.rawValue]},
        "right": {EXP in [CMTextAlignmentAttributeName: NSTextAlignment.Left.rawValue]},
        "left":  {EXP in [CMTextAlignmentAttributeName: NSTextAlignment.Right.rawValue]},
        
        // 缩紧
        "firstlineindent": {EXP in [CMTextFirstLineHeadIndentAttributeName: FloatValue(EXP.1)]},
        "flindent": {EXP in [CMTextFirstLineHeadIndentAttributeName: FloatValue(EXP.1)]},
        
        "headindent": {EXP in [CMTextHeadIndentAttributeName: FloatValue(EXP.1)]},
        "hindent": {EXP in [CMTextHeadIndentAttributeName: FloatValue(EXP.1)]},
        
        "trailindent": {EXP in [CMTextTailIndentAttributeName: FloatValue(EXP.1)]},
        "tindent": {EXP in [CMTextTailIndentAttributeName: FloatValue(EXP.1)]},
        
        "linespace": {EXP in [CMTextLineSpaceAttributeName: FloatValue(EXP.1)]},
    ]
}