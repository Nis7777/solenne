import SwiftUI

/// Route `.challenge`: the intro until the user opts in, then today's challenge day.
struct ChallengeIntroView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if model.data.challengeStart == nil {
            intro
        } else {
            ChallengeDayView()
        }
    }

    private var intro: some View {
        VStack(spacing: 0) {
            ScreenHeader()
            Spacer()
            Flame(size: 92)
            DottedTrail(total: 21, done: 0)
                .padding(.top, 18)
            SerifHeading("the 21-day *challenge.*", size: 36)
                .padding(.top, 26)
            Text("listen daily. keep the flame.")
                .font(.sans(14))
                .foregroundStyle(Palette.inkSoft)
                .padding(.top, 8)
            HStack(spacing: 8) {
                Chip(title: "daily audio", icon: "play.fill") {}
                Chip(title: "keep the streak", icon: "flame.fill") {}
            }
            .allowsHitTesting(false)
            .padding(.top, 18)
            Spacer()
            Spacer()
            Button("I'm in") {
                withAnimation { model.data.challengeStart = .now }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, 24)
            Button("maybe later") { dismiss() }
                .font(.sans(13))
                .foregroundStyle(Palette.inkSoft)
                .padding(.vertical, 14)
        }
        .solenneBackground()
    }
}

struct ChallengeDayView: View {
    @Environment(AppModel.self) private var model

    private var todayStory: Story? { model.forYou.first ?? LibraryContent.trending.first }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader {
                Button { model.push(.challengeProgress) } label: {
                    Label("Progress", systemImage: "calendar")
                }
                .buttonStyle(.secondary)
            }
            ScrollView {
                VStack(spacing: 0) {
                    EyebrowLabel("Day \(model.challengeDay) of 21")
                        .padding(.top, 12)
                    Flame(size: 60, lit: model.listenedToday)
                        .padding(.top, 20)
                    DottedTrail(total: 21, done: model.challengeDaysDone)
                        .padding(.top, 14)
                    Text(model.challengeDaysDone >= 21 ? "you did it" : "day \(model.challengeDay)")
                        .font(.serif(38))
                        .foregroundStyle(Palette.ink)
                        .padding(.top, 20)
                    EyebrowLabel(model.listenedToday ? "flame lit for today" : "starts now")
                        .padding(.top, 4)

                    Button { model.push(.reminders) } label: {
                        Label(reminderText, systemImage: "bell")
                            .font(.sans(12.5, .medium))
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(Capsule().fill(Color.white.opacity(0.8)))
                    }
                    .padding(.top, 18)

                    if let story = todayStory {
                        DayStoryCard(story: story, day: model.challengeDay)
                            .padding(.top, 22)
                    }
                }
                .padding(.horizontal, 24)
            }
            if let story = todayStory {
                Button("play day \(model.challengeDay) ✦") { model.play(story) }
                    .buttonStyle(.primary)
                    .padding(.horizontal, 24)
                if let reminder = model.data.reminder {
                    Text("today at \(reminder.label)")
                        .font(.sans(12))
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.vertical, 12)
                } else {
                    Spacer().frame(height: 16)
                }
            }
        }
        .solenneBackground()
    }

    private var reminderText: String {
        if let reminder = model.data.reminder { return "I'll remind you every day · \(reminder.label)" }
        return "Set a daily reminder"
    }
}

private struct DayStoryCard: View {
    let story: Story
    let day: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            story.cover
            LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(story.title)
                        .font(.serifItalic(20))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("day \(day) · \(story.minutes) min")
                        .font(.sans(11, .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "play.fill")
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.white))
            }
            .padding(16)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Row of dots leading to the flame; filled dots are completed days.
struct DottedTrail: View {
    let total: Int
    let done: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < done ? Palette.rose : Palette.mauve.opacity(0.3))
                    .frame(width: i == 0 ? 7 : 4, height: i == 0 ? 7 : 4)
            }
        }
        .accessibilityLabel("\(done) of \(total) days complete")
    }
}

// MARK: - Progress

struct ChallengeProgressView: View {
    @Environment(AppModel.self) private var model
    @State private var month = Date.now

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader()
            ScrollView {
                VStack(spacing: 18) {
                    Flame(size: 72, lit: model.currentStreak > 0)
                    Text("\(model.currentStreak)")
                        .font(.serif(64))
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text(streakCaption.uppercased())
                        .font(.sans(10.5, .semibold))
                        .tracking(2)
                        .foregroundStyle(Palette.inkSoft)
                        .padding(.horizontal, 16)
                        .frame(height: 30)
                        .background(Capsule().fill(Color.white.opacity(0.7)))
                    weekRow
                    HStack(spacing: 12) {
                        stat(model.daysThisMonth, "days this month")
                        stat(model.longestStreak, "longest streak")
                    }
                    MonthCalendar(month: $month, highlighted: model.listenDays)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .solenneBackground()
    }

    private var streakCaption: String {
        if model.currentStreak == 0 { return "listen today to start your streak" }
        if !model.listenedToday { return "listen today to keep your streak" }
        return model.currentStreak == 1 ? "day one. beautiful." : "\(model.currentStreak) days in a row"
    }

    private var weekRow: some View {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        return HStack(spacing: 10) {
            ForEach(days, id: \.self) { day in
                VStack(spacing: 6) {
                    Circle()
                        .fill(model.listenDays.contains(Day.key(day)) ? Palette.rose : Palette.mauve.opacity(0.22))
                        .frame(width: 28, height: 28)
                        .overlay {
                            if model.listenDays.contains(Day.key(day)) {
                                Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(.white)
                            }
                        }
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.sans(9.5, .medium))
                        .foregroundStyle(Palette.inkFaint)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text("\(value)").font(.serif(30)).foregroundStyle(Palette.ink)
            EyebrowLabel(label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glass(radius: 22, opacity: 0.6)
        .accessibilityElement(children: .combine)
    }
}

struct MonthCalendar: View {
    @Binding var month: Date
    let highlighted: Set<String>

    private var cal: Calendar { Calendar.current }

    private var cells: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        let count = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let days: [Date?] = (0..<count).map { cal.date(byAdding: .day, value: $0, to: interval.start) }
        return Array(repeating: nil, count: leading) + days
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                arrow("chevron.left", -1)
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()).lowercased())
                    .font(.serif(20))
                    .foregroundStyle(Palette.ink)
                Spacer()
                arrow("chevron.right", 1)
            }
            let symbols = cal.veryShortWeekdaySymbols
            let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.sans(9.5, .medium)).foregroundStyle(Palette.inkFaint)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let lit = highlighted.contains(Day.key(date))
                        let today = cal.isDateInToday(date)
                        Text("\(cal.component(.day, from: date))")
                            .font(.sans(12, lit ? .semibold : .regular))
                            .foregroundStyle(lit ? Color.white : Palette.ink)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(lit ? Palette.rose : Color.clear))
                            .overlay(Circle().strokeBorder(today ? Palette.ink : Color.clear, lineWidth: 1))
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
        .padding(18)
        .glass(radius: 26, opacity: 0.6)
    }

    private func arrow(_ symbol: String, _ delta: Int) -> some View {
        Button {
            if let m = cal.date(byAdding: .month, value: delta, to: month) { month = m }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.8)))
        }
        .accessibilityLabel(delta < 0 ? "Previous month" : "Next month")
    }
}
