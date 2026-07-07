//
//  EditProjectView.swift
//  ARchitect
//
//  Edit a project — Instagram "edit post" style: back / title / save header,
//  the project image, an editable name, and tag management.
//

import SwiftUI

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    // The project is passed into the view.
    let project: Project

    @State private var projectName: String
    @State private var tagSearch: String = ""
    @State private var selectedTags: [String]

    init(project: Project) {
        self.project = project
        _projectName = State(initialValue: project.name)
        _selectedTags = State(initialValue: project.tags)
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar: back / title / save
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.appText)
                    }

                    Spacer()

                    Text("Edit project")
                        .font(AppFont.inter(15, .semibold))
                        .foregroundColor(.appText)

                    Spacer()

                    Button {
                        // Save action
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.appAccent)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 48)

                Divider().background(Color.appDivider)

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Image(project.image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                        // Editable name
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Name")
                                .font(AppFont.inter(13, .semibold))
                                .foregroundColor(.appTextSecondary)
                            AuthField(placeholder: "Project name", text: $projectName)
                        }

                        // Tags
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Tags")
                                .font(AppFont.inter(13, .semibold))
                                .foregroundColor(.appTextSecondary)

                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.appTextSecondary)
                                TextField("Find tags", text: $tagSearch)
                                    .font(AppFont.body)
                                    .foregroundColor(.appText)
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                                    .fill(Color.appSurfaceAlt)
                            )

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(selectedTags, id: \.self) { tag in
                                        TagChip(text: tag)
                                    }
                                }
                            }
                            .padding(.top, AppSpacing.xs)
                        }
                    }
                    .padding(AppSpacing.md)
                }

                // Bottom bar: Delete and Save
                HStack(spacing: AppSpacing.sm) {
                    Button {
                        // Delete action
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button {
                        // Save action
                        dismiss()
                    } label: {
                        Text("Save")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
        }
        // Custom header + back button above, so hide the native nav bar.
        .toolbar(.hidden, for: .navigationBar)
    }
}

// A simple subview for tag chips.
struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AppFont.inter(12, .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.appAccent))
            .foregroundColor(.white)
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
