//
//  ArtistsGalleryView.swift
//  InkMatching
//
//  Created by Youness on 2025-09-18.
//

import SwiftUI
import CoreLocation

// MARK: - Helpers

private enum SortOption: String, CaseIterable {
    case ratingDesc = "Top rated"
    case nameAsc    = "Name A–Z"
    case cityAsc    = "City A–Z"
}

private let ratingChoices: [Double] = [0.0, 4.0, 4.5, 4.8]

private func parsedStyles(from raw: String?) -> [String] {
    guard let s = raw, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
    let seps = CharacterSet(charactersIn: ",/•|;")
    return s.components(separatedBy: seps)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

// MARK: - View

struct ArtistsGalleryView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var chatVM: ChatViewModel

    // Data
    @State private var artists: [PublicArtist] = []
    @State private var isLoading = false
    @State private var errorText: String?

    // Auth gate
    @State private var pendingArtistUID: String?
    @State private var showLoginSheet = false

    // Filters / Search
    @State private var searchText: String = ""
    @State private var selectedCity: String = "All"
    @State private var selectedStyle: String = "All"
    @State private var minRating: Double = 0.0
    @State private var sort: SortOption = .ratingDesc
    @State private var showFilters: Bool = true

    // Near me
    @State private var nearMe: Bool = false
    @State private var radiusKm: Double = 25
    @State private var userLocation: CLLocation?
    @State private var userCity: String?
    @State private var locating: Bool = false
    @State private var geocodeError: String?

    // Derived options
    private var allCities: [String] {
        let set = Set(artists.compactMap { $0.city?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return ["All"] + set.sorted()
    }

    private var allStyles: [String] {
        let flat = artists.flatMap { parsedStyles(from: $0.styles) }
        let set = Set(flat)
        return ["All"] + set.sorted()
    }

    // Filtered data
    private var filtered: [PublicArtist] {
        var list = artists

        // search
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter { a in
                a.displayName.lowercased().contains(q)
                || (a.city?.lowercased().contains(q) ?? false)
                || (a.styles?.lowercased().contains(q) ?? false)
            }
        }

        // city
        if selectedCity != "All" {
            list = list.filter { $0.city == selectedCity }
        }

        // style
        if selectedStyle != "All" {
            list = list.filter { parsedStyles(from: $0.styles).contains(selectedStyle) }
        }

        // rating
        if minRating > 0 {
            list = list.filter { ($0.rating ?? 0) >= minRating }
        }

        // near me
        if nearMe {
            if let me = userLocation {
                list = list.filter { a in
                    if let c = a.coordinate {
                        let d = CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: me)
                        return d <= radiusKm * 1000.0
                    } else if let city = a.city, let myCity = userCity, !myCity.isEmpty {
                        return city.caseInsensitiveCompare(myCity) == .orderedSame
                    } else {
                        return false
                    }
                }
            } else if let myCity = userCity, !myCity.isEmpty {
                list = list.filter { ($0.city ?? "").caseInsensitiveCompare(myCity) == .orderedSame }
            }
        }

        // sort
        switch sort {
        case .ratingDesc:
            list.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .nameAsc:
            list.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .cityAsc:
            list.sort { ($0.city ?? "").localizedCaseInsensitiveCompare($1.city ?? "") == .orderedAscending }
        }

        return list
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search + filters
                filtersBar

                Divider().opacity(0.6)

                Group {
                    if isLoading {
                        ProgressView().padding(.top, 32)
                    } else if let err = errorText {
                        VStack(spacing: 12) {
                            Text("Failed to load artists").font(Theme.Fonts.headline)
                            Text(err).font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                            Button("Retry") { Task { await load() } }.buttonStyle(SecondaryButtonStyle())
                        }
                        .padding()
                    } else {
                        content
                    }
                }
            }
            .task { await load() }
            .sheet(isPresented: $showLoginSheet) {
                NavigationStack {
                    LoginView()
                        .environmentObject(authVM)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showLoginSheet = false } } }
                }
                .presentationDetents([.large])
            }
            .onChange(of: authVM.me != nil) { _, isAuth in
                guard isAuth, let target = pendingArtistUID else { return }
                Task {
                    await startChat(with: target)
                    pendingArtistUID = nil
                    showLoginSheet = false
                }
            }
        }
        // pas de NavigationLink caché ici : on route via NotificationCenter
    }

    // MARK: - UI Sections

    private var filtersBar: some View {
        VStack(spacing: 10) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField("Search artists, styles, cities", text: $searchText)
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal)

            // Toggle filters visibility
            HStack {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { showFilters.toggle() }
                } label: {
                    Label("Filters", systemImage: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(TertiaryButtonStyle())

                Spacer()

                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(SortOption.allCases, id: \.self) { s in Text(s.rawValue).tag(s) }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                }
                .buttonStyle(TertiaryButtonStyle())
            }
            .padding(.horizontal)

            if showFilters {
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        // City
                        Menu {
                            Picker("City", selection: $selectedCity) {
                                ForEach(allCities, id: \.self) { city in Text(city).tag(city) }
                            }
                        } label: { Chip(text: selectedCity == "All" ? "All cities" : selectedCity, systemImage: "mappin.circle") }

                        // Style
                        Menu {
                            Picker("Style", selection: $selectedStyle) {
                                ForEach(allStyles, id: \.self) { st in Text(st).tag(st) }
                            }
                        } label: { Chip(text: selectedStyle == "All" ? "All styles" : selectedStyle, systemImage: "paintbrush.pointed") }

                        // Rating
                        Menu {
                            Picker("Minimum rating", selection: $minRating) {
                                ForEach(ratingChoices, id: \.self) { r in Text(r == 0 ? "Any rating" : "≥ \(String(format: "%.1f", r))").tag(r) }
                            }
                        } label: { Chip(text: minRating == 0 ? "Any rating" : "≥ \(String(format: "%.1f", minRating))", systemImage: "star.fill") }
                    }

                    // Near me row
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle(isOn: $nearMe) {
                                Label("Near me", systemImage: "location.circle")
                            }
                            .onChange(of: nearMe) { _, on in
                                if on && userLocation == nil && !locating {
                                    Task { await requestLocationAndCity() }
                                }
                            }

                            if locating { ProgressView().scaleEffect(0.8).padding(.leading, 6) }

                            if let myCity = userCity, !myCity.isEmpty {
                                Text("• \(myCity)").font(Theme.Fonts.caption).foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }

                        if nearMe {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Radius: \(Int(radiusKm)) km")
                                        .font(Theme.Fonts.caption)
                                        .foregroundStyle(Theme.Colors.textSecondary)
                                    Spacer()
                                    Button("Use my location") {
                                        Task { await requestLocationAndCity(force: true) }
                                    }
                                    .buttonStyle(TertiaryButtonStyle())
                                }
                                Slider(value: $radiusKm, in: 5...100, step: 5)
                            }
                        }

                        if let geocodeError {
                            Text(geocodeError)
                                .font(Theme.Fonts.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 10)
        .background(Theme.Colors.background)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            if #available(iOS 17.0, *) {
                ContentUnavailableView("No artists match your filters",
                                       systemImage: "person.2.slash",
                                       description: Text("Try clearing filters or searching a different style."))
                    .padding(.top, 40)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.slash").font(.largeTitle)
                    Text("No artists match your filters").font(Theme.Fonts.headline)
                    Text("Try clearing filters or searching a different style.")
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .padding(.top, 40)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(filtered) { artist in
                        ArtistCard(artist: artist) {
                            Task { await onSelect(artist: artist) }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        errorText = nil
        do {
            let data = try await PublicProfilesService.shared.fetchArtistsOnce(limit: 200)
            await MainActor.run { artists = data }
        } catch {
            await MainActor.run { errorText = error.localizedDescription }
        }
        isLoading = false
    }

    private func onSelect(artist: PublicArtist) async {
        guard let _ = authVM.me else {
            pendingArtistUID = artist.id
            showLoginSheet = true
            return
        }
        await startChat(with: artist.id)
    }

    private func startChat(with artistUID: String) async {
        do {
            let tid = try await chatVM.openOrCreateThread(with: artistUID)
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .openThread,
                    object: nil,
                    userInfo: ["threadId": tid]
                )
            }
        } catch {
            await MainActor.run { errorText = "Could not start chat. \(error.localizedDescription)" }
        }
    }

    private func requestLocationAndCity(force: Bool = false) async {
        if locating { return }
        locating = true
        geocodeError = nil
        do {
            let loc = try await LocationService.shared.requestOneShotLocation()
            await MainActor.run { userLocation = loc }
            if force || userCity == nil {
                let gc = CLGeocoder()
                let placemarks = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CLPlacemark], Error>) in
                    gc.reverseGeocodeLocation(loc) { p, e in
                        if let e = e { cont.resume(throwing: e); return }
                        cont.resume(returning: p ?? [])
                    }
                }
                let locality = placemarks.first?.locality
                await MainActor.run { userCity = locality }
            }
        } catch {
            await MainActor.run { geocodeError = "Location unavailable. Check permissions in Settings." }
        }
        locating = false
    }
}

// MARK: - Reusable UI bits

private struct ArtistCard: View {
    let artist: PublicArtist
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {

                // ---- COVER: fixed height, fills & clips (no overflow) ----
                GeometryReader { geo in
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Theme.Colors.surface)

                        if let url = artist.coverURL, let u = URL(string: url) {
                            AsyncImage(url: u) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geo.size.width, height: 150)
                                        .clipped()
                                case .failure:
                                    Image(systemName: "photo").font(.largeTitle)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: geo.size.width, height: 150)
                            .clipped()
                        } else {
                            Image(systemName: "photo").font(.largeTitle)
                        }
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // ----------------------------------------------------------

                Text(artist.displayName)
                    .font(Theme.Fonts.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let city = artist.city, !city.isEmpty {
                        Label(city, systemImage: "mappin.and.ellipse")
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    if let r = artist.rating {
                        Text(String(format: "★ %.1f", r))
                            .font(Theme.Fonts.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                if let styles = artist.styles, !styles.isEmpty {
                    Text(styles)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.Colors.stroke.opacity(0.6), lineWidth: Theme.Layout.strokeWidth)
            )
        }
        .buttonStyle(.plain)
    }
}

