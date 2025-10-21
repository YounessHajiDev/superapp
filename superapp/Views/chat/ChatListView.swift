//
//  ChatListView.swift
//  InkMatching
//
//  Created by Youness on 2025-09-08.
//  Updated: 2025-10-21 - Artist restrictions (receive-only mode)
//

import SwiftUI

struct ChatListView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var chatVM: ChatViewModel

    // UI state
    @State private var searchText: String = ""
    @State private var showNewChatSheet: Bool = false
    @State private var otherUID: String = ""
    @State private var isCreating: Bool = false

    // Navigation 
    @State private var navigateToNewThread: Bool = false
    @State private var newThreadId: String? = nil
    
    // MARK: - Artist Check
    private var isArtist: Bool {
        authVM.me?.role == .artist
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content

            // Floating "new chat" button - HIDDEN for artists
            if !isArtist {
                Button {
                    otherUID = ""
                    showNewChatSheet = true
                } label: {
                    Image(systemName: "plus.bubble.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Theme.Colors.accent.gradient, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 30)
            }

            // Hidden link to push new thread
            NavigationLink(isActive: $navigateToNewThread) {
                ChatRoomView(threadId: newThreadId ?? "")
            } label: { EmptyView() }
            .hidden()
        }
        .navigationTitle(isArtist 
            ? NSLocalizedString("Client Messages", comment: "")
            : NSLocalizedString("Chat", comment: ""))
        .toolbar {
            // "New chat" toolbar button - HIDDEN for artists
            if !isArtist {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        otherUID = ""
                        showNewChatSheet = true
                    } label: {
                        Label(NSLocalizedString("New chat", comment: ""), systemImage: "plus.bubble.fill")
                    }
                }
            }
            
            // Artists see "Leads inbox" button instead
            if isArtist {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: Text("Leads")) { // Replace with your LeadsHomeView
                        Label("Leads", systemImage: "tray.fill")
                    }
                }
            }
        }
        .searchable(text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: Text(NSLocalizedString("Search chats", comment: "")))
        .sheet(isPresented: $showNewChatSheet) {
            NewChatSheet(
                otherUID: $otherUID,
                isCreating: $isCreating,
                onCreate: { Task { await createThread() } }
            )
        }
        .onAppear {
            if chatVM.inbox.isEmpty { chatVM.startInbox() }
        }
    }

    // MARK: - Content

    private var content: some View {
        Group {
            if chatVM.isLoadingInbox && chatVM.inbox.isEmpty {
                ProgressView().padding()
            } else if filteredInbox.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 42))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text(NSLocalizedString("No conversations", comment: ""))
                        .font(Theme.Fonts.headline)
                    
                    // Different empty state messages for artists vs clients
                    Text(isArtist 
                        ? NSLocalizedString("When clients message you through the platform, their conversations will appear here.", comment: "")
                        : NSLocalizedString("Start a chat from an artist profile or a request.", comment: ""))
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // "Start new chat" button - HIDDEN for artists
                    if !isArtist {
                        Button {
                            otherUID = ""
                            showNewChatSheet = true
                        } label: {
                            Text(NSLocalizedString("Start a new chat", comment: ""))
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredInbox) { item in
                            NavigationLink {
                                ChatRoomView(threadId: item.id)
                            } label: {
                                ThreadCard(item: item, myUID: authVM.me?.uid)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                        Spacer(minLength: 12)
                    }
                    .padding(.top, 10)
                }
            }
        }
        .background(InkBackground())
    }

    // MARK: - Filter

    private var filteredInbox: [UserThreadIndex] {
        let uid = authVM.me?.uid
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return chatVM.inbox }
        return chatVM.inbox.filter { item in
            let other = item.otherMember(for: uid).lowercased()
            let last = (item.lastMessage ?? "").lowercased()
            return other.contains(q) || last.contains(q) || item.id.lowercased().contains(q)
        }
    }

    // MARK: - Create thread

    private func createThread() async {
        let target = otherUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        isCreating = true
        do {
            let tid = try await chatVM.openOrCreateThread(with: target)
            newThreadId = tid
            showNewChatSheet = false
            navigateToNewThread = true
        } catch {
            // Option: show alert
        }
        isCreating = false
    }
}

// MARK: - NewChatSheet (list of clients from leads)

private struct NewChatSheet: View {
    @Binding var otherUID: String
    @Binding var isCreating: Bool
    var onCreate: () -> Void

    @State private var leadClients: [LeadClient] = []
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Start a new chat").font(Theme.Fonts.title3)

                Text("Pick a client from your leads, or enter a user ID.")
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                // Manual entry
                TextField("Other user's UID", text: $otherUID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(ModernTextFieldStyle())

                // List of lead clients
                Group {
                    if isLoading {
                        HStack { ProgressView(); Text("Loading…") }
                    } else if let e = loadError {
                        Text(e).foregroundStyle(.red)
                    } else if leadClients.isEmpty {
                        Text("No clients from leads yet.")
                            .foregroundStyle(Theme.Colors.textSecondary)
                    } else {
                        List(leadClients) { c in
                            Button {
                                otherUID = c.id
                            } label: {
                                HStack {
                                    AvatarView(initials: initials(from: c.name), urlString: nil, size: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.name).font(Theme.Fonts.headline)
                                        if let last = c.lastMessage, !last.isEmpty {
                                            Text(last)
                                                .font(Theme.Fonts.caption)
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    Text(c.status.rawValue.capitalized)
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                }
                            }
                        }
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                Spacer()

                Button(action: onCreate) {
                    if isCreating {
                        HStack {
                            ProgressView()
                            Text("Creating…")
                        }
                    } else {
                        Text("Create chat")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(otherUID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
            }
            .padding()
            .navigationTitle("New chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                do {
                    leadClients = try await LeadsService.shared.fetchLeadClients(statuses: [.new, .accepted])
                } catch { loadError = error.localizedDescription }
                isLoading = false
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    private func initials(from name: String) -> String {
        let letters = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let up = String(String.UnicodeScalarView(letters)).uppercased()
        return String(up.prefix(2)).isEmpty ? "?" : String(up.prefix(2))
    }
}

// MARK: - Thread Card

private struct ThreadCard: View {
    let item: UserThreadIndex
    let myUID: String?

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initials: initials(from: otherUID), urlString: nil, size: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(titleText)
                        .font(Theme.Fonts.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(relativeDateString(for: item.lastUpdatedDate))
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Text(previewText)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.8))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.Colors.surface2.opacity(0.7), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private var otherUID: String { item.otherMember(for: myUID) }

    private var titleText: String {
        // If you have displayName later, replace here
        otherUID
    }

    private var previewText: String {
        if let last = item.lastMessage, !last.isEmpty { return last }
        return "—"
    }

    private func initials(from uid: String) -> String {
        let letters = uid.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let up = String(String.UnicodeScalarView(letters)).uppercased()
        let ini = String(up.prefix(2))
        return ini.isEmpty ? "?" : ini
    }

    private func relativeDateString(for date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
