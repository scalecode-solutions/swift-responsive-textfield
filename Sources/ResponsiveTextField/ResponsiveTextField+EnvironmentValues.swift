//
//  ResponsiveTextField+EnvironmentValues.swift
//  TextField
//
//  Created by Luke Redpath on 14/03/2021.
//

import CombineSchedulers
import SwiftUI

// MARK: - Environment Values

extension EnvironmentValues {
    @Entry var keyboardReturnKeyType: UIReturnKeyType = .default
    @Entry var textFieldFont: UIFont = .preferredFont(forTextStyle: .body)
    @Entry var textFieldPlaceholderColor: UIColor = .placeholderText
    @Entry var textFieldTextColor: UIColor = .label
    @Entry var textFieldTextAlignment: NSTextAlignment = .natural
    @Entry var firstResponderStateDemand: FirstResponderDemand? = nil
    @Entry public var responderScheduler: AnySchedulerOf<RunLoop> = .main
}
