import SwiftUI

private let feedBackground = Color(red: 0.99, green: 0.97, blue: 0.94)
private let feedCardShadow = Color.brown.opacity(0.12)

// MARK: - Feed list (no nested NavigationStack — uses ContentView’s stack)

struct FeedView: View {
    @ObservedObject private var store = FeedPostsStore.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(store.posts) { post in
                    NavigationLink {
                        FeedPostDetailView(post: store.binding(for: post.id))
                    } label: {
                        FeedPostCard(post: store.binding(for: post.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(feedBackground.ignoresSafeArea())
        .navigationTitle("Feed")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }
}

// MARK: - Card (list row)

struct FeedPostCard: View {
    @Binding var post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.orange.opacity(0.85))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(post.user.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                        Button {
                            post.user.isFollowing.toggle()
                        } label: {
                            Text(post.user.isFollowing ? "Following" : "Follow")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(post.user.isFollowing ? Color.green.opacity(0.15) : Color.blue.opacity(0.12))
                                .foregroundColor(post.user.isFollowing ? .green : .blue)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.borderless)
                    }
                    Text("🔥 \(post.user.streak) week streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text(post.visibility.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary.opacity(0.9))
                }
            }

            HStack {
                Text(post.emoji)
                    .font(.largeTitle)
                Text("Week wrapup")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(post.insight)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if !post.whoop.isEmpty {
                Text("Whoops: \(post.whoop)")
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.9))
            }
            if !post.goal.isEmpty {
                Text("Goal: \(post.goal)")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.9))
            }

            reactionRow

            HStack(spacing: 20) {
                Button {
                    if post.isLiked {
                        post.likeCount = max(0, post.likeCount - 1)
                    } else {
                        post.likeCount += 1
                    }
                    post.isLiked.toggle()
                } label: {
                    Label("\(post.likeCount)", systemImage: post.isLiked ? "heart.fill" : "heart")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(post.isLiked ? .pink : .secondary)
                }
                .buttonStyle(.borderless)
                .scaleEffect(post.isLiked ? 1.15 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: post.isLiked)

                Label("\(post.comments.count)", systemImage: "bubble.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: feedCardShadow, radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.orange.opacity(0.08), lineWidth: 1)
        )
    }

    private var reactionRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(post.reactions.keys.sorted()), id: \.self) { key in
                Button {
                    var r = post.reactions
                    r[key, default: 0] += 1
                    post.reactions = r
                } label: {
                    Text("\(key) \(post.reactions[key, default: 0])")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

// MARK: - Detail

struct FeedPostDetailView: View {
    @Binding var post: FeedPost
    @State private var newComment = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.orange.opacity(0.85))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.user.name)
                            .font(.title2.bold())
                        Text("🔥 \(post.user.streak) week streak")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                            Text(post.visibility.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        post.user.isFollowing.toggle()
                    } label: {
                        Text(post.user.isFollowing ? "Following" : "Follow")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(post.user.isFollowing ? Color.green.opacity(0.18) : Color.blue.opacity(0.15))
                            .foregroundColor(post.user.isFollowing ? .green : .blue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                }

                Text(post.emoji)
                    .font(.system(size: 48))

                Text(post.insight)
                    .font(.body)

                if !post.whoop.isEmpty {
                    Text("Whoops: \(post.whoop)")
                        .foregroundColor(.orange)
                }
                if !post.goal.isEmpty {
                    Text("Weekly goal: \(post.goal)")
                        .foregroundColor(.blue)
                }

                reactionRowDetail

                HStack(spacing: 16) {
                    Button {
                        if post.isLiked {
                            post.likeCount = max(0, post.likeCount - 1)
                        } else {
                            post.likeCount += 1
                        }
                        post.isLiked.toggle()
                    } label: {
                        Label("\(post.likeCount) Like\(post.likeCount == 1 ? "" : "s")", systemImage: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .pink : .primary)
                    }
                    .buttonStyle(.borderless)
                    .scaleEffect(post.isLiked ? 1.2 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: post.isLiked)
                }

                Divider()
                    .padding(.vertical, 4)

                Text("Comments")
                    .font(.headline)

                if post.comments.isEmpty {
                    Text("No comments yet—be the first to say something kind.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(post.comments.enumerated()), id: \.offset) { _, text in
                        Text(text)
                            .font(.subheadline)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.08)))
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Add a comment...", text: $newComment, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    Button("Post") {
                        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        post.comments.append(trimmed)
                        newComment = ""
                    }
                    .font(.body.weight(.semibold))
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(feedBackground.ignoresSafeArea())
        .navigationTitle("Wrapup Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var reactionRowDetail: some View {
        HStack(spacing: 12) {
            ForEach(Array(post.reactions.keys.sorted()), id: \.self) { key in
                Button {
                    var r = post.reactions
                    r[key, default: 0] += 1
                    post.reactions = r
                } label: {
                    Text("\(key) \(post.reactions[key, default: 0])")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
