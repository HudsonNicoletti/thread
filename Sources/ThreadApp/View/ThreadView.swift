import AppKit
import SwiftUI

struct ThreadView: View {
    @ObservedObject var controller: ThreadController
    @FocusState private var focusDraft: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Thread").font(.title.bold())
                        Text("Remember what you were doing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let active = controller.active {
                        activeCard(active)
                    } else {
                        newThreadForm
                    }

                    if !controller.parked.isEmpty {
                        section("Parked") {
                            ForEach(controller.parked) { thread in
                                threadRow(thread, action: "Resume") { controller.resume(thread) }
                            }
                        }
                    }

                    if !controller.completed.isEmpty {
                        section("Done") {
                            ForEach(controller.completed.prefix(5)) { thread in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    Text(thread.intention).lineLimit(1)
                                    Spacer()
                                    if let date = thread.finishedAt {
                                        Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(18)
            }
            Divider()
            HStack {
                Text("Local only").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit Thread") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
            }
            .padding(12)
        }
        .frame(width: 380, height: 520)
    }

    private var newThreadForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("What are you doing now?", text: $controller.draft)
                .textFieldStyle(.roundedBorder)
                .focused($focusDraft)
                .onSubmit(controller.setIntention)
                .accessibilityLabel("Current intention")
            TextField("Optional note", text: $controller.note)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Optional note")
            Button("Start Thread", action: controller.setIntention)
                .buttonStyle(.borderedProminent)
                .disabled(controller.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func activeCard(_ thread: WorkThread) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current thread", systemImage: "circle.dotted")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(thread.intention).font(.title2.weight(.semibold))
            if !thread.note.isEmpty { Text(thread.note).foregroundStyle(.secondary) }
            HStack {
                Button("Park & New", action: controller.park)
                Button("Complete", action: controller.complete).buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }

    private func threadRow(_ thread: WorkThread, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.intention).lineLimit(1)
                if !thread.note.isEmpty { Text(thread.note).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            Button(action, action: perform)
            Button(role: .destructive) { controller.removeParked(thread) } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(thread.intention)")
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
