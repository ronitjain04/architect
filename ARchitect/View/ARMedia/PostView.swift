//
//  PostView.swift
//  ARchitect
//
//  Created by Amiire kolawole on 2025-03-03.
//

import SwiftUI

struct PostView: View {
    @ObservedObject var post: Post
    @Environment(\.dismiss) private var dismiss
    @State private var showComments = false
    @State private var showMenuSheet = false
    @State private var showPopUp = false
    @State private var selectedFurniture: VREnvironmentConfig.VRObjectConfig? = nil

    let environment: VREnvironmentConfig
    let objects: [VREnvironmentConfig.VRObjectConfig]

    init(post: Post, showComments: Bool = false) {
        let postID = post.uuid

        self.post = post
        self.showComments = showComments

        //Firebase call for getting an environment with just the post ID
        let environments = [VREnvironmentConfig(postID: postID)]
        environment = environments.first(where: { $0.id == postID}) ?? VREnvironmentConfig(postID: postID)

        objects = environment.objects
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                Divider().background(Color.appDivider)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Author row
                        HStack(spacing: 10) {
                            Avatar(monogram: post.username, size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(post.username)
                                    .font(AppFont.inter(13, .semibold))
                                    .foregroundColor(.appText)
                                Text(post.title)
                                    .font(AppFont.inter(11, .regular))
                                    .foregroundColor(.appTextSecondary)
                            }
                            Spacer()
                            Button { showMenuSheet = true } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.appText)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)

                        // Full-bleed image — tap to open the AR session.
                        NavigationLink(destination: ARSessionView2(config: environment)
                            .ignoresSafeArea()) {
                            ZStack(alignment: .topTrailing) {
                                PostImage(post: post)
                                    .frame(height: 380)
                                    .frame(maxWidth: .infinity)
                                    .containerRelativeFrame(.horizontal)
                                    .clipped()
                                    .background(Color.appSurface)
                                    .contentShape(Rectangle())

                                Label("View in AR", systemImage: "arkit")
                                    .font(AppFont.inter(11, .semibold))
                                    .foregroundColor(.appOnPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.appText.opacity(0.55)))
                                    .padding(12)
                            }
                        }
                        .buttonStyle(.plain)

                        // Action bar
                        HStack(spacing: 18) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                post.toggleLike()
                            } label: {
                                Image(systemName: post.user_liked ? "heart.fill" : "heart")
                                    .foregroundColor(post.user_liked ? .appLike : .appText)
                                    .symbolEffect(.bounce, value: post.user_liked)
                            }
                            Button { showComments = true } label: {
                                Image(systemName: "bubble.right").foregroundColor(.appText)
                            }
                            Button { showMenuSheet = true } label: {
                                Image(systemName: "paperplane").foregroundColor(.appText)
                            }
                            Spacer()
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                post.toggleSaved()
                            } label: {
                                Image(systemName: post.saved ? "bookmark.fill" : "bookmark")
                                    .foregroundColor(.appText)
                                    .symbolEffect(.bounce, value: post.saved)
                            }
                        }
                        .font(.system(size: 23, weight: .regular))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        Text("\(post.likes) likes")
                            .font(AppFont.inter(13, .semibold))
                            .foregroundColor(.appText)
                            .padding(.horizontal, AppSpacing.md)

                        (Text(post.username + "  ").font(AppFont.inter(13, .semibold))
                         + Text(post.description).font(AppFont.inter(13, .regular)))
                            .foregroundColor(.appText)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, 3)

                        Text(post.time_ago().uppercased())
                            .font(AppFont.inter(10, .regular))
                            .foregroundColor(.appTextSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, 6)

                        // Featured furniture in this post
                        FeaturedInPost(objects: objects, showPopUp: $showPopUp, selectedFurniture: $selectedFurniture)
                            .padding(.top, AppSpacing.lg)
                            .padding(.bottom, AppSpacing.lg)
                    }
                }
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
        .toolbar(.hidden, for: .navigationBar)
    }

    private var navBar: some View {
        HStack(spacing: AppSpacing.md) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.appText)
            }
            Text(post.username)
                .font(AppFont.inter(15, .semibold))
                .foregroundColor(.appText)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(height: 48)
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
            .font(AppFont.title3)
            .foregroundColor(.appText)
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
            VStack(alignment: .leading, spacing: AppSpacing.md) {

                // Close button at top-right
                HStack {
                    Spacer()
                    Button {
                        self.isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.appTextSecondary)
                    }
                }

                // Main item image
                // Replace furniture.imageName with your actual asset name if needed.
                Image(selectedFurniture.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)         // Adjust to your preference
                    .frame(height: 160)          // Example height
                    .cornerRadius(AppRadius.md)
                    .padding(.top, -12)          // Pulls image up a bit if desired

                // Title and short description
                Text(selectedFurniture.displayName)
                    .font(AppFont.title2)
                    .foregroundColor(.appText)

                Text(selectedFurniture.description)
                    .font(AppFont.subheadline)
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(nil)


                // “Related Items” header
                Text("Related Items")
                    .font(AppFont.headline)
                    .foregroundColor(.appText)
                    .padding(.top, AppSpacing.sm)

                // Related items row (example placeholders)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.md) {
                        // Replace with your real “related items” data
                        ForEach(sampleRelatedItems, id: \.0) { relatedItem in
                            VStack(spacing: AppSpacing.xs) {
                                // Placeholder image or real image
                                Image(relatedItem.1)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(AppRadius.sm)

                                Text(relatedItem.0)
                                    .font(AppFont.caption)
                                    .foregroundColor(.appText)
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(Color.appBackground)
            )
            .frame(width: 320) // Adjust card width to suit your design
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, AppSpacing.md)
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
