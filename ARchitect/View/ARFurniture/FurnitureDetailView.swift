import SwiftUI

/// Product page for a furniture item — opened from the Explore grid. Large
/// image, name in the display serif, tag chips, and a primary "View in AR"
/// call to action.
struct FurnitureDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: FurnitureItem
    @State private var showAR = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack(spacing: AppSpacing.md) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.appText)
                    }
                    Text(item.category)
                        .font(AppFont.inter(15, .semibold))
                        .foregroundColor(.appText)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(height: 48)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Image(item.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 340)
                            .containerRelativeFrame(.horizontal)
                            .background(Color.appSurface)

                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text(item.name)
                                .font(AppFont.fraunces(26, .semibold))
                                .foregroundColor(.appText)

                            HStack(spacing: AppSpacing.sm) {
                                ForEach(item.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(AppFont.inter(12, .semibold))
                                        .foregroundColor(.white)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 12)
                                        .background(Capsule().fill(Color.appAccent))
                                }
                            }

                            Text("Preview this piece in your own room with AR to see how it fits before you commit.")
                                .font(AppFont.inter(14, .regular))
                                .foregroundColor(.appTextSecondary)
                        }
                        .padding(AppSpacing.md)
                    }
                }

                // Bottom CTA
                Button {
                    showAR = true
                } label: {
                    Label("View in AR", systemImage: "arkit")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
            }
        }
        .fullScreenCover(isPresented: $showAR) {
            FurnitureTryOutView()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct FurnitureDetailView_Previews: PreviewProvider {
    static var previews: some View {
        FurnitureDetailView(item: FurnitureItem(name: "Grey Couch", tags: ["Modern", "Grey"], imageName: "GreyCouch", category: "Sofas"))
    }
}
