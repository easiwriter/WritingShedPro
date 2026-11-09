import SwiftUI

struct OperatorSalesView: View {
    @State private var service = OperatorSalesService()
    @State private var showClearVerificationConfirmation = false
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

                    if service.appleSales.isEmpty && !service.isLoading {
                        Text(
                            service.appleSalesStatus?.isConfigured == false
                                ? "Apple Sales and Trends is not configured"
                                : "No Apple purchase reports imported for this month"
                        )
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(service.appleSales) { sale in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(sale.displayName)
                                    Spacer()
                                    Text(sale.purchases, format: .number)
                                        .font(.headline)
                                        .monospacedDigit()
                                }
                                if sale.refunds > 0 {
                                    Text("\(sale.refunds) refund\(sale.refunds == 1 ? "" : "s") • \(sale.netPurchases) net")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        HStack {
                            Text("Total Purchases")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(service.totalApplePurchases, format: .number)
                                .font(.headline)
                                .monospacedDigit()
                        }
                        if service.totalAppleRefunds > 0 {
                            HStack {
                                Text("Total Refunds")
                                Spacer()
                                Text(service.totalAppleRefunds, format: .number)
                                    .monospacedDigit()
                            }
                        }
                    }

                    Button("Sync Apple Reports") {
                        Task {
                            await service.syncAppleSales(settings: settings)
                        }
                    }
                    .disabled(
                        service.isLoading
                            || service.selectedMonth.isEmpty
                            || service.appleSalesStatus?.isConfigured == false
                    )

                    if let status = service.appleSalesStatus, status.importedDays > 0 {
                        Text("\(status.importedDays) daily report\(status.importedDays == 1 ? "" : "s") imported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apple Purchases")
                } footer: {
                    Text("Authoritative Sales and Trends reports from Apple. Purchases and refunds are shown separately. Apple publishes daily reports the following day.")
                }

                Section {
                    if let metrics = service.trialMetrics {
                        metricRow("Trials Started", value: metrics.starts)
                        metricRow("Scheduled 10-Day Ends", value: metrics.scheduledEnds)
                        metricRow("Observed Expiries", value: metrics.observedExpiries)
                        metricRow("Converted to Full Access", value: metrics.conversions)
                        metricRow("Active at Period End", value: metrics.activeAtMonthEnd)
                    } else if !service.isLoading {
                        Text("No trial telemetry available")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Free Trials")
                } footer: {
                    Text("Scheduled ends are calculated from each anonymous trial start. Observed expiries count devices that opened the app after the trial ended. No Apple ID or personal information is collected.")
                }

                Section {
                    if service.sortedSales.isEmpty && !service.isLoading {
                        Text("No device transaction reports for this month")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(service.sortedSales) { sale in
                            metricRow(sale.displayName, value: sale.count)
                        }
                    }
                } header: {
                    Text("Device Transaction Telemetry")
                } footer: {
                    Text("Diagnostic reports received from app launches. These are not authoritative sales totals and may be incomplete.")
                }

                Section {
                    if service.verificationFailures.isEmpty && !service.isLoading {
                        Text("No transaction verification failures")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(service.verificationFailures) { failure in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(failure.productDisplayName)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(failure.categoryDisplayName)
                                        .font(.caption)
                                        .foregroundStyle(
                                            failure.isResolved
                                                ? Color.secondary
                                                : failure.category == "appleRejected"
                                                    ? Color.red
                                                    : Color.orange
                                        )
                                }

                                Text(failure.reason)
                                    .font(.callout)

                                Text(
                                    "\(failure.maskedTransactionID) • HTTP \(failure.statusCode) • \(failure.attemptCount) attempt\(failure.attemptCount == 1 ? "" : "s")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Text(failure.lastSeenDate, format: .dateTime)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }

                        Button("Clear Verification Diagnostics", role: .destructive) {
                            showClearVerificationConfirmation = true
                        }
                    }
                } header: {
                    Text("Transaction Verification")
                } footer: {
                    Text("Attempt counts are repeated reports of the same transaction, not numbers of sales. Apple Rejected indicates that Apple could not find or validate the production transaction. Temporary Failure indicates that Apple verification or the service was unavailable.")
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
            .confirmationDialog(
                "Clear all verification diagnostics?",
                isPresented: $showClearVerificationConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear Diagnostics", role: .destructive) {
                    Task {
                        await service.clearVerificationFailures(settings: settings)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes diagnostic retry records only. It does not delete recorded sales.")
            }
        }
    }

    @ViewBuilder
    private func metricRow(_ title: String, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value, format: .number)
                .font(.headline)
                .monospacedDigit()
        }
    }
}
