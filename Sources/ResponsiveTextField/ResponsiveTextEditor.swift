//
//  ResponsiveTextEditor.swift
//

import Combine
import UIKit
import SwiftUI
import CombineSchedulers

// MARK: - Main Interface

/// A SwiftUI wrapper around UITextView that gives precise control over the responder state
/// and supports multiline text input.
///
/// This is the multiline counterpart to `ResponsiveTextField`. It provides the same level
/// of control over first responder state, text changes, and standard edit actions, but uses
/// `UITextView` under the hood for multiline text editing.
///
public struct ResponsiveTextEditor {
    /// The text editor placeholder string, displayed when the text is empty.
    let placeholder: String?

    /// A binding to the text state that will hold the typed text.
    let text: Binding<String>

    /// Can be used to programatically control the text editor's first responder state.
    ///
    /// When the binding's wrapped value is set, it will cause the text editor to try and become or resign first responder status
    /// either on first initialisation or on subsequent view updates.
    ///
    /// A wrapped value of `nil` indicates there is no demand (or any previous demand has been fulfilled).
    ///
    /// To detect when the text editor actually becomes or resigns first responder, pass in a `onFirstResponderStateChanged`
    /// handler.
    var firstResponderDemand: Binding<FirstResponderDemand?>?

    /// Allows for the text editor to be configured during creation.
    let configuration: Configuration

    /// Controls whether or not the text editor is editable, using the SwiftUI environment.
    /// To disable the text editor, you can use the standard SwiftUI `.disabled()`
    /// modifier.
    @Environment(\.isEnabled)
    var isEnabled: Bool

    /// Sets the keyboard return type - use the `.responsiveKeyboardReturnType()` modifier.
    @Environment(\.keyboardReturnKeyType)
    var returnKeyType: UIReturnKeyType

    /// Sets the text editor font - use the `.responsiveTextFieldFont()` modifier.
    ///
    /// - Note: if `adjustsFontForContentSizeCategory` is `true`, the font will only be set
    /// to this value once when the underlying text view is first created.
    ///
    @Environment(\.textFieldFont)
    var font: UIFont

    /// Sets the text editor placeholder color - use the `.responsiveTextFieldPlaceholderColor()` modifier.
    @Environment(\.textFieldPlaceholderColor)
    var placeholderColor: UIColor

    /// When `true`, configures the text view to automatically adjust its font based on the content size category.
    ///
    /// - Note: When set to `true`, the underlying text view will not respond to changes to the `textFieldFont`
    /// environment variable. If you want to implement your own dynamic/state-driven font changes you should set this
    /// to `false` and handle font size adjustment manually.
    ///
    var adjustsFontForContentSizeCategory: Bool

    /// Sets the text editor color - use the `.responsiveTextFieldTextColor()` modifier.
    @Environment(\.textFieldTextColor)
    var textColor: UIColor

    /// Sets the text editor alignment - use the `.responsiveTextFieldTextAlignment()` modifier.
    @Environment(\.textFieldTextAlignment)
    var textAlignment: NSTextAlignment

    @Environment(\.responderScheduler)
    private var responderScheduler: AnySchedulerOf<RunLoop>

    /// A callback function that will be called whenever the first responder state changes.
    var onFirstResponderStateChanged: FirstResponderStateChangeHandler?

    /// A callback function that will be called when the user deletes backwards.
    ///
    /// Takes a single argument - a `String` - which will be the current text when the user
    /// hits the delete key (but before any deletion occurs).
    ///
    /// If this is an empty string, it indicates that the user tapped delete inside an empty editor.
    var handleDelete: ((String) -> Void)?

    /// A callback function that can be used to control whether or not text should change.
    ///
    /// Takes two `String` arguments - the text prior to the change and the new text if
    /// the change is permitted.
    ///
    /// Return `true` to allow the change or `false` to prevent the change.
    var shouldChange: ((String, String) -> Bool)?

    /// A list of supported standard editing actions.
    ///
    /// When set, this will override the default standard edit actions for a `UITextView`. Leave
    /// set to `nil` if you only want to support the default actions.
    ///
    /// You can use this property and `standardEditActionHandler` to support both the
    /// range of standard editing actions and how each editing action should be handled.
    ///
    /// If you exclude an edit action from this list, any corresponding action handler set in
    /// any provided `standardEditActionHandler` will not be called.
    var supportedStandardEditActions: Set<StandardEditAction>?

    /// Can be set to provide custom standard editing action behaviour.
    ///
    /// When `nil`, all standard editing actions will result in the default `UITextView` behaviour.
    ///
    /// When set, any overridden actions will be called and if the action handler returns `true`, the
    /// default `UITextView` behaviour will also be called. If the action handler returns `false`,
    /// the default behaviour will not be called.
    ///
    /// If the provided type does not implement a particular editing action, the default `UITextView`
    /// behaviour will be called.
    var standardEditActionHandler: StandardEditActionHandling<UITextView>?

    public init(
        placeholder: String? = nil,
        text: Binding<String>,
        adjustsFontForContentSizeCategory: Bool = true,
        firstResponderDemand: Binding<FirstResponderDemand?>? = nil,
        configuration: Configuration = .empty,
        onFirstResponderStateChanged: FirstResponderStateChangeHandler? = nil,
        handleDelete: ((String) -> Void)? = nil,
        shouldChange: ((String, String) -> Bool)? = nil,
        supportedStandardEditActions: Set<StandardEditAction>? = nil,
        standardEditActionHandler: StandardEditActionHandling<UITextView>? = nil
    ) {
        self.placeholder = placeholder
        self.text = text
        self.firstResponderDemand = firstResponderDemand
        self.configuration = configuration
        self.adjustsFontForContentSizeCategory = adjustsFontForContentSizeCategory
        self.onFirstResponderStateChanged = onFirstResponderStateChanged
        self.handleDelete = handleDelete
        self.shouldChange = shouldChange
        self.supportedStandardEditActions = supportedStandardEditActions
        self.standardEditActionHandler = standardEditActionHandler
    }
}

// MARK: - UIViewRepresentable implementation

extension ResponsiveTextEditor: UIViewRepresentable {
    public func makeUIView(context: Context) -> _UnderlyingTextView {
        let textView = _UnderlyingTextView()
        configuration.configure(textView)
        textView.handleDelete = handleDelete
        textView.supportedStandardEditActions = supportedStandardEditActions
        textView.standardEditActionHandler = standardEditActionHandler
        textView.text = text.wrappedValue
        textView.isEditable = isEnabled
        textView.isSelectable = true
        textView.font = font
        textView.adjustsFontForContentSizeCategory = adjustsFontForContentSizeCategory
        textView.textColor = textColor
        textView.textAlignment = textAlignment
        textView.returnKeyType = returnKeyType
        textView.backgroundColor = .clear
        // Remove default text container insets for cleaner alignment
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        // Setup placeholder label
        let placeholderLabel = UILabel()
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.font = font
        placeholderLabel.textColor = placeholderColor
        placeholderLabel.text = placeholder
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isHidden = !text.wrappedValue.isEmpty
        placeholderLabel.tag = _placeholderTag
        textView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor)
        ])

        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(textEditor: self)
    }

    /// Will update the text view when the containing view triggers a body re-calculation.
    ///
    /// If the first responder state has changed, this may trigger the text editor to become or resign
    /// first responder.
    ///
    public func updateUIView(_ uiView: _UnderlyingTextView, context: Context) {
        uiView.isEditable = isEnabled
        uiView.isSelectable = true
        uiView.returnKeyType = returnKeyType
        uiView.textColor = textColor
        uiView.textAlignment = textAlignment

        if uiView.text != text.wrappedValue {
            uiView.text = text.wrappedValue
        }

        // Update placeholder
        if let placeholderLabel = uiView.viewWithTag(_placeholderTag) as? UILabel {
            placeholderLabel.text = placeholder
            placeholderLabel.textColor = placeholderColor
            placeholderLabel.font = font
            placeholderLabel.isHidden = !text.wrappedValue.isEmpty
        }

        if !adjustsFontForContentSizeCategory {
            // We should only support dynamic font changes using our own environment
            // value if dynamic type support is disabled otherwise we will override
            // the automatically adjusted font.
            uiView.font = font
        }

        switch (uiView.isFirstResponder, firstResponderDemand?.wrappedValue) {
        case (true, .shouldResignFirstResponder):
            responderScheduler.schedule { uiView.resignFirstResponder() }
        case (false, .shouldBecomeFirstResponder):
            responderScheduler.schedule { uiView.becomeFirstResponder() }
        case (_, nil):
            // If there is no demand then there's nothing to do.
            break
        default:
            // If the current responder state matches the demand then
            // the demand is already fulfilled so we can just reset it.
            resetFirstResponderDemand()
        }
    }

    fileprivate func resetFirstResponderDemand() {
        // Because the first responder demand will trigger a view
        // update when it is set, we need to wait until the next
        // runloop tick to reset it back to nil to avoid runtime
        // warnings.
        responderScheduler.schedule {
            firstResponderDemand?.wrappedValue = nil
        }
    }

    public class Coordinator: NSObject, UITextViewDelegate {
        var parent: ResponsiveTextEditor

        @Binding
        var text: String

        init(textEditor: ResponsiveTextEditor) {
            self.parent = textEditor
            self._text = textEditor.text
        }

        public func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
            if let canBecomeFirstResponder = parent.onFirstResponderStateChanged?.canBecomeFirstResponder {
                let shouldBeginEditing = canBecomeFirstResponder()
                if !shouldBeginEditing {
                    parent.resetFirstResponderDemand()
                }
                return shouldBeginEditing
            }
            return true
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFirstResponderStateChanged?(true)
            parent.resetFirstResponderDemand()
        }

        public func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
            if let canResignFirstResponder = parent.onFirstResponderStateChanged?.canResignFirstResponder {
                let shouldEndEditing = canResignFirstResponder()
                if !shouldEndEditing {
                    parent.resetFirstResponderDemand()
                }
                return shouldEndEditing
            }
            return true
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            parent.onFirstResponderStateChanged?(false)
            parent.resetFirstResponderDemand()
        }

        public func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if let shouldChange = parent.shouldChange {
                let currentText = textView.text ?? ""
                guard let newRange = Range(range, in: currentText) else {
                    return false
                }
                let newText = currentText.replacingCharacters(in: newRange, with: text)
                return shouldChange(currentText, newText)
            }
            return true
        }

        public func textViewDidChange(_ textView: UITextView) {
            self.text = textView.text ?? ""

            // Update placeholder visibility
            if let placeholderLabel = textView.viewWithTag(_placeholderTag) as? UILabel {
                placeholderLabel.isHidden = !textView.text.isEmpty
            }
        }
    }
}

/// Tag used to identify the placeholder label inside the text view.
private let _placeholderTag = 99887

// MARK: - Underlying UITextView subclass

public class _UnderlyingTextView: UITextView {
    var handleDelete: ((String) -> Void)?
    var supportedStandardEditActions: Set<StandardEditAction>?
    var standardEditActionHandler: StandardEditActionHandling<UITextView>?

    public override func deleteBackward() {
        handleDelete?(text ?? "")
        super.deleteBackward()
    }

    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard let supportedActions = supportedStandardEditActions else {
            return super.canPerformAction(action, withSender: sender)
        }
        switch action {
        case #selector(cut(_:)):
            return supportedActions.contains(.cut)
        case #selector(copy(_:)):
            return supportedActions.contains(.copy)
        case #selector(paste(_:)):
            return supportedActions.contains(.paste)
        case #selector(select(_:)):
            return supportedActions.contains(.select)
        case #selector(selectAll(_:)):
            return supportedActions.contains(.selectAll)
        case #selector(toggleBoldface(_:)):
            return supportedActions.contains(.toggleBoldface)
        case #selector(toggleItalics(_:)):
            return supportedActions.contains(.toggleItalics)
        case #selector(toggleUnderline(_:)):
            return supportedActions.contains(.toggleUnderline)
        case #selector(makeTextWritingDirectionLeftToRight(_:)):
            return supportedActions.contains(.makeTextWritingDirectionLeftToRight)
        case #selector(makeTextWritingDirectionRightToLeft(_:)):
            return supportedActions.contains(.makeTextWritingDirectionRightToLeft)
        case #selector(increaseSize(_:)):
            return supportedActions.contains(.increaseSize)
        case #selector(decreaseSize(_:)):
            return supportedActions.contains(.decreaseSize)
        case #selector(updateTextAttributes(conversionHandler:)):
            return supportedActions.contains(.updateTextAttributes)
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }
}

// MARK: - Standard editing action handling for UITextView

extension _UnderlyingTextView {
    typealias EditActionHandling = StandardEditActionHandling<UITextView>
    typealias EditActionHandler = EditActionHandling.StandardEditActionHandler

    private func performStandardEditActionHandler(
        sender: Any?,
        original: (Any?) -> Void,
        override: KeyPath<EditActionHandling, EditActionHandler?>
    ) {
        guard let actions = standardEditActionHandler else {
            original(sender)
            return
        }
        if let override = actions[keyPath: override] {
            let callOriginal = override(self, sender)
            if callOriginal { original(sender) }
        } else {
            original(sender)
        }
    }

    public override func cut(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.cut($0) },
            override: \.cut
        )
    }

    public override func copy(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.copy($0) },
            override: \.copy
        )
    }

    public override func paste(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.paste($0) },
            override: \.paste
        )
    }

    public override func select(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.select($0) },
            override: \.select
        )
    }

    public override func selectAll(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.selectAll($0) },
            override: \.selectAll
        )
    }

    public override func toggleBoldface(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.toggleBoldface($0) },
            override: \.toggleBoldface
        )
    }

    public override func toggleItalics(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.toggleItalics($0) },
            override: \.toggleItalics
        )
    }

    public override func toggleUnderline(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.toggleUnderline($0) },
            override: \.toggleUnderline
        )
    }

    public override func makeTextWritingDirectionLeftToRight(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.makeTextWritingDirectionLeftToRight($0) },
            override: \.makeTextWritingDirectionLeftToRight
        )
    }

    public override func makeTextWritingDirectionRightToLeft(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.makeTextWritingDirectionRightToLeft($0) },
            override: \.makeTextWritingDirectionRightToLeft
        )
    }

    public override func increaseSize(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.increaseSize($0) },
            override: \.increaseSize
        )
    }

    public override func decreaseSize(_ sender: Any?) {
        performStandardEditActionHandler(
            sender: sender,
            original: { super.decreaseSize($0) },
            override: \.decreaseSize
        )
    }

    public override func updateTextAttributes(conversionHandler: ([NSAttributedString.Key : Any]) -> [NSAttributedString.Key : Any]) {
        guard let actions = standardEditActionHandler else {
            super.updateTextAttributes(conversionHandler: conversionHandler)
            return
        }
        if let override = actions.updateTextAttributes {
            let callOriginal = override(self, conversionHandler)
            if callOriginal {
                super.updateTextAttributes(conversionHandler: conversionHandler)
            }
        } else {
            super.updateTextAttributes(conversionHandler: conversionHandler)
        }
    }
}

// MARK: - TextEditor Configurations

extension ResponsiveTextEditor {
    /// Provides a way of configuring the underlying UITextView inside a ResponsiveTextEditor.
    ///
    /// All ResponsiveTextEditors take a configuration which lets you package up common configurations
    /// that you use in your app. Configurations are composable and can be combined to create more
    /// detailed configurations.
    ///
    public struct Configuration: Sendable {
        var configure: @MainActor @Sendable (UITextView) -> Void

        public init(configure: @escaping @MainActor @Sendable (UITextView) -> Void) {
            self.configure = configure
        }

        public static func combine(_ configurations: Self...) -> Self {
            combine(configurations)
        }

        public static func combine(_ configurations: [Self]) -> Self {
            .init { textView in
                for configuration in configurations {
                    configuration.configure(textView)
                }
            }
        }
    }
}

// MARK: - Built-in Configuration Values

public extension ResponsiveTextEditor.Configuration {
    static let empty = Self { _ in }

    static let noCorrection = Self {
        $0.autocorrectionType = .no
        $0.autocapitalizationType = .none
        $0.spellCheckingType = .no
    }

    static let scrollDisabled = Self {
        $0.isScrollEnabled = false
    }
}

// MARK: - Previews

private struct TextEditorPreview: View {
    @State
    var text: String = ""

    @State
    var firstResponderDemand: FirstResponderDemand? = .shouldBecomeFirstResponder

    var body: some View {
        ResponsiveTextEditor(
            placeholder: "Type something...",
            text: $text,
            firstResponderDemand: $firstResponderDemand
        )
        .frame(minHeight: 100)
        .padding()
        .border(Color.gray.opacity(0.3))
        .padding()
    }
}

#Preview("Empty Editor") {
    TextEditorPreview()
}

#Preview("With Text") {
    TextEditorPreview(text: "Hello, this is a multiline\ntext editor with\nmultiple lines of text.")
}

#Preview("Styled Editor") {
    TextEditorPreview()
        .responsiveTextFieldFont(.preferredFont(forTextStyle: .title2))
        .responsiveTextFieldTextColor(.systemBlue)
}

#Preview("Disabled Editor") {
    TextEditorPreview(text: "This editor is disabled")
        .disabled(true)
}
