import SwiftUI
import QuickLook

struct FurnitureDetailView: View {
    let item: FurnitureItem

    var body: some View {
        NavigationView {
            VStack {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250, height: 250)

                HStack {
                    ForEach(item.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.headline)
                            .padding(6)
                            .background(Color.orange.opacity(0.8))
                            .cornerRadius(5)
                    }
                }
                .padding(.top, 8)

                Spacer()

                Text(item.name)
                    .font(.largeTitle)
                    .bold()
                    .padding()
            }
            .padding()
            .navigationTitle("Furniture Details")
        }
        .background(Color(hex: "#FFF2DF"))
        .edgesIgnoringSafeArea(.all)
    }
}

struct FurnitureDetailView_Previews: PreviewProvider {
    static var previews: some View {
        FurnitureDetailView(item: FurnitureItem(name: "Grey Couch", tags: ["Modern", "Grey"], imageName: "GreyCouch", category: "Sofas"))
    }
}
