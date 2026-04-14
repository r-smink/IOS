import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let me = vm.me {
                    GroupBox("Gebruikersgegevens") {
                        profileRow("Naam", me.user.displayName)
                        profileRow("E-mail", me.user.email)
                        profileRow("Locaties", me.locations.map(\.name).joined(separator: ", "))
                    }

                    if let ical = me.icalUrl, let url = URL(string: ical) {
                        GroupBox("Agenda Synchronisatie") {
                            Text("Voeg je rooster toe aan je agenda via deze persoonlijke iCal-link.")
                                .foregroundStyle(.secondary)
                            HStack {
                                Link(destination: url) {
                                    Label("Openen", systemImage: "arrow.up.right.square")
                                }
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = ical
                                } label: {
                                    Label("Kopiëren", systemImage: "doc.on.doc")
                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func profileRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .padding(.vertical, 2)
    }
}
