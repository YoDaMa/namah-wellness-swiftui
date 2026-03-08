import SwiftUI
import SwiftData

struct ExerciseView: View {
    @Query(sort: \Workout.dayOfWeek) private var workouts: [Workout]
    @Query private var sessions: [WorkoutSession]
    @Query private var exercises: [CoreExercise]
    @Query private var completions: [WorkoutCompletion]

    @State private var selectedDayOfWeek: Int?
    @State private var showCoreExercises = false

    private var todayDow: Int {
        // Monday=0 through Sunday=6
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    private var currentDow: Int {
        selectedDayOfWeek ?? todayDow
    }

    private var currentWorkout: Workout? {
        workouts.first { $0.dayOfWeek == currentDow }
    }

    private var currentSessions: [WorkoutSession] {
        guard let workout = currentWorkout else { return [] }
        return sessions.filter { $0.workoutId == workout.id }
    }

    private var completedSessionIds: Set<String> {
        Set(completions.map(\.workoutId))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Workouts")
                        .font(.heading(32))
                        .foregroundStyle(.ink)

                    // Day selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(workouts, id: \.id) { workout in
                                Button {
                                    selectedDayOfWeek = workout.dayOfWeek
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(String(workout.dayLabel.prefix(3)))
                                            .font(.bodyMedium(9))
                                            .textCase(.uppercase)
                                            .tracking(1)
                                        if workout.dayOfWeek == todayDow {
                                            Circle()
                                                .fill(Color.spice)
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .foregroundStyle(currentDow == workout.dayOfWeek ? .white : .muted)
                                    .background(currentDow == workout.dayOfWeek ? Color.ink : .clear)
                                    .overlay(
                                        Rectangle()
                                            .stroke(currentDow == workout.dayOfWeek ? .clear : Color.border, lineWidth: 1)
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
                                .font(.heading(20))
                                .foregroundStyle(.ink)
                            Text(workout.dayFocus)
                                .font(.body(13))
                                .foregroundStyle(.muted)
                            if workout.isRestDay {
                                Text("REST DAY")
                                    .font(.bodyMedium(9))
                                    .textCase(.uppercase)
                                    .tracking(2)
                                    .foregroundStyle(.spice)
                                    .padding(.top, 4)
                            }
                        }
                    }

                    // Sessions
                    ForEach(currentSessions, id: \.id) { session in
                        sessionCard(session)
                    }

                    // Core exercises toggle
                    if !exercises.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCoreExercises.toggle()
                            }
                        } label: {
                            HStack {
                                Text("Daily Core Protocol")
                                    .font(.bodyMedium(11))
                                    .foregroundStyle(.ink)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.muted)
                                    .rotationEffect(showCoreExercises ? .degrees(180) : .zero)
                            }
                            .padding(14)
                            .background(Color.white)
                            .overlay(Rectangle().stroke(Color.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        if showCoreExercises {
                            ForEach(exercises, id: \.id) { exercise in
                                exerciseCard(exercise)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color.paper)
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
                    .foregroundStyle(completed ? .phaseF : .muted.opacity(0.4))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.timeSlot)
                        .font(.bodyMedium(9))
                        .foregroundStyle(.muted)
                        .textCase(.uppercase)
                        .tracking(1)
                    Text(session.title)
                        .font(.bodyMedium(13))
                        .foregroundStyle(completed ? .muted : .ink)
                        .strikethrough(completed)
                    if !session.sessionDescription.isEmpty {
                        Text(session.sessionDescription)
                            .font(.body(11))
                            .foregroundStyle(.muted)
                            .lineLimit(3)
                    }
                }
                Spacer()
            }
            .padding(12)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func exerciseCard(_ exercise: CoreExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.name)
                    .font(.bodyMedium(13))
                    .foregroundStyle(.ink)
                Spacer()
                Text(exercise.sets)
                    .font(.body(10))
                    .foregroundStyle(.muted)
            }
            Text(exercise.exerciseDescription)
                .font(.body(11))
                .foregroundStyle(.muted)
        }
        .padding(12)
        .background(Color.white)
        .overlay(Rectangle().stroke(Color.border, lineWidth: 1))
    }

    @Environment(\.modelContext) private var modelContext

    private func toggleSession(_ sessionId: String) {
        if let existing = completions.first(where: { $0.workoutId == sessionId }) {
            modelContext.delete(existing)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let today = formatter.string(from: Date())
            modelContext.insert(WorkoutCompletion(workoutId: sessionId, date: today))
        }
    }
}
