//
//  MenuSheet.swift
//  ARchitect
//
//  Created by Amiire kolawole on 2025-04-09.
//

import SwiftUI

struct MenuSheet: View {
    var post: Post
    var body: some View {
        ZStack{
            Color(.sRGB,red: 249/255, green: 237/255, blue: 215/255)
                .edgesIgnoringSafeArea(.all)
            Spacer().frame(height: 5)
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 5)
            VStack() {
                Button {
                    print("Option 1 tapped")
                } label: {
                    Label("Share this post", systemImage: "square.and.arrow.up")
                        .cornerRadius(10)
                        .foregroundStyle(Color(.black))
                }
                Divider()
                Button {
                    print("Option 2 tapped")
                } label: {
                    Label("Hide this post", systemImage: "eye.slash")
                        .cornerRadius(10)
                        .foregroundStyle(Color(.black))
                }
                Divider()
                Button {
                    print("Option 3 tapped")
                } label: {
                    Label("Go to profile", systemImage: "person.circle")
                        .cornerRadius(10)
                        .foregroundStyle(Color(.black))
                }
            }
            .padding(.vertical, 10)
            .background(Color(red: 102/255, green: 82/255, blue: 56/255,opacity: 0.31))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray, lineWidth: 1))
            .padding(20)
            .presentationDetents([.fraction(0.3)])
            .background(Color(.sRGB,red: 249/255, green: 237/255, blue: 215/255))
        }
    }
}

#Preview {
    MenuSheet(
        post: Post(
            username: "username",
            userImage: "person.circle.fill", // SF Symbol for user avatar
            title: "1990 Vintage",
            imageName: "ar_room1", // Replace with actual asset name
            description: "Bold interior design project that revives the vibrant energy of the early '80s. It marries vivid color schemes, geometric patterns, and nostalgic accents with contemporary comforts.",
            likes: 120)
    )
}
