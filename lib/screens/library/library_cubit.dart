import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/capture.dart';
import '../../data/capture_repository.dart';
import 'capture_format.dart';

enum LibraryFilter { all, withNotes, videos, noLocation }

extension LibraryFilterLabel on LibraryFilter {
  String get label => switch (this) {
        LibraryFilter.all => 'All',
        LibraryFilter.withNotes => 'With notes',
        LibraryFilter.videos => 'Videos',
        LibraryFilter.noLocation => 'No location',
      };

  bool matches(Capture c) => switch (this) {
        LibraryFilter.all => true,
        LibraryFilter.withNotes => c.hasNote,
        LibraryFilter.videos => c.isVideo,
        LibraryFilter.noLocation => !c.hasLocation,
      };
}

/// Captures sharing one calendar day.
class DayGroup {
  final String label;
  final List<Capture> items;
  const DayGroup(this.label, this.items);
}

class LibraryState extends Equatable {
  final List<Capture> all;
  final LibraryFilter filter;
  final String query;

  const LibraryState({this.all = const [], this.filter = LibraryFilter.all, this.query = ''});

  int get noteCount => all.where((c) => c.hasNote).length;

  List<Capture> get visible {
    final q = query.trim().toLowerCase();
    return all.where((c) {
      if (!filter.matches(c)) return false;
      if (q.isEmpty) return true;
      final hay = [
        c.place ?? '',
        c.address ?? '',
        c.note,
        CaptureFormat.searchableDate(c.takenAt),
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  /// Visible captures grouped by day, newest first.
  List<DayGroup> get groups {
    final sorted = [...visible]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    final out = <DayGroup>[];
    for (final c in sorted) {
      final label = CaptureFormat.dayLabel(c.takenAt);
      if (out.isNotEmpty && out.last.label == label) {
        out.last.items.add(c);
      } else {
        out.add(DayGroup(label, [c]));
      }
    }
    return out;
  }

  LibraryState copyWith({List<Capture>? all, LibraryFilter? filter, String? query}) => LibraryState(
        all: all ?? this.all,
        filter: filter ?? this.filter,
        query: query ?? this.query,
      );

  @override
  List<Object?> get props => [all, filter, query];
}

/// Library list state: mirrors [CaptureRepository] and applies filter/search.
class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit(CaptureRepository repo) : super(LibraryState(all: repo.items)) {
    _sub = repo.changes.listen((items) => emit(state.copyWith(all: items)));
  }

  late final StreamSubscription<List<Capture>> _sub;

  void setFilter(LibraryFilter f) => emit(state.copyWith(filter: f));
  void setQuery(String q) => emit(state.copyWith(query: q));

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
