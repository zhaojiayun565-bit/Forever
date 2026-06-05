import MapKit
import SwiftUI

/// Search field with focus-driven location autocomplete suggestions.
struct LocationSearchBar: View {
    @Bindable var searchService: LocationSearchService
    @FocusState.Binding var isFocused: Bool
    let onSelect: (MKLocalSearchCompletion) -> Void

    private var showsSuggestions: Bool {
        isFocused
            && !searchService.searchQuery.isEmpty
            && !searchService.completions.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search a city or place...", text: $searchService.searchQuery)
                .padding(12)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 5)
                .padding()
                .focused($isFocused)
                .submitLabel(.search)

            if showsSuggestions {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(searchService.completions, id: \.id) { completion in
                            Button {
                                isFocused = false
                                onSelect(completion)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(ForeverFont.header(.headline))
                                        .foregroundStyle(.primary)
                                    Text(completion.subtitle)
                                        .font(ForeverFont.subheader(.subheadline))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if completion.id != searchService.completions.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .shadow(radius: 5)
            }
        }
    }
}

private extension MKLocalSearchCompletion {
    /// Stable identity for SwiftUI lists.
    var id: String { "\(title)|\(subtitle)" }
}
