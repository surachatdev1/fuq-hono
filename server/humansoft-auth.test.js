import test from 'node:test';
import assert from 'node:assert/strict';
import {createHumanSoftAuth, HumanSoftAuthError} from './humansoft-auth.js';

function fixture({mutate = () => {}, channels, failure} = {}) {
  const calls = [];
  const employee = {instance_server_id: 'server-fixture',
    instance_server_channel_id: 'nwl-fixture', employee_code: 'fixture-employee',
    employee_id: 'employee-fixture', user_id: 'user-fixture', identify_user_id: 'identity-fixture',
    user_type: 'hrs', first_singin_flag: 'N', password_expire_flag: 'N',
    sys_del_flag: 'N', userpsw_tmp: 'must-not-escape', salary: 'must-not-escape'};
  mutate(employee);
  const auth = createHumanSoftAuth({fetchImpl: async (url, init) => {
    const body = JSON.parse(init.body);
    calls.push({url, init, body});
    if (failure) throw new Error('sensitive-password-and-response');
    if (body._action === 'get_instance_server_code') {
      return Response.json({code: '200', payload: [{instance_server_code: 'PSDGROUP',
        instance_server_id: 'server-fixture', INSTANCE_SERVER_CHANNELS: channels ?? [
          {company_code: 'OTHER', instance_server_channel_id: 'other-fixture'},
          {company_code: 'NWL', instance_server_channel_id: 'nwl-fixture'},
        ]}]});
    }
    return Response.json({code: 200, jwt_token: 'opaque-fixture-token', payload: employee});
  }});
  return {auth, calls};
}
const input = {username: 'fixture-employee', password: 'fixture-pass&word'};

test('HRS login chooses NWL, encodes IDs and returns only a server-side session', async () => {
  const {auth, calls} = fixture();
  const result = await auth.login(input);
  assert.equal(calls.length, 2);
  for (const {url, init} of calls) {
    assert.equal(url, 'https://web-core.humansoft.co.th/api-web.php');
    assert.equal(init.method, 'POST');
    assert.equal(init.redirect, 'error');
    assert.equal(init.signal instanceof AbortSignal, true);
    assert.equal(url.includes(input.password), false);
  }
  assert.equal(calls[1].body.instance_server_channel_id,
    Buffer.from('nwl-fixture').toString('base64'));
  assert.equal(calls[1].body.user_psw, input.password);
  assert.equal(result.employee, input.username);
  assert.equal(result.token, 'opaque-fixture-token');
  assert.equal(JSON.stringify(result).includes('must-not-escape'), false);
  assert.equal(JSON.stringify(result).includes(input.password), false);
});

test('missing or ambiguous company never sends credentials to another company', async () => {
  for (const channels of [[], [{company_code: 'OTHER', instance_server_channel_id: 'other'}],
    [{company_code: 'NWL', instance_server_channel_id: 'a'},
      {company_code: 'NWL', instance_server_channel_id: 'b'}]]) {
    const {auth, calls} = fixture({channels});
    await assert.rejects(auth.login(input), {code: 'company_unavailable'});
    assert.equal(calls.length, 1);
  }
});

test('wrong employee, company or instance cannot become the linked session', async () => {
  for (const key of ['employee_code', 'instance_server_channel_id', 'instance_server_id']) {
    const {auth} = fixture({mutate: account => account[key] = 'another-account'});
    await assert.rejects(auth.login(input), {code: 'account_mismatch'});
  }
});

test('required password actions, MFA and disabled accounts require an official handoff', async () => {
  for (const key of ['first_singin_flag', 'password_expire_flag', 'force_change_password_flag',
    'code_2factor', 'sys_del_flag', 'use_app_flag']) {
    const {auth} = fixture({mutate: a => a[key] = key === 'use_app_flag' ? 'N' : 'Y'});
    await assert.rejects(auth.login(input), error => error instanceof HumanSoftAuthError &&
      error.code === (['sys_del_flag', 'use_app_flag'].includes(key)
        ? 'account_disabled' : 'account_action_required'));
  }
});

test('transport failure is sanitized and is not retried with credentials', async () => {
  const {auth, calls} = fixture({failure: true});
  await assert.rejects(auth.login(input), error => {
    assert.equal(error.code, 'transport_failed');
    assert.equal(JSON.stringify(error).includes('sensitive'), false);
    assert.equal(error.stack.includes('sensitive'), false);
    return true;
  });
  assert.equal(calls.length, 1);
});

test('invalid inputs make no request and missing identity cannot create a session', async () => {
  const {auth, calls} = fixture();
  for (const fields of [{domain: 'https://elsewhere.invalid'}, {company: '../NWL'},
    {username: ''}, {password: ''}]) {
    await assert.rejects(auth.login({...input, ...fields}), {code: 'invalid_input'});
  }
  assert.equal(calls.length, 0);
  const incomplete = fixture({mutate: account => delete account.identify_user_id});
  await assert.rejects(incomplete.auth.login(input), {code: 'session_incomplete'});
});

test('HTTP failure, application rejection and malformed JSON never leak upstream details', async () => {
  for (const response of [
    new Response('sensitive detail', {status: 403}),
    Response.json({code: '400', message: 'sensitive detail'}),
    new Response('not-json-sensitive-detail'),
  ]) {
    let count = 0;
    const auth = createHumanSoftAuth({fetchImpl: async () => {count++; return response;}});
    await assert.rejects(auth.login(input), error => {
      assert.equal(error instanceof HumanSoftAuthError, true);
      assert.equal(error.stack.includes('sensitive'), false);
      return true;
    });
    assert.equal(count, 1);
  }
});
