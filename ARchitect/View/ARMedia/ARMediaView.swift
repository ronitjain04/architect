//
//  ARMediaView.swift
//  ARchitect
//
//  Created by Songyuan Liu on 2/4/25.
//

import SwiftUI

struct ARMediaView: View {
    @State var posts: [Post]
    //@State private var showSettings = false
    
    init() {
        //Firebase call gets all posts
        posts = [
            Post(
                username: "username",
                userImage: "person.circle.fill", // SF Symbol for user avatar
                title: "1990 Vintage",
                imageName: "ar_room1", // Replace with actual asset name
                description: "Bold interior design project that revives the vibrant energy of the early '80s. It marries vivid color schemes, geometric patterns, and nostalgic accents with contemporary comforts.",
                likes: 35),
            Post(
                username: "Bob",
                userImage: "person.circle.fill", // SF Symbol for user avatar
                title: "Virtual Office",
                imageName: "ar_room2", // Replace with actual asset name
                description: "Bold interior design project that revives the vibrant energy of the early '80s. It marries vivid color schemes, geometric patterns, and nostalgic accents with contemporary comforts.",
                likes: 28),
            
            Post(
                username: "Sam",
                imageName: "ar_room3", // Replace with actual asset name
                description: "My own room with amazing lighting and furniture. Explore how I have transfomed my space"),
            
            Post(
                username: "Paul",
                imageName: "ar_room4", // Replace with actual asset name
                description: "Bold interior design project that revives the vibrant energy of the early '80s. It marries vivid color schemes, geometric patterns, and nostalgic accents with contemporary comforts."),
            Post(imageName: "ar_room5"),
            
            Post(
                username: "Steven",
                imageName: "ar_room6", // Replace with actual asset name
                description: "My own room with amazing lighting and furniture. Explore how I have transfomed my space"),
            Post(imageName: "ar_room7")
        ]
    }
    
    var body: some View {
        NavigationStack {
            ZStack (alignment: .bottom){
                Color(.sRGB,red: 249/255, green: 237/255, blue: 215/255)
                    .ignoresSafeArea()
                VStack {
                    // Top Bar
                    HStack {
                        HStack(spacing: 15) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                            
                            Text("ARchitect")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color(red: 102/255, green: 82/255, blue: 56/255))
                        }
                        
                        Spacer()
//                        
//                        Button(action: {
//                            showSettings.toggle()
//                        }) {
//                            Image(systemName: "line.3.horizontal")
//                                .resizable()
//                                .frame(width: 20, height: 15)
//                                .padding(6)
//                                .foregroundColor(.black)
//                        }
//                        .sheet(isPresented: $showSettings) {
//                            Text("Settings go here")
//                                .font(.title)
//                                .padding()
//                        }
                        
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Divider()
                        .background(Color.gray)
                        .frame(maxWidth: .infinity)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(posts) { post in
//                                if let binding = bindingForPost(id: post.id) {
                                    NavigationLink(destination: PostView(post: post)) {
                                        SubARView(post: post)
                                    }
//                                }
                                
                                Divider()
                                    .background(Color.gray)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                
                BottomNavigationBar()
            }
        }
    }
    
//    private func bindingForPost(id: UUID) -> Binding<Post>? {
//        guard let index = posts.firstIndex(where: { $0.id == id}) else { return nil}
//        return $posts[index]
//    }
    
}

#Preview {
    ARMediaView()
}

struct SubARView: View {
    @ObservedObject var post:Post
    @State private var showComments = false
    @State private var showMenuSheet = false
    
    var body: some View {
        VStack {
            // User Info and Options
            Spacer().frame(height: 5)
            HStack {
                Image(systemName: post.userImage)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                
                Text(post.username)
                    .font(.custom("SF Pro Display",size:20))
                    .foregroundColor(Color(red: 102/255, green: 82/255, blue: 56/255))
                
                
                Spacer()
                Button {
                    showMenuSheet = true
                } label: {
                       Image(systemName: "ellipsis")
                           .frame(width: 30, height: 30)
                           .foregroundColor(.black)
                   }
                
            }
            .padding(.horizontal,20)
            
            Spacer().frame(height: 30)
            
            ZStack(alignment: .bottomLeading) {
                // AR Image with rounded corners and overlay
                Image(post.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 300)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
                
                // Overlay Content
                Text(post.description)
                    .frame(maxWidth: .infinity)
                    .font(.callout)
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(20)
            }
            .padding(.horizontal)
            
            Spacer().frame(height: 30)
            
            // Interaction Bar
            HStack {
                Button(action: {
                    post.toggleLike()
                }) {
                    HStack {
                        Image(systemName: post.user_liked ? "heart.fill" : "heart")
                            .foregroundColor(.red)
                            .font(.largeTitle)
                        Text(post.likes >= 100 ? "100+" : "\(post.likes)")
                    }
                }
                
                Button(action: {
                    showComments.toggle()
                }) {
                    HStack {
                        Image(systemName: "ellipsis.message")
                            .font(.largeTitle)
                        Text("\(post.numberOfComments())+")
                    }
                }
                
                Spacer()
                
                Text(post.time_ago())
                    .padding(.leading, 30)
                
            }
            .padding(.horizontal)
        }
        .foregroundColor(.black) // Set the text color to grey
        .font(.body)
        .sheet(isPresented: $showMenuSheet) {
            MenuSheet(post: post)
        }
        .sheet(isPresented: $showComments) {
            CommentSectionView(viewModel: $post.commentsModel)
        }
        
    }
}
