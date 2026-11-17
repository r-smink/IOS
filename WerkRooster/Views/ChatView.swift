import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(vm.chatMessages.enumerated()), id: \.element.id) { index, message in
                            let day = message.createdAt.chatDay
                            let previousDay = index > 0 ? vm.chatMessages[index - 1].createdAt.chatDay : nil
                            if let day, day != previousDay {
                                ChatDateHeader(label: day.chatDayLabel)
                            }
                            ChatBubble(message: message, isMe: message.senderId == vm.currentUserId)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                }
                .onChange(of: vm.chatMessages.count) { _ in
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    vm.reloadChat()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Vernieuwen")
            }
        }
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

private struct ChatDateHeader: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.tertiarySystemFill), in: Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}

private extension Date {
    /// "Vandaag", "Gisteren", "ma 16 nov" (dit jaar) of "ma 16 nov 2025" (ander jaar).
    var chatDayLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Vandaag" }
        if calendar.isDateInYesterday(self) { return "Gisteren" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nl_NL")
        let sameYear = calendar.component(.year, from: self) == calendar.component(.year, from: Date())
        formatter.dateFormat = sameYear ? "EEE d MMM" : "EEE d MMM yyyy"
        return formatter.string(from: self).replacingOccurrences(of: ".", with: "")
    }
}

private extension String {
    /// Begin van de dag van een WP-tijdstempel (yyyy-MM-dd ...), of nil als die niet te lezen is.
    var chatDay: Date? {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: String(prefix(10))) else { return nil }
        return Calendar.current.startOfDay(for: date)
    }

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
