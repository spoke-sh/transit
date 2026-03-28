import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Start Here',
      items: [
        'start-here/choose-your-track',
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
        'concepts/tiered-storage-and-manifests',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      items: [
        'reference/foundational-docs',
        {
          type: 'category',
          label: 'Platform Contracts',
          items: [
            'reference/contracts/repository-overview',
            'reference/contracts/constitution',
            'reference/contracts/architecture',
            'reference/contracts/configuration',
            'reference/contracts/guide',
            'reference/contracts/drift',
            'reference/contracts/evaluations',
            'reference/contracts/release',
          ],
        },
        {
          type: 'category',
          label: 'Workload Contracts',
          items: [
            'reference/contracts/communication',
            'reference/contracts/materialization',
            'reference/contracts/integrity',
            'reference/contracts/ai-traces',
            'reference/contracts/ai-artifacts',
          ],
        },
      ],
    },
  ],
};

export default sidebars;
