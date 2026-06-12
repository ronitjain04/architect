import SwiftUI

enum RecentMode {
    case box
    case sofa
}

struct GeneralView: View {
    @State private var recentMode: RecentMode = .box
    @State private var selectedTab: String = "Projects"
    @State private var searchText: String = ""
    
    let tabs = ["Projects", "Furniture"]
    let filters = ["All Projects", "Favorites", "A-Z", "Private", "Public"]
    
    var body: some View {
        NavigationStack {
            VStack (spacing: 0) {
                navigationHeader
                
                ZStack {
                    if selectedTab == "Projects" {
                        ProjectsView(recentMode: $recentMode)
                    } else {
                        FurnitureLibraryWrapperView(searchText: $searchText)
                    }
                    
    //                if !isKeyboardVisible {
    //                    BottomNavigationBar()
    //                }
                    
                    VStack{
                        Spacer()
                        BottomNavigationBar()
                    }
                }
                   
            }
//            .toolbar {
//                NavigationLink {
//                    ARSessionView()
//                } label: {
//                    Text("Start AR")
//                }
//                
//            }
        }
        .background(Color(hex: "#FFF2DF").edgesIgnoringSafeArea(.all))
        
    }
    
    var navigationHeader: some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Text("Home")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#635346"))
                    
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search", text: $searchText)
                    
                    Image(systemName: "mic.fill")
                        .foregroundColor(.gray)
                }
                .padding(8)
                .background(Color(hex: "#ECD8BD"))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            // Tab buttons
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    Button(action: {
                        withAnimation {
                            selectedTab = tab
                        }
                    }) {
                        HStack {
                            if tab == "Projects" {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 16))
                            } else {
                                Image(systemName: "chair.fill")
                                    .font(.system(size: 16))
                            }
                            
                            Text(tab)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(hex: "#635346"))
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(selectedTab == tab ? Color(hex: "#635346") : Color(hex: "#635346"))
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(selectedTab == tab ?
                                    Color(hex: "#ECD8BD") : // Updated color
                                    Color.clear)

                        )
                    }
                }
            }
            //.padding(4)
            .background(Color(hex: "#FFF2DF"))
            //.cornerRadius(25)
            .padding(.horizontal)
        }
        .background(Color(hex: "#FFF2DF"))
    }}

struct GeneralView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralView()
    }
}
