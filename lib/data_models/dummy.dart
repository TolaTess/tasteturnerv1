import '../service/battle_service.dart';

class TestBattleData {
  static final List<Map<String, dynamic>> testBattles = [
    {
      'category': 'all',
      'participants': [
        {
          'userId': 'H9ktpa51QYT0WT0pM7LyaX72LtH2',
          'votes': ['CSpF2nSn5lgEudwEKjoaPDF4f3C3']
        },
        {
          'userId': 'CSpF2nSn5lgEudwEKjoaPDF4f3C3',
          'votes': ['DeMzuPqxRXSf6wlQWKW1bNbHOug1']
        }
      ],
      'voted': ['CSpF2nSn5lgEudwEKjoaPDF4f3C3', 'DeMzuPqxRXSf6wlQWKW1bNbHOug1'],
      'ingredients': [
        '12fM4B95d3oMHQ5r1F8Z',
        '1j9XbHLyOpMIebb9wjtv',
      ]
    },
    {
      'category': 'carnivore',
      'participants': [
        {
          'userId': 'H9ktpa51QYT0WT0pM7LyaX72LtH2',
          'votes': ['DeMzuPqxRXSf6wlQWKW1bNbHOug1']
        },
        {
          'userId': 'DeMzuPqxRXSf6wlQWKW1bNbHOug1',
          'votes': ['CSpF2nSn5lgEudwEKjoaPDF4f3C3']
        }
      ],
      'voted': ['DeMzuPqxRXSf6wlQWKW1bNbHOug1', 'CSpF2nSn5lgEudwEKjoaPDF4f3C3'],
      'ingredients': [
        'Qu2I3pjNM1CjBXt5FxvA',
        'VzWOnXkYnCNqUB8RpXVG',
      ]
    },
    {
      'category': 'keto',
      'participants': [
        {
          'userId': 'CSpF2nSn5lgEudwEKjoaPDF4f3C3',
          'votes': ['H9ktpa51QYT0WT0pM7LyaX72LtH2']
        },
        {
          'userId': 'DeMzuPqxRXSf6wlQWKW1bNbHOug1',
          'votes': ['CSpF2nSn5lgEudwEKjoaPDF4f3C3']
        }
      ],
      'voted': ['H9ktpa51QYT0WT0pM7LyaX72LtH2', 'CSpF2nSn5lgEudwEKjoaPDF4f3C3'],
      'ingredients': [
        'VzWOnXkYnCNqUB8RpXVG',
        '88Fk2ItGP8afEpPrz7vK',
      ]
    },
    {
      'category': 'vegan',
      'participants': [
        {
          'userId': 'DeMzuPqxRXSf6wlQWKW1bNbHOug1',
          'votes': ['H9ktpa51QYT0WT0pM7LyaX72LtH2']
        },
        {
          'userId': 'CSpF2nSn5lgEudwEKjoaPDF4f3C3',
          'votes': ['DeMzuPqxRXSf6wlQWKW1bNbHOug1']
        }
      ],
      'voted': ['H9ktpa51QYT0WT0pM7LyaX72LtH2', 'DeMzuPqxRXSf6wlQWKW1bNbHOug1'],
      'ingredients': [
        '1j9XbHLyOpMIebb9wjtv',
        '88Fk2ItGP8afEpPrz7vK',
      ]
    },
    {
      'category': 'vegetarian',
      'participants': [
        {
          'userId': 'H9ktpa51QYT0WT0pM7LyaX72LtH2',
          'votes': ['CSpF2nSn5lgEudwEKjoaPDF4f3C3']
        },
        {
          'userId': 'DeMzuPqxRXSf6wlQWKW1bNbHOug1',
          'votes': ['H9ktpa51QYT0WT0pM7LyaX72LtH2']
        }
      ],
      'voted': ['CSpF2nSn5lgEudwEKjoaPDF4f3C3', 'H9ktpa51QYT0WT0pM7LyaX72LtH2'],
      'ingredients': [
        '88Fk2ItGP8afEpPrz7vK',
        'Qu2I3pjNM1CjBXt5FxvA',
      ]
    },
    {
      'category': 'weight loss',
      'participants': [
        {
          'userId': 'CSpF2nSn5lgEudwEKjoaPDF4f3C3',
          'votes': ['DeMzuPqxRXSf6wlQWKW1bNbHOug1']
        },
        {
          'userId': 'H9ktpa51QYT0WT0pM7LyaX72LtH2',
          'votes': ['CSpF2nSn5lgEudwEKjoaPDF4f3C3']
        }
      ],
      'voted': ['DeMzuPqxRXSf6wlQWKW1bNbHOug1', 'CSpF2nSn5lgEudwEKjoaPDF4f3C3'],
      'ingredients': [
        '12fM4B95d3oMHQ5r1F8Z',
        'VzWOnXkYnCNqUB8RpXVG',
      ]
    }
  ];

  static Future<void> createTestBattles(BattleService battleService) async {
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, 17);

    for (final battle in testBattles) {
      try {
        final battleId = await battleService.createBattle(
          category: battle['category'],
          ingredients: List<String>.from(battle['ingredients']),
        );

        // Add participants and their votes
        for (final participant in battle['participants']) {
          await battleService.joinBattle(
            battleId: battleId,
            userId: participant['userId'],
            userName: 'Test User ${participant['userId'].substring(0, 5)}',
            userImage: 'https://picsum.photos/200',
          );

          // Add votes for this participant
          for (final voterId in participant['votes']) {
            await battleService.castVote(
              battleId: battleId,
              voterId: voterId,
              votedForUserId: participant['userId'],
            );
          }
        }
      } catch (e) {
        print('Error creating test battle: $e');
      }
    }
  }
}
