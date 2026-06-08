import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore

    @State private var testResult: String = ""
    @State private var testing = false

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Backend", selection: $settings.aiProvider) {
                    ForEach(AIProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: settings.aiProvider) { provider in
                    if settings.aiEndpoint.isBlank {
                        settings.aiEndpoint = provider.defaultEndpoint
                    }
                }

                if settings.aiProvider != .none {
                    TextField("Endpoint", text: $settings.aiEndpoint)
                        .help("e.g. http://localhost:8080 for llama.cpp")
                    TextField("Model", text: $settings.aiModel)
                    if settings.aiProvider.requiresAPIKey {
                        SecureField("API Key", text: $settings.aiApiKey)
                    }

                    HStack {
                        Button {
                            runTest()
                        } label: {
                            if testing {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Test Connection")
                            }
                        }
                        .disabled(testing)
                        Spacer()
                        if !testResult.isEmpty {
                            Text(testResult)
                                .font(.caption)
                                .foregroundStyle(testResult.hasPrefix("OK") ? .green : .red)
                                .lineLimit(2)
                        }
                    }
                }
            }

            if settings.aiProvider != .none {
                Section("Features") {
                    Toggle("Semantic search", isOn: $settings.enableSemanticSearch)
                    Toggle("Smart classification", isOn: $settings.enableSmartCategory)
                    Toggle("Title & summary generation", isOn: $settings.enableSummary)
                    Toggle("Smart deduplication", isOn: $settings.enableDedup)
                }

                Section("Dedup similarity threshold") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Threshold")
                            Spacer()
                            Text(String(format: "%.2f", settings.dedupThreshold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.dedupThreshold, in: 0.5...1.0, step: 0.01)
                    }
                    Text("Higher = stricter (only near-identical content is treated as duplicate).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Local Features (no backend required)") {
                Toggle("Intent recognition & action suggestions", isOn: $settings.enableIntentRecognition)
                Toggle("Format cleaning on capture", isOn: $settings.enableFormatCleaning)
                Toggle("Smart convert menu", isOn: $settings.enableSmartConvert)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }

    private func runTest() {
        testing = true
        testResult = ""
        Task {
            let result = await appState.testAIConnection()
            testResult = result
            testing = false
        }
    }
}
