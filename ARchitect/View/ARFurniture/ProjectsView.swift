import SwiftUI

/// The Profile tab — modelled on an Instagram profile. A header with avatar,
/// project/follower stats, bio, and action buttons sits above a 3-column grid
/// of the user's projects (the app's closest thing to a personal gallery).
struct ProfileView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selectedSection: ProfileSection = .grid
    @State private var selectedProject: Project? = nil
    @State private var showEditProfile = false
    @State private var showARCamera = false
    @State private var showLogOutDialog = false

    enum ProfileSection { case grid, locked, saved }

    private var handle: String { session.profile?.username ?? "you" }
    private var displayName: String { session.profile?.displayName ?? "" }
    private var bio: String {
        let value = session.profile?.bio ?? ""
        return value.isEmpty ? "Add a bio in Edit profile" : value
    }

    let projects = [
        Project(name: "Minimalistic", tags: ["Minimalistic"], isLocked: true, image: "Minimalistic", modified: "August 23, 2022"),
        Project(name: "Bedroom", tags: ["Modern", "Sunlit"], isLocked: false, image: "Bedroom", modified: "August 15, 2022"),
        Project(name: "Office", tags: ["Old Gothic", "More"], isLocked: true, image: "Office", modified: "August 10, 2022"),
        Project(name: "Living Room", tags: ["Modern", "Sunlit"], isLocked: false, image: "Living Room", modified: "August 05, 2022"),
        Project(name: "Kitchen", tags: ["Modern"], isLocked: false, image: "Kitchen", modified: "July 28, 2022"),
        Project(name: "Dining Room", tags: ["Modern"], isLocked: false, image: "Dining Room", modified: "July 25, 2022"),
        Project(name: "Sunlit Bedroom", tags: ["Nature", "Cottage core"], isLocked: false, image: "Sunlit Bedroom", modified: "July 20, 2022"),
        Project(name: "Cool Living Room", tags: ["Contemporary", "Colorful"], isLocked: true, image: "Cool Living Room", modified: "July 15, 2022")
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var visibleProjects: [Project] {
        switch selectedSection {
        case .grid:   return projects
        case .locked: return projects.filter { $0.isLocked }
        case .saved:  return projects.filter { $0.tags.contains("Minimalistic") || $0.name == "Bedroom" }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Divider().background(Color.appDivider)

                ScrollView {
                    profileHeader
                    sectionTabs
                    grid
                        .padding(.bottom, 90)
                }
            }

            if let selectedProject {
                projectPopup(for: selectedProject)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 6) {
            Text(handle)
                .font(AppFont.inter(18, .semibold))
                .foregroundColor(.appText)
            Spacer()
            // Capture a new space in AR.
            Button { showARCamera = true } label: {
                Image(systemName: "plus.app")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.appText)
            }
            // Account menu.
            Button { showLogOutDialog = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(.appText)
            }
            .padding(.leading, AppSpacing.sm)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .fullScreenCover(isPresented: $showARCamera) {
            ARViewControllerWrapper()
                .ignoresSafeArea()
        }
        .confirmationDialog("Account", isPresented: $showLogOutDialog) {
            Button("Log out", role: .destructive) {
                session.signOut()
            }
        }
    }

    // MARK: Header

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.appAccent, lineWidth: 2.5)
                        .frame(width: 88, height: 88)
                    Avatar(monogram: "M", size: 78)
                }

                HStack(spacing: 0) {
                    stat(value: "\(projects.count)", label: "projects")
                    stat(value: "142", label: "followers")
                    stat(value: "98", label: "following")
                }
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(AppFont.inter(14, .semibold))
                    .foregroundColor(.appText)
                Text(bio)
                    .font(AppFont.inter(13, .regular))
                    .foregroundColor(.appText)
            }

            HStack(spacing: AppSpacing.sm) {
                Button { showEditProfile = true } label: { Text("Edit profile") }
                    .buttonStyle(CompactSecondaryButtonStyle())
                ShareLink(item: "Check out my ARchitect profile — @\(handle)") {
                    Text("Share profile")
                }
                .buttonStyle(CompactSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(
                displayName: session.profile?.displayName ?? "",
                bio: session.profile?.bio ?? ""
            )
            .environmentObject(session)
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(AppFont.inter(17, .semibold))
                .foregroundColor(.appText)
            Text(label)
                .font(AppFont.inter(12, .regular))
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Section tabs

    private var sectionTabs: some View {
        HStack(spacing: 0) {
            sectionTab(.grid, icon: "square.grid.3x3")
            sectionTab(.locked, icon: "lock")
            sectionTab(.saved, icon: "bookmark")
        }
        .overlay(Rectangle().fill(Color.appDivider).frame(height: 0.5), alignment: .top)
    }

    private func sectionTab(_ section: ProfileSection, icon: String) -> some View {
        let isSelected = selectedSection == section
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedSection = section }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .appText : .appTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .overlay(
                    Rectangle()
                        .fill(isSelected ? Color.appText : Color.clear)
                        .frame(height: 1.5),
                    alignment: .bottom
                )
        }
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(visibleProjects, id: \.id) { project in
                if project.isLocked {
                    ProjectGridCell(project: project)
                        .onTapGesture { withAnimation { selectedProject = project } }
                } else {
                    NavigationLink(destination: EditProjectView(project: project).navigationBarBackButtonHidden(true)) {
                        ProjectGridCell(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: Project popup

    private func projectPopup(for project: Project) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { withAnimation { selectedProject = nil } }

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Spacer()
                    Button { withAnimation { selectedProject = nil } } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundColor(.appTextSecondary)
                    }
                }

                Image(project.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)
                    .frame(height: 160)
                    .cornerRadius(AppRadius.md)
                    .padding(.top, -12)

                Text(project.name)
                    .font(AppFont.title2)
                    .foregroundColor(.appText)

                Text("A modern dining chair with wooden legs and a grey seat. Looks great in any contemporary dining space.")
                    .font(AppFont.subheadline)
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)

                Text("Modified: \(project.modified)")
                    .font(AppFont.subheadline)
                    .foregroundColor(.appTextSecondary)

                NavigationLink(destination: ARViewControllerWrapper().navigationBarBackButtonHidden(true)) {
                    Text("Open Project")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, AppSpacing.sm)

                Button { withAnimation { selectedProject = nil } } label: {
                    Text("Delete")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(Color.appBackground)
            )
            .frame(width: 320)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, AppSpacing.md)
        }
        .transition(.opacity)
    }
}

/// Edits the profile fields and persists them to the user's Firestore
/// document.
struct EditProfileSheet: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State var displayName: String
    @State var bio: String

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Edit profile")
                .font(AppFont.inter(15, .semibold))
                .foregroundColor(.appText)
                .padding(.top, AppSpacing.md)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Name")
                    .font(AppFont.inter(13, .semibold))
                    .foregroundColor(.appTextSecondary)
                AuthField(placeholder: "Name", text: $displayName)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Bio")
                    .font(AppFont.inter(13, .semibold))
                    .foregroundColor(.appTextSecondary)
                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(2...4)
                    .font(AppFont.body)
                    .foregroundColor(.appText)
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(Color.appSurfaceAlt)
                    )
            }

            Button("Done") {
                Task {
                    await session.updateProfile(displayName: displayName, bio: bio)
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBackground)
    }
}

/// Quiet, compact tan button used for the profile's "Edit profile" / "Share".
struct CompactSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.inter(13, .semibold))
            .foregroundColor(.appText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(Color.appSurfaceAlt)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Square grid cell

struct ProjectGridCell: View {
    let project: Project

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(project.image)
                    .resizable()
                    .scaledToFill()
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: project.isLocked ? "lock.fill" : "cube.transparent.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .shadow(color: .black.opacity(0.4), radius: 2)
            }
            .overlay(alignment: .bottomLeading) {
                if let tag = project.tags.first {
                    Text(tag)
                        .font(AppFont.inter(9, .semibold))
                        .padding(.vertical, 3)
                        .padding(.horizontal, 7)
                        .background(Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(AppRadius.sm)
                        .padding(6)
                }
            }
            .clipped()
            // scaledToFill overflows the square; without an explicit content
            // shape the overflow still hit-tests and taps bleed into
            // neighboring cells.
            .contentShape(Rectangle())
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SessionStore())
    }
}
