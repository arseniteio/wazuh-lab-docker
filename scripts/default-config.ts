// Prints the document the Configuration screen saves the first time
// (the plugin's defaultENSConfigurationTemplate), ready for the first-save PUT.
// This way the lab does not need that click in the browser. The scope is the ens
// group: the engine configures the Wazuh groups of the scope.
import { defaultENSConfigurationTemplate } from '/w/common/ens/configuration/data/default-configuration';

process.stdout.write(
  JSON.stringify({
    configuration: { ...defaultENSConfigurationTemplate, scope: { mode: 'group', agentIds: [], groupIds: ['ens'] } },
    changeReason: 'First save of the lab (ensfacil-lab).',
    expectedVersion: null,
  })
);
