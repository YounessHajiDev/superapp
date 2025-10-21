# iOS App Alignment with Web Application

**Date**: October 21, 2025  
**Status**: Core Models Updated ✅ | Chat Restrictions Added ✅ | Services Need Updates ⏳

## 🎯 Overview

This document tracks the alignment between the **InkMatching iOS app** (Swift/SwiftUI) and the **inkmatching-web** (Next.js/TypeScript) to ensure feature parity and consistent user experience across platforms.

---

## ✅ Completed Updates

### 1. **PublicArtist Model** - Address Field Added
**File**: `superapp/Models/PublicArtist.swift`

**Changes**:
- ✅ Added `address: String?` property for full street address
- ✅ Added `fullLocation` computed property that prioritizes address over city for geocoding
- ✅ Maintains backward compatibility with existing city-only profiles

**Why**: The web app added this field to improve map marker accuracy. Without full addresses, geocoding to city centers causes clustering issues.

**Example**:
```swift
struct PublicArtist {
    let address: String?        // NEW
    
    var fullLocation: String? {
        if let address = address, !address.isEmpty {
            if let city = city, !city.isEmpty {
                return "\(address), \(city)"  // Best precision
            }
            return address
        }
        return city  // Fallback
    }
}
```

---

### 2. **Lead Model** - Aftercare Integration
**File**: `superapp/Models/Lead.swift`

**Changes**:
- ✅ Added `aftercareId: String?` property to link leads with aftercare plans

**Why**: Web app allows artists to create aftercare plans when accepting leads. This field links the two entities.

**Database Path**: 
- Lead: `/leadsByArtist/{artistUid}/{leadId}`
- Aftercare: `/aftercareByClient/{clientUid}/{aftercareId}`

---

### 3. **Aftercare Models** - Complete Redesign
**File**: `superapp/Models/AftercareModels.swift`

**Changes**:
- ✅ Added `AftercareStatus` enum: `.active`, `.completed`, `.archived`
- ✅ Added `AftercareInstruction` struct with completion tracking
- ✅ Added `Aftercare` struct (main model) matching web app structure
- ✅ Added progress computation: `progress`, `progressPercentage`, `isComplete`
- ✅ Kept legacy models (`AftercarePlan`, `AftercareStep`) for backward compatibility

**New Structure**:
```swift
struct Aftercare {
    var id: String
    var artistUid: String
    var artistName: String
    var clientUid: String
    var clientName: String
    var tattooDescription: String?
    var instructions: [AftercareInstruction]
    var status: AftercareStatus
    var createdAt: TimeInterval
    var updatedAt: TimeInterval
    var completedDays: [String: TimeInterval]?
    
    var progress: Double  // 0.0 to 1.0
    var progressPercentage: Int  // 0 to 100
    var isComplete: Bool
}

struct AftercareInstruction {
    var id: String
    var day: Int
    var instruction: String
    var completed: Bool = false
}
```

---

### 4. **ChatListView** - Artist Restrictions
**File**: `superapp/Views/chat/ChatListView.swift`

**Changes**:
- ✅ Added `isArtist` computed property checking `authVM.me?.role == .artist`
- ✅ **Hid "New Chat" floating button** for artists
- ✅ **Hid "New Chat" toolbar button** for artists
- ✅ **Hid "Start a new chat" empty state button** for artists
- ✅ Changed navigation title: "Client Messages" for artists, "Chat" for clients
- ✅ Changed empty state message for artists: "When clients message you through the platform..."
- ✅ Added "Leads inbox" toolbar button for artists (replace destination with actual `LeadsHomeView`)

**Why**: Business logic requires clients to initiate contact through the lead system. Artists should only respond, not spam potential clients.

**Matches Web**: `app/chat/page.tsx` - same restrictions applied

---

## ⏳ Pending Updates (Next Steps)

### 5. **PublicProfilesService** - Address Field Support
**File**: `superapp/Services/PublicProfilesService.swift`

**TODO**:
- [ ] Update `saveProfile()` to include `address` field in Firebase write
- [ ] Update profile parsing to read `address` from database
- [ ] Update geocoding logic to use `fullLocation` instead of just `city`

**Example**:
```swift
func saveProfile(_ profile: PublicArtist) async throws {
    var data: [String: Any] = [
        "displayName": profile.displayName,
        "city": profile.city ?? "",
        "address": profile.address ?? "",  // ADD THIS
        "styles": profile.styles ?? "",
        // ... rest of fields
    ]
    // Geocode using profile.fullLocation
    if let location = profile.fullLocation {
        let coords = try await geocode(location)
        data["latitude"] = coords.latitude
        data["longitude"] = coords.longitude
    }
}
```

---

### 6. **LeadsService** - Aftercare Integration
**File**: `superapp/Services/LeadsService.swift`

**TODO**:
- [ ] Update `updateLeadStatus()` to accept optional `aftercareId` parameter
- [ ] Write `aftercareId` to Firebase when provided
- [ ] Create helper function `linkAftercare(leadId:aftercareId:)` for existing leads

**Example**:
```swift
func updateLeadStatus(leadId: String, status: LeadStatus, aftercareId: String? = nil) async throws {
    var updates: [String: Any] = [
        "status": status.rawValue,
        "updatedAt": Date().timeIntervalSince1970
    ]
    if let aftercareId = aftercareId {
        updates["aftercareId"] = aftercareId
    }
    // Write to Firebase...
}
```

---

### 7. **AftercareService** - New Model Support
**File**: `superapp/Services/AftercareService.swift`

**TODO**:
- [ ] Add `createAftercare(aftercare: Aftercare)` function
- [ ] Add `fetchClientAftercares(clientUid: String)` function
- [ ] Add `fetchArtistAftercares(artistUid: String)` function (uses `/aftercareByArtist` index)
- [ ] Add `updateAftercareStatus(id:status:)` function
- [ ] Add `markInstructionCompleted(aftercareId:instructionId:)` function
- [ ] Add real-time subscription: `subscribeToClientAftercares(clientUid:)`

**Database Structure** (from web app):
```
/aftercareByClient/{clientUid}/{aftercareId}
/aftercareByArtist/{artistUid}/{aftercareId}  // index/mirror
```

**Reference Web Implementation**: `lib/aftercare.ts`

---

### 8. **LeadsHomeView** - Aftercare Creation Modal
**File**: `superapp/Views/artist/LeadsHomeView.swift`

**TODO**:
- [ ] Add `@State var showAftercareModal = false`
- [ ] Add `@State var selectedLead: Lead?`
- [ ] When artist accepts a lead (status changes to `.accepted`), show aftercare creation modal
- [ ] Modal should:
  - Pre-fill client name and lead details
  - Allow artist to add custom instructions (day + text)
  - Show "Add Step" / "Remove Step" buttons
  - Create `Aftercare` object and save to Firebase
  - Update lead with `aftercareId`

**Reference Web Implementation**: `app/leads/page.tsx` lines 80-180 (AftercareModal component)

---

### 9. **ArtistAftercareView** - Dashboard Update
**File**: `superapp/Views/artist/ArtistAftercareView.swift`

**TODO**:
- [ ] Fetch aftercare plans using new `Aftercare` model
- [ ] Display plans in grid/list with:
  - Client name
  - Tattoo description
  - Progress bar (using `progressPercentage`)
  - Status badge (active/completed/archived)
- [ ] Add "Create New" button → shows same modal as LeadsHomeView
- [ ] Allow status updates: active → completed → archived

**Reference Web Implementation**: `app/aftercare/page.tsx` - ArtistAftercareView component

---

### 10. **ClientAftercareView** - Progress Tracking
**File**: `superapp/Views/client/ClientAftercareView.swift`

**TODO**:
- [ ] Fetch aftercare plans for current client
- [ ] Display as list of cards with:
  - Artist name
  - Tattoo description
  - Overall progress bar
- [ ] Tap card → Detail view with:
  - All instructions listed by day
  - Checkboxes to mark completed
  - Visual progress indicator
- [ ] Real-time updates using `subscribeToClientAftercares()`

**Reference Web Implementation**: `app/aftercare/page.tsx` - ClientAftercareView component

---

### 11. **SettingsView** - Address Field UI
**File**: `superapp/Views/settings/SettingsView.swift`

**TODO** (if artist profile settings exist):
- [ ] Add `@State var address: String = ""`
- [ ] Add TextField for address input above or below city field
- [ ] Load address from profile on appear
- [ ] Save address when updating profile
- [ ] Trigger geocoding with new address+city combination

**Reference Web Implementation**: `app/settings/page.tsx` lines 120-135

---

## 🔥 Firebase Realtime Database Rules Update

**CRITICAL**: The web app has updated database rules that need to be deployed to production:

### New Rules Added:
```json
{
  "aftercareByClient": {
    "$clientUid": {
      "$aftercareId": {
        ".read": "$clientUid === auth.uid",
        ".write": "data.child('artistUid').val() === auth.uid || $clientUid === auth.uid",
        ".validate": "newData.hasChildren(['artistUid', 'clientUid', 'artistName', 'clientName', 'instructions', 'status', 'createdAt', 'updatedAt'])",
        // ... field validation
      }
    }
  },
  "aftercareByArtist": {
    "$artistUid": {
      ".read": "$artistUid === auth.uid",
      ".write": "$artistUid === auth.uid",
      "$aftercareId": {
        ".validate": "newData.hasChildren(['artistUid', 'clientUid'])"
      }
    }
  }
}
```

**TODO**: Deploy updated `database.rules.json` from web app to Firebase Console

---

## 📱 iOS-Specific Considerations

### Architecture Differences:
1. **SwiftUI vs React**: 
   - iOS uses `@State`, `@EnvironmentObject` for state management
   - Web uses React hooks (`useState`, `useEffect`, custom hooks)
   
2. **Navigation**:
   - iOS: `NavigationStack`, `NavigationLink`, `.sheet()`
   - Web: Next.js App Router, `useRouter().push()`

3. **Real-time Data**:
   - iOS: Use Combine publishers or async streams with Firebase SDK
   - Web: Direct Firebase `onValue()` listeners

4. **Date Formatting**:
   - iOS: `RelativeDateTimeFormatter`, `DateFormatter`
   - Web: `toLocaleDateString()`, `toLocaleTimeString()`

### Swift Best Practices:
- Use `async/await` for Firebase operations
- Create separate `@MainActor` classes for ViewModels
- Use `Sendable` protocol for thread-safe models
- Leverage Swift's strong typing (enums with associated values)

---

## 🚀 Implementation Priority

**Phase 1 - Critical (This Week)**:
1. ✅ Update models (DONE)
2. ✅ Update ChatListView (DONE)
3. ⏳ Update PublicProfilesService (address support)
4. ⏳ Update LeadsService (aftercareId support)

**Phase 2 - Core Features (Next Week)**:
5. ⏳ Update AftercareService (new model CRUD)
6. ⏳ Add aftercare modal to LeadsHomeView
7. ⏳ Update ArtistAftercareView dashboard
8. ⏳ Update ClientAftercareView tracker

**Phase 3 - Polish (Following Week)**:
9. ⏳ Add address field to SettingsView
10. ⏳ Update map views to use fullLocation
11. ⏳ Add loading states and error handling
12. ⏳ Test end-to-end flow

**Phase 4 - Testing & Deployment**:
13. ⏳ Integration testing (artist accepts lead → creates aftercare → client sees it)
14. ⏳ Deploy updated Firebase rules
15. ⏳ TestFlight build for beta testing
16. ⏳ App Store submission

---

## 📊 Feature Parity Checklist

| Feature | Web Status | iOS Status | Priority |
|---------|-----------|-----------|----------|
| Address field in profiles | ✅ Live | ✅ Model ready, ⏳ UI pending | High |
| Lead → Aftercare linking | ✅ Live | ✅ Model ready, ⏳ Service pending | High |
| Aftercare status tracking | ✅ Live | ✅ Model ready, ⏳ Service pending | High |
| Chat restrictions (artists) | ✅ Live | ✅ Complete | Critical |
| Aftercare creation modal | ✅ Live | ⏳ Not started | High |
| Aftercare artist dashboard | ✅ Live | ⏳ Partial | Medium |
| Aftercare client tracker | ✅ Live | ⏳ Partial | Medium |
| Real-time aftercare updates | ✅ Live | ⏳ Not started | Medium |
| Progress visualization | ✅ Live | ⏳ Not started | Low |

---

## 🔗 Reference Files

### Web App (Next.js):
- Types: `types/index.ts`
- Aftercare Library: `lib/aftercare.ts`
- Artist Leads View: `app/leads/page.tsx`
- Aftercare Views: `app/aftercare/page.tsx`
- Chat Restrictions: `app/chat/page.tsx`
- Settings (Address): `app/settings/page.tsx`
- Database Rules: `database.rules.json`

### iOS App (Swift):
- Models: `superapp/Models/`
- Services: `superapp/Services/`
- Views: `superapp/Views/`
- ViewModels: `superapp/ViewModels/`

---

## 🐛 Known Issues to Address

1. **ChatListView Leads Button**: Replace `Text("Leads")` placeholder with actual `LeadsHomeView` navigation
2. **Aftercare Legacy Models**: Remove old `AftercarePlan` once all code migrated to new `Aftercare`
3. **Geocoding**: Need to test Nominatim API calls with address+city combinations
4. **Firebase Indexes**: Ensure `/aftercareByArtist/{artistUid}` index is configured in Firebase Console

---

## 📝 Notes

- **Firebase Project**: Both apps share the same Firebase project (check `GoogleService-Info.plist` and `.env.local`)
- **API Keys**: Ensure all API keys (Maps, Stripe, etc.) are synced between platforms
- **Localization**: iOS has French localization - ensure new strings are added to `Localizable.strings`
- **Dark Mode**: iOS app has appearance settings - test all new UI in both light/dark modes

---

## ✍️ Author Notes

**Git Branches**:
- Web: `main` (commit `759a06f`)
- iOS: `inkmatching`

**Last Sync**: October 21, 2025

**Contact**: For questions about web implementation details, refer to the conversation history or check the web app codebase directly.

---

**Next Action**: Start with Phase 1 items - update `PublicProfilesService` and `LeadsService` to support the new model fields. Then move to Phase 2 to implement the aftercare UI components.
