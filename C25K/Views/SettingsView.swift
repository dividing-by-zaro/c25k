import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Calories.weightKey) private var weightLb = Calories.defaultWeightLb
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $weightLb, in: 70...400, step: 1) {
                        HStack {
                            Text("Body weight")
                            Spacer()
                            Text("\(Int(weightLb)) lb").foregroundStyle(Theme.muted).monospacedDigit()
                        }
                    }
                } footer: {
                    Text("Used to estimate calories for workouts you finish from now on.")
                }

                Section {
                    Button("Reset all progress", role: .destructive) { confirmingReset = true }
                } footer: {
                    Text("Your workouts are stored only on this iPhone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Erase every completed workout?", isPresented: $confirmingReset,
                                titleVisibility: .visible) {
                Button("Reset progress", role: .destructive) {
                    try? context.delete(model: Completion.self)
                    try? context.save()
                    dismiss()
                }
            } message: {
                Text("This can't be undone.")
            }
        }
        .presentationDetents([.medium])
    }
}
