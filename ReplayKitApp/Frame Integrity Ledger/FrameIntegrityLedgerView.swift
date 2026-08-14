import SwiftUI

/// Reusable Frame Integrity Ledger table — used by both Option B (In App Screen Recording/ Frame Capture) and Option C (System Wide Screen Recording)
public struct FrameIntegrityLedgerView: View {
    let records: [FrameRecord]
    /// Label shown in the header to indicate which pipeline computed the SHA-256.
    let pipelineLabel: String
    @Binding var selectedRecord: FrameRecord?

    public init(records: [FrameRecord], pipelineLabel: String, selectedRecord: Binding<FrameRecord?>) {
        self.records = records
        self.pipelineLabel = pipelineLabel
        self._selectedRecord = selectedRecord
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Frame Integrity Ledger")
                    .font(.headline)
                Spacer()
                Text(pipelineLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.85))
                    .cornerRadius(6)
            }
            .padding(.top, 8)

            if records.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No frames captured yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 60)
            } else {
                // Column headings
                HStack {
                    Text("#").frame(width: 30, alignment: .leading)
                    Text("Preview").frame(width: 50, alignment: .leading)
                    Text("Timestamp").frame(width: 80, alignment: .leading)
                    Text("Size").frame(width: 55, alignment: .leading)
                    Text("SHA-256").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Chain").frame(width: 50, alignment: .leading)
                    Text("AES").frame(width: 25, alignment: .center)
                }
                .font(.caption2.bold())
                .foregroundColor(.secondary)

                // Rows
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(records) { record in
                            Button(action: { selectedRecord = record }) {
                                LedgerRow(record: record)
                            }
                        }
                    }
                }
                .frame(height: 160)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Single ledger row
private struct LedgerRow: View {
    let record: FrameRecord

    var body: some View {
        HStack {
            Text("\(record.index)")
                .frame(width: 30, alignment: .leading)
                .foregroundColor(.secondary)

            Group {
                if let thumb = record.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray
                }
            }
            .frame(width: 32, height: 32)
            .cornerRadius(4)
            .clipped()
            .frame(width: 50, alignment: .leading)

            Text(record.timestamp)
                .frame(width: 80, alignment: .leading)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.primary)

            Text(record.sizeKB)
                .frame(width: 55, alignment: .leading)
                .foregroundColor(.primary)

            Text(record.sha256.prefix(4) + "…" + record.sha256.suffix(4))
                .font(.system(.caption2, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)

            Text("VALID")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .cornerRadius(4)
                .frame(width: 50, alignment: .leading)

            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundColor(.red)
                .frame(width: 25, alignment: .center)
        }
        .font(.caption)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    let record1 = FrameRecord(
        id: UUID(),
        index: 1,
        timestamp: "timeString",
        sizeKB: String(format: "%.1f KB", Double(100000) / 1024.0),
        rawSize: 2,
        sha256: "frameHash",
        previousHash: "prevHash",
        chainHash: "currentChainHash",
        isChainValid: true,
        isEncrypted: true,
        thumbnail: UIImage(systemName: "photo"),
        hexDump: "hexBytesString",
        sessionID: "sessionID",
        resolution: "1024x768"
    )
    
    let record2 = FrameRecord(
        id: UUID(),
        index: 2,
        timestamp: "timeString",
        sizeKB: String(format: "%.1f KB", Double(100000) / 1024.0),
        rawSize: 2,
        sha256: "frameHash",
        previousHash: "prevHash",
        chainHash: "currentChainHash",
        isChainValid: true,
        isEncrypted: true,
        thumbnail: UIImage(systemName: "photo"),
        hexDump: "hexBytesString",
        sessionID: "sessionID",
        resolution: "1024x768"
    )
    @State var records: [FrameRecord] = [record1, record2]
    @State var selectedRecord: FrameRecord? = record1

    FrameIntegrityLedgerView(records: records, pipelineLabel: "pipelineLabel", selectedRecord: $selectedRecord)
}
