//
//  PosterCard.swift
//  海报卡片与海报图（列表/网格共用）
//
//  图片走 URLCache（App 启动时配置成磁盘 500 MB / 内存 50 MB，见 CatyApp）。
//  源里的 vod_pic 常常是它自己的本地代理地址（/imageProxy?url=...），直接请求即可。
//

import SwiftUI

struct PosterImage: View {

    let urlString: String?
    /// 没有封面时显示的文字（用片名的前几个字当"文字封面"）
    var fallbackText: String?
    /// 竖向 2:3，横向 16:9。格子比例固定，网格才整齐。
    var aspect: CGFloat = Theme.posterAspect

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.12))
            .aspectRatio(aspect, contentMode: .fit)
            .overlay {
                RemoteImage(urlString: urlString, fallbackText: fallbackText)
            }
            .clipped()
    }
}

/// 网格里的海报卡片
struct PosterCard: View {

    let item: VodItem
    var showRemarks = true
    /// 片名字号（首页要"大一号"，其它格子保持原样）
    var titleFont: Font = .caption
    /// true = 横向 16:9，片名压在底部毛玻璃上；false = 竖向 2:3
    var landscape = false
    /// 片名下面的一行小字（续播进度、目录提示）
    var caption: String? = nil

    var body: some View {
        // 横竖只用同一个卡片结构，只改图片比例。
        // 原仓库就是这样。横版如果改成「字压在图上」的另一套布局，列表一出来会把格子高度算爆。
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                PosterImage(urlString: item.pic, fallbackText: item.name, aspect: imageAspect)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.posterRadius))
                if let remarks = remarksText {
                    RemarksBadge(text: remarks)
                        .padding(4)
                }
            }
            Text(item.name)
                .font(titleFont)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var imageAspect: CGFloat {
        landscape ? Theme.posterLandscapeAspect : Theme.posterAspect
    }

    private var remarksText: String? {
        guard showRemarks, let remarks = item.remarks, !remarks.isEmpty else { return nil }
        return remarks
    }
}

/// 横向列表里的行（列表模式用，比海报省空间）
struct VodRow: View {

    let item: VodItem
    var subtitle: String?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingM) {
            PosterImage(urlString: item.pic, fallbackText: item.name)
                .frame(width: 54, height: 81)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.body).lineLimit(2)
                if let subtitle {
                    Text(subtitle).font(.caption2).foregroundStyle(Theme.accent)
                }
                if let remarks = item.remarks {
                    Text(remarks).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                if let typeName = item.typeName {
                    Text(typeName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// 海报墙用的稳定身份。源列表里 vod_id 经常重复，直接 ForEach(items) 会闪退。
struct VodGridSlot: Identifiable {
    let slot: Int
    let item: VodItem
    var id: String { "\(slot)|\(item.sourceId)|\(item.siteKey)|\(item.id)" }
}

extension Array where Element == VodItem {
    var gridSlots: [VodGridSlot] {
        enumerated().map { VodGridSlot(slot: $0.offset, item: $0.element) }
    }
}
