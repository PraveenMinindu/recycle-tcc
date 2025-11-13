import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportPage extends StatelessWidget {
  HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          const _SectionHeader(
            icon: Icons.help_outline,
            title: 'How can we help you?',
            subtitle:
                'Find answers to common questions or contact our support team',
          ),
          const SizedBox(height: 32),

          // FAQ Section
          const _SectionTitle('Frequently Asked Questions'),
          const SizedBox(height: 16),
          ..._faqItems.map((item) => _FAQItem(item['q']!, item['a']!)).toList(),
          const SizedBox(height: 24),

          // Contact Section
          const _SectionTitle('Contact Support'),
          const SizedBox(height: 16),
          _ContactOption(
            icon: Icons.email,
            title: 'Email Us',
            subtitle: 'Get response within 24 hours',
            onTap: () => _launchEmail(),
          ),
          const SizedBox(height: 12),
          _ContactOption(
            icon: Icons.phone,
            title: 'Call Support',
            subtitle: 'Mon-Fri, 9AM-5PM',
            onTap: () => _launchPhone(),
          ),
          const SizedBox(height: 24),

          // Resources Section
          const _SectionTitle('Resources'),
          const SizedBox(height: 16),
          _ResourceItem(
            icon: Icons.book,
            title: 'Recycling Guide',
            onTap: () => _openRecyclingGuide(context),
          ),
          const SizedBox(height: 8),
          _ResourceItem(
            icon: Icons.description,
            title: 'Terms of Service',
            onTap: () => _openTerms(context),
          ),
        ],
      ),
    );
  }

  // FAQ data
  final List<Map<String, String>> _faqItems = [
    {
      'q': 'How do I schedule a pickup?',
      'a':
          'Go to the Home tab, select "Schedule Pickup", choose your preferred date and time, and confirm your request.',
    },
    {
      'q': 'What materials can I recycle?',
      'a':
          'We accept paper, cardboard, plastic bottles, glass containers, and metal cans. Please rinse containers before recycling.',
    },
    {
      'q': 'How do I earn rewards?',
      'a':
          'You earn points for each successful recycling pickup. These points can be redeemed for discounts and special offers.',
    },
    {
      'q': 'What should I do if my pickup was missed?',
      'a':
          'Please submit a complaint through the app, and our team will schedule a new pickup as soon as possible.',
    },
  ];

  // Helper functions
  void _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'praveenminindu899@gmail.com',
      queryParameters: {'subject': 'EcoChange App Support'},
    );
    if (await canLaunchUrl(emailLaunchUri)) await launchUrl(emailLaunchUri);
  }

  void _launchPhone() async {
    final Uri phoneLaunchUri = Uri(scheme: 'tel', path: '0776987401');
    if (await canLaunchUrl(phoneLaunchUri)) await launchUrl(phoneLaunchUri);
  }

  void _openRecyclingGuide(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecyclingGuidePage()),
    );
  }

  void _openTerms(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Terms of Service'),
            content: const SingleChildScrollView(
              child: Text(
                'By using the EcoChange app, you agree to our terms of service. '
                'We are committed to providing a reliable recycling service while '
                'protecting your privacy and data. For full terms, please visit our website.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}

// Reusable Widget Components
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 50, color: const Color(0xFF4CAF50)),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C3E50),
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem(this.question, this.answer);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(answer, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF4CAF50)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

class _ResourceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ResourceItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF4CAF50)),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// Recycling Guide Page
class RecyclingGuidePage extends StatelessWidget {
  const RecyclingGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycling Guide'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proper Recycling Guidelines',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '1. Rinse all containers before recycling\n'
                '2. Remove caps and lids from bottles\n'
                '3. Flatten cardboard boxes to save space\n'
                '4. Keep paper dry and clean\n'
                '5. Don\'t bag recyclables - place them loose in the bin\n'
                '6. Check local guidelines for specific items',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
