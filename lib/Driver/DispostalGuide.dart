import 'package:flutter/material.dart';

class DisposalGuide extends StatefulWidget {
  const DisposalGuide({super.key});

  @override
  State<DisposalGuide> createState() => _DisposalGuideState();
}

class _DisposalGuideState extends State<DisposalGuide> {
  final TextEditingController _searchController = TextEditingController();

  final List<DisposalCategory> categories = [
    DisposalCategory(
      name: 'Plastic',
      imagePath: 'images/plastic.png',
      description:
          'Pick up clean plastic bottles and containers. Avoid bags with food scraps.',
      dos: ['✅ Bottles & containers', '✅ Rinse before sorting'],
      donts: ['❌ Plastic bags', '❌ Food-soiled plastics'],
      tips: [
        '💡 Flatten bottles to save space',
        '💡 Keep separate from non-recyclables',
      ],
      commonMistakes: [
        'Throwing greasy containers',
        'Mixing with general trash',
      ],
      doAction: 'Pick up & sort',
      dontAction: 'Do not mix',
    ),
    DisposalCategory(
      name: 'Paper',
      imagePath: 'images/paper.png',
      description:
          'Collect newspapers, boxes, and clean paper. Avoid wet or food-contaminated paper.',
      dos: ['✅ Newspapers & boxes', '✅ Keep dry'],
      donts: ['❌ Wet paper', '❌ Food-stained paper'],
      tips: ['💡 Flatten boxes', '💡 Keep separate from wet waste'],
      commonMistakes: [
        'Throwing tissues',
        'Mixing coated paper with recyclables',
      ],
      doAction: 'Pick up & sort',
      dontAction: 'Do not mix',
    ),
    DisposalCategory(
      name: 'Food Waste',
      imagePath: 'images/food.jpeg',
      description:
          'Collect food scraps separately for composting. Avoid plastics or metals mixed in.',
      dos: ['✅ Compostable waste', '✅ Chop large pieces'],
      donts: ['❌ Plastics', '❌ Metal or glass in food waste'],
      tips: ['💡 Separate wet & dry waste', '💡 Keep covered to prevent smell'],
      commonMistakes: [
        'Putting food in recycling',
        'Adding non-compostable items',
      ],
      doAction: 'Collect separately',
      dontAction: 'Do not mix',
    ),
    DisposalCategory(
      name: 'Electronics',
      imagePath: 'images/electronics.png',
      description:
          'Handle e-waste carefully. Remove batteries and separate for recycling.',
      dos: ['✅ Old electronics', '✅ Use e-waste bins'],
      donts: ['❌ Throw in trash', '❌ Break electronics'],
      tips: ['💡 Remove batteries first', '💡 Donate working devices'],
      commonMistakes: [
        'Mixing with household trash',
        'Dropping e-waste in bins',
      ],
      doAction: 'Handle safely',
      dontAction: 'Do not trash',
    ),
    DisposalCategory(
      name: 'Glass',
      imagePath: 'images/glass.png',
      description:
          'Collect bottles & jars. Avoid broken glass or ceramics that can injure.',
      dos: ['✅ Glass bottles', '✅ Jars'],
      donts: ['❌ Ceramics', '❌ Broken glass in pieces'],
      tips: ['💡 Remove caps', '💡 Keep separate from metals'],
      commonMistakes: [
        'Mixing with non-recyclables',
        'Throwing glass with hazardous liquids',
      ],
      doAction: 'Pick up & sort',
      dontAction: 'Do not mix',
    ),
    DisposalCategory(
      name: 'Metal',
      imagePath: 'images/metal.png',
      description:
          'Collect clean metal cans and tins. Avoid painted or chemical-contaminated metal.',
      dos: ['✅ Aluminum cans', '✅ Tin containers'],
      donts: ['❌ Painted metal', '❌ Metal with chemicals'],
      tips: ['💡 Flatten cans', '💡 Rinse containers'],
      commonMistakes: [
        'Throwing scrap metal in trash',
        'Including contaminated metals',
      ],
      doAction: 'Pick up & sort',
      dontAction: 'Do not mix',
    ),
    DisposalCategory(
      name: 'Textiles',
      imagePath: 'images/textiles.png',
      description:
          'Collect clean clothes and fabrics. Avoid wet or moldy textiles.',
      dos: ['✅ Usable clothes', '✅ Old fabrics for recycling'],
      donts: ['❌ Wet/moldy clothes', '❌ Dirty textiles'],
      tips: ['💡 Donate wearable clothes', '💡 Separate fabric types'],
      commonMistakes: [
        'Throwing all old clothes',
        'Mixing with non-recyclables',
      ],
      doAction: 'Pick up & sort',
      dontAction: 'Do not mix',
    ),
    DisposalCategory(
      name: 'Batteries',
      imagePath: 'images/battery.png',
      description:
          'Handle batteries with care. Tape terminals to prevent accidents.',
      dos: ['✅ Store in battery bins', '✅ Use e-waste facilities'],
      donts: ['❌ Throw in trash', '❌ Burn or puncture'],
      tips: ['💡 Keep cool and dry', '💡 Tape terminals'],
      commonMistakes: [
        'Mixing with household waste',
        'Ignoring rechargeable batteries',
      ],
      doAction: 'Collect safely',
      dontAction: 'Do not throw',
    ),
    DisposalCategory(
      name: 'Hazardous Waste',
      imagePath: 'images/hazardous.png',
      description:
          'Collect paints, chemicals, and solvents carefully. Follow safety rules.',
      dos: ['✅ Take to hazardous facility', '✅ Follow local rules'],
      donts: ['❌ Pour down drains', '❌ Mix with trash'],
      tips: ['💡 Store securely', '💡 Avoid mixing chemicals'],
      commonMistakes: [
        'Pouring chemicals into drains',
        'Throwing hazardous waste carelessly',
      ],
      doAction: 'Collect safely',
      dontAction: 'Do not mix',
    ),
    DisposalCategory(
      name: 'Garden Waste',
      imagePath: 'images/garden.png',
      description:
          'Collect leaves, grass, and branches. Avoid plastics or diseased plants.',
      dos: ['✅ Leaves, grass clippings', '✅ Compost or mulch'],
      donts: ['❌ Plastic or metal', '❌ Diseased plants'],
      tips: ['💡 Chop branches', '💡 Keep compost moist'],
      commonMistakes: ['Mixing non-organic waste', 'Leaving piles too long'],
      doAction: 'Collect separately',
      dontAction: 'Do not mix',
    ),
  ];

  List<DisposalCategory> filteredCategories = [];

  @override
  void initState() {
    super.initState();
    filteredCategories = categories;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        filteredCategories = categories;
      });
    } else {
      setState(() {
        filteredCategories =
            categories.where((category) {
              return category.name.toLowerCase().contains(query) ||
                  category.description.toLowerCase().contains(query) ||
                  category.dos.any(
                    (item) => item.toLowerCase().contains(query),
                  ) ||
                  category.donts.any(
                    (item) => item.toLowerCase().contains(query),
                  ) ||
                  category.tips.any(
                    (item) => item.toLowerCase().contains(query),
                  ) ||
                  category.commonMistakes.any(
                    (item) => item.toLowerCase().contains(query),
                  );
            }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Garbage Worker Guide',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search categories...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Type here...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find what to collect or avoid on your route.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredCategories.length,
              itemBuilder: (context, index) {
                return _buildCategoryCard(filteredCategories[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(DisposalCategory category) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Image.asset(
            category.imagePath,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.category, color: Colors.green[800]);
            },
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text('Quick guide for ${category.name}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Description', Colors.blueGrey),
                Text(category.description),
                const SizedBox(height: 12),
                _buildListSection(
                  category.doAction,
                  category.dos,
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(height: 12),
                _buildListSection(
                  category.dontAction,
                  category.donts,
                  Icons.cancel,
                  Colors.red,
                ),
                const SizedBox(height: 12),
                _buildListSection(
                  'Tips',
                  category.tips,
                  Icons.lightbulb,
                  Colors.teal,
                ),
                const SizedBox(height: 12),
                _buildListSection(
                  'Common Mistakes',
                  category.commonMistakes,
                  Icons.warning,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Text _sectionTitle(String title, Color color) => Text(
    title,
    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
  );

  Widget _buildListSection(
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: color,
        ),
      ),
      const SizedBox(height: 8),
      ...items.map(
        (item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(item)),
            ],
          ),
        ),
      ),
    ],
  );
}

class DisposalCategory {
  final String name;
  final String imagePath;
  final String description;
  final List<String> dos;
  final List<String> donts;
  final List<String> tips;
  final List<String> commonMistakes;
  final String doAction;
  final String dontAction;

  DisposalCategory({
    required this.name,
    required this.imagePath,
    required this.description,
    required this.dos,
    required this.donts,
    required this.tips,
    required this.commonMistakes,
    required this.doAction,
    required this.dontAction,
  });
}
