import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let red = CGFloat((int >> 16) & 0xFF) / 255.0
        let green = CGFloat((int >> 8) & 0xFF) / 255.0
        let blue = CGFloat(int & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

struct FurnitureLibraryWrapperView: View {
    @State private var refreshID = UUID()
    @Binding var searchText: String

    var body: some View {
        ZStack {
            
            Color(hex: "#FFF2DF").ignoresSafeArea()
                
            FurnitureLibraryView(searchText: $searchText)
                .id(refreshID) // 🔁 Triggers reinitialization
//            Button {
//                refreshID = UUID() // Changing this causes the view to reset
//                print("reset furniture library")
//            } label: {
//                Image(systemName: "arrow.clockwise")
//            }
//            .padding()
        }
    }
}

struct FurnitureLibraryView: View {
    @Binding var searchText: String //search string
    
    @State private var selectedCategory = "Furniture"
    @State private var selectedFilter = "Chairs"
    
    @State private var selectedItem: FurnitureItem?
    @State private var isDetailedView = false;
    
    @State private var showARPreview = false
    
    @State private var showHeader = true
    @State private var lastScrollOffset: CGFloat = 0

    
    let categories = ["Projects", "Furniture"]
    let filters = [
        ("Sofas", "sofa.fill"),
        ("Lights", "lamp.floor.fill"),
        ("Desks", "table.furniture.fill"),
        ("Chairs", "chair.fill"),
        ("Drawers", "archivebox.fill"),
    ]
    
    let recentItems: [FurnitureItem] = [
        //Couches
        FurnitureItem(name: "Grey Couch", tags: ["Modern", "Grey"], imageName: "GreyCouch", category: "Sofas"),
        FurnitureItem(name: "Chelsey Sofa", tags: ["Grey"], imageName: "ChelseyCouch", category: "Sofas"),
        FurnitureItem(name: "Blue Couch", tags: ["Modern", "Blue"], imageName: "BlueCouch", category: "Sofas"),
        FurnitureItem(name: "Dahlia Couch", tags: ["traditional", "small"], imageName: "DahliaCouch", category: "Sofas"),
        FurnitureItem(name: "Leather Couch", tags: ["Leather", "brown"], imageName: "LeatherCouch", category: "Sofas"),
        FurnitureItem(name: "Folding Couch", tags: ["Folding", "Green"], imageName: "FoldingCouch", category: "Sofas"),
        
        //Lamps
        FurnitureItem(name: "Orange Lamp", tags: ["Orange"], imageName: "Orange Lamp", category: "Lights"),
        FurnitureItem(name: "Office Lamp", tags: ["Office", "Black"], imageName: "Office Lamp", category: "Lights"),
        
        //Tables
        FurnitureItem(name: "Dining Table", tags: ["Dining", "wood"], imageName: "DiningTableWood", category: "Desks"),
        FurnitureItem(name: "Dining Table Glass", tags: ["Dining", "glass"], imageName: "DiningTableGlass", category: "Desks"),
        FurnitureItem(name: "Sci Fi Table", tags: ["Science", "steel"], imageName: "SciFiTable", category: "Desks"),
        FurnitureItem(name: "Simple Dining Table", tags: ["Simple", "White"], imageName: "SimpleDiningTable", category: "Desks"),
        FurnitureItem(name: "Office Table", tags: ["Office", "Wood"], imageName: "OfficeTable", category: "Desks"),
        
        //Chairs
        FurnitureItem(name: "Living Room Chair", tags: ["Wooden", "Warm"], imageName: "Living Room Chair", category: "Chairs"),
        FurnitureItem(name: "European Chair", tags: ["European", "Cream"], imageName: "European Chair", category: "Chairs"),
        FurnitureItem(name: "Dublin Chair", tags: ["Leather", "Black"], imageName: "DublinChair", category: "Chairs"),
        FurnitureItem(name: "Arm Chair", tags: ["Linen", "Grey"], imageName: "armChair", category: "Chairs"),
        FurnitureItem(name: "Blue Chair", tags: ["Office", "Blue"], imageName: "blueChair", category: "Chairs"),
        
        //Drawers
        FurnitureItem(name: "Wooden Drawer", tags: ["Nighstand", "Wooden"], imageName: "Wooden Drawer", category: "Drawers"),
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#FFF2DF").ignoresSafeArea()
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: 0)
                                .background(
                                    GeometryReader { scrollGeo in
                                        Color.clear
                                            .preference(key: ScrollOffsetPreferenceKey.self, value: scrollGeo.frame(in: .global).minY)
                                    }
                                )
                            
                            if showHeader {
                                VStack(spacing: 0) {
                                    // 🟤 "Recent"
                                    Text("Recent")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.bottom, 1)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 30) {
                                            ForEach(recentItems.prefix(3)) { item in
                                                Button {
                                                    showARPreview = true
                                                } label: {
                                                    FurnitureCard(item: item)
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    
                                    // 🟤 Filters
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(filters, id: \.0) { filter in
                                                Button(action: { selectedFilter = filter.0 }) {
                                                    VStack {
                                                        Image(systemName: filter.1)
                                                            .font(.title2)
                                                            .foregroundColor(selectedFilter == filter.0 ? .white : Color(hex: "#3E2A47"))
                                                            .padding()
                                                            .background(selectedFilter == filter.0 ? Color.brown : Color.gray.opacity(0.2))
                                                            .clipShape(Circle())
                                                        
                                                        Text(filter.0)
                                                            .font(.caption)
                                                            .foregroundColor(selectedFilter == filter.0 ? .black : .gray)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .padding()
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            // 🟤 Main Grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                                ForEach(recentItems.filter { $0.category == selectedFilter }) { item in
                                    Button {
                                        showARPreview = true
                                    } label: {
                                        FurnitureCard(item: item)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    .fullScreenCover(isPresented: $showARPreview, content: {
                        FurnitureTryOutView()
                    })
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        let delta = offset - lastScrollOffset
                        if abs(delta) > 5 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showHeader = delta > 0 || offset > -50 // reveal on scroll up or near top
                            }
                        }
                        lastScrollOffset = offset
                    }
                }
            }
        }

    }
       
}

struct FurnitureCard: View {
    let item: FurnitureItem
    
    var body: some View {
        ZStack {
            Image(item.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 173, height: 188)
                .clipped()

            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.clear]),
                startPoint: .bottom,
                endPoint: .center
            )
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    ForEach(item.tags, id: \.self) { tag in
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

                Text(item.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .frame(width: 173, height: 188)
        .background(Color(hex: "#FFF2DF")) // optional if you want card color
        .cornerRadius(12)
        .clipped()
        .shadow(radius: 3)
    }
}

struct BottomNavItem: View {
    let icon: String
    
    var body: some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundColor(.black)
            .padding()
    }
}

struct HomeView_Previews: PreviewProvider {
    @State static var placeHolderSearchText = ""

    static var previews: some View {
        FurnitureLibraryView(searchText: $placeHolderSearchText)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
