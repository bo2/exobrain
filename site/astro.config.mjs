// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://exobrain.diy',
  integrations: [
    starlight({
      title: 'Exobrain',
      customCss: ['./src/styles/custom.css'],
      description:
        'A version-controlled knowledge base your AI agent loads as context, so it works with knowledge of your world instead of starting cold every session.',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/bo2/exobrain' },
      ],
      editLink: {
        baseUrl: 'https://github.com/bo2/exobrain/edit/main/site/',
      },
      sidebar: [
        { label: 'Why an exobrain', slug: 'why' },
        { label: 'How it gets used', slug: 'how-its-used' },
        { label: 'Evidence', slug: 'evidence' },
        { label: 'Get started', slug: 'start' },
        {
          label: 'Concepts',
          items: [
            { label: 'Scopes', slug: 'concepts/scopes' },
            { label: 'Knowledge and workspaces', slug: 'concepts/knowledge-and-workspaces' },
            { label: 'How knowledge lands', slug: 'concepts/how-knowledge-lands' },
            { label: 'Skills and tools', slug: 'concepts/skills-and-tools' },
            { label: 'Staying current', slug: 'concepts/staying-current' },
          ],
        },
        { label: 'Questions', slug: 'questions' },
      ],
    }),
  ],
});
