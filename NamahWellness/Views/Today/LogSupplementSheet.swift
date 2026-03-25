import SwiftUI
import SwiftData

struct LogSupplementSheet: View {
    let phaseColor: Color

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService

    @Query private var definitions: [SupplementDefinition]
    @Query private var userSupplements: [UserSupplement]
    @Query private var supplementLogs: [SupplementLog]

    private var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    private var activeRegimen: [UserSupplement] { userSupplements.filter { $0.isActive } }

    private var todayLogIds: Set<String> {
        Set(supplementLogs.filter { $0.date == today && $0.taken }.map(\.userSupplementId))
    }

    var body: some View {
        NavigationStack {
            List {
                let activeIds = Set(activeRegimen.compactMap(\.supplementId))
                let extraDefs = definitions.filter { !activeIds.contains($0.id) }

                if !extraDefs.isEmpty {
                    Section("Available Supplements") {
                        ForEach(extraDefs, id: \.id) { def in
                            let isLogged = todayLogIds.contains("extra-\(def.id)")
                            Button {
                                toggleExtraSupplement(def)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(def.name)
                                            .font(.nSubheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        if let brand = def.brand, !brand.isEmpty {
                                            Text(brand)
                                                .font(.nCaption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: isLogged ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isLogged ? phaseColor : Color(uiColor: .tertiaryLabel))
                                }
                            }
                        }
                    }
                }

                if !activeRegimen.isEmpty {
                    Section("In Your Plan") {
                        ForEach(activeRegimen, id: \.id) { userSup in
                            let def = userSup.supplementId.flatMap { supId in definitions.first { $0.id == supId } }
                            let isTaken = todayLogIds.contains(userSup.id)
                            Button {
                                toggleSupplement(userSup)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(def?.name ?? "Unknown")
                                            .font(.nSubheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.primary)
                                        Text("\(Int(userSup.dosage)) \(def?.servingUnit ?? "dose")")
                                            .font(.nCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isTaken ? phaseColor : Color(uiColor: .tertiaryLabel))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleSupplement(_ userSup: UserSupplement) {
        if let existing = supplementLogs.first(where: { $0.userSupplementId == userSup.id && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": existing.id, "userSupplementId": userSup.id,
                                           "date": today, "taken": existing.taken],
                                    modelContext: modelContext)
        } else {
            let log = SupplementLog(userSupplementId: userSup.id, date: today, taken: true)
            modelContext.insert(log)
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": log.id, "userSupplementId": userSup.id,
                                           "date": today, "taken": true],
                                    modelContext: modelContext)
        }
    }

    private func toggleExtraSupplement(_ def: SupplementDefinition) {
        let extraId = "extra-\(def.id)"
        if let existing = supplementLogs.first(where: { $0.userSupplementId == extraId && $0.date == today }) {
            existing.taken.toggle()
            existing.loggedAt = Date()
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": existing.id, "userSupplementId": extraId,
                                           "date": today, "taken": existing.taken],
                                    modelContext: modelContext)
        } else {
            let log = SupplementLog(userSupplementId: extraId, date: today, taken: true)
            modelContext.insert(log)
            syncService.queueChange(table: "supplementLogs", action: "upsert",
                                    data: ["id": log.id, "userSupplementId": extraId,
                                           "date": today, "taken": true],
                                    modelContext: modelContext)
        }
    }
}
