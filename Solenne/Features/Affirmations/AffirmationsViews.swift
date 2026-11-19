import SwiftUI

struct AffirmationsView: View {
    @Environment(AppModel.self) private var model
    @State private var drag: CGSize = .zero
    @State private var sharing: AffirmationDeck.Card?

    private var deck: [AffirmationDeck.Card] { AffirmationDeck.deck() }

    private var index: Int {
        model.data.affirmationDay == Day.key() ? model.data.affirmationIndex : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Affirmations").font(.serif(34)).foregroundStyle(Palette.ink)
                    EyebrowLabel("Come back once daily")
                }
                Spacer()
                Button { model.push(.savedAffirmations) } label: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Palette.mauve)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Color.white.opacity(0.8)))
                        .overlay(alignment: .topTrailing) {
                            if !model.data.savedAffirmations.isEmpty {
                                Text("\(model.data.savedAffirmations.count)")
                                    .font(.sans(9.5, .bold))
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 17, minHeight: 17)
                                    .background(Circle().fill(Palette.plum))
                                    .offset(x: 4, y: -4)
                            }
                        }
                }
                .accessibilityLabel("Saved affirmations, \(model.data.savedAffirmations.count)")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            Spacer()
            if index >= deck.count {
                completed
            } else {
                stack
            }
            Spacer()

            Button { model.push(.collection(.affirmation)) } label: {
                Label("Listen to affirmation tracks", systemImage: "headphones")
            }
            .buttonStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 110)
        }
        .solenneBackground()
        .sheet(item: Binding(get: { sharing.map(IdentifiedCard.init) }, set: { sharing = $0?.card })) { item in
            ShareActionsSheet(card: AffirmationShareCard(card: item.card), text: item.card.text)
        }
    }

    private var stack: some View {
        ZStack {
            ForEach(Array(deck.enumerated()).reversed(), id: \.offset) { i, card in
                if i >= index && i < index + 3 {
                    let depth = CGFloat(i - index)
                    AffirmationCardView(card: card, saved: model.data.savedAffirmations.contains(card.text)) {
                        toggleSave(card)
                    } onShare: {
                        sharing = card
                    }
                    .offset(x: i == index ? drag.width : 0, y: depth * 14 + (i == index ? drag.height * 0.2 : 0))
                    .scaleEffect(1 - depth * 0.05)
                    .rotationEffect(.degrees(i == index ? Double(drag.width / 18) : 0))
                    .opacity(depth > 1 ? 0.6 : 1)
                    .allowsHitTesting(i == index)
                    .gesture(swipe)
                }
            }
        }
        .padding(.horizontal, 28)
        .accessibilityAction(named: "Next affirmation") { next() }
    }

    private var swipe: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if abs(value.translation.width) > 110 {
                    withAnimation(.easeOut(duration: 0.25)) {
                        drag = CGSize(width: value.translation.width > 0 ? 600 : -600, height: value.translation.height)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        drag = .zero
                        next()
                    }
                } else {
                    withAnimation(.spring) { drag = .zero }
                }
            }
    }

    private func next() {
        if model.data.affirmationDay != Day.key() {
            model.data.affirmationDay = Day.key()
            model.data.affirmationIndex = 0
        }
        withAnimation { model.data.affirmationIndex += 1 }
    }

    private func toggleSave(_ card: AffirmationDeck.Card) {
        if let i = model.data.savedAffirmations.firstIndex(of: card.text) {
            model.data.savedAffirmations.remove(at: i)
        } else {
            model.data.savedAffirmations.insert(card.text, at: 0)
        }
    }

    private var completed: some View {
        VStack(spacing: 18) {
            SerifHeading("You've aligned with all of\n*your affirmations for today.*", size: 28)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let hours = max(1, Int(Day.nextMidnight(after: context.date).timeIntervalSince(context.date) / 3600))
                Text("COME BACK IN \(hours)H FOR YOUR\nNEXT SET OF CARDS")
                    .font(.sans(10.5, .semibold))
                    .tracking(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.inkSoft)
            }
            Button {
                withAnimation { model.data.affirmationIndex = 0 }
            } label: {
                Label("Redo", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

private struct IdentifiedCard: Identifiable {
    let card: AffirmationDeck.Card
    var id: String { card.text }
}

struct AffirmationCardView: View {
    let card: AffirmationDeck.Card
    let saved: Bool
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            HStack {
                Button(action: onSave) {
                    Image(systemName: saved ? "heart.fill" : "heart")
                        .foregroundStyle(saved ? Palette.rose : Palette.mauve)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.white))
                }
                .accessibilityLabel(saved ? "Unsave" : "Save")
                Spacer()
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Palette.ink)
                        .frame(width: 38, height: 38)
                }
                .accessibilityLabel("Share")
            }
            Spacer()
            Text(card.text)
                .font(.serifItalic(27))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Text(card.anchor.uppercased())
                .font(.sans(10, .semibold))
                .tracking(2)
                .foregroundStyle(Palette.inkSoft)
            Spacer()
        }
        .padding(22)
        .frame(height: 400)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Palette.paper)
                .shadow(color: Palette.plum.opacity(0.12), radius: 20, y: 10)
        )
        .sensoryFeedback(.impact(weight: .light), trigger: saved)
    }
}

struct AffirmationShareCard: View {
    let card: AffirmationDeck.Card

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.cream, Palette.blush], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 20) {
                Spacer()
                Text(card.text)
                    .font(.serifItalic(30))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Text(card.anchor.uppercased())
                    .font(.sans(10, .semibold))
                    .tracking(2)
                    .foregroundStyle(Palette.inkSoft)
                Spacer()
                Text("Solenne").font(.serif(18)).foregroundStyle(Palette.ink).padding(.bottom, 26)
            }
        }
        .frame(width: 320, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct SavedAffirmationsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "Saved *affirmations*")
            if model.data.savedAffirmations.isEmpty {
                Spacer()
                Text("Tap the heart on a card to keep it here.")
                    .font(.sans(14))
                    .foregroundStyle(Palette.inkSoft)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(model.data.savedAffirmations, id: \.self) { text in
                            let anchor = AffirmationDeck.pool.first { $0.text == text }?.anchor ?? ""
                            VStack(spacing: 12) {
                                HStack {
                                    Spacer()
                                    Button {
                                        model.data.savedAffirmations.removeAll { $0 == text }
                                    } label: {
                                        Image(systemName: "heart.fill").foregroundStyle(Palette.rose)
                                    }
                                    .accessibilityLabel("Remove")
                                }
                                Text(text)
                                    .font(.serifItalic(17))
                                    .foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if !anchor.isEmpty {
                                    Text(anchor.uppercased())
                                        .font(.sans(8.5, .semibold))
                                        .tracking(1.5)
                                        .foregroundStyle(Palette.inkSoft)
                                }
                            }
                            .padding(14)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.paper))
                        }
                    }
                    .padding(20)
                }
            }
        }
        .solenneBackground()
    }
}
