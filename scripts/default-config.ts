import { defaultENSConfigurationTemplate } from '/w/common/ens/configuration/data/default-configuration';

process.stdout.write(
  JSON.stringify({
    configuration: { ...defaultENSConfigurationTemplate, scope: { mode: 'group', agentIds: [], groupIds: ['ens'] } },
    changeReason: 'First save of the lab (power-ens-lab).',
    expectedVersion: null,
  })
);
