import SwiftUI
import SwiftData

// MARK: - Plan Tab

enum PlanTab: String, CaseIterable, Identifiable {
    case nourish = "NOURISH"
    case move = "MOVE"
    case supplements = "SUPPLEMENTS"

    var id: String { rawValue }
}

// MARK: - PlanView

struct PlanView: View {
    let cycleService: CycleService

    @Query(sort: \Phase.dayStart) private var phases: [Phase]
    @Query private var userPlanItems: [UserPlanItem]
    @Query private var userItemsHidden: [UserItemHidden]

    @State private var selectedTab: PlanTab = .nourish
    @State private var showProfile = false
    @State private var showPhaseDetail = false
    @State private var showAddItem = false

    private var currentSlug: String {
        cycleService.currentPhase?.phaseSlug ?? "menstrual"
    }

    private var currentPhase: Phase? {
        phases.first { $0.slug == currentSlug }
    }

    private var phaseColors: PhaseColors { PhaseColors.forSlug(currentSlug) }

    private var hiddenIds: Set<String> {
        Set(userItemsHidden.map(\.itemId))
    }

    private var customMeals: [UserPlanItem] {
        userPlanItems.filter { $0.category == .meal && $0.isActive }
    }

    private var customWorkouts: [UserPlanItem] {
        userPlanItems.filter { $0.category == .workout && $0.isActive }
    }

    private var customGrocery: [UserPlanItem] {
        userPlanItems.filter { $0.category == .grocery && $0.isActive }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    heroCard
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 4)

                    Section {
                        Group {
                            switch selectedTab {
                            case .nourish:
                                NourishView(
                                    phaseSlug: currentSlug,
                                    cycleService: cycleService,
                                    customItems: customMeals,
                                    customGrocery: customGrocery,
                                    hiddenIds: hiddenIds
                                )
                            case .move:
                                MoveView(
                                    phaseSlug: currentSlug,
                                    customWorkouts: customWorkouts,
                                    hiddenIds: hiddenIds
                                )
                            case .supplements:
                                PlanSupplementsView()
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
                    defaultCategory: selectedTab == .move ? .workout : selectedTab == .nourish ? .meal : .meal,
                    phaseSlug: currentSlug
                )
            }
            .sheet(isPresented: $showPhaseDetail) {
                NavigationStack {
                    if let phase = currentPhase {
                        PhaseDetailView(phase: phase, cycleService: cycleService)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") { showPhaseDetail = false }
                                }
                            }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Hero Card (tappable → phase detail sheet)

    private var heroCard: some View {
        Button { showPhaseDetail = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let phase = currentPhase {
                    VStack(alignment: .leading, spacing: 8) {
                        // Day counter
                        if let info = cycleService.currentPhase {
                            Text("Day \(info.cycleDay) of \(cycleService.cycleStats.avgCycleLength)")
                                .font(.nCaption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        // Phase title
                        Text(phase.heroTitle)
                            .font(.display(26))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        // Intention sentence (ET Book)
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

                    // Footer: Days range + informational phase dots
                    heroFooter(phase)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            .background(phaseColors.color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero Footer (Days X–Y + phase dots)

    private func heroFooter(_ phase: Phase) -> some View {
        let slugOrder = ["menstrual", "follicular", "ovulatory", "luteal"]

        return HStack {
            Text("Days \(phase.dayStart)\u{2013}\(phase.dayEnd)")
                .font(.nCaption2)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.5))

            Spacer()

            HStack(spacing: 6) {
                ForEach(slugOrder, id: \.self) { slug in
                    let isCurrent = currentSlug == slug
                    Circle()
                        .fill(isCurrent ? .white : .white.opacity(0.3))
                        .frame(width: isCurrent ? 8 : 6, height: isCurrent ? 8 : 6)
                }
            }
        }
    }

    // MARK: - Sticky Header (accent bar + label + sub-tabs)

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            // Phase label row with thick left accent bar
            HStack(spacing: 0) {
                // Thick vertical accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(phaseColors.color)
                    .frame(width: 4, height: 28)
                    .padding(.trailing, 10)

                // Phase dot + name
                Circle()
                    .fill(phaseColors.color)
                    .frame(width: 8, height: 8)

                Text(currentPhase?.name ?? "")
                    .font(.nCaption)
                    .fontWeight(.bold)
                    .foregroundStyle(phaseColors.color)
                    .padding(.leading, 6)

                if let info = cycleService.currentPhase {
                    Text("·")
                        .foregroundStyle(phaseColors.color.opacity(0.4))
                        .padding(.leading, 6)
                    Text("Day \(info.dayInPhase)")
                        .font(.nCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(phaseColors.color.opacity(0.7))
                        .padding(.leading, 4)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

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
        .background(Color(uiColor: .systemBackground))
    }
}
