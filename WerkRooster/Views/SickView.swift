import SwiftUI

struct SickView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ziek melden").font(.title3.bold())
            Text("Bel eerst je teamleider als het dringend is.")

            if vm.teamPhoneContacts.isEmpty {
                Text("Geen telefoonnummers beschikbaar.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.teamPhoneContacts) { contact in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contact.name)
                            .font(.headline)
                        Button {
                            let cleaned = contact.phone.filter { $0.isNumber || $0 == "+" }
                            if let url = URL(string: "tel://\(cleaned)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "phone.fill")
                                Text("Bel: \(contact.phone)")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()
        }
        .padding()
    }
}
