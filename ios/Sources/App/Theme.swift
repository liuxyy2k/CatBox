//
//  Theme.swift
//  设计 token（颜色 / 间距 / 圆角 / 字体），见 docs/02-ui-spec.md
//

import SwiftUI

enum Theme {

    // 主色：蓝紫（与设计稿一致）
    static let accent = Color(red: 0.36, green: 0.52, blue: 0.98)
    static let accentSoft = Color(red: 0.36, green: 0.52, blue: 0.98).opacity(0.18)

    static let cardRadius: CGFloat = 14
    static let posterRadius: CGFloat = 12
    static let chipRadius: CGFloat = 14

    /// 页面底色。内容区用实色，毛玻璃只留给系统导航和底部标签。
    static let canvas = Color(red: 0.03, green: 0.035, blue: 0.045)
    static let cardFill = Color.primary.opacity(0.06)

    static let padding: CGFloat = 14
    static let spacingS: CGFloat = 6
    static let spacingM: CGFloat = 10
    static let spacingL: CGFloat = 16

    /// 海报宽高比（2:3）
    static let posterAspect: CGFloat = 2.0 / 3.0
    /// 横向海报（16:9）
    static let posterLandscapeAspect: CGFloat = 16.0 / 9.0

    /// wide = true（iPad / 横屏）时多铺两列：同一个"每行 3 个"的设置在 iPad 上不会显得稀稀拉拉
    static func posterColumns(_ count: Int, wide: Bool = false) -> [GridItem] {
        let columns = max(2, min(8, wide ? count + 2 : count))
        return Array(repeating: GridItem(.flexible(), spacing: spacingM), count: columns)
    }

    /// 分类列表的列数。横向海报更宽，列数大约减半，手机上至少留 1 列。
    static func categoryColumnCount(gridColumns: Int, wide: Bool, landscape: Bool) -> Int {
        let portrait = max(2, min(4, gridColumns)) + (wide ? 2 : 0)
        if !landscape { return min(8, portrait) }
        return max(1, (portrait + 1) / 2)
    }

    /// 按给定列数铺网格（允许 1 列，给横向大海报用）
    static func columns(_ count: Int) -> [GridItem] {
        let columns = max(1, min(8, count))
        return Array(repeating: GridItem(.flexible(), spacing: spacingM), count: columns)
    }
}

/// 统一的小胶囊标签（分类 / 线路 / 备注角标都用它）
struct ChipLabel: View {

    let text: String
    var selected = false
    var compact = false
    /// 首页用的"大一号"版式（用户反馈整体字号偏小）
    var large = false
    /// 毛玻璃胶囊（分类条 / 筛选项）
    var glass = false

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.88))
            .background { chipFill }
            .clipShape(Capsule())
            .overlay { chipStroke }
    }

    @ViewBuilder
    private var chipFill: some View {
        if selected {
            Capsule().fill(Theme.accent)
        } else if glass {
            Capsule().fill(Theme.cardFill)
        } else {
            Capsule().fill(Color.secondary.opacity(0.12))
        }
    }

    @ViewBuilder
    private var chipStroke: some View {
        if !selected {
            Capsule().strokeBorder(Color.primary.opacity(glass ? 0.10 : 0.06), lineWidth: 0.5)
        }
    }

    private var font: Font {
        if large { return compact ? .footnote : .subheadline }
        return compact ? .caption2 : .caption
    }

    private var horizontalPadding: CGFloat {
        if large { return 12 }
        return compact ? 8 : 12
    }

    private var verticalPadding: CGFloat {
        if large { return 7 }
        return compact ? 3 : 6
    }
}

/// 备注角标（海报右下角）
struct RemarksBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(Color.black.opacity(0.62), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// 分类列表右上角：竖向海报 / 横向海报
struct PosterLayoutSwitch: View {

    @Binding var landscape: Bool

    var body: some View {
        HStack(spacing: 2) {
            segment(title: "竖", symbol: "rectangle.portrait", on: !landscape) {
                landscape = false
            }
            segment(title: "横", symbol: "rectangle", on: landscape) {
                landscape = true
            }
        }
        .padding(2)
        .background(Theme.cardFill, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    private func segment(title: String, symbol: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .foregroundStyle(on ? Color.white : Color.primary.opacity(0.72))
            .background {
                if on {
                    Capsule().fill(Theme.accent)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "横" ? "横向海报" : "竖向海报")
    }
}
