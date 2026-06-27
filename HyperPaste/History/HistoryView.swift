import SwiftUI
import SwiftData
import AppKit

struct HistoryView: View {
    let attachmentStore: AttachmentStore
    let onDismiss: () -> Void
    let onCommit: () -> Void
    let onRequestDeleteItem: (ClipboardItem) -> Void
    let onRequestDeleteItems: ([ClipboardItem]) -> Void
    let onRequestTogglePin: (ClipboardItem) -> Void

    @Query(sort: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)])
    private var items: [ClipboardItem]

    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedIndex: Int = 0
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var selectionAnchorIndex: Int?
    @State private var isSearchFocused = false
    @FocusState private var isHistoryFocused: Bool

    private let pasteCoordinator = PasteCoordinator()

    private var filteredItems: [ClipboardItem] {
        let categoryFiltered = items.filter { selectedFilter.matches($0) }
        guard !searchText.isEmpty else { return categoryFiltered }
        let lower = searchText.lowercased()
        return categoryFiltered.filter { $0.searchableText.contains(lower) }
    }

    private var hasMultipleSelection: Bool {
        selectedItemIDs.count > 1
    }

    private var selectedItemsInDisplayOrder: [ClipboardItem] {
        filteredItems.filter { selectedItemIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                SearchField(
                    prompt: "Search your clipboard…",
                    text: $searchText,
                    isFocused: $isSearchFocused
                ) {
                    if !filteredItems.isEmpty {
                        Text(itemCountLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
                .onSubmit { pasteSelected(plainText: false) }
            }

            FilterPillsRow(
                selected: selectedFilter,
                onSelect: selectFilter
            )

            content
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(EdgeInsets(top: 14, leading: 14, bottom: 12, trailing: 14))
        .frame(width: 600, height: 600, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
        }
        .background {
            Button("") { pasteSelected(plainText: true) }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .opacity(0)
                .accessibilityHidden(true)
        }
        .task {
            for await notification in NotificationCenter.default.notifications(named: .historyPanelKeyCommand) {
                handlePanelKeyCommand(notification)
            }
        }
        .onChange(of: searchText) { _, _ in resetSelection() }
        .onChange(of: filteredItems.count) { _, count in
            if selectedIndex >= count {
                selectedIndex = max(count - 1, 0)
            }
            pruneSelection()
        }
        .focusable(true)
        .focusEffectDisabled()
        .focused($isHistoryFocused)
        .onAppear {
            searchText = ""
            resetSelection()
            focusSearchField()
        }
        .onKeyPress(.upArrow, phases: .down) { keyPress in
            moveSelectionUp(extending: keyPress.modifiers.contains(.shift))
            return .handled
        }
        .onKeyPress(.downArrow, phases: .down) { keyPress in
            moveSelectionDown(extending: keyPress.modifiers.contains(.shift))
            return .handled
        }
        .onKeyPress(.return) {
            pasteSelected(plainText: false)
            return .handled
        }
        .onKeyPress(.escape) {
            handleEscape()
            return .handled
        }
    }

    private func requestDeleteSelected() {
        let selectedItems = selectedItemsInDisplayOrder
        if selectedItems.count > 1 {
            onRequestDeleteItems(selectedItems)
            return
        }
        guard let item = activeSelectedItem else { return }
        onRequestDeleteItem(item)
    }

    private func handlePanelKeyCommand(_ notification: Notification) {
        guard let command = HistoryPanelKeyCommand(notification: notification) else { return }
        let extendingSelection = HistoryPanelKeyCommand.extendsSelection(notification)
        switch command {
        case .moveUp:
            moveSelectionUp(extending: extendingSelection)
        case .moveDown:
            moveSelectionDown(extending: extendingSelection)
        case .selectPreviousFilter:
            selectPreviousFilter()
        case .selectNextFilter:
            selectNextFilter()
        case .commit:
            pasteSelected(plainText: false)
        case .escape:
            handleEscape()
        case .delete:
            requestDeleteSelected()
        }
    }

    private func handleEscape() {
        if hasMultipleSelection {
            selectFocusedItem()
            return
        }
        if !searchText.isEmpty {
            searchText = ""
            return
        }
        onDismiss()
    }

    private func focusSearchField() {
        isHistoryFocused = false
        Task { @MainActor in
            await Task.yield()
            isSearchFocused = true
        }
    }

    private func selectFilter(_ filter: HistoryFilter) {
        guard selectedFilter != filter else { return }
        selectedFilter = filter
        resetSelection()
        focusSearchField()
    }

    private func selectPreviousFilter() {
        selectFilter(offset: -1)
    }

    private func selectNextFilter() {
        selectFilter(offset: 1)
    }

    private func selectFilter(offset: Int) {
        let filters = HistoryFilter.allCases
        guard let currentIndex = filters.firstIndex(of: selectedFilter), !filters.isEmpty else { return }
        let nextIndex = (currentIndex + offset + filters.count) % filters.count
        selectFilter(filters[nextIndex])
    }

    private var itemCountLabel: LocalizedStringKey {
        filteredItems.count == 1 ? "1 item" : "\(filteredItems.count) items"
    }

    @ViewBuilder
    private var content: some View {
        if filteredItems.isEmpty {
            EmptyStateView(
                systemImage: items.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                title: items.isEmpty ? "Nothing copied yet" : "No matches",
                message: items.isEmpty
                    ? "Items you copy will appear here."
                    : "Try a shorter query or a different filter."
            )
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            ItemCardView(
                                item: item,
                                isSelected: isSelected(item, at: index),
                                onRequestDelete: { onRequestDeleteItem(item) },
                                onRequestTogglePin: { onRequestTogglePin(item) }
                            )
                            .id(item.id)
                            .onTapGesture {
                                handleItemClick(at: index)
                            }
                        }
                    }
                }
                .onChange(of: selectedIndex) { _, new in
                    guard filteredItems.indices.contains(new) else { return }
                    withAnimation(.snappy) {
                        proxy.scrollTo(filteredItems[new].id, anchor: .center)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var currentModifierFlags: NSEvent.ModifierFlags {
        NSApp.currentEvent?.modifierFlags ?? []
    }

    private func handleItemClick(at index: Int) {
        guard filteredItems.indices.contains(index) else { return }
        let modifiers = currentModifierFlags
        let wasMultipleSelection = hasMultipleSelection

        isSearchFocused = false
        isHistoryFocused = true

        if modifiers.contains(.command) {
            toggleItemSelection(at: index)
            return
        }

        if modifiers.contains(.shift) {
            extendSelection(to: index)
            return
        }

        selectOnlyItem(at: index)
        if !wasMultipleSelection {
            pasteSelected(plainText: false)
        }
    }

    private func isSelected(_ item: ClipboardItem, at index: Int) -> Bool {
        selectedItemIDs.contains(item.id) || (selectedItemIDs.isEmpty && index == selectedIndex)
    }

    private var activeSelectedItem: ClipboardItem? {
        if selectedItemIDs.count == 1,
           let selectedID = selectedItemIDs.first,
           let item = filteredItems.first(where: { $0.id == selectedID }) {
            return item
        }

        guard filteredItems.indices.contains(selectedIndex) else { return nil }
        return filteredItems[selectedIndex]
    }

    private func resetSelection() {
        selectedIndex = 0
        selectionAnchorIndex = nil
        selectFocusedItem()
    }

    private func selectFocusedItem() {
        guard filteredItems.indices.contains(selectedIndex) else {
            selectedItemIDs = []
            selectionAnchorIndex = nil
            return
        }
        selectedItemIDs = []
        selectionAnchorIndex = nil
    }

    private func selectOnlyItem(at index: Int) {
        guard filteredItems.indices.contains(index) else { return }
        selectedIndex = index
        selectedItemIDs = []
        selectionAnchorIndex = nil
    }

    private func toggleItemSelection(at index: Int) {
        guard filteredItems.indices.contains(index) else { return }
        if selectedItemIDs.isEmpty {
            selectionAnchorIndex = index
        }

        selectedIndex = index
        let id = filteredItems[index].id
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
            if selectedItemIDs.isEmpty {
                selectionAnchorIndex = nil
            }
        } else {
            selectedItemIDs.insert(id)
        }
    }

    private func extendSelection(to index: Int) {
        guard filteredItems.indices.contains(index) else { return }
        guard let anchor = selectionAnchorIndex,
              filteredItems.indices.contains(anchor)
        else {
            selectOnlyItem(at: index)
            return
        }

        selectedIndex = index
        let bounds = min(anchor, index)...max(anchor, index)
        selectedItemIDs = Set(bounds.map { filteredItems[$0].id })
    }

    private func moveSelectionUp(extending: Bool = false) {
        moveSelection(by: -1, extending: extending)
    }

    private func moveSelectionDown(extending: Bool = false) {
        moveSelection(by: 1, extending: extending)
    }

    private func moveSelection(by delta: Int, extending: Bool) {
        let newIndex = selectedIndex + delta
        guard filteredItems.indices.contains(newIndex) else { return }

        if extending {
            if selectionAnchorIndex == nil {
                selectionAnchorIndex = selectedIndex
            }
            extendSelection(to: newIndex)
        } else {
            selectOnlyItem(at: newIndex)
        }
    }

    private func pruneSelection() {
        let visibleIDs = Set(filteredItems.map(\.id))
        selectedItemIDs.formIntersection(visibleIDs)
        if let anchor = selectionAnchorIndex,
           !filteredItems.indices.contains(anchor) || !visibleIDs.contains(filteredItems[anchor].id) {
            selectionAnchorIndex = selectedIndex
        }
        if selectedItemIDs.isEmpty {
            selectionAnchorIndex = nil
            selectFocusedItem()
        }
    }

    private func pasteSelected(plainText: Bool) {
        let selectedItems = selectedItemsInDisplayOrder
        if selectedItems.count > 1 {
            if pasteCoordinator.writeBackSelected(selectedItems) {
                onCommit()
            } else {
                NSSound.beep()
            }
            return
        }

        guard let item = activeSelectedItem else { return }
        if pasteCoordinator.writeBack(item, plainText: plainText, attachmentStore: attachmentStore) {
            onCommit()
        }
    }
}


private struct FilterPillsRow: View {
    let selected: HistoryFilter
    let onSelect: (HistoryFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HistoryFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        title: filter.titleKey,
                        systemImage: filter.systemImage,
                        isSelected: selected == filter
                    ) {
                        onSelect(filter)
                    }
                }
            }
        }
    }
}
