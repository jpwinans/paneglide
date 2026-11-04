import Foundation
import Testing
import PaneGlideCore

private class PublicReleasesProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    var statusCode: Int { 200 }
    override func startLoading() {
        guard request.url?.absoluteString == "https://api.github.com/repos/jpwinans/paneglide/releases?per_page=100",
              request.value(forHTTPHeaderField: "Authorization") == nil else {
            client?.urlProtocol(self, didFailWithError: URLError(.userAuthenticationRequired))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        let body = Data(#"[{"tag_name":"v0.3.0","draft":false,"prerelease":false,"assets":[{"id":7,"name":"PaneGlide.zip","size":1500}]}]"#.utf8)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Test func publishedUpdatesAreAvailableWithoutAnAccountOrToken() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [PublicReleasesProtocol.self]
    let source = GitHubReleases(configuration: configuration)
    let checker = UpdateChecker(source: source, current: try ReleaseVersion("0.2.0"))
    #expect(try await checker.check() == Release(version: ReleaseVersion("0.3.0"), assetID: 7, byteCount: 1500))
}
