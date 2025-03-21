import SwiftSyntax

private let legacyObjcTypes = [
    "NSAffineTransform",
    "NSArray",
    "NSCalendar",
    "NSCharacterSet",
    "NSData",
    "NSDateComponents",
    "NSDateInterval",
    "NSDate",
    "NSDecimalNumber",
    "NSDictionary",
    "NSIndexPath",
    "NSIndexSet",
    "NSLocale",
    "NSMeasurement",
    "NSNotification",
    "NSNumber",
    "NSPersonNameComponents",
    "NSSet",
    "NSString",
    "NSTimeZone",
    "NSURL",
    "NSURLComponents",
    "NSURLQueryItem",
    "NSURLRequest",
    "NSUUID",
]

@SwiftSyntaxRule(optIn: true)
struct LegacyObjcTypeRule: Rule {
    var configuration = LegacyObjcTypeConfiguration()

    static let description = RuleDescription(
        identifier: "legacy_objc_type",
        name: "Legacy Objective-C Reference Type",
        description: "Prefer Swift value types to bridged Objective-C reference types",
        kind: .idiomatic,
        nonTriggeringExamples: [
            Example("var array = Array<Int>()"),
            Example("var calendar: Calendar? = nil"),
            Example("var formatter: NSDataDetector"),
            Example("var className: String = NSStringFromClass(MyClass.self)"),
            Example("_ = URLRequest.CachePolicy.reloadIgnoringLocalCacheData"),
            Example(#"_ = Notification.Name("com.apple.Music.playerInfo")"#),
            Example(#"""
            class SLURLRequest: NSURLRequest {
                let data = NSData()
                let number: NSNumber
            }
            """#, configuration: ["allowed_types": ["NSData", "NSNumber", "NSURLRequest"]]),
        ],
        triggeringExamples: [
            Example("var array = ↓NSArray()"),
            Example("var calendar: ↓NSCalendar? = nil"),
            Example("_ = ↓NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData"),
            Example(#"_ = ↓NSNotification.Name("com.apple.Music.playerInfo")"#),
            Example(#"""
            let keyValuePair: (Int) -> (↓NSString, ↓NSString) = {
              let n = "\($0)" as ↓NSString; return (n, n)
            }
            dictionary = [↓NSString: ↓NSString](uniqueKeysWithValues:
              (1...10_000).lazy.map(keyValuePair))
            """#),
            Example("""
            extension Foundation.Notification.Name {
                static var reachabilityChanged: Foundation.↓NSNotification.Name {
                    return Foundation.Notification.Name("org.wordpress.reachability.changed")
                }
            }
            """),
        ]
    )
}

private extension LegacyObjcTypeRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: IdentifierTypeSyntax) {
            if let name = node.typeName, isViolatingType(name) {
                violations.append(node.positionAfterSkippingLeadingTrivia)
            }
        }

        override func visitPost(_ node: DeclReferenceExprSyntax) {
            if isViolatingType(node.baseName.text) {
                violations.append(node.baseName.positionAfterSkippingLeadingTrivia)
            }
        }

        override func visitPost(_ node: MemberTypeSyntax) {
            if node.baseType.as(IdentifierTypeSyntax.self)?.typeName == "Foundation", isViolatingType(node.name.text) {
                violations.append(node.name.positionAfterSkippingLeadingTrivia)
            }
        }

        private func isViolatingType(_ name: String) -> Bool {
            legacyObjcTypes.contains(name) && !configuration.allowedTypes.contains(name)
        }
    }
}
