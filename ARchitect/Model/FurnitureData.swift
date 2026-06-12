import Foundation

enum FurnitureData {
    static let allItems: [FurnitureItem] = [
        // Sofas
        FurnitureItem(name: "Grey Couch",     tags: ["Modern", "Grey"],           imageName: "GreyCouch",       category: "Sofas"),
        FurnitureItem(name: "Chelsey Sofa",   tags: ["Grey"],                     imageName: "ChelseyCouch",    category: "Sofas"),
        FurnitureItem(name: "Blue Couch",     tags: ["Modern", "Blue"],           imageName: "BlueCouch",       category: "Sofas"),
        FurnitureItem(name: "Dahlia Couch",   tags: ["Traditional", "Small"],     imageName: "DahliaCouch",     category: "Sofas"),
        FurnitureItem(name: "Leather Couch",  tags: ["Leather", "Brown"],         imageName: "LeatherCouch",    category: "Sofas"),
        FurnitureItem(name: "Folding Couch",  tags: ["Folding", "Green"],         imageName: "FoldingCouch",    category: "Sofas"),

        // Lights
        FurnitureItem(name: "Orange Lamp",    tags: ["Orange"],                   imageName: "Orange Lamp",     category: "Lights"),
        FurnitureItem(name: "Office Lamp",    tags: ["Office", "Black"],          imageName: "Office Lamp",     category: "Lights"),

        // Desks / Tables
        FurnitureItem(name: "Dining Table",        tags: ["Dining", "Wood"],     imageName: "DiningTableWood", category: "Desks"),
        FurnitureItem(name: "Dining Table Glass",  tags: ["Dining", "Glass"],    imageName: "DiningTableGlass",category: "Desks"),
        FurnitureItem(name: "Sci-Fi Table",        tags: ["Science", "Steel"],   imageName: "SciFiTable",      category: "Desks"),
        FurnitureItem(name: "Simple Dining Table", tags: ["Simple", "White"],    imageName: "SimpleDiningTable",category: "Desks"),
        FurnitureItem(name: "Office Table",        tags: ["Office", "Wood"],     imageName: "OfficeTable",     category: "Desks"),

        // Chairs
        FurnitureItem(name: "Living Room Chair", tags: ["Wooden", "Warm"],       imageName: "Living Room Chair", category: "Chairs"),
        FurnitureItem(name: "European Chair",    tags: ["European", "Cream"],    imageName: "European Chair",    category: "Chairs"),
        FurnitureItem(name: "Dublin Chair",      tags: ["Leather", "Black"],     imageName: "DublinChair",       category: "Chairs"),
        FurnitureItem(name: "Arm Chair",         tags: ["Linen", "Grey"],        imageName: "armChair",          category: "Chairs"),
        FurnitureItem(name: "Blue Chair",        tags: ["Office", "Blue"],       imageName: "blueChair",         category: "Chairs"),

        // Drawers
        FurnitureItem(name: "Wooden Drawer", tags: ["Nightstand", "Wooden"],     imageName: "Wooden Drawer",   category: "Drawers"),
    ]
}
