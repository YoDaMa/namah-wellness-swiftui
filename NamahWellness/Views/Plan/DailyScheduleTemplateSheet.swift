import SwiftUI

struct DailyScheduleTemplateSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Every Weekday \u{2014} Your Repeating Rhythm")
                            .font(.display(22, relativeTo: .title3))

                        Text("Same rhythm every weekday. Slot your specific workout from the day cards into the 10:30am and 4pm windows. Everything else is fixed.")
                            .font(.prose(13))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Timeline
                    timeline
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .navigationTitle("Daily Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Timeline

    private var timeline: some View {
        ZStack(alignment: .topLeading) {
            // Vertical line
            GeometryReader { geo in
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(width: 1)
                    .padding(.leading, 5) // center on 11pt dot
                    .padding(.top, 6)
                    .frame(height: geo.size.height - 12)
            }

            // Timeline rows
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Self.items) { item in
                    timelineRow(item)
                }
            }
        }
    }

    private func timelineRow(_ item: TimelineItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Dot
            Circle()
                .fill(item.type.dotColor)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
                .padding(.top, 3)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Time + tag
                HStack(spacing: 8) {
                    Text(item.time)
                        .font(.sans(11))
                        .fontWeight(.medium)

                    Text(item.tag)
                        .font(.sans(9))
                        .fontWeight(.medium)
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(item.type.tagForeground)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(item.type.tagBackground)
                        .clipShape(Capsule())
                }

                // Body + optional emphasis
                Group {
                    if let emphasis = item.emphasis {
                        Text(item.body + " ")
                            .font(.prose(12))
                            .foregroundStyle(.secondary) +
                        Text(emphasis)
                            .font(.prose(12))
                            .italic()
                            .foregroundStyle(.primary.opacity(0.6))
                    } else {
                        Text(item.body)
                            .font(.prose(12))
                            .foregroundStyle(.secondary)
                    }
                }
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Data

private enum TimelineItemType {
    case fast, move, eat, core

    var dotColor: Color {
        switch self {
        case .fast: return .secondary
        case .move: return .phaseF
        case .eat:  return .phaseO
        case .core: return .spice
        }
    }

    var tagForeground: Color {
        switch self {
        case .fast: return .secondary
        case .move: return .phaseF
        case .eat:  return .phaseO
        case .core: return .spice
        }
    }

    var tagBackground: Color {
        switch self {
        case .fast: return Color(uiColor: .tertiarySystemFill)
        case .move: return .phaseFSoft
        case .eat:  return .phaseOSoft
        case .core: return Color.spice.opacity(0.1)
        }
    }
}

private struct TimelineItem: Identifiable {
    let id = UUID()
    let type: TimelineItemType
    let time: String
    let tag: String
    let body: String
    let emphasis: String?
}

extension DailyScheduleTemplateSheet {
    fileprivate static let items: [TimelineItem] = [
        TimelineItem(
            type: .fast,
            time: "7\u{2013}9am",
            tag: "Fasting Window",
            body: "Black coffee (1 cup max), water, electrolytes if needed (pinch of salt + squeeze of lemon in water). No food. This is where morning fat burning happens.",
            emphasis: "Especially effective for South Asian insulin metabolism \u{2014} several hours of low insulin before first meal makes a measurable difference."
        ),
        TimelineItem(
            type: .move,
            time: "9:00am",
            tag: "Morning Mobility \u{00B7} 10 min",
            body: "On the floor before sitting at your desk. Hip circles, cat-cow, spinal twist, thoracic rotations. Addresses the hip flexor tightness that\u{2019}s causing your knee pain.",
            emphasis: "Non-negotiable \u{2014} this is what makes the rest of your workday comfortable."
        ),
        TimelineItem(
            type: .core,
            time: "9:10am",
            tag: "Core Protocol \u{00B7} 10 min \u{00B7} South Asian Priority",
            body: "Dead bugs 3\u{00D7}10, bird dogs 3\u{00D7}10, plank 3\u{00D7}20sec, hollow body hold 2\u{00D7}15sec. Same sequence every single morning. Done fasted, before your first meal \u{2014} this timing maximizes visceral fat reduction. See the core exercise guide below for form details.",
            emphasis: "This 10 minutes done daily will visibly flatten your stomach faster than almost anything else you can do."
        ),
        TimelineItem(
            type: .move,
            time: "10:30am",
            tag: "Primary Workout \u{00B7} 15\u{2013}25 min",
            body: "See your day\u{2019}s specific session below. Treadmill or strength. Between meetings \u{2014} if a call runs over, push to 11am, don\u{2019}t skip. This is your main calorie-burning block.",
            emphasis: nil
        ),
        TimelineItem(
            type: .eat,
            time: "12:00pm",
            tag: "Eating Window Opens \u{00B7} First Meal",
            body: "Lunch from your phase meal plan. Eat slowly. You\u{2019}ve been fasted since 8pm \u{2014} let this be a real meal, not rushed.",
            emphasis: "South Asian note: always eat protein and fat before carbs within the same meal \u{2014} it blunts the glucose spike significantly."
        ),
        TimelineItem(
            type: .move,
            time: "12:45pm",
            tag: "Post-Meal Walk \u{00B7} 10\u{2013}15 min",
            body: "Treadmill, flat, easy pace immediately after lunch.",
            emphasis: "A 10-minute post-meal walk reduces the glucose spike by up to 30% \u{2014} this is especially high-impact for South Asian metabolism and directly targets abdominal fat storage. Do not skip this one."
        ),
        TimelineItem(
            type: .eat,
            time: "3:30pm",
            tag: "Afternoon Snack \u{00B7} Under 220 cal",
            body: "From your phase plan. Protein + fat focused. Prevents dinner bingeing. Keeps blood sugar stable through end-of-workday slump.",
            emphasis: "Especially critical during luteal phase when cravings peak."
        ),
        TimelineItem(
            type: .move,
            time: "4:00pm",
            tag: "Afternoon Session \u{00B7} 10\u{2013}15 min",
            body: "Your day\u{2019}s second movement block \u{2014} see day cards. Usually lower body finisher, second walk, or oblique work. Breaks up afternoon screen time. Keeps metabolism elevated into the evening.",
            emphasis: nil
        ),
        TimelineItem(
            type: .eat,
            time: "7:00pm",
            tag: "Dinner \u{00B7} Main Meal",
            body: "Biggest, most satisfying meal. Always lead with protein before carbs. Eating window closes at 8pm. From your phase meal plan.",
            emphasis: nil
        ),
        TimelineItem(
            type: .eat,
            time: "7:45pm",
            tag: "Optional Closer \u{00B7} Under 100 cal",
            body: "2\u{2013}3 squares 85% dark chocolate, small handful of berries, or chamomile tea with honey. Window closes at 8pm sharp.",
            emphasis: nil
        ),
        TimelineItem(
            type: .fast,
            time: "8:00pm+",
            tag: "Fasting Window Begins",
            body: "Water and herbal tea only. You ate well. Go lay down. You earned it.",
            emphasis: nil
        ),
    ]
}
