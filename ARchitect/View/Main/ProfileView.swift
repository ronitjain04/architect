import SwiftUI

struct ProfileView: View {
    @State private var selectedColumn = 0
    @State private var indicatorPosition: CGFloat = -UIScreen.main.bounds.width / 4
    
    var body: some View {
        VStack {
            // Profile Picture and Username
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 10)
                
                Text("Username:")
                    .font(.title)
                    .foregroundColor(.gray)
                    .padding(.leading, 30)
            }
            .padding(.top, 30)

            // Buttons (General and Projects)
            VStack {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedColumn = 0
                            indicatorPosition = -UIScreen.main.bounds.width / 4
                        }
                    }) {
                        Text("General")
                            .font(.headline)
                            .foregroundColor(selectedColumn == 0 ? .black : .gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedColumn = 1
                            indicatorPosition = UIScreen.main.bounds.width / 4
                        }
                    }) {
                        Text("Projects")
                            .font(.headline)
                            .foregroundColor(selectedColumn == 1 ? .black : .gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
                .frame(height: 50)
                .padding([.top, .horizontal])

                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 30, height: 5)
                        .cornerRadius(2.5)
                        .offset(x: indicatorPosition)
                        .animation(.easeInOut(duration: 0.3), value: indicatorPosition)
                }
                .frame(height: 10)
                .padding([.leading, .trailing])
            }
            Spacer()
            if selectedColumn == 0 {
                GeneralView()
            } else {
                //
            }
        }
    }
}







#Preview {
    ProfileView()
}
