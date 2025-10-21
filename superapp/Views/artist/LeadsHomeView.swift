//
//  LeadsHomeView.swift
//  superapp
//
//  Created by Youness Haji on 2025-09-19.
//

import SwiftUI

// MARK: - Main

struct LeadsHomeView: View {
    @State private var items: [Lead] = []
    @State private var handle: UInt?

    @State private var filter: LeadStatus? = .new
    @State private var isBusy = false
    @State private var alertMessage: String?
    @State private var leadToManage: Lead?

    var body: some View {
        VStack(spacing: 0) {
            // Sticky filter bar
            FilterBar(selected: $filter)
                .background(.ultraThinMaterial)
                .overlay(Divider().opacity(0.5), alignment: .bottom)

            if itemsFiltered.isEmpty {
                ContentUnavailableView("No leads",
                                       systemImage: "tray",
                                       description: Text("Try another filter or check back later."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.Colors.surface.gradient.opacity(0.7))
            } else {
                List {
                    ForEach(itemsFiltered) { lead in
                        LeadRowView(
                            lead: lead,
                            onMessage: { Task { await startChat(with: lead) } },
                            onManage:  { leadToManage = lead }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Accept") { Task { try? await LeadsService.shared.setStatus(leadId: lead.id, .accepted) } }
                                .tint(.green)
                            Button("Decline") { Task { try? await LeadsService.shared.setStatus(leadId: lead.id, .declined) } }
                                .tint(.red)
                            Button("Archive") { Task { try? await LeadsService.shared.setStatus(leadId: lead.id, .archived) } }
                                .tint(.gray)
                        }
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { try? await LeadsService.shared.delete(leadId: lead.id) }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(LinearGradient(colors: [Theme.Colors.background, Theme.Colors.surface],
                                           startPoint: .top, endPoint: .bottom))
            }
        }
        .navigationTitle("Leads")
        .overlay {
            if isBusy {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("Opening chat…")
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .alert("Error", isPresented: Binding(get: { alertMessage != nil }, set: { _ in alertMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            handle = LeadsService.shared.streamLeads { items in
                withAnimation(.spring(duration: 0.35)) { self.items = items }
            }
        }
        .onDisappear {
            if let h = handle { LeadsService.shared.stopStreaming(h) }
        }
        .sheet(item: $leadToManage) { lead in
            ManageLeadSheet(lead: lead) {
                leadToManage = nil
            }
        }
    }

    // MARK: - Computed

    private var itemsFiltered: [Lead] {
        guard let f = filter else { return items }
        return items.filter { $0.status == f }
    }

    // MARK: - Actions

    private func startChat(with lead: Lead) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let threadId = try await ChatService.shared.openOrCreateThread(with: lead.clientId)
            // You might navigate here or handle threadId
            print("Opened thread: \(threadId)")
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

// MARK: - Filter Bar

private struct FilterBar: View {
    @Binding var selected: LeadStatus?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", isActive: selected == nil) {
                    selected = nil
                }
                ForEach(LeadStatus.allCases, id: \.self) { status in
                    FilterChip(title: status.rawValue.capitalized, isActive: selected == status) {
                        selected = status
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    struct FilterChip: View {
        let title: String
        let isActive: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(Theme.Fonts.body.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .white : Theme.Colors.textSecondary)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isActive ? Theme.Colors.accent : Color.white.opacity(0.08))
                    )
            }
        }
    }
}

// MARK: - Lead Row

private struct LeadRowView: View {
    let lead: Lead
    let onMessage: () -> Void
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lead.clientName)
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(.white)
                    if let msg = lead.message, !msg.isEmpty {
                        Text(msg)
                            .font(Theme.Fonts.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                StatusBadge(status: lead.status)
            }

            HStack(spacing: 6) {
                if let style = lead.style, !style.isEmpty {
                    IconText(icon: "paintbrush.pointed.fill", text: style)
                }
                if let city = lead.city, !city.isEmpty {
                    IconText(icon: "mappin.circle.fill", text: city)
                }
            }

            if let note = lead.internalNote, !note.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .font(.caption)
                    Text(note)
                        .font(Theme.Fonts.caption)
                }
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.8))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 8) {
                Button {
                    onMessage()
                } label: {
                    Label("Message", systemImage: "message.fill")
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.Colors.accent.gradient, in: Capsule())
                }

                Button {
                    onManage()
                } label: {
                    Label("Manage", systemImage: "slider.horizontal.3")
                        .font(Theme.Fonts.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                }
            }

            Text(relativeDateString(for: Date(timeIntervalSince1970: lead.createdAt)))
                .font(Theme.Fonts.caption2)
                .foregroundStyle(Theme.Colors.textSecondary.opacity(0.7))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Theme.Colors.surface2.opacity(0.6), lineWidth: 0.7)
        )
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .padding(.horizontal, 16).padding(.vertical, 6)
    }

    func relativeDateString(for date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

private struct IconText: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption)
            Text(text).font(Theme.Fonts.caption)
        }
        .foregroundStyle(Theme.Colors.textSecondary)
    }
}

private struct StatusBadge: View {
    let status: LeadStatus
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(Theme.Fonts.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color(for: status), in: Capsule())
    }

    func color(for s: LeadStatus) -> Color {
        switch s {
        case .new: return .blue
        case .accepted: return .green
        case .declined: return .red
        case .archived: return .gray
        }
    }
}
