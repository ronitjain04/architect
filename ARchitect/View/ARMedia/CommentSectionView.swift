import SwiftUI

struct CommentSectionView: View {
    @Binding var viewModel: CommentViewModel
    @State private var newCommentText = ""
    
    var body: some View {
        ZStack{
            Color(.sRGB,red: 249/255, green: 237/255, blue: 215/255)
                .edgesIgnoringSafeArea(.all)
            VStack{
                Spacer().frame(height: 5)
                
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 5)
                
                VStack(alignment: .leading, spacing: 8) {
                    Spacer().frame(height: 5)
                    
                    HStack {
                        Spacer()
                        Text("Comments")
                            .font(.title2)
                            .foregroundColor(.black)
                        
                        Spacer()
                    }
                    
                    // List of comments
                    ScrollView(.vertical, showsIndicators: false) {
                        ForEach(viewModel.comments) { comment in
                            HStack(alignment: .top) {
                                
                                Image(systemName: comment.userImage)
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                
                                Spacer().frame(width: 10)
                                // Comment text
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(comment.publisher)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Text(comment.text)
                                        .font(.body)
                                }
                            
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .cornerRadius(12)
                    
                    // Text input for adding new comments
                    HStack (spacing: 20) {
                        TextField("Add a comment...", text: $newCommentText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(height: 50) // Increased height from 40 to 50
                            .background(Color(.sRGB,red: 229/255, green: 207/255, blue: 185/255)) // Light gray background
                            .cornerRadius(25) // Increased radius for a more rounded look
                            .foregroundColor(.black)
                        
                        Button(action: {
                            if !newCommentText.isEmpty {
                                viewModel.addComment(text: newCommentText, publisher: "User123")
                                newCommentText = ""
                            }
                        }) {
                            Image(systemName: "paperplane.fill")
                                .resizable()
                                .foregroundColor(.gray)
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 40)
                        }
                    }
                    .padding()
                }
                .padding(.top)
                .presentationDetents([.medium, .large])
            }
            
            .padding(.horizontal,20)
        }
        .presentationDetents([.fraction(0.8)])
        .foregroundColor(.black)
    }
}

#Preview {
    @Previewable @State var commentViewModel = CommentViewModel()
    
    CommentSectionView(viewModel: $commentViewModel)
}
