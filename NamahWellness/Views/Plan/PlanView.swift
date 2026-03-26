import SwiftUI
import SwiftData

// MARK: - Plan Tab

enum PlanTab: String, CaseIterable, Identifiable {
    case nourish = "NOURISH"
    case move = "MOVE"
    case habits = "HABITS"

    var id: String { rawValue }
}

// MARK: - PlanView

struct PlanView: View {
    let cycleService: CycleService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query private var habits: [Habit]
    @Query private var userItemsHidden: [UserItemHidden]

    @State private var selectedTab: PlanTab = .nourish
    @State private var showProfile = false
    @State private var showAddItem = false
    @State private var showPhaseDetail = false
    @State private var selectedPhaseIndex: Int? = nil
    @State private var swipeDirection: Edge = .trailing

    private let slugOrder = ["menstrual", "follicular", "ovulatory", "luteal"]

    private var realCurrentSlug: String {
        cycleService.currentPhase?.phaseSlug ?? "menstrual"
    }

    private var currentPhaseIndex: Int {
        slugOrder.firstIndex(of: realCurrentSlug) ?? 0
    }

    private var displayedSlug: String {
        if let idx = selectedPhaseIndex { return slugOrder[idx] }
        return realCurrentSlug
    }

    private var displayedPhase: Phase? {
        phases.first { $0.slug == displayedSlug }
    }

    private var isViewingCurrentPhase: Bool {
        guard let idx = selectedPhaseIndex else { return true }
        return idx == currentPhaseIndex
    }

    private var phaseColors: PhaseColors { PhaseColors.forSlug(displayedSlug) }

    private var hiddenIds: Set<String> {
        Set(userItemsHidden.map(\.itemId))
    }

    private var customMeals: [Habit] {
        habits.filter { $0.category == .meal && $0.isActive }
    }

    private var customWorkouts: [Habit] {
        habits.filter { $0.category == .workout && $0.isActive }
    }

    private var customGrocery: [Habit] {
        habits.filter { $0.category == .grocery && $0.isActive }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    heroCard
                        .id(displayedSlug)
                        .transition(.asymmetric(
                            insertion: .move(edge: swipeDirection).combined(with: .opacity),
                            removal: .move(edge: swipeDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                        .contentShape(Rectangle())
                        .simultaneousGesture(phaseSwipeGesture)
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 4)

                    Section {
                        Group {
                            switch selectedTab {
                            case .nourish:
                                NourishView(
                                    phaseSlug: displayedSlug,
                                    cycleService: cycleService,
                                    customItems: customMeals,
                                    customGrocery: customGrocery,
                                    hiddenIds: hiddenIds
                                )
                            case .move:
                                MoveView(
                                    phaseSlug: displayedSlug,
                                    customWorkouts: customWorkouts,
                                    hiddenIds: hiddenIds
                                )
                            case .habits:
                                HabitsView(phaseSlug: displayedSlug)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    } header: {
                        stickyHeader
                    }
                }
            }
            .onAppear { selectedPhaseIndex = nil }
            .navigationDestination(isPresented: $showPhaseDetail) {
                if let phase = displayedPhase {
                    PhaseDetailView(phase: phase, cycleService: cycleService)
                }
            }
            .background(Color.paper.ignoresSafeArea())
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showAddItem = true } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(phaseColors.color)
                        }
                        Button { showProfile = true } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                NavigationStack {
                    ProfileView(cycleService: cycleService)
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddPlanItemSheet(
                    defaultCategory: selectedTab == .move ? .workout : selectedTab == .habits ? .habit : .meal,
                    phaseSlug: displayedSlug
                )
            }
        }
    }

    // MARK: - Phase Swipe Gesture

    private var phaseSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                let h = value.translation.width
                // Must be primarily horizontal
                guard abs(h) > abs(value.translation.height) * 1.5 else { return }
                guard abs(h) > 40 else { return }
                let idx = selectedPhaseIndex ?? currentPhaseIndex
                if h < 0 {
                    swipeDirection = .trailing
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedPhaseIndex = (idx + 1) % 4
                    }
                } else {
                    swipeDirection = .leading
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedPhaseIndex = (idx - 1 + 4) % 4
                    }
                }
            }
    }

    // MARK: - Hero Card (tappable → phase detail sheet)

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let phase = displayedPhase {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Days \(phase.dayStart)\u{2013}\(phase.dayEnd)")
                        .font(.nCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))

                    Text(phase.heroTitle)
                        .font(.display(26))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(phase.heroSubtitle)
                        .font(.prose(13))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 14)

                heroFooter(phase)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .background(phaseColors.color)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .leading) {
            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.leading, 6)
        }
        .overlay(alignment: .trailing) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.trailing, 6)
        }
        .onTapGesture { showPhaseDetail = true }
    }

    // MARK: - Hero Footer (day info + phase dots)

    private func heroFooter(_ phase: Phase) -> some View {
        HStack {
            if isViewingCurrentPhase, let info = cycleService.currentPhase {
                Text("Day \(info.dayInPhase) · Cycle day \(info.cycleDay)")
                    .font(.nCaption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(slugOrder, id: \.self) { slug in
                    let isSelected = displayedSlug == slug
                    Circle()
                        .fill(isSelected ? .white : .white.opacity(0.3))
                        .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)
                }
            }
        }
    }

    // MARK: - Sticky Header (accent bar + label + sub-tabs)

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            // "Today" button row — only visible when browsing another phase
            if !isViewingCurrentPhase {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedPhaseIndex = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9, weight: .semibold))
                            Text("TODAY")
                                .font(.nCaption2)
                                .fontWeight(.bold)
                                .tracking(1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(PhaseColors.forSlug(realCurrentSlug).color)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }

            // Sub-tab bar
            HStack(spacing: 0) {
                ForEach(PlanTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 0) {
                            Text(tab.rawValue)
                                .font(.nCaption)
                                .fontWeight(.semibold)
                                .tracking(1.5)
                                .foregroundStyle(selectedTab == tab ? phaseColors.color : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)

                            Rectangle()
                                .fill(selectedTab == tab ? phaseColors.color : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
        }
        .background(Color.paper)
    }
}
