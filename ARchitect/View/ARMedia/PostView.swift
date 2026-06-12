//
//  PostView.swift
//  ARchitect
//
//  Created by Amiire kolawole on 2025-03-03.
//

import SwiftUI

struct PostView: View {
    @ObservedObject var post: Post
    @State private var showComments = false
    @State private var showMenuSheet = false
    @State private var showPopUp = false
    @State private var selectedFurniture: VREnvironmentConfig.VRObjectConfig? = nil
    
    let environment: VREnvironmentConfig
    let objects: [VREnvironmentConfig.VRObjectConfig]
    private let barColor = Color(red: 99/255, green: 83/255, blue: 70/255)
    private let iconColor = Color(red: 222/255, green: 204/255, blue: 177/255)
    
    init(post: Post, showComments: Bool = false) {
        let postID = post.id
        
        self.post = post
        self.showComments = showComments
        
        //Firebase call for getting an environment with just the post ID
        let environments = [VREnvironmentConfig(postID: postID)]
        environment = environments.first(where: { $0.id == postID}) ?? VREnvironmentConfig(postID: postID)
        
        objects = environment.objects
    }
    
    var body: some View {
        ZStack {
            Color(.sRGB,red: 249/255, green: 237/255, blue: 215/255)
                .ignoresSafeArea()
            VStack(alignment: .leading) {
                //header
                Text("\(post.username)'s Post: \(post.title)")
                    .font(.custom("SF Pro Display",size:18))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(Color(red: 102/255, green: 82/255, blue: 56/255))
                    .frame(height: 58)
                Divider()
                    .background(Color.gray)
                    .frame(maxWidth: .infinity)
                
                ScrollView {
                    // User Info and Options
                    Spacer().frame(height: 5)
                    HStack {
                        Image(systemName: post.userImage)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                        
                        Text(post.username)
                            .font(.custom("SF Pro Display",size:14))
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
                    
                    // AR Image with Overlays
                    NavigationLink(destination: ARSessionView2(config: environment)
                        .ignoresSafeArea()) {
                        Image(post.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 300)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                    }
                    .padding()
                    
                    Spacer().frame(height: 30)
                    // Description
                    VStack {
                        Text(post.description)
                            .font(.custom("SF Pro Display",size:16))
                            .padding(.horizontal,22)
                        Spacer().frame(height: 10)
                        Text(post.time_ago())
                            .font(.custom("SF Pro Display",size:12))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.gray)
                            .padding(.horizontal,22)
                        Spacer().frame(height: 20)
                        //Featured
                        FeaturedInPost(objects: objects, showPopUp: $showPopUp, selectedFurniture: $selectedFurniture)
                    }
                    
                }
                
                HStack {
                    Spacer()
                    
                    // Plus Button opens the AR session view (using NavigationLink)
                    Button(action: {
                        post.toggleLike()
                    }) {
                        Image(systemName: post.user_liked ? "heart.fill" : "heart")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(post.user_liked ? .red : .white)
                    }
                    
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    
                    Button(action: {
                        showComments = true
                    }) {
                        Image(systemName: "bubble.left")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                    }
                    
                    
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()
                    
                    Button(action: {
                        showMenuSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(iconColor)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(barColor.opacity(0.90))
                        .blur(radius: 1)
                )
                .padding(.horizontal, 40)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .ignoresSafeArea()
                
            }
            .sheet(isPresented: $showComments) {
                CommentSectionView(viewModel: $post.commentsModel)
            }
            .sheet(isPresented: $showMenuSheet) {
                MenuSheet(post: post)
            }
            
            if showPopUp, let selectedFurniture = selectedFurniture {
                FeaturedCard(
                    isPresented: $showPopUp,
                    selectedFurniture: selectedFurniture
                )
            }
        }
    }
}


struct FeaturedInPost: View {
    @State var objects: [VREnvironmentConfig.VRObjectConfig]
    @Binding var showPopUp: Bool
    @Binding var selectedFurniture: VREnvironmentConfig.VRObjectConfig?
    

    let colors: [Color] = [.red, .green, .blue, .orange, .purple]
    
    var body: some View {
        Text("Featured In This Post")
            .frame(maxWidth: .infinity, alignment: .leading)
            .font(.custom("SF Pro Display",size:18))
            .foregroundColor(Color(red: 102/255, green: 82/255, blue: 56/255))
            .padding(.horizontal,22)
    
        ZStack {
            HStack {
                let objectsWithIndices = Array(objects.enumerated())
                
                ForEach(objectsWithIndices, id: \.element.id) { index, object in
                    let iconName = object.iconName
                    Button {
                        showPopUp.toggle()
                        self.selectedFurniture = object
                    } label: {
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(colors[index % colors.count].opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                
            }
            
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal,22)
            
        }
    }
}


struct FeaturedCard: View {
    @Binding var isPresented: Bool
    let selectedFurniture: VREnvironmentConfig.VRObjectConfig
    
    let sampleRelatedItems: [(String, String)] = [
        ("Bar Stool chair", "barChair"), // <– Replace with real asset name
        ("Dining Table", "SimpleDiningTable"),
        ("Personal Chair", "Living Room Chair")
    ]
    
    var body: some View {
        ZStack {
            // Dark, translucent background behind the card
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .allowsHitTesting(true)
                .onTapGesture {
                    // Close popup if user taps outside the card
                    self.isPresented = false
                }
            
            // The popup card
            VStack(alignment: .leading, spacing: 16) {
                
                // Close button at top-right
                HStack {
                    Spacer()
                    Button {
                        self.isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(Color.gray.opacity(0.6))
                    }
                }
                
                // Main item image
                // Replace furniture.imageName with your actual asset name if needed.
                Image(selectedFurniture.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)         // Adjust to your preference
                    .frame(height: 160)          // Example height
                    .cornerRadius(12)
                    .padding(.top, -12)          // Pulls image up a bit if desired
                
                // Title and short description
                Text(selectedFurniture.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Text(selectedFurniture.description)
                    .font(.subheadline)
                    .foregroundColor(.black.opacity(0.8))
                    .lineLimit(nil)
                
                
                // “Related Items” header
                Text("Related Items")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.top, 8)
                
                // Related items row (example placeholders)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        // Replace with your real “related items” data
                        ForEach(sampleRelatedItems, id: \.0) { relatedItem in
                            VStack(spacing: 4) {
                                // Placeholder image or real image
                                Image(relatedItem.1)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(6)
                                
                                Text(relatedItem.0)
                                    .font(.caption)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    // Matches your overall beige scheme:
                    .fill(Color(red: 255/255, green: 242/255, blue: 223/255))
            )
            .frame(width: 320) // Adjust card width to suit your design
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 16)
        }
        .transition(.opacity)  // Fade in/out transition
    }
}


#Preview {
    @Previewable @State var post = Post(
        username: "username",
        userImage: "person.circle.fill",
        title: "1990 Vintage",
        imageName: "ar_room1",
        description: "Bold interior design project that revives the vibrant energy of the early '80s.",
        likes: 120
    )
    
    PostView(post: post)
}
