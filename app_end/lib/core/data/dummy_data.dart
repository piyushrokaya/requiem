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
