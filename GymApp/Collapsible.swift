import SwiftUI

/// Lembra quais cartões estão abertos (vale entre aberturas do app).
@Observable
final class CollapseStore {
    static let shared = CollapseStore()
    private let key = "ui.expandedCards"
    private(set) var expanded: Set<String>

    private init() { expanded = Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }

    func isOpen(_ id: String) -> Bool { expanded.contains(id) }
    func toggle(_ id: String) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        UserDefaults.standard.set(Array(expanded), forKey: key)
    }
}

/// Cartão recolhível: fechado mostra só o título e um resumo curto; um toque abre o cartão completo.
/// Aberto, os toques voltam a funcionar como antes (abrir detalhes, menus…); a seta no topo recolhe.
struct Collapsible<Content: View>: View {
    let id: String
    let title: String
    let icon: String
    var summary: String = ""
    var tint: Color = Theme.accent
    @ViewBuilder var content: Content
    private var store: CollapseStore { CollapseStore.shared }

    var body: some View {
        let open = store.isOpen(id)
        VStack(alignment: .leading, spacing: 6) {
            if open {
                Button { withAnimation(.snappy(duration: 0.3)) { store.toggle(id) } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: icon).font(.caption2.bold()).foregroundStyle(tint)
                        Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.up").font(.caption2.bold()).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Recolher \(title)")
                content
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            } else {
                Button { withAnimation(.snappy(duration: 0.3)) { store.toggle(id) } } label: {
                    Card {
                        HStack(spacing: 12) {
                            Image(systemName: icon).font(.subheadline.bold()).foregroundStyle(tint)
                                .frame(width: 34, height: 34)
                                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                if !summary.isEmpty {
                                    Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down").font(.caption.bold()).foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("\(title). \(summary). Toque para abrir")
            }
        }
    }
}

extension View {
    /// Deixa o cartão recolhível (fechado por padrão).
    func collapsible(_ id: String, _ title: String, icon: String, summary: String = "", tint: Color = Theme.accent) -> some View {
        Collapsible(id: id, title: title, icon: icon, summary: summary, tint: tint) { self }
    }
}
