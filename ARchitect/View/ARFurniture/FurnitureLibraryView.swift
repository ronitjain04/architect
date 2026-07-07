import SwiftUI

/// The Explore tab — an Instagram-style discovery screen: search furniture
/// (catalog grid) or people (accounts to follow), with category pills and a
/// tight grid of items that open the product page.
struct FurnitureExploreView: View {
    @EnvironmentObject var session: SessionStore
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "Chairs"
    @State private var searchScope: SearchScope = .furniture
    @State private var userResults: [UserProfile] = []

    enum SearchScope { case furniture, people }

    private let categories: [(String, String)] = [
        ("Chairs", "chair.fill"),
        ("Sofas", "sofa.fill"),
        ("Lights", "lamp.floor.fill"),
        ("Desks", "table.furniture.fill"),
        ("Drawers", "archivebox.fill"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var items: [FurnitureItem] {
        FurnitureData.allItems.filter { item in
            (selectedCategory.isEmpty || item.category == selectedCategory) &&
            (searchText.isEmpty ||
             item.name.localizedCaseInsensitiveContains(searchText) ||
             item.tags.contains { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search field
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.appTextSecondary)
                    TextField("Search furniture or people", text: $searchText)
                        .font(AppFont.body)
                        .foregroundColor(.appText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.appTextSecondary)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(Color.appSurfaceAlt)
                )
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)

                // Scope toggle appears while searching.
                if !searchText.isEmpty {
                    HStack(spacing: AppSpacing.sm) {
                        scopePill("Furniture", scope: .furniture)
                        scopePill("People", scope: .people)
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
                }

                if !searchText.isEmpty && searchScope == .people {
                    peopleResults
                } else {
                    furnitureBrowser
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: "\(searchText)|\(searchScope == .people)") {
            guard searchScope == .people, !searchText.isEmpty else { return }
            // Small debounce so we don't query per keystroke.
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            userResults = await SocialService.searchUsers(prefix: searchText)
        }
    }

    private func scopePill(_ label: String, scope: SearchScope) -> some View {
        let isSelected = searchScope == scope
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { searchScope = scope }
        } label: {
            Text(label)
                .font(AppFont.inter(13, .semibold))
                .foregroundColor(isSelected ? .appOnPrimary : .appPrimary)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(Capsule().fill(isSelected ? Color.appPrimary : Color.appSurfaceAlt))
        }
    }

    // MARK: People results

    private var peopleResults: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if userResults.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.appTextSecondary)
                        Text("No people found")
                            .font(AppFont.inter(15, .semibold))
                            .foregroundColor(.appText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(userResults, id: \.username) { user in
                        NavigationLink(destination: UserProfileView(username: user.username)) {
                            HStack(spacing: AppSpacing.md) {
                                Avatar(monogram: user.username, size: 44)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(user.username)
                                        .font(AppFont.inter(14, .semibold))
                                        .foregroundColor(.appText)
                                    if !user.displayName.isEmpty {
                                        Text(user.displayName)
                                            .font(AppFont.inter(12, .regular))
                                            .foregroundColor(.appTextSecondary)
                                    }
                                }

                                Spacer()

                                if user.username != session.profile?.username {
                                    FollowButton(username: user.username)
                                        .frame(width: 100)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 90)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: Furniture browser

    private var furnitureBrowser: some View {
        VStack(spacing: 0) {
                // Category pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(categories, id: \.0) { category in
                            let isSelected = selectedCategory == category.0
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedCategory = category.0 }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.1).font(.system(size: 13))
                                    Text(category.0).font(AppFont.inter(13, .semibold))
                                }
                                .foregroundColor(isSelected ? .appOnPrimary : .appPrimary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(
                                    Capsule().fill(isSelected ? Color.appPrimary : Color.appSurfaceAlt)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .padding(.bottom, AppSpacing.sm)

                Divider().background(Color.appDivider)

                // Discovery grid — cells open the product page.
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(items) { item in
                            NavigationLink(destination: FurnitureDetailView(item: item)) {
                                ExploreCell(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 90)
                }
                .scrollDismissesKeyboard(.immediately)
        }
    }
}

/// Square discovery thumbnail with a gold tag chip.
struct ExploreCell: View {
    let item: FurnitureItem

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
            )
            .overlay(alignment: .bottomLeading) {
                if let tag = item.tags.first {
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
            .background(Color.appSurface)
            .clipped()
            // scaledToFill overflows the square; without an explicit content
            // shape the overflow still hit-tests and taps bleed into
            // neighboring cells.
            .contentShape(Rectangle())
    }
}

struct FurnitureExploreView_Previews: PreviewProvider {
    static var previews: some View {
        FurnitureExploreView()
            .environmentObject(SessionStore())
    }
}
