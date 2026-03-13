import SwiftUI
import SwiftData

struct MoveView: View {
    let phaseSlug: String
    let customWorkouts: [UserPlanItem]
    let hiddenIds: Set<String>

    @Environment(\.modelContext) private var modelContext
    @Environment(SyncService.self) private var syncService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var workoutSessions: [WorkoutSession]
    @Query private var exercises: [CoreExercise]

    @State private var selectedDayOfWeek: Int?
    @State private var showAddWorkout = false

    private var phase: Phase? { phases.first { $0.slug == phaseSlug } }
    private var phaseColor: Color { PhaseColors.forSlug(phaseSlug).color }
    private var phaseColors: PhaseColors { PhaseColors.forSlug(phaseSlug) }

    private var todayDow: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private var currentDow: Int { selectedDayOfWeek ?? todayDow }

    private var currentWorkout: Workout? {
        workouts.first { $0.dayOfWeek == currentDow }
    }

    private var currentSessions: [WorkoutSession] {
        guard let workout = currentWorkout else { return [] }
        return workoutSessions.filter { $0.workoutId == workout.id && !hiddenIds.contains($0.id) }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }

    private var todayStr: String {
        dateFormatter.string(from: Date())
    }

    private var customWorkoutsForDay: [UserPlanItem] {
        customWorkouts.filter { $0.appliesOnDate(todayStr) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Exercise intensity indicator
            if let p = phase {
                intensityBar(p.exerciseIntensity)
            }

            // 7-day week strip
            weekStrip

            // Selected day workout
            if let workout = currentWorkout {
                workoutContent(workout)
            }

            // Daily core protocol
            if !exercises.isEmpty {
                coreProtocol
            }
        }
    }

    // MARK: - Intensity Bar

    private func intensityBar(_ intensity: String) -> some View {
        let level: Int = {
            switch intensity.lowercased() {
            case "low": return 1
            case "moderate", "medium": return 2
            case "high": return 3
            default: return 2
            }
        }()

        return HStack(spacing: 12) {
            Text("EXERCISE INTENSITY")
                .namahLabel()

            Spacer()

            HStack(spacing: 6) {
                Text(intensity)
                    .font(.nCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(phaseColor)

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < level ? phaseColor : phaseColor.opacity(0.2))
                            .frame(width: 16, height: 10)
                    }
                }
            }
        }
        .padding(14)
        .background(phaseColors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK")
                .namahLabel()

            HStack(spacing: 0) {
                ForEach(workouts, id: \.id) { workout in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDayOfWeek = workout.dayOfWeek
                        }
                    } label: {
                        let isSelected = currentDow == workout.dayOfWeek
                        let isToday = workout.dayOfWeek == todayDow

                        VStack(spacing: 6) {
                            Text(String(workout.dayLabel.prefix(3)).uppercased())
                                .font(.sans(10))
                                .fontWeight(.semibold)
                                .tracking(0.5)

                            Circle()
                                .fill(isSelected ? phaseColor : Color(uiColor: .tertiarySystemFill))
                                .frame(width: 8, height: 8)

                            if isToday {
                                Text("TODAY")
                                    .font(.sans(7))
                                    .fontWeight(.bold)
                                    .tracking(0.5)
                                    .foregroundStyle(.spice)
                            } else {
                                Color.clear.frame(height: 10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? phaseColor : .secondary)
                        .background(
                            isSelected
                                ? phaseColor.opacity(0.08)
                                : .clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Workout Content

    private func workoutContent(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.dayLabel)
                    .font(.display(22, relativeTo: .title3))
                Text(workout.dayFocus)
                    .font(.nSubheadline)
                    .foregroundStyle(.secondary)
            }

            if workout.isRestDay {
                HStack(spacing: 8) {
                    Image(systemName: "moon.fill")
                        .font(.sans(14))
                        .foregroundStyle(phaseColor)
                    Text("Rest Day — recover and restore")
                        .font(.prose(14))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(phaseColors.soft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(currentSessions, id: \.id) { session in
                    sessionCard(session)
                        .contextMenu {
                            Button(role: .destructive) {
                                hideItem(session.id, type: .workout)
                            } label: {
                                Label("Hide This Workout", systemImage: "eye.slash")
                            }
                        }
                }

                // Custom workouts for this day
                ForEach(customWorkoutsForDay, id: \.id) { item in
                    customWorkoutCard(item)
                }
            }
        }
    }

    private func sessionCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.timeSlot)
                .font(.nCaption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text(session.title)
                .font(.nSubheadline)
                .fontWeight(.semibold)

            if !session.sessionDescription.isEmpty {
                Text(session.sessionDescription)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Custom Workout Card

    private func customWorkoutCard(_ item: UserPlanItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let time = item.time {
                    Text(time)
                        .font(.nCaption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                Text("CUSTOM")
                    .font(.sans(8))
                    .fontWeight(.bold)
                    .tracking(1)
                    .foregroundStyle(phaseColor)
            }

            Text(item.title)
                .font(.nSubheadline)
                .fontWeight(.semibold)

            if let sub = item.subtitle, !sub.isEmpty {
                Text(sub)
                    .font(.nCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                if let focus = item.workoutFocus {
                    Text(focus)
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }
                if let dur = item.duration {
                    Text(dur)
                        .font(.nCaption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(phaseColors.soft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(phaseColor.opacity(0.3), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                item.isActive = false
                syncService.queueChange(
                    table: "userPlanItems", action: "upsert",
                    data: ["id": item.id, "isActive": false], modelContext: modelContext
                )
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    // MARK: - Hide Item

    private func hideItem(_ itemId: String, type: PlanItemCategory) {
        let hidden = UserItemHidden(itemId: itemId, itemType: type)
        modelContext.insert(hidden)
        syncService.queueChange(
            table: "userItemsHidden", action: "upsert",
            data: ["id": hidden.id, "itemId": itemId], modelContext: modelContext
        )
    }

    // MARK: - Core Protocol

    private var coreProtocol: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DAILY CORE PROTOCOL")
                    .namahLabel()
                Text("Every day, regardless of phase")
                    .font(.prose(12))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.nSubheadline)
                                .fontWeight(.medium)
                            Text(exercise.exerciseDescription)
                                .font(.nCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(exercise.sets)
                            .font(.nCaption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if index < exercises.count - 1 {
                        Divider()
                            .padding(.horizontal, 14)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
