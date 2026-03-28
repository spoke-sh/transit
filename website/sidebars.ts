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
  ],
};

export default sidebars;
