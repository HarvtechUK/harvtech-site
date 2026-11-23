/**
 * The words and figures on /health-check.
 *
 * Kept as data so the page file is mostly layout. Two rules for anything
 * added here:
 *
 *   1. Every number is one the product itself reports. The check counts
 *      come from the engine's rule list; the example findings are real
 *      output from the DEMONSTRATION estate (a made-up insurer), never
 *      from a client.
 *   2. No verdict words. The health check is not an audit, so nothing
 *      here says an estate is "compliant" or that a control is "met".
 *      The report's own wording is "improvements found" and
 *      "no improvements found".
 */

/**
 * The counts quoted around the site, in one place. They change whenever
 * checks are added to the engine (`finops rules | wc -l` gives the first;
 * the onboarding guide gives the per-tier split), so every page reads
 * them from here instead of typing the number.
 */
export const counts = {
  /** Every check the health check runs. */
  checks: 354,
  /** How many of those need nothing more than the Reader role. */
  readerOnly: 305,
  /** The areas of Azure the report groups findings by. */
  areas: 13,
};

/** Headline facts under the hero. */
export const facts = [
  { value: String(counts.checks), label: 'checks across cost, security and network' },
  { value: String(counts.areas), label: 'areas of Azure, from SQL to Entra ID' },
  { value: 'Read-only', label: 'nothing in your tenant is created or changed' },
  { value: 'Fixed fee', label: 'one price agreed before we start' },
];

export interface Pillar {
  name: string;
  question: string;
  body: string;
  points: string[];
}

export const pillars: Pillar[] = [
  {
    name: 'Cost',
    question: 'What could we stop paying for?',
    body: 'Savings priced in pounds a month, each one traced to the meter and the measurement behind it.',
    points: [
      'Licensing: Azure Hybrid Benefit, SQL Server editions, Dev/Test, reservations and savings plans',
      'Right-sizing from 30 days of measured use, not from a guess',
      'Orphaned and idle resources still on the bill',
      'Storage: tiers, redundancy, and capacity provisioned but not used',
    ],
  },
  {
    name: 'Security',
    question: 'Where are we exposed?',
    body: 'Findings ranked by a severity that takes context into account and says why it landed where it did.',
    points: [
      'Exposure: what is reachable from the internet, and through which rule',
      'Vulnerabilities, missing protection and unprotected backups',
      'Software and services past the end of support',
      'Identity and access: standing admin roles, PIM, guests, app secrets, Conditional Access',
    ],
  },
  {
    name: 'Network',
    question: 'Is the network doing what we think it is?',
    body: 'The configuration as written, and with flow logs, the traffic that is really crossing it.',
    points: [
      'NSG rules that are too wide, shadowed or never hit',
      'Routes that point nowhere or step around the firewall',
      'Overlapping address space, peering and subnets about to run out',
      'Production talking to dev, and the internet reaching sensitive ports',
    ],
  },
];

/**
 * The disclaimer shown wherever the page quotes a saving. What a client
 * really pays depends on their own agreement, so every figure is a list
 * price and the page has to say so in plain words.
 */
export const savingsNote =
  'Savings are estimates at Azure list price in pounds. What you actually pay depends on your own agreement: a CSP or Enterprise Agreement discount, reservations, savings plans or negotiated rates will make the real figure different, and usually lower. Treat each figure as the size and order of the opportunity, to be confirmed against your own bill before it goes into a budget.';

export interface ExampleFinding {
  pillar: 'Cost' | 'Security' | 'Network';
  section: string;
  title: string;
  /** Cost findings: the monthly saving. Security and network: the severity. */
  figure: string;
  /** Under the figure: "a month" for savings, the reasons for a severity. */
  figureNote: string;
  body: string;
  /** What a change board wants to know, as the finding states it. */
  plan: string[];
}

/**
 * Eight findings from the demonstration estate, one for each section of
 * the report. Titles and figures are exactly as the product printed them;
 * the body is the finding's own evidence in a sentence or two.
 */
export const examples: ExampleFinding[] = [
  {
    pillar: 'Cost',
    section: 'Licensing',
    title: 'vm-sql-prd-01a pays for SQL Server Enterprise by the hour',
    figure: '£3,293',
    figureNote: 'a month',
    body: 'A 16-vCPU SQL Server Enterprise VM on pay-as-you-go licensing. If you already own the licences with Software Assurance, Azure Hybrid Benefit removes the hourly licence charge.',
    plan: ['Low effort', 'No reboot', 'No downtime', 'Standard change', 'Owner: DBA'],
  },
  {
    pillar: 'Cost',
    section: 'Right-sizing',
    title: 'Dedicated SQL pool dwh (DW500c) peaks at 20%: DW200c would do',
    figure: '£2,733',
    figureNote: 'a month',
    body: 'The pool used 20% of DW500c at the 95th percentile of hourly peaks over 30 days. DW200c holds that with 50% headroom.',
    plan: ['Low effort', 'No reboot', 'Brief downtime while it scales', 'Normal change', 'Owner: DBA'],
  },
  {
    pillar: 'Cost',
    section: 'Orphaned and idle',
    title: 'DDoS plan ddos-plan protects no networks',
    figure: '£2,213',
    figureNote: 'a month',
    body: 'The plan has no virtual network attached, so it protects nothing and still bills its flat monthly charge.',
    plan: ['Low effort', 'No reboot', 'No downtime', 'Normal change', 'Owner: network team'],
  },
  {
    pillar: 'Cost',
    section: 'Storage',
    title: 'stpremfiles/docs: 5120 GiB provisioned, 800 GiB used',
    figure: '£532',
    figureNote: 'a month',
    body: 'A Premium file share billed on the size it was given, not on what it holds. 1100 GiB would still leave 30% headroom.',
    plan: ['Low effort', 'No reboot', 'No downtime', 'Standard change', 'Owner: platform team'],
  },
  {
    pillar: 'Security',
    section: 'Exposure',
    title: 'avd-claims-00 has RDP (3389) open to the internet',
    figure: 'Critical',
    figureNote: 'internet-facing, production',
    body: 'Reachable on its public IP. Allowed by the subnet NSG nsg-app-04, rule allow-rdp-internet, priority 100, from any address.',
    plan: ['Low effort', 'No reboot', 'No downtime', 'Normal change', 'Owner: security team'],
  },
  {
    pillar: 'Security',
    section: 'End of support',
    title: 'dc-onprem-00 runs Windows Server 2012 R2, out of support since 2023-10-10',
    figure: 'Critical',
    figureNote: 'past end of support, production',
    body: 'An Arc-connected production server more than three years past the end of support, so it no longer receives security fixes.',
    plan: ['High effort', 'Reboot needed', 'Planned window', 'Major change (needs CAB)', 'Owner: platform team'],
  },
  {
    pillar: 'Security',
    section: 'Identity and access',
    title: 'No Conditional Access policy requires MFA of administrators',
    figure: 'Critical',
    figureNote: 'privileged access',
    body: 'One policy is enabled, for Office 365 only. Nothing requires multifactor authentication of the people who hold directory roles.',
    plan: ['Low effort', 'No reboot', 'No downtime', 'Normal change', 'Owner: security team'],
  },
  {
    pillar: 'Network',
    section: 'Network traffic',
    title: '5,200 flows between vnet-spoke-00 (prod) and vnet-spoke-02 (dev)',
    figure: 'Critical',
    figureNote: 'production',
    body: 'Over 30 days, 5,200 allowed flows (12.5 GB) crossed from production to dev on port 1433. Read from flow logs, not inferred from rules.',
    plan: ['Medium effort', 'No reboot', 'No downtime', 'Normal change', 'Owner: network team'],
  },
];

/** What every finding carries, whatever it is about. */
export const planningFields = [
  ['Effort', 'Low, medium or high'],
  ['Reboot', 'Yes, no or possibly'],
  ['Downtime', 'None, brief, or a planned window with an estimate'],
  ['Change type', 'Standard, normal, or major and bound for CAB'],
  ['Owner', 'Platform, DBA, network, security or application'],
  ['Before you start', 'What to confirm first'],
  ['What could go wrong', 'The side effects to expect'],
  ['How to undo it', 'The way back'],
];

export interface CoverageArea {
  area: string;
  resources: string;
}

/** The thirteen areas the report groups its findings by. */
export const coverage: CoverageArea[] = [
  { area: 'Compute', resources: 'Windows and Linux virtual machines, scale sets, dedicated hosts, shutdown schedules' },
  { area: 'SQL', resources: 'SQL Server on VMs, Azure SQL Database and elastic pools, SQL Managed Instance' },
  { area: 'Storage', resources: 'Managed disks, snapshots, images, blob and file storage, Data Lake, NetApp Files' },
  { area: 'Backup and DR', resources: 'Recovery Services vaults, Azure Backup, Site Recovery' },
  { area: 'Network', resources: 'Virtual WAN, hub-and-spoke VNets, peering, NSGs, route tables, Azure Firewall, ExpressRoute and VPN gateways, public IPs, private endpoints, Private DNS, Bastion, load balancers' },
  { area: 'Databases', resources: 'Cosmos DB' },
  { area: 'Virtual desktops', resources: 'Azure Virtual Desktop host pools, session hosts, scaling plans, FSLogix shares' },
  { area: 'Data platform', resources: 'Data Factory, Databricks, Synapse, Fabric, Power BI, Analysis Services' },
  { area: 'Applications', resources: 'App Service, Functions, Logic Apps, API Management, Service Bus, Event Hubs' },
  { area: 'Edge', resources: 'Application Gateway with WAF, Front Door' },
  { area: 'Identity and security', resources: 'Entra ID roles, PIM, guests and app registrations, Conditional Access, Azure RBAC, Key Vault, Defender for Cloud' },
  { area: 'Monitoring', resources: 'Log Analytics, Azure Monitor, Application Insights, Sentinel' },
  { area: 'Hybrid and licensing', resources: 'Azure Arc servers, Extended Security Updates, Hybrid Benefit, reservations, savings plans, Dev/Test subscriptions' },
];

export interface Step {
  number: string;
  title: string;
  body: string;
}

export const steps: Step[] = [
  {
    number: '01',
    title: 'A short call',
    body: 'Thirty minutes to agree which subscriptions are in scope and how much read access you are comfortable granting.',
  },
  {
    number: '02',
    title: 'You grant read-only access',
    body: 'A checklist in the client portal walks your team through each grant. We test that every one works before the scan, so nothing is found missing afterwards.',
  },
  {
    number: '03',
    title: 'We scan and review',
    body: 'The scan reads configuration, metrics and prices. We check the leading findings by hand before you see any of them.',
  },
  {
    number: '04',
    title: 'You get the findings',
    body: 'A walk-through of the results, the report in your portal, the PDF, and CSV and Excel for your engineers. What happens next is your decision.',
  },
];

export interface AccessTier {
  grant: string;
  checks: string;
  unlocks: string;
}

/**
 * What a client grants, and how much of the health check each grant
 * switches on. The five counts add up to `counts.checks`.
 */
export const accessTiers: AccessTier[] = [
  {
    grant: 'Reader on the subscriptions in scope',
    checks: String(counts.readerOnly),
    unlocks: 'Every check that reads configuration, metrics and prices. Enough on its own for a full engagement.',
  },
  {
    grant: 'Log Analytics Reader on your workspaces',
    checks: '13',
    unlocks: 'What is really happening: network flows, firewall traffic, virtual desktop usage, log ingestion you pay for and never query.',
  },
  {
    grant: 'A Microsoft Graph app with read permissions',
    checks: '8',
    unlocks: 'Who holds what in Entra ID: standing admin roles, PIM, guests, app secrets near expiry, Conditional Access.',
  },
  {
    grant: 'Reservations Reader and Savings plan reader',
    checks: '7',
    unlocks: 'How well your reservations and savings plans are used, and where a steady workload has none.',
  },
  {
    grant: 'Optional extras',
    checks: '21',
    unlocks: 'Databricks workspaces, and read-only scripts your own staff run for SQL Server VMs, FSLogix shares and Synapse.',
  },
];

/** The short version of the security and data-handling statement. */
export const safeguards = [
  {
    title: 'Read-only, control plane only',
    body: 'The scan identity holds Reader and the optional read-only roles, nothing else. It reads no blobs, files, database rows, secrets or keys.',
  },
  {
    title: 'Nothing installed',
    body: 'No agent, extension or resource goes into your tenant. Any script that runs inside a server is supplied in source and run by your own staff.',
  },
  {
    title: 'Held in the UK',
    body: 'What we collect is configuration, metric summaries and the findings. It is held in HarvTech’s own Azure tenant in the UK, behind Entra sign-in.',
  },
  {
    title: 'Deleted when we are done',
    body: 'Your data is kept for the engagement and 90 days after the final report, then deleted. Sooner on request, confirmed in writing.',
  },
  {
    title: 'No third parties, no AI',
    body: 'Findings come from deterministic rules. No client data is sent to a third party or processed by a language model.',
  },
  {
    title: 'A statement you can read first',
    body: 'The full security and data-handling statement lists everything read, grant by grant. You see it before you grant anything.',
  },
];

export interface Question {
  q: string;
  a: string;
}

export const questions: Question[] = [
  {
    q: 'Is this an audit?',
    a: 'No. It is not an audit or a certification, and it gives no opinion on any standard. It shows where the checks found improvements to make, which is useful to have in hand before an auditor arrives.',
  },
  {
    q: 'How real are the savings?',
    a: 'They are estimates. Each one is priced at Azure list price in pounds from Microsoft’s public price list, so the real figure depends on what you pay through your CSP or Enterprise Agreement and will usually be lower. The headline counts one option per resource, so two ways of saving on the same server are never added together. Where a figure cannot be worked out honestly, the finding says so.',
  },
  {
    q: 'What if we only grant Reader?',
    a: `That is a complete engagement: ${counts.readerOnly} of the ${counts.checks} checks. Anything that needed more is shown as “not assessed”, so a gap in access never looks like a clean result.`,
  },
  {
    q: 'Does it change anything in our tenant?',
    a: 'No. It has no write permission and no code that writes to a client tenant. We recommend; you decide and you make the change, or ask us to.',
  },
  {
    q: 'Does it cover AWS, Google Cloud or third-party appliances?',
    a: 'Not today. It covers Microsoft Azure and Entra ID in depth, and nothing else.',
  },
  {
    q: 'Who fixes what it finds?',
    a: 'Your team can, working from the plan each finding carries. If you would rather we did it, our remediation and cost work picks up from the same findings.',
  },
];
