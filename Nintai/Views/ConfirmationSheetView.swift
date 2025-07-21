import SwiftUI

struct ConfirmationSheetView: View {
    let title: String
    let message: String
    let confirmButtonTitle: String
    let cancelButtonTitle: String
    let confirmAction: () -> Void
    let cancelAction: () -> Void

    @Namespace var namespace

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture(perform: cancelAction)
                    .transition(.opacity)
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            withAnimation {
                                confirmAction()
                            }
                        }) {
                            Text(confirmButtonTitle)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white)
                                .cornerRadius(14)
                        }
                        
                        Button(action: {
                            withAnimation {
                                cancelAction()
                            }
                        }) {
                            Text(cancelButtonTitle)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.clear)
                                .foregroundColor(.red)
                                .cornerRadius(14)
                        }
                    }
                    .padding(24)
                    .padding(.bottom, max(20, geometry.safeAreaInsets.bottom))
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(red: 0.1, green: 0.1, blue: 0.1))
                    )
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ConfirmationSheetView(
        title: "Are you sure?",
        message: "This action cannot be undone.",
        confirmButtonTitle: "Confirm",
        cancelButtonTitle: "Cancel",
        confirmAction: {},
        cancelAction: {}
    )
} 