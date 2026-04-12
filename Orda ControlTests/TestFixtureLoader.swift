import Foundation

enum TestFixtureLoader {
    static func contractsFixtureJSON() throws -> Data {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fixtureURL = testsDirectory
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("contracts_fixtures.json")
        return try Data(contentsOf: fixtureURL)
    }
}
