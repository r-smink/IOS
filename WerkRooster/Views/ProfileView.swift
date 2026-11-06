import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let me = vm.me {
                    if let user = me.user {
                        GroupBox("Gebruikersgegevens") {
                            profileRow("Naam", user.displayName)
                            profileRow("E-mail", user.email)
                            profileRow("Locaties", me.locations?.map(\.name).joined(separator: ", ") ?? "Geen")
                        }
                    }

                    if let ical = me.icalUrl {
                        GroupBox("Agenda Synchronisatie") {
                            Text("Eén keer instellen: je rooster verschijnt daarna automatisch in de Agenda-app en blijft bijgewerkt.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            // webcal:// makes iOS offer "Abonneer" in the Agenda app instead of downloading a file
                            if let webcal = URL(string: ical.replacingOccurrences(of: "^https?://", with: "webcal://", options: .regularExpression)) {
                                Button {
                                    UIApplication.shared.open(webcal)
                                } label: {
                                    Label("Toevoegen aan Agenda", systemImage: "calendar.badge.plus")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 6)
                            }
                            HStack {
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
