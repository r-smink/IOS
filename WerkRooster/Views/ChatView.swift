import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.chatMessages) { message in
                            ChatBubble(message: message, isMe: message.senderId == vm.currentUserId)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
                .onChange(of: vm.chatMessages.count) { _, _ in
                    if let last = vm.chatMessages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            HStack {
                TextField("Typ een bericht...", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let outgoing = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !outgoing.isEmpty else { return }
                    Task { await vm.sendChat(outgoing) }
                    text = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .padding(10)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(8)
            .background(Color(.systemBackground))
        }
        .task { vm.ensureChatConnected() }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let isMe: Bool

    var body: some View {
        VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
            if !isMe {
                Text(message.senderName)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                if message.isAnnouncement == 1 {
                    Label("MEDEDELING", systemImage: "megaphone")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                Text(message.message)
                Text(message.createdAt.chatTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 14))
            .frame(maxWidth: 300, alignment: isMe ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
    }

    private var bubbleColor: Color {
        if message.isAnnouncement == 1 { return .orange.opacity(0.2) }
        return isMe ? .blue.opacity(0.2) : Color(.secondarySystemBackground)
    }
}

private extension String {
    var chatTime: String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = input.date(from: self) {
            let output = DateFormatter()
            output.dateFormat = "HH:mm"
            return output.string(from: date)
        }
        if count >= 5 { return String(suffix(8).prefix(5)) }
        return self
    }
}
