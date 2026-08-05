import SwiftUI

struct OperatorSalesView: View {
    @State private var service = OperatorSalesService()
    @Bindable var settings: OperatorSettingsStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Endpoint", text: $settings.endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Admin API Token", text: $settings.token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Connection")
                }

                Section {
                    if service.months.isEmpty {
                        Text(service.selectedMonth.isEmpty ? "No sales months found" : service.selectedMonth)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Month", selection: Binding(
                            get: { service.selectedMonth },
                            set: { newValue in
                                service.selectedMonth = newValue
                                Task {
                                    await service.fetch(month: newValue, settings: settings)
                                }
                            }
                        )) {
                            ForEach(service.months, id: \.self) { month in
                                Text(month).tag(month)
                            }
                        }
                    }
                } header: {
                    Text("Month")
                }

                Section {
                    if service.isLoading {
                        ProgressView()
                    }

                    if service.sortedSales.isEmpty && !service.isLoading {
                        Text("No sales recorded for this month")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(service.sortedSales) { sale in
                            HStack {
                                Text(sale.displayName)
                                Spacer()
                                Text(sale.count, format: .number)
                                    .font(.headline)
                                    .monospacedDigit()
                            }
                        }

                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(service.totalSales, format: .number)
                                .font(.headline)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Sales")
                } footer: {
                    Text("Bundle and Manuscript Analyst purchases are listed separately from project-type module sales.")
                }
            }
            .navigationTitle("WSP Sales")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await service.fetch(month: service.selectedMonth.isEmpty ? nil : service.selectedMonth, settings: settings)
                        }
                    }
                    .disabled(settings.token.isEmpty)
                }
            }
            .task {
                if !settings.token.isEmpty {
                    await service.fetch(month: nil, settings: settings)
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { service.errorMessage != nil },
                    set: { if !$0 { service.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { service.errorMessage = nil }
            } message: {
                Text(service.errorMessage ?? "")
            }
        }
    }
}
