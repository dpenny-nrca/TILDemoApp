import Foundation
import Vapor
import Leaf
import Authentication
import Fluent
import Crypto
import Imperial


struct WebsiteController: RouteCollection {
    func boot(router: Router) throws {
        let authSessionRoutes = router.grouped(User.authSessionsMiddleware())
        authSessionRoutes.get(use: indexHandler)
        authSessionRoutes.get("acronyms", Acronym.parameter, use: acronymHandler)
        authSessionRoutes.get("acronyms", "search", use: searchHandler)
        authSessionRoutes.get("users", use: allUsersHandler)
        authSessionRoutes.get("users", User.parameter, use: userHandler)
        authSessionRoutes.get("categories", use: allCategoriesHandler)
        authSessionRoutes.get("categories", Category.parameter, use: categoryHandler)
        authSessionRoutes.get("login", use: loginHandler)
        authSessionRoutes.post("login", use: loginPostHandler)

        let protectedImperialRoutes = router.grouped(ImperialMiddleware())
        protectedImperialRoutes.get("create-acronym", use: createAcronymHandler)
        protectedImperialRoutes.post("create-acronym", use: createAncronymPostHandler)

        let protectedRoutes = authSessionRoutes.grouped(RedirectReturnMiddleware<User>(path: "/login"))
        protectedRoutes.get("create-category", use: createCategoryHandler)
        protectedRoutes.post("create-category", use: createCategoryPostHandler)
        protectedRoutes.get("create-user", use: createUserHandler)
        protectedRoutes.post("create-user", use: createUserPostHandler)
        protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "edit", use: editAncronymPostHandler)
        protectedRoutes.post("acronyms", Acronym.parameter, "delete", use: deleteAncronymPostHandler)
    }
    
    func indexHandler(_ req: Request) throws -> Future<View> {
        return Acronym.query(on: req).all().flatMap(to: View.self) { acronyms in
            let content = IndexContent(title: "Homepage", acronyms: acronyms.isEmpty ? nil : acronyms)
            return try req.leaf().render("index", content)
        }
    }
    
    func acronymHandler(_ req: Request) throws -> Future<View> {
        return try req.parameter(Acronym.self).flatMap(to: View.self) { acronym in
            return try acronym.creator.get(on: req).flatMap(to: View.self) { creator in
                return try acronym.categories.query(on: req).all().flatMap(to: View.self) { categories in
                    let content = AcronymContent(title: acronym.long, acronym: acronym, creator: creator, categories: categories)
                    return try req.leaf().render("acronym", content)
                }
            }
        }
    }
    
    func createAcronymHandler(_ req: Request) throws -> Future<View> {
        let token = try req.accessToken()
        print(token)
        return Category.query(on: req).all().flatMap(to: View.self) { allCategories in
            let content = CreateAcronymContent(title: "New Acronym", allCategories: allCategories)
            return try req.leaf().render("create-acronym", content)
        }
    }
    
    func createCategoryHandler(_ req: Request) throws -> Future<View> {
        let content = CreateContent(title: "New Category")
        return try req.leaf().render("create-category", content)
    }
    
    func createUserHandler(_ req: Request) throws -> Future<View> {
        let content = CreateContent(title: "New User")
        return try req.leaf().render("create-user", content)
    }
    
    func allUsersHandler(_ req: Request) throws -> Future<View> {
        return User.query(on: req).all().flatMap(to: View.self) { users in
            let content = AllUsersContent(title: "Users", users: users.isEmpty ? nil : users)
            return try req.leaf().render("all-users", content)
        }
    }
    
    func userHandler(_ req: Request) throws -> Future<View> {
        return try req.parameter(User.self).flatMap(to: View.self) { user in
            return try user.acronyms.query(on: req).all().flatMap(to: View.self) { acronyms in
                let content = UserContent(title: user.name, user: user, acronyms: acronyms.isEmpty ? nil : acronyms)
                return try req.leaf().render("user", content)
            }
        }
    }
    
    func allCategoriesHandler(_ req: Request) throws -> Future<View> {
        return Category.query(on: req).all().flatMap(to: View.self) { categories in
            let content = AllCategoriesContent(title: "Categories", categories: categories.isEmpty ? nil : categories)
            return try req.leaf().render("all-categories", content)
        }
    }
    
    func categoryHandler(_ req: Request) throws -> Future<View> {
        return try req.parameter(Category.self).flatMap(to: View.self) { category in
            return try category.acronyms.query(on: req).all().flatMap(to: View.self) { acronyms in
                let content = CategoryContent(title: category.name, category: category, acronyms: acronyms.isEmpty ? nil : acronyms)
                return try req.leaf().render("category", content)
            }
        }
    }
    
    func createAncronymPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.content.decode(AcronymPostData.self).flatMap(to: Response.self) { data in
            let user = try req.requireAuthenticated(User.self)
            let acronym = try Acronym(short: data.acronymShort, long: data.acronymLong, creatorID: user.requireID())
            return acronym.save(on: req).map(to: Response.self) { acronym in
                guard let id = acronym.id else {
                    return req.redirect(to: "/")
                }
                if let acronymCategories = data.acronymCategories {
                    for categoryID in acronymCategories {
                        let pivot = AcronymCategoryPivot(id, Int(categoryID)!)
                        _ = pivot.save(on: req)
                    }
                }
                return req.redirect(to: "/acronyms/\(id)")
            }
        }
    }
    
    func createCategoryPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.content.decode(CategoryPostData.self).flatMap(to: Response.self) { data in
            let category = Category(name: data.categoryName)
            return category.save(on: req).map(to: Response.self) { category in
                if category.id == nil {
                    return req.redirect(to: "/")
                }
                else {
                    return req.redirect(to: "/categories")
                }
            }
        }
    }
    
    func createUserPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.content.decode(UserPostData.self).flatMap(to: Response.self) { data in
            let hasher = try req.make(BCryptDigest.self)
            let password = try String.convertFromData(hasher.hash(data.userPassword))
            let user = User(name: data.userName, username: data.userUsername, password: password)
            return user.save(on: req).map(to: Response.self) { user in
                if user.id == nil {
                    return req.redirect(to: "/")
                }
                else {
                    return req.redirect(to: "/users")
                }
            }
        }
    }
    
    func searchHandler(_ req: Request) throws -> Future<View> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(.badRequest, reason: "Missing search term in request.")
        }
        let results = try Acronym.query(on: req).group(.or) { or in
            try or.filter(\.short == searchTerm)
            try or.filter(\.long == searchTerm)
        }.all()
        return results.flatMap(to: View.self) { acronyms in
            let content = SearchContent(title: "Search Results", acronyms: acronyms)
            return try req.leaf().render("search-results", content)
        }
    }
    
    func editAcronymHandler(_ req: Request) throws -> Future<View> {
        return Category.query(on: req).all().flatMap(to: View.self) { allCategories in
            return try req.parameter(Acronym.self).flatMap(to: View.self) { acronym in
                return try acronym.categories.query(on: req).all().flatMap(to: View.self) { acronymCategories in
                    var acronymCategoryIDs: [Int] = []
                    for category in acronymCategories {
                        acronymCategoryIDs.append(category.id!)
                    }
                    let content = EditAcronymContent(title: "Edit Acronym", acronym: acronym, allCategories: allCategories, acronymCategoryIDs: acronymCategoryIDs)
                    return try req.leaf().render("create-acronym", content)
                }
            }
        }
    }
    
    func editAncronymPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameter(Acronym.self).flatMap(to: Response.self) { acronym in
            return try req.content.decode(AcronymPostData.self).flatMap(to: Response.self) { data in
                acronym.short = data.acronymShort
                acronym.long = data.acronymLong
                acronym.creatorID = try req.requireAuthenticated(User.self).requireID()
                
                return acronym.save(on: req).map(to: Response.self) { acronym in
                    guard let id = acronym.id else {
                        return req.redirect(to:"/")
                    }
                    if let acronymCategories = data.acronymCategories {
                        for categoryID in acronymCategories {
                            let pivot = AcronymCategoryPivot(id, Int(categoryID)!)
                            _ = pivot.save(on: req)
                        }
                    }
                    return req.redirect(to: "/acronyms/\(id)")
                }
            }
        }
    }
    
    func deleteAncronymPostHandler(_ req: Request) throws -> Future<Response> {
        return try req.parameter(Acronym.self).flatMap(to: Response.self) { acronym in
            return acronym.delete(on: req).transform(to: req.redirect(to: "/"))
        }
    }
    
    func loginHandler(_ req: Request) throws -> Future<View> {
        let content = LoginContent(title: "Log In")
        return try req.leaf().render("login", content)
    }
    
    func loginPostHandler(_ req: Request) throws -> Future<Response> {
        let returnPath = req.query[String.self, at: "returnPath"]
        return try req.content.decode(LoginPostData.self).flatMap(to: Response.self) { data in
            let verifier = try req.make(BCryptDigest.self)
            return User.authenticate(username: data.username, password: data.password, using: verifier, on: req).map(to: Response.self) { user in
                guard let user = user else {
                    return req.redirect(to: "/login")
                }
                try req.authenticateSession(user)

                //
                // Commented out for compatibility with the nil coalescing
                // operator defined in Optional+Imperial.swift.
                //
                //return req.redirect(to: returnPath ?? "/")

                if let returnPath = returnPath {
                    return req.redirect(to: returnPath)
                } else {
                    return req.redirect(to: "/")
                }
            }
        }
    }
}

extension Request {
    func leaf() throws -> LeafRenderer {
        return try self.make(LeafRenderer.self)
    }
}

struct IndexContent: Encodable {
    let title: String
    let acronyms: [Acronym]?
}

struct AcronymContent: Encodable {
    let title: String
    let acronym: Acronym
    let creator: User
    let categories: [Category]?
}

struct AllUsersContent: Encodable {
    let title: String
    let users: [User]?
}

struct UserContent: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]?
}

struct AllCategoriesContent: Encodable {
    let title: String
    let categories: [Category]?
}

struct CategoryContent: Encodable {
    let title: String
    let category: Category
    let acronyms: [Acronym]?
}

struct CreateAcronymContent: Encodable {
    let title: String
    let allCategories: [Category]?
}

struct AcronymPostData: Content {
    static var defaultMediaType = MediaType.urlEncodedForm
    let acronymShort: String
    let acronymLong: String
    let acronymCategories: [String]?
}

struct CategoryPostData: Content {
    static var defaultMediaType = MediaType.urlEncodedForm
    let categoryName: String
}

struct UserPostData: Content {
    static var defaultMediaType = MediaType.urlEncodedForm
    let userName: String
    let userUsername: String
    let userPassword: String
}

struct EditAcronymContent: Encodable {
    let title: String
    let acronym: Acronym
    let allCategories: [Category]?
    let acronymCategoryIDs: [Int]?
    let editing = true
}

struct LoginContent: Encodable {
    let title: String
}

struct LoginPostData: Content {
    let username: String
    let password: String
    let returnPath: String?
}

struct CreateContent: Encodable {
    let title: String
}

struct SearchContent: Encodable {
    let title: String
    let acronyms: [Acronym]?
}
