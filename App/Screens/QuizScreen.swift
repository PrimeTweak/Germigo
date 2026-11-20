import SwiftUI

/// The daily quiz: three questions from the germ notes, each answer explained with its sources.
struct QuizScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var picked: Int?
    @State private var lastRight = false
    @State private var newBadges: [Badge] = []
    @State private var drag: CGFloat = 0

    private var finished: Bool { !questions.isEmpty && index >= questions.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if index < questions.count {
                            questionView(questions[index])
                        } else if finished {
                            summary
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                footer
            }
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard questions.isEmpty else { return }
        questions = model.startQuiz()
        index = min(model.quizAnswers().count, questions.count)
    }

    // MARK: - Frame

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(tr("Close"))
            HStack(spacing: 6) {
                ForEach(0..<questions.count, id: \.self) { step in
                    Capsule()
                        .fill(step < index || (step == index && picked != nil) ? palette.progress : palette.ink.opacity(0.1))
                        .frame(height: 7)
                }
            }
            Text(verbatim: "\(min(index + 1, max(questions.count, 1)))/\(questions.count)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(palette.inkSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var footer: some View {
        if finished {
            Button(tr("Done")) {
                dismiss()
            }
            .buttonStyle(PillButtonStyle(kind: .ink))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        } else if picked != nil {
            Button(index + 1 >= questions.count ? tr("See my score") : tr("Next")) {
                advance()
            }
            .buttonStyle(PillButtonStyle(kind: .ink))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Questions

    @ViewBuilder
    private func questionView(_ question: QuizQuestion) -> some View {
        kindChip(question.kind)
        if question.kind == .myth {
            if picked == nil {
                mythCard(question)
                Text(tr("Tap, or swipe the card: left for myth, right for fact."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .frame(maxWidth: .infinity)
                HStack(spacing: 12) {
                    Button(tr("Myth")) {
                        choose(0, question)
                    }
                    .buttonStyle(PillButtonStyle(kind: .coral, height: 64))
                    Button(tr("Fact")) {
                        choose(1, question)
                    }
                    .buttonStyle(PillButtonStyle(kind: .accent, height: 64))
                }
            } else {
                reveal(question)
            }
        } else {
            promptCard(question)
            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { item in
                    optionButton(item.element, at: item.offset, question: question)
                }
            }
            if picked != nil {
                reveal(question)
            }
        }
    }

    private func kindChip(_ kind: QuizKind) -> some View {
        let label: String
        let foreground: Color
        let background: Color
        switch kind {
        case .myth:
            label = tr("Myth or fact?")
            foreground = Color(hex: Swatch.grape)
            background = Color(hex: Swatch.lilacMist)
        case .whoAmI, .telltale, .weakness:
            label = tr("Who am I?")
            foreground = Color(hex: Swatch.night)
            background = Color(hex: Swatch.skyPale)
        case .showsUp, .lasts:
            label = tr("Timing")
            foreground = Color(hex: Swatch.forest)
            background = Color(hex: Swatch.mintAlt)
        case .microbe:
            label = tr("Virus or bacterium?")
            foreground = Color(hex: Swatch.night)
            background = Color(hex: Swatch.butter)
        case .antibiotics:
            label = tr("Antibiotics?")
            foreground = Color(hex: Swatch.night)
            background = Color(hex: Swatch.lilacPale)
        }
        return Text(label)
            .font(.caption.weight(.heavy))
            .kerning(1.2)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
            .padding(.top, 8)
    }

    private func mythCard(_ question: QuizQuestion) -> some View {
        let caught = model.count(of: question.germ.id) > 0
        return VStack(spacing: 18) {
            GermImage(germ: question.germ, size: 110, silhouette: !caught)
                .foregroundStyle(question.germ.deepTint)
            Text(question.prompt)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(alignment: .topLeading) {
            stamp(tr("Myth"), color: palette.coralInk)
                .opacity(Double(max(0, -drag) / 100))
        }
        .overlay(alignment: .topTrailing) {
            stamp(tr("Fact"), color: palette.successInk)
                .opacity(Double(max(0, drag) / 100))
        }
        .shadow(color: Color.black.opacity(palette.isDark ? 0 : 0.1), radius: 16, x: 0, y: 8)
        .offset(x: drag)
        .rotationEffect(.degrees(Double(drag / 25)))
        .gesture(
            DragGesture()
                .onChanged { value in
                    drag = value.translation.width
                }
                .onEnded { value in
                    if value.translation.width > 100 {
                        choose(1, question)
                    } else if value.translation.width < -100 {
                        choose(0, question)
                    }
                    withAnimation(.spring(duration: 0.3)) {
                        drag = 0
                    }
                }
        )
    }

    private func stamp(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.headline.weight(.heavy))
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay {
                RoundedRectangle(cornerRadius: 8).stroke(color, lineWidth: 2.5)
            }
            .padding(18)
            .accessibilityHidden(true)
    }

    private func promptCard(_ question: QuizQuestion) -> some View {
        Text(question.kind == .whoAmI ? tr("“%@”", question.prompt) : question.prompt)
            .font(.title3.weight(.bold))
            .foregroundStyle(palette.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 30)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity, minHeight: 170)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Color.black.opacity(palette.isDark ? 0 : 0.08), radius: 14, x: 0, y: 6)
    }

    private func optionButton(_ text: String, at offset: Int, question: QuizQuestion) -> some View {
        let answered = picked != nil
        let isRight = offset == question.answer
        let isPicked = offset == picked
        let border: Color = answered && isRight ? palette.successInk : (answered && isPicked ? palette.coralInk : .clear)
        return Button {
            choose(offset, question)
        } label: {
            HStack(spacing: 12) {
                Text(text)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                if answered && isRight {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(palette.successInk)
                } else if answered && isPicked {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.coralInk)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(border, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(answered)
        .accessibilityAddTraits(answered && isRight ? .isSelected : [])
    }

    // MARK: - Answer

    private func reveal(_ question: QuizQuestion) -> some View {
        let germ = question.germ
        let title: String
        if question.kind == .myth {
            title = question.answer == 1 ? tr("Fact!") : tr("Myth!")
        } else {
            title = lastRight ? tr("Right!") : tr("Not quite.")
        }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: lastRight ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(lastRight ? palette.successInk : palette.coralInk)
                Text(title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(lastRight ? palette.successInk : palette.coralInk)
            }
            if question.kind == .myth {
                Text(question.prompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(germ.myth.explanation.value)
                    .font(.body)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(germ.illness.value)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                ForEach(Array(revealFacts(question).enumerated()), id: \.offset) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.element.label)
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                        Text(item.element.value)
                            .font(.callout)
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Divider()
            Text(tr("Case file sources: %@", germ.sourcePublishers))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
            NavigationLink(value: germ) {
                Label(tr("Open the case file"), systemImage: "doc.text.magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
            }
            Text(lastRight ? tr("+%lld pts", RewardEngine.quizAnswerPoints) : tr("It will come back another day."))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(lastRight ? palette.successInk : palette.inkSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func revealFacts(_ question: QuizQuestion) -> [(label: String, value: String)] {
        let germ = question.germ
        switch question.kind {
        case .showsUp, .lasts:
            return [(label: tr("Shows up"), value: germ.showsUp.value), (label: tr("Lasts"), value: germ.lasts.value)]
        case .microbe, .antibiotics:
            guard let microbe = germ.microbe else { return [] }
            return [(label: tr("Behind it"), value: microbe.label), (label: tr("Antibiotics"), value: microbe.antibioticsNote)]
        case .whoAmI, .myth, .telltale, .weakness:
            return germ.facts.prefix(2).map { (label: $0.label.value, value: $0.value.value) }
        }
    }

    private func choose(_ choice: Int, _ question: QuizQuestion) {
        guard picked == nil else { return }
        if let outcome = model.answerQuiz(choice, to: question) {
            lastRight = outcome.right
            newBadges += outcome.newBadges
            if outcome.right {
                Haptics.success()
            } else {
                Haptics.thud()
            }
            withAnimation(.easeOut(duration: 0.2)) {
                picked = choice
            }
        } else {
            questions = model.startQuiz()
            index = min(model.quizAnswers().count, questions.count)
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            picked = nil
            drag = 0
            index += 1
        }
        if finished && !newBadges.isEmpty {
            SoundPlayer.shared.play(.badge)
        }
    }

    // MARK: - Score

    private var summary: some View {
        let answers = model.quizAnswers()
        let score = zip(questions, answers).filter { $0.0.answer == $0.1 }.count
        let streak = model.labStreak()
        let line: String
        if score == questions.count {
            line = tr("Perfect round.")
        } else if score == 0 {
            line = tr("The germs win this round.")
        } else {
            line = tr("Not bad at all.")
        }
        return VStack(spacing: 14) {
            Image(systemName: "flask.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(palette.night)
                .frame(width: 92, height: 92)
                .background(palette.lime, in: Circle())
                .padding(.top, 24)
            Text(tr("%1$lld of %2$lld", score, questions.count))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.ink)
            Text(line)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.inkSecondary)
            VStack(alignment: .leading, spacing: 0) {
                ValueRow(symbol: "plus.circle.fill", tint: palette.limeDeep, title: tr("Points"),
                         value: tr("+%lld pts", score * RewardEngine.quizAnswerPoints), showsChevron: false)
                Divider()
                ValueRow(symbol: "flame.fill", tint: palette.coralDeep, title: tr("Lab streak"),
                         value: trCount(streak, one: "%lld day", other: "%lld days"), showsChevron: false)
                if let next = model.nextLesson {
                    Divider()
                    ValueRow(symbol: "book.fill", tint: palette.lilac, title: next.article.title.value,
                             value: trCount(next.remaining, one: "%lld to go", other: "%lld to go"), showsChevron: false)
                }
                ForEach(newBadges) { badge in
                    Divider()
                    ValueRow(symbol: badge.symbol, tint: Color(hex: badge.tint), title: badge.title,
                             value: tr("New badge"), showsChevron: false)
                }
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
            Text(tr("A new quiz tomorrow."))
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
