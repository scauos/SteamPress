import Vapor
import HTTP
import Routing
import LeafMarkdown

struct BlogController {
    
    // MARK: - Properties
    fileprivate let blogPostsPath = "posts"
    fileprivate let labelsPath = "labels"
    fileprivate let authorsPath = "authors"
    fileprivate let drop: Droplet
    fileprivate let pathCreator: BlogPathCreator
    fileprivate let viewFactory: ViewFactory
    
    // MARK: - Initialiser
    init(drop: Droplet, pathCreator: BlogPathCreator, viewFactory: ViewFactory) {
        self.drop = drop
        self.pathCreator = pathCreator
        self.viewFactory = viewFactory
    }
    
    // MARK: - Add routes
    func addRoutes() {
        drop.group(pathCreator.blogPath ?? "") { index in
            index.get(handler: indexHandler)
            index.get(blogPostsPath, BlogPost.self, handler: blogPostHandler)
            index.get(labelsPath, BlogLabel.self, handler: labelViewHandler)
            index.get(authorsPath, BlogUser.self, handler: authorViewHandler)
        }
    }
    
    // MARK: - Route Handlers
    
    func indexHandler(request: Request) throws -> ResponseRepresentable {
        var blogPosts = try BlogPost.all()
        let labels = try BlogLabel.all()
        var parameters: [String: Node] = [:]

        blogPosts.sort { $0.created > $1.created }

        if blogPosts.count > 0 {
            var postsNode = [Node]()
            for post in blogPosts {
                postsNode.append(try post.makeNodeWithExtras())
            }
            parameters["posts"] = try postsNode.makeNode()
        }
        
        if labels.count > 0 {
            parameters["labels"] = try labels.makeNode()
        }
        
        do {
            if let user = try request.auth.user() as? BlogUser {
                parameters["user"] = try user.makeNodeWithoutPassword()
            }
        }
        catch {}
        
        parameters["blogIndexPage"] = true
        
        return try drop.view.make("blog/blog", parameters)
    }
    
    func blogPostHandler(request: Request, blogPost: BlogPost) throws -> ResponseRepresentable {
        guard let author = try blogPost.getAuthor() else {
            throw Abort.badRequest
        }
                
        var parameters = try Node(node: [
                "post": blogPost.makeNodeWithExtras(),
                "author": author.makeNodeWithoutPassword(),
                "blogPostPage": true.makeNode()
            ])
        
        do {
            if let user = try request.auth.user() as? BlogUser {
                parameters["user"] = try user.makeNodeWithoutPassword()
            }
        }
        catch {}
        
        return try drop.view.make("blog/blogpost", parameters)
    }
    
    func labelViewHandler(request: Request, label: BlogLabel) throws -> ResponseRepresentable {
        let posts = try label.blogPosts()
        
        var parameters: [String: Node] = [
            "label": try label.makeNode(),
            "posts": try posts.makeNode(),
            "labelPage": true.makeNode()
        ]
        
        do {
            if let user = try request.auth.user() as? BlogUser {
                parameters["user"] = try user.makeNodeWithoutPassword()
            }
        }
        catch {}
        
        return try drop.view.make("blog/label", parameters)
    }
    
    func authorViewHandler(request: Request, author: BlogUser) throws -> ResponseRepresentable {
        return try viewFactory.createProfileView(user: author, isMyProfile: false)
    }
    
}