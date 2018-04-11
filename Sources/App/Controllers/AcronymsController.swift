import Fluent
import Vapor

struct AcronymsController: RouteCollection {
    func boot(router: Router) throws {
        let acronymsRoute = router.grouped("api", "acronyms")
        acronymsRoute.get(use: getAllHandler)
        acronymsRoute.get(Acronym.parameter, use: getHandler)
        acronymsRoute.get(Acronym.parameter, "creator", use: getCreatorHandler)
        acronymsRoute.get(Acronym.parameter, "categories", use: getCategoriesHandler)
        acronymsRoute.get("search", use: searchHandler)
        acronymsRoute.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
        
        /*
         - What about assigning categories being protected as well?
         */
        
        let tokenAuthMiddleware = User.tokenAuthMiddleware()
        let tokenAuthGroup = acronymsRoute.grouped(tokenAuthMiddleware)
        tokenAuthGroup.post(use: createHandler)
        tokenAuthGroup.delete(Acronym.parameter, use: deleteHandler)
        tokenAuthGroup.put(Acronym.parameter, use: updateHandler)
        
    }
    
    func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).all()
    }
    
    func getHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameter(Acronym.self)
    }
    
    func getCreatorHandler(_ req: Request) throws -> Future<User> {
        return try req.parameter(Acronym.self).flatMap(to: User.self) { acronym in
            return try acronym.creator.get(on: req)
        }
    }
    
    func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
        return try req.parameter(Acronym.self).flatMap(to: [Category].self) { acronym in
            return try acronym.categories.query(on: req).all()
        }
    }
    
    func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest, reason: "Missing search term in request.")
        }
        return try Acronym.query(on: req).group(.or) { or in
            try or.filter(\.short == searchTerm)
            try or.filter(\.long == searchTerm)
        }.all()
    }
    
    func createHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.content.decode(AcronymCreateData.self).flatMap(to: Acronym.self) { acronymData in
            let user = try req.requireAuthenticated(User.self)
            let acronym = try Acronym(short: acronymData.short, long: acronymData.long, creatorID: user.requireID())
            return acronym.save(on: req)
        }
    }
    
    func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameter(Acronym.self).flatMap(to: HTTPStatus.self) { acronym in
            return try req.parameter(Category.self).flatMap(to: HTTPStatus.self) { category in
                let pivot = try AcronymCategoryPivot(acronym.requireID(), category.requireID())
                return pivot.save(on: req).transform(to: .ok)
            }
        }
    }
    
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameter(Acronym.self).flatMap(to: HTTPStatus.self) { acronym in
            return acronym.delete(on: req).transform(to: .noContent)
        }
    }
    
    func updateHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameter(Acronym.self).flatMap(to: Acronym.self) { acronym in
            return try req.content.decode(AcronymCreateData.self).flatMap(to: Acronym.self) { acronymData in
                acronym.short = acronymData.short
                acronym.long = acronymData.long
                acronym.creatorID = try req.requireAuthenticated(User.self).requireID()
                return acronym.save(on: req)
            }
        }
    }
}

extension Acronym: Parameter {}

struct AcronymCreateData: Content {
    let short: String
    let long: String
}
