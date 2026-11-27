import Foundation
import Testing
import UIKit
import WebKit

/// More ways to show a document and to ask its page what it shows and what it allows.
extension ShownDocument {
    /// Writes `files` (name → contents) into a new folder of their own, then shows the one called `name`.
    static func show(files: [String: Data], opening name: String, in size: CGSize = phone) async throws
        -> ShownDocument
    {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        for (path, contents) in files {
            let file = folder.appending(path: path)
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: file)
        }
        return try await show(folder.appending(path: name), in: size)
    }

    /// Runs `body` as a JavaScript function in the page and decodes the JSON it returns.
    func json<Value: Decodable>(
        _ type: Value.Type, _ body: String, _ arguments: [String: Any] = [:]
    ) async throws -> Value {
        let script = "return JSON.stringify(await (async () => { \(body) })());"
        let text = try #require(try await evaluate(script, arguments) as? String)
        return try JSONDecoder().decode(Value.self, from: Data(text.utf8))
    }

    /// Whether the page's policy refuses an element `tag` with `attributes` once it is added to
    /// the page: true when adding it reports a Content Security Policy violation within half a
    /// second. The element is removed again afterwards.
    func policyRefuses(_ tag: String, _ attributes: [String: String]) async throws -> Bool {
        let script = """
            return await new Promise(resolve => {
              const element = document.createElement(tag);
              const finish = refused => {
                document.removeEventListener("securitypolicyviolation", onViolation);
                element.remove();
                resolve(refused);
              };
              const onViolation = () => finish(true);
              document.addEventListener("securitypolicyviolation", onViolation);
              for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, value);
              (document.body ?? document.documentElement).append(element);
              setTimeout(() => finish(false), 500);
            });
            """
        return try #require(try await evaluate(script, ["tag": tag, "attributes": attributes]) as? Bool)
    }

    /// Whether the page's policy refuses what `action`, JavaScript run in the page, tries to load:
    /// true when it reports a Content Security Policy violation within half a second.
    func policyRefuses(running action: String) async throws -> Bool {
        let script = """
            return await new Promise(resolve => {
              const finish = refused => {
                document.removeEventListener("securitypolicyviolation", onViolation);
                resolve(refused);
              };
              const onViolation = () => finish(true);
              document.addEventListener("securitypolicyviolation", onViolation);
              try { \(action) } catch {}
              setTimeout(() => finish(false), 500);
            });
            """
        return try #require(try await evaluate(script) as? Bool)
    }

    /// Waits `seconds` in the page, so that what the page might run on its own gets the chance.
    func settle(_ seconds: Double = 0.5) async throws {
        _ = try await evaluate(
            "await new Promise(resolve => setTimeout(resolve, seconds * 1000)); return true", ["seconds": seconds])
    }
}
