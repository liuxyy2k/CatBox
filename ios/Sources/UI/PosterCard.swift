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
                // 封面必须吃掉格子给的尺寸。不裁切的话，原图的像素宽高会把整行格子撑到几千点，列表一出来就崩。
                RemoteImage(urlString: urlString, fallbackText: fallbackText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
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
        if landscape {
            landscapeCard
        } else {
            portraitCard
        }
    }

    private var portraitCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                PosterImage(urlString: item.pic, fallbackText: item.name)
                if let remarks = remarksText {
                    RemarksBadge(text: remarks)
                        .padding(6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.posterRadius, style: .continuous))
            .overlay { posterStroke }
            Text(item.name)
                .font(titleFont)
                .lineLimit(2)
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

    private var landscapeCard: some View {
        ZStack(alignment: .bottomLeading) {
            PosterImage(urlString: item.pic, fallbackText: item.name, aspect: Theme.posterLandscapeAspect)
            LinearGradient(colors: [.clear, .black.opacity(0.78)],
                           startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(titleFont.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let remarks = remarksText {
                    Text(remarks)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.posterRadius, style: .continuous))
        .overlay { posterStroke }
    }

    private var posterStroke: some View {
        RoundedRectangle(cornerRadius: Theme.posterRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
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
