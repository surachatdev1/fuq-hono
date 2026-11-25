// Experimental HRS web login contract, confirmed separately from the Android
// binary. Not connected to production routes and contains no attendance writes.
const endpoint = 'https://web-core.humansoft.co.th/api-web.php';
const b64 = value => Buffer.from(String(value), 'utf8').toString('base64');
const text = value => typeof value === 'string' || typeof value === 'number'
  ? String(value).trim() : '';
const yes = value => ['Y', '1', 'true'].includes(String(value));

export class HumanSoftAuthError extends Error {
  constructor(code) {
    super('HumanSoft login unavailable');
    this.name = 'HumanSoftAuthError';
    this.code = code;
  }
}

export function createHumanSoftAuth({fetchImpl = globalThis.fetch} = {}) {
  async function request(fields) {
    try {
      const response = await fetchImpl(endpoint, {
        method: 'POST', redirect: 'error',
        headers: {'Content-Type': 'application/json', Origin: 'https://hrs.humansoft.co.th'},
        body: JSON.stringify({...fields, language_code: 'TH'}),
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) throw new HumanSoftAuthError('transport_failed');
      const result = await response.json();
      if (!result || ![200, '200'].includes(result.code)) {
        throw new HumanSoftAuthError('upstream_rejected');
      }
      return result;
    } catch (error) {
      // Upstream bodies/errors may contain credentials or employee information.
      if (error instanceof HumanSoftAuthError) throw error;
      throw new HumanSoftAuthError('transport_failed');
    }
  }

  return {
    async login({domain = 'PSDGROUP', company = 'NWL', username, password} = {}) {
      if (!/^[A-Za-z0-9_-]{1,64}$/.test(domain) ||
          !/^[A-Za-z0-9_-]{1,64}$/.test(company) ||
          typeof username !== 'string' || !username.trim() || username.length > 128 ||
          typeof password !== 'string' || !password || password.length > 1024) {
        throw new HumanSoftAuthError('invalid_input');
      }
      // Never assume that the first company returned by PSDGROUP is NWL.
      const lookup = await request({_compgrp: 'hrs', _comp: 'sites',
        _action: 'get_instance_server_code', instance_server_code: domain});
      const servers = Array.isArray(lookup.payload) ? lookup.payload : [];
      const matches = servers.filter(server =>
        text(server.instance_server_code).toUpperCase() === domain.toUpperCase());
      if (matches.length !== 1) throw new HumanSoftAuthError('domain_unavailable');
      const server = matches[0];
      const channels = Array.isArray(server.INSTANCE_SERVER_CHANNELS)
        ? server.INSTANCE_SERVER_CHANNELS.filter(c => text(c.company_code) === company) : [];
      if (channels.length !== 1 || !text(server.instance_server_id) ||
          !text(channels[0].instance_server_channel_id)) {
        throw new HumanSoftAuthError('company_unavailable');
      }
      const channel = channels[0];
      const authenticated = await request({_compgrp: 'hrs', _comp: 'users',
        _action: 'identifier_user', user_name: username, user_psw: password,
        instance_server_id: b64(server.instance_server_id),
        instance_server_channel_id: b64(channel.instance_server_channel_id),
        identify_user_id: '', employee_id: ''});
      const account = authenticated.payload;
      if (!account || Array.isArray(account) || typeof account !== 'object') {
        throw new HumanSoftAuthError('session_incomplete');
      }
      if (['first_singin_flag', 'password_expire_flag', 'force_change_password_flag']
          .some(k => yes(account[k])) || text(account.code_2factor)) {
        throw new HumanSoftAuthError('account_action_required');
      }
      if (yes(account.sys_del_flag) || account.use_app_flag === 'N') {
        throw new HumanSoftAuthError('account_disabled');
      }
      if (text(account.instance_server_id) !== text(server.instance_server_id) ||
          text(account.instance_server_channel_id) !== text(channel.instance_server_channel_id) ||
          text(account.employee_code) !== username.trim() || account.user_type !== 'hrs') {
        throw new HumanSoftAuthError('account_mismatch');
      }
      if (!text(authenticated.jwt_token) ||
          ['employee_id', 'user_id', 'identify_user_id'].some(k => !text(account[k]))) {
        throw new HumanSoftAuthError('session_incomplete');
      }
      // Server-only value; a future route must seal/persist it independently of
      // HONO. Never return this object to the browser or save it in localStorage.
      return {provider: 'humansoft', domain: text(server.instance_server_code),
        company, employee: text(account.employee_code), employeeId: text(account.employee_id),
        userId: text(account.user_id), identifyUserId: text(account.identify_user_id),
        instanceId: text(account.instance_server_id),
        channelId: text(account.instance_server_channel_id), token: authenticated.jwt_token};
    },
  };
}
