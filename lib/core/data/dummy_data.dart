import '../models/comparison_cluster.dart';
import '../models/news_article.dart';

/// Static placeholder content used while the real backend integration
/// (matching the sanksep app) is built out in a later phase.
final List<NewsArticle> dummyArticles = [
  NewsArticle(
    id: 'a1',
    title: 'Government announces new budget for infrastructure projects',
    source: 'Kantipur',
    publishedAt: DateTime.now().subtract(const Duration(minutes: 40)),
    summary:
        'The finance ministry unveiled a plan to fund road and bridge '
        'projects across the country over the next fiscal year.',
    fullText:
        'The finance ministry unveiled a plan to fund road and bridge '
        'projects across the country over the next fiscal year. Officials '
        'said the budget prioritizes rural connectivity and disaster-'
        'resilient construction standards, with rollout expected in phases '
        'starting next quarter.',
  ),
  NewsArticle(
    id: 'a2',
    title: 'Local football club advances to national finals',
    source: 'OnlineKhabar',
    publishedAt: DateTime.now().subtract(const Duration(hours: 3)),
    summary:
        'A last-minute goal secured the win, sending the team to the '
        'championship match for the first time in a decade.',
    fullText:
        'A last-minute goal secured the win, sending the team to the '
        'championship match for the first time in a decade. Fans '
        'celebrated across the city as the squad prepares for the final '
        'showdown next weekend.',
  ),
  NewsArticle(
    id: 'a3',
    title: 'New health guidelines released for monsoon season',
    source: 'Setopati',
    publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
    summary:
        'Health officials urge residents to take precautions against '
        'waterborne diseases as rainfall increases nationwide.',
    fullText:
        'Health officials urge residents to take precautions against '
        'waterborne diseases as rainfall increases nationwide. The '
        'guidelines recommend boiling drinking water, clearing stagnant '
        'water near homes, and seeking care early for fever symptoms.',
  ),
  NewsArticle(
    id: 'a4',
    title: 'Tech startup raises funding to expand digital payments',
    source: 'Ekantipur',
    publishedAt: DateTime.now().subtract(const Duration(hours: 20)),
    summary:
        'The company plans to use the investment to expand into rural '
        'markets and add support for more local banks.',
    fullText:
        'The company plans to use the investment to expand into rural '
        'markets and add support for more local banks. Founders say the '
        'goal is to make mobile payments accessible to small merchants '
        'who currently rely on cash.',
  ),
  NewsArticle(
    id: 'a5',
    title: 'Cultural festival draws record crowds this year',
    source: 'Nagarik News',
    publishedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    summary:
        'Organizers report the highest attendance in the festival\'s '
        'history, with visitors traveling from across the region.',
    fullText:
        'Organizers report the highest attendance in the festival\'s '
        'history, with visitors traveling from across the region. The '
        'event featured traditional music, food stalls, and craft '
        'exhibitions over three days.',
  ),
];

final List<ComparisonCluster> dummyClusters = [
  ComparisonCluster(
    clusterId: 1,
    sources: const ['Kantipur', 'Setopati', 'OnlineKhabar'],
    titles: const [
      'Budget prioritizes rural roads',
      'Finance ministry unveils infrastructure plan',
      'New budget targets bridges and highways',
    ],
    category: 'Politics',
    oneLiner: 'Sources agree on the budget increase but differ on rollout timing.',
    shortSummary:
        'All three outlets confirm the government has approved additional '
        'funding for infrastructure, but they report different start dates '
        'for construction.',
    keyPoints:
        '- Budget increase confirmed by all sources\n'
        '- Rural roads and bridges are the main focus\n'
        '- Start dates range from "next quarter" to "next year"',
    missingInfo:
        'None of the sources mention how the funding will be audited or '
        'who oversees contractor selection.',
    coverageBreakdown: 'Kantipur: detailed. Setopati: brief. OnlineKhabar: moderate.',
  ),
  ComparisonCluster(
    clusterId: 2,
    sources: const ['Ekantipur', 'Nagarik News'],
    titles: const [
      'Startup secures new funding round',
      'Digital payment company expands to rural areas',
    ],
    category: 'Business',
    oneLiner: 'Both sources confirm the funding round but cite different amounts.',
    shortSummary:
        'Ekantipur and Nagarik News both report on the funding round, but '
        'the reported amount differs by roughly 15%.',
    keyPoints:
        '- Funding round confirmed by both sources\n'
        '- Expansion into rural markets is the stated goal\n'
        '- Reported amounts differ slightly',
    missingInfo: 'Neither source names the lead investor.',
    coverageBreakdown: 'Ekantipur: detailed. Nagarik News: brief.',
  ),
  ComparisonCluster(
    clusterId: 3,
    sources: const ['OnlineKhabar', 'Kantipur'],
    titles: const [
      'Local club reaches national finals',
      'Underdog team stuns rivals to advance',
    ],
    category: 'Sports',
    oneLiner: 'Coverage is largely consistent, with only tone differing.',
    shortSummary:
        'Both outlets describe the same last-minute goal and the team\'s '
        'first finals appearance in ten years.',
    keyPoints:
        '- Same final score reported\n'
        '- Both note the ten-year gap since the last finals run\n'
        '- Match date for the final agrees across sources',
    missingInfo: 'Neither source mentions ticket availability for the final.',
    coverageBreakdown: 'OnlineKhabar: detailed. Kantipur: detailed.',
  ),
];

/// Very small canned Q&A used to simulate the "Ask" feature before it is
/// wired up to a real backend.
const Map<String, String> dummyAskResponses = {
  'budget':
      'Based on current coverage, the government has approved additional '
      'infrastructure funding, though outlets disagree on the exact rollout '
      'timeline.',
  'football':
      'The local club won its semifinal with a last-minute goal and will '
      'play in the national final next weekend.',
  'health':
      'New monsoon health guidelines recommend boiling drinking water and '
      'clearing stagnant water to prevent waterborne disease.',
  'funding':
      'A local payments startup raised a new funding round to expand into '
      'rural markets, according to two independent sources.',
};

const String dummyAskFallback =
    'This is placeholder data for now — try asking about "budget", '
    '"football", "health", or "funding" to see a sample answer.';
