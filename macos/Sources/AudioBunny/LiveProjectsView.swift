import SwiftUI
import UniformTypeIdentifiers

private let allProjectsID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

struct LiveProjectsView: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    @EnvironmentObject var pluginManager: PluginManager
    @State private var selection: UUID? = allProjectsID
    @State private var showDirectoryPicker = false

    var selectedProject: LiveProject? {
        guard let sel = selection, sel != allProjectsID else { return nil }
        return liveProjectManager.projects.first { $0.id == sel }
    }

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
        .onChange(of: liveProjectManager.isScanning) { scanning in
            if !scanning && !liveProjectManager.projects.isEmpty {
                selection = allProjectsID
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
                    AllProjectsRow()
                        .tag(allProjectsID)

                    if !liveProjectManager.projects.isEmpty {
                        Section("Projects") {
                            ForEach(liveProjectManager.projects) { project in
                                ProjectSidebarRow(project: project)
                                    .tag(project.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Projects")
        .frame(minWidth: 200)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if liveProjectManager.isScanning { ScanProgressBar() }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    var detailContent: some View {
        if selection == allProjectsID || selection == nil {
            PluginsListView(
                plugins: liveProjectManager.allUniquePlugins,
                showProjectCount: true
            )
            .navigationTitle("All Projects")
        } else if let project = selectedProject {
            PluginsListView(plugins: project.plugins, showProjectCount: false)
                .navigationTitle(project.name)
        } else {
            LiveEmptyView(
                icon: "doc.richtext",
                title: "Select a Project",
                message: "Choose a project from the sidebar to see its plugins."
            )
        }
    }
}

// MARK: - All Projects Sidebar Row

struct AllProjectsRow: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    @EnvironmentObject var pluginManager: PluginManager

    var missingCount: Int {
        liveProjectManager.allUniquePlugins.filter { !$0.isInstalled(in: pluginManager.plugins) }.count
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("All Projects")
                    .fontWeight(.medium)
                if !liveProjectManager.projects.isEmpty {
                    let n = liveProjectManager.projects.count
                    Text("\(n) project\(n == 1 ? "" : "s")")
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
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Project Sidebar Row

struct ProjectSidebarRow: View {
    @EnvironmentObject var pluginManager: PluginManager
    let project: LiveProject

    var missingCount: Int {
        project.plugins.filter { !$0.isInstalled(in: pluginManager.plugins) }.count
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .lineLimit(1)
                let n = project.plugins.count
                Text(n == 0 ? "No plugins" : "\(n) plugin\(n == 1 ? "" : "s")")
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

// MARK: - Plugins List (detail pane)

struct PluginsListView: View {
    @EnvironmentObject var pluginManager: PluginManager
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    let plugins: [LiveProjectPlugin]
    let showProjectCount: Bool

    var missing: [LiveProjectPlugin]   { plugins.filter { !$0.isInstalled(in: pluginManager.plugins) } }
    var installed: [LiveProjectPlugin] { plugins.filter {  $0.isInstalled(in: pluginManager.plugins) } }

    var body: some View {
        if plugins.isEmpty {
            LiveEmptyView(
                icon: "puzzlepiece",
                title: "No Plugins",
                message: "No plugins found in this selection."
            )
        } else {
            List {
                if !missing.isEmpty {
                    Section("Missing (\(missing.count))") {
                        ForEach(missing) { plugin in
                            PluginUsageRow(
                                plugin: plugin,
                                isInstalled: false,
                                projectCount: showProjectCount ? liveProjectManager.projectCount(for: plugin) : nil
                            )
                        }
                    }
                }
                if !installed.isEmpty {
                    Section("Installed (\(installed.count))") {
                        ForEach(installed) { plugin in
                            PluginUsageRow(
                                plugin: plugin,
                                isInstalled: true,
                                projectCount: showProjectCount ? liveProjectManager.projectCount(for: plugin) : nil
                            )
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - Scan Progress Bar

struct ScanProgressBar: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                if liveProjectManager.scanTotalCount > 0 {
                    ProgressView(
                        value: Double(liveProjectManager.scanCurrentIndex),
                        total: Double(liveProjectManager.scanTotalCount)
                    )
                    .progressViewStyle(.linear)
                    .frame(width: 120)
                    Text("\(liveProjectManager.scanCurrentIndex) of \(liveProjectManager.scanTotalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("·").foregroundStyle(.tertiary)
                    Text(liveProjectManager.scanCurrentFile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(liveProjectManager.scanFoundCount) found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                    Text(liveProjectManager.scanCurrentFile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
        }
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
        .padding(.vertical, 4)
    }
}

// MARK: - Empty State

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
