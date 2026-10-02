export interface ServiceOffering {
  title: string;
  description: string;
}

/**
 * A packaged engagement stage (assessment → delivery → retainer).
 * Services structured as a productised journey (Security Hardening)
 * use `stages`; the broader capability lines use `offerings`.
 */
export interface ServiceStage {
  number: string;
  name: string;
  format: string; // e.g. "Fixed scope · 2-3 weeks", engagement shape, never pricing
  description: string;
  outputs: string[];
}

export interface Service {
  slug: string;
  title: string;
  eyebrow: string;
  tagline: string;
  summary: string;
  offerings?: ServiceOffering[];
  stages?: ServiceStage[];
  deliverables: string[];
}

export const services: Service[] = [
  {
    slug: 'security-hardening',
    title: 'Security Hardening',
    eyebrow: 'Security & compliance',
    tagline: 'Failed an audit - or facing one? Findings fixed in code, with evidence.',
    summary:
      'Audit-driven Azure security and compliance remediation for regulated environments. The usual trigger is a failed or upcoming audit: we turn the findings into a risk-scored plan, fix them in Terraform and pipelines with a full evidence trail, and keep you compliant between audits.',
    stages: [
      {
        number: '01',
        name: 'Security Controls Assessment',
        format: 'Fixed scope · 2-3 weeks',
        description:
          'A gap analysis of your Azure estate against the thing that actually triggered the work - your audit findings, or SOX ITGC, ISO 27001 Annex A, and DORA control sets. Identity, privileged access, Conditional Access, Key Vault, Defender, logging, and the pipelines that change them.',
        outputs: [
          'Risk-scored remediation plan, ordered by exposure and audit impact',
          'Effort estimate per finding, so remediation can be budgeted honestly',
          'Evidence requirements per control - what an auditor will ask for, captured up front',
        ],
      },
      {
        number: '02',
        name: 'Remediation Sprints',
        format: 'Delivery · 10-day blocks',
        description:
          'The plan delivered in Terraform and CI/CD pipelines - Entra ID, PIM, Conditional Access, Key Vault, Defender for Cloud. Every change reviewed, merged through your branching process, and traceable: what changed, when, why, and which control it satisfies.',
        outputs: [
          'Findings remediated as reviewed, merged infrastructure-as-code',
          'Azure Policy guardrails that keep fixed things fixed',
          'An auditor-ready evidence pack closing out each block',
        ],
      },
      {
        number: '03',
        name: 'Continuous Compliance',
        format: 'Retainer',
        description:
          'Compliance decays between audits - access accumulates, policies drift, scores slip. A standing cadence keeps the posture you paid for: reviewed, evidenced, and ready before the auditor asks.',
        outputs: [
          'Quarterly access reviews with documented outcomes',
          'PIM and Conditional Access drift checks against the agreed baseline',
          'Defender for Cloud secure score reporting with trend and commentary',
          'Pre-audit readiness checks ahead of each cycle',
        ],
      },
    ],
    deliverables: [
      'Risk-scored assessment mapped to DORA, SOX ITGC, ISO 27001 Annex A, FCA, and PCI DSS',
      'Remediation delivered as reviewed Terraform with a full change history',
      'Auditor-ready evidence pack per remediation block',
      'Terraform-managed Azure Policy guardrails',
      'Entra ID, PIM, and Conditional Access hardened with phishing-resistant MFA',
      'Defender for Cloud workload protection configured and reporting',
    ],
  },
  {
    slug: 'greenfield-platform-build',
    title: 'Greenfield Platform Build',
    eyebrow: 'Platform engineering',
    tagline: 'The right foundations. Before the first workload lands.',
    summary:
      'Build your Azure platform right from day one - CAF-aligned landing zone designed for your workloads and regulatory environment, engineered in Terraform with automated delivery workflows baked in from the start.',
    offerings: [
      {
        title: 'CAF Alignment',
        description:
          'Subscription design, management group hierarchy, naming conventions, tagging strategy, and governance policies, aligned to the Microsoft Cloud Adoption Framework and your organisation\'s operating model.',
      },
      {
        title: 'Architectural Design',
        description:
          'Hub-spoke or Virtual WAN topology, identity architecture, DNS design, and security baseline, documented in Architecture Decision Records so every trade-off is visible, reasoned, and reviewable by your team.',
      },
      {
        title: 'Engineering',
        description:
          'Everything in Terraform. Modules for each landing zone component, tested in CI with Checkov, Trivy, and tflint. State in Azure Storage with locking, RBAC-restricted, and fully auditable.',
      },
      {
        title: 'DevOps Workflows',
        description:
          'OIDC-federated GitHub Actions pipelines, no long-lived secrets in CI. Branch protection, required status checks, and automated security scanning baked into every pull request from day one.',
      },
    ],
    deliverables: [
      'CAF-aligned landing zone in Terraform',
      'Architecture Decision Records for every significant design choice',
      'Hub-spoke network topology with Azure Firewall',
      'Entra ID identity baseline and Conditional Access policies',
      'CI/CD pipelines with OIDC federation and security scanning',
      'Operational runbooks and handover documentation',
    ],
  },
  {
    slug: 'migrations',
    title: 'Migrations',
    eyebrow: 'Cloud adoption',
    tagline: 'Move to the cloud. Land in a well-architected state.',
    summary:
      'Structured migrations from data centres, on-premises infrastructure, or sprawling unmanaged environments, using the CAF Migration Factory approach so every workload lands governed, secured, and documented.',
    offerings: [
      {
        title: 'Data Centre to Cloud',
        description:
          'Full DC exit planning and execution - assess your current estate, map dependencies, sequence migration waves, and land each workload in a dedicated landing zone with security controls applied from day one.',
      },
      {
        title: 'On-premises to Cloud',
        description:
          'Lift-and-shift or modernise-in-flight - Azure Migrate for discovery and replication, Terraform for the destination infrastructure, and a clear cutover plan that minimises downtime and risk at every stage.',
      },
      {
        title: 'Unstructured to Landing Zones',
        description:
          'Environments that grew without guardrails - subscription sprawl, no governance policies, accumulated security debt. We assess what you have, design the target state, and migrate workloads into a governed landing zone.',
      },
    ],
    deliverables: [
      'Migration wave plan with sequenced workloads and dependencies mapped',
      'Azure Migrate discovery and dependency analysis',
      'Target landing zone architecture and IaC',
      'Cutover runbooks and rollback procedures',
      'Post-migration security posture assessment',
    ],
  },
  {
    slug: 'networking',
    title: 'Networking',
    eyebrow: 'Network architecture',
    tagline: 'Secure, scalable Azure networks - built to last.',
    summary:
      'Design and build Azure network topologies that are secure by default, auditable in code, and documented so your team understands every traffic flow and every rule.',
    offerings: [
      {
        title: 'Firewalls',
        description:
          'Azure Firewall in a hub with centralised policy management - IDPS in alert or deny mode, application and network rules, DNS proxy. Firewall Policy as code, version-controlled and reviewed in CI.',
      },
      {
        title: 'Load Balancers',
        description:
          'Azure Load Balancer, Application Gateway, and Front Door selected by traffic pattern, protocol requirement, and WAF need. Each layer designed with TLS termination, DDoS protection, and health probes configured correctly.',
      },
      {
        title: 'VLAN & Segmentation',
        description:
          'Subnet design with Network Security Groups and Application Security Groups - micro-segmentation aligned to workload tiers and regulatory zoning requirements. NSG flow logs to Log Analytics for continuous audit.',
      },
      {
        title: 'Routing',
        description:
          'User-defined routes to force traffic through the hub firewall, BGP for ExpressRoute circuits, and route table management in Terraform with documented traffic flows for every subnet.',
      },
      {
        title: 'Private Links & Endpoints',
        description:
          'Private Endpoints for PaaS services - Storage, Key Vault, Cosmos DB, SQL, and more. Private DNS Zones auto-registered. Public internet access disabled at the resource level, not just firewalled at the perimeter.',
      },
    ],
    deliverables: [
      'Hub-spoke or Virtual WAN network design in Terraform',
      'Azure Firewall Policy as code with IDPS configured',
      'NSG and ASG ruleset with documented traffic flows',
      'Private Endpoint and Private DNS Zone deployment',
      'Network architecture diagram and high-level design document',
    ],
  },
  {
    slug: 'finops',
    title: 'FinOps',
    eyebrow: 'Cost management',
    tagline: 'Visibility, discipline, and accountability for Azure spend.',
    summary:
      'Get Azure costs under control - identify what\'s wasting money, right-size over-provisioned workloads, optimise licensing, and put the structures in place so spend stays visible and owned.',
    offerings: [
      {
        title: 'Cost Optimisation',
        description:
          'Analyse Cost Management data to identify the top spend drivers, assess reservation and savings plan opportunities, and quantify the changes that deliver measurable savings without sacrificing reliability or performance.',
      },
      {
        title: 'Stale Resources',
        description:
          'Systematic discovery of orphaned managed disks, unattached public IPs, idle App Service Plans, stopped VMs still incurring storage costs, and other forgotten resources accumulating charges month after month.',
      },
      {
        title: 'Right Sizing',
        description:
          'VM and PaaS SKU analysis against actual CPU, memory, and IOPS utilisation data. Over-provisioned workloads costing twice what they should - recommendations with risk assessment so you know what\'s safe to resize.',
      },
      {
        title: 'Licensing',
        description:
          'Azure Hybrid Benefit coverage gaps for Windows and SQL Server, Dev/Test pricing for non-production environments, BYOL opportunities for third-party software. Savings quantified, coverage changes tracked in Terraform.',
      },
    ],
    deliverables: [
      'Azure spend analysis with top cost-driver breakdown',
      'Stale resource inventory with estimated monthly saving per item',
      'Right-sizing recommendations with utilisation data evidence',
      'Licensing optimisation report with Hybrid Benefit coverage gaps',
      'Tagging strategy and budget alert configuration in Terraform',
    ],
  },
];
