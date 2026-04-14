import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var vm: AppViewModel
    @State private var url = "https://"
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verbind met WerkRooster")
                .font(.title2.bold())
            Text("Voer je WordPress site URL en inloggegevens in.")
                .foregroundStyle(.secondary)

            TextField("WordPress site URL", text: $url)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
            TextField("Gebruikersnaam", text: $username)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
            SecureField("Wachtwoord", text: $password)
                .textFieldStyle(.roundedBorder)

            Button(vm.loading ? "Inloggen..." : "Inloggen") {
                Task { await vm.login(baseUrl: url.trimmingCharacters(in: .whitespaces), username: username, password: password) }
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
