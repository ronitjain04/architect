//
//  EditProjectView.swift
//  ARchitect
//
//  Created by Jiyoon Lee on 4/11/25.
//

import SwiftUI

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    // The project is passed into the view.
    let project: Project

    @State private var projectName: String
    // @State private var descriptionText: String
    @State private var tagSearch: String = ""
    @State private var selectedTags: [String]
    
    let brownColor = Color(red: 99/255, green: 83/255, blue: 70/255)

    init(project: Project) {
        self.project = project
        _projectName = State(initialValue: project.name)
        _selectedTags = State(initialValue: project.tags)
        // _descriptionText = State(initialValue: project.descriptionText ?? "")
    }
    
    var body: some View {
        ZStack {
            Color(red: 255/255, green: 242/255, blue: 223/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                                .foregroundColor(Color(red: 99/255, green: 83/255, blue: 70/255))
                                .fontWeight(.semibold)
                                .font(.title2)
                    }
                    Spacer()
                    
                    Text(projectName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(red: 99/255, green: 83/255, blue: 70/255))
                    

                    Spacer()
                    Button {
                        // Dismiss logic here
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(Color(red: 99/255, green: 83/255, blue: 70/255))
                            .fontWeight(.semibold)
                            .font(.title2)
                    }
                    Spacer()
                }
                .padding(.top, 8)
                
                // Main Content
                ScrollView {
                    // Large Image with a share button at the top-right
                    ZStack(alignment: .topTrailing) {
                        Image(project.image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    // "Find Tags" field
                    VStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(brownColor)
                                .padding(.leading, 14)
                            TextField("Find Tags", text: $tagSearch)
                                .foregroundColor(brownColor)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 236/255, green: 216/255, blue: 189/255))
                                .frame(width: 338, height: 33)
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(selectedTags, id: \.self) { tag in
                                    TagChip(text: tag)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.horizontal)
                    }
                    // Project Description
                    //                ZStack(alignment: .topLeading) {
                    //                    if descriptionText.isEmpty {
                    //                        Text("Enter project description...")
                    //                            .foregroundColor(.gray)
                    //                            .padding(.leading, 6)
                    //                            .padding(.top, 8)
                    //                    }
                    //                    TextEditor(text: $descriptionText)
                    //                        .padding(4)
                    //                        .frame(minHeight: 100)
                    //                }
                    //                .background(
                    //                    RoundedRectangle(cornerRadius: 10)
                    //                        .fill(Color(UIColor.systemGray6))
                    //                )
                    //                .padding(.horizontal)
                    //                .padding(.top, 8)
                    //
                    //                Spacer(minLength: 40)
                }
                
                // Bottom Bar with "Delete" and "Save" buttons
                HStack(spacing: 12) {
                    Spacer()
                    Spacer()
                    Button(action: {
                            // Delete action
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                            .font(.subheadline)
                            .foregroundColor(brownColor)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(brownColor, lineWidth: 2)
                                    .frame(width: 152, height: 33)
                            )
                        }
                    Spacer()
                    Spacer()
                    Spacer()
                    Button(action: {
                            // Save action
                        }) {
                            Text("Save")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(brownColor)
                                        .frame(width: 152, height: 33)
                                )
                    }
                    Spacer()
                    Spacer()
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
        }
    }
}

// A simple subview for tag chips.
struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(red: 206/255, green: 135/255, blue: 35/255))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

// A sample preview showing how to pass a project.
struct EditProjectView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EditProjectView(project: Project(name: "Dining Room",
                                             tags: ["Modern", "Sunlit"],
                                             isLocked: false,
                                             image: "diningRoomImage",
                                             modified: "August 05, 2022"))
        }
    }
}
