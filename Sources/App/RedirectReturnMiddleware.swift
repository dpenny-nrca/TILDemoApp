import Vapor
import Authentication

/// Basic middleware to redirect unauthenticated requests to the supplied path
public struct RedirectReturnMiddleware<A>: Middleware where A: Authenticatable {
    
    /// The path to redirect to
    let path: String
    
    /// Initialise the `RedirectMiddleware`
    ///
    /// - parameters:
    ///    - authenticatableType: The type to check authentication against
    ///    - path: The path to redirect to if the request is not authenticated
    public init(A authenticatableType: A.Type = A.self, path: String) {
        self.path = path
    }
    
    /// See Middleware.respond
    public func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        if try request.isAuthenticated(A.self) {
            return try next.respond(to: request)
        }
        let redirect = request.redirect(to: "\(path)?returnPath=\(request.http.url.relativePath)")
        return Future.map(on: request) { redirect }
    }
    
    /// Use this middleware to redirect users away from
    /// protected content to a login page
    public static func login(path: String = "/login") -> RedirectReturnMiddleware {
        return RedirectReturnMiddleware(path: path)
    }
}
