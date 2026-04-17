import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Start Here',
      items: [
        'start-here/choose-your-track',
        'start-here/capabilities',
        'start-here/embedded-library-first-run',
        'start-here/server-first-run',
      ],
    },
    {
      type: 'category',
      label: 'Concepts',
      items: [
        'concepts/core-model',
        'concepts/embedded-and-server',
        'concepts/durability-modes',
        'concepts/cursors',
        'concepts/tiered-storage-and-manifests',
        'concepts/failover',
        'concepts/cryptographic-proofs',
      ],
    },
    {
      type: 'category',
      label: 'Foundations',
      items: [
        'foundations/system-model',
        'reference/contracts/repository-overview',
        'reference/contracts/architecture',
        'reference/contracts/configuration',
        'reference/contracts/integrity',
        'reference/contracts/materialization',
        'reference/contracts/communication',
        'reference/contracts/ai-traces',
        'reference/contracts/ai-artifacts',
        'reference/contracts/evaluations',
      ],
    },
  ],
};

export default sidebars;
