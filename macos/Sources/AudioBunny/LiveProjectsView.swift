import SwiftUI
import UniformTypeIdentifiers

// Sentinel UUID that represents the "All Plugins" summary item in the sidebar.
private let allPluginsID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

struct LiveProjectsView: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    @EnvironmentObject var pluginManager: PluginManager
    @State private var selection: UUID? = nil
    @State private var showDirectoryPicker = false

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebarContent
        } detail: {
            detailContent
        }
        .removeSidebarToggle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Scan Folder…") { showDirectoryPicker = true }
                    .disabled(liveProjectManager.isScanning)
            }
        }
        .fileImporter(
            isPresented: $showDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                Task { await liveProjectManager.scanDirectory(url) }
            }
        }
        .onChange(of: liveProjectManager.isScanning) { isScanning in
            if !isScanning && !liveProjectManager.projects.isEmpty {
                selection = allPluginsID
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    var sidebarContent: some View {
        ZStack {
            if liveProjectManager.projects.isEmpty && !liveProjectManager.isScanning {
                LiveEmptyView(
                    icon: "folder.badge.questionmark",
                    title: "No Projects",
                    message: "Click \"Scan Folder\" to scan a directory for Ableton Live projects."
                )
            } else {
                List(selection: $selection) {
                    AllPluginsSidebarRow()
                        .tag(allPluginsID)

                    Section("Projects") {
                        ForEach(liveProjectManager.projects) { project in
                            LiveProjectRowView(
                                project: project,
                                installedPlugins: pluginManager.plugins
                            )
                            .tag(project.id)
                        }
                    }
                }
                .listStyle(.sidebar)
            }

            if liveProjectManager.isScanning {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Scanning…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .navigationTitle("Live Projects")
        .frame(minWidth: 220)
    }

    // MARK: - Detail

    @ViewBuilder
    var detailContent: some View {
        if selection == allPluginsID {
            AllPluginsSummaryView()
        } else if let id = selection,
                  let project = liveProjectManager.projects.first(where: { $0.id == id }) {
            LiveProjectDetailView(project: project)
        } else if liveProjectManager.projects.isEmpty {
            LiveEmptyView(
                icon: "metronome",
                title: "Scan a Folder",
                message: "Scan a folder to see which plugins your Ableton Live projects use."
            )
        } else {
            Text("Select a project")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - All Plugins Sidebar Row

struct AllPluginsSidebarRow: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    @EnvironmentObject var pluginManager: PluginManager

    var allPlugins: [LiveProjectPlugin] { liveProjectManager.allUniquePlugins }
    var missingCount: Int { allPlugins.filter { !$0.isInstalled(in: pluginManager.plugins) }.count }

    var body: some View {
        HStack {
            Image(systemName: "list.bullet.clipboard")
                .foregroundStyle(.blue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("All Plugins")
                    .fontWeight(.medium)
                if !allPlugins.isEmpty {
                    Text("\(allPlugins.count) unique plugin\(allPlugins.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if missingCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("\(missingCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            } else if !allPlugins.isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Project Row

struct LiveProjectRowView: View {
    let project: LiveProject
    let installedPlugins: [AudioPlugin]

    var missingCount: Int {
        project.plugins.filter { !$0.isInstalled(in: installedPlugins) }.count
    }

    var body: some View {
        HStack {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)
                Text(project.plugins.isEmpty
                     ? "No plugins"
                     : "\(project.plugins.count) plugin\(project.plugins.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if missingCount > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("\(missingCount)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - All Plugins Summary (detail)

struct AllPluginsSummaryView: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    @EnvironmentObject var pluginManager: PluginManager

    var allPlugins: [LiveProjectPlugin] { liveProjectManager.allUniquePlugins }
    var missing: [LiveProjectPlugin] { allPlugins.filter { !$0.isInstalled(in: pluginManager.plugins) } }
    var installed: [LiveProjectPlugin] { allPlugins.filter { $0.isInstalled(in: pluginManager.plugins) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Stats header
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("All Plugins")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("\(liveProjectManager.projects.count) project\(liveProjectManager.projects.count == 1 ? "" : "s") scanned")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Label("\(installed.count) installed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            if !missing.isEmpty {
                                Label("\(missing.count) missing", systemImage: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                if allPlugins.isEmpty {
                    LiveEmptyView(
                        icon: "puzzlepiece",
                        title: "No Plugins Found",
                        message: "No plugins were found across the scanned projects."
                    )
                } else {
                    if !missing.isEmpty {
                        GroupBox {
                            VStack(spacing: 0) {
                                ForEach(missing) { plugin in
                                    PluginUsageRow(
                                        plugin: plugin,
                                        isInstalled: false,
                                        projectCount: liveProjectManager.projectCount(for: plugin)
                                    )
                                    if plugin.id != missing.last?.id { Divider() }
                                }
                            }
                        } label: {
                            Label("Missing Plugins (\(missing.count))", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    if !installed.isEmpty {
                        GroupBox {
                            VStack(spacing: 0) {
                                ForEach(installed) { plugin in
                                    PluginUsageRow(
                                        plugin: plugin,
                                        isInstalled: true,
                                        projectCount: liveProjectManager.projectCount(for: plugin)
                                    )
                                    if plugin.id != installed.last?.id { Divider() }
                                }
                            }
                        } label: {
                            Label("Installed Plugins (\(installed.count))", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("All Plugins")
    }
}

// MARK: - Project Detail

struct LiveProjectDetailView: View {
    @EnvironmentObject var pluginManager: PluginManager
    let project: LiveProject

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(project.url.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)

                if project.plugins.isEmpty {
                    LiveEmptyView(
                        icon: "puzzlepiece",
                        title: "No Plugins Found",
                        message: "This project uses no plugins, or the file could not be parsed."
                    )
                } else {
                    let missing = project.plugins.filter { !$0.isInstalled(in: pluginManager.plugins) }
                    let installed = project.plugins.filter { $0.isInstalled(in: pluginManager.plugins) }

                    if !missing.isEmpty {
                        GroupBox {
                            VStack(spacing: 0) {
                                ForEach(missing) { plugin in
                                    PluginUsageRow(plugin: plugin, isInstalled: false)
                                    if plugin.id != missing.last?.id { Divider() }
                                }
                            }
                        } label: {
                            Label("Missing Plugins (\(missing.count))", systemImage: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    if !installed.isEmpty {
                        GroupBox {
                            VStack(spacing: 0) {
                                ForEach(installed) { plugin in
                                    PluginUsageRow(plugin: plugin, isInstalled: true)
                                    if plugin.id != installed.last?.id { Divider() }
                                }
                            }
                        } label: {
                            Label("Installed Plugins (\(installed.count))", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(project.name)
    }
}

// MARK: - Plugin Usage Row

struct PluginUsageRow: View {
    let plugin: LiveProjectPlugin
    let isInstalled: Bool
    var projectCount: Int? = nil

    var body: some View {
        HStack {
            Image(systemName: isInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isInstalled ? .green : .red)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(plugin.name)
                HStack(spacing: 8) {
                    if let mfr = plugin.manufacturer {
                        Text(mfr)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let count = projectCount {
                        Text("\(count) project\(count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
            if let type = plugin.type {
                Text(type.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Empty State Helper

struct LiveEmptyView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
