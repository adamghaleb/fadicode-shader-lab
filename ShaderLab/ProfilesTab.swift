import SwiftUI

/// Profiles tab: tag starred shaders with semantic metadata for LLM export.
struct ProfilesTab: View {
    @EnvironmentObject var state: TerminalState
    @State private var showExported: Bool = false
    @State private var expandedTiers: Set<ShaderTier> = Set(ShaderTier.allCases)

    // Tier classification based on profile attributes
    private enum ShaderTier: String, CaseIterable {
        case ambient = "Ambient / Calm"
        case flowing = "Flowing / Steady"
        case deep = "Deep Processing"
        case highEnergy = "High Energy"
        case untagged = "Untagged"

        var icon: String {
            switch self {
            case .ambient:    return "moon.stars"
            case .flowing:    return "water.waves"
            case .deep:       return "cpu"
            case .highEnergy: return "bolt.fill"
            case .untagged:   return "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .ambient:    return .cyan
            case .flowing:    return .green
            case .deep:       return .purple
            case .highEnergy: return .orange
            case .untagged:   return .gray
            }
        }
    }

    private func tier(for mode: Int) -> ShaderTier {
        guard let profile = state.shaderProfiles[mode] else { return .untagged }
        let isDefault = profile.tags.isEmpty
            && profile.coverage == .medium && profile.density == .medium
            && profile.speed == .medium && profile.energy == .medium
        if isDefault { return .untagged }

        switch profile.energy {
        case .high:
            return .highEnergy
        case .low:
            return .ambient
        case .medium:
            if profile.coverage == .high { return .deep }
            return .flowing
        }
    }

    private static func levelValue(_ level: ShaderLevel) -> Int {
        switch level { case .low: return 0; case .medium: return 1; case .high: return 2 }
    }

    private func presetsFor(_ tier: ShaderTier) -> [(mode: Int, name: String, icon: String)] {
        shaderPresets
            .filter { state.starredShaders.contains($0.mode) && self.tier(for: $0.mode) == tier }
            .sorted { a, b in
                let ap = state.shaderProfiles[a.mode] ?? ShaderProfile()
                let bp = state.shaderProfiles[b.mode] ?? ShaderProfile()
                let aScore = Self.levelValue(ap.coverage) + Self.levelValue(ap.density)
                let bScore = Self.levelValue(bp.coverage) + Self.levelValue(bp.density)
                if aScore != bScore { return aScore < bScore }
                return a.name < b.name
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header + export
                HStack {
                    Text("Shader Profiles")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        _ = state.exportProfilesJSON()
                        showExported = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            showExported = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showExported ? "checkmark" : "square.and.arrow.up")
                            Text(showExported ? "Copied!" : "Export JSON")
                        }
                    }
                    .buttonStyle(DebugButtonStyle(color: showExported ? .green : .cyan))
                }

                let hasStarred = !shaderPresets.filter({ state.starredShaders.contains($0.mode) }).isEmpty

                if !hasStarred {
                    Text("No starred shaders yet.\nStar shaders in the Controls tab to profile them.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                } else {
                    ForEach(ShaderTier.allCases, id: \.self) { tier in
                        let presets = presetsFor(tier)
                        if !presets.isEmpty {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedTiers.contains(tier) },
                                    set: { expanded in
                                        if expanded { expandedTiers.insert(tier) }
                                        else { expandedTiers.remove(tier) }
                                    }
                                )
                            ) {
                                ForEach(presets, id: \.mode) { preset in
                                    shaderCard(preset)
                                }
                            } label: {
                                tierHeader(tier, count: presets.count)
                            }
                            .tint(.white.opacity(0.4))
                        }
                    }
                }

                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Tier Header

    private func tierHeader(_ tier: ShaderTier, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: tier.icon)
                .font(.system(size: 10))
                .foregroundColor(tier.color)
            Text(tier.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(tier.color)
            Text("(\(count))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(tier.color.opacity(0.6))
            Spacer()
            Rectangle()
                .fill(tier.color.opacity(0.2))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    // MARK: - Shader Card

    private func shaderCard(_ preset: (mode: Int, name: String, icon: String)) -> some View {
        let profile = Binding<ShaderProfile>(
            get: { state.shaderProfiles[preset.mode] ?? ShaderProfile() },
            set: { state.shaderProfiles[preset.mode] = $0 }
        )

        return VStack(alignment: .leading, spacing: 10) {
            // Header: icon + name (tappable) + tier color dot
            HStack(spacing: 8) {
                Button {
                    state.shaderMode = preset.mode
                    if state.isFocused { state.isFocused = false }
                    if !state.isWorkingStateActive { state.isWorkingStateActive = true }
                } label: {
                    HStack(spacing: 6) {
                        Text(preset.icon)
                            .font(.system(size: 13))
                        Text(preset.name)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(state.shaderMode == preset.mode ? .white : .white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                let t = tier(for: preset.mode)
                Circle()
                    .fill(t.color)
                    .frame(width: 6, height: 6)
            }

            // Attribute rows
            attributeRow("Coverage", level: profile.coverage)
            attributeRow("Density", level: profile.density)
            attributeRow("Speed", level: profile.speed)
            attributeRow("Energy", level: profile.energy)

            // Tags grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(ShaderTag.allCases, id: \.self) { tag in
                    tagChip(tag, isActive: profile.wrappedValue.tags.contains(tag)) {
                        if profile.wrappedValue.tags.contains(tag) {
                            profile.wrappedValue.tags.remove(tag)
                        } else {
                            profile.wrappedValue.tags.insert(tag)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    state.shaderMode == preset.mode
                        ? Color(nsColor: state.themeColor).opacity(0.4)
                        : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Attribute Row (L / M / H buttons)

    private func attributeRow(_ label: String, level: Binding<ShaderLevel>) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 60, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                ForEach(ShaderLevel.allCases, id: \.self) { lv in
                    Button {
                        level.wrappedValue = lv
                    } label: {
                        Text(lv.shortLabel)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(level.wrappedValue == lv ? .white : .white.opacity(0.3))
                            .frame(width: 32, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(level.wrappedValue == lv
                                        ? Color(nsColor: state.themeColor).opacity(0.35)
                                        : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(
                                        level.wrappedValue == lv
                                            ? Color(nsColor: state.themeColor).opacity(0.6)
                                            : Color.white.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tag Chip

    private func tagChip(_ tag: ShaderTag, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(tag.rawValue)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(isActive ? .white : .white.opacity(0.35))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive
                            ? Color(nsColor: state.themeColor).opacity(0.3)
                            : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isActive
                                ? Color(nsColor: state.themeColor).opacity(0.5)
                                : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
