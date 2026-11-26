import SwiftUI

/// Build your own workout out of run, walk and interval blocks.
struct BuilderView: View {
    var onStart: (Workout) -> Void

    @State private var plan = CustomPlan.load()
    /// The block being edited, or a new one not yet added.
    @State private var editing: Block?

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 4, trailing: 4))

            Section {
                if plan.blocks.isEmpty {
                    Text("Add a run, a walk or some intervals to get started.")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .padding(.vertical, 8)
                }
                ForEach(Array(plan.blocks.enumerated()), id: \.element.id) { i, block in
                    Button { editing = block } label: {
                        BlockRow(block: block, isSkipped: plan.foreverIndex.map { i > $0 } ?? false)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { plan.blocks.remove(atOffsets: $0) }
                .onMove { plan.blocks.move(fromOffsets: $0, toOffset: $1) }
            } header: {
                Text("Blocks")
            } footer: {
                Text(footer)
            }

            Section {
                addButtons
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .scrollContentBackground(.hidden)
        .background(GlowBackground())
        .statusBarScrim()
        .bottomBar {
            Button { onStart(plan.workout) } label: {
                Label("Start workout", systemImage: "play.fill")
            }
            .buttonStyle(PillButtonStyle(fill: plan.blocks.isEmpty ? Theme.sage : Theme.pine))
            .disabled(plan.blocks.isEmpty)
        }
        .sheet(item: $editing) { block in
            BlockEditor(block: block,
                        isNew: !plan.blocks.contains { $0.id == block.id },
                        onSave: save,
                        onDelete: { plan.blocks.removeAll { $0.id == block.id } })
        }
        .onChange(of: plan) { _, plan in plan.save() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BUILD YOUR OWN")
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.75))
            Text(CustomPlan.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            if !plan.blocks.isEmpty && !plan.isOpenEnded {
                SegmentStrip(workout: plan.workout, spacing: 2,
                             color: { $0 == .run ? .white : .white.opacity(0.4) })
                    .frame(height: 6)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        let n = plan.blocks.count
        guard n > 0 else { return "No blocks yet" }
        let blocks = "\(n) block\(n == 1 ? "" : "s")"
        if plan.isOpenEnded {
            return plan.fixedSeconds > 0
                ? "\(blocks) | \(Fmt.duration(plan.fixedSeconds)), then intervals until you stop"
                : "\(blocks) | intervals until you stop"
        }
        return "\(blocks) | \(Fmt.duration(plan.fixedSeconds)) total"
    }

    private var footer: String {
        if let i = plan.foreverIndex, i < plan.blocks.count - 1 {
            return "Blocks after a repeat-forever interval won't play. Drag to reorder, swipe to delete."
        }
        return "Tap a block to change it. Drag to reorder, swipe to delete."
    }

    private var addButtons: some View {
        HStack(spacing: 10) {
            ForEach(Block.Kind.allCases, id: \.self) { kind in
                Button { editing = .new(kind) } label: {
                    VStack(spacing: 6) {
                        Image(systemName: kind.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text("Add \(kind.name.lowercased())")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Theme.pine)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save(_ block: Block) {
        if let i = plan.blocks.firstIndex(where: { $0.id == block.id }) {
            plan.blocks[i] = block
        } else {
            plan.blocks.append(block)
        }
    }
}

private struct BlockRow: View {
    var block: Block
    var isSkipped: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: block.kind.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(block.kind == .walk ? Theme.pine : .white)
                .frame(width: 40, height: 40)
                .background(block.kind == .walk ? Theme.mint : (block.kind == .run ? Theme.forest : Theme.fern),
                            in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(block.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            if block.loopsForever {
                Image(systemName: "infinity")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.fern)
            }
        }
        .padding(.vertical, 4)
        .opacity(isSkipped ? 0.4 : 1)
        .contentShape(Rectangle())
    }
}

/// Sheet for setting a block's lengths.
private struct BlockEditor: View {
    @State var block: Block
    var isNew: Bool
    var onSave: (Block) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                switch block.kind {
                case .run, .walk:
                    Section {
                        durationPicker("Length", $block.seconds, BlockOptions.blockSeconds)
                    } footer: {
                        if block.kind == .run {
                            Text("On runs of 10 minutes or more, you'll hear how far you are every 5 minutes, up to 40.")
                        }
                    }
                case .interval:
                    Section {
                        durationPicker("Run for", $block.runSeconds, BlockOptions.intervalSeconds)
                        durationPicker("Then walk for", $block.walkSeconds, BlockOptions.intervalSeconds)
                    }
                    Section {
                        Toggle("Repeat until I stop", isOn: $block.forever.animation())
                            .tint(Theme.pine)
                        if !block.forever {
                            Stepper("\(block.repeats) time\(block.repeats == 1 ? "" : "s")",
                                    value: $block.repeats, in: BlockOptions.repeats)
                        }
                    } footer: {
                        Text(block.forever
                             ? "The intervals keep going until you tap Finish. Put this block last."
                             : "\(Fmt.duration(block.totalSeconds)) in all.")
                    }
                }

                if !isNew {
                    Section {
                        Button("Delete block", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New \(block.kind.name.lowercased())" : block.kind.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Done") {
                        onSave(block)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(32)
    }

    private func durationPicker(_ label: String, _ value: Binding<Int>, _ options: [Int]) -> some View {
        Picker(label, selection: value) {
            ForEach(options, id: \.self) { Text(Fmt.duration($0)).tag($0) }
        }
        .tint(Theme.pine)
    }
}
