import SwiftUI

struct HomeDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @State private var lockScreenMessage = ""
    @State private var isDrawing = false
    
    var daysTogether: Int {
        guard let date = state.currentUser?.anniversaryDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // HERO: Days Together
                    BubblyCard {
                        VStack(spacing: 8) {
                            Text("We've been together for")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(daysTogether)")
                                    .font(.system(size: 64, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                Text("days")
                                    .font(.title2.weight(.bold).design(.rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    // ACTION: Draw Note
                    Button {
                        isDrawing = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Draw a Note")
                                    .font(.title3.weight(.bold).design(.rounded))
                                Text("Send to their Home Screen")
                                    .font(.subheadline)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.title)
                        }
                        .padding(24)
                        .foregroundStyle(.white)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                    .buttonStyle(BubblyButtonStyle())
                    
                    // ACTION: Lock Screen Message
                    BubblyCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Lock Screen Message", systemImage: "lock.iphone")
                                .font(.headline.design(.rounded))
                            
                            HStack {
                                TextField("Thinking of you...", text: $lockScreenMessage)
                                    .padding(14)
                                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                
                                Button {
                                    Task {
                                        try? await SupabaseManager.shared.sendLockScreenMessage(lockScreenMessage)
                                        lockScreenMessage = ""
                                    }
                                } label: {
                                    Image(systemName: "paperplane.fill")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .padding(14)
                                        .background(lockScreenMessage.isEmpty ? Color.gray.opacity(0.3) : Color.pink)
                                        .clipShape(Circle())
                                }
                                .disabled(lockScreenMessage.isEmpty)
                                .animation(.spring(), value: lockScreenMessage.isEmpty)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Us")
            .fullScreenCover(isPresented: $isDrawing) {
                DrawingView()
            }
        }
    }
}
