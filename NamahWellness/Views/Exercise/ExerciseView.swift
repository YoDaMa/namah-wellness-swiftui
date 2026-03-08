import SwiftUI
import SwiftData

struct ExerciseView: View {
    let cycleService: CycleService

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var sessions: [WorkoutSession]
    @Query private var exercises: [CoreExercise]
    @Query private var completions: [WorkoutCompletion]

    @State private var selectedDayOfWeek: Int?
    @State private var showCoreExercises = false

    private var todayDow: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private var currentDow: Int { selectedDayOfWeek ?? todayDow }
    private var currentWorkout: Workout? { workouts.first { $0.dayOfWeek == currentDow } }
    private var currentSessions: [WorkoutSession] {
        guard let workout = currentWorkout else { return [] }
        return sessions.filter { $0.workoutId == workout.id }
    }
    private var completedSessionIds: Set<String> { Set(completions.map(\.workoutId)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let phase = cycleService.currentPhase {
                        PhaseHeaderView(phase: phase)
                    }

                    // Day selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(workouts, id: \.id) { workout in
                                Button {
                                    selectedDayOfWeek = workout.dayOfWeek
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(String(workout.dayLabel.prefix(3)))
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .textCase(.uppercase)
                                        if workout.dayOfWeek == todayDow {
                                            Circle()
                                                .fill(Color.spice)
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(currentDow == workout.dayOfWeek ? .white : .secondary)
                                    .background(currentDow == workout.dayOfWeek ? Color.primary : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(currentDow == workout.dayOfWeek ? .clear : Color(uiColor: .separator), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Current day header
                    if let workout = currentWorkout {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.dayLabel)
                                .font(.title3)
                                .fontDesign(.serif)
                            Text(workout.dayFocus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if workout.isRestDay {
                                Text("REST DAY")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .textCase(.uppercase)
                                    .tracking(2)
                                    .foregroundStyle(.spice)
                                    .padding(.top, 2)
                            }
                        }
                    }

                    // Sessions
                    ForEach(currentSessions, id: \.id) { session in
                        sessionCard(session)
                    }

                    // Core exercises
                    if !exercises.isEmpty {
                        DisclosureGroup(isExpanded: $showCoreExercises) {
                            ForEach(exercises, id: \.id) { exercise in
                                exerciseCard(exercise)
                            }
                        } label: {
                            Text("Daily Core Protocol")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Workouts")
        }
    }

    private func sessionCard(_ session: WorkoutSession) -> some View {
        let completed = completedSessionIds.contains(session.id)
        return Button {
            toggleSession(session.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(completed ? Color.phaseF : Color(uiColor: .tertiaryLabel))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.timeSlot)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text(session.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(completed ? .secondary : .primary)
                        .strikethrough(completed)
                    if !session.sessionDescription.isEmpty {
                        Text(session.sessionDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func exerciseCard(_ exercise: CoreExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(exercise.sets)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(exercise.exerciseDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func toggleSession(_ sessionId: String) {
        if let existing = completions.first(where: { $0.workoutId == sessionId }) {
            modelContext.delete(existing)
        } else {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            modelContext.insert(WorkoutCompletion(workoutId: sessionId, date: f.string(from: Date())))
        }
    }
}
