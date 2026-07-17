import SwiftUI
import AppKit

enum AppTab: String {
    case library
    case browse
    case presets
    case liveProjects
}

struct ContentView: View {
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager
    @EnvironmentObject var presetManager: PresetManager
    @State private var selectedPlugin: AudioPlugin? = nil
    @AppStorage("audiobunny.activeTab") private var activeTab: AppTab = .browse

    var body: some View {
        TabView(selection: $activeTab) {
            StoreView()
                .tabItem { Label("Discover", systemImage: "safari") }
                .tag(AppTab.browse)

            NavigationSplitView(columnVisibility: .constant(.all)) {
                SidebarView(selectedPlugin: $selectedPlugin)
            } detail: {
                if let plugin = selectedPlugin {
                    PluginDetailView(plugin: plugin)
                } else {
                    Text("Select a plugin")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .removeSidebarToggle()
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: manager.refresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(manager.isScanning)
                    .help("Rescan for plugins")
                }
            }
            .tabItem { Label("My Plugins", systemImage: "waveform") }
            .tag(AppTab.library)

            PresetsView()
                .tabItem { Label("Presets", systemImage: "music.note.list") }
                .tag(AppTab.presets)

            LiveProjectsView()
                .tabItem { Label("Projects", systemImage: "waveform.badge.exclamationmark") }
                .tag(AppTab.liveProjects)
        }
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var manager: PluginManager
    @Binding var selectedPlugin: AudioPlugin?

    var body: some View {
        VStack(spacing: 0) {
            // Stats bar
            StatsBar()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(.bar)

            Divider()

            // Filters
            FilterBar()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Disable all failing button (shown only when there are failing plugins)
            let failedCount = manager.pluginCounts.failed
            if failedCount > 0 {
                Button(action: manager.disableAllFailing) {
                    Label("Disable \(failedCount) Failing Plugin\(failedCount == 1 ? "" : "s")", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .disabled(manager.isScanning)

                Divider()
            }

            Button(action: manager.testAllUntested) {
                Label("Test All", systemImage: "play.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .disabled(manager.isScanning)
            .help("Test all untested plugins")

            Divider()

            // Plugin list with overlayed scanning indicator
            ZStack {
                if manager.filteredPlugins.isEmpty {
                    Text("No plugins found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedPlugin) {
                        if !instrumentGroups.isEmpty {
                            Section("Instruments (\(instrumentGroups.count))") {
                                ForEach(instrumentGroups, id: \.self) { group in
                                    MergedPluginRowView(group: group)
                                        .tag(group[0])
                                }
                            }
                        }
                        if !effectGroups.isEmpty {
                            Section("Effects (\(effectGroups.count))") {
                                ForEach(effectGroups, id: \.self) { group in
                                    MergedPluginRowView(group: group)
                                        .tag(group[0])
                                }
                            }
                        }
                        if !uncategorizedGroups.isEmpty {
                            Section("Uncategorized (\(uncategorizedGroups.count))") {
                                ForEach(uncategorizedGroups, id: \.self) { group in
                                    MergedPluginRowView(group: group)
                                        .tag(group[0])
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }

                if manager.isScanning {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView("Scanning...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                }
            }
        }
        .searchable(text: $manager.searchText, prompt: "Search plugins")
        .navigationTitle("AudioBunny")
        .frame(minWidth: 330)
    }

    // Plugins are already sorted by name, so identically-named plugins
    // (e.g. the same instrument installed as both AU and VST3) are adjacent —
    // just chunk them into runs of matching name.
    private var groupedFilteredPlugins: [[AudioPlugin]] {
        var groups: [[AudioPlugin]] = []
        for plugin in manager.filteredPlugins {
            if let lastIndex = groups.indices.last,
               groups[lastIndex][0].name.caseInsensitiveCompare(plugin.name) == .orderedSame {
                groups[lastIndex].append(plugin)
            } else {
                groups.append([plugin])
            }
        }
        return groups
    }

    private var instrumentGroups: [[AudioPlugin]] {
        groupedFilteredPlugins.filter { preferredCategory(for: $0) == .instrument }
    }
    private var effectGroups: [[AudioPlugin]] {
        groupedFilteredPlugins.filter { preferredCategory(for: $0) == .effect }
    }
    private var uncategorizedGroups: [[AudioPlugin]] {
        groupedFilteredPlugins.filter { preferredCategory(for: $0) == nil }
    }
}

// MARK: - Stats Bar

struct StatsBar: View {
    @EnvironmentObject var manager: PluginManager

    var body: some View {
        let counts = manager.pluginCounts
        HStack(spacing: 16) {
            statItem(counts.active, label: "Active", color: .green)
            statItem(counts.failed, label: "Failed", color: .red)
            statItem(counts.disabled, label: "Disabled", color: .secondary)
            statItem(counts.untested, label: "Untested", color: .orange)
            Spacer()
            statItem(counts.total, label: "Total", color: .primary)
        }
        .frame(maxWidth: .infinity)
        .font(.caption)
    }

    @ViewBuilder
    private func statItem(_ count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Filter Bar

struct FilterBar: View {
    @EnvironmentObject var manager: PluginManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Type filter
            HStack(spacing: 6) {
                Text("Type:")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                filterChip("All", selected: manager.filterType == nil) {
                    manager.filterType = nil
                }
                ForEach(PluginType.allCases, id: \.self) { type in
                    filterChip(type.rawValue, selected: manager.filterType == type) {
                        manager.filterType = type
                    }
                }
            }

            // Status filter
            HStack(spacing: 6) {
                Text("Status:")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                ForEach(PluginManager.PluginStatusFilter.allCases, id: \.self) { filter in
                    filterChip(filter.rawValue, selected: manager.filterStatus == filter) {
                        manager.filterStatus = filter
                    }
                }
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Plugin Row (one row per plugin name; same-name variants merge into it)

struct MergedPluginRowView: View {
    let group: [AudioPlugin]

    private var primary: AudioPlugin { group[0] }

    private var isAnyEnabled: Bool { group.contains { !$0.isDisabled } }

    private var versionText: String {
        Set(group.compactMap(\.version)).sorted().joined(separator: ", ")
    }

    private var category: PluginCategory? { preferredCategory(for: group) }

    var body: some View {
        HStack(spacing: 10) {
            if let category {
                Image(systemName: category.icon)
                    .foregroundStyle(category == .instrument ? .green : .orange)
                    .frame(width: 18)
                    .help(category.label)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(primary.name)
                    .font(.body)
                    .foregroundStyle(isAnyEnabled ? .primary : .secondary)
                    .lineLimit(1)
                if !versionText.isEmpty {
                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(group) { plugin in
                    HStack(spacing: 3) {
                        PluginStatusIcon(status: plugin.status)
                        PluginTypeTag(type: plugin.type)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(isAnyEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Plugin Type Tag

struct PluginTypeTag: View {
    let type: PluginType

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(.white)
    }

    private var label: String {
        switch type {
        case .audioUnit: return "AU"
        case .vst2: return "VST2"
        case .vst3: return "VST3"
        }
    }

    private var color: Color {
        switch type {
        case .audioUnit: return .blue
        case .vst2: return Color(red: 0.36, green: 0.16, blue: 0.56)
        case .vst3: return Color(red: 0.68, green: 0.42, blue: 0.98)
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: PluginStatus

    var body: some View {
        Text(shortLabel)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .cornerRadius(4)
    }

    private var shortLabel: String {
        switch status {
        case .untested: return "—"
        case .testing: return "..."
        case .active: return "OK"
        case .failed: return "FAIL"
        case .disabled: return "OFF"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .untested: return .secondary
        case .testing: return .orange
        case .active: return .green
        case .failed: return .red
        case .disabled: return .gray
        }
    }
}

// MARK: - Plugin Status Icon (tested / untested indicator for sidebar rows)

struct PluginStatusIcon: View {
    let status: PluginStatus

    var body: some View {
        Group {
            switch status {
            case .untested:
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
            case .testing:
                ProgressView()
                    .controlSize(.mini)
            case .active:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .disabled:
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.gray)
            }
        }
        .font(.caption)
        .help(status.label)
    }
}

// MARK: - Plugin Detail View

struct PluginDetailView: View {
    @ObservedObject var plugin: AudioPlugin
    @EnvironmentObject var manager: PluginManager

    // Other format variants of this same plugin (e.g. the AU and VST3 builds of
    // the same instrument) so we can list every install location, not just the
    // one that happened to be selected.
    private var groupVariants: [AudioPlugin] {
        manager.plugins
            .filter { $0.name.caseInsensitiveCompare(plugin.name) == .orderedSame }
            .sorted { $0.type.rawValue < $1.type.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: plugin.category?.icon ?? "waveform")
                        .font(.largeTitle)
                        .foregroundStyle(categoryColor)
                        .frame(width: 50, height: 50)
                        .background(categoryColor.opacity(0.1))
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(plugin.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(plugin.manufacturer)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(plugin.type.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(typeColor.opacity(0.1))
                                .foregroundStyle(typeColor)
                                .cornerRadius(6)
                            StatusBadge(status: plugin.status)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                // Status details
                if case .failed(let msg) = plugin.status {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(msg)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Plugin info
                GroupBox("Plugin Information") {
                    VStack(spacing: 0) {
                        ForEach(groupVariants) { variant in
                            locationRow(variant)
                        }
                        if let sub = plugin.subtypeString {
                            infoRow("Subtype", sub)
                        }
                        if let mfr = plugin.manufacturerCodeString {
                            infoRow("Manufacturer Code", mfr)
                        }
                    }
                }

                // Actions
                GroupBox("Actions") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button(action: { manager.testPlugin(plugin) }) {
                                Label("Test Plugin", systemImage: "play.circle")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!plugin.canTest)

                            if plugin.status == .testing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }

                        Divider()

                        if plugin.isDisabled {
                            Button(action: { manager.enablePlugin(plugin) }) {
                                Label("Re-enable Plugin", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(.bordered)
                            Text("Plugin will be moved back to: \(manager.restorePath(for: plugin.type))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(action: { manager.disablePlugin(plugin) }) {
                                Label("Disable Plugin", systemImage: "xmark.circle")
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            Text("Plugin file will be moved to: \(manager.disabledFolderURL.path)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(plugin.name)
    }

    @ViewBuilder
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        Divider()
    }

    @ViewBuilder
    private func locationRow(_ variant: AudioPlugin) -> some View {
        HStack(alignment: .top) {
            Text("Location (\(variant.type.rawValue))")
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(variant.fileURL.path)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([variant.fileURL])
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        Divider()
    }

    private var typeColor: Color {
        switch plugin.type {
        case .audioUnit: return .blue
        case .vst2: return .purple
        case .vst3: return .indigo
        }
    }

    private var categoryColor: Color {
        switch plugin.category {
        case .instrument: return .green
        case .effect: return .orange
        case nil: return .secondary
        }
    }
}

// MARK: - Backport: hide sidebar toggle on macOS 13

extension View {
    @ViewBuilder func removeSidebarToggle() -> some View {
        if #available(macOS 14.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }
}

