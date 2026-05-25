import SwiftUI

struct GroupSearchView: View {
    @EnvironmentObject private var firestore: FirestoreManager
    @EnvironmentObject private var auth: AuthManager

    @State private var searchText = ""
    @State private var joiningGroupNames: Set<String> = []
    @State private var userPreferences: UserPreferences?
    @State private var loggedSearchSignature = ""
    @State private var loggedRenderSignature = ""

    private var allGroups: [SocialGroup] {
        firestore.discoverableGroups
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedQuery: String {
        normalized(trimmedQuery)
    }

    private var isSearching: Bool {
        !normalizedQuery.isEmpty
    }

    private var myGroupNameSet: Set<String> {
        Set(firestore.myGroups.map { $0.name.lowercased() })
    }

    private var filteredGroups: [SocialGroup] {
        let raw = searchText
        let trimmed = trimmedQuery
        let query = normalizedQuery
        #if DEBUG
        print("[GROUP_SEARCH][QUERY] raw='\(raw)' trimmed='\(trimmed)' normalized='\(query)'")
        #endif
        #if DEBUG
        print("[GROUP_SEARCH][FILTER_INPUT] query='\(query)' candidateCount=\(allGroups.count) candidateNames=\(allGroups.map(\.name).sorted().joined(separator: " | "))")
        #endif
        guard !query.isEmpty else { return allGroups }
        let queryTerms = expandedSearchTerms(for: query)
        #if DEBUG
        if shouldVerboseDebug(for: query) {
            print("[GROUP_SEARCH][QUERY] alias_expanded_terms=\(queryTerms)")
            print("[GROUP_SEARCH][QUERY] candidate_count=\(allGroups.count)")
        }
        #endif
        let ranked = rankedGroups(for: query)
        let result = ranked.map(\.group)
        #if DEBUG
        let names = result.map(\.name).sorted().joined(separator: " | ")
        print("[GROUP_SEARCH][FILTER_OUTPUT] query='\(query)' resultCount=\(result.count) resultNames=\(names)")
        #endif
        return result
    }

    private var recommendedGroups: [SocialGroup] {
        guard !isSearching else { return [] }
        let stressorWords = Set(
            (userPreferences?.topStressors ?? [])
                .flatMap { $0.lowercased().split(separator: " ").map(String.init) }
        )
        let ranked = allGroups
            .map { group -> (SocialGroup, Int) in
                let blob = "\(group.name) \(group.category ?? "") \(group.tags.joined(separator: " "))".lowercased()
                let profileBoost = stressorWords.reduce(into: 0) { partial, token in
                    if blob.contains(token) { partial += 2 }
                }
                let popularity = min(20, group.memberIds.count)
                return (group, profileBoost + popularity)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
        return Array(ranked.prefix(6))
    }

    private var visibleGroups: [SocialGroup] {
        isSearching ? filteredGroups : allGroups
    }

    private var displayArrayName: String {
        isSearching ? "filteredGroups" : "allGroups"
    }

    private var searchResultsUnjoined: [SocialGroup] {
        visibleGroups.filter { !myGroupNameSet.contains($0.name.lowercased()) }
    }

    private var searchResultsJoined: [SocialGroup] {
        visibleGroups.filter { myGroupNameSet.contains($0.name.lowercased()) }
    }

    var body: some View {
        List {
            if !isSearching, !recommendedGroups.isEmpty {
                Section("Popular / recommended for you") {
                    ForEach(recommendedGroups) { group in
                        groupRow(group)
                    }
                }
            }

            Section(
                !isSearching
                ? "Suggested groups"
                : "Search results"
            ) {
                if firestore.isDiscoverableGroupsLoading && allGroups.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading groups...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if isSearching && searchResultsUnjoined.isEmpty && searchResultsJoined.isEmpty {
                    Text("No groups found matching your search")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    let rows = isSearching ? searchResultsUnjoined : visibleGroups
                    ForEach(rows) { group in
                        groupRow(group)
                            .onAppear {
                                #if DEBUG
                                if shouldVerboseDebug(for: normalizedQuery) {
                                    print("[GROUP_SEARCH][UI] rendering_row name='\(group.name)' id=\(group.id) joined=\(myGroupNameSet.contains(group.name.lowercased()))")
                                }
                                if isBurnoutOrPTSDRelated(group: group) {
                                    let joined = myGroupNameSet.contains(group.name.lowercased())
                                    let canMaterializeDefault = group.id.hasPrefix("default_")
                                    print("[GROUP_SEARCH][JOINABILITY] group='\(group.name)' id=\(group.id) row_tappable=true join_button_visible=\(!joined) joined=\(joined) can_materialize_default=\(canMaterializeDefault)")
                                }
                                #endif
                            }
                    }
                }
            }
            if isSearching, !searchResultsJoined.isEmpty {
                Section("Already joined") {
                    ForEach(searchResultsJoined) { group in
                        groupRow(group)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Discover Groups")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name, description, tag, or category")
        .onChange(of: searchText) { _, _ in
            logSearchDebug()
            runDebugSearchMatrix()
            logRenderSource()
            logSourceAudit()
        }
        .onChange(of: firestore.discoverableGroups.count) { _, _ in
            logSearchDebug()
            runDebugSearchMatrix()
            logRenderSource()
            logSourceAudit()
        }
        .onChange(of: firestore.discoverableGroupsVersion) { _, _ in
            logSearchDebug()
            runDebugSearchMatrix()
            logRenderSource()
            logSourceAudit()
        }
        .task(id: auth.currentUser?.id) {
            await firestore.loadDiscoverableGroups(forceRefresh: true)
            if let authUid = auth.currentUser?.id {
                let prefs = await firestore.fetchUserPreferences(userId: authUid)
                await MainActor.run { userPreferences = prefs }
            } else {
                await MainActor.run { userPreferences = nil }
            }
            logSearchDebug()
            runDebugSearchMatrix()
            logRenderSource()
            logSourceAudit()
            #if DEBUG
            print("[GROUP_SEARCH][DATASET] DISCOVERABLE_TOTAL_COUNT=\(allGroups.count)")
            print("[GROUP_SEARCH][DATASET] DISCOVERABLE_FIRST_50_NAMES=\(allGroups.map(\.name).sorted().prefix(50).joined(separator: " | "))")
            #endif
        }
    }

    @ViewBuilder
    private func groupRow(_ group: SocialGroup) -> some View {
        NavigationLink {
            GroupSettingsView(group: group)
                .environmentObject(firestore)
                .environmentObject(auth)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(group.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let description = group.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        if let category = group.category, !category.isEmpty {
                            Text(category)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.primary.opacity(0.07)))
                        }
                        Text("\(group.memberIds.count) members")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !group.tags.isEmpty {
                        Text(group.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 10)
                let joined = myGroupNameSet.contains(group.name.lowercased())
                let joining = joiningGroupNames.contains(group.name)
                Button(joined ? "Joined" : (joining ? "Joining…" : "Join")) {
                    Task { await joinGroup(named: group.name) }
                }
                .buttonStyle(.bordered)
                .disabled(joined || joining)
            }
            .padding(.vertical, 2)
        }
    }

    private func joinGroup(named groupName: String) async {
        guard let uid = auth.currentUser?.id else { return }
        if joiningGroupNames.contains(groupName) { return }
        joiningGroupNames.insert(groupName)
        defer { joiningGroupNames.remove(groupName) }
        do {
            #if DEBUG
            print("[GROUP_SEARCH][JOIN] attempt name='\(groupName)' user=\(uid)")
            #endif
            try await firestore.joinSuggestedGroup(named: groupName, userId: uid)
            await firestore.loadDiscoverableGroups(forceRefresh: true)
        } catch {
            AppLogger.error("joinGroup search failed: \(error.localizedDescription)")
        }
    }

    private func rankedGroups(for query: String) -> [(group: SocialGroup, score: Int, reason: String, searchable: String)] {
        let queryTerms = expandedSearchTerms(for: query)
        return allGroups.compactMap { group in
            let normName = normalized(group.name)
            let normDescription = normalized(group.description ?? "")
            let normCategory = normalized(group.category ?? "")
            let normTags = group.tags.map(normalized)
            let normKeywords = group.searchKeywords.map(normalized)
            let searchable = ([normName, normDescription, normCategory] + normTags + normKeywords).joined(separator: " ")
            let tokens = Set(searchable.split(separator: " ").map(String.init))

            var bestScore = 0
            var bestReason = "none"
            for term in queryTerms where !term.isEmpty {
                // Tier 1: exact normalized name/tag/keyword match
                if normName == term || normTags.contains(term) || normKeywords.contains(term) {
                    let score = 400 + (normName == term ? 20 : 0)
                    if score > bestScore {
                        bestScore = score
                        bestReason = "tier1_exact"
                    }
                    continue
                }
                // Tier 2: substring name/tags/keywords
                if normName.contains(term)
                    || normTags.contains(where: { $0.contains(term) || term.contains($0) })
                    || normKeywords.contains(where: { $0.contains(term) || term.contains($0) }) {
                    if 300 > bestScore {
                        bestScore = 300
                        bestReason = "tier2_substring_name_tags_keywords"
                    }
                    continue
                }
                // Tier 3: substring description/category
                if normDescription.contains(term) || normCategory.contains(term) {
                    if 200 > bestScore {
                        bestScore = 200
                        bestReason = "tier3_substring_description_category"
                    }
                    continue
                }
                // Tier 4: fuzzy token
                if tokens.contains(where: { $0.contains(term) || term.contains($0) }) {
                    if 100 > bestScore {
                        bestScore = 100
                        bestReason = "tier4_fuzzy"
                    }
                }
            }

            let didMatch = bestScore > 0
            #if DEBUG
            let isInteresting = isBurnoutOrPTSDRelated(group: group) || shouldVerboseDebug(for: query)
            if isInteresting {
                print("[GROUP_SEARCH][MATCH] group='\(group.name)' searchable='\(searchable)' didMatch=\(didMatch) reason=\(bestReason)")
            }
            #endif

            guard didMatch else { return nil }
            return (group: group, score: bestScore, reason: bestReason, searchable: searchable)
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.group.name.localizedCaseInsensitiveCompare($1.group.name) == .orderedAscending
        }
    }

    private func normalized(_ value: String) -> String {
        var out = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let punct: [String] = ["-", "_", "/", ",", ".", "(", ")", ":", ";", "'"]
        for symbol in punct {
            out = out.replacingOccurrences(of: symbol, with: " ")
        }
        while out.contains("  ") {
            out = out.replacingOccurrences(of: "  ", with: " ")
        }
        return out
    }

    private func expandedSearchTerms(for query: String) -> [String] {
        let q = normalized(query)
        guard !q.isEmpty else { return [] }
        var terms = Set<String>()
        terms.insert(q)
        for token in q.split(separator: " ").map(String.init) {
            terms.insert(token)
        }
        for alias in aliases(for: q) { terms.insert(alias) }
        return Array(terms)
    }

    private func aliases(for term: String) -> [String] {
        let t = normalized(term)
        let map: [String: [String]] = [
            "ptsd": ["post traumatic stress disorder", "post-traumatic stress disorder", "trauma"],
            "post traumatic stress disorder": ["ptsd", "trauma"],
            "post traumatic stress": ["ptsd", "trauma"],
            "post traumatic stress d": ["ptsd", "trauma"],
            "post traumatic stress disorder support": ["ptsd", "trauma"],
            "adhd": ["attention deficit", "executive dysfunction"],
            "burnout": ["workplace stress", "work stress", "chronic stress", "exhaustion", "overwhelm", "stress"],
            "workplace stress": ["burnout", "exhaustion", "stress"],
            "exhaustion": ["burnout", "stress"],
            "overwhelm": ["burnout", "stress"],
            "grief": ["loss", "mourning"]
        ]
        return map[t] ?? []
    }

    private func logSearchDebug() {
        #if DEBUG
        let raw = trimmedQuery
        let normalizedQuery = self.normalizedQuery
        let matched = visibleGroups.map(\.name).sorted()
        let signature = "\(raw)|\(matched.joined(separator: ","))|\(allGroups.count)"
        guard signature != loggedSearchSignature else { return }
        loggedSearchSignature = signature
        print("[GROUP_SEARCH] input='\(raw)' normalized='\(normalizedQuery)' collections=groups+default_groups before=\(allGroups.count) after=\(matched.count) names=\(matched.joined(separator: " | "))")
        print("[GROUP_SEARCH][UI] hidden_by_joined_only=false hidden_by_discoverable_only=false hidden_by_privacy=false hidden_by_category_tab=false hidden_by_membership_status=false hidden_by_blocked_flag=false")
        #endif
    }

    private func logRenderSource() {
        #if DEBUG
        let names = visibleGroups.map(\.name).joined(separator: " | ")
        let signature = "\(normalizedQuery)|\(displayArrayName)|\(names)|\(searchResultsUnjoined.map(\.name).joined(separator: "|"))"
        guard signature != loggedRenderSignature else { return }
        loggedRenderSignature = signature
        print("[GROUP_SEARCH][RENDER_SOURCE] query='\(normalizedQuery)' isSearching=\(isSearching) displayArrayName='\(displayArrayName)' displayCount=\(visibleGroups.count) displayNames=\(names)")
        #endif
    }

    private func logSourceAudit() {
        #if DEBUG
        let joined = firestore.myGroups.map(\.name).sorted()
        let discoverable = firestore.discoverableGroups.map(\.name).sorted()
        let candidateNames = (isSearching ? filteredGroups : visibleGroups).map(\.name).sorted()
        print("[GROUP_SEARCH][SOURCE] searchText='\(searchText)' candidateArrayName='\(displayArrayName)' candidateCount=\(candidateNames.count) candidateNames=\(candidateNames.joined(separator: " | ")) joinedGroupCount=\(joined.count) joinedGroupNames=\(joined.joined(separator: " | ")) discoverableGroupCount=\(discoverable.count) discoverableGroupNames=\(discoverable.prefix(50).joined(separator: " | "))")
        #endif
    }

    #if DEBUG
    private func shouldVerboseDebug(for query: String) -> Bool {
        let q = normalized(query)
        return q.contains("burnout")
            || q.contains("ptsd")
            || q.contains("post traumatic stress")
            || q.contains("post-traumatic stress")
    }

    private func isBurnoutOrPTSDRelated(group: SocialGroup) -> Bool {
        let blob = "\(group.name) \(group.description ?? "") \(group.category ?? "") \(group.tags.joined(separator: " "))".lowercased()
        return blob.contains("burnout")
            || blob.contains("ptsd")
            || blob.contains("post traumatic stress")
            || blob.contains("post-traumatic stress")
            || blob.contains("trauma")
    }

    private func runDebugSearchMatrix() {
        let tests: [(query: String, expectedTop: String)] = [
            ("burnout", "Burnout"),
            ("Burnout", "Burnout"),
            ("BURNOUT", "Burnout"),
            ("ptsd", "PTSD"),
            ("PTSD", "PTSD"),
            ("post traumatic stress", "PTSD")
        ]
        for test in tests {
            let n = normalized(test.query)
            let matched = rankedGroups(for: n).map(\.group)
            let top = matched.first?.name ?? "none"
            let pass = top.caseInsensitiveCompare(test.expectedTop) == .orderedSame
            print("[GROUP_SEARCH][ASSERT] query='\(test.query)' expected='\(test.expectedTop)' top='\(top)' pass=\(pass)")
        }

        let uiTests: [(query: String, expectedContains: String)] = [
            ("ptsd", "PTSD"),
            ("burnout", "Burnout"),
            ("mens", "Men"),
            ("grief", "Grief"),
            ("loneliness", "Loneliness")
        ]
        for test in uiTests {
            let n = normalized(test.query)
            let display = rankedGroups(for: n).map(\.group.name)
            let pass = display.contains { normalized($0).contains(normalized(test.expectedContains)) }
            let expectedInDiscoverable = allGroups.map(\.name).contains { normalized($0).contains(normalized(test.expectedContains)) }
            let expectedInJoined = firestore.myGroups.map(\.name).contains { normalized($0).contains(normalized(test.expectedContains)) }
            let filteredOutReason: String = {
                if !expectedInDiscoverable { return "missing_from_discoverable" }
                if pass { return "none" }
                return "ranking_or_filter"
            }()
            print("[GROUP_SEARCH][UI_ASSERT] query='\(test.query)' expectedContains='\(test.expectedContains)' expectedInDiscoverable=\(expectedInDiscoverable) expectedInJoined=\(expectedInJoined) filteredOutReason='\(filteredOutReason)' displayNames='\(display.joined(separator: " | "))' pass=\(pass)")
        }
    }
    #endif
}
