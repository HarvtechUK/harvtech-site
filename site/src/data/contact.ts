/**
 * How to reach HarvTech, in one place.
 *
 * Every call to action on the site reads from here, so a new phone number
 * or booking link is a one-line change and appears everywhere at once.
 *
 * `phone` and `bookingUrl` are optional: leave them as empty strings and
 * the site simply does not show a phone line or a "Pick a time" button.
 * Nothing breaks and nothing shows a placeholder.
 */
export const contact = {
  email: 'alex@harvtech.co.uk',

  linkedinUrl: 'https://www.linkedin.com/in/alexander-harvey-39433619',
  linkedinName: 'Alexander Harvey',

  // The number as people read it, e.g. '020 7946 0123'. Empty hides it.
  phoneDisplay: '',
  // The same number as a phone dials it, e.g. '+442079460123'.
  phoneDial: '',

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
