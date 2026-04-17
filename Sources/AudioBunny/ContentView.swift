import SwiftUI

enum AppTab {
    case library
    case browse
}

struct ContentView: View {
    @EnvironmentObject var manager: PluginManager
    @EnvironmentObject var catalogManager: CatalogManager
    @State private var selectedPlugin: AudioPlugin? = nil
    @State private var activeTab: AppTab = .library

    var body: some View {
        Group {
            if activeTab == .library {
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
            } else {
                StoreView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Picker("", selection: $activeTab) {
                    Text("Library").tag(AppTab.library)
                    Text("Browse").tag(AppTab.browse)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if activeTab == .library {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: manager.testAllUntested) {
                        Label("Test All", systemImage: "play.circle")
                    }
                    .disabled(manager.isScanning)
                    .help("Test all untested plugins")

                    Button(action: manager.refresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(manager.isScanning)
                    .help("Rescan for plugins")
                }
            }
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

            // Plugin list with overlayed scanning indicator
            ZStack {
                if manager.filteredPlugins.isEmpty {
                    Text("No plugins found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(manager.filteredPlugins, selection: $selectedPlugin) { plugin in
                        PluginRowView(plugin: plugin)
                            .tag(plugin)
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

// MARK: - Plugin Row

struct PluginRowView: View {
    @ObservedObject var plugin: AudioPlugin
    @EnvironmentObject var manager: PluginManager

    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: plugin.type.icon)
                .foregroundStyle(typeColor)
                .frame(width: 18)

            // Name + manufacturer
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                    .font(.body)
                    .foregroundStyle(plugin.isDisabled ? .secondary : .primary)
                    .lineLimit(1)
                Text(plugin.manufacturer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status badge
            StatusBadge(status: plugin.status)
        }
        .padding(.vertical, 2)
        .opacity(plugin.isDisabled ? 0.6 : 1.0)
    }

    private var typeColor: Color {
        switch plugin.type {
        case .audioUnit: return .blue
        case .vst2: return .purple
        case .vst3: return .indigo
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

// MARK: - Plugin Detail View

struct PluginDetailView: View {
    @ObservedObject var plugin: AudioPlugin
    @EnvironmentObject var manager: PluginManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: plugin.type.icon)
                        .font(.largeTitle)
                        .foregroundStyle(typeColor)
                        .frame(width: 50, height: 50)
                        .background(typeColor.opacity(0.1))
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
                        infoRow("Type", plugin.type.rawValue)
                        infoRow("Location", plugin.fileURL.path)
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

    private var typeColor: Color {
        switch plugin.type {
        case .audioUnit: return .blue
        case .vst2: return .purple
        case .vst3: return .indigo
        }
    }
}

