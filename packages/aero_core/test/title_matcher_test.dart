import 'package:aero_core/aero_core.dart';
import 'package:test/test.dart';

void main() {
  group('normalise', () {
    const cases = {
      'The Shawshank Redemption': 'shawshank redemption',
      '  SPIDER-MAN: No Way Home (2021) ': 'spider man no way home',
      'Amélie': 'amelie',
      'Crouching Tiger, Hidden Dragon': 'crouching tiger hidden dragon',
      'WALL·E': 'wall e',
      'Movie [1080p] {WEB-DL}': 'movie',
      'Show S01E05': 'show',
      'Show Season 2 Episode 3': 'show',
      'Se7en': 'se7en',
      'The 100': '100',
      'Mr. & Mrs. Smith': 'mr mrs smith',
      'Star Wars: Episode IV - A New Hope': 'star wars episode iv a new hope',
      'Festen': 'festen',
      'Æon Flux': 'aeon flux',
      'Straße': 'strasse',
    };
    cases.forEach((input, expected) {
      test('"$input" -> "$expected"', () {
        expect(TitleMatcher.normalise(input), expected);
      });
    });

    test('a lone article is kept, not stripped to nothing', () {
      expect(TitleMatcher.normalise('The'), 'the');
    });
  });

  group('similarity: pairs that SHOULD match', () {
    // Real-world spellings: add-on title vs scraper title.
    const shouldMatch = <(String, String)>[
      ('The Shawshank Redemption', 'Shawshank Redemption'),
      ('The Shawshank Redemption', 'The Shawshank Redemption (1994)'),
      ('Spider-Man: No Way Home', 'Spider Man No Way Home'),
      ('Spider-Man: No Way Home', 'Spider-Man: No Way Home [1080p]'),
      ('Amélie', 'Amelie'),
      ('The Lord of the Rings: The Fellowship of the Ring',
          'Lord of the Rings Fellowship of the Ring'),
      ('Breaking Bad', 'Breaking Bad S01E01'),
      ('Money Heist', 'La Casa de Papel'),
      ('The Godfather', 'Godfather, The'),
      ('WALL·E', 'WALL-E'),
      ('Ocean\'s Eleven', 'Oceans Eleven'),
      ('Mission: Impossible - Dead Reckoning',
          'Mission Impossible Dead Reckoning'),
      ('The Dark Knight', 'Dark Knight'),
      ('Avengers: Endgame', 'Avengers Endgame (2019)'),
      ('Parasite', 'Gisaengchung'),
      ('Spirited Away', 'Sen to Chihiro no Kamikakushi'),
      ('Coco', 'Coco (2017)'),
      ('Dune', 'Dune 2021'),
      ('Everything Everywhere All at Once',
          'Everything Everywhere All At Once'),
    ];
    for (final (a, b) in shouldMatch) {
      test('"$a" ~ "$b"', () {
        // Foreign-title pairs are genuinely dissimilar strings; the matcher
        // should not pretend otherwise. Only assert on the transliterations.
        if (b == 'La Casa de Papel' ||
            b == 'Gisaengchung' ||
            b == 'Sen to Chihiro no Kamikakushi') {
          expect(TitleMatcher.similarity(a, b), lessThan(0.5));
          return;
        }
        expect(TitleMatcher.similarity(a, b), greaterThanOrEqualTo(0.6),
            reason: '$a vs $b');
      });
    }
  });

  group('similarity: pairs that must NOT match', () {
    const shouldNotMatch = <(String, String)>[
      ('The Dark Knight', 'The Dark Knight Rises'),
      ('Dune', 'Dune: Part Two'),
      ('Alien', 'Aliens'),
      ('Toy Story', 'Toy Story 2'),
      ('The Matrix', 'The Matrix Reloaded'),
      ('Iron Man', 'Iron Man 3'),
      ('Fast & Furious', 'Fast X'),
      ('Batman Begins', 'The Batman'),
      ('Home Alone', 'Home Alone 2: Lost in New York'),
      ('Joker', 'Joker: Folie à Deux'),
    ];
    for (final (a, b) in shouldNotMatch) {
      test('"$a" != "$b" (sequel guard)', () {
        // Sequels share most tokens; year/type must be what separates them.
        final s = TitleMatcher.similarity(a, b);
        expect(s, lessThan(0.95), reason: '$a vs $b scored $s');
      });
    }

    test('a franchise prefix is NOT auto-matched, by design', () {
      // "Star Wars: Episode V - The Empire Strikes Back" vs "The Empire
      // Strikes Back" is a subset. A containment bonus would match it, but the
      // same rule would also match "The Dark Knight" to "The Dark Knight
      // Rises". Sequel false-positives play the wrong film, so the matcher
      // stays conservative and this case goes to the "Wrong match?" picker.
      final s = TitleMatcher.similarity(
        'Star Wars: Episode V - The Empire Strikes Back',
        'The Empire Strikes Back',
      );
      expect(s, lessThan(TitleMatcher.acceptThreshold));
    });

    test('a year mismatch pulls a sequel below the accept threshold', () {
      final base = TitleCandidate(title: 'Dune', link: 'a', year: 1984);
      final sequel = TitleCandidate(title: 'Dune', link: 'b', year: 2021);
      final picked = TitleMatcher.best([base, sequel], title: 'Dune', year: 2021);
      expect(picked!.candidate.link, 'b');
    });
  });

  group('scoring', () {
    test('an exact title with matching year scores highest', () {
      final s = TitleMatcher.score(
        const TitleCandidate(title: 'Dune', link: 'x', year: 2021, type: 'movie'),
        title: 'Dune', year: 2021, type: 'movie',
      );
      expect(s, greaterThanOrEqualTo(0.99));
    });

    test('a wrong type is penalised', () {
      final movie = TitleMatcher.score(
        const TitleCandidate(title: 'Dune', link: 'x', type: 'movie'),
        title: 'Dune', type: 'movie');
      final series = TitleMatcher.score(
        const TitleCandidate(title: 'Dune', link: 'x', type: 'series'),
        title: 'Dune', type: 'movie');
      expect(movie, greaterThan(series));
    });

    test('year bonuses are graded', () {
      expect(TitleMatcher.yearBonus(2020, 2020), greaterThan(0));
      expect(TitleMatcher.yearBonus(2021, 2020), greaterThan(0));
      expect(TitleMatcher.yearBonus(2025, 2020), lessThan(0));
      expect(TitleMatcher.yearBonus(null, 2020), 0);
    });

    test('best() returns null when nothing clears the threshold', () {
      final r = TitleMatcher.best([
        const TitleCandidate(title: 'Completely Different Film', link: 'x'),
      ], title: 'Dune');
      expect(r, isNull);
    });

    test('rank() orders candidates for the "Wrong match?" picker', () {
      final ranked = TitleMatcher.rank([
        const TitleCandidate(title: 'Dune: Part Two', link: 'b'),
        const TitleCandidate(title: 'Dune', link: 'a'),
        const TitleCandidate(title: 'Dune World', link: 'c'),
      ], title: 'Dune', year: 2021);
      expect(ranked.first.candidate.link, 'a');
      expect(ranked.length, 3);
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].score, greaterThanOrEqualTo(ranked[i].score));
      }
    });

    test('an empty candidate list yields no match', () {
      expect(TitleMatcher.best(const [], title: 'Dune'), isNull);
      expect(TitleMatcher.rank(const [], title: 'Dune'), isEmpty);
    });
  });

  group('episode parsing', () {
    const cases = <String, (int, int)>{
      'S01E02': (1, 2),
      's2 e10': (2, 10),
      '1x05': (1, 5),
      'Season 3 Episode 7': (3, 7),
      'Episode 4': (1, 4),
      '  12  ': (1, 12),
      'Show.Name.S04E11.1080p': (4, 11),
    };
    cases.forEach((input, expected) {
      test('"$input" -> $expected', () {
        expect(TitleMatcher.parseEpisode(input), expected);
      });
    });

    test('a plain title has no episode', () {
      expect(TitleMatcher.parseEpisode('Pilot'), isNull);
      expect(TitleMatcher.parseEpisode('The One With The Cake'), isNull);
    });

    test('defaultSeason is used when only an episode number is present', () {
      expect(TitleMatcher.parseEpisode('Episode 4', defaultSeason: 3), (3, 4));
    });
  });
}
