import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Start Here',
      items: ['start-here/choose-your-track'],
    },
    {
      type: 'category',
      label: 'Concepts',
      items: ['concepts/core-model'],
    },
  ],
};

export default sidebars;

