//
//  EnsemblesConfiguration.swift
//  Writing Shed Pro
//
//  Created by Copilot on 03/07/2026.
//

import Foundation
import Ensembles

enum EnsemblesConfiguration {
    private static var didActivateLicense = false

    static func activateLicense() {
        guard !didActivateLicense else { return }
        EnsemblesLicense.activate("eyJlbWFpbCI6ImVhc2l3cml0ZXJAd3JpdGluZy1zaGVkLmNvbSIsImV4cGlyZXMiOiIyMDI2LTA4LTAzIiwiaXNzdWVkIjoiMjAyNi0wNy0wMyIsInR5cGUiOiJ0cmlhbCJ9.85UJZpy4MMyD67BBWkM25EvaOmhibMUjYLMlM7+FWbRHGiF7MFSoBoN+qu+YvrykiUx2eMQIsmoDkDOvKh3N9g==")
        #if DEBUG
        setLoggingLevel(.verbose)
        #endif
        didActivateLicense = true
    }
}
