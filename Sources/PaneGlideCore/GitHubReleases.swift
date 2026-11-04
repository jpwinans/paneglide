import Foundation

private final class NoReleaseRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public final class GitHubReleases: ReleaseSource {
    private let session: URLSession
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration, delegate: NoReleaseRedirects(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }

    public func releases() async throws -> Data {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/jpwinans/paneglide/releases?per_page=100")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("PaneGlide", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SettingsError.invalid("GitHub release check failed (HTTP \(code)). The service may be unavailable or its request limit reached; retry later.")
        }
        return data
    }
}
