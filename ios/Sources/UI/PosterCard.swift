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
                // 用自己写的加载器（带 Referer/UA + 内存缓存），AsyncImage 在图床防盗链面前会白图
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
        if landscape {
            landscapeCard
        } else {
            portraitCard
        }
    }

    private var portraitCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                PosterImage(urlString: item.pic, fallbackText: item.name)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay { glassStroke }
    }

    private var landscapeCard: some View {
        ZStack(alignment: .bottomLeading) {
            PosterImage(urlString: item.pic, fallbackText: item.name, aspect: Theme.posterLandscapeAspect)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(titleFont)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let remarks = remarksText {
                    Text(remarks)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay { glassStroke }
    }

    private var glassStroke: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.6)
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
