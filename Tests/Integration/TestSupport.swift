import Foundation

// Native assertions for Apple CLT, which ships no XCTest/Swift Testing modules.
class XCTestCase {}
var failures: [String] = []
var casesRun = 0
func XCTAssertTrue(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !value() { failures.append("\(file):\(line): expected true") }
}
func XCTAssertFalse(_ value: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(!value(), file: file, line: line)
}
func XCTAssertNil(_ value: Any?, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(value == nil, file: file, line: line)
}
func XCTAssertEqual<T: Equatable>(_ value: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    if value != expected { failures.append("\(file):\(line): \(value) != \(expected)") }
}
@MainActor func runCase(_ name: String, _ body: () -> Void) {
    let filter = CommandLine.arguments.dropFirst().first ?? ""
    guard filter.isEmpty || name.contains(filter) else { return }
    casesRun += 1
    let count = failures.count
    body()
    print("\(failures.count == count ? "PASS" : "FAIL") \(name)")
}
