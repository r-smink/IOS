import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verbind met WerkRooster")
                .font(.title2.bold())
            Text("Voer je inloggegevens in.")
                .foregroundStyle(.secondary)

            TextField("Gebruikersnaam", text: $username)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
            SecureField("Wachtwoord", text: $password)
                .textFieldStyle(.roundedBorder)

            Button(vm.loading ? "Inloggen..." : "Inloggen") {
                Task { await vm.login(username: username, password: password) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.loading)
            .frame(maxWidth: .infinity, alignment: .center)

            if let error = vm.error {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .padding(20)
        .frame(maxWidth: 520)
    }
}
