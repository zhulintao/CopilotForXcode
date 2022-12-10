import AppKit
import CopilotService
import Foundation
import LanguageServerProtocol
import XPCShared

@globalActor enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

@ServiceActor
var workspaces = [URL: Workspace]()

public class XPCService: NSObject, XPCServiceProtocol {
    @ServiceActor
    lazy var authService: CopilotAuthServiceType = Environment.createAuthService()

    override public init() {
        super.init()
        let identifier = ObjectIdentifier(self)
        Task {
            await AutoTrigger.shared.start(by: identifier)
        }
        Task { @ServiceActor in
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 8 * 60 * 60 * 1_000_000_000)
                for (url, workspace) in workspaces {
                    if workspace.isExpired {
                        workspaces[url] = nil
                    } else {
                        workspace.cleanUp()
                    }
                }
            }
        }
    }

    deinit {
        let identifier = ObjectIdentifier(self)
        Task {
            await AutoTrigger.shared.stop(by: identifier)
        }
    }

    public func checkStatus(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let status = try await authService.checkStatus()
                reply(status.rawValue, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
    }

    public func signInInitiate(withReply reply: @escaping (String?, String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let (verificationLink, userCode) = try await authService.signInInitiate()
                reply(verificationLink, userCode, nil)
            } catch {
                reply(nil, nil, NSError.from(error))
            }
        }
    }

    public func signInConfirm(userCode: String, withReply reply: @escaping (String?, String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let (username, status) = try await authService.signInConfirm(userCode: userCode)
                reply(username, status.rawValue, nil)
            } catch {
                reply(nil, nil, NSError.from(error))
            }
        }
    }

    public func getVersion(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let version = try await authService.version()
                reply(version, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
    }

    public func signOut(withReply reply: @escaping (String?, Error?) -> Void) {
        Task { @ServiceActor in
            do {
                let status = try await authService.signOut()
                reply(status.rawValue, nil)
            } catch {
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                let updatedContent = try await workspace.getSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition,
                    tabSize: editor.tabSize,
                    indentSize: editor.indentSize,
                    usesTabsForIndentation: editor.usesTabsForIndentation
                )
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                print(error)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getNextSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                let updatedContent = workspace.getNextSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                )
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                print(error)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getPreviousSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                let updatedContent = workspace.getPreviousSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                )
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                print(error)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getSuggestionRejectedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                let updatedContent = workspace.getSuggestionRejectedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                )
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                print(error)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getSuggestionAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                let updatedContent = workspace.getSuggestionAcceptedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                )
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                print(error)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func getRealtimeSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        Task { @ServiceActor in
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let fileURL = try await Environment.fetchCurrentFileURL()
                let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)

                let canAutoTrigger = workspace.canAutoTriggerGetSuggestions(
                    forFileAt: fileURL,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition
                )
                guard canAutoTrigger else {
                    reply(nil, nil)
                    return
                }

                let updatedContent = try await workspace.getSuggestedCode(
                    forFileAt: fileURL,
                    content: editor.content,
                    lines: editor.lines,
                    cursorPosition: editor.cursorPosition,
                    tabSize: editor.tabSize,
                    indentSize: editor.indentSize,
                    usesTabsForIndentation: editor.usesTabsForIndentation
                )
                reply(try JSONEncoder().encode(updatedContent), nil)
            } catch {
                print(error)
                reply(nil, NSError.from(error))
            }
        }
    }

    public func setAutoSuggestion(enabled: Bool, withReply reply: @escaping (Error?) -> Void) {
        Task { @ServiceActor in
            let fileURL = try await Environment.fetchCurrentFileURL()
            let workspace = try await fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
            workspace.isRealtimeSuggestionEnabled = enabled
            reply(nil)
        }
    }
}

extension XPCService {
    @ServiceActor
    func fetchOrCreateWorkspaceIfNeeded(fileURL: URL) async throws -> Workspace {
        let projectURL = try await Environment.fetchCurrentProjectRootURL(fileURL)
        let workspaceURL = projectURL ?? fileURL
        let workspace = workspaces[workspaceURL] ?? Workspace(projectRootURL: workspaceURL)
        workspaces[workspaceURL] = workspace
        return workspace
    }
}

extension NSError {
    static func from(_ error: Error) -> NSError {
        if let error = error as? ServerError {
            var message = "Unknown"
            switch error {
            case let .handlerUnavailable(handler):
                message = "Handler unavailable: \(handler)."
            case let .unhandledMethod(method):
                message = "Methond unhandled: \(method)."
            case let .notificationDispatchFailed(error):
                message = "Notification dispatch failed: \(error.localizedDescription)."
            case let .requestDispatchFailed(error):
                message = "Request dispatch failed: \(error.localizedDescription)."
            case let .clientDataUnavailable(error):
                message = "Client data unavalable: \(error.localizedDescription)."
            case .serverUnavailable:
                message = "Server unavailable, please make sure you have installed Node."
            case .missingExpectedParameter:
                message = "Missing expected parameter."
            case .missingExpectedResult:
                message = "Missing expected result."
            case let .unableToDecodeRequest(error):
                message = "Unable to decode request: \(error.localizedDescription)."
            case let .unableToSendRequest(error):
                message = "Unable to send request: \(error.localizedDescription)."
            case let .unableToSendNotification(error):
                message = "Unable to send notification: \(error.localizedDescription)."
            case let .serverError(code, m, _):
                message = "Server error: (\(code)) \(m)."
            case let .invalidRequest(error):
                message = "Invalid request: \(error?.localizedDescription ?? "Unknown")."
            case .timeout:
                message = "Timeout."
            }
            return NSError(domain: "com.intii.CopilotForXcode", code: -1, userInfo: [
                NSLocalizedDescriptionKey: message,
            ])
        }
        return NSError(domain: "com.intii.CopilotForXcode", code: -1, userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription,
        ])
    }
}
