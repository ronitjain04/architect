import SwiftUI

struct ARTriggerView: View {
	
	var body: some View {
		VStack {
			Button("Open Popup") {
				showPopup.toggle()
			}
			.font(.headline)
			.padding()
		}
		.sheet(isPresented: $showPopup) {
			ARPopupView()
		}
	}
	
	@State private var showPopup = false
}

struct ARPopupView: View {
	@Environment(\.presentationMode) var presentationMode
	@State private var offsetY: CGFloat = 0
	var body: some View {
		VStack {
			// Handle for dragging
			RoundedRectangle(cornerRadius: 4)
				.frame(width: 40, height: 6)
				.foregroundColor(.gray.opacity(0.6))
				.padding(.top, 10)
				.gesture(
					DragGesture()
						.onChanged { value in
							if value.translation.height > 0 {
								offsetY = value.translation.height
							}
						}
						.onEnded { value in
							if value.translation.height > 100 {
								presentationMode.wrappedValue.dismiss()
							} else {
								withAnimation {
									offsetY = 0
								}
							}
						}
				)
			PopUpContentView()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.white)
		.cornerRadius(16)
		.offset(y: offsetY)
		.animation(.spring(), value: offsetY)
	}
}

struct ARTriggerView_Previews: PreviewProvider {
	static var previews: some View {
		ARTriggerView()
	}
}
