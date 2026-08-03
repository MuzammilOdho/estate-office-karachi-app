/// One page of a paginated query plus its paging metadata.
///
/// Carries the "is there another page?" answer ([hasMore]) so callers
/// (infinite-scroll lists, etc.) don't need to know PocketBase's own
/// `ResultList` shape, and so the repository can return a domain type
/// (`PagedResult<PaymentModel>`) instead of leaking the SDK type upward.
class PagedResult<T> {
  final List<T> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;

  const PagedResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  /// True when another page can be fetched. [page] is 1-based.
  bool get hasMore => page < totalPages;
}
