// swiftlint:disable file_length
import Foundation
import SourceKittenFramework
@testable import SwiftLintBuiltInRules
@testable import SwiftLintFramework
import XCTest

private extension Command {
    init?(string: String) {
        let nsString = string.bridge()
        guard nsString.length > 7 else { return nil }
        let subString = nsString.substring(with: NSRange(location: 3, length: nsString.length - 4))
        self.init(commandString: subString, line: 1, range: 4..<nsString.length)
    }
}

// swiftlint:disable:next type_body_length
final class CommandTests: SwiftLintTestCase {
    // MARK: Command Creation

    func testNoCommandsInEmptyFile() {
        let file = SwiftLintFile(contents: "")
        XCTAssertEqual(file.commands(), [])
    }

    func testEmptyString() {
        XCTAssertNil(Command(string: ""))
    }

    func testDisable() {
        let input = "// swiftlint:disable rule_id\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<29)
        XCTAssertEqual(file.commands(), [expected])
        XCTAssertEqual(Command(string: input), expected)
    }

    func testDisablePrevious() {
        let input = "// swiftlint:disable:previous rule_id\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<38,
                               modifier: .previous)
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    func testDisableThis() {
        let input = "// swiftlint:disable:this rule_id\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<34,
                               modifier: .this)
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    func testDisableNext() {
        let input = "// swiftlint:disable:next rule_id\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<34,
                               modifier: .next)
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    func testEnable() {
        let input = "// swiftlint:enable rule_id\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<28)
        XCTAssertEqual(file.commands(), [expected])
        XCTAssertEqual(Command(string: input), expected)
    }

    func testEnablePrevious() {
        let input = "// swiftlint:enable:previous rule_id\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<37,
                               modifier: .previous)
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    func testEnableThis() {
        let input = "// swiftlint:enable:this rule_id\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<33, modifier: .this)
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    func testEnableNext() {
        let input = "// swiftlint:enable:next rule_id\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<33, modifier: .next)
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    func testTrailingComment() {
        let input = "// swiftlint:enable:next rule_id - Comment\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<43,
                               modifier: .next,
                               trailingComment: "Comment")
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    func testTrailingCommentWithUrl() {
        let input = "// swiftlint:enable:next rule_id - Comment with URL https://github.com/realm/SwiftLint\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<87,
                               modifier: .next,
                               trailingComment: "Comment with URL https://github.com/realm/SwiftLint")
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    func testTrailingCommentUrlOnly() {
        let input = "// swiftlint:enable:next rule_id - https://github.com/realm/SwiftLint\n"
        let file = SwiftLintFile(contents: input)
        let expected = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<70,
                               modifier: .next,
                               trailingComment: "https://github.com/realm/SwiftLint")
        XCTAssertEqual(file.commands(), expected.expand())
        XCTAssertEqual(Command(string: input), expected)
    }

    // MARK: Action

    func testActionInverse() {
        XCTAssertEqual(Command.Action.enable.inverse(), .disable)
        XCTAssertEqual(Command.Action.disable.inverse(), .enable)
    }

    // MARK: Command Expansion

    private let completeLine = 0..<Int.max

    func testNoModifierCommandExpandsToItself() {
        do {
            let command = Command(action: .disable, ruleIdentifiers: ["rule_id"])
            XCTAssertEqual(command.expand(), [command])
        }
        do {
            let command = Command(action: .enable, ruleIdentifiers: ["rule_id"])
            XCTAssertEqual(command.expand(), [command])
        }
        do {
            let command = Command(action: .disable, ruleIdentifiers: ["1", "2"])
            XCTAssertEqual(command.expand(), [command])
        }
    }

    func testExpandPreviousCommand() {
        do {
            let command = Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<48,
                                  modifier: .previous)
            let expanded = [
                Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 0),
                Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 0, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
        do {
            let command = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<48,
                                  modifier: .previous)
            let expanded = [
                Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 0),
                Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 0, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
        do {
            let command = Command(action: .enable, ruleIdentifiers: ["1", "2"], line: 1, range: 4..<48,
                                  modifier: .previous)
            let expanded = [
                Command(action: .enable, ruleIdentifiers: ["1", "2"], line: 0),
                Command(action: .disable, ruleIdentifiers: ["1", "2"], line: 0, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
    }

    func testExpandThisCommand() {
        do {
            let command = Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<48,
                                  modifier: .this)
            let expanded = [
                Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1),
                Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
        do {
            let command = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<48,
                                  modifier: .this)
            let expanded = [
                Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1),
                Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
        do {
            let command = Command(action: .enable, ruleIdentifiers: ["1", "2"], line: 1, range: 4..<48,
                                  modifier: .this)
            let expanded = [
                Command(action: .enable, ruleIdentifiers: ["1", "2"], line: 1),
                Command(action: .disable, ruleIdentifiers: ["1", "2"], line: 1, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
    }

    func testExpandNextCommand() {
        do {
            let command = Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<48,
                                  modifier: .next)
            let expanded = [
                Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 2),
                Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 2, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
        do {
            let command = Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 1, range: 4..<48,
                                  modifier: .next)
            let expanded = [
                Command(action: .enable, ruleIdentifiers: ["rule_id"], line: 2),
                Command(action: .disable, ruleIdentifiers: ["rule_id"], line: 2, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
        do {
            let command = Command(action: .enable, ruleIdentifiers: ["1", "2"], line: 1,
                                  modifier: .next)
            let expanded = [
                Command(action: .enable, ruleIdentifiers: ["1", "2"], line: 2),
                Command(action: .disable, ruleIdentifiers: ["1", "2"], line: 2, range: completeLine),
            ]
            XCTAssertEqual(command.expand(), expanded)
        }
    }

    // MARK: Superfluous Disable Command Detection

    func testSuperfluousDisableCommands() {
        XCTAssertEqual(
            violations(Example("// swiftlint:disable nesting\nprint(123)\n")).map(\.ruleIdentifier),
            ["blanket_disable_command", "superfluous_disable_command"]
        )
        XCTAssertEqual(
            violations(Example("// swiftlint:disable:next nesting\nprint(123)\n"))[0].ruleIdentifier,
            "superfluous_disable_command"
        )
        XCTAssertEqual(
            violations(Example("print(123) // swiftlint:disable:this nesting\n"))[0].ruleIdentifier,
            "superfluous_disable_command"
        )
        XCTAssertEqual(
            violations(Example("print(123)\n// swiftlint:disable:previous nesting\n"))[0].ruleIdentifier,
            "superfluous_disable_command"
        )
    }

    func testDisableAllOverridesSuperfluousDisableCommand() {
        XCTAssert(
            violations(
                Example("""
                        // swiftlint:disable all
                        // swiftlint:disable nesting
                        print(123)
                        // swiftlint:enable nesting
                        // swiftlint:enable all
                        """)
            ).isEmpty
        )
        XCTAssert(
            violations(
                Example("""
                        // swiftlint:disable all
                        // swiftlint:disable:next nesting
                        print(123)
                        // swiftlint:enable all
                        """)
            ).isEmpty
        )
        XCTAssert(
            violations(
                Example("""
                        // swiftlint:disable all
                        // swiftlint:disable:this nesting
                        print(123)
                        // swiftlint:enable all
                        """)
            ).isEmpty
        )
        XCTAssert(
            violations(
                Example("// swiftlint:disable all\n// swiftlint:disable:previous nesting\nprint(123)\n")
            ).isEmpty
        )
    }

    func testSuperfluousDisableCommandsIgnoreDelimiter() {
        let longComment = "Comment with a large number of words that shouldn't register as superfluous"
        XCTAssertEqual(
            violations(Example("// swiftlint:disable nesting - \(longComment)\nprint(123)\n")).map(\.ruleIdentifier),
            ["blanket_disable_command", "superfluous_disable_command"]
        )
        XCTAssertEqual(
            violations(Example("// swiftlint:disable:next nesting - Comment\nprint(123)\n"))[0]
                .ruleIdentifier,
            "superfluous_disable_command"
        )
        XCTAssertEqual(
            violations(Example("print(123) // swiftlint:disable:this nesting - Comment\n"))[0]
                .ruleIdentifier,
            "superfluous_disable_command"
        )
        XCTAssertEqual(
            violations(Example("print(123)\n// swiftlint:disable:previous nesting - Comment\n"))[0]
                .ruleIdentifier,
            "superfluous_disable_command"
        )
    }

    func testInvalidDisableCommands() {
        XCTAssertEqual(
            violations(Example("// swiftlint:disable nesting_foo\n" +
                               "print(123)\n" +
                               "// swiftlint:enable nesting_foo\n"))[0].ruleIdentifier,
            "superfluous_disable_command"
        )
        XCTAssertEqual(
            violations(Example("// swiftlint:disable:next nesting_foo\nprint(123)\n"))[0]
                .ruleIdentifier,
            "superfluous_disable_command"
        )
        XCTAssertEqual(
            violations(Example("print(123) // swiftlint:disable:this nesting_foo\n"))[0]
                .ruleIdentifier,
            "superfluous_disable_command"
        )
        XCTAssertEqual(
            violations(Example("print(123)\n// swiftlint:disable:previous nesting_foo\n"))[0]
                .ruleIdentifier,
            "superfluous_disable_command"
        )

        XCTAssertEqual(
            violations(Example("print(123)\n// swiftlint:disable:previous nesting_foo \n")).count,
            1
        )

        let example = Example("// swiftlint:disable nesting this is a comment\n// swiftlint:enable nesting\n")
        let multipleViolations = violations(example)
        XCTAssertEqual(multipleViolations.filter({ $0.ruleIdentifier == "superfluous_disable_command" }).count, 9)
        XCTAssertEqual(multipleViolations.filter({ $0.ruleIdentifier == "blanket_disable_command" }).count, 4)

        let onlyNonExistentRulesViolations = violations(Example("// swiftlint:disable this is a comment\n"))
        XCTAssertEqual(
            onlyNonExistentRulesViolations.filter({ $0.ruleIdentifier == "superfluous_disable_command" }).count, 4
        )
        XCTAssertEqual(onlyNonExistentRulesViolations.filter({
            $0.ruleIdentifier == "blanket_disable_command"
        }).count, 4)

        XCTAssertEqual(
            violations(Example("print(123)\n// swiftlint:disable:previous nesting_foo\n"))[0].reason,
            "'nesting_foo' is not a valid SwiftLint rule; remove it from the disable command"
        )
    }

    func testSuperfluousDisableCommandsDisabled() {
        XCTAssertEqual(
            violations(Example("// swiftlint:disable superfluous_disable_command nesting\n" +
                               "print(123)\n" +
                               "// swiftlint:enable superfluous_disable_command nesting\n")),
            []
        )
        XCTAssertEqual(
            violations(Example("// swiftlint:disable superfluous_disable_command\n" +
                               "// swiftlint:disable nesting\n" +
                               "print(123)\n" +
                               "// swiftlint:enable superfluous_disable_command nesting\n")),
            []
        )
        XCTAssertEqual(
            violations(Example("// swiftlint:disable:next superfluous_disable_command nesting\nprint(123)\n")),
            []
        )
        XCTAssertEqual(
            violations(Example("print(123) // swiftlint:disable:this superfluous_disable_command nesting\n")),
            []
        )
        XCTAssertEqual(
            violations(Example("print(123)\n// swiftlint:disable:previous superfluous_disable_command nesting\n")),
            []
        )
    }

    func testSuperfluousDisableCommandsDisabledOnConfiguration() {
        let rulesMode = Configuration.RulesMode.defaultConfiguration(
            disabled: ["superfluous_disable_command"], optIn: []
        )
        let configuration = Configuration(rulesMode: rulesMode)

        XCTAssertEqual(
            violations(Example("// swiftlint:disable nesting\n" +
                               "print(123)\n" +
                               "// swiftlint:enable nesting\n"), config: configuration),
            []
        )
        XCTAssertEqual(
            violations(Example("// swiftlint:disable:next nesting\nprint(123)\n"), config: configuration),
            []
        )
        XCTAssertEqual(
            violations(Example("print(123) // swiftlint:disable:this nesting\n"), config: configuration),
            []
        )
        XCTAssertEqual(
            violations(Example("print(123)\n// swiftlint:disable:previous nesting\n"), config: configuration),
            []
        )
    }

    func testSuperfluousDisableCommandsDisabledWhenAllRulesDisabled() {
        XCTAssertEqual(
            violations(Example("""
                               // swiftlint:disable all
                               // swiftlint:disable non_existent_rule_name
                               // swiftlint:enable non_existent_rule_name
                               // swiftlint:enable all
                               """
            )),
            []
        )
        XCTAssertEqual(
            violations(Example("""
                               // swiftlint:disable superfluous_disable_command
                               // swiftlint:disable non_existent_rule_name
                               // swiftlint:enable non_existent_rule_name
                               // swiftlint:enable superfluous_disable_command

                               """
            )),
            []
        )
    }

    func testSuperfluousDisableCommandsInMultilineComments() {
        XCTAssertEqual(
            violations(Example("""
                               /*
                               // swiftlint:disable identifier_name
                               let a = 0
                               */

                               """
            )),
            []
        )
    }

    func testSuperfluousDisableCommandsEnabledForAnalyzer() {
        let configuration = Configuration(
            rulesMode: .defaultConfiguration(disabled: [], optIn: [UnusedDeclarationRule.identifier])
        )
        let violations = violations(
            Example("""
            public class Foo {
                // swiftlint:disable:next unused_declaration
                func foo() -> Int {
                    1
                }
                // swiftlint:disable:next unused_declaration
                func bar() {
                   foo()
                }
            }
            """),
            config: configuration,
            requiresFileOnDisk: true
        )
        XCTAssertEqual(violations.count, 1)
        XCTAssertEqual(violations.first?.ruleIdentifier, "superfluous_disable_command")
        XCTAssertEqual(violations.first?.location.line, 3)
    }
}
