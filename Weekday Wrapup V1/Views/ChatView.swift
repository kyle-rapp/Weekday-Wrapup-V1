import SwiftUI

/// FILE: Views/ChatView.swift
/// 1:1 direct message thread between the current user and one other person.

struct ChatView: View {
    let conversation: Conversation
    let otherUserName: String

    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var messages: [DirectMessage] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var loading = true
    @FocusState private var isInputFocused: Bool

    private var myId: String? { auth.currentUser?.id }

    var body: some View {
        VStack(spacing: 0) {
            if loading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty {
                ContentUnavailableView(
                    "Say hello 👋",
                    systemImage: "bubble.left",
                    description: Text("Send the first message.")
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                TextField("Message…", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.systemGray6))
                    )

                Button {
                    Task { await sendMessage() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.accentColor))
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .navigationTitle(otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func messageBubble(_ msg: DirectMessage) -> some View {
        let isMe = msg.senderId == myId
        HStack {
            if isMe { Spacer(minLength: 48) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                Text(msg.text)
                    .font(.body)
                    .foregroundStyle(isMe ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isMe ? Color.accentColor : Color(.systemGray5))
                    )
                if let date = msg.createdAt {
                    Text(date.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            if !isMe { Spacer(minLength: 48) }
        }
    }

    private func load() async {
        messages = await firestore.fetchMessages(conversationId: conversation.id)
        await MainActor.run { loading = false }
    }

    private func sendMessage() async {
        guard let me = myId else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        draft = ""
        do {
            try await firestore.sendDirectMessage(conversationId: conversation.id, senderId: me, text: text)
            messages = await firestore.fetchMessages(conversationId: conversation.id)
        } catch {
            AppLogger.error("sendMessage failed: \(error.localizedDescription)")
            draft = text
        }
        sending = false
    }
}
