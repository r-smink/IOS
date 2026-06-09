import SwiftUI

struct SickView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var reason = ""

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
                .buttonStyle(.bordered)
            }

            TextField("Toelichting (optioneel)", text: $reason, axis: .vertical)
                .textFieldStyle(.roundedBorder)

            Button(vm.loading ? "Verzenden..." : "Verzend ziekmelding") {
                Task { await vm.reportSick(reason: reason.isEmpty ? nil : reason) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.loading)

            if let status = vm.availabilityStatus, status.contains("Ziekmelding") {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            Spacer()
        }
        .padding()
    }
}
