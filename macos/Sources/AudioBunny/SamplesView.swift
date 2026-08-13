import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SamplesView: View {
    @EnvironmentObject var sampleManager: SampleManager
    @State private var showFolderPicker = false

    var body: some View {
        VStack(spacing: 0) {
            TabActionBar(title: "Samples") {
                if !sampleManager.folders.isEmpty {
                    Button(action: sampleManager.rescanAll) {
                        Label("Rescan All", systemImage: "arrow.clockwise")
                    }
                    .disabled(sampleManager.folders.contains { $0.isScanning })
                    .help("Rescan all sample folders")
                }
                Button {
                    showFolderPicker = true
                } label: {
                    Label("Add Folder…", systemImage: "folder.badge.plus")
                }
            }

            content
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls { sampleManager.addFolder(url) }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if sampleManager.folders.isEmpty {
            LiveEmptyView(
                icon: "waveform.circle",
                title: "No Folders Added",
                message: "Click \"Add Folder…\" to scan one or more directories for sound files."
            )
        } else {
            List {
                ForEach(sampleManager.folders) { folder in
                    Section {
                        if folder.isScanning && folder.samples.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                                Text("Scanning…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if folder.samples.isEmpty {
                            Text("No supported audio files found")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(folder.samples) { sample in
                                SampleRow(sample: sample)
                            }
                        }
                    } header: {
                        SampleFolderHeader(folder: folder)
                    }
                }
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - Folder Section Header

struct SampleFolderHeader: View {
    @EnvironmentObject var sampleManager: SampleManager
    let folder: SampleFolder
    @State private var isHovering = false

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.secondary)
            Text(folder.name)
                .fontWeight(.medium)
            Spacer()
            if folder.isScanning {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
            } else if isHovering {
                HStack(spacing: 10) {
                    Button {
                        sampleManager.rescan(folderID: folder.id)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Rescan this folder")

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([folder.url])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")

                    Button {
                        sampleManager.removeFolder(folder.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .help("Remove folder")
                }
                .foregroundStyle(.secondary)
            } else if !folder.samples.isEmpty {
                Text("\(folder.samples.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onHover { isHovering = $0 }
    }
}

// MARK: - Sample Row

struct SampleRow: View {
    @EnvironmentObject var sampleManager: SampleManager
    let sample: SoundFile

    private var isPlaying: Bool { sampleManager.currentlyPlayingID == sample.id }

    var body: some View {
        Button {
            sampleManager.togglePlay(sample)
        } label: {
            HStack {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle")
                    .font(.title3)
                    .foregroundStyle(isPlaying ? Color.accentColor : .secondary)
                    .frame(width: 22)
                Text(sample.name)
                    .lineLimit(1)
                Spacer()
                Text(sample.fileExtension)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
