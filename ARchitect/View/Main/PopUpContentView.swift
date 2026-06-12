//
//  ARPopupView.swift
//  ARchitect
//
//  Created by Ivan Li on 3/31/25.
//

import SwiftUI
struct PopUpContentView: View {
	let categories = [
		"Chairs", "Lights", "Tables", "Sofas"
	]
	let icons = [
		"chair", "cabinet", "lamp.desk", "bed.double",
	]
	let items: [FurnitureItem] = [
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
	@State private var selectedCategory = "Chairs"
	var body: some View {
		VStack {
			// Navigation Bar
			Spacer()
			ScrollView(.horizontal, showsIndicators: false) {
				HStack {
					ForEach(categories, id: \.self) { category in
						Button(action: {
							selectedCategory = category
						}) {
							VStack {
								Image(selectedCategory == category ?  category+"_active" : category+"_inactive")
								Text(category)
									.font(.caption)
									.foregroundColor(.black)
							}
						}
						.padding(.horizontal, 5)
					}
				}
				.padding()
			}
			
			// Grid of Furniture Items
			ScrollView {
				LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
					ForEach(items.filter { $0.category == selectedCategory}) { item in
						FurnitureItemView(item: item)
					}
				}
				.padding(.horizontal)
			}
		}
	}
}

struct FurnitureItemView: View {
	let item: FurnitureItem
	
	var body: some View {
		VStack(alignment: .leading) {
			Image(item.imageName)
				.resizable()
				.scaledToFit()
				.cornerRadius(30)
			
			HStack {
				ForEach(item.tags, id: \.self) { tag in
					Text(tag)
						.font(.caption)
						.padding(5)
						.background(Color.orange.opacity(0.8))
						.foregroundColor(.white)
						.cornerRadius(5)
				}
			}
			
			Text(item.name)
				.font(.headline)
		}
		.padding()
		.background(Color(.systemGray6))
		.cornerRadius(10)
	}
}


struct PopUpContent_Previews: PreviewProvider {
	static var previews: some View {
		PopUpContentView()
	}
}
