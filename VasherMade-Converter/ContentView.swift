import SwiftUI
import AVFoundation
import Combine

// MARK: - App Colors
extension Color {
    static let electricBlue = Color(hex: "006FFF")
    static let customOrange = Color(hex: "FF8C00")

    static func dynamicAccent(for scheme: ColorScheme) -> Color {
        return scheme == .dark ? .customOrange : .electricBlue
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch hex.count {
        case 3: (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
        case 6: (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, int >> 24)
        default: (r, g, b, a) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Theme Logic
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Data Model
struct Conversion: Identifiable, Codable {
    var id = UUID()
    let inches: String
    let mm: String
}

@Observable
class ConversionManager {
    var currentInches: String = ""
    var currentMM: String = ""
    var history: [Conversion] = [] {
        didSet { saveToDefaults() }
    }
    
    var selectedTheme: AppTheme = .system {
        didSet { UserDefaults.standard.set(selectedTheme.rawValue, forKey: "AppTheme") }
    }
    
    let commonConversions: [Conversion] = [
        Conversion(inches: "1.0000", mm: "25.40"),
        Conversion(inches: "0.7500", mm: "19.05"),
        Conversion(inches: "0.5000", mm: "12.70"),
        Conversion(inches: "0.2500", mm: "6.35"),
        Conversion(inches: "0.1250", mm: "3.18"),
        Conversion(inches: "0.0625", mm: "1.59")
    ]
    
    private let storageKey = "SavedConversions"
    
    init() {
        loadFromDefaults()
        if let themeRaw = UserDefaults.standard.string(forKey: "AppTheme"),
           let theme = AppTheme(rawValue: themeRaw) {
            self.selectedTheme = theme
        }
    }
    
    func save() {
        guard !currentInches.isEmpty || !currentMM.isEmpty else { return }
        let entry = Conversion(inches: currentInches, mm: currentMM)
        history.insert(entry, at: 0)
    }
    
    func clearFields() {
        currentInches = ""
        currentMM = ""
    }
    
    func clearHistory() { history.removeAll() }
    
    private func saveToDefaults() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Conversion].self, from: data) {
            history = decoded
        }
    }
}

// MARK: - Custom Tab Component
struct TabItem {
    let icon: String
    let title: String
    var badge: Int = 0
}

struct CustomTabBar: View {
    @Binding var selection: Int
    @Environment(\.colorScheme) var colorScheme
    let items: [TabItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<items.count, id: \.self) { index in
                Button {
                    selection = index
                    triggerFeedback()
                } label: {
                    Image(systemName: items[index].icon)
                        .symbolVariant(selection == index ? .fill : .none)
                        .font(.system(size: 18, weight: .bold))
                        .overlay(alignment: .topTrailing) {
                            if items[index].badge > 0 {
                                Text("\(items[index].badge)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(Capsule().fill(Color.red))
                                    .fixedSize()
                                    .offset(x: 14, y: -8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if selection == index {
                                // UPDATED: Changed to Capsule for full rounding
                                Group {
                                    if colorScheme == .dark {
                                        Capsule().strokeBorder(Color.white, lineWidth: 1.5)
                                    } else {
                                        Capsule()
                                            .fill(Color.white)
                                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                    }
                                }
                                .matchedGeometryEffect(id: "tab", in: tabAnimation)
                            }
                        }
                        .foregroundColor(
                            selection == index ?
                            (colorScheme == .dark ? .white : .black) :
                            .gray
                        )
                }
                .accessibilityLabel(items[index].title)
                .accessibilityValue(items[index].badge > 0 ? "\(items[index].badge)" : "")
                .accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.primary.opacity(0.08))
        // UPDATED: Changed to Capsule for full rounding
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
    
    @Namespace private var tabAnimation
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var manager = ConversionManager()
    @State private var selectedTab: Int = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            VStack {
                CustomTabBar(selection: $selectedTab, items: [
                    TabItem(icon: "arrow.left.arrow.right", title: "Convert"),
                    TabItem(icon: "bookmark", title: "Saved", badge: manager.history.count),
                    TabItem(icon: "gearshape", title: "Settings")
                ])
            }
            .background(.ultraThinMaterial)
            
            Divider()
            
            ZStack {
                switch selectedTab {
                case 0: ConverterView(manager: manager).transition(.move(edge: .leading).combined(with: .opacity))
                case 1: SavedView(manager: manager).transition(.opacity)
                default: SettingsView(manager: manager).transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)
            
            Spacer(minLength: 0)
        }
        .preferredColorScheme(manager.selectedTheme.colorScheme)
    }
}

// MARK: - Converter View
struct ConverterView: View {
    @Bindable var manager: ConversionManager
    @Environment(\.colorScheme) var colorScheme
    @State private var activeField: Field = .inches
    @State private var activeModal: ModalType?
    enum Field { case inches, mm }

    var body: some View {
        VStack(spacing: 0) {
            VStack {
                Spacer()
                VStack(spacing: 24) {
                    inputSection(title: "INCHES", text: manager.currentInches, field: .inches, hasModals: true)
                    inputSection(title: "MM", text: manager.currentMM, field: .mm, hasModals: false)
                }
                .padding(.horizontal, 20)
                Spacer()
            }
            
            HStack(spacing: 16) {
                Button(action: { manager.clearFields(); triggerFeedback() }) {
                    Text("Clear All").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.red.opacity(0.15)).foregroundColor(.red).cornerRadius(16)
                }
                Button(action: { manager.save(); triggerFeedback() }) {
                    Text("Save").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(manager.currentInches.isEmpty ? Color.primary.opacity(0.1) : Color.dynamicAccent(for: colorScheme))
                        .foregroundColor(manager.currentInches.isEmpty ? .gray : (colorScheme == .dark ? .black : .white)).cornerRadius(16)
                }
                .disabled(manager.currentInches.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            
            CustomKeypad(text: activeField == .inches ? $manager.currentInches : $manager.currentMM) {
                if activeField == .inches { convertToMM(manager.currentInches) }
                else { convertToInches(manager.currentMM) }
            }
        }
        .sheet(item: $activeModal) { type in
            UnitInputView(type: type) { decimalResult in
                manager.currentInches = decimalResult
                convertToMM(decimalResult)
            }
        }
    }

    private func inputSection(title: String, text: String, field: Field, hasModals: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 12, weight: .black)).foregroundColor(.gray)
                Spacer()
                if hasModals {
                    HStack(spacing: 8) {
                        unitButton(title: "Fraction", type: .fraction)
                        unitButton(title: "Feet", type: .feet)
                        unitButton(title: "Yards", type: .yards)
                    }
                }
            }
            
            HStack(spacing: 12) {
                Text(text.isEmpty ? "0.00" : text)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(text.isEmpty ? .gray.opacity(0.5) : .primary)
                    .padding(.horizontal, 16).padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(activeField == field ? Color.dynamicAccent(for: colorScheme) : Color.gray.opacity(0.3), lineWidth: 2.5)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.05)))
                    )
                    .onTapGesture { activeField = field; triggerFeedback() }
                
                TextCopyButton(value: text)
            }
        }
    }

    private func unitButton(title: String, type: ModalType) -> some View {
        Button(title) { activeModal = type; triggerFeedback() }
        .font(Font(UIFont.systemFont(ofSize: 13, weight: .medium)))
        .foregroundColor(Color.dynamicAccent(for: colorScheme))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.dynamicAccent(for: colorScheme).opacity(0.15)).cornerRadius(8)
    }

    private func convertToMM(_ value: String) {
        guard let val = Double(value) else { manager.currentMM = ""; return }
        manager.currentMM = (val * 25.4).truncating(to: 8)
    }
    private func convertToInches(_ value: String) {
        guard let val = Double(value) else { manager.currentInches = ""; return }
        manager.currentInches = (val / 25.4).truncating(to: 8)
    }
}

// MARK: - Unit Input Modal
enum ModalType: String, Identifiable {
    case fraction, feet, yards
    var id: String { rawValue }
}

struct UnitInputView: View {
    let type: ModalType
    var onConfirm: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var value1: String = ""
    @State private var value2: String = ""
    @State private var activeField: Int = 1

    var title: String {
        switch type {
        case .fraction: return "Enter Fraction"
        case .feet: return "Enter Feet"
        case .yards: return "Enter Yards"
        }
    }
    
    private var isInputValid: Bool {
        if type == .fraction {
            return !value1.isEmpty && !value2.isEmpty
        } else {
            return !value1.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 15) {
                    Text(title).font(.headline).foregroundColor(.secondary).padding(.top, 20)
                    
                    VStack(spacing: 15) {
                        if type == .fraction {
                            modalDisplay(text: value1, placeholder: "Num", isActive: activeField == 1)
                                .onTapGesture { activeField = 1; triggerFeedback() }
                            Rectangle().frame(width: 60, height: 4).foregroundColor(Color.dynamicAccent(for: colorScheme)).cornerRadius(2)
                            modalDisplay(text: value2, placeholder: "Denom", isActive: activeField == 2)
                                .onTapGesture { activeField = 2; triggerFeedback() }
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 12) {
                                modalDisplay(text: value1, placeholder: "0", isActive: true)
                                Text(type == .feet ? "ft" : "yd").font(.title2).fontWeight(.bold).foregroundColor(Color.dynamicAccent(for: colorScheme))
                            }
                        }
                    }
                    .frame(maxWidth: 220)
                    .padding(.bottom, 20)
                }
                
                Spacer(minLength: 0)
                
                CustomKeypad(text: activeField == 1 ? $value1 : $value2) { }
                    .padding(.bottom, 12)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss(); triggerFeedback() } label: {
                        Image(systemName: "xmark").fontWeight(.bold).foregroundColor(.red)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        processResult()
                        dismiss()
                        triggerFeedback()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                            .foregroundColor(isInputValid ? Color.dynamicAccent(for: colorScheme) : .gray.opacity(0.4))
                    }
                    .disabled(!isInputValid)
                }
            }
        }
        .presentationDetents(type == .fraction ? [.height(580)] : [.height(460)])
        .presentationDragIndicator(.visible)
    }
    
    private func modalDisplay(text: String, placeholder: String, isActive: Bool) -> some View {
        Text(text.isEmpty ? placeholder : text)
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .foregroundColor(text.isEmpty ? .gray.opacity(0.3) : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? Color.dynamicAccent(for: colorScheme) : Color.gray.opacity(0.2), lineWidth: 2)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.05)))
            )
    }

    private func processResult() {
        guard let v1 = Double(value1) else { return }
        switch type {
        case .fraction:
            if let v2 = Double(value2), v2 != 0 { onConfirm((v1 / v2).truncating(to: 8)) }
        case .feet: onConfirm((v1 * 12).truncating(to: 8))
        case .yards: onConfirm((v1 * 36).truncating(to: 8))
        }
    }
}

// MARK: - Custom Keypad
struct CustomKeypad: View {
    @Binding var text: String
    var onChange: () -> Void
    
    let buttons = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "delete.left"]
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(buttons, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { label in
                        Button(action: { handlePress(label) }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.12))
                                if label == "delete.left" {
                                    Image(systemName: label).font(.title2).fontWeight(.bold)
                                } else {
                                    Text(label).font(.title).fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 60)
                        }
                        .buttonStyle(.plain).foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
    }
    
    private func handlePress(_ label: String) {
        triggerFeedback()
        if label == "delete.left" {
            if !text.isEmpty { text.removeLast() }
        } else if label == "." {
            if !text.contains(".") { text += "." }
        } else {
            if let dotIndex = text.firstIndex(of: "."), text.distance(from: dotIndex, to: text.endIndex) > 8 {
                return
            }
            text += label
        }
        onChange()
    }
}

// MARK: - Saved View
struct SavedView: View {
    @Bindable var manager: ConversionManager
    var body: some View {
        VStack(spacing: 0) {
            if manager.history.isEmpty {
                ContentUnavailableView("No Saved Items", systemImage: "bookmark", description: Text("Tap Save to keep your conversions."))
            } else {
                List {
                    ForEach(manager.history) { item in ConversionRow(item: item) }
                    .onDelete { manager.history.remove(atOffsets: $0); triggerFeedback() }
                }
                Button(action: { manager.clearHistory(); triggerFeedback() }) {
                    Text("Clear Saved Items").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.red.opacity(0.15)).foregroundColor(.red).cornerRadius(16)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Bindable var manager: ConversionManager
    var body: some View {
        List {
            Section("Appearance") {
                Picker("Theme", selection: $manager.selectedTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            }
            
            Section("Common Conversions") {
                ForEach(manager.commonConversions) { item in
                    ConversionRow(item: item)
                }
            }
        }
    }
}

// MARK: - Shared Row Component
struct ConversionRow: View {
    let item: Conversion
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.inches) in").font(.headline).fontWeight(.bold)
                Text(decimalToFraction(item.inches)).font(.caption).fontWeight(.medium).foregroundColor(.gray)
            }
            MiniTextCopyButton(value: item.inches)
            Spacer()
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 8) {
                Text("\(item.mm) mm").font(.headline).fontWeight(.bold).foregroundColor(Color.dynamicAccent(for: colorScheme))
                MiniTextCopyButton(value: item.mm)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Fraction Helper
func decimalToFraction(_ decimalString: String) -> String {
    guard let decimal = Double(decimalString) else { return "" }
    let precision = 64
    let wholeNumber = Int(decimal)
    let fractionalPart = decimal - Double(wholeNumber)
    if fractionalPart < (1.0 / Double(precision * 2)) {
        return wholeNumber > 0 ? "\(wholeNumber)\"" : ""
    }
    var numerator = Int(round(fractionalPart * Double(precision)))
    var denominator = precision
    while numerator % 2 == 0 && denominator % 2 == 0 {
        numerator /= 2
        denominator /= 2
    }
    let fractionString = "\(numerator)/\(denominator)\""
    return wholeNumber > 0 ? "\(wholeNumber) \(fractionString)" : fractionString
}

// MARK: - Shared Utilities
struct TextCopyButton: View {
    let value: String
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Button(action: { UIPasteboard.general.string = value; triggerFeedback() }) {
            Text("Copy").font(.system(size: 16, weight: .bold)).padding(.horizontal, 20).padding(.vertical, 16)
                .background(value.isEmpty ? Color.primary.opacity(0.05) : Color.dynamicAccent(for: colorScheme).opacity(0.2))
                .foregroundColor(value.isEmpty ? .gray.opacity(0.3) : Color.dynamicAccent(for: colorScheme)).cornerRadius(16)
        }
        .buttonStyle(.borderless).disabled(value.isEmpty)
    }
}

struct MiniTextCopyButton: View {
    let value: String
    @Environment(\.colorScheme) var colorScheme
    var body: some View {
        Button(action: { UIPasteboard.general.string = value; triggerFeedback() }) {
            Text("Copy").font(.system(size: 11, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 4)
                .background(Color.dynamicAccent(for: colorScheme).opacity(0.2)).foregroundColor(Color.dynamicAccent(for: colorScheme)).cornerRadius(4)
        }
        .buttonStyle(.borderless)
    }
}

extension Double {
    func truncating(to places: Int) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = places
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ""
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

func triggerFeedback() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    SoundManager.instance.playSound()
}

class SoundManager {
    static let instance = SoundManager()
    var player: AVAudioPlayer?
    func playSound() {
        guard let url = Bundle.main.url(forResource: "click", withExtension: "m4a") else { return }
        try? player = AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
