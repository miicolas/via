import Foundation

extension URLSessionConfiguration {
    /// Applies the cookie policy shared by every session that talks to the
    /// Via API. Auth is bearer-only: replaying the Better Auth session cookie
    /// without an Origin header trips its CSRF check
    /// (403 MISSING_OR_NULL_ORIGIN), so API sessions never store or send
    /// cookies. Callers tune cache and timeouts on the returned configuration.
    static func viaAPI(base: URLSessionConfiguration) -> URLSessionConfiguration {
        base.httpShouldSetCookies = false
        base.httpCookieAcceptPolicy = .never
        base.httpCookieStorage = nil
        return base
    }
}
