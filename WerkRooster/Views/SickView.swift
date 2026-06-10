import SwiftUI

struct SickView: View {
    @EnvironmentObject private var vm: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ziek melden").font(.title3.bold())
            Text("Bel eerst je teamleider als het dringend is.")

            if let phone = vm.teamPhone, !phone.isEmpty {
                Button("Bel teamleider: \(phone)") {
                    let cleaned = phone.filter { $0.isNumber || $0 == "+" }
                    if let url = URL(string: "tel://\(cleaned)") {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Geen teamleider telefoonnummer beschikbaar.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}
