//
//  PostModel.swift
//  ARchitect
//
//  Created by Amiire kolawole on 2025-03-03.
//

import Foundation

class Post: ObservableObject, Identifiable {
    let id = UUID()
    let username: String
    let userImage: String
    let title: String
    let imageName: String
    let description: String
    let timeAgo: Date = Date()
    @Published var likes: Int
    @Published var user_liked: Bool
    @Published var commentsModel: CommentViewModel
    
    init(username: String, userImage: String, title: String, imageName: String, description: String, likes: Int, user_liked: Bool = false, commentsModel: CommentViewModel = CommentViewModel()) {
        self.username = username
        self.userImage = userImage
        self.title = title
        self.imageName = imageName
        self.description = description
        self.likes = likes
        self.user_liked = user_liked
        self.commentsModel = commentsModel
    }
    
    init(username: String, imageName: String, description: String) {
        self.username = username
        self.userImage = "person.circle.fill" // SF Symbol for user avatar
        self.title = "1990 Vintage"
        self.imageName = imageName // Replace with actual asset name
        self.description = description
        self.likes = 120
        self.user_liked = false
        self.commentsModel = CommentViewModel()
    }
    
    init(imageName: String) {
        self.username = "username"
        self.userImage = "person.circle.fill" // SF Symbol for user avatar
        self.title = "1990 Vintage"
        self.imageName = imageName // Replace with actual asset name
        self.description = "Lengthy description about the furniture and the positioning of different elements that were used. It is a good example of what we can do."
        self.likes = 80
        self.user_liked = false
        self.commentsModel = CommentViewModel()
    }
    
    init() {
        self.username = "username"
        self.userImage = "person.circle.fill" // SF Symbol for user avatar
        self.title = "1990 Vintage"
        self.imageName = "ar_room1" // Replace with actual asset name
        self.description = "Bold interior design project that revives the vibrant energy of the early '80s. It marries vivid color schemes, geometric patterns, and nostalgic accents with contemporary comforts."
        self.likes = 600
        self.user_liked = false
        self.commentsModel = CommentViewModel()
    }
   
//    var environment: VREnvironmentConfig
//
//        init(
//            username: String,
//            userImage: String,
//            title: String,
//            imageName: String,
//            tags: [String],
//            description: String,
//            timeAgo: String,
//            likes: Int
//        ) {
//            self.username = username
//            self.userImage = userImage
//            self.title = title
//            self.imageName = imageName
//            self.tags = tags
//            self.description = description
//            self.timeAgo = timeAgo
//            self.likes = likes
//            
//            self.environment = VREnvironmentConfig(postID: self.id)
//        }
    
    func toggleLike() {
        if user_liked {
            likes = max(likes - 1, 0)
        } else {
            likes += 1
        }
        user_liked.toggle()
    }
    
    func addComment(text: String, publisher: String) {
        commentsModel.addComment(text: text, publisher: publisher)
    }
    
    func time_ago() -> String {
        let time_diff = Date().timeIntervalSince(timeAgo)
        
        if time_diff < 5 {
            return "Just now"
        } else if time_diff < 60 {
            return "\(Int(time_diff)) seconds ago"
        } else if time_diff < 3600 {
            return "\(Int(time_diff/60)) minutes ago"
        } else if time_diff < 86400 {
            return "\(Int(time_diff/60/60)) hours ago"
        } else {
            return "\(Int(time_diff/60/60/24)) days ago"
        }
    }
    
    func numberOfComments() -> Int {
        commentsModel.length()
    }
    
    
}
