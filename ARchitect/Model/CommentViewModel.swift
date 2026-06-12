//
//  CommentViewModel.swift
//  ARchitect
//
//  Created by Dhairya Patel on 2/20/25.
//

import SwiftUI

class CommentViewModel: ObservableObject {
    @Published var comments: [Comment] = [
        Comment(text: "This is a test comment!", timestamp: Date(), publisher: "TestUser")
    ]
    
    struct Comment: Identifiable {
        let id = UUID()
        let username: String = "username"
        let userImage: String = "person.circle.fill"
        let text: String
        let timestamp: Date
        let publisher: String
//        var likes: Int
//        var isLiked: Bool = false
    }
    
    func addComment(text: String, publisher: String) {
        let newComment = Comment(text: text, timestamp: Date(), publisher: publisher)
        comments.append(newComment)
    }
    
//    func toggleLike(for comment: Comment) {
//        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
//            if comments[index].isLiked {
//                // Remove like
//                comments[index].likes = max(comments[index].likes - 1, 0)
//                comments[index].isLiked = false
//            } else {
//                // Add like
//                comments[index].likes += 1
//                comments[index].isLiked = true
//            }
//        }
//    }
    
    func length() -> Int {
        return comments.count
    }
}
//class CommentViewModel: ObservableObject {
//    @Published var comments: [Comment] = [
//        Comment(text: "This is a test comment!", timestamp: Date(), publisher: "TestUser")
//    ] // 🔥 Add a default comment
//}
