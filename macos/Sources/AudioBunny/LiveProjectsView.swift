import SwiftUI
import UniformTypeIdentifiers

struct LiveProjectsView: View {
    @EnvironmentObject var liveProjectManager: LiveProjectManager
    @EnvironmentObject var pluginManager: PluginManager
    @State private var selection: UUID?
    @State private var showDirectoryPicker = false

    private func isFolderID(_ id: UUID) -> Bool {
        liveProjectManager.folders.contains { $0.id == id }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebarContent
        } detail: {
            detailContent
        }
        .removeSidebarToggle()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: pluginManager.refresh) {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(pluginManager.isScanning)
                .help("Rescan installed plugins")

                Button {
                    showDirectoryPicker = true
                } label: {
                    Label("Add Project Folder…", systemImage: "folder.badge.plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls { liveProjectManager.addFolder(url) }
                if selection == nil { selection = urls.first.flatMap { u in
                    liveProjectManager.folders.first { $0.url.path == u.path }?.id
                } }
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    var sidebarContent: some View {
        ZStack {
            if liveProjectManager.folders.isEmpty {
                LiveEmptyView(
                    icon: "folder.badge.questionmark",
                    title: "No Project Folders",
                    message: "Click \"Add Project Folder…\" to track a directory of Ableton Live projects."
                )
            } else {
                List(selection: $selection) {
                    ForEach(liveProjectManager.folders) { folder in
                        FolderRow(folder: folder)
                            .tag(folder.id)
                            .contextMenu {
                                Button("Rescan") {
                                    Task { await liveProjectManager.rescan(folderID: folder.id) }
                                }
                                Button("Remove Folder", role: .destructive) {
                                    if selection == folder.id { selection = nil }
                                    liveProjectManager.removeFolder(folder.id)
                                }
                            }

                        ForEach(folder.projects) { project in
                            ProjectSidebarRow(project: project)
                                .tag(project.id)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle("Projects")
        .frame(minWidth: 200)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let scanning = liveProjectManager.folders.first(where: { $0.isScanning }) {
                ScanProgressBar(folder: scanning)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    var detailContent: some View {
        if let sel = selection, isFolderID(sel), let folder = liveProjectManager.folders.first(where: { $0.id == sel }) {
            PluginsListView(plugins: folder.allUniquePlugins, folder: folder)
                .navigationTitle(folder.name)
        } else if let sel = selection, let project = liveProjectManager.project(withID: sel) {
            PluginsListView(plugins: project.plugins)
                .navigationTitle(project.name)
        } else {
            LiveEmptyView(
                icon: "doc.richtext",
                title: "Select a Folder or Project",
                message: "Choose a project folder or project from the sidebar to see its plugins."
            )
        }
    }
}

// MARK: - Folder Sidebar Row

struct FolderRow: View {
    @EnvironmentObject var pluginManager: PluginManager
    let folder: ProjectFolder

    var missingCount: Int {
        folder.allUniquePlugins.filter { !$0.isInstalled(in: pluginManager.plugins) }.count
    }

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if !folder.projects.isEmpty {
                    let n = folder.projects.count
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
    let plugins: [LiveProjectPlugin]
    var folder: ProjectFolder? = nil

    var missing: [LiveProjectPlugin]   { plugins.filter { !$0.isInstalled(in: pluginManager.plugins) } }
    var installed: [LiveProjectPlugin] { plugins.filter {  $0.isInstalled(in: pluginManager.plugins) } }

    var body: some View {
        if plugins.isEmpty {
            LiveEmptyView(
                icon: "waveform",
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
                                projectCount: folder?.projectCount(for: plugin)
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
                                projectCount: folder?.projectCount(for: plugin)
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
    let folder: ProjectFolder

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Text(folder.name)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("·").foregroundStyle(.tertiary)
                if folder.scanTotalCount > 0 {
                    ProgressView(
                        value: Double(folder.scanCurrentIndex),
                        total: Double(folder.scanTotalCount)
                    )
                    .progressViewStyle(.linear)
                    .frame(width: 120)
                    Text("\(folder.scanCurrentIndex) of \(folder.scanTotalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("·").foregroundStyle(.tertiary)
                    Text(folder.scanCurrentFile)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(folder.scanFoundCount) found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                    Text(folder.scanCurrentFile)
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
