import SwiftUI

struct ProjectsView: View {
    @Binding var recentMode: RecentMode  // Shared state from GeneralView
    
    @State private var selectedFilter: String = "All Projects"
    @State private var isSearchActive: Bool = false
    @State private var searchQuery: String = ""
    @State private var isKeyboardVisible: Bool = false
    @State private var selectedProject: Project? = nil
    
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
    
    let sampleRelatedItems: [(String, String)] = [
        ("Rond table", "rondTableImage"),
        ("Chaich", "chaichImage"),
        ("Parson Chair", "parsonChairImage")
    ]
    
    let projectFilters = ["All Projects", "Favorites", "A-Z", "Private", "Public"]
    
    private func leftColumnProjects() -> [Project] {
        let filtered = filteredProjects()
        return stride(from: 0, to: filtered.count, by: 2).map { filtered[$0] }
    }

    private func rightColumnProjects() -> [Project] {
        let filtered = filteredProjects()
        return stride(from: 1, to: filtered.count, by: 2).map { filtered[$0] }
    }
    
    var body: some View {
        // No NavigationStack here — the root stack is owned by RootTabView.
        Group {
            ZStack(alignment: .bottom) {
                Color(red: 255/255, green: 242/255, blue: 223/255)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // Recent Section & Filters
                    ScrollView {
                        // "Recent" navigation buttons row
                        HStack {
                            Text("Recent")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(Color(red: 99/255, green: 83/255, blue: 70/255))
                            Spacer()
                            HStack {
                                Button {
                                    withAnimation {
                                        recentMode = .box
                                    }
                                } label: {
                                    Image(systemName: "square.split.bottomrightquarter.fill")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(red: 99/255, green: 83/255, blue: 70/255))
                                }
                                Button {
                                    withAnimation {
                                        recentMode = .sofa
                                    }
                                } label: {
                                    Image(systemName: "sofa")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(red: 99/255, green: 83/255, blue: 70/255))
                                }
                            }
                            .padding(.vertical, 7.5)
                            .padding(.horizontal, 15)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(red: 236/255, green: 216/255, blue: 189/255))
                            )
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        
                        // Horizontal scroll of sample projects
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(projects.prefix(3), id: \.id) { project in
                                    if project.isLocked {
                                        ProjectCard(project: project)
                                            .onTapGesture {
                                                withAnimation {
                                                    selectedProject = project
                                                }
                                            }
                                    } else {
                                        NavigationLink(destination: EditProjectView(project: project).navigationBarBackButtonHidden(true)) {
                                            ProjectCard(project: project)
                                                .frame(width: 123, height: 212)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }.padding(.horizontal)
                            }
                        }
                        
                        // Filters row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(projectFilters, id: \.self) { filter in
                                    Button(action: {
                                        selectedFilter = filter
                                    }) {
                                        Text(filter)
                                            .font(.subheadline)
                                            .fontWeight(selectedFilter == filter ? .bold : .regular)
                                            .foregroundColor(Color(red: 99/255, green: 83/255, blue: 70/255))
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(red: 236/255, green: 216/255, blue: 189/255))
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.gray.opacity(0.2), lineWidth: selectedFilter == filter ? 0 : 1)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 12)
                        
                        // Main grid of projects after filtering and search query
                        // Split the projects into two vertical columns
                        HStack(alignment: .top, spacing: 12) {
                            LazyVStack(spacing: 16) {
                                ForEach(leftColumnProjects(), id: \.id) { project in
                                    ProjectCard(project: project)
                                }
                            }

                            LazyVStack(spacing: 16) {
                                ForEach(rightColumnProjects(), id: \.id) { project in
                                    ProjectCard(project: project)
                                }
                            }
                        }
                        .padding([.horizontal, .bottom])
                        .padding(.top, 4)
                    }
                }
                
                //            if !isKeyboardVisible {
                //                BottomNavigationBar()
                //            }
                
                // Black popup overlay when a project is selected.
                if let selectedProject = selectedProject {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    self.selectedProject = nil
                                }
                            }
                        
                        // Popup Card resembling your design
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation {
                                        self.selectedProject = nil
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .resizable()
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(Color.gray.opacity(0.6))
                                }
                            }
                            
                            Image(selectedProject.image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 200)
                                .frame(height: 160)
                                .cornerRadius(12)
                                .padding(.top, -12)
                            
                            Text(selectedProject.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            
                            Text("A modern dining chair with wooden legs and a grey seat. Looks great in any contemporary dining space.")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.8))
                                .lineLimit(2)
                            
                            Text("Modified: \(selectedProject.modified)")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.8))
                            
                            NavigationLink(destination: ARViewControllerWrapper().navigationBarBackButtonHidden(true)) {
                                Text("Open Project")
                                    .foregroundColor(Color(red: 99/255, green: 83/255, blue: 70/255))
                                    .fontWeight(.bold)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(12)
                            }
                            .padding(.top, 8)

                            Button {
                                withAnimation {
                                    self.selectedProject = nil
                                }
                            } label: {
                                Text("Delete")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(red: 99/255, green: 83/255, blue: 70/255))
                                    .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(red: 255/255, green: 242/255, blue: 223/255))
                        )
                        .frame(width: 320)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                    }
                    .transition(.opacity)
                }
            }
        }
    }
    
    // MARK: - Filter Logic
    private func filteredProjects() -> [Project] {
        var result = projects
        if !searchQuery.isEmpty {
            result = result.filter { project in
                project.name.lowercased().contains(searchQuery.lowercased())
            }
        }
        if selectedFilter == "Favorites" {
            result = result.filter { $0.name.contains("Minimalistic") || $0.tags.contains("Minimalistic") }
        } else if selectedFilter == "A-Z" {
            result.sort { $0.name < $1.name }
        } else if selectedFilter == "Private" {
            result = result.filter { $0.isLocked }
        } else if selectedFilter == "Public" {
            result = result.filter { !$0.isLocked }
        }
        return result
    }
}

// MARK: - Card for Projects
struct ProjectCard: View {
    var project: Project
    
    var body: some View {
        ZStack {
            Image(project.image)
                .resizable()
                .scaledToFill()
                .frame(width: 173, height: 188) // 🔒 Lock the image to card size
                .clipped()

            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                startPoint: .bottom,
                endPoint: .center
            )
            .cornerRadius(12)

            if project.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding([.top, .trailing], 4)
            } else {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding([.top, .trailing], 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    ForEach(project.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 8))
                            .fontWeight(.bold)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(red: 206/255, green: 135/255, blue: 35/255))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .lineLimit(1)
                    }
                }
                Text(project.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(width: 173, height: 188) // 💡 Apply fixed frame here to contain it all
        .cornerRadius(12)
        .clipped() // 🛡 Prevents image overflow
    }
}


struct ProjectsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView()
    }
}
