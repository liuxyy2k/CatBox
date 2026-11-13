//
//  BrowseView.swift
//  分类浏览：站点的完整分类列表 + 筛选项 + 翻页 + 目录条目
//
//  契约（M0 实测）：home 返回 class（分类）与 filters（筛选项）；
//  category 用 { tid, pg } 取内容；带筛选项时额外提交 { filter: "1", extend: {...} }。
//  目录条目（vod_tag=folder）点进去是**同一站点的另一个分类**（用条目 id 当 tid）。
//

import SwiftUI

/// 进入目录条目用的导航值
struct FolderTarget: Hashable {
    let site: SiteInfo
    let tid: String
    let title: String
}

struct BrowseView: View {

    let site: SiteInfo
    let client: NodeClient?
    var initialTid: String?
    var title: String?

    @State private var categories: [Category] = []
    @State private var filters: [FilterGroup] = []
    @State private var selected: [String: String] = [:]
    @State private var tid: String?
    @State private var items: [VodItem] = []
    @State private var page = 1
    @State private var pageCount = 1
    @State private var loading = false
    @State private var errorText: String?
    @ObservedObject private var library = LibraryStore.shared
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var posterLandscape: Bool { library.settings.posterLandscape }
    private var wideColumnCount: Int { library.settings.gridColumns + (sizeClass == .regular ? 2 : 0) }
    private var posterLandscapeBinding: Binding<Bool> {
        Binding(get: { library.settings.posterLandscape },
                set: { library.settings.posterLandscape = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !categories.isEmpty || !filters.isEmpty { filterBar }
                pageBody
                    .padding(.top, Theme.spacingS)
            }
        }
        .navigationTitle(title ?? site.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PosterLayoutSwitch(landscape: posterLandscapeBinding)
            }
        }
        .navigationDestination(for: VodItem.self) { item in
            DetailView(item: item, client: client)
        }
        .navigationDestination(for: FolderTarget.self) { target in
            BrowseView(site: target.site, client: client, initialTid: target.tid, title: target.title)
        }
        .task { await loadInitial() }
    }

    @ViewBuilder
    private var pageBody: some View {
        if loading && items.isEmpty {
            PosterSkeletonGrid(columns: wideColumnCount, rows: 2,
                                aspect: posterLandscape ? Theme.posterLandscapeAspect : Theme.posterAspect)
        } else if items.isEmpty {
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, Theme.padding)
            } else if !loading {
                StateView(kind: .empty("这个分类没有内容", hint: "换一个分类试试"))
            }
        } else {
            posterGrid
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
            if let errorText {
                Text(errorText)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, Theme.padding)
            }
        }
    }

    // MARK: - 顶部：分类 + 筛选项

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            if !categories.isEmpty { categoryRow }
            ForEach(filters) { group in filterRow(group) }
        }
        .padding(.vertical, Theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacingS) {
                ForEach(categories) { category in
                    Button {
                        guard category.id != tid else { return }
                        tid = category.id
                        selected = [:]
                        Task { await reload() }
                    } label: {
                            ChipLabel(text: category.name, selected: category.id == tid, compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.padding)
        }
    }

    private func filterRow(_ group: FilterGroup) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacingS) {
                Text(group.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(group.options, id: \.self) { option in
                    Button {
                        if selected[group.id] == option.value {
                            selected[group.id] = nil
                        } else {
                            selected[group.id] = option.value
                        }
                        Task { await reload() }
                    } label: {
                        ChipLabel(text: option.name,
                                  selected: selected[group.id] == option.value,
                                  compact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.padding)
        }
    }

    // MARK: - 海报墙

    private var posterGrid: some View {
        LazyVGrid(columns: Theme.posterColumns(library.settings.gridColumns, wide: sizeClass == .regular),
                  spacing: Theme.spacingM) {
            ForEach(items.gridSlots) { slot in
                posterLink(slot)
            }
        }
        .padding(.horizontal, Theme.padding)
        .padding(.bottom, Theme.padding)
    }

    @ViewBuilder
    private func posterLink(_ slot: VodGridSlot) -> some View {
        let item = slot.item
        let caption = item.isFolder ? "目录" : subtitle(for: item)
        if item.isFolder {
            NavigationLink(value: FolderTarget(site: site, tid: item.id, title: item.name)) {
                PosterCard(item: item, showRemarks: true, titleFont: .footnote,
                           landscape: posterLandscape, caption: caption)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: item) {
                PosterCard(item: item, showRemarks: true, titleFont: .footnote,
                           landscape: posterLandscape, caption: caption)
            }
            .buttonStyle(.plain)
            .onAppear {
                if slot.slot == items.count - 1 { Task { await loadMore() } }
            }
        }
    }

    private func subtitle(for item: VodItem) -> String? {
        if let record = LibraryStore.shared.history(for: item), record.positionSec > 5 {
            return "看到 \(record.episodeName)"
        }
        return nil
    }

    // MARK: - 取数

    @MainActor
    private func loadInitial() async {
        guard let client else {
            errorText = "运行时还没就绪"
            return
        }
        guard !loading else { return }
        loading = true
        defer { loading = false }

        do {
            let home = try await client.home(site: site)
            categories = home.categories
            if let initialTid {
                tid = initialTid
            } else if tid == nil {
                tid = home.categories.first?.id
            }
            filters = tid.flatMap { home.filters[$0] } ?? []
            if !home.items.isEmpty && initialTid == nil {
                items = Array(home.items.prefix(60))
            }
            if let tid {
                let result = try await client.category(site: site, tid: tid, page: 1, extend: selected)
                if !result.items.isEmpty || items.isEmpty {
                    items = Array(result.items.prefix(60))
                    page = result.page
                    pageCount = result.pageCount
                }
            }
        } catch {
            errorText = "取不到内容：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func reload() async {
        guard let client, !loading else { return }
        loading = true
        defer { loading = false }
        items = []
        page = 1
        errorText = nil
        do {
            let result = try await client.category(site: site, tid: tid, page: 1, extend: selected)
            items = Array(result.items.prefix(60))
            page = result.page
            pageCount = result.pageCount
        } catch {
            errorText = "取不到内容：\(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadMore() async {
        guard let client, !loading, page < pageCount, !items.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            let result = try await client.category(site: site, tid: tid, page: page + 1, extend: selected)
            let existing = Set(items.map(\.id))
            let fresh = result.items.filter { !existing.contains($0.id) }
            items.append(contentsOf: fresh.prefix(60))
            page = result.page
            pageCount = result.pageCount
        } catch {
            CatyLog.shared.warn("site", "翻页失败：\(error.localizedDescription)")
        }
    }
}
