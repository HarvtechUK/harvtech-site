/**
 * How to reach HarvTech, in one place.
 *
 * Every call to action on the site reads from here, so a change of
 * address or a new booking link is a one-line change and appears
 * everywhere at once.
 *
 * There is deliberately no telephone number: a published number attracts
 * sales calls and scams, not clients. People reach us by the form or by
 * email, and we arrange the call from there.
 *
 * `bookingUrl` is optional: leave it as an empty string and the site
 * simply does not show a "Pick a time" button.
 */
export const contact = {
  email: 'enquiries@harvtech.co.uk',

  linkedinUrl: 'https://www.linkedin.com/company/harvtechuk/',
  linkedinName: 'HarvTech',

  // A booking page (Microsoft Bookings or similar) where a visitor picks a
  // slot themselves. Empty hides the button.
  bookingUrl: '',
};

/**
 * What a visitor can ask to talk about. The `slug` is what a link passes
 * in the address (`/contact?topic=health-check#request-a-call`) so the
 * form opens with the right subject already chosen.
 */
export const callTopics = [
  { slug: 'health-check', label: 'Azure Health Check' },
  { slug: 'security', label: 'Security and compliance remediation' },
  { slug: 'platform', label: 'Platform build or migration' },
  { slug: 'cost', label: 'Cost review (FinOps)' },
  { slug: 'other', label: 'Something else' },
] as const;

export type CallTopic = (typeof callTopics)[number]['slug'];

/** The address of the request-a-call form, with a subject already chosen. */
export function callLink(topic?: CallTopic): string {
  return topic ? `/contact?topic=${topic}#request-a-call` : '/contact#request-a-call';
}
